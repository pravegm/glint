import Foundation

/// Tiny deterministic RNG for sound variation (main thread). Named to avoid clashing with Core's `SeededRandom`.
struct FeelDice {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0…1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    /// Uniform in lower…upper.
    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }

    /// Uniform in lower…upper, as a Float.
    mutating func float(_ lower: Float, _ upper: Float) -> Float {
        Float(range(Double(lower), Double(upper)))
    }

    /// Uniform in 0..<count (0 when count ≤ 1).
    mutating func index(_ count: Int) -> Int {
        guard count > 1 else { return 0 }
        return Int(next() % UInt64(count))
    }

    mutating func seed32() -> UInt32 {
        UInt32(truncatingIfNeeded: next()) | 1
    }
}

/// What is burning this frame, for the sizzle (sound and haptic). Pure.
struct FeelBurn: Equatable, Sendable {
    /// 0…1 sizzle level from the total burn rate.
    var level: Double = 0
    /// 0…1 how close the lit glooms are to popping (light-weighted mean of 1 − hp/maxHP).
    var heat: Double = 0
    /// 0…1 the highest scorch of a firefly in the light.
    var danger: Double = 0

    static let zero = FeelBurn()
}

/// Glint's sound design (GAME-DESIGN §9, ROUND-1 "Feel engineer"), as pure data: every recipe returns synth commands
/// and the continuous bed is a pure function of the snapshot, so it is all unit-tested and nothing here touches audio
/// hardware.
///
/// Mix intent: a garden at dawn. The dawn pad (music) is a soft bed that brightens with the sun; the band's air is a
/// whisper. The **sizzle** is the one continuous sound that grows loud, and only while you're burning something:
/// it climbs in pitch as the shadow weakens and whistles just before the pop. The **pops** are the hero: a bubble burst,
/// a plucked note on a C major pentatonic ladder (each chain step one note up), and a sparkle tail, so a sweep through
/// a crowd plays a rising run. Bigger shadows pop lower and fuller. The master limiter keeps every pile-up clean.
enum FeelSoundBook {
    /// Master trim applied to everything (the bed's master). Hush's value (careful play sat at −32 LUFS at 1.25).
    static let masterGain: Float = 1.8

    // MARK: The pentatonic ladder (the pops)

    /// C5, the ladder's first rung (Hz).
    static let ladderRootHz = 523.25
    /// The C major pentatonic (semitones above C).
    static let pentatonic: [Int] = [0, 2, 4, 7, 9]
    /// The top rung: two octaves above C5 (C7). Chains longer than this stay on the top rung.
    static let ladderTop = 10

    /// The rung (0…`ladderTop`) for a chain count (1 = the first pop). 0 and below read as the first rung.
    static func ladderIndex(chain: Int) -> Int {
        min(max(chain, 1) - 1, ladderTop)
    }

    /// Semitones above C5 for a rung: C D E G A, then up an octave, capped at C7 (24).
    static func ladderSemitones(index: Int) -> Int {
        let i = min(max(index, 0), ladderTop)
        return 12 * (i / pentatonic.count) + pentatonic[i % pentatonic.count]
    }

    /// The pop's note (Hz) for a chain count: chain 1 = C5, 2 = D5 … 5 = A5, 6 = C6 … 11+ = C7.
    static func ladderHz(chain: Int) -> Float {
        let semis = Double(ladderSemitones(index: ladderIndex(chain: chain)))
        return Float(ladderRootHz * pow(2.0, semis / 12))
    }

    /// 0…1 how big a gloom is, for the pop's weight (wisp small … brute big).
    static func popSize(_ kind: GloomKind) -> Float {
        switch kind {
        case .wisp: return 0.2
        case .murk: return 0.5
        case .splitter: return 0.6
        case .hopper: return 0.6
        case .brute: return 1.0
        }
    }

    /// The pluck's register for a kind: the brute plays its rung an octave down (its chime keeps the rung's pitch).
    static func popRegister(_ kind: GloomKind) -> Float {
        switch kind {
        case .brute: return 0.5
        case .wisp, .murk, .splitter, .hopper: return 1
        }
    }

    /// The bubble's pitch (Hz) for a kind: smaller glooms burst higher.
    static func bubbleHz(_ kind: GloomKind) -> Float {
        900 - 520 * popSize(kind)
    }

    /// The pluck's fundamental (Hz) for a pop.
    static func popPitch(kind: GloomKind, chain: Int) -> Float {
        ladderHz(chain: chain) * popRegister(kind)
    }

    /// One pop (GAME-DESIGN §9): a bubble burst and a puff of air, a plucked note on the ladder with a chime an octave
    /// up, a warm body under it for bigger glooms (the brute adds a whumpf and a fifth), and a sparkle tail of glass
    /// glints from the pentatonic above. `scale` trims a busy cascade; `sparkles` caps the tail (nil: by size).
    static func pop(kind: GloomKind, chain: Int, scale: Float = 1, delay: Float = 0, sparkles: Int? = nil,
                    dice: inout FeelDice) -> [FeelSynthCommand] {
        let note = ladderHz(chain: chain)
        let size = popSize(kind)
        let pluck = note * popRegister(kind)
        let s = max(scale, 0)
        var commands: [FeelSynthCommand] = []
        // 1. The burst: a bubble chirping up (lower and longer for bigger), and the air it lets out.
        commands.append(.drop(FeelDropSpec(frequency: bubbleHz(kind) * dice.float(0.94, 1.06), chirp: 2.2 - 0.6 * size,
                                           decay: 0.016 + 0.03 * size, gain: (0.11 + 0.05 * size) * s, delay: delay)))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 3400 - 1700 * size, to: 900, sweep: 0.05, q: 0.9,
                                             attack: 0.0006, decay: 0.008 + 0.014 * size, gain: (0.07 + 0.05 * size) * s,
                                             delay: delay)))
        // 2. The note: a bright pluck on the rung, a chime an octave up for shine.
        commands.append(.ring(FeelRingSpec(.pluck, fundamental: pluck, partials: 5, decay: 0.22 + 0.25 * size,
                                           brightness: 0.5, gain: (0.12 + 0.02 * size) * s, delay: delay + 0.004,
                                           seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.chime, fundamental: pluck * 2, partials: 3, decay: 0.3, brightness: 0.3,
                                           gain: (0.045 - 0.01 * size) * s, delay: delay + 0.006,
                                           seed: dice.seed32())))
        // 3. The body: an octave (the brute two) under the rung, warm and short.
        if size >= 0.45 {
            let under: Float = kind == .brute ? note * 0.25 : note * 0.5
            commands.append(.tone(FeelToneSpec(start: under * 1.06, end: under, glide: 0.03, duration: 0.18 + 0.25 * size,
                                               attack: 0.003, decay: 0.06 + 0.12 * size, gain: 0.08 * size * s,
                                               harmonics: 4, delay: delay)))
        }
        if kind == .brute {
            // The whumpf, the fifth, and the weight of it landing.
            commands.append(.tone(FeelToneSpec(start: 160, end: 70, glide: 0.08, duration: 0.32, attack: 0.002,
                                               decay: 0.08, gain: 0.13 * s, harmonics: 6, delay: delay)))
            commands.append(.ring(FeelRingSpec(.pluck, fundamental: note * 0.75, partials: 4, decay: 0.45,
                                               brightness: 0.45, gain: 0.07 * s, delay: delay + 0.012,
                                               seed: dice.seed32())))
            commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 700, to: 200, sweep: 0.08, q: 1, attack: 0.001,
                                                 decay: 0.05, gain: 0.11 * s, delay: delay)))
        }
        // 4. The sparkle tail: glass glints from the pentatonic above the rung, falling in after the note.
        let count = sparkles ?? (kind == .brute ? 5 : (size >= 0.45 ? 3 : 2))
        for k in 0..<max(count, 0) {
            let step = ladderIndex(chain: chain) + 2 + dice.index(5)
            let semis = 12 * (step / pentatonic.count) + pentatonic[step % pentatonic.count]
            var f = Float(ladderRootHz * pow(2.0, Double(semis) / 12)) * 2
            while f > 5200 { f *= 0.5 }
            let kf = Float(k)
            commands.append(.ring(FeelRingSpec(.glass, fundamental: f, partials: 2, decay: dice.float(0.08, 0.14),
                                               brightness: 0.3, gain: max(0.032 - 0.005 * kf, 0.01) * s,
                                               delay: delay + 0.03 + 0.035 * kf + dice.float(0, 0.012),
                                               seed: dice.seed32())))
        }
        return commands
    }

    // MARK: Sweep, split, hop, emerge

    /// "Sweep!" (3 pops within 0.35 s): a strummed C6/9 chord stab (C5 E5 G5 A5 D6) on chimes over a warm C–G stab, a
    /// whoosh up through the band, and two glints on top.
    static func sweepStab(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let chord: [Float] = [523.25, 659.25, 783.99, 880.0, 1174.66]
        var commands: [FeelSynthCommand] = []
        for (index, f) in chord.enumerated() {
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: 0.6, brightness: 0.4,
                                               gain: 0.055, delay: delay + 0.012 * Float(index), seed: dice.seed32())))
        }
        commands.append(.tone(FeelToneSpec(start: 261.63, duration: 0.45, attack: 0.004, decay: 0.18, gain: 0.05,
                                           harmonics: 5, delay: delay)))
        commands.append(.tone(FeelToneSpec(start: 392.0, duration: 0.45, attack: 0.004, decay: 0.18, gain: 0.04,
                                           harmonics: 5, delay: delay + 0.006)))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 500, to: 4500, sweep: 0.25, q: 0.8, attack: 0.06,
                                             decay: 0.12, gain: 0.09, delay: max(delay - 0.04, 0))))
        commands.append(.ring(FeelRingSpec(.glass, fundamental: 2093.0, partials: 2, decay: 0.3, brightness: 0.3,
                                           gain: 0.035, delay: delay + 0.08, seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.glass, fundamental: 2637.02, partials: 2, decay: 0.3, brightness: 0.3,
                                           gain: 0.03, delay: delay + 0.12, seed: dice.seed32())))
        return commands
    }

    /// The sweep growing past 3 (`count` = the running count): one more chime rung above the chord and a glint.
    static func sweepRung(count: Int, delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let rung = min(max(count - 4, 0), 5) + 6 // C6, D6, E6, G6, A6, C7
        let f = ladderHz(chain: rung)
        return [
            .ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: 0.5, brightness: 0.4, gain: 0.05,
                               delay: delay, seed: dice.seed32())),
            .ring(FeelRingSpec(.glass, fundamental: min(f * 2, 5200), partials: 2, decay: 0.2, brightness: 0.3,
                               gain: 0.025, delay: delay + 0.03, seed: dice.seed32())),
        ]
    }

    /// A splitter flings its wisps: two quick bright plips.
    static func split(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .drop(FeelDropSpec(frequency: dice.float(1150, 1250), chirp: 1.8, decay: 0.015, gain: 0.06,
                               delay: delay + 0.05)),
            .drop(FeelDropSpec(frequency: dice.float(1450, 1550), chirp: 1.8, decay: 0.015, gain: 0.055,
                               delay: delay + 0.085)),
        ]
    }

    /// A hopper hops: a little boing and its landing (0.22 s later); skittish (the light made it jump) adds a squeak.
    static func hop(skittish: Bool, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            .tone(FeelToneSpec(start: dice.float(250, 280), end: 480, glide: 0.07, duration: 0.12, attack: 0.003,
                               decay: 0.04, gain: 0.05, harmonics: 2)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 500, q: 0.9, attack: 0.001, decay: 0.03, gain: 0.05, delay: 0.22)),
        ]
        if skittish {
            commands.append(.tone(FeelToneSpec(start: 1400, end: 2000, glide: 0.05, duration: 0.08, attack: 0.003,
                                               decay: 0.03, gain: 0.03, vibratoRate: 30, vibratoDepth: 0.03)))
        }
        return commands
    }

    /// A gloom seeps out of the crease: a soft low blorp (a brute's is deeper). Quiet: they come often.
    static func emerge(kind: GloomKind, dice: inout FeelDice) -> [FeelSynthCommand] {
        let big = kind == .brute
        let f: Float = big ? dice.float(105, 120) : dice.float(170, 240)
        return [
            .drop(FeelDropSpec(frequency: f, chirp: 1.4, decay: big ? 0.08 : 0.05, gain: big ? 0.07 : 0.04)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: big ? 220 : 320, q: 0.9, attack: 0.01, decay: 0.04,
                                 gain: big ? 0.05 : 0.025)),
        ]
    }

    // MARK: Fireflies

    /// A firefly drifts out: two faint glass twinkles (G6, C7).
    static func fireflyArrived(dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.glass, fundamental: 1567.98, partials: 2, decay: 0.25, brightness: 0.3, gain: 0.02,
                               seed: dice.seed32())),
            .ring(FeelRingSpec(.glass, fundamental: 2093.0, partials: 2, decay: 0.3, brightness: 0.3, gain: 0.016,
                               delay: 0.07, seed: dice.seed32())),
        ]
    }

    /// A firefly fizzles in the light: a sad falling blip, a fizz, and a last little blip down.
    static func fizzle(dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .tone(FeelToneSpec(start: dice.float(1280, 1360), end: 440, glide: 0.28, duration: 0.34, attack: 0.004,
                               decay: 0.12, gain: 0.07, harmonics: 2, vibratoRate: 14, vibratoDepth: 0.03)),
            .noise(FeelNoiseSpec(.highPass, cutoff: 5000, to: 1500, sweep: 0.2, q: 0.7, attack: 0.002, decay: 0.06,
                                 gain: 0.07)),
            .drop(FeelDropSpec(frequency: 600, chirp: 0.6, decay: 0.03, gain: 0.05, delay: 0.25)),
        ]
    }

    /// A firefly reaches the flowers: a bell (G6) and a glint; `replanted` adds the bloom (a C6–E6–G6–C7 arpeggio, a
    /// soft "fwoomp" of petals opening, a warm C–E stab); else a smaller two-note bloom (+50).
    static func delivered(replanted: Bool, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            .ring(FeelRingSpec(.bell, fundamental: 1567.98, partials: 6, decay: 1.0, brightness: 0.45, gain: 0.08,
                               seed: dice.seed32())),
            .ring(FeelRingSpec(.glass, fundamental: 3135.96, partials: 2, decay: 0.25, brightness: 0.3, gain: 0.03,
                               delay: 0.02, seed: dice.seed32())),
        ]
        if replanted {
            let bloom: [Float] = [1046.5, 1318.51, 1567.98, 2093.0]
            for (index, f) in bloom.enumerated() {
                let last = index == bloom.count - 1
                commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 3, decay: last ? 0.8 : 0.4,
                                                   brightness: 0.35, gain: last ? 0.06 : 0.05,
                                                   delay: 0.12 + 0.07 * Float(index), seed: dice.seed32())))
            }
            commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 300, to: 1200, sweep: 0.2, q: 0.8, attack: 0.08,
                                                 decay: 0.2, gain: 0.06, delay: 0.1)))
            commands.append(.tone(FeelToneSpec(start: 523.25, duration: 0.9, attack: 0.08, decay: 0.35, gain: 0.03,
                                               harmonics: 3, delay: 0.12)))
            commands.append(.tone(FeelToneSpec(start: 659.25, duration: 0.9, attack: 0.08, decay: 0.35, gain: 0.025,
                                               harmonics: 3, delay: 0.16)))
        } else {
            commands.append(.ring(FeelRingSpec(.chime, fundamental: 1318.51, partials: 3, decay: 0.4, brightness: 0.35,
                                               gain: 0.045, delay: 0.12, seed: dice.seed32())))
            commands.append(.ring(FeelRingSpec(.chime, fundamental: 1567.98, partials: 3, decay: 0.6, brightness: 0.35,
                                               gain: 0.05, delay: 0.19, seed: dice.seed32())))
        }
        return commands
    }

    // MARK: Losses

    /// A flower is eaten: a crunch (a falling band of noise and three dry snaps), a knock, a low thud, and one sad
    /// little falling note.
    static func flowerEaten(dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 1400, to: 500, sweep: 0.07, q: 1.3, attack: 0.001, decay: 0.05,
                                 gain: 0.3)),
            .ring(FeelRingSpec(.wood, fundamental: 320, partials: 4, decay: 0.05, brightness: 0.45, gain: 0.2,
                               seed: dice.seed32())),
            .tone(FeelToneSpec(start: 120, end: 48, glide: 0.12, duration: 0.35, attack: 0.002, decay: 0.11, gain: 0.2,
                               harmonics: 7, delay: 0.01)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 400, to: 120, sweep: 0.1, q: 1, attack: 0.001, decay: 0.08,
                                 gain: 0.14, delay: 0.01)),
            .tone(FeelToneSpec(start: 659.25, end: 523.25, glide: 0.25, duration: 0.4, attack: 0.01, decay: 0.15,
                               gain: 0.035, harmonics: 2, delay: 0.18)),
        ]
        for k in 0..<3 {
            commands.append(.ring(FeelRingSpec(.wood, fundamental: dice.float(900, 1600), partials: 3, decay: 0.012,
                                               brightness: 0.5, gain: 0.14, delay: 0.025 * Float(k),
                                               seed: dice.seed32())))
        }
        return commands
    }

    /// A long chain broke (a fizzle or a lost flower): two quiet glass notes falling (E6 → C6), after the loss itself.
    static func chainLost(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.glass, fundamental: 1318.51, partials: 2, decay: 0.2, brightness: 0.3, gain: 0.03,
                               delay: delay, seed: dice.seed32())),
            .ring(FeelRingSpec(.glass, fundamental: 1046.5, partials: 2, decay: 0.25, brightness: 0.3, gain: 0.028,
                               delay: delay + 0.08, seed: dice.seed32())),
        ]
    }

    // MARK: The level's arc

    /// The first light (`.started`): an airy rise, a soft C4 swell and two glints of dawn.
    static func dawn() -> [FeelSynthCommand] {
        [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 400, to: 2400, sweep: 0.6, q: 0.8, attack: 0.25, decay: 0.3,
                                 gain: 0.04)),
            .tone(FeelToneSpec(start: 261.63, duration: 1.0, attack: 0.3, decay: 0.5, gain: 0.03, harmonics: 3)),
            .ring(FeelRingSpec(.glass, fundamental: 1046.5, partials: 2, decay: 0.6, brightness: 0.3, gain: 0.025,
                               delay: 0.15)),
            .ring(FeelRingSpec(.glass, fundamental: 1567.98, partials: 2, decay: 0.6, brightness: 0.3, gain: 0.022,
                               delay: 0.25)),
        ]
    }

    /// Sunrise: the shadows left evaporate in a quick soft ripple up the ladder (`ripple` of them, ≤ 10), then a rising
    /// C major chord (C4 E4 G4 C5 E5 G5, strummed slowly, warm, with chimes an octave up) over a C3 swell, a bell on
    /// top, an airy rise, and birdsong: 3 + `stars` little chirp phrases.
    static func sunrise(stars: Int, ripple: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = []
        let n = min(max(ripple, 0), 10)
        for k in 0..<n {
            let t = 0.03 * Float(k)
            commands.append(.drop(FeelDropSpec(frequency: dice.float(700, 1000), chirp: 2.0, decay: 0.02, gain: 0.06,
                                               delay: t)))
            commands.append(.ring(FeelRingSpec(.glass, fundamental: min(ladderHz(chain: k + 1) * 2, 5200), partials: 2,
                                               decay: 0.15, brightness: 0.3, gain: 0.03, delay: t + 0.005,
                                               seed: dice.seed32())))
        }
        let t0: Float = n > 0 ? 0.03 * Float(n) + 0.05 : 0
        let chord: [Float] = [261.63, 329.63, 392.0, 523.25, 659.25, 783.99]
        for (index, f) in chord.enumerated() {
            let at = t0 + 0.09 * Float(index)
            commands.append(.tone(FeelToneSpec(start: f * 0.995, end: f, glide: 0.3, duration: 2.6, attack: 0.25,
                                               decay: 1.1, gain: 0.05, harmonics: 4,
                                               vibratoRate: 4.8 + 0.3 * Float(index), vibratoDepth: 0.004, delay: at)))
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f * 2, partials: 3, decay: 0.9, brightness: 0.35,
                                               gain: 0.045, delay: at, seed: dice.seed32())))
        }
        commands.append(.tone(FeelToneSpec(start: 130.81, duration: 2.8, attack: 0.4, decay: 1.2, gain: 0.06,
                                           harmonics: 3, delay: t0)))
        commands.append(.ring(FeelRingSpec(.bell, fundamental: 1046.5, partials: 6, decay: 1.6, brightness: 0.45,
                                           gain: 0.07, delay: t0 + 0.55, seed: dice.seed32())))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 500, to: 5000, sweep: 1.0, q: 0.7, attack: 0.5,
                                             decay: 0.6, gain: 0.03, delay: t0)))
        commands.append(contentsOf: birdsong(phrases: 3 + min(max(stars, 0), 3), start: t0 + 0.6, dice: &dice))
        return commands
    }

    /// Little bird phrases: 2–4 quick rising chirps each (2.6–3.6 kHz, a fast trill), the phrases ~0.35 s apart.
    static func birdsong(phrases: Int, start: Float, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = []
        for phrase in 0..<max(phrases, 0) {
            let at = start + 0.35 * Float(phrase) + dice.float(0, 0.15)
            let chirps = 2 + dice.index(3)
            let base = dice.float(2600, 3600)
            for k in 0..<chirps {
                let f0 = base * dice.float(0.92, 1.08)
                commands.append(.tone(FeelToneSpec(start: f0, end: f0 * dice.float(1.2, 1.45), glide: 0.045,
                                                   duration: 0.06, attack: 0.004, decay: 0.025, gain: 0.03,
                                                   vibratoRate: 38, vibratoDepth: 0.03,
                                                   delay: at + 0.075 * Float(k))))
            }
        }
        return commands
    }

    /// The night wins: a low A minor fall (E4, C4, A3 sinking a little), a low drone gliding down, a dark breath and a
    /// low bell.
    static func nightWins() -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = []
        let chord: [Float] = [329.63, 261.63, 220.0]
        for (index, f) in chord.enumerated() {
            commands.append(.tone(FeelToneSpec(start: f, end: f * 0.94, glide: 1.2, duration: 2.2, attack: 0.05,
                                               decay: 0.9, gain: 0.06, harmonics: 5, delay: 0.12 * Float(index))))
        }
        commands.append(.tone(FeelToneSpec(start: 110, end: 82, glide: 1.5, duration: 2.5, attack: 0.08, decay: 1.0,
                                           gain: 0.09, harmonics: 6)))
        commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 900, to: 150, sweep: 1.5, q: 0.8, attack: 0.1,
                                             decay: 0.7, gain: 0.06)))
        commands.append(.ring(FeelRingSpec(.bell, fundamental: 220, partials: 5, decay: 2.0, brightness: 0.4,
                                           gain: 0.06, delay: 0.3)))
        return commands
    }

    /// Long Night: the wave went up. A low bell (C4), a fifth above it, a dark swell.
    static func waveUp(_ wave: Int) -> [FeelSynthCommand] {
        let lift = Float(min(max(wave, 1), 12) - 1) * 0.01
        return [
            .ring(FeelRingSpec(.bell, fundamental: 261.63 * (1 + lift), partials: 6, decay: 1.4, brightness: 0.45,
                               gain: 0.07)),
            .ring(FeelRingSpec(.bell, fundamental: 392.0 * (1 + lift), partials: 5, decay: 1.2, brightness: 0.4,
                               gain: 0.05, delay: 0.18)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 300, to: 900, sweep: 0.5, q: 0.8, attack: 0.2, decay: 0.3,
                                 gain: 0.05)),
        ]
    }

    // MARK: UI

    /// The menu sounds: wooden marimba taps, bells for stars, an arpeggio for an unlock, a dawn swell to start.
    static func ui(_ cue: UICue, dice: inout FeelDice) -> [FeelSynthCommand] {
        switch cue {
        case .tap:
            return [
                .ring(FeelRingSpec(.marimba, fundamental: 1046.5, partials: 3, decay: 0.06, brightness: 0.4,
                                   gain: 0.09)),
                .noise(FeelNoiseSpec(.highPass, cutoff: 3000, q: 0.7, attack: 0.0005, decay: 0.003, gain: 0.03)),
            ]
        case .back:
            return [
                .ring(FeelRingSpec(.marimba, fundamental: 783.99, partials: 3, decay: 0.06, brightness: 0.4,
                                   gain: 0.08)),
                .ring(FeelRingSpec(.marimba, fundamental: 659.25, partials: 3, decay: 0.07, brightness: 0.4,
                                   gain: 0.06, delay: 0.05)),
            ]
        case .toggle:
            return [
                .ring(FeelRingSpec(.marimba, fundamental: 1318.51, partials: 3, decay: 0.05, brightness: 0.4,
                                   gain: 0.07)),
                .ring(FeelRingSpec(.marimba, fundamental: 1567.98, partials: 3, decay: 0.06, brightness: 0.4,
                                   gain: 0.07, delay: 0.05)),
            ]
        case .star(let n):
            return star(n, dice: &dice)
        case .unlock:
            var commands: [FeelSynthCommand] = []
            let notes: [Float] = [523.25, 659.25, 783.99, 1046.5, 1318.51]
            for (index, f) in notes.enumerated() {
                commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: 0.5, brightness: 0.35,
                                                   gain: 0.06, delay: 0.06 * Float(index), seed: dice.seed32())))
            }
            commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 600, to: 4000, sweep: 0.3, q: 0.8, attack: 0.05,
                                                 decay: 0.15, gain: 0.05)))
            commands.append(.ring(FeelRingSpec(.bell, fundamental: 1567.98, partials: 6, decay: 1.0, brightness: 0.45,
                                               gain: 0.07, delay: 0.32, seed: dice.seed32())))
            return commands
        case .levelStart:
            return [
                .tone(FeelToneSpec(start: 261.63, duration: 0.9, attack: 0.2, decay: 0.4, gain: 0.035, harmonics: 3)),
                .tone(FeelToneSpec(start: 392.0, duration: 0.9, attack: 0.25, decay: 0.4, gain: 0.025, harmonics: 3,
                                   delay: 0.05)),
                .noise(FeelNoiseSpec(.bandPass, cutoff: 400, to: 2000, sweep: 0.5, q: 0.8, attack: 0.2, decay: 0.25,
                                     gain: 0.035)),
                .ring(FeelRingSpec(.glass, fundamental: 783.99, partials: 2, decay: 0.5, brightness: 0.3, gain: 0.03,
                                   delay: 0.2)),
                .ring(FeelRingSpec(.glass, fundamental: 1046.5, partials: 2, decay: 0.5, brightness: 0.3, gain: 0.03,
                                   delay: 0.3)),
            ]
        }
    }

    /// The pitch of the n-th star's bell (1: G5, 2: C6, 3: E6).
    static func starHz(_ n: Int) -> Float {
        switch min(max(n, 1), 3) {
        case 1: return 783.99
        case 2: return 1046.5
        default: return 1318.51
        }
    }

    /// The n-th star lands on the results card: a bell climbing with the count, a glint; the third adds a shower.
    static func star(_ n: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let f = starHz(n)
        var commands: [FeelSynthCommand] = [
            .ring(FeelRingSpec(.bell, fundamental: f, partials: 6, decay: 1.0, brightness: 0.45, gain: 0.09,
                               seed: dice.seed32())),
            .ring(FeelRingSpec(.glass, fundamental: f * 2, partials: 2, decay: 0.3, brightness: 0.3, gain: 0.03,
                               delay: 0.02, seed: dice.seed32())),
            .noise(FeelNoiseSpec(.highPass, cutoff: 2500, q: 0.7, attack: 0.0005, decay: 0.008, gain: 0.05)),
        ]
        if n >= 3 {
            for k in 0..<5 {
                commands.append(.ring(FeelRingSpec(.glass, fundamental: dice.float(2600, 4200), partials: 2,
                                                   decay: 0.15, brightness: 0.3, gain: 0.022,
                                                   delay: 0.12 + 0.06 * Float(k), seed: dice.seed32())))
            }
        }
        return commands
    }

    // MARK: The bed (everything continuous)

    /// Glide (s) of the frame-by-frame bed, and of a fade (pause, menus).
    static let frameGlide: Float = 0.05
    static let fadeGlide: Float = 0.35
    /// The pad's share while paused, and in menus (`FeedbackDirector.ambience(sun:)`).
    static let pausedPadShare = 0.5
    static let menuPadShare = 0.7

    /// The sizzle's level for a total burn rate (HP/s; 1 = one gloom in full light): 0 at nothing, ≈0.69 at 1,
    /// ≈0.94 at 2.5, → 1. Continuous and monotonic, so it swells and fades with what's burning.
    static func sizzleLevel(burn: Double) -> Double {
        guard burn.isFinite, burn > 0.005 else { return 0 }
        return FeelMath.clamp01(pow(1 - exp(-burn / 0.9), 0.9))
    }

    /// How close the lit glooms are to popping (0 fresh … 1 nearly gone): the mean of 1 − hp/maxHP weighted by light.
    static func heat(of glooms: [GloomState]) -> Double {
        var weight = 0.0
        var sum = 0.0
        for gloom in glooms where gloom.lit > 0 && gloom.maxHP > 0 {
            let lit = FeelMath.clamp01(gloom.lit)
            weight += lit
            sum += lit * (1 - FeelMath.clamp01(gloom.hp / gloom.maxHP))
        }
        guard weight > 1e-6 else { return 0 }
        return FeelMath.clamp01(sum / weight)
    }

    /// What is burning in a snapshot (all zero outside `.playing`).
    static func burn(of snapshot: DawnSnapshot) -> FeelBurn {
        guard snapshot.phase == .playing else { return FeelBurn.zero }
        let t = snapshot.telemetry
        return FeelBurn(level: sizzleLevel(burn: t.burnRate), heat: heat(of: snapshot.glooms),
                        danger: FeelMath.clamp01(t.fireflyDanger))
    }

    /// The hiss's centre (Hz): 1.5 kHz on a fresh gloom, rising ~1.7 octaves as it weakens, a little brighter louder.
    static func sizzleHz(heat: Double, level: Double) -> Double {
        1500 * pow(2.0, 1.7 * FeelMath.clamp01(heat)) * (0.9 + 0.2 * FeelMath.clamp01(level))
    }

    /// Crackles per second.
    static func crackleRate(level: Double, heat: Double) -> Double {
        30 + 160 * FeelMath.clamp01(level) + 100 * FeelMath.clamp01(heat)
    }

    /// The kettle whistle: only as something lit nears its pop (heat over 0.4), with the sizzle's level.
    static func kettleLevel(level: Double, heat: Double) -> Double {
        0.9 * FeelMath.clamp01(level) * FeelMath.smoothstep((heat - 0.4) / 0.6)
    }

    /// The firefly whimper: rises with the scorch (silent under 0.02).
    static func alarmLevel(danger: Double) -> Double {
        let d = FeelMath.clamp01(danger)
        guard d > 0.02 else { return 0 }
        return 0.9 * pow(d, 0.8)
    }

    /// The band's air (very quiet): nothing under 0.05 d/s, up to 0.6 at ~1.65 d/s and above.
    static func airLevel(bandSpeed: Double) -> Double {
        let s = bandSpeed.isFinite ? abs(bandSpeed) : 0
        return 0.6 * pow(FeelMath.clamp01((s - 0.05) / 1.6), 1.3)
    }

    /// The pad's brightness (0 night … 1 sunrise). Levels and daily: pre-dawn while waiting, then with the sun, full at
    /// sunrise, dark when the night wins. Long Night: a dim night that deepens with its depth.
    static func padBrightness(mode: PlayMode, phase: SessionPhase, sun: Double) -> Double {
        let s = FeelMath.clamp01(sun)
        if case .endless = mode {
            switch phase {
            case .lost: return 0.05
            case .waiting, .playing, .won: return 0.3 * (1 - 0.7 * s)
            }
        }
        switch phase {
        case .waiting: return 0.06
        case .playing: return 0.08 + 0.92 * s
        case .won: return 1
        case .lost: return 0.05
        }
    }

    /// No continuous layers, master kept: menus, pause cards and one-shots stay audible.
    static func idleBed(master: Float, glide: Float = fadeGlide) -> FeelBed {
        var bed = FeelBed()
        bed.master = master
        bed.glide = glide
        return bed
    }

    /// The menus' bed: the dawn pad only (music on), softer, at a given sun.
    static func menuBed(sun: Double, master: Float, music: Bool) -> FeelBed {
        var bed = idleBed(master: master, glide: frameGlide)
        guard music else { return bed }
        let bright = 0.15 + 0.6 * FeelMath.clamp01(sun)
        bed.pad = Float(menuPadShare)
        bed.padBright = Float(bright)
        bed.twinkleRate = Float(0.1 + 0.4 * bright)
        return bed
    }

    /// The continuous layers for one game frame (GAME-DESIGN §9). `sound` gates the sizzle, the alarm and the air;
    /// `music` gates the pad. `advancing` is false on a frame that doesn't step the session (dt = 0): nothing burns or
    /// moves then. Paused: everything but the pad (at half) is silent.
    static func playBed(snapshot: DawnSnapshot, sound: Bool, music: Bool, paused: Bool, advancing: Bool) -> FeelBed {
        let master: Float = (sound || music) ? masterGain : 0
        var bed = idleBed(master: master, glide: paused ? fadeGlide : frameGlide)
        let live = !paused && advancing
        if sound && live {
            let state = burn(of: snapshot)
            if state.level > 0 {
                bed.sizzle = Float(state.level)
                bed.sizzleHz = Float(sizzleHz(heat: state.heat, level: state.level))
                bed.crackleRate = Float(crackleRate(level: state.level, heat: state.heat))
                bed.kettle = Float(kettleLevel(level: state.level, heat: state.heat))
                bed.kettleHz = Float(1100 + 1500 * state.heat)
            }
            let alarm = alarmLevel(danger: state.danger)
            if alarm > 0 {
                bed.alarm = Float(alarm)
                bed.alarmHz = Float(1300 + 700 * state.danger)
            }
            if snapshot.phase == .playing || snapshot.phase == .waiting {
                let speed = snapshot.telemetry.bandSpeed
                bed.air = Float(airLevel(bandSpeed: speed))
                bed.airHz = Float(350 + 900 * FeelMath.clamp01(abs(speed.isFinite ? speed : 0) / 2))
            }
        }
        if music {
            let bright = padBrightness(mode: snapshot.mode, phase: snapshot.phase, sun: snapshot.sun)
            var share = paused ? pausedPadShare : 1.0
            if snapshot.phase == .lost { share *= 0.6 }
            bed.pad = Float(share)
            bed.padBright = Float(bright)
            bed.twinkleRate = paused ? 0 : Float(0.1 + 0.6 * bright)
        }
        return bed
    }
}
