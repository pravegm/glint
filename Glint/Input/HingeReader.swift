import Foundation
import QuartzCore
import SwiftUI

/// Reads the iPhone Duo hinge (iOS 27.1+) and reports `(angleDegrees, time)`: 180 = flat, time = `CACurrentMediaTime()`
/// on receipt (samples carry no timestamp of their own). On devices without a hinge (or below iOS 27.1) it calls
/// `onUnavailable` instead. Never use the hinge's `status` for play (it reads `.closed` at ~85° on hardware).
/// Copied from Hush (`Hush/Input/HingeReader.swift`, itself from Swoop and Brim), battle-tested on a real Duo.
///
/// Lifecycle trap (Squish, real Duo): back from the background with the phone open and still, iOS may send no hinge
/// change at all. On every scene activation the subscription is switched off and on again, which delivers the current
/// state. After a hinge has been seen, a transient nil (display handover) must not demote the app to the drag
/// fallback; that policy belongs to the caller (`HingeMirrorSource.hasHinge` never goes back to false).
///
/// Hush QA-5: iOS may also go silent after a display hand-off WITHOUT a scene-phase change (the app moved back to the
/// inner display). Bump `refreshToken` to force the same off/on re-subscription at any time (e.g. on every cover ↔
/// inner change). The default (0, never changed) does nothing extra.
///
/// Usage: `view.modifier(HingeReader(onUpdate: { angle, time in … }, onUnavailable: { … }, refreshToken: n))`
struct HingeReader: ViewModifier {
    let onUpdate: (Double, TimeInterval) -> Void
    let onUnavailable: () -> Void
    /// Any change re-subscribes (off, then on 30 ms later), which delivers the current hinge state.
    let refreshToken: Int

    @Environment(\.scenePhase) private var scenePhase
    @State private var enabled = true
    @State private var refresh = 0

    init(onUpdate: @escaping (Double, TimeInterval) -> Void, onUnavailable: @escaping () -> Void = {},
         refreshToken: Int = 0) {
        self.onUpdate = onUpdate
        self.onUnavailable = onUnavailable
        self.refreshToken = refreshToken
    }

    /// The off/on toggle: off now, on again 30 ms later (unless another re-subscription started meanwhile).
    @MainActor
    private func resubscribe() {
        refresh &+= 1
        let ticket = refresh
        enabled = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            guard ticket == refresh else { return }
            enabled = true
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .onHingeChange(isEnabled: enabled) { _, newContext in
                    if let hinge = newContext.hinge {
                        let time = CACurrentMediaTime()
                        let degrees = hinge.angle.degrees
                        FeelHingeLog.record(angle: degrees, at: time)
                        onUpdate(degrees, time)
                    } else {
                        onUnavailable()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    resubscribe()
                }
                .onChange(of: refreshToken) { _, _ in
                    resubscribe()
                }
        } else {
            content.onAppear(perform: onUnavailable)
        }
    }
}

/// `GLINT-H <t> <angle>` stdout lines for CI (the Duo scripts grep them), only in DEBUG with the `-glintDemo` launch
/// argument, at most 10 per second. Don't rename the prefix. Called on the main thread only (hinge callbacks).
enum FeelHingeLog {
    static let isEnabled: Bool = FeelDemoLog.isEnabled
    nonisolated(unsafe) private static var lastLine: TimeInterval = -.infinity

    static func record(angle: Double, at time: TimeInterval) {
        guard isEnabled, time - lastLine >= 0.1 else { return }
        lastLine = time
        print(String(format: "GLINT-H %.3f %.1f", time, angle))
        fflush(stdout)
    }
}
