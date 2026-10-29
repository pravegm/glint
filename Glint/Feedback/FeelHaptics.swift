import CoreHaptics
import Foundation
import os
import QuartzCore
import UIKit

/// One haptic note: a transient tap or a short continuous buzz (times relative to the cue's start).
struct FeelHapticNote: Sendable, Equatable {
    enum Kind: Sendable, Equatable { case transient, continuous }
    var kind: Kind
    var time: Double
    var intensity: Float
    var sharpness: Float
    var duration: Double

    static func tap(_ intensity: Float, _ sharpness: Float, at time: Double = 0) -> FeelHapticNote {
        FeelHapticNote(kind: .transient, time: time, intensity: intensity, sharpness: sharpness, duration: 0)
    }

    static func buzz(_ intensity: Float, _ sharpness: Float, at time: Double = 0, duration: Double) -> FeelHapticNote {
        FeelHapticNote(kind: .continuous, time: time, intensity: intensity, sharpness: sharpness, duration: duration)
    }
}

/// One point of an intensity-control curve.
struct FeelHapticPoint: Sendable, Equatable {
    var time: Double
    var value: Float
}

/// A haptic cue: notes plus an optional intensity-control curve (ramps and fades).
struct FeelHapticCue: Sendable, Equatable {
    var notes: [FeelHapticNote]
    /// Intensity-control points (time, 0…1 multiplier) applied across the cue (≤ 16); empty = none.
    var curve: [FeelHapticPoint]

    init(notes: [FeelHapticNote], curve: [FeelHapticPoint] = []) {
        self.notes = notes
        self.curve = curve
    }

    /// The end of the last note (s).
    var length: Double {
        notes.map { $0.time + $0.duration }.max() ?? 0
    }
}

/// Normal or Strong haptics (Swoop Round 3). Strong is the Duo default: the founder found the Duo's Taptic Engine weak
/// (Squish, real Duo), so Strong layers a short, rounder burst under every tap and lifts the continuous textures.
/// Off is `FeedbackDirector.hapticsOn = false`.
enum FeelHapticProfile: String, Codable, CaseIterable, Sendable {
    case off, normal, strong

    /// The default before the player chooses: Strong on a phone with a fold (a hinge was seen), Normal elsewhere.
    static func defaultFor(hasFold: Bool) -> FeelHapticProfile {
        hasFold ? .strong : .normal
    }
}

/// The haptic vocabulary of Glint (GAME-DESIGN §9). Pure data, so it is testable.
enum FeelHapticBook {
    // MARK: The Strong profile (Hush R12)

    static let strongContinuousGain: Float = 1.4
    static let strongBurst: Double = 0.04
    static let strongBurstSharpness: Float = 0.5
    static let strongBurstGain: Float = 0.7
    static let strongTapGain: Float = 1.15

    /// A cue in the given profile: Normal (and Off, which never plays) unchanged; Strong keeps every tap (× 1.15) and
    /// layers a 40 ms rounder burst under it, and lifts buzzes × 1.4. The curve is kept.
    static func adapt(_ cue: FeelHapticCue, to profile: FeelHapticProfile) -> FeelHapticCue {
        guard profile == .strong else { return cue }
        var notes: [FeelHapticNote] = []
        notes.reserveCapacity(cue.notes.count * 2)
        for note in cue.notes {
            switch note.kind {
            case .transient:
                notes.append(.tap(min(note.intensity * strongTapGain, 1), note.sharpness, at: note.time))
                notes.append(.buzz(min(note.intensity * strongBurstGain, 1), min(note.sharpness, strongBurstSharpness),
                                   at: note.time, duration: strongBurst))
            case .continuous:
                notes.append(.buzz(min(note.intensity * strongContinuousGain, 1), note.sharpness, at: note.time,
                                   duration: note.duration))
            }
        }
        return FeelHapticCue(notes: notes, curve: cue.curve)
    }

    /// R5 (QA-R5 P2-12): the cue held back by `delay` s (every note and curve point), so on a Bluetooth route a pop is
    /// felt when it is heard. Non-positive or non-finite delays return the cue unchanged.
    static func delayed(_ cue: FeelHapticCue, by delay: Double) -> FeelHapticCue {
        guard delay.isFinite, delay > 0.0005 else { return cue }
        var notes = cue.notes
        for index in notes.indices { notes[index].time += delay }
        var curve = cue.curve
        for index in curve.indices { curve[index].time += delay }
        return FeelHapticCue(notes: notes, curve: curve)
    }

    // MARK: The continuous sizzle texture (what's burning, under your fingers)

    /// The texture's intensity for a sizzle level (`FeelSoundBook.sizzleLevel`): nothing under 0.02, then
    /// 0.12 + 0.5 × level; Strong × 1.4 (clamped).
    static func sizzleLevel(_ sizzle: Double, profile: FeelHapticProfile) -> Float {
        guard sizzle.isFinite, sizzle > 0.02 else { return 0 }
        let level = Float(0.12 + 0.5 * FeelMath.clamp01(sizzle))
        switch profile {
        case .off: return 0
        case .normal: return level
        case .strong: return min(level * strongContinuousGain, 1)
        }
    }

    /// The texture's sharpness: 0.35 (a fresh shadow, a soft fizz) … 0.75 (about to pop, keen).
    static let sizzleSharpnessLow: Float = 0.35
    static let sizzleSharpnessHigh: Float = 0.75
    static func sizzleSharpness(heat: Double) -> Float {
        sizzleSharpnessLow + (sizzleSharpnessHigh - sizzleSharpnessLow) * Float(FeelMath.clamp01(heat))
    }

    /// R2 (cloud shadows): the lowest sharpness a muffled sizzle reaches (a dull, rounded fizz).
    static let sizzleSharpnessFloor: Float = 0.15
    /// R2: the sharpness with the shade's muffle: down by up to 0.25, never under `sizzleSharpnessFloor`.
    static func sizzleSharpness(heat: Double, muffle: Double) -> Float {
        max(sizzleSharpness(heat: heat) - 0.25 * Float(FeelMath.clamp01(muffle)), sizzleSharpnessFloor)
    }

    /// R2: a muffled sizzle is felt softer (× 0.65 at full muffle).
    static func muffledIntensity(_ muffle: Double) -> Float {
        1 - 0.35 * Float(FeelMath.clamp01(muffle))
    }

    /// R2: a cloud's shadow slides onto the band: a faint, slow, dull swell (the "cool hush").
    static let coolHush = FeelHapticCue(notes: [.buzz(0.2, 0.15, duration: 0.45)],
                                        curve: [FeelHapticPoint(time: 0, value: 0), FeelHapticPoint(time: 0.2, value: 1),
                                                FeelHapticPoint(time: 0.45, value: 0)])

    /// ± jitter on every send while sizzling (intensity as a fraction, sharpness absolute): the crackle you feel.
    static let sizzleIntensityJitter: Float = 0.3
    static let sizzleSharpnessJitter: Float = 0.08

    /// The firefly alarm: a light, keen flutter while a firefly scorches (nothing under 0.05).
    static func alarmLevel(_ danger: Double, profile: FeelHapticProfile) -> Float {
        guard profile != .off, danger.isFinite, danger > 0.05 else { return 0 }
        let level = Float(0.1 + 0.25 * FeelMath.clamp01(danger))
        return profile == .strong ? min(level * strongContinuousGain, 1) : level
    }

    // MARK: Pops

    /// A pop's tap intensity by size (wisp 0.45 … brute 1.0).
    static func popIntensity(_ kind: GloomKind) -> Float {
        switch kind {
        case .wisp: return 0.45
        case .murk: return 0.65
        case .splitter: return 0.7
        case .hopper: return 0.7
        case .brute: return 1.0
        }
    }

    /// A pop's sharpness: small ones crisp, the brute rounder; a long chain gets a touch keener.
    static func popSharpness(_ kind: GloomKind, chain: Int) -> Float {
        let base: Float
        switch kind {
        case .wisp: base = 0.95
        case .murk: base = 0.8
        case .splitter: base = 0.8
        case .hopper: base = 0.85
        case .brute: base = 0.55
        }
        return min(base + 0.01 * Float(min(max(chain, 0), 10)), 1)
    }

    /// The notes of one pop at `time`: a sharp tap by size; bigger glooms add a short thump under it.
    static func popNotes(kind: GloomKind, chain: Int, at time: Double) -> [FeelHapticNote] {
        var notes: [FeelHapticNote] = [.tap(popIntensity(kind), popSharpness(kind, chain: chain), at: time)]
        switch kind {
        case .brute:
            notes.append(.buzz(0.6, 0.3, at: time, duration: 0.09))
            notes.append(.tap(0.5, 0.4, at: time + 0.06))
        case .splitter, .hopper, .murk:
            notes.append(.buzz(0.25, 0.5, at: time, duration: 0.03))
        case .wisp:
            break
        }
        return notes
    }

    /// Every pop of a frame in one pattern, on the sound's own staggered times (so the run is felt in step).
    static func pops(_ items: [(kind: GloomKind, chain: Int, delay: Double)]) -> FeelHapticCue {
        var notes: [FeelHapticNote] = []
        for item in items.prefix(12) {
            notes.append(contentsOf: popNotes(kind: item.kind, chain: item.chain, at: max(item.delay, 0)))
        }
        return FeelHapticCue(notes: notes)
    }

    // MARK: Moments

    /// "Sweep!": a fast rising roll and a swell.
    static func sweep(delay: Double = 0) -> FeelHapticCue {
        let t = max(delay, 0)
        return FeelHapticCue(
            notes: [.tap(0.5, 0.9, at: t), .tap(0.65, 0.9, at: t + 0.035), .tap(0.8, 0.95, at: t + 0.07),
                    .buzz(0.4, 0.6, at: t + 0.08, duration: 0.18)],
            curve: [FeelHapticPoint(time: 0, value: 1), FeelHapticPoint(time: t + 0.09, value: 1),
                    FeelHapticPoint(time: t + 0.26, value: 0)]
        )
    }

    /// The sweep growing: one more crisp tick.
    static func sweepRung(delay: Double = 0) -> FeelHapticCue {
        FeelHapticCue(notes: [.tap(0.45, 1.0, at: max(delay, 0))])
    }

    static let split = FeelHapticCue(notes: [.tap(0.35, 1.0, at: 0.05), .tap(0.3, 1.0, at: 0.085)])
    static let hop = FeelHapticCue(notes: [.tap(0.3, 0.6), .tap(0.25, 0.3, at: 0.22)])
    static let bruteEmerged = FeelHapticCue(notes: [.tap(0.25, 0.2)])
    /// R3: a gloom surfaces: the faintest round tick (a brute's a touch firmer). A flock: two soft ticks.
    static func surfaced(_ kind: GloomKind) -> FeelHapticCue {
        FeelHapticCue(notes: [.tap(kind == .brute ? 0.26 : 0.18, 0.3)])
    }
    static let surfaceChord = FeelHapticCue(notes: [.tap(0.22, 0.3), .tap(0.18, 0.3, at: 0.05)])
    static let fireflyArrived = FeelHapticCue(notes: [.tap(0.2, 1.0)])
    /// A firefly fizzles: two soft falling taps and a faint fade.
    static let fizzle = FeelHapticCue(notes: [.tap(0.45, 0.5), .tap(0.3, 0.3, at: 0.09),
                                              .buzz(0.2, 0.2, at: 0.1, duration: 0.12)],
                                      curve: [FeelHapticPoint(time: 0, value: 1), FeelHapticPoint(time: 0.1, value: 1),
                                              FeelHapticPoint(time: 0.22, value: 0)])
    /// A firefly delivered: a bright double tap and a little bloom swell (a replant swells longer).
    static func delivered(replanted: Bool) -> FeelHapticCue {
        let swell = replanted ? 0.3 : 0.15
        return FeelHapticCue(
            notes: [.tap(0.4, 0.9), .tap(0.55, 0.95, at: 0.08), .buzz(0.3, 0.5, at: 0.1, duration: swell)],
            curve: [FeelHapticPoint(time: 0, value: 0.3), FeelHapticPoint(time: 0.1 + swell * 0.5, value: 1),
                    FeelHapticPoint(time: 0.1 + swell, value: 0)]
        )
    }
    /// A flower eaten: the heaviest hit of the game, a fading shudder and a second knock.
    static let flowerEaten = FeelHapticCue(
        notes: [.tap(1.0, 0.35), .buzz(0.95, 0.15, duration: 0.28), .tap(0.7, 0.2, at: 0.12)],
        curve: [FeelHapticPoint(time: 0, value: 1), FeelHapticPoint(time: 0.1, value: 0.85),
                FeelHapticPoint(time: 0.28, value: 0)]
    )
    static let chainLost = FeelHapticCue(notes: [.tap(0.4, 1.0), .tap(0.2, 1.0, at: 0.06)])
    /// The first light: a soft swell.
    static let dawn = FeelHapticCue(notes: [.buzz(0.3, 0.4, duration: 0.5)],
                                    curve: [FeelHapticPoint(time: 0, value: 0), FeelHapticPoint(time: 0.3, value: 1),
                                            FeelHapticPoint(time: 0.5, value: 0)])
    /// Sunrise: a climbing ripple, then a warm swell.
    static let sunrise = FeelHapticCue(
        notes: [.tap(0.4, 0.6), .tap(0.5, 0.7, at: 0.1), .tap(0.65, 0.8, at: 0.2), .tap(0.8, 0.9, at: 0.3),
                .tap(1.0, 0.95, at: 0.42), .buzz(0.5, 0.4, at: 0.45, duration: 0.6)],
        curve: [FeelHapticPoint(time: 0, value: 1), FeelHapticPoint(time: 0.5, value: 1),
                FeelHapticPoint(time: 1.05, value: 0)]
    )
    /// The night wins: one low knock and a long fading rumble.
    static let nightWins = FeelHapticCue(notes: [.tap(0.8, 0.2), .buzz(0.8, 0.1, duration: 1.2)],
                                         curve: [FeelHapticPoint(time: 0, value: 1),
                                                 FeelHapticPoint(time: 1.2, value: 0)])
    static let waveUp = FeelHapticCue(notes: [.tap(0.6, 0.4), .tap(0.45, 0.5, at: 0.18)])

    // MARK: UI

    static func ui(_ cue: UICue) -> FeelHapticCue {
        switch cue {
        case .tap: return FeelHapticCue(notes: [.tap(0.35, 0.7)])
        case .back: return FeelHapticCue(notes: [.tap(0.3, 0.5), .tap(0.2, 0.5, at: 0.05)])
        case .toggle: return FeelHapticCue(notes: [.tap(0.4, 0.8), .tap(0.25, 0.9, at: 0.05)])
        case .star(let n):
            let k = Float(min(max(n, 1), 3))
            return FeelHapticCue(notes: [.tap(0.45 + 0.15 * k, 0.8), .buzz(0.2 + 0.1 * k, 0.5, at: 0.01, duration: 0.08)])
        case .unlock:
            return FeelHapticCue(notes: [.tap(0.4, 0.7), .tap(0.5, 0.8, at: 0.06), .tap(0.6, 0.9, at: 0.12),
                                         .tap(0.75, 0.95, at: 0.18), .tap(0.9, 0.6, at: 0.32)])
        case .levelStart:
            return FeelHapticCue(notes: [.buzz(0.3, 0.4, duration: 0.35), .tap(0.4, 0.7, at: 0.3)],
                                 curve: [FeelHapticPoint(time: 0, value: 0), FeelHapticPoint(time: 0.3, value: 1),
                                         FeelHapticPoint(time: 0.35, value: 0)])
        }
    }
}

/// Core Haptics for Glint: two looping advanced players carry the continuous feel (the sizzle texture and the firefly
/// alarm, steered by dynamic parameters at ≤ 30 Hz with ramps, so there is no zipper), and every moment plays as its
/// own short pattern. Self-healing after stops and server resets (Squish's/Brim's/Swoop's/Hush's pattern). Phones
/// without Core Haptics (and the simulator) fall back to `UIImpactFeedbackGenerator` for the moments, or do nothing.
@MainActor
final class FeelHaptics {
    private static let log = Logger(subsystem: "com.pravegm.glint", category: "haptics")

    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled {
                guard wantsStart else { return }
                if engine == nil { start() } else { restart() }
            } else {
                // Switched off mid-session: the hardware goes to sleep at once.
                setContinuous(sizzle: 0, sharpness: 0.4, alarm: 0, now: CACurrentMediaTime(), force: true)
                stopPlayers()
                if let engine, isRunning { engine.stop(completionHandler: nil) }
                isRunning = false
            }
        }
    }

    /// Normal or Strong (Off is `enabled = false`, set by the director).
    var profile: FeelHapticProfile = .normal

    /// Menus and long pauses: no looping players, and the engine may shut the hardware down by itself. A cue still
    /// plays (the engine is started again for it). Off: the players are rebuilt at once.
    var idle = false {
        didSet {
            guard oldValue != idle else { return }
            if idle {
                stopPlayers()
                engine?.isAutoShutdownEnabled = true
            } else {
                engine?.isAutoShutdownEnabled = false
                if engine != nil && (!isRunning || sizzlePlayer == nil) { restart() }
            }
        }
    }

    private let supportsHaptics: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var sizzlePlayer: CHHapticAdvancedPatternPlayer?
    private var alarmPlayer: CHHapticAdvancedPatternPlayer?
    private var isRunning = false
    /// R5: an asynchronous start is in flight.
    private var starting = false
    /// R5: the last cue asked for while the engine was starting (played on start if under `pendingLife` s old).
    private var pendingCue: FeelHapticCue?
    private var pendingAt: CFTimeInterval = 0
    static let pendingLife: Double = 0.2
    private var wantsStart = false
    private var lastRecovery: CFTimeInterval = 0
    private var lastSend: CFTimeInterval = 0
    private var lastSizzle: Float = 0
    private var lastSharpness: Float = 0.4
    private var lastAlarm: Float = 0
    private var dice = FeelDice(seed: 0x474C_494E)
    private var fallbackLight: UIImpactFeedbackGenerator?
    private var fallbackMedium: UIImpactFeedbackGenerator?
    private var fallbackHeavy: UIImpactFeedbackGenerator?
    private(set) var lastError: String?

    init() {}

    /// Idempotent. Does nothing while haptics are off (it starts when they are switched on).
    func start() {
        wantsStart = true
        guard enabled else { return }
        guard supportsHaptics else {
            prepareFallback()
            return
        }
        guard engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = idle
            // Both handlers arrive on an engine-internal queue: hop to the main actor.
            engine.stoppedHandler = { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.sizzlePlayer = nil
                    self.alarmPlayer = nil
                }
            }
            engine.resetHandler = { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.isRunning = false
                    self.sizzlePlayer = nil
                    self.alarmPlayer = nil
                    self.restart()
                }
            }
            self.engine = engine
            restart()
        } catch {
            record("Couldn't create the haptic engine", error)
            engine = nil
        }
    }

    /// The app became active again: the system stops the engine on suspension.
    func resume() {
        guard supportsHaptics, enabled, wantsStart else { return }
        if engine == nil {
            start()
        } else if !isRunning || (!idle && sizzlePlayer == nil) {
            restart()
        }
    }

    /// Throttled recovery from the frame loop.
    func heal() {
        guard enabled, engine != nil, !isRunning || (!idle && sizzlePlayer == nil) else { return }
        guard UIApplication.shared.applicationState != .background else { return }
        restart()
    }

    /// R5 (QA-R5 P2-6): the engine starts **asynchronously** (`start(completionHandler:)`), so a wake never blocks the
    /// frame that asked for it; the looping players are built when it reports back, on their own main-actor turn.
    private func restart() {
        guard enabled, let engine, !starting else { return }
        starting = true
        engine.start(completionHandler: { [weak self] (error: Error?) in
            guard let self else { return }
            Task { @MainActor in
                self.didStart(error: error)
            }
        })
    }

    private func didStart(error: Error?) {
        starting = false
        guard enabled, engine != nil else {
            pendingCue = nil
            return
        }
        if let error {
            isRunning = false
            pendingCue = nil
            record("Couldn't start the haptic engine", error)
            return
        }
        isRunning = true
        sizzlePlayer = nil
        alarmPlayer = nil
        // Menus have nothing burning: no looping players to keep the hardware awake.
        if !idle {
            do {
                sizzlePlayer = try makeLoopingPlayer(sharpness: 0.4)
                alarmPlayer = try makeLoopingPlayer(sharpness: 0.9)
                lastSizzle = 0
                lastAlarm = 0
            } catch {
                record("Couldn't build the continuous haptics", error)
            }
        }
        // A moment asked for while the engine was coming up plays now, if it is still fresh.
        if let cue = pendingCue {
            pendingCue = nil
            if CACurrentMediaTime() - pendingAt <= Self.pendingLife { play(cue) }
        }
    }

    private func stopPlayers() {
        if let player = sizzlePlayer { try? player.stop(atTime: CHHapticTimeImmediate) }
        if let player = alarmPlayer { try? player.stop(atTime: CHHapticTimeImmediate) }
        sizzlePlayer = nil
        alarmPlayer = nil
        lastSizzle = 0
        lastAlarm = 0
    }

    /// One looping continuous event at intensity 1; the intensity control scales it (starts at 0).
    private func makeLoopingPlayer(sharpness: Float) throws -> CHHapticAdvancedPatternPlayer? {
        guard let engine else { return nil }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: 30
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makeAdvancedPlayer(with: pattern)
        player.loopEnabled = true
        let zero = [CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)]
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        try player.start(atTime: CHHapticTimeImmediate)
        try player.sendParameters(zero, atTime: CHHapticTimeImmediate)
        return player
    }

    // MARK: - Per frame

    /// The continuous feel: call every frame with what's burning (`FeelBurn`); `FeelBurn.zero` fades it out. Sends at most ~30
    /// times a second, ramping between values (no zipper); while sizzling every send carries a little intensity and
    /// sharpness jitter (the crackle you feel).
    func update(burn: FeelBurn, now: CFTimeInterval) {
        var sizzle: Float = 0
        var sharpness = lastSharpness
        var alarm: Float = 0
        if enabled {
            sizzle = FeelHapticBook.sizzleLevel(burn.level, profile: profile)
                * FeelHapticBook.muffledIntensity(burn.muffle)
            alarm = FeelHapticBook.alarmLevel(burn.danger, profile: profile)
            if sizzle > 0 { sharpness = FeelHapticBook.sizzleSharpness(heat: burn.heat, muffle: burn.muffle) }
        }
        setContinuous(sizzle: sizzle, sharpness: sharpness, alarm: alarm, now: now, force: false)
    }

    /// Fade the continuous feel to nothing.
    func quiet(now: CFTimeInterval) {
        setContinuous(sizzle: 0, sharpness: lastSharpness, alarm: 0, now: now, force: false)
    }

    private func setContinuous(sizzle: Float, sharpness: Float, alarm: Float, now: CFTimeInterval, force: Bool) {
        guard isRunning, let sizzlePlayer else { return }
        let silencing = (sizzle == 0 && lastSizzle > 0) || (alarm == 0 && lastAlarm > 0)
        // While sizzling every send is a little different (the jitter), so it sends at the full 30 Hz.
        let changed = sizzle > 0 || alarm > 0
        guard force || silencing || changed else { return }
        guard force || silencing || now - lastSend >= 1.0 / 30 else { return }
        lastSend = now
        var intensity = sizzle
        var keen = sharpness
        if sizzle > 0 {
            intensity = min(max(sizzle * (1 + FeelHapticBook.sizzleIntensityJitter * Float(dice.range(-1, 1))), 0), 1)
            keen = min(max(sharpness + FeelHapticBook.sizzleSharpnessJitter * Float(dice.range(-1, 1)),
                           FeelHapticBook.sizzleSharpnessFloor), FeelHapticBook.sizzleSharpnessHigh)
        }
        // The alarm flutters: every other send dips, so a scorching firefly feels like a trembling wing.
        var flutter = alarm
        if alarm > 0 && dice.unit() < 0.5 { flutter = alarm * 0.35 }
        let ramp: TimeInterval = silencing ? 0.06 : 1.0 / 30
        schedule(sizzlePlayer, from: lastSizzle, to: intensity, ramp: ramp)
        // Sharpness control is an offset from the event's 0.4.
        try? sizzlePlayer.sendParameters([CHHapticDynamicParameter(parameterID: .hapticSharpnessControl,
                                                                   value: keen - 0.4, relativeTime: 0)],
                                         atTime: CHHapticTimeImmediate)
        if let alarmPlayer {
            schedule(alarmPlayer, from: lastAlarm, to: flutter, ramp: ramp)
        }
        lastSizzle = intensity
        lastSharpness = keen
        lastAlarm = flutter
    }

    private func schedule(_ player: CHHapticAdvancedPatternPlayer, from start: Float, to end: Float,
                          ramp: TimeInterval) {
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: start),
                CHHapticParameterCurve.ControlPoint(relativeTime: ramp, value: end),
            ],
            relativeTime: 0
        )
        try? player.scheduleParameterCurve(curve, atTime: CHHapticTimeImmediate)
    }

    // MARK: - Moments

    func play(_ cue: FeelHapticCue) {
        guard enabled, !cue.notes.isEmpty else { return }
        guard supportsHaptics else {
            playFallback(cue)
            return
        }
        if !isRunning || engine == nil || starting {
            // R5: the engine comes up asynchronously; keep this cue to play when it does (if still fresh).
            let now = CACurrentMediaTime()
            pendingCue = cue
            pendingAt = now
            if now - lastRecovery > 0.5 {
                lastRecovery = now
                resume()
            }
            return
        }
        guard let engine else { return }
        do {
            let player = try engine.makePlayer(with: try Self.pattern(for: cue))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            record("Couldn't play a haptic", error)
        }
    }

    /// The Core Haptics pattern for a cue.
    private static func pattern(for cue: FeelHapticCue) throws -> CHHapticPattern {
        let events: [CHHapticEvent] = cue.notes.map { (note: FeelHapticNote) -> CHHapticEvent in
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(note.intensity, 0), 1))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(note.sharpness, 0), 1))
            switch note.kind {
            case .transient:
                return CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness],
                                     relativeTime: note.time)
            case .continuous:
                return CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness],
                                     relativeTime: note.time, duration: max(note.duration, 0.01))
            }
        }
        var curves: [CHHapticParameterCurve] = []
        if !cue.curve.isEmpty {
            var points: [CHHapticParameterCurve.ControlPoint] = []
            for point in cue.curve.prefix(16) {
                points.append(CHHapticParameterCurve.ControlPoint(relativeTime: point.time, value: point.value))
            }
            curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points,
                                                 relativeTime: 0))
        }
        return try CHHapticPattern(events: events, parameterCurves: curves)
    }

    // MARK: - Fallback (no Core Haptics)

    private func prepareFallback() {
        if fallbackLight == nil { fallbackLight = UIImpactFeedbackGenerator(style: .light) }
        if fallbackMedium == nil { fallbackMedium = UIImpactFeedbackGenerator(style: .medium) }
        if fallbackHeavy == nil { fallbackHeavy = UIImpactFeedbackGenerator(style: .heavy) }
        fallbackLight?.prepare()
        fallbackMedium?.prepare()
        fallbackHeavy?.prepare()
    }

    /// Up to three notes of the cue as impacts (a buzz plays as one impact at its start). Notes within 5 ms of the one
    /// before count once (Strong's tap-plus-burst pairs are one hit).
    private func playFallback(_ cue: FeelHapticCue) {
        prepareFallback()
        var notes: [FeelHapticNote] = []
        for note in cue.notes.sorted(by: { $0.time < $1.time }) {
            if let last = notes.last, note.time - last.time < 0.005 { continue }
            notes.append(note)
            if notes.count == 3 { break }
        }
        for note in notes {
            let intensity = CGFloat(min(max(note.intensity, 0.05), 1))
            let generator: UIImpactFeedbackGenerator?
            if note.intensity >= 0.75 {
                generator = fallbackHeavy
            } else if note.intensity >= 0.4 {
                generator = fallbackMedium
            } else {
                generator = fallbackLight
            }
            guard let generator else { continue }
            if note.time <= 0.005 {
                generator.impactOccurred(intensity: intensity)
            } else {
                let delay = UInt64(note.time * 1_000_000_000)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: delay)
                    generator.impactOccurred(intensity: intensity)
                }
            }
        }
    }

    private func record(_ what: String, _ error: Error) {
        let nsError = error as NSError
        let message = "\(what): \(nsError.localizedDescription) (code \(nsError.code))"
        lastError = message
        Self.log.error("\(message, privacy: .public)")
    }
}
