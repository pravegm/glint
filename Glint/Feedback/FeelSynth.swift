import Foundation
import Synchronization

// MARK: - Commands (main thread → audio thread)
//
// Every payload is a plain value (Floats, Ints, enums without payloads), so copying a command never touches ARC and
// the audio thread can read it from the lock-free queue without allocating or locking. Machinery copied from Hush's
// FeelSynth (itself from Swoop, Brim and Squish); the continuous layers are Glint's.

enum FeelFilterMode: Sendable, Equatable {
    case lowPass, bandPass, highPass
}

/// Partial tables for struck resonators.
enum FeelRingKind: Sendable, Equatable {
    /// A soft, nearly pure bell (harmonic partials 1, 2, 3, 4.2 … rolled off hard).
    case chime
    /// Inharmonic church-bell partials (prime, hum an octave down, minor-third tierce, quint, nominal).
    case bell
    /// A marimba bar (1, 3.93, 9.3 …): soft UI notes.
    case marimba
    /// A wooden tick: clicks, crunches, knocks.
    case wood
    /// Glassy, sparse, bright: glints, sparkles.
    case glass
    /// A plucked string (harmonic, a touch stiff): the pop ladder.
    case pluck
}

/// A one-shot filtered-noise burst (puffs, whooshes, crunches), optionally sweeping its cutoff.
struct FeelNoiseSpec: Sendable, Equatable {
    var mode: FeelFilterMode
    var cutoff: Float
    var cutoffEnd: Float
    var sweep: Float
    var q: Float
    var attack: Float
    /// Exponential decay time constant (s).
    var decay: Float
    var gain: Float
    var delay: Float

    init(_ mode: FeelFilterMode, cutoff: Float, to cutoffEnd: Float? = nil, sweep: Float = 0, q: Float = 0.8,
         attack: Float = 0.002, decay: Float, gain: Float, delay: Float = 0) {
        self.mode = mode
        self.cutoff = cutoff
        self.cutoffEnd = cutoffEnd ?? cutoff
        self.sweep = sweep
        self.q = q
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// A pitched tone with a glide, vibrato and a 1/n harmonic stack (bodies, chords, chirps).
struct FeelToneSpec: Sendable, Equatable {
    var start: Float
    var end: Float
    var glide: Float
    var duration: Float
    var attack: Float
    var decay: Float
    var gain: Float
    var harmonics: Int
    var vibratoRate: Float
    var vibratoDepth: Float
    var delay: Float

    init(start: Float, end: Float? = nil, glide: Float = 0.1, duration: Float, attack: Float = 0.01, decay: Float,
         gain: Float, harmonics: Int = 1, vibratoRate: Float = 0, vibratoDepth: Float = 0, delay: Float = 0) {
        self.start = start
        self.end = end ?? start
        self.glide = glide
        self.duration = duration
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.harmonics = harmonics
        self.vibratoRate = vibratoRate
        self.vibratoDepth = vibratoDepth
        self.delay = delay
    }
}

/// A struck modal resonator: up to `FeelSynth.maxPartials` decaying sinusoids.
struct FeelRingSpec: Sendable, Equatable {
    var kind: FeelRingKind
    var fundamental: Float
    var partials: Int
    /// Decay time constant of the first partial (s); higher partials decay faster.
    var decay: Float
    /// Amplitude roll-off per partial, 0…1 (higher = brighter).
    var brightness: Float
    var gain: Float
    var delay: Float
    /// Seeds a ±1.5 % partial detune so two strikes never sound identical.
    var seed: UInt32

    init(_ kind: FeelRingKind, fundamental: Float, partials: Int = 4, decay: Float, brightness: Float = 0.5,
         gain: Float, delay: Float = 0, seed: UInt32 = 1) {
        self.kind = kind
        self.fundamental = fundamental
        self.partials = partials
        self.decay = decay
        self.brightness = brightness
        self.gain = gain
        self.delay = delay
        self.seed = seed
    }
}

/// A bubble (Minnaert): a decaying sine whose pitch chirps (> 1 rises, < 1 falls). The heart of every pop.
struct FeelDropSpec: Sendable, Equatable {
    var frequency: Float
    /// Pitch ratio reached by the end of the pop (> 1 rises).
    var chirp: Float
    var decay: Float
    var gain: Float
    var delay: Float

    init(frequency: Float, chirp: Float = 1.5, decay: Float, gain: Float, delay: Float = 0) {
        self.frequency = frequency
        self.chirp = chirp
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// A two-operator FM tone: a sine carrier phase-modulated by a sine at `ratio` × the carrier, whose index decays
/// faster than the tone. Inharmonic ratios make metal: glints and clinks.
struct FeelFMSpec: Sendable, Equatable {
    var carrier: Float
    var ratio: Float
    /// Peak modulation index (radians).
    var index: Float
    /// Time constant (s) of the index's decay.
    var indexDecay: Float
    var attack: Float
    var decay: Float
    var gain: Float
    var delay: Float

    init(carrier: Float, ratio: Float, index: Float, indexDecay: Float, attack: Float = 0.0008, decay: Float,
         gain: Float, delay: Float = 0) {
        self.carrier = carrier
        self.ratio = ratio
        self.index = index
        self.indexDecay = indexDecay
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.delay = delay
    }
}

/// Glint's continuous layers (sent every frame, glided per sample on the audio thread). GAME-DESIGN §9.
struct FeelBed: Sendable, Equatable {
    /// Master gain (0 = silent).
    var master: Float = 0
    /// Time constant (s) of the glide from the current layers to this bed (frames: ~0.05; fades: ~0.35).
    var glide: Float = 0.05

    // The sizzle: what's burning (hiss + fry + crackle), plus the "about to pop" kettle whistle.
    /// 0…1 sizzle level (total burn rate).
    var sizzle: Float = 0
    /// The hiss's band centre (Hz): rises as the lit glooms' HP falls.
    var sizzleHz: Float = 1800
    /// Crackles per second.
    var crackleRate: Float = 0
    /// R2 (cloud shadows): 0…1 how muffled the sizzle is (the burning is under a cloud's shade): a 24 dB low-pass
    /// closing from 14 kHz (0, open) to 600 Hz (1), so a shaded burn sounds smothered instead of cutting out.
    var sizzleMuffle: Float = 0
    /// 0…1 kettle whistle (only when something lit is nearly popped).
    var kettle: Float = 0
    var kettleHz: Float = 1200

    // A firefly is in the light: a soft trembling whimper.
    var alarm: Float = 0
    var alarmHz: Float = 1400

    // The band moving: a soft air tone (very quiet).
    var air: Float = 0
    var airHz: Float = 600

    // Music: the dawn pad (a C major add-6/9 pad that brightens with the sun) and its rare high twinkles.
    var pad: Float = 0
    /// 0…1: night (dark, few voices) … sunrise (open filter, every voice).
    var padBright: Float = 0
    /// Twinkles per second.
    var twinkleRate: Float = 0

    /// True when any continuous layer is audible (the engine stays awake for it).
    var hasLayers: Bool {
        let zero: Float = 0
        if sizzle > zero || kettle > zero || alarm > zero { return true }
        return air > zero || pad > zero || twinkleRate > zero
    }

    mutating func approach(_ target: FeelBed, _ k: Float) {
        master += (target.master - master) * k
        sizzle += (target.sizzle - sizzle) * k
        sizzleHz += (target.sizzleHz - sizzleHz) * k
        crackleRate += (target.crackleRate - crackleRate) * k
        sizzleMuffle += (target.sizzleMuffle - sizzleMuffle) * k
        kettle += (target.kettle - kettle) * k
        kettleHz += (target.kettleHz - kettleHz) * k
        alarm += (target.alarm - alarm) * k
        alarmHz += (target.alarmHz - alarmHz) * k
        air += (target.air - air) * k
        airHz += (target.airHz - airHz) * k
        pad += (target.pad - pad) * k
        padBright += (target.padBright - padBright) * k
        twinkleRate += (target.twinkleRate - twinkleRate) * k
    }
}

enum FeelSynthCommand: Sendable, Equatable {
    case bed(FeelBed)
    case noise(FeelNoiseSpec)
    case tone(FeelToneSpec)
    case ring(FeelRingSpec)
    case drop(FeelDropSpec)
    case fm(FeelFMSpec)
    /// Stop every one-shot voice and the continuous layers' grain state now (sound switched off, an interruption).
    case stopAll

    /// Peak gain parameter (0 for `bed`/`stopAll`), for tests.
    var gain: Float {
        switch self {
        case .noise(let spec): return spec.gain
        case .tone(let spec): return spec.gain
        case .ring(let spec): return spec.gain
        case .drop(let spec): return spec.gain
        case .fm(let spec): return spec.gain
        case .bed, .stopAll: return 0
        }
    }

    /// When the voice starts (s after the command), for tests.
    var delay: Float {
        switch self {
        case .noise(let spec): return spec.delay
        case .tone(let spec): return spec.delay
        case .ring(let spec): return spec.delay
        case .drop(let spec): return spec.delay
        case .fm(let spec): return spec.delay
        case .bed, .stopAll: return 0
        }
    }

    /// The command's lowest sounding pitch (Hz; 0 for noise, bed and stopAll), for tests.
    var pitch: Float {
        switch self {
        case .tone(let spec): return min(spec.start, spec.end)
        case .ring(let spec): return spec.kind == .bell ? spec.fundamental * 0.5 : spec.fundamental
        case .drop(let spec): return spec.chirp < 1 ? spec.frequency * spec.chirp : spec.frequency
        case .fm(let spec): return spec.carrier
        case .noise, .bed, .stopAll: return 0
        }
    }
}

// MARK: - DSP building blocks (audio thread)

/// Topology-preserving state-variable filter (Zavalishin), from Squish/Brim/Swoop/Hush. Band-pass normalised to 0 dB
/// at centre.
private struct FeelSVF {
    var a1: Float = 0, a2: Float = 0, a3: Float = 0, k: Float = 1
    var ic1: Float = 0, ic2: Float = 0

    mutating func tune(cutoff: Float, q: Float, sampleRate: Float) {
        let f = min(max(cutoff, 20), sampleRate * 0.45)
        let g = tan(Float.pi * f / sampleRate)
        k = 1 / max(q, 0.1)
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
    }

    mutating func process(_ x: Float, _ mode: FeelFilterMode) -> Float {
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        switch mode {
        case .lowPass: return v2
        case .bandPass: return v1 * k
        case .highPass: return x - k * v1 - v2
        }
    }
}

private enum FeelVoiceKind {
    case noise, tone, ring, drop, fm
}

private struct FeelVoice {
    var active = false
    var kind: FeelVoiceKind = .noise
    var delay = 0
    var age = 0
    var attack = 1
    var length = 0
    var decayRate: Float = 1
    var level: Float = 1
    var gain: Float = 0
    // Noise.
    var filter = FeelSVF()
    var mode: FeelFilterMode = .bandPass
    var q: Float = 1
    var cutoff: Float = 1000
    var cutoffEnd: Float = 1000
    var sweepSamples = 0
    // Tone, drop and FM.
    var phase: Float = 0
    var frequency: Float = 0
    var startFrequency: Float = 0
    var endFrequency: Float = 0
    var glide = 1
    var harmonics = 1
    var vibratoPhase: Float = 0
    var vibratoRate: Float = 0
    var vibratoDepth: Float = 0
    var chirpPerSample: Float = 1
    // FM.
    var modPhase: Float = 0
    var modRatio: Float = 1
    var index: Float = 0
    var indexRate: Float = 1
    // Ring (its partial state lives in the synth's bank at this voice's slot).
    var partialCount = 0
}

// MARK: - Synth

/// Glint's real-time synth, rendered inside an `AVAudioSourceNode` (mono Float32). The machinery is Hush's (lock-free
/// command queue, voice pool, modal bank, limiter); the continuous layers are Glint's: the sizzle, the kettle, the
/// firefly alarm, the band air and the dawn pad.
///
/// Threading: the main thread calls `send` (single producer); the audio thread calls `render` (single consumer).
/// Commands cross through a fixed-capacity single-producer/single-consumer ring whose two indices are atomics
/// (acquire/release), so the render path takes no locks, never allocates and never touches ARC.
/// Master chain: DC blocker → peak-follower limiter (ceiling 0.9) → tanh soft clip, so the output can never clip.
final class FeelSynth: @unchecked Sendable {
    let sampleRate: Float

    /// A sweep of ten pops (each up to ~12 voices, staggered over 0.4 s) plus a sweep stab must never steal.
    static let voiceCount = 160
    static let maxPartials = 6
    static let queueCapacity = 1_024
    static let ceiling: Float = 0.9
    /// A struck ring holds its slot for this many time constants of its first partial.
    static let ringLife: Float = 5
    private static let partialStride = 5 // re, im, cos, sin, decay
    /// Below this a continuous layer is skipped entirely.
    private static let quiet: Float = 0.00002

    // Layer mixes (before the bed's level and the master). Node probe (design/notes/feel-R1.md), pre-limiter RMS at
    // the 1.8 master: a pop's first 80 ms −15 dBFS; the sizzle −30 (one gloom) … −24.5 (a crowd about to pop); the
    // pad −35 (night) … −29 (sunrise); the band air −40 at its loudest.
    static let hissGain: Float = 0.09
    static let fryGain: Float = 0.04
    static let crackleGain: Float = 0.35
    static let kettleGain: Float = 0.03
    static let alarmGain: Float = 0.035
    static let airGain: Float = 0.05
    static let padGain: Float = 0.014
    static let twinkleGain: Float = 0.014
    /// The pad: six notes, two detuned saws each.
    static let padNotes = 6
    static let padOscillators = 12

    private let queue: UnsafeMutablePointer<FeelSynthCommand>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(0)
    private let peakBits = Atomic<UInt32>(0)
    private let renderCount = Atomic<Int>(0)
    private let stealCount = Atomic<Int>(0)
    private let liveCount = Atomic<Int>(0)

    // Audio-thread-only state below.
    private let voices: UnsafeMutablePointer<FeelVoice>
    private let bank: UnsafeMutablePointer<Float>
    private let padPhase: UnsafeMutablePointer<Float>
    private let padStep: UnsafeMutablePointer<Float>
    private var bed = FeelBed()
    private var target = FeelBed()
    private var glideK: Float = 0
    private var noiseState: UInt32 = 0x2545_F491
    private var retuneCounter = 0

    // Sizzle.
    private var hissFilter = FeelSVF()
    private var fryFilter = FeelSVF()
    private var crackleFilter = FeelSVF()
    private var muffleFilterA = FeelSVF()
    private var muffleFilterB = FeelSVF()
    private var crackleEnv: Float = 0
    private var flutter: Float = 0.5
    private var flutterTarget: Float = 0.5
    private var flutterCountdown = 0
    // Kettle.
    private var kettlePhase: Float = 0
    private var kettleVibrato: Float = 0
    private var kettleFilter = FeelSVF()
    // Alarm.
    private var alarmPhase: Float = 0
    private var alarmTremolo: Float = 0
    // Air.
    private var airFilter = FeelSVF()
    // Pad.
    private var padFilterA = FeelSVF()
    private var padFilterB = FeelSVF()
    private var padLFO: Float = 0
    private var twinkleCounter: UInt32 = 0
    // Master.
    private var dcIn: Float = 0
    private var dcOut: Float = 0
    private var envelope: Float = 0

    private let flutterStep: Float
    private let crackleDecay: Float
    private let envelopeRelease: Float
    private let dcCoefficient: Float

    init(sampleRate: Float) {
        let rate: Float = sampleRate > 1000 ? sampleRate : 48_000
        self.sampleRate = rate
        queue = UnsafeMutablePointer<FeelSynthCommand>.allocate(capacity: FeelSynth.queueCapacity)
        queue.initialize(repeating: .stopAll, count: FeelSynth.queueCapacity)
        voices = UnsafeMutablePointer<FeelVoice>.allocate(capacity: FeelSynth.voiceCount)
        voices.initialize(repeating: FeelVoice(), count: FeelSynth.voiceCount)
        let bankSize = FeelSynth.voiceCount * FeelSynth.maxPartials * FeelSynth.partialStride
        bank = UnsafeMutablePointer<Float>.allocate(capacity: bankSize)
        bank.initialize(repeating: 0, count: bankSize)
        let phases = UnsafeMutablePointer<Float>.allocate(capacity: FeelSynth.padOscillators)
        phases.initialize(repeating: 0, count: FeelSynth.padOscillators)
        let steps = UnsafeMutablePointer<Float>.allocate(capacity: FeelSynth.padOscillators)
        steps.initialize(repeating: 0, count: FeelSynth.padOscillators)
        for index in 0..<FeelSynth.padOscillators {
            let detune: Float = index % 2 == 0 ? 0.9965 : 1.0035
            steps[index] = FeelSynth.padHz(index / 2) * detune / rate
            // Spread the starting phases so the pad doesn't open with a click of aligned saws.
            let spread: Float = Float(index) * 0.137
            phases[index] = spread - spread.rounded(.down)
        }
        padPhase = phases
        padStep = steps
        glideK = 1 - exp(-1 / (0.05 * rate))
        flutterStep = 1 - exp(-1 / (0.002 * rate))
        crackleDecay = exp(-1 / (0.0015 * rate))
        envelopeRelease = exp(-1 / (0.08 * rate))
        dcCoefficient = 1 - 2 * Float.pi * 30 / rate
        tuneFixedFilters()
        retuneContinuous()
    }

    deinit {
        queue.deinitialize(count: FeelSynth.queueCapacity)
        queue.deallocate()
        voices.deinitialize(count: FeelSynth.voiceCount)
        voices.deallocate()
        bank.deallocate()
        padPhase.deallocate()
        padStep.deallocate()
    }

    // MARK: Main thread

    /// Queue a command (main thread only). Returns false if the queue is full (the command is dropped, never blocks).
    @discardableResult
    func send(_ command: FeelSynthCommand) -> Bool {
        let write = writeIndex.load(ordering: .relaxed)
        let next = (write + 1) % FeelSynth.queueCapacity
        guard next != readIndex.load(ordering: .acquiring) else { return false }
        queue[write] = command
        writeIndex.store(next, ordering: .releasing)
        return true
    }

    /// Loudest output sample so far (linear), for tests and diagnostics.
    var peak: Float { Float(bitPattern: peakBits.load(ordering: .relaxed)) }

    /// Render callbacks so far: if it stops climbing, the engine isn't pulling audio.
    var renderCallbacks: Int { renderCount.load(ordering: .relaxed) }

    /// One-shot voices started while every slot was busy (each one cut a sounding voice), for tests and diagnostics.
    var voiceSteals: Int { stealCount.load(ordering: .relaxed) }

    /// One-shot voices holding a slot (sounding or still waiting out their delay) at the end of the last render.
    var liveVoices: Int { liveCount.load(ordering: .relaxed) }

    // MARK: Audio thread

    func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        drain()
        var blockPeak: Float = 0
        for frame in 0..<frames {
            bed.approach(target, glideK)
            retuneCounter += 1
            if retuneCounter >= 32 {
                retuneCounter = 0
                retuneContinuous()
            }

            var sample: Float = 0
            if bed.sizzle > FeelSynth.quiet {
                sample += renderSizzle()
            } else {
                crackleEnv = 0
            }
            if bed.kettle > FeelSynth.quiet {
                sample += renderKettle()
            }
            if bed.alarm > FeelSynth.quiet {
                sample += renderAlarm()
            }
            if bed.air > FeelSynth.quiet {
                sample += airFilter.process(nextNoise(), .bandPass) * FeelSynth.airGain * bed.air
            }
            if bed.pad > FeelSynth.quiet {
                sample += renderPad()
            }
            if bed.twinkleRate > 0.001, unitNoise() < bed.twinkleRate / sampleRate {
                startTwinkle()
            }
            for index in 0..<FeelSynth.voiceCount where voices[index].active {
                sample += renderVoice(&voices[index], slot: index)
            }
            sample *= bed.master

            // DC blocker (30 Hz), then a peak follower that keeps the drive at or below the ceiling, then tanh.
            let blocked = sample - dcIn + dcCoefficient * dcOut
            dcIn = sample
            dcOut = blocked
            let magnitude = abs(blocked)
            envelope = max(magnitude, envelope * envelopeRelease)
            let drive = envelope > FeelSynth.ceiling ? FeelSynth.ceiling / envelope : 1
            var shaped = tanh(blocked * drive)
            if !shaped.isFinite {
                shaped = 0
                resetFilters()
            }
            shaped = min(max(shaped, -0.98), 0.98)
            blockPeak = max(blockPeak, abs(shaped))
            out[frame] = shaped
        }
        let previous = Float(bitPattern: peakBits.load(ordering: .relaxed))
        if blockPeak > previous { peakBits.store(blockPeak.bitPattern, ordering: .relaxed) }
        var live = 0
        for index in 0..<FeelSynth.voiceCount where voices[index].active { live += 1 }
        liveCount.store(live, ordering: .relaxed)
        renderCount.store(renderCount.load(ordering: .relaxed) &+ 1, ordering: .relaxed)
    }

    // MARK: The sizzle

    /// What's burning (GAME-DESIGN §9): three parts that follow the bed per sample.
    /// - the **hiss**: noise through a band whose centre rises as the lit glooms weaken (1.5 → 5 kHz), its level
    ///   fluttering on a fast random walk (4–16 ms steps): fat in a pan;
    /// - the **fry**: the top end (> 6 kHz) gated by the same flutter, squared, so it spits;
    /// - the **crackle**: random 1.5 ms impulses at `crackleRate`, each through its own resonant band (1.8–5.3 kHz).
    private func renderSizzle() -> Float {
        flutterCountdown -= 1
        if flutterCountdown <= 0 {
            flutterTarget = 0.25 + 0.75 * unitNoise()
            flutterCountdown = Int(sampleRate * (0.004 + 0.012 * unitNoise())) + 1
        }
        flutter += (flutterTarget - flutter) * flutterStep
        let hiss = hissFilter.process(nextNoise(), .bandPass) * FeelSynth.hissGain * (0.6 + 0.4 * flutter)
        let fry = fryFilter.process(nextNoise(), .highPass) * FeelSynth.fryGain * flutter * flutter
        if bed.crackleRate > 0.01, unitNoise() < bed.crackleRate / sampleRate {
            crackleEnv = 0.35 + 0.65 * unitNoise()
            crackleFilter.tune(cutoff: 1800 + 3500 * unitNoise(), q: 1.5, sampleRate: sampleRate)
        }
        crackleEnv *= crackleDecay
        var crackle: Float = 0
        if crackleEnv > 0.0005 {
            crackle = crackleFilter.process(nextNoise() * crackleEnv, .bandPass) * FeelSynth.crackleGain
        }
        let mix = hiss + fry + crackle
        // R2: under a cloud's shade the burn is smothered (low-passed), not cut. Always in the path (14 kHz when open,
        // nearly transparent), so the filter never switches in with a click.
        let muffled = muffleFilterB.process(muffleFilterA.process(mix, .lowPass), .lowPass)
        return muffled * bed.sizzle
    }

    /// R2: the muffle's low-pass cutoff (Hz) for a muffle amount: 14 kHz open … 600 Hz fully shaded (log sweep).
    static func muffleCutoff(_ muffle: Float) -> Float {
        let m = min(max(muffle, 0), 1)
        return 14_000 * pow(600.0 / 14_000.0, m)
    }

    /// The kettle: a breathy whistle (a sine plus noise through a narrow band at the same pitch) with a 5.5 Hz
    /// vibrato, riding the sizzle's flutter. It only sounds when something lit is close to popping.
    private func renderKettle() -> Float {
        let twoPi = 2 * Float.pi
        kettleVibrato += twoPi * 5.5 / sampleRate
        if kettleVibrato > twoPi { kettleVibrato -= twoPi }
        let f = min(max(bed.kettleHz, 200), sampleRate * 0.4) * (1 + 0.012 * sin(kettleVibrato))
        kettlePhase += twoPi * f / sampleRate
        if kettlePhase > twoPi { kettlePhase -= twoPi }
        let breath = kettleFilter.process(nextNoise(), .bandPass) * 1.2
        return (sin(kettlePhase) * 0.6 + breath) * FeelSynth.kettleGain * bed.kettle * (0.7 + 0.3 * flutter)
    }

    /// The firefly alarm: a soft sine whimper with an 8 Hz tremolo and a slow pitch waver.
    private func renderAlarm() -> Float {
        let twoPi = 2 * Float.pi
        alarmTremolo += twoPi * 8 / sampleRate
        if alarmTremolo > twoPi { alarmTremolo -= twoPi }
        let f = min(max(bed.alarmHz, 200), sampleRate * 0.4) * (1 + 0.02 * sin(alarmTremolo * 0.5))
        alarmPhase += twoPi * f / sampleRate
        if alarmPhase > twoPi { alarmPhase -= twoPi }
        let tremolo: Float = 0.5 + 0.5 * sin(alarmTremolo)
        let voice = sin(alarmPhase) + 0.2 * sin(2 * alarmPhase)
        return voice * tremolo * FeelSynth.alarmGain * bed.alarm
    }

    // MARK: The dawn pad

    /// The pad's notes (Hz): C3 G3 C4 E4 A4 D5 (C major with the 6th and 9th, the pentatonic's colour). A switch, not
    /// an array: no lazy global initialisation on the audio thread.
    static func padHz(_ note: Int) -> Float {
        switch note {
        case 0: return 130.81
        case 1: return 196.00
        case 2: return 261.63
        case 3: return 329.63
        case 4: return 440.00
        default: return 587.33
        }
    }

    /// How much of each pad note sounds at a brightness (0 night … 1 sunrise): the root and fifth always, the middle
    /// warming in, the 6th and the high 9th only as the sun comes up.
    static func padWeight(_ note: Int, bright: Float) -> Float {
        let b = min(max(bright, 0), 1)
        switch note {
        case 0: return 1
        case 1: return 0.8
        case 2: return 0.55 + 0.35 * b
        case 3: return 0.4 + 0.4 * b
        case 4: return 0.6 * b
        default: return 0.5 * b * b
        }
    }

    /// The twinkles' pitches: the C major pentatonic from C6 up (Hz).
    static func twinkleHz(_ index: Int) -> Float {
        switch index % 6 {
        case 0: return 1046.5
        case 1: return 1174.66
        case 2: return 1318.51
        case 3: return 1567.98
        case 4: return 1760.0
        default: return 2093.0
        }
    }

    /// Twelve PolyBLEP saws (six notes, a detuned pair each), through a 24 dB low-pass that opens with the sun
    /// (`retuneContinuous`), breathing on a 0.06 Hz swell.
    private func renderPad() -> Float {
        let twoPi = 2 * Float.pi
        padLFO += twoPi * 0.06 / sampleRate
        if padLFO > twoPi { padLFO -= twoPi }
        let bright = bed.padBright
        var sum: Float = 0
        for index in 0..<FeelSynth.padOscillators {
            let step = padStep[index]
            var p = padPhase[index] + step
            if p >= 1 { p -= 1 }
            padPhase[index] = p
            let weight = FeelSynth.padWeight(index / 2, bright: bright)
            if weight > 0.001 {
                sum += (2 * p - 1 - FeelSynth.polyBlep(p, step)) * weight
            }
        }
        let filtered = padFilterB.process(padFilterA.process(sum, .lowPass), .lowPass)
        let breathe: Float = 0.8 + 0.2 * sin(padLFO)
        return filtered * FeelSynth.padGain * breathe * bed.pad
    }

    /// One soft high glass twinkle on the pentatonic (the pad's dew catching the light).
    private func startTwinkle() {
        twinkleCounter &+= 1
        let pick = Int((unitNoise() * 5.999).rounded(.down))
        let f = FeelSynth.twinkleHz(pick)
        let level = 0.6 + 0.4 * unitNoise()
        start(.ring(FeelRingSpec(.glass, fundamental: f, partials: 2, decay: 0.35 + 0.3 * unitNoise(),
                                 brightness: 0.3, gain: FeelSynth.twinkleGain * level * bed.pad,
                                 seed: twinkleCounter | 1)))
    }

    /// Band-limited step correction for a saw (PolyBLEP), so the pad doesn't alias.
    private static func polyBlep(_ t: Float, _ dt: Float) -> Float {
        guard dt > 0 else { return 0 }
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        }
        if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    // MARK: Plumbing

    private func tuneFixedFilters() {
        fryFilter.tune(cutoff: 6000, q: 0.7, sampleRate: sampleRate)
        crackleFilter.tune(cutoff: 3200, q: 1.5, sampleRate: sampleRate)
    }

    private func retuneContinuous() {
        hissFilter.tune(cutoff: min(max(bed.sizzleHz, 400), 9000), q: 0.7, sampleRate: sampleRate)
        let muffle = FeelSynth.muffleCutoff(bed.sizzleMuffle)
        muffleFilterA.tune(cutoff: muffle, q: 0.6, sampleRate: sampleRate)
        muffleFilterB.tune(cutoff: muffle, q: 0.6, sampleRate: sampleRate)
        kettleFilter.tune(cutoff: min(max(bed.kettleHz, 200), 8000), q: 8, sampleRate: sampleRate)
        airFilter.tune(cutoff: min(max(bed.airHz, 150), 4000), q: 0.6, sampleRate: sampleRate)
        let bright = min(max(bed.padBright, 0), 1)
        let cutoff: Float = 280 + 2600 * pow(bright, 1.4)
        padFilterA.tune(cutoff: cutoff, q: 0.6, sampleRate: sampleRate)
        padFilterB.tune(cutoff: cutoff, q: 0.6, sampleRate: sampleRate)
    }

    private func drain() {
        var read = readIndex.load(ordering: .relaxed)
        let write = writeIndex.load(ordering: .acquiring)
        var handled = 0
        while read != write && handled < 256 {
            let command = queue[read]
            read = (read + 1) % FeelSynth.queueCapacity
            handled += 1
            apply(command)
        }
        readIndex.store(read, ordering: .releasing)
    }

    private func apply(_ command: FeelSynthCommand) {
        switch command {
        case .bed(let params):
            target = params
            let glide = params.glide.isFinite ? max(params.glide, 0.004) : 0.05
            glideK = 1 - exp(-1 / (glide * sampleRate))
        case .stopAll:
            for index in 0..<FeelSynth.voiceCount { voices[index].active = false }
            crackleEnv = 0
        case .noise, .tone, .ring, .drop, .fm:
            start(command)
        }
    }

    private func resetFilters() {
        hissFilter = FeelSVF()
        fryFilter = FeelSVF()
        crackleFilter = FeelSVF()
        muffleFilterA = FeelSVF()
        muffleFilterB = FeelSVF()
        kettleFilter = FeelSVF()
        airFilter = FeelSVF()
        padFilterA = FeelSVF()
        padFilterB = FeelSVF()
        tuneFixedFilters()
        retuneContinuous()
        crackleEnv = 0
        envelope = 0
        dcIn = 0
        dcOut = 0
        for index in 0..<FeelSynth.voiceCount { voices[index].active = false }
    }

    private func nextNoise() -> Float {
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
    }

    private func unitNoise() -> Float {
        (nextNoise() + 1) * 0.5
    }

    private func start(_ command: FeelSynthCommand) {
        var slot = -1
        var oldest = -1
        var oldestAge = -1
        for index in 0..<FeelSynth.voiceCount {
            if !voices[index].active {
                slot = index
                break
            }
            if voices[index].age > oldestAge {
                oldestAge = voices[index].age
                oldest = index
            }
        }
        if slot < 0 {
            slot = oldest
            stealCount.store(stealCount.load(ordering: .relaxed) &+ 1, ordering: .relaxed)
        }
        guard slot >= 0 else { return }
        var voice = FeelVoice()
        voice.active = true
        switch command {
        case .noise(let spec):
            voice.kind = .noise
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 7)
            voice.gain = spec.gain
            voice.mode = spec.mode
            voice.q = spec.q
            voice.cutoff = spec.cutoff
            voice.cutoffEnd = spec.cutoffEnd
            voice.sweepSamples = abs(spec.cutoffEnd - spec.cutoff) > 1 ? max(Int(spec.sweep * sampleRate), 1) : 0
            voice.filter.tune(cutoff: spec.cutoff, q: spec.q, sampleRate: sampleRate)
        case .tone(let spec):
            voice.kind = .tone
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.length = max(Int(spec.duration * sampleRate), voice.attack + 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.gain = spec.gain
            voice.startFrequency = spec.start
            voice.endFrequency = spec.end
            voice.glide = max(Int(spec.glide * sampleRate), 1)
            voice.harmonics = min(max(spec.harmonics, 1), 8)
            voice.vibratoRate = spec.vibratoRate
            voice.vibratoDepth = spec.vibratoDepth
        case .drop(let spec):
            voice.kind = .drop
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0015 * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 6)
            voice.gain = spec.gain
            voice.frequency = min(max(spec.frequency, 40), sampleRate * 0.4)
            voice.chirpPerSample = pow(max(spec.chirp, 0.25), 1 / Float(max(voice.length, 1)))
        case .fm(let spec):
            voice.kind = .fm
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 7)
            voice.gain = spec.gain
            voice.frequency = min(max(spec.carrier, 40), sampleRate * 0.42)
            voice.modRatio = max(spec.ratio, 0.01)
            voice.index = max(spec.index, 0)
            voice.indexRate = exp(-1 / max(spec.indexDecay * sampleRate, 1))
        case .ring(let spec):
            voice.kind = .ring
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0005 * sampleRate), 1)
            voice.decayRate = 1
            voice.length = min(Int(spec.decay * sampleRate * FeelSynth.ringLife), Int(sampleRate * 6))
            voice.gain = 1
            configureRing(spec, slot: slot, voice: &voice)
        case .bed, .stopAll:
            return
        }
        voices[slot] = voice
    }

    private static func ratio(_ kind: FeelRingKind, _ n: Int) -> Float {
        switch kind {
        case .chime:
            switch n {
            case 0: return 1
            case 1: return 2.0
            case 2: return 3.0
            case 3: return 4.2
            case 4: return 5.4
            default: return 6.8
            }
        case .bell:
            switch n {
            case 0: return 1      // prime
            case 1: return 0.5    // hum
            case 2: return 1.19   // tierce (minor third)
            case 3: return 1.5    // quint
            case 4: return 2.0    // nominal
            default: return 2.66
            }
        case .marimba:
            switch n {
            case 0: return 1
            case 1: return 3.93
            case 2: return 9.3
            case 3: return 12.0
            case 4: return 15.2
            default: return 18.6
            }
        case .wood:
            switch n {
            case 0: return 1
            case 1: return 2.6
            case 2: return 3.9
            case 3: return 5.4
            case 4: return 6.9
            default: return 8.6
            }
        case .glass:
            switch n {
            case 0: return 1
            case 1: return 2.32
            case 2: return 4.25
            case 3: return 6.63
            case 4: return 9.38
            default: return 12.1
            }
        case .pluck:
            switch n {
            case 0: return 1
            case 1: return 2.0
            case 2: return 3.005
            case 3: return 4.015
            case 4: return 5.03
            default: return 6.05
            }
        }
    }

    private func configureRing(_ spec: FeelRingSpec, slot: Int, voice: inout FeelVoice) {
        let count = min(max(spec.partials, 1), FeelSynth.maxPartials)
        voice.partialCount = count
        let brightness = min(max(spec.brightness, 0.05), 0.98)
        var total: Float = 0
        for n in 0..<count { total += pow(brightness, Float(n)) }
        var jitter = spec.seed | 1
        let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
        for n in 0..<count {
            jitter ^= jitter << 13
            jitter ^= jitter >> 17
            jitter ^= jitter << 5
            let detune: Float = n == 0 ? 1 : 1 + 0.015 * (Float(jitter % 2001) / 1000 - 1)
            let frequency = spec.fundamental * FeelSynth.ratio(spec.kind, n) * detune
            let offset = base + n * FeelSynth.partialStride
            guard frequency > 20, frequency < sampleRate * 0.45 else {
                bank[offset] = 0
                bank[offset + 1] = 0
                bank[offset + 2] = 1
                bank[offset + 3] = 0
                bank[offset + 4] = 0
                continue
            }
            var tau = spec.decay / (1 + 0.7 * Float(n))
            // A bell's hum (an octave under the prime) is what lingers in a real bell.
            if spec.kind == .bell && n == 1 { tau = spec.decay * 1.3 }
            if frequency > 2500 && frequency < 4500 && n > 0 { tau *= 0.5 } // no lingering screech in the ear's peak
            let omega = 2 * Float.pi * frequency / sampleRate
            bank[offset] = spec.gain * pow(brightness, Float(n)) / total * 1.6
            bank[offset + 1] = 0
            bank[offset + 2] = cos(omega)
            bank[offset + 3] = sin(omega)
            bank[offset + 4] = exp(-1 / max(tau * sampleRate, 1))
        }
    }

    private func renderVoice(_ voice: inout FeelVoice, slot: Int) -> Float {
        if voice.delay > 0 {
            voice.delay -= 1
            return 0
        }
        let age = voice.age
        voice.age += 1
        if age >= voice.length {
            voice.active = false
            return 0
        }
        let envelope: Float
        if age < voice.attack {
            envelope = Float(age) / Float(voice.attack)
        } else {
            voice.level *= voice.decayRate
            envelope = voice.level
        }
        if envelope < 0.0003 && age > voice.attack {
            voice.active = false
            return 0
        }
        // A gentle release over the last 30 ms so nothing ever clicks off.
        let left = voice.length - age
        let release = min(Float(left) / (0.03 * sampleRate), 1)
        let twoPi = 2 * Float.pi
        switch voice.kind {
        case .noise:
            if voice.sweepSamples > 0 && age % 32 == 0 {
                let progress = min(Float(age) / Float(voice.sweepSamples), 1)
                let cutoff = voice.cutoff * pow(voice.cutoffEnd / max(voice.cutoff, 1), progress)
                voice.filter.tune(cutoff: cutoff, q: voice.q, sampleRate: sampleRate)
            }
            return voice.filter.process(nextNoise(), voice.mode) * envelope * voice.gain * release
        case .tone:
            let progress = min(Float(age) / Float(voice.glide), 1)
            var frequency = voice.startFrequency + (voice.endFrequency - voice.startFrequency) * progress
            if voice.vibratoDepth > 0 {
                voice.vibratoPhase += twoPi * voice.vibratoRate / sampleRate
                if voice.vibratoPhase > twoPi { voice.vibratoPhase -= twoPi }
                frequency *= 1 + voice.vibratoDepth * sin(voice.vibratoPhase)
            }
            voice.phase += twoPi * frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            var value: Float = 0
            let limit = sampleRate * 0.45
            var harmonic = 1
            while harmonic <= voice.harmonics {
                if frequency * Float(harmonic) < limit {
                    value += sin(voice.phase * Float(harmonic)) / Float(harmonic)
                }
                harmonic += 1
            }
            return value * envelope * voice.gain * release
        case .drop:
            voice.frequency *= voice.chirpPerSample
            voice.phase += twoPi * voice.frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            return sin(voice.phase) * envelope * voice.gain * release
        case .fm:
            voice.modPhase += twoPi * voice.frequency * voice.modRatio / sampleRate
            if voice.modPhase > twoPi { voice.modPhase -= twoPi }
            voice.phase += twoPi * voice.frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            voice.index *= voice.indexRate
            return sin(voice.phase + voice.index * sin(voice.modPhase)) * envelope * voice.gain * release
        case .ring:
            let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
            var sum: Float = 0
            for n in 0..<voice.partialCount {
                let o = base + n * FeelSynth.partialStride
                let re = bank[o]
                let im = bank[o + 1]
                let c = bank[o + 2]
                let s = bank[o + 3]
                let d = bank[o + 4]
                let newIm = (re * s + im * c) * d
                bank[o] = (re * c - im * s) * d
                bank[o + 1] = newIm
                sum += newIm
            }
            return sum * envelope * release
        }
    }
}
