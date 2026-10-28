import CoreGraphics
import Foundation

/// The phone fallback (GAME-DESIGN §3, first class): drag anywhere to aim the light, like a trackpad.
///
/// - **Relative**: a finger may land anywhere and the light doesn't jump to it. Only the finger's motion along the
///   garden's crease → flowers axis (`layout.dDirection`) counts: `Δband = Δpoints / layout.gardenDepth × 1.2`, so
///   one garden depth of drag is the full sweep (`Tuning.bandMin`…1). The target is clamped to that range at every
///   step, so pushing past an end and coming back moves the light at once.
/// - **Eased with a soft speed cap**: the band follows the target at `v = cap · tanh(error / (cap · easeTime))`, with
///   `cap = Tuning.dragSpeedCap` (R2: 1.4 d/s, was 2.4). A small move follows in ~60 ms; a flick is limited to the cap, so it
///   plays like the hinge (which can't teleport either).
/// - `creaseGlow` grows from 0 at `Tuning.bandMin` to 1 as the band reaches the crease (d = 0), like opening the phone.
/// - Never shut.
@MainActor
final class DragMirrorSource: MirrorSource {
    /// Band units per garden depth of drag (the full sweep, `1 − Tuning.bandMin`, at the default −0.2).
    nonisolated static let dragGain: Double = 1.2
    /// The ease's time constant (s) for small errors.
    nonisolated static let easeTime: Double = 0.06
    /// The longest frame step credited (s): a hitch never teleports the band.
    nonisolated static let maxStep: Double = 0.1

    /// Set by the App whenever the canvas changes.
    var layout: GardenLayout

    /// Where the band is now (d units).
    private(set) var band: Double
    /// Where the finger has asked it to go (d units, `Tuning.bandMin`…1).
    private(set) var target: Double
    /// True once any drag has moved the target (cleared by `reset(band:)`, not by `setBand`).
    private(set) var hasMoved = false
    /// A finger is down.
    private(set) var isDragging = false
    /// The value returned by the last `mirror(at:)`.
    private(set) var lastMirror: MirrorInput

    private var lastPoint: CGPoint?
    private var lastTime: TimeInterval?
    private var lastQuery: TimeInterval?
    private var velocity = FeelVelocityWindow(window: 0.1)

    init() {
        layout = GardenLayout(size: CGSize(width: 390, height: 844), foldVertical: false, gardenAfter: true,
                              gardenFraction: 0.58)
        let start = Tuning.bandMin
        band = start
        target = start
        lastMirror = MirrorInput(band: start, creaseGlow: 0, isShut: false, bandSpeed: 0)
    }

    // MARK: Touches (SwiftUI-space points)

    func dragBegan(_ p: CGPoint) {
        guard p.x.isFinite, p.y.isFinite else { return }
        lastPoint = p
        isDragging = true
    }

    func dragMoved(_ p: CGPoint) {
        guard p.x.isFinite, p.y.isFinite else { return }
        guard let last = lastPoint else {
            // A move without a begin (a touch that started elsewhere): anchor here, no jump.
            lastPoint = p
            isDragging = true
            return
        }
        lastPoint = p
        let delta = Self.bandDelta(from: last, to: p, layout: layout)
        let next = FeelMath.clamp(target + delta, Tuning.bandMin, 1)
        if abs(next - target) > 1e-9 { hasMoved = true }
        target = next
    }

    func dragEnded() {
        lastPoint = nil
        isDragging = false
    }

    // MARK: Placement

    /// Jump the band (and its target) to `newBand` with no speed: a level start puts it at `Tuning.bandMin`. Keeps
    /// `hasMoved`.
    func setBand(_ newBand: Double) {
        let value = newBand.isFinite ? FeelMath.clamp(newBand, Tuning.bandMin, 1) : Tuning.bandMin
        band = value
        target = value
        velocity.reset()
        lastMirror = MirrorInput(band: value, creaseGlow: Self.creaseGlow(band: value), isShut: false, bandSpeed: 0)
    }

    /// A fresh level: `setBand(newBand)`, forget the finger and clear `hasMoved` (so "Drag down to let the light in"
    /// shows again).
    func reset(band newBand: Double = Tuning.bandMin) {
        setBand(newBand)
        hasMoved = false
        dragEnded()
    }

    // MARK: MirrorSource

    func mirror(at time: TimeInterval) -> MirrorInput {
        guard time.isFinite else { return lastMirror }
        if let previous = lastQuery, time <= previous { return lastMirror }
        lastQuery = time
        let dt = lastTime.map { min(max(time - $0, 0), Self.maxStep) } ?? 0
        lastTime = time
        band = Self.ease(band, toward: target, dt: dt)
        let speed = velocity.add(band, at: time)
        let input = MirrorInput(band: band, creaseGlow: Self.creaseGlow(band: band), isShut: false, bandSpeed: speed)
        lastMirror = input
        return input
    }

    // MARK: Pure maths

    /// The band change for a finger moving from `a` to `b` (SwiftUI points): the motion along `layout.dDirection`,
    /// in garden depths, × `dragGain`. Motion across the garden (along the crease) counts for nothing.
    nonisolated static func bandDelta(from a: CGPoint, to b: CGPoint, layout: GardenLayout) -> Double {
        let depth = Double(layout.gardenDepth)
        guard depth > 1, depth.isFinite else { return 0 }
        let direction = layout.dDirection
        let dx = Double(b.x - a.x)
        let dy = Double(b.y - a.y)
        let along = dx * Double(direction.dx) + dy * Double(direction.dy)
        guard along.isFinite else { return 0 }
        return along / depth * dragGain
    }

    /// One frame of the ease: the band after `dt` s chasing `target` with the soft speed cap. Never overshoots.
    nonisolated static func ease(_ current: Double, toward goal: Double, dt: Double) -> Double {
        guard dt > 0, dt.isFinite, current.isFinite, goal.isFinite else { return current.isFinite ? current : goal }
        let error = goal - current
        if abs(error) < 1e-6 { return goal }
        let cap = max(Tuning.dragSpeedCap, 0.01)
        let speed = cap * tanh(error / (cap * easeTime))
        let step = speed * dt
        if abs(step) >= abs(error) { return goal }
        return current + step
    }

    /// The crease glow for a band position: 0 at `Tuning.bandMin`, 1 once the band reaches the crease (d ≥ 0).
    nonisolated static func creaseGlow(band value: Double) -> Double {
        let low = Tuning.bandMin
        guard low < 0 else { return 1 }
        return FeelMath.clamp01((value - low) / (0 - low))
    }
}
