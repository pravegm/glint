import Foundation
import QuartzCore
import UIKit

/// The menu sounds the App asks for (ARCHITECTURE "Feedback API").
enum UICue: Equatable {
    case tap, back, toggle
    /// The n-th star (1…3) landing on the results card.
    case star(Int)
    case unlock
    case levelStart
}

/// Audio + haptics for Glint (GAME-DESIGN §9). The App calls `start()` once at launch, sets the toggles from its
/// SettingsStore, then every game frame calls `handle(_:snapshot:)` (the frame's events) and `frame(snapshot:dt:)`.
/// Everything audible is synthesised in real time (`FeelSynth`); every touch is Core Haptics (`FeelHaptics`).
///
/// Per frame it builds one small value (`FeelBed`: the sizzle, the kettle, the firefly alarm, the band air, the dawn
/// pad), pushes it into a lock-free queue (≤ 60 Hz) and steers the two looping haptic players (≤ 30 Hz: the sizzle
/// texture and the alarm flutter). Events map (`FeelCueMap`) to short recipes from `FeelSoundBook` and
/// `FeelHapticBook`; pops on one frame are spaced into a rising run (`FeelPopSequencer`).
///
/// `soundOn` gates every sound but the pad; `musicOn` gates the dawn pad; `hapticsOn` gates every touch.
/// Battery: after `idleDelay` s with no play, no events and no UI cue the engines idle (the haptic players stop, the
/// audio engine naps once quiet). If the frames stop without a `setPaused(true)` (the app went away), a watchdog fades
/// the continuous layers after `staleAfter` s, so nothing can be left sizzling. Nothing here can crash or block when
/// audio or haptics are unavailable (simulator, CI): failures are logged and the game goes quiet.
@MainActor
final class FeedbackDirector {
    static let shared = FeedbackDirector()

    /// Seconds without play (and without events) before the engines idle.
    static let idleDelay: Double = 3
    /// Seconds without a `frame` or `ambience` call after which the continuous layers fade by themselves.
    static let staleAfter: Double = 0.25
    /// Throttles for the frequent quiet cues (s).
    static let emergeGap: Double = 0.15
    static let hopGap: Double = 0.1
    static let fireflyGap: Double = 0.3

    /// Sound effects on/off (Settings › Sound). The dawn pad follows `musicOn`.
    var soundOn: Bool = true {
        didSet {
            guard oldValue != soundOn else { return }
            refreshAudioEnabled()
        }
    }

    /// The dawn pad on/off (Settings › Music).
    var musicOn: Bool = true {
        didSet {
            guard oldValue != musicOn else { return }
            refreshAudioEnabled()
        }
    }

    /// Haptics on/off (Settings). Turning it on restores the last profile, or the device default.
    var hapticsOn: Bool {
        get { profile != .off }
        set {
            if !newValue {
                applyProfile(.off)
            } else if profile == .off {
                applyProfile(profileChosen ? lastOnProfile : FeelHapticProfile.defaultFor(hasFold: deviceHasFold))
            }
        }
    }

    /// Additive: Normal or Strong haptics. Setting it counts as the player's choice; until then the profile follows
    /// the device (`deviceHasFold`: Strong on a Duo, whose Taptic Engine is weak).
    var hapticProfile: FeelHapticProfile {
        get { profile }
        set {
            profileChosen = true
            applyProfile(newValue)
        }
    }

    /// Additive: the App sets this once a hinge has been seen (a Duo). It moves an unchosen profile to Strong.
    var deviceHasFold: Bool = false {
        didSet {
            guard oldValue != deviceHasFold, !profileChosen, profile != .off else { return }
            applyProfile(FeelHapticProfile.defaultFor(hasFold: deviceHasFold))
        }
    }

    /// Additive: menus. The engines may nap once quiet; a UI cue or `ambience(sun:)` still plays (it wakes them).
    var idle: Bool = false {
        didSet {
            guard oldValue != idle else { return }
            refreshIdle(now: CACurrentMediaTime())
        }
    }

    /// True while `setPaused(true)` holds.
    private(set) var paused = false

    private let audio = FeelAudioEngine()
    private let haptics = FeelHaptics()
    private var started = false
    private var activationObserver: NSObjectProtocol?
    private var dice = FeelDice(seed: 0x474C_494E_5421)
    private var profile: FeelHapticProfile = .normal
    private var lastOnProfile: FeelHapticProfile = .normal
    private var profileChosen = false

    private var lastBedSend: CFTimeInterval = -Double.infinity
    private var lastHeal: CFTimeInterval = 0
    private var lastActive: CFTimeInterval = -Double.infinity
    private var lastFrame: CFTimeInterval = -Double.infinity
    private var audioIdle = false
    private var hapticIdle = false
    private var continuousLive = false
    private var watchdogPending = false

    private var popSequencer = FeelPopSequencer()
    // Literals (= `emergeGap`, `hopGap`, `fireflyGap`): plain default values.
    private var emergeThrottle = FeelThrottle(gap: 0.15)
    private var hopThrottle = FeelThrottle(gap: 0.1)
    private var fireflyThrottle = FeelThrottle(gap: 0.3)
    /// R2: clouds that have slid onto the band (the cool hush).
    private var shadeWatcher = FeelShadeWatcher()
    /// R3: groups surfacings (one bloop, then one chord for a flock).
    private var surfaceGate = FeelSurfaceGate()
    /// The pad brightness of the last game bed (a pause keeps it).
    private var lastPadBright: Float = 0.06
    /// Glooms on the last frame (sunrise evaporates them silently: the ripple counts them).
    private var lastGloomCount = 0
    /// The phase on the last frame (a phase change glides the bed slower).
    private var lastPhase: SessionPhase = .waiting

    /// Diagnostics: pops sounded and pops dropped by the sequencer.
    private(set) var popsPlayed = 0
    private(set) var popsDropped = 0

    init() {
        // Menus play before any game frame: start from an audible, empty bed (a master of 0 mutes one-shots too).
        audio.setBed(FeelSoundBook.idleBed(master: master))
    }

    private var master: Float { (soundOn || musicOn) ? FeelSoundBook.masterGain : 0 }

    /// Audio session (`.playback`, `.mixWithOthers`) and engines. Safe to call more than once; also called lazily by
    /// the first sound.
    func start() {
        guard !started else { return }
        started = true
        audio.enabled = soundOn || musicOn
        haptics.enabled = profile != .off
        if profile != .off { haptics.profile = profile }
        audio.start()
        haptics.start()
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.audio.resume()
                self?.haptics.resume()
            }
        }
    }

    // MARK: - Per frame

    /// The frame's events (call once per frame, before `frame(snapshot:dt:)`; an empty list is cheap).
    func handle(_ events: [GameEvent], snapshot: DawnSnapshot) {
        guard !events.isEmpty else { return }
        ensureStarted()
        let now = CACurrentMediaTime()
        lastActive = now
        refreshIdle(now: now)
        let cues = FeelCueMap.cues(for: events)
        guard !cues.isEmpty else { return }

        // Pops first, as one staggered run (sound and haptic in step).
        var pops: [(kind: GloomKind, chain: Int, delay: Double)] = []
        var runEnd = 0.0
        var lossDelay: Float = 0
        for cue in cues {
            guard case .pop(let kind, let chain) = cue else { continue }
            guard let delay = popSequencer.slot(at: now) else {
                popsDropped += 1
                continue
            }
            let index = pops.count
            pops.append((kind: kind, chain: chain, delay: delay))
            runEnd = max(runEnd, delay)
            popsPlayed += 1
            if soundOn {
                audio.play(FeelSoundBook.pop(kind: kind, chain: chain, scale: FeelPopSequencer.scale(index: index),
                                             delay: Float(delay), sparkles: FeelPopSequencer.sparkles(index: index),
                                             dice: &dice))
            }
        }
        if !pops.isEmpty { playHaptic(FeelHapticBook.pops(pops)) }

        for cue in cues {
            switch cue {
            case .pop:
                break // played above
            case .emerge(let kind):
                guard emergeThrottle.allow(at: now) else { break }
                playSound(FeelSoundBook.emerge(kind: kind, dice: &dice))
                if kind == .brute { playHaptic(FeelHapticBook.bruteEmerged) }
            case .surface(let kind):
                switch surfaceGate.next(at: now) {
                case .bloop:
                    playSound(FeelSoundBook.bloop(kind: kind, dice: &dice))
                    playHaptic(FeelHapticBook.surfaced(kind))
                case .chord(let count):
                    playSound(FeelSoundBook.surfaceChord(count: count, dice: &dice))
                    playHaptic(FeelHapticBook.surfaceChord)
                case .quiet:
                    break
                }
            case .sweep(let count):
                // With the pop that made it (the run's last slot so far).
                let at = Float(runEnd)
                if count <= 3 {
                    playSound(FeelSoundBook.sweepStab(delay: at, dice: &dice))
                    playHaptic(FeelHapticBook.sweep(delay: runEnd))
                } else {
                    playSound(FeelSoundBook.sweepRung(count: count, delay: at, dice: &dice))
                    playHaptic(FeelHapticBook.sweepRung(delay: runEnd))
                }
            case .split:
                playSound(FeelSoundBook.split(delay: Float(runEnd), dice: &dice))
                playHaptic(FeelHapticBook.split)
            case .hop(let skittish):
                guard hopThrottle.allow(at: now) else { break }
                playSound(FeelSoundBook.hop(skittish: skittish, dice: &dice))
                playHaptic(FeelHapticBook.hop)
            case .fireflyArrived:
                guard fireflyThrottle.allow(at: now) else { break }
                playSound(FeelSoundBook.fireflyArrived(dice: &dice))
                playHaptic(FeelHapticBook.fireflyArrived)
            case .fizzle:
                playSound(FeelSoundBook.fizzle(dice: &dice))
                playHaptic(FeelHapticBook.fizzle)
                lossDelay = max(lossDelay, 0.3)
            case .delivered(let replanted):
                playSound(FeelSoundBook.delivered(replanted: replanted, dice: &dice))
                playHaptic(FeelHapticBook.delivered(replanted: replanted))
            case .flowerEaten:
                playSound(FeelSoundBook.flowerEaten(dice: &dice))
                playHaptic(FeelHapticBook.flowerEaten)
                lossDelay = max(lossDelay, 0.4)
            case .chainLost:
                // After the loss that broke it.
                let delay = max(lossDelay, 0.3)
                playSound(FeelSoundBook.chainLost(delay: delay, dice: &dice))
                playHaptic(FeelHapticBook.chainLost)
            case .dawn:
                playSound(FeelSoundBook.dawn())
                playHaptic(FeelHapticBook.dawn)
            case .sunrise(let stars):
                popSequencer.reset()
                playSound(FeelSoundBook.sunrise(stars: stars, ripple: lastGloomCount, dice: &dice))
                playHaptic(FeelHapticBook.sunrise)
            case .nightWins:
                popSequencer.reset()
                playSound(FeelSoundBook.nightWins())
                playHaptic(FeelHapticBook.nightWins)
            case .waveUp(let wave):
                playSound(FeelSoundBook.waveUp(wave))
                playHaptic(FeelHapticBook.waveUp)
            }
        }
        scheduleWatchdog()
    }

    /// The continuous layers for this frame: the sizzle (sound and haptic texture), the firefly alarm, the band air
    /// and the dawn pad. Call every game frame with the frame's `dt` (0 while the driver holds the session).
    func frame(snapshot: DawnSnapshot, dt: Double) {
        ensureStarted()
        let now = CACurrentMediaTime()
        lastFrame = now
        let advancing = dt.isFinite && dt > 0
        let live = advancing && !paused && snapshot.phase == .playing
        if live { lastActive = now }
        refreshIdle(now: now)
        heal(now: now)

        let phaseChanged = snapshot.phase != lastPhase
        lastPhase = snapshot.phase
        if now - lastBedSend >= 1.0 / 60 || phaseChanged {
            lastBedSend = now
            var bed = FeelSoundBook.playBed(snapshot: snapshot, sound: soundOn, music: musicOn, paused: paused,
                                            advancing: advancing)
            if phaseChanged { bed.glide = FeelSoundBook.fadeGlide }
            if bed.pad > 0 { lastPadBright = bed.padBright }
            audio.setBed(bed)
            continuousLive = true
        }
        let burn = live ? FeelSoundBook.burn(of: snapshot) : FeelBurn.zero
        haptics.update(burn: burn, now: now)
        // R2: a cloud's shadow slides onto the band: the cool hush (once per cloud, only while live).
        let hush = shadeWatcher.update(shades: snapshot.shades, phase: snapshot.phase, live: live,
                                       sessionTime: snapshot.time, now: now)
        if hush {
            playSound(FeelSoundBook.coolHush(dice: &dice))
            playHaptic(FeelHapticBook.coolHush)
        }
        lastGloomCount = snapshot.glooms.count
        scheduleWatchdog()
    }

    /// Paused (phone shut, app inactive, the pause menu): the sizzle, the alarm and the air fade out, the pad drops to
    /// half. Un-pausing lets the next `frame` bring them back.
    func setPaused(_ paused: Bool) {
        guard paused != self.paused else { return }
        self.paused = paused
        let now = CACurrentMediaTime()
        if paused {
            var bed = FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide)
            if musicOn {
                bed.pad = Float(FeelSoundBook.pausedPadShare)
                bed.padBright = lastPadBright
            }
            audio.setBed(bed)
            haptics.quiet(now: now)
            popSequencer.reset()
            // Count the quiet from now (a pause right after a game frame still waits the full delay).
            lastActive = now
            scheduleIdleCheck()
        } else {
            lastActive = now
            refreshIdle(now: now)
        }
    }

    /// Additive: the menus' music. Call every menu frame (the attract garden behind Home) with a sun for the pad's
    /// brightness; only the dawn pad plays (`musicOn`), softer. Stop calling it and the watchdog fades it.
    func ambience(sun: Double) {
        ensureStarted()
        let now = CACurrentMediaTime()
        lastFrame = now
        heal(now: now)
        if now - lastBedSend >= 1.0 / 30 {
            lastBedSend = now
            audio.setBed(FeelSoundBook.menuBed(sun: sun, master: master, music: musicOn))
            continuousLive = true
        }
        haptics.quiet(now: now)
        scheduleWatchdog()
    }

    /// Additive: fade every continuous layer out now (leaving play for the menus). One-shots already ringing play out.
    func silence() {
        let now = CACurrentMediaTime()
        audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide))
        haptics.quiet(now: now)
        continuousLive = false
        popSequencer.reset()
        lastActive = now
        scheduleIdleCheck()
    }

    // MARK: - Menu sounds

    func ui(_ cue: UICue) {
        ensureStarted()
        let now = CACurrentMediaTime()
        lastActive = now
        refreshIdle(now: now)
        playSound(FeelSoundBook.ui(cue, dice: &dice))
        playHaptic(FeelHapticBook.ui(cue))
    }

    // MARK: - Helpers

    private func ensureStarted() {
        if !started { start() }
    }

    private func playSound(_ commands: [FeelSynthCommand]) {
        guard soundOn, !commands.isEmpty else { return }
        audio.play(commands)
    }

    private func playHaptic(_ cue: FeelHapticCue) {
        guard profile != .off else { return }
        haptics.play(FeelHapticBook.adapt(cue, to: profile))
    }

    private func refreshAudioEnabled() {
        audio.enabled = soundOn || musicOn
        audio.setBed(FeelSoundBook.idleBed(master: master))
    }

    private func applyProfile(_ newProfile: FeelHapticProfile) {
        profile = newProfile
        if newProfile != .off {
            lastOnProfile = newProfile
            haptics.profile = newProfile
        }
        haptics.enabled = newProfile != .off
    }

    private func heal(now: CFTimeInterval) {
        guard now - lastHeal > 1 else { return }
        lastHeal = now
        if !audioIdle { audio.heal() }
        if !hapticIdle { haptics.heal() }
    }

    /// Menus (`idle`) or a long quiet idle the engines.
    private func refreshIdle(now: CFTimeInterval) {
        let quiet = now - lastActive > Self.idleDelay
        let wantIdle = idle || quiet
        if wantIdle != audioIdle {
            audioIdle = wantIdle
            audio.idle = wantIdle
        }
        if wantIdle != hapticIdle {
            hapticIdle = wantIdle
            if wantIdle { haptics.quiet(now: now) }
            haptics.idle = wantIdle
        }
    }

    /// After a pause no frames may come (a pause card, the menus): idle once the delay has passed.
    private func scheduleIdleCheck() {
        let delay = Self.idleDelay + 0.05
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.refreshIdle(now: CACurrentMediaTime())
        }
    }

    /// Frames stopped without a pause: fade the continuous layers so nothing is left sizzling.
    private func scheduleWatchdog() {
        guard !watchdogPending else { return }
        watchdogPending = true
        let delay = Self.staleAfter
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.watchdog()
        }
    }

    private func watchdog() {
        watchdogPending = false
        guard continuousLive else { return }
        let now = CACurrentMediaTime()
        if now - lastFrame >= Self.staleAfter {
            continuousLive = false
            audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide))
            haptics.quiet(now: now)
            refreshIdle(now: now)
        } else {
            scheduleWatchdog()
        }
    }
}
