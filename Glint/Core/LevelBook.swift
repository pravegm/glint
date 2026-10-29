import Foundation

// MARK: - The 30 sunrises, Today's Dawn and Long Night's waves (GAME-DESIGN §6)
//
// "Handcrafted by formula": each level is one row of `recipes` (what comes, how fast, how crowded, how cloudy), and
// `groups(for:rng:start:span:endPad:)` + `clouds(for:rng:start:span:)` lay the row out on the clock, seeded by the
// level number, so a level is the same script on every device. The session draws each member's exact `u` itself.
//
// The layout keeps the load smooth: groups are shuffled (brutes and hoppers lean later), then placed by cumulative
// cost (seconds of attention each kind needs) along a density that rises from 0.7× to 1.3× of the level's average.
// R2: with chance `front`, a group arrives together with the one before it (a mixed front: a murk line with a wisp
// flock, say), which makes cascades. Clouds slide in from an edge at even, jittered times.
//
// Balance R2 (design/notes/core-R2.md; BalanceTests prints GLINT-BAL): the rows were sized by the JS mirror
// (design/notes/core-R1-sim, `tune.js` then `fix.js`) against the R2 targets with the human-hinge pilot. Speeds vary
// per level on purpose (a fast sparse tide, a slow dense fog); the counts were re-rolled around each speed.

/// One level's ingredients.
struct LevelRecipe: Equatable {
    var title: String
    var duration: Double
    var murks: Int
    /// Wisp flocks, each `flockSize` wisps (a ladder or a cluster).
    var flocks: Int
    var flockSize: Int
    var brutes: Int
    /// Splitter groups (1, or 2 with probability `pair`).
    var splitters: Int
    /// Hopper groups (1, or 2 with probability `pair`).
    var hoppers: Int
    var fireflies: Int
    /// Speed scale (1 = GloomSpec speeds), rising 0.95× → 1.05× across the level.
    var speed: Double
    /// The largest murk pack.
    var crowd: Int
    var pair: Double
    /// R2: the chance a group arrives together with the previous one (never a brute).
    var front: Double = 0
    /// R2: cloud shadows in the level, their typical half-width (u), drift speed (u/s) and strength.
    var clouds: Int = 0
    var cloudWidth: Double = 0
    var cloudSpeed: Double = 0
    var cloudStrength: Double = 1
    /// R3: members surface between `surfaceMin` and `surfaceMax` (0 = never submerged); see `groups(for:…)`.
    var surfaceMin: Double = Tuning.surfaceMin
    var surfaceMax: Double = 0
    /// R3: the third star's score bar (`LevelSpec.starScore`).
    var starScore: Int = 0
    /// R4/R5: the opener: one murk at t = 0 already rising, surfacing at `LevelBook.openerSurface` ~0.75 s after the
    /// first light (every level, Today's Dawn and Long Night's first wave).
    var opener: Bool = false
}

enum LevelBook {
    static let count: Int = 30
    static let worldCount: Int = 3
    static let levelsPerWorld: Int = 10

    /// Seconds into a level of the first spawn, and how long before sunrise the last one lands.
    /// R5 (founder, TestFlight build 2: "a lot of time doing nothing"): action from second 1 and spawns until 3 s
    /// before sunrise (was 2.5 s and 8 s).
    static let firstSpawn: Double = 0.5
    static let endPad: Double = 3
    /// R5: every level opens with one murk at t = 0 already rising: it surfaces at this depth ~0.75 s after the first
    /// light (it starts `openerLead × speed` below it).
    static let openerSurface: Double = 0.25
    static let openerLead: Double = 0.12
    /// Clouds start this long after `start` and the last one appears this long before the end.
    static let cloudLead: Double = 6
    static let cloudTail: Double = 16

    // swiftlint:disable line_length
    static let recipes: [LevelRecipe] = [
        // World 1: Meadow. Murks (L1 opens with a quick riser), wisps (from 3), brutes (2, then from 4), fireflies (from 4).
        LevelRecipe(title: "First Light", duration: 35, murks: 36, flocks: 0, flockSize: 0, brutes: 0, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.85, crowd: 2, pair: 0.0, front: 0.35, surfaceMin: 0.15, surfaceMax: 0.35, starScore: 0, opener: true),
        LevelRecipe(title: "Dew", duration: 38, murks: 40, flocks: 0, flockSize: 0, brutes: 1, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.85, crowd: 3, pair: 0.0, front: 0.35, surfaceMin: 0.15, surfaceMax: 0.35, starScore: 0, opener: true),
        LevelRecipe(title: "Ladder of Wisps", duration: 42, murks: 36, flocks: 3, flockSize: 5, brutes: 0, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.85, crowd: 3, pair: 0.0, front: 0.35, surfaceMin: 0.15, surfaceMax: 0.35, starScore: 0, opener: true),
        LevelRecipe(title: "Fireflies", duration: 45, murks: 40, flocks: 3, flockSize: 5, brutes: 2, splitters: 0, hoppers: 0, fireflies: 2, speed: 1.077, crowd: 3, pair: 0.0, front: 0.3, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 2400, opener: true),
        LevelRecipe(title: "Big Feet", duration: 50, murks: 45, flocks: 4, flockSize: 6, brutes: 3, splitters: 0, hoppers: 0, fireflies: 3, speed: 1.593, crowd: 3, pair: 0.0, front: 0.3, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 3100, opener: true),
        LevelRecipe(title: "Clover", duration: 55, murks: 52, flocks: 5, flockSize: 6, brutes: 4, splitters: 0, hoppers: 0, fireflies: 3, speed: 1.53, crowd: 4, pair: 0.0, front: 0.3, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 3950, opener: true),
        LevelRecipe(title: "Morning Hush", duration: 58, murks: 58, flocks: 5, flockSize: 6, brutes: 4, splitters: 0, hoppers: 0, fireflies: 4, speed: 1.437, crowd: 4, pair: 0.0, front: 0.3, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4350, opener: true),
        LevelRecipe(title: "Buttercups", duration: 62, murks: 58, flocks: 6, flockSize: 6, brutes: 5, splitters: 0, hoppers: 0, fireflies: 4, speed: 1.468, crowd: 4, pair: 0.0, front: 0.3, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4400, opener: true),
        LevelRecipe(title: "Long Shadows", duration: 65, murks: 61, flocks: 6, flockSize: 6, brutes: 5, splitters: 0, hoppers: 0, fireflies: 4, speed: 1.593, crowd: 4, pair: 0.0, front: 0.3, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4600, opener: true),
        LevelRecipe(title: "Meadow Sunrise", duration: 70, murks: 74, flocks: 7, flockSize: 6, brutes: 6, splitters: 0, hoppers: 0, fireflies: 5, speed: 1.218, crowd: 5, pair: 0.0, front: 0.3, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5800, opener: true),
        // World 2: Rooftops. Splitters (from 11), hoppers (from 14), full-strength cloud shadows (3 per level).
        LevelRecipe(title: "Chimney Pots", duration: 65, murks: 54, flocks: 6, flockSize: 6, brutes: 3, splitters: 3, hoppers: 0, fireflies: 4, speed: 0.78, crowd: 5, pair: 0.3, front: 0.3, clouds: 2, cloudWidth: 0.07, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4050, opener: true),
        LevelRecipe(title: "Split Ends", duration: 65, murks: 56, flocks: 6, flockSize: 6, brutes: 3, splitters: 3, hoppers: 0, fireflies: 4, speed: 1.093, crowd: 5, pair: 0.3, front: 0.3, clouds: 2, cloudWidth: 0.072, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4800, opener: true),
        LevelRecipe(title: "Slate Grey", duration: 70, murks: 58, flocks: 6, flockSize: 6, brutes: 3, splitters: 3, hoppers: 0, fireflies: 4, speed: 0.795, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.074, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4750, opener: true),
        LevelRecipe(title: "Hop Along", duration: 70, murks: 66, flocks: 6, flockSize: 6, brutes: 4, splitters: 4, hoppers: 3, fireflies: 4, speed: 0.78, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.076, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5650, opener: true),
        LevelRecipe(title: "Gutters", duration: 75, murks: 67, flocks: 7, flockSize: 6, brutes: 4, splitters: 4, hoppers: 3, fireflies: 4, speed: 0.702, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.078, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5800, opener: true),
        LevelRecipe(title: "Weathervane", duration: 75, murks: 62, flocks: 7, flockSize: 6, brutes: 4, splitters: 4, hoppers: 4, fireflies: 5, speed: 0.748, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.08, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5150, opener: true),
        LevelRecipe(title: "Pigeon Row", duration: 80, murks: 69, flocks: 7, flockSize: 6, brutes: 5, splitters: 5, hoppers: 4, fireflies: 5, speed: 0.843, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.082, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5800, opener: true),
        LevelRecipe(title: "Tin Roofs", duration: 80, murks: 71, flocks: 7, flockSize: 6, brutes: 5, splitters: 5, hoppers: 5, fireflies: 5, speed: 0.655, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.084, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6150, opener: true),
        LevelRecipe(title: "Skylight", duration: 85, murks: 73, flocks: 8, flockSize: 6, brutes: 5, splitters: 5, hoppers: 5, fireflies: 5, speed: 0.795, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.086, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6700, opener: true),
        LevelRecipe(title: "Rooftop Dawn", duration: 85, murks: 74, flocks: 8, flockSize: 6, brutes: 6, splitters: 6, hoppers: 6, fireflies: 5, speed: 0.732, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.088, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7050, opener: true),
        // World 3: Harbour. Everything, more and wider clouds, fewer fireflies.
        LevelRecipe(title: "Low Tide", duration: 75, murks: 61, flocks: 7, flockSize: 7, brutes: 4, splitters: 4, hoppers: 4, fireflies: 4, speed: 1.014, crowd: 6, pair: 0.4, front: 0.35, clouds: 4, cloudWidth: 0.09, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6300, opener: true),
        LevelRecipe(title: "Rope and Rigging", duration: 78, murks: 61, flocks: 7, flockSize: 7, brutes: 4, splitters: 4, hoppers: 4, fireflies: 4, speed: 1.202, crowd: 6, pair: 0.4, front: 0.35, clouds: 4, cloudWidth: 0.093, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5400, opener: true),
        LevelRecipe(title: "Gull Cry", duration: 80, murks: 63, flocks: 7, flockSize: 7, brutes: 4, splitters: 4, hoppers: 4, fireflies: 4, speed: 0.873, crowd: 6, pair: 0.4, front: 0.35, clouds: 4, cloudWidth: 0.096, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6150, opener: true),
        LevelRecipe(title: "Fog Bank", duration: 82, murks: 68, flocks: 8, flockSize: 7, brutes: 5, splitters: 5, hoppers: 5, fireflies: 4, speed: 0.952, crowd: 6, pair: 0.4, front: 0.35, clouds: 4, cloudWidth: 0.099, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6900, opener: true),
        LevelRecipe(title: "Lantern Row", duration: 85, murks: 70, flocks: 8, flockSize: 7, brutes: 5, splitters: 5, hoppers: 5, fireflies: 4, speed: 1.093, crowd: 6, pair: 0.4, front: 0.35, clouds: 4, cloudWidth: 0.102, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7200, opener: true),
        LevelRecipe(title: "Lighthouse", duration: 88, murks: 74, flocks: 8, flockSize: 7, brutes: 5, splitters: 5, hoppers: 5, fireflies: 3, speed: 0.873, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.105, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6750, opener: true),
        LevelRecipe(title: "Undertow", duration: 90, murks: 70, flocks: 9, flockSize: 7, brutes: 6, splitters: 6, hoppers: 6, fireflies: 3, speed: 0.827, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.108, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7100, opener: true),
        LevelRecipe(title: "Night Ferry", duration: 92, murks: 73, flocks: 9, flockSize: 7, brutes: 6, splitters: 6, hoppers: 6, fireflies: 3, speed: 1.03, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.111, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7250, opener: true),
        LevelRecipe(title: "Last Watch", duration: 95, murks: 72, flocks: 9, flockSize: 7, brutes: 6, splitters: 6, hoppers: 6, fireflies: 3, speed: 0.748, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.114, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7050, opener: true),
        LevelRecipe(title: "Harbour Sunrise", duration: 95, murks: 79, flocks: 10, flockSize: 7, brutes: 7, splitters: 7, hoppers: 7, fireflies: 3, speed: 0.655, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.117, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 8750, opener: true),
    ]
    // swiftlint:enable line_length

    /// Every level, built once.
    static let all: [LevelSpec] = {
        var out: [LevelSpec] = []
        var n: Int = 1
        while n <= LevelBook.count {
            out.append(LevelBook.build(n))
            n += 1
        }
        return out
    }()

    /// Level `n` (1…30, clamped).
    static func level(_ n: Int) -> LevelSpec {
        let k: Int = min(max(n, 1), count)
        return all[k - 1]
    }

    /// The world (1…3) a level belongs to (clamped).
    static func world(of level: Int) -> Int {
        let k: Int = min(max(level, 1), count)
        return min(max((k - 1) / levelsPerWorld + 1, 1), worldCount)
    }

    static func worldName(_ world: Int) -> String {
        switch min(max(world, 1), worldCount) {
        case 1: return "Meadow"
        case 2: return "Rooftops"
        default: return "Harbour"
        }
    }

    /// The level numbers of a world (clamped to 1…3).
    static func levels(inWorld w: Int) -> ClosedRange<Int> {
        let ww: Int = min(max(w, 1), worldCount)
        return ((ww - 1) * levelsPerWorld + 1)...(ww * levelsPerWorld)
    }

    /// Today's Dawn for `day` (days since 2026-01-01 UTC): a 90 s sunrise with Harbour-like pressure and four clouds,
    /// seeded by the day. `number` is 0, `world` 2.
    static func daily(day: Int) -> LevelSpec {
        var rng = SeededRandom(seed: DailySeed.seed(day: day) ^ 0x5A5A_5A5A)
        let recipe: LevelRecipe = dailyRecipe(&rng)
        let span: Double = Tuning.dailyDuration - firstSpawn
        let groups: [SpawnGroup] = LevelBook.groups(for: recipe, rng: &rng, start: firstSpawn, span: span,
                                                    endPad: endPad)
        let clouds: [CloudSpec] = LevelBook.clouds(for: recipe, rng: &rng, start: firstSpawn, span: span)
        return LevelSpec(number: 0, world: 2, title: recipe.title, duration: Tuning.dailyDuration, groups: groups,
                         clouds: clouds)
    }

    // MARK: Internals (internal for tests)

    /// The script seed of level `n`.
    static func levelSeed(_ n: Int) -> UInt64 {
        return UInt64(0x47_4C49_4E54) &* 1000 &+ UInt64(max(n, 0)) &* 7919
    }

    static func build(_ n: Int) -> LevelSpec {
        let k: Int = min(max(n, 1), count)
        let recipe: LevelRecipe = recipes[k - 1]
        var rng = SeededRandom(seed: levelSeed(k))
        let span: Double = recipe.duration - firstSpawn
        let groups: [SpawnGroup] = LevelBook.groups(for: recipe, rng: &rng, start: firstSpawn, span: span,
                                                    endPad: endPad)
        let clouds: [CloudSpec] = LevelBook.clouds(for: recipe, rng: &rng, start: firstSpawn, span: span)
        return LevelSpec(number: k, world: world(of: k), title: recipe.title, duration: recipe.duration,
                         groups: groups, clouds: clouds, starScore: recipe.starScore)
    }

    static func dailyRecipe(_ rng: inout SeededRandom) -> LevelRecipe {
        let murks: Int = 60 + rng.int(0...6)
        let flocks: Int = 6 + rng.int(0...1)
        let brutes: Int = 5 + rng.int(0...1)
        let splitters: Int = 4 + rng.int(0...1)
        let hoppers: Int = 4 + rng.int(0...1)
        return LevelRecipe(title: "Today's Dawn", duration: Tuning.dailyDuration, murks: murks, flocks: flocks,
                           flockSize: 7, brutes: brutes, splitters: splitters, hoppers: hoppers, fireflies: 5,
                           speed: 0.8, crowd: 5, pair: 0.35, front: 0.3, clouds: 4, cloudWidth: 0.1,
                           cloudSpeed: 0.07, cloudStrength: 1, surfaceMin: Tuning.surfaceMin,
                           surfaceMax: Tuning.surfaceMax, opener: true)
    }

    /// Long Night's wave `n` (1, 2, …). R3 (REVIEW-2 #11): wave 1 (the first 30 s) is a gentle Meadow wave; from
    /// wave 2 the night jumps to Rooftops/Harbour pressure (step k = n + 3: every kind, a cloud, deep surfacing) and
    /// keeps escalating gently (two clouds from wave 9; clouds 0.75 → 0.95 strong; flocks of ≤ 6 so one cloud over a
    /// flock can't end a run on its own).
    static func endlessRecipe(_ n: Int) -> LevelRecipe {
        let w: Int = max(n, 1)
        let k: Int = w == 1 ? 0 : w - 1 + 4
        let murks: Int = Int((10 + 1.5 * Double(k)).rounded(.down))
        let flocks: Int = w >= 2 ? 1 + k / 2 : 0
        let brutes: Int = w >= 2 ? 1 + max(k - 2, 0) / 3 : 0
        let splitters: Int = w >= 2 ? 1 + max(k - 3, 0) / 3 : 0
        let hoppers: Int = w >= 3 ? 1 + max(k - 4, 0) / 3 : 0
        let fireflies: Int = w >= 2 ? (w % 2 == 1 ? 2 : 1) : 0
        let clouds: Int = w >= 2 ? (w >= 9 ? 2 : 1) : 0
        return LevelRecipe(title: "Long Night", duration: Tuning.endlessWaveSeconds, murks: murks,
                           flocks: flocks, flockSize: min(4 + k / 3, 6), brutes: brutes, splitters: splitters,
                           hoppers: hoppers, fireflies: fireflies, speed: min(0.75 + 0.012 * Double(k), 1.2),
                           crowd: min(2 + k / 2, 6), pair: min(0.08 * Double(k), 0.5), front: 0.3, clouds: clouds,
                           cloudWidth: min(0.08 + 0.005 * Double(k), 0.14), cloudSpeed: 0.07,
                           cloudStrength: min(0.75 + 0.02 * Double(k), 0.95), surfaceMin: Tuning.surfaceMin,
                           surfaceMax: w == 1 ? Tuning.surfaceMaxGentle : Tuning.surfaceMax, opener: w == 1)
    }

    /// Long Night's wave `n`, times relative to the wave's start (0…30 s).
    static func endlessWave(_ n: Int, rng: inout SeededRandom) -> [SpawnGroup] {
        return groups(for: endlessRecipe(n), rng: &rng, start: 0, span: Tuning.endlessWaveSeconds, endPad: 0)
    }

    /// Long Night's clouds for wave `n` (drawn after the wave's spawns are expanded), times relative to its start.
    static func endlessClouds(_ n: Int, rng: inout SeededRandom) -> [CloudSpec] {
        return clouds(for: endlessRecipe(n), rng: &rng, start: 0, span: Tuning.endlessWaveSeconds)
    }

    /// Seconds of attention a member of each kind costs the player (the layout's load unit).
    static func cost(_ kind: SpawnKind) -> Double {
        switch kind {
        case .firefly: return 0.7
        case .gloom(let k):
            switch k {
            case .murk: return 0.55
            case .wisp: return 0.22
            case .brute: return 1.2
            case .splitter: return 1.0
            case .hopper: return 1.0
            }
        }
    }

    /// How late in a level each kind leans (0 = anywhere, 0.3 = never in the first 30 % of the shuffle).
    static func lateBias(_ kind: SpawnKind) -> Double {
        switch kind {
        case .firefly: return 0.1
        case .gloom(let k):
            switch k {
            case .murk: return 0
            case .wisp: return 0.1
            case .brute: return 0.3
            case .splitter: return 0.15
            case .hopper: return 0.2
            }
        }
    }

    private struct Draft {
        var kind: SpawnKind
        var count: Int
        var u: ClosedRange<Double>
        var formation: Formation
        var key: Double
        var order: Int
        var surface: ClosedRange<Double> = 0...0
    }

    /// R3: the deepest a kind surfaces (brutes shallow so they can be tracked; wisp flocks surface together).
    static func surfaceHigh(_ kind: GloomKind, max top: Double) -> Double {
        switch kind {
        case .murk: return top
        case .wisp: return min(0.55, top)
        case .brute: return min(0.3, top)
        case .splitter: return min(0.45, top)
        case .hopper: return min(0.4, top)
        }
    }

    private static func uRange(_ width: Double, _ rng: inout SeededRandom) -> ClosedRange<Double> {
        let w: Double = min(max(width, 0), 0.8)
        let c: Double = rng.between(0.1 + w / 2, 0.9 - w / 2)
        return (c - w / 2)...(c + w / 2)
    }

    private static func isBrute(_ kind: SpawnKind) -> Bool {
        if case .gloom(let k) = kind, k == .brute { return true }
        return false
    }

    /// Lays a recipe out between `start` and `start + span − endPad` seconds.
    static func groups(for recipe: LevelRecipe, rng: inout SeededRandom, start: Double, span: Double,
                       endPad: Double) -> [SpawnGroup] {
        var items: [Draft] = []
        var left: Int = max(recipe.murks, 0)
        let crowd: Int = max(recipe.crowd, 1)
        while left > 0 {
            let k: Int = min(left, rng.int(1...crowd))
            left -= k
            var line: Bool = false
            if k >= 3 { line = rng.unit() < 0.4 }
            let u: ClosedRange<Double> = uRange(k == 1 ? 0.2 : 0.5, &rng)
            items.append(Draft(kind: .gloom(.murk), count: k, u: u, formation: line ? .line : .cluster, key: 0,
                               order: items.count))
        }
        if recipe.flockSize > 0 {
            var i: Int = 0
            while i < recipe.flocks {
                let u: ClosedRange<Double> = uRange(0.6, &rng)
                let ladder: Bool = rng.unit() < 0.5
                items.append(Draft(kind: .gloom(.wisp), count: recipe.flockSize, u: u,
                                   formation: ladder ? .stagger(0.16) : .cluster, key: 0, order: items.count))
                i += 1
            }
        }
        var b: Int = 0
        while b < recipe.brutes {
            let u: ClosedRange<Double> = uRange(0.3, &rng)
            items.append(Draft(kind: .gloom(.brute), count: 1, u: u, formation: .cluster, key: 0, order: items.count))
            b += 1
        }
        var s: Int = 0
        while s < recipe.splitters {
            let n: Int = rng.unit() < recipe.pair ? 2 : 1
            let u: ClosedRange<Double> = uRange(0.5, &rng)
            items.append(Draft(kind: .gloom(.splitter), count: n, u: u, formation: .line, key: 0, order: items.count))
            s += 1
        }
        var h: Int = 0
        while h < recipe.hoppers {
            let n: Int = rng.unit() < recipe.pair ? 2 : 1
            let u: ClosedRange<Double> = uRange(0.5, &rng)
            items.append(Draft(kind: .gloom(.hopper), count: n, u: u, formation: .line, key: 0, order: items.count))
            h += 1
        }
        var f: Int = 0
        while f < recipe.fireflies {
            let u: ClosedRange<Double> = uRange(0.4, &rng)
            items.append(Draft(kind: .firefly, count: 1, u: u, formation: .cluster, key: 0, order: items.count))
            f += 1
        }
        // R3: where each group surfaces (drawn before the shuffle keys). A murk pack spreads ±0.05 around its depth;
        // everything else (lines, ladders, wisp flocks) surfaces together.
        let smax: Double = recipe.surfaceMax
        let smin: Double = recipe.surfaceMin
        if smax > 0 {
            var q: Int = 0
            while q < items.count {
                if case .gloom(let gk) = items[q].kind {
                    let hi: Double = max(surfaceHigh(gk, max: smax), smin)
                    if gk == .murk && items[q].formation == .cluster && items[q].count >= 2 {
                        let c: Double = rng.between(smin + 0.05, max(hi - 0.05, smin + 0.05))
                        items[q].surface = (c - 0.05)...(c + 0.05)
                    } else {
                        let v: Double = rng.between(smin, hi)
                        items[q].surface = v...v
                    }
                }
                q += 1
            }
        }
        // R4: fireflies don't join the load layout; they fly in the gaps between gloom groups (below).
        var lights: [Draft] = []
        var shadows: [Draft] = []
        for it in items {
            if case .firefly = it.kind { lights.append(it) } else { shadows.append(it) }
        }
        var j: Int = 0
        while j < shadows.count {
            let bias: Double = lateBias(shadows[j].kind)
            shadows[j].key = rng.unit() * (1 - bias) + bias
            j += 1
        }
        shadows.sort { (a: Draft, c: Draft) -> Bool in
            if a.key != c.key { return a.key < c.key }
            return a.order < c.order
        }
        // R5: fronts are pairs: a group joins the one before it (never a brute, never a third), and the pair shares one
        // slot of the load layout, so a front never leaves a hole in the timeline. (One draw per group after the first.)
        var hosts: [[Int]] = []
        var q2: Int = 0
        while q2 < shadows.count {
            var join: Bool = false
            if q2 > 0 {
                let roll: Double = rng.unit()
                if let host = hosts.last {
                    join = roll < recipe.front && !isBrute(shadows[q2].kind) && !isBrute(shadows[host[0]].kind)
                        && host.count == 1
                }
            }
            if join {
                hosts[hosts.count - 1].append(q2)
            } else {
                hosts.append([q2])
            }
            q2 += 1
        }
        var total: Double = 0
        for host in hosts {
            for k in host { total += cost(shadows[k].kind) * Double(shadows[k].count) }
        }
        let window: Double = max(span - endPad, 0)
        var cum: Double = 0
        var out: [SpawnGroup] = []
        out.reserveCapacity(items.count)
        for host in hosts {
            var c: Double = 0
            for k in host { c += cost(shadows[k].kind) * Double(shadows[k].count) }
            let mid: Double = (cum + c / 2) / max(total, 1e-9)
            cum += c
            // R5: density 0.85 + 0.3x over the window: F(x) = 0.85x + 0.15x², inverted (flatter than R1–R4's 0.7 + 0.6x).
            let x: Double = (-0.85 + (0.7225 + 0.6 * mid).squareRoot()) / 0.3
            let t: Double = start + window * x
            let scale: Double = recipe.speed * (0.95 + 0.1 * x)
            for k in host {
                let it: Draft = shadows[k]
                out.append(SpawnGroup(time: t, kind: it.kind, count: it.count, u: it.u, formation: it.formation,
                                      speedScale: scale, surface: it.surface))
            }
        }
        // R4: each firefly takes the widest unused gap between gloom groups near its slot (15–85 % of the window).
        var used: [Bool] = Array(repeating: false, count: max(out.count - 1, 0))
        var merged: [(SpawnGroup, Int)] = []
        merged.reserveCapacity(out.count + lights.count + 1)
        for (i, g) in out.enumerated() { merged.append((g, i)) }
        var f2: Int = 0
        while f2 < lights.count {
            let want: Double = start + window * (0.15 + 0.7 * (Double(f2) + 0.5) / Double(lights.count))
            var bestJ: Int = -1
            var bestScore: Double = -1e9
            var g2: Int = 0
            while g2 + 1 < out.count {
                if !used[g2] {
                    let gapLength: Double = out[g2 + 1].time - out[g2].time
                    let mid: Double = (out[g2].time + out[g2 + 1].time) / 2
                    let score: Double = gapLength - 0.1 * abs(mid - want)
                    if score > bestScore {
                        bestScore = score
                        bestJ = g2
                    }
                }
                g2 += 1
            }
            var t: Double = want
            if bestJ >= 0 {
                used[bestJ] = true
                t = (out[bestJ].time + out[bestJ + 1].time) / 2
            }
            let it: Draft = lights[f2]
            merged.append((SpawnGroup(time: t, kind: .firefly, count: 1, u: it.u, formation: it.formation,
                                      speedScale: 1), out.count + f2))
            f2 += 1
        }
        merged.sort { (a: (SpawnGroup, Int), b: (SpawnGroup, Int)) -> Bool in
            if a.0.time != b.0.time { return a.0.time < b.0.time }
            return a.1 < b.1
        }
        var result: [SpawnGroup] = []
        result.reserveCapacity(merged.count + 1)
        if recipe.opener {
            result.append(SpawnGroup(time: 0, kind: .gloom(.murk), count: 1, u: 0.4...0.6, formation: .cluster,
                                     speedScale: recipe.speed, surface: openerSurface...openerSurface,
                                     startD: openerSurface - openerLead * recipe.speed))
        }
        for m in merged { result.append(m.0) }
        return result
    }

    /// R2: a recipe's cloud shadows between `start + cloudLead` and `start + span − cloudTail`, evenly spread with
    /// jitter; each slides in from a random edge, its width and drift ±20 % around the recipe's.
    static func clouds(for recipe: LevelRecipe, rng: inout SeededRandom, start: Double, span: Double) -> [CloudSpec] {
        let n: Int = max(recipe.clouds, 0)
        if n == 0 { return [] }
        let a: Double = start + cloudLead
        let b: Double = max(start + span - cloudTail, a)
        var out: [CloudSpec] = []
        out.reserveCapacity(n)
        var i: Int = 0
        while i < n {
            var x: Double = (Double(i) + 0.5 + rng.between(-0.3, 0.3)) / Double(n)
            x = min(max(x, 0), 1)
            let fromLeft: Bool = rng.unit() < 0.5
            let hw: Double = recipe.cloudWidth * (0.8 + 0.4 * rng.unit())
            let speed: Double = recipe.cloudSpeed * (0.8 + 0.4 * rng.unit())
            out.append(CloudSpec(time: a + (b - a) * x, fromLeft: fromLeft, halfWidth: hw, speed: speed,
                                 strength: recipe.cloudStrength))
            i += 1
        }
        return out
    }
}
