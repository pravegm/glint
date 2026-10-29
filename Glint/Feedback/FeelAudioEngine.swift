import AVFoundation
import Foundation
import os
import QuartzCore
import UIKit

/// Owns the audio session and the AVAudioEngine that hosts `FeelSynth` (Hush's `FeelAudioEngine`, via Swoop and Brim).
///
/// Session: `.playback` + `.mixWithOthers`, so the game is heard even with the silent switch on (the founder's rule
/// since Squish) and never stops the player's own music.
/// Self-healing: interruptions, route changes, engine configuration changes and media-services resets all restart or
/// rebuild it; `heal()` (called ~1/s by the director, outside the frame) restarts a stopped engine. Every failure is
/// logged and the game simply goes silent: nothing here can crash or block (no audio hardware on the simulator or CI).
///
/// R5 (QA-R5 scene-feel P2-6, P2-10, P2-11, P2-12):
/// - **No synchronous wake from the frame loop.** A napping engine is woken on its own main-actor turn (`wakeSoon`),
///   never inside the frame that needs it; sounds asked for meanwhile are queued in the synth and play on the restart.
///   `prepare()` (the director calls it at level start, off the frame) brings everything up early.
/// - **Interruptions**: a `.began` whose reason is `.appWasSuspended` is ignored (it arrives late and isn't a call);
///   an `.ended` that never comes is repaired by `heal()` once the app is active again, and a "running" engine that
///   has stopped pulling audio (render callbacks frozen for ~2 s) is restarted.
/// - **Other audio**: `otherAudioPlaying` follows `secondaryAudioShouldBeSilencedHint` (the player's Music or a
///   podcast); the director mutes the dawn pad while it's true and keeps the game sounds.
/// - **Bluetooth**: `hapticDelay` is the route's output latency (+ the IO buffer), capped at 0.25 s, on Bluetooth
///   outputs only; the director delays haptic cues by it so a pop is felt when it's heard on AirPods.
@MainActor
final class FeelAudioEngine {
    /// Seconds of quiet while idle before the engine naps (lets a tap, a bell or the pad ring out).
    static let napAfter: Double = 6
    /// R5: an interruption with no `.ended` is repaired once the app has been active for this long after it began.
    static let interruptionRepairAfter: Double = 1.5
    /// R5: the longest a haptic is held back for a Bluetooth route (s).
    nonisolated static let maxHapticDelay: Double = 0.25

    private static let log = Logger(subsystem: "com.pravegm.glint", category: "audio")

    /// Audio on/off (sound or music on). Off pauses the engine (no battery spent); on starts it again.
    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled {
                if isStarted { ensureRunning(reason: "sound switched on") } else if wantsStart { start() }
            } else {
                synth?.send(.stopAll)
                if engine.isRunning { engine.pause() }
            }
        }
    }

    /// Menus and long pauses: while idle the engine naps (`AVAudioEngine.pause()`, no render callbacks) once nothing
    /// has played for `napAfter` seconds; a one-shot (a menu tap) wakes it for that sound. Off: awake soon (R5: on its
    /// own turn, not inside the caller's frame).
    var idle = false {
        didSet {
            guard oldValue != idle else { return }
            if idle {
                scheduleNap()
            } else {
                napTask?.cancel()
                napTask = nil
                wakeSoon(reason: "game")
            }
        }
    }

    /// R5: the player's own audio is playing (`secondaryAudioShouldBeSilencedHint`).
    private(set) var otherAudioPlaying = false
    /// R5: called on the main actor when `otherAudioPlaying` changes.
    var onOtherAudioChange: ((Bool) -> Void)?
    /// R5: how long to hold haptics back so they land with the sound (s; 0 except on Bluetooth).
    private(set) var hapticDelay: Double = 0

    private var engine = AVAudioEngine()
    private(set) var synth: FeelSynth?
    private var sourceNode: AVAudioSourceNode?
    private var observers: [NSObjectProtocol] = []
    private var engineObserver: NSObjectProtocol?
    private(set) var isStarted = false
    private var wantsStart = false
    private(set) var lastError: String?
    private var startFailures = 0
    private var lastRebuild: CFTimeInterval = -Double.infinity
    private var lastBed = FeelBed()
    /// Paused on purpose (see `idle`): nothing restarts it except a sound or leaving idle.
    private(set) var isNapping = false
    private var napTask: Task<Void, Never>?
    private var wakeTask: Task<Void, Never>?
    private var lastSoundTime: CFTimeInterval = -Double.infinity
    /// An interruption (a call, Siri) is in progress: `heal()` leaves the engine alone until it ends (or is repaired).
    private(set) var interrupted = false
    private var interruptedAt: CFTimeInterval = -Double.infinity
    /// R5: the render watchdog.
    private var lastRenderCount = -1
    private var renderStalls = 0

    init() {}

    var isRunning: Bool { engine.isRunning }

    /// Session, graph, engine. Lazy: does nothing until audio is on. Idempotent.
    func start() {
        wantsStart = true
        guard enabled, !isStarted else { return }
        isStarted = true
        configureSession()
        activateSession()
        buildGraph()
        startEngine(reason: "launch")
        observeSystem()
        refreshRoute()
        refreshOtherAudio()
    }

    /// R5: bring the engine up now (a level is about to start). Call it off the frame loop (the director does, on its
    /// own task): it may start the engine synchronously.
    func prepare() {
        if !isStarted {
            start()
        } else if isNapping {
            wake(reason: "prepare")
        } else {
            ensureRunning(reason: "prepare")
        }
        refreshRoute()
        refreshOtherAudio()
    }

    /// Queue one-shot sounds. Dropped while audio is off, the engine never came up, or it is stopped by an
    /// interruption (queued sounds would otherwise burst out together when the call ends). R5: a napping engine is
    /// woken on its own turn and the sounds wait in the synth's queue for it (a few ms late, never lost).
    func play(_ commands: [FeelSynthCommand]) {
        guard enabled, isStarted, !commands.isEmpty, let synth else { return }
        if isNapping {
            wakeSoon(reason: "sound")
        } else if !engine.isRunning {
            return
        }
        lastSoundTime = CACurrentMediaTime()
        for command in commands { synth.send(command) }
        if idle { scheduleNap() }
    }

    /// The continuous layers (always forwarded while awake). Remembered, so a synth built later (lazy start, rebuild
    /// after a media-services reset) or woken from a nap starts from it. An audible bed counts as sound: it wakes a
    /// napping engine (on its own turn) and holds off the next nap.
    func setBed(_ bed: FeelBed) {
        lastBed = bed
        if bed.hasLayers && bed.master > 0 && enabled && isStarted {
            lastSoundTime = CACurrentMediaTime()
            if idle && napTask == nil { scheduleNap() }
            if isNapping {
                wakeSoon(reason: "continuous sound") // the wake sends `lastBed`
                return
            }
        }
        if isNapping { return }
        synth?.send(.bed(bed))
    }

    /// The app became active again (calls, Siri, background). Also ends a tracked interruption (`.ended` isn't
    /// guaranteed to arrive).
    func resume() {
        interrupted = false
        refreshRoute()
        refreshOtherAudio()
        guard isStarted, enabled, !isNapping else { return }
        activateSession()
        ensureRunning(reason: "app active again")
    }

    /// Cheap check (the director calls it about once a second, on its own task). Repairs a stopped engine, an
    /// interruption whose `.ended` never came (once the app is active), and an engine that says it runs but has
    /// stopped rendering.
    func heal() {
        guard isStarted, enabled, !isNapping, synth != nil else { return }
        let state = UIApplication.shared.applicationState
        guard state != .background else { return }
        if interrupted {
            guard state == .active, CACurrentMediaTime() - interruptedAt > Self.interruptionRepairAfter else { return }
            interrupted = false
            activateSession()
            Self.log.info("Repaired an interruption with no end")
        }
        guard engine.isRunning else {
            lastRenderCount = -1
            renderStalls = 0
            ensureRunning(reason: "found stopped")
            return
        }
        let count = synth?.renderCallbacks ?? 0
        renderStalls = count == lastRenderCount ? renderStalls + 1 : 0
        lastRenderCount = count
        if renderStalls >= 2 {
            renderStalls = 0
            lastRenderCount = -1
            record("Audio engine stopped rendering", NSError(domain: "Glint.audio", code: 1))
            engine.stop()
            activateSession()
            startEngine(reason: "render stalled")
        }
    }

    // MARK: - Pure helpers (tests)

    /// The haptic hold-back for a route: output latency + IO buffer on Bluetooth (capped at `maxHapticDelay`), else 0.
    nonisolated static func hapticDelay(outputLatency: Double, ioBuffer: Double, bluetooth: Bool) -> Double {
        guard bluetooth else { return 0 }
        let latency = outputLatency.isFinite ? max(outputLatency, 0) : 0
        let buffer = ioBuffer.isFinite ? max(ioBuffer, 0) : 0
        return min(latency + buffer, maxHapticDelay)
    }

    /// Bluetooth outputs (A2DP, LE, hands-free).
    nonisolated static func isBluetooth(_ port: AVAudioSession.Port) -> Bool {
        port == .bluetoothA2DP || port == .bluetoothLE || port == .bluetoothHFP
    }

    /// Whether an interruption notification should be honoured: a `.began` caused by the app being suspended is not a
    /// real interruption (it arrives late, after the app is back), so it is ignored.
    nonisolated static func honoursBegan(reason: AVAudioSession.InterruptionReason?) -> Bool {
        reason != .appWasSuspended
    }

    // MARK: - Route and other audio

    private func refreshRoute() {
        let session = AVAudioSession.sharedInstance()
        let bluetooth = session.currentRoute.outputs.contains { (port: AVAudioSessionPortDescription) -> Bool in
            Self.isBluetooth(port.portType)
        }
        hapticDelay = Self.hapticDelay(outputLatency: session.outputLatency, ioBuffer: session.ioBufferDuration,
                                       bluetooth: bluetooth)
    }

    private func refreshOtherAudio() {
        let hint = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        guard hint != otherAudioPlaying else { return }
        otherAudioPlaying = hint
        onOtherAudioChange?(hint)
    }

    // MARK: - Naps (battery)

    private func scheduleNap() {
        napTask?.cancel()
        let delay: Double = Self.napAfter
        napTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            self?.napIfQuiet()
        }
    }

    private func napIfQuiet() {
        napTask = nil
        guard idle, !isNapping else { return }
        if CACurrentMediaTime() - lastSoundTime < Self.napAfter - 0.05 {
            scheduleNap()
            return
        }
        isNapping = true
        // Nothing may be left ringing (or queued) to burst out on waking.
        synth?.send(.stopAll)
        if engine.isRunning { engine.pause() }
    }

    private func interruptionBegan(reason: AVAudioSession.InterruptionReason?) {
        guard Self.honoursBegan(reason: reason) else { return }
        interrupted = true
        interruptedAt = CACurrentMediaTime()
        // Whatever was queued must not burst out when the call ends.
        synth?.send(.stopAll)
    }

    /// R5: wake on the next main-actor turn (never inside the caller's frame). Repeated asks share one wake.
    private func wakeSoon(reason: String) {
        guard isNapping, wakeTask == nil else { return }
        wakeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.wakeTask = nil
            self.wake(reason: reason)
        }
    }

    private func wake(reason: String) {
        guard isNapping else { return }
        isNapping = false
        synth?.send(.bed(lastBed))
        ensureRunning(reason: reason)
    }

    // MARK: - Session and graph

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            record("Couldn't set the audio category", error)
        }
        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(0.005)
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            record("Couldn't activate the audio session", error)
        }
    }

    /// Source node → main mixer → output, mono Float32 at the session rate (the mixer converts on route changes).
    private func buildGraph() {
        let session = AVAudioSession.sharedInstance()
        let sampleRate = session.sampleRate > 0 ? session.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            lastError = "Couldn't make a \(Int(sampleRate)) Hz format"
            Self.log.error("Couldn't make an audio format")
            return
        }
        let synth = FeelSynth(sampleRate: Float(sampleRate))
        let node = AVAudioSourceNode(format: format, renderBlock: Self.renderBlock(for: synth))
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
        synth.send(.bed(lastBed))
        self.synth = synth
        sourceNode = node

        if let engineObserver { NotificationCenter.default.removeObserver(engineObserver) }
        engineObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureRunning(reason: "audio hardware changed")
                self?.refreshRoute()
            }
        }
    }

    /// Built outside the main actor on purpose: the block runs on the real-time audio thread and touches only the
    /// synth (an `@unchecked Sendable` object whose render path is lock-free and allocation-free).
    private nonisolated static func renderBlock(for synth: FeelSynth) -> AVAudioSourceNodeRenderBlock {
        return { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let first = buffers.first, let data = first.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            synth.render(frames: Int(frameCount), into: data)
            if buffers.count > 1 {
                for index in 1..<buffers.count {
                    buffers[index].mData?.copyMemory(from: data, byteCount: Int(first.mDataByteSize))
                }
            }
            return noErr
        }
    }

    private func startEngine(reason: String) {
        guard sourceNode != nil, enabled else { return }
        do {
            try engine.start()
            startFailures = 0
        } catch {
            startFailures += 1
            record("Couldn't start the audio engine (\(reason), try \(startFailures))", error)
            if startFailures == 2 {
                // Let the mixer → output connection renegotiate the hardware format, then try once more.
                engine.disconnectNodeOutput(engine.mainMixerNode)
                engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
                do {
                    try engine.start()
                    startFailures = 0
                } catch {
                    startFailures += 1
                    record("Couldn't start the audio engine after reconnecting", error)
                }
            } else if startFailures >= 4 {
                let now = CACurrentMediaTime()
                if now - lastRebuild > 5 {
                    lastRebuild = now
                    startFailures = 0
                    rebuild()
                }
            }
        }
    }

    private func ensureRunning(reason: String) {
        // A napping engine stays paused through route and configuration changes; a sound wakes it.
        guard isStarted, enabled, !isNapping else { return }
        if synth == nil {
            rebuild()
            return
        }
        guard !engine.isRunning else { return }
        activateSession()
        startEngine(reason: reason)
    }

    /// The audio server restarted (or the engine kept failing): every audio object is dead, so start from scratch.
    private func rebuild() {
        guard isStarted else { return }
        if let engineObserver {
            NotificationCenter.default.removeObserver(engineObserver)
            self.engineObserver = nil
        }
        engine = AVAudioEngine()
        synth = nil
        sourceNode = nil
        lastRenderCount = -1
        renderStalls = 0
        configureSession()
        activateSession()
        buildGraph()
        if !isNapping { startEngine(reason: "rebuild") }
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let reasonRaw = notification.userInfo?[AVAudioSessionInterruptionReasonKey] as? UInt
            let reason = reasonRaw.flatMap { AVAudioSession.InterruptionReason(rawValue: $0) }
            let ended = type == .ended
            let began = type == .began
            MainActor.assumeIsolated {
                if began { self?.interruptionBegan(reason: reason) }
                if ended { self?.resume() }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureRunning(reason: "route changed")
                self?.refreshRoute()
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuild()
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.silenceSecondaryAudioHintNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshOtherAudio()
            }
        })
    }

    private func record(_ what: String, _ error: Error) {
        let nsError = error as NSError
        let message = "\(what): \(nsError.localizedDescription) (code \(nsError.code))"
        lastError = message
        Self.log.error("\(message, privacy: .public)")
    }
}
