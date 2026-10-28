import Foundation

/// One feedback moment (sound + haptic), the pure translation of a `GameEvent` (GAME-DESIGN §9). The director turns
/// each into `FeelSoundBook` and `FeelHapticBook` recipes; `FeelCueMap` is the tested mapping.
enum FeelCue: Equatable, Sendable {
    /// A gloom seeped out of the crease (quiet; throttled by the director).
    case emerge(GloomKind)
    /// A pop on the ladder: `chain` is the chain count after it (1 = first).
    case pop(GloomKind, chain: Int)
    /// "Sweep!" reached 3 (`count` 3: the full stab) or grew (`count` > 3: one more rung).
    case sweep(count: Int)
    case split
    case hop(skittish: Bool)
    case fireflyArrived
    case fizzle
    case delivered(replanted: Bool)
    case flowerEaten(flowersLeft: Int)
    /// A chain of at least `FeelCueMap.chainLostMinimum` was broken by a loss.
    case chainLost(was: Int)
    /// The first light (`waiting` → `playing`).
    case dawn
    case sunrise(stars: Int)
    case nightWins
    case waveUp(Int)
}

/// `GameEvent`s → `FeelCue`s, in order. Pure. Events with no sound of their own (`hint`, a quiet chain timeout, a
/// short chain broken) map to nothing.
enum FeelCueMap {
    /// A broken chain shorter than this makes no extra sound (the fizzle or the crunch already says it).
    static let chainLostMinimum = 3

    static func cue(for event: GameEvent) -> FeelCue? {
        switch event {
        case .emerged(_, let kind, _):
            return .emerge(kind)
        case .popped(_, let kind, _, _, let chain, _):
            return .pop(kind, chain: chain)
        case .swept(let count, _):
            return .sweep(count: count)
        case .split:
            return .split
        case .hopped(_, _, _, let skittish):
            return .hop(skittish: skittish)
        case .fireflyEmerged:
            return .fireflyArrived
        case .fireflyScorched:
            return .fizzle
        case .fireflyDelivered(_, _, let replanted, _):
            return .delivered(replanted: replanted)
        case .flowerEaten(_, let flowersLeft, _):
            return .flowerEaten(flowersLeft: flowersLeft)
        case .chainBroken(let was):
            return was >= chainLostMinimum ? .chainLost(was: was) : nil
        case .chainEnded:
            return nil
        case .hint:
            return nil
        case .started:
            return .dawn
        case .sunrise(let stars, _):
            return .sunrise(stars: stars)
        case .nightWins:
            return .nightWins
        case .waveUp(let wave):
            return .waveUp(wave)
        }
    }

    static func cues(for events: [GameEvent]) -> [FeelCue] {
        var cues: [FeelCue] = []
        cues.reserveCapacity(events.count)
        for event in events {
            if let cue = cue(for: event) { cues.append(cue) }
        }
        return cues
    }
}

/// Spaces pops into a run (GAME-DESIGN §9: "sweeps through a crowd pop a cascade of rising notes"). Pops on the same
/// frame (or frames a few ms apart) would otherwise land as one chord; each takes the next slot `gap` s after the last,
/// so a flock of six plays as a quick rising arpeggio. A pop that would wait longer than `maxDelay` is dropped (its
/// sparks still fly; at that density nobody can hear one more). Pure, with explicit times.
struct FeelPopSequencer {
    /// Seconds between pops in a run.
    static let gap = 0.045
    /// The longest a pop may wait for its slot (s).
    static let maxDelay = 0.4

    /// When the next pop may sound (−∞: now).
    private(set) var nextSlot = -Double.infinity

    init() {}

    /// The delay (s from `now`) for the next pop, or nil to drop it.
    mutating func slot(at now: Double) -> Double? {
        guard now.isFinite else { return nil }
        let delay = max(nextSlot - now, 0)
        guard delay <= Self.maxDelay else { return nil }
        nextSlot = now + delay + Self.gap
        return delay
    }

    mutating func reset() {
        nextSlot = -Double.infinity
    }

    /// A pop's loudness in a busy run: full for the first three of a frame, then trimmed (≥ 0.6) so a ten-pop sweep
    /// stays clean in the limiter.
    static func scale(index: Int) -> Float {
        guard index >= 3 else { return 1 }
        return max(1 - 0.06 * Float(index - 2), 0.6)
    }

    /// A pop's sparkle tail in a busy run: by size for the first three, then one glint each.
    static func sparkles(index: Int) -> Int? {
        index >= 3 ? 1 : nil
    }
}

/// Throttle for frequent quiet cues (emerge blorps, hops): at most one per `gap` s. Pure.
struct FeelThrottle {
    let gap: Double
    private(set) var last = -Double.infinity

    init(gap: Double) {
        self.gap = gap
    }

    /// True (and records `now`) when the cue may play.
    mutating func allow(at now: Double) -> Bool {
        guard now.isFinite else { return false }
        if last.isFinite && now - last < gap && now >= last { return false }
        last = now
        return true
    }

    mutating func reset() {
        last = -Double.infinity
    }
}
