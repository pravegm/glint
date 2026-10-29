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
}

enum LevelBook {
    static let count: Int = 30
    static let worldCount: Int = 3
    static let levelsPerWorld: Int = 10

    /// Seconds into a level of the first spawn, and how long before sunrise the last one lands.
    static let firstSpawn: Double = 2.5
    static let endPad: Double = 8
    /// Clouds start this long after `start` and the last one appears this long before the end.
    static let cloudLead: Double = 6
    static let cloudTail: Double = 16

    // swiftlint:disable line_length
    static let recipes: [LevelRecipe] = [
        // World 1: Meadow. Murks, wisps (from 3), one teaching brute (2) then brutes (from 5), fireflies (from 4).
        LevelRecipe(title: "First Light", duration: 60, murks: 12, flocks: 0, flockSize: 0, brutes: 0, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.8, crowd: 1, pair: 0.0, front: 0.0, surfaceMin: 0.15, surfaceMax: 0.35, starScore: 300),
        LevelRecipe(title: "Dew", duration: 60, murks: 20, flocks: 0, flockSize: 0, brutes: 1, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.8, crowd: 2, pair: 0.0, front: 0.15, surfaceMin: 0.15, surfaceMax: 0.35, starScore: 600),
        LevelRecipe(title: "Ladder of Wisps", duration: 65, murks: 24, flocks: 3, flockSize: 5, brutes: 0, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.82, crowd: 3, pair: 0.0, front: 0.2, surfaceMin: 0.15, surfaceMax: 0.35, starScore: 1400),
        LevelRecipe(title: "Fireflies", duration: 65, murks: 28, flocks: 4, flockSize: 5, brutes: 0, splitters: 0, hoppers: 0, fireflies: 3, speed: 0.84, crowd: 3, pair: 0.0, front: 0.2, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 1900),
        LevelRecipe(title: "Big Feet", duration: 70, murks: 30, flocks: 4, flockSize: 5, brutes: 2, splitters: 0, hoppers: 0, fireflies: 3, speed: 0.86, crowd: 3, pair: 0.0, front: 0.2, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 2050),
        LevelRecipe(title: "Clover", duration: 70, murks: 66, flocks: 8, flockSize: 6, brutes: 3, splitters: 0, hoppers: 0, fireflies: 4, speed: 1.357, crowd: 4, pair: 0.0, front: 0.25, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5200),
        LevelRecipe(title: "Morning Hush", duration: 75, murks: 73, flocks: 8, flockSize: 6, brutes: 3, splitters: 0, hoppers: 0, fireflies: 4, speed: 1.014, crowd: 4, pair: 0.0, front: 0.25, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5450),
        LevelRecipe(title: "Buttercups", duration: 75, murks: 82, flocks: 10, flockSize: 6, brutes: 4, splitters: 0, hoppers: 0, fireflies: 5, speed: 1.171, crowd: 4, pair: 0.0, front: 0.25, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7050),
        LevelRecipe(title: "Long Shadows", duration: 80, murks: 88, flocks: 10, flockSize: 6, brutes: 6, splitters: 0, hoppers: 0, fireflies: 5, speed: 1.232, crowd: 4, pair: 0.0, front: 0.25, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7700),
        LevelRecipe(title: "Meadow Sunrise", duration: 85, murks: 104, flocks: 11, flockSize: 6, brutes: 7, splitters: 0, hoppers: 0, fireflies: 6, speed: 1.107, crowd: 5, pair: 0.0, front: 0.25, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 8450),
        // World 2: Rooftops. Splitters (from 11), hoppers (from 14), full-strength cloud shadows (3 per level).
        LevelRecipe(title: "Chimney Pots", duration: 75, murks: 52, flocks: 6, flockSize: 6, brutes: 3, splitters: 2, hoppers: 0, fireflies: 4, speed: 0.827, crowd: 4, pair: 0.2, front: 0.3, clouds: 3, cloudWidth: 0.07, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 3900),
        LevelRecipe(title: "Split Ends", duration: 75, murks: 56, flocks: 6, flockSize: 6, brutes: 3, splitters: 3, hoppers: 0, fireflies: 4, speed: 0.623, crowd: 4, pair: 0.2, front: 0.3, clouds: 3, cloudWidth: 0.072, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4400),
        LevelRecipe(title: "Slate Grey", duration: 80, murks: 59, flocks: 6, flockSize: 6, brutes: 3, splitters: 3, hoppers: 0, fireflies: 5, speed: 0.795, crowd: 5, pair: 0.2, front: 0.3, clouds: 3, cloudWidth: 0.074, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5100),
        LevelRecipe(title: "Hop Along", duration: 80, murks: 62, flocks: 6, flockSize: 6, brutes: 3, splitters: 2, hoppers: 2, fireflies: 4, speed: 0.748, crowd: 5, pair: 0.2, front: 0.3, clouds: 3, cloudWidth: 0.076, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4900),
        LevelRecipe(title: "Gutters", duration: 80, murks: 66, flocks: 7, flockSize: 6, brutes: 3, splitters: 3, hoppers: 2, fireflies: 5, speed: 0.607, crowd: 5, pair: 0.25, front: 0.3, clouds: 3, cloudWidth: 0.078, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5400),
        LevelRecipe(title: "Weathervane", duration: 85, murks: 66, flocks: 7, flockSize: 6, brutes: 4, splitters: 3, hoppers: 3, fireflies: 5, speed: 0.702, crowd: 5, pair: 0.25, front: 0.3, clouds: 3, cloudWidth: 0.08, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5450),
        LevelRecipe(title: "Pigeon Row", duration: 85, murks: 63, flocks: 7, flockSize: 6, brutes: 4, splitters: 4, hoppers: 3, fireflies: 5, speed: 0.607, crowd: 5, pair: 0.25, front: 0.3, clouds: 3, cloudWidth: 0.082, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5700),
        LevelRecipe(title: "Tin Roofs", duration: 90, murks: 70, flocks: 8, flockSize: 6, brutes: 4, splitters: 4, hoppers: 3, fireflies: 6, speed: 0.623, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.084, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6250),
        LevelRecipe(title: "Skylight", duration: 90, murks: 77, flocks: 8, flockSize: 6, brutes: 5, splitters: 4, hoppers: 4, fireflies: 6, speed: 0.607, crowd: 5, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.086, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6200),
        LevelRecipe(title: "Rooftop Dawn", duration: 95, murks: 80, flocks: 8, flockSize: 6, brutes: 5, splitters: 5, hoppers: 4, fireflies: 6, speed: 0.607, crowd: 6, pair: 0.3, front: 0.3, clouds: 3, cloudWidth: 0.088, cloudSpeed: 0.06, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7300),
        // World 3: Harbour. Everything, more and wider clouds, fewer fireflies.
        LevelRecipe(title: "Low Tide", duration: 85, murks: 55, flocks: 6, flockSize: 7, brutes: 2, splitters: 2, hoppers: 2, fireflies: 4, speed: 0.795, crowd: 5, pair: 0.35, front: 0.35, clouds: 4, cloudWidth: 0.09, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4550),
        LevelRecipe(title: "Rope and Rigging", duration: 85, murks: 56, flocks: 6, flockSize: 7, brutes: 3, splitters: 3, hoppers: 2, fireflies: 4, speed: 0.982, crowd: 5, pair: 0.35, front: 0.35, clouds: 4, cloudWidth: 0.093, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 4550),
        LevelRecipe(title: "Gull Cry", duration: 90, murks: 63, flocks: 7, flockSize: 7, brutes: 3, splitters: 3, hoppers: 3, fireflies: 4, speed: 0.686, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.096, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 5550),
        LevelRecipe(title: "Fog Bank", duration: 90, murks: 57, flocks: 7, flockSize: 7, brutes: 4, splitters: 4, hoppers: 3, fireflies: 4, speed: 0.607, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.099, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6100),
        LevelRecipe(title: "Lantern Row", duration: 90, murks: 69, flocks: 8, flockSize: 7, brutes: 4, splitters: 4, hoppers: 4, fireflies: 4, speed: 0.607, crowd: 6, pair: 0.4, front: 0.35, clouds: 5, cloudWidth: 0.102, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6800),
        LevelRecipe(title: "Lighthouse", duration: 95, murks: 64, flocks: 8, flockSize: 7, brutes: 5, splitters: 5, hoppers: 4, fireflies: 4, speed: 0.843, crowd: 6, pair: 0.45, front: 0.35, clouds: 5, cloudWidth: 0.105, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 6700),
        LevelRecipe(title: "Undertow", duration: 95, murks: 67, flocks: 8, flockSize: 7, brutes: 5, splitters: 5, hoppers: 5, fireflies: 4, speed: 0.655, crowd: 6, pair: 0.45, front: 0.35, clouds: 5, cloudWidth: 0.108, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 7150),
        LevelRecipe(title: "Night Ferry", duration: 95, murks: 70, flocks: 9, flockSize: 7, brutes: 6, splitters: 6, hoppers: 5, fireflies: 3, speed: 0.639, crowd: 6, pair: 0.45, front: 0.35, clouds: 5, cloudWidth: 0.111, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 8150),
        LevelRecipe(title: "Last Watch", duration: 95, murks: 75, flocks: 9, flockSize: 7, brutes: 6, splitters: 6, hoppers: 6, fireflies: 3, speed: 0.748, crowd: 6, pair: 0.5, front: 0.35, clouds: 5, cloudWidth: 0.114, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 9150),
        LevelRecipe(title: "Harbour Sunrise", duration: 95, murks: 72, flocks: 10, flockSize: 7, brutes: 7, splitters: 7, hoppers: 6, fireflies: 3, speed: 0.639, crowd: 6, pair: 0.5, front: 0.35, clouds: 5, cloudWidth: 0.117, cloudSpeed: 0.075, cloudStrength: 1.0, surfaceMin: 0.15, surfaceMax: 0.6, starScore: 8450),
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
                           surfaceMax: Tuning.surfaceMax)
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
                           surfaceMax: w == 1 ? Tuning.surfaceMaxGentle : Tuning.surfaceMax)
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
            case .brute: return 3.0
            case .splitter: return 1.3
            case .hopper: return 1.3
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
        var j: Int = 0
        while j < items.count {
            let bias: Double = lateBias(items[j].kind)
            items[j].key = rng.unit() * (1 - bias) + bias
            j += 1
        }
        items.sort { (a: Draft, c: Draft) -> Bool in
            if a.key != c.key { return a.key < c.key }
            return a.order < c.order
        }
        var total: Double = 0
        for it in items { total += cost(it.kind) * Double(it.count) }
        let window: Double = max(span - endPad, 0)
        var cum: Double = 0
        var out: [SpawnGroup] = []
        out.reserveCapacity(items.count)
        var prevX: Double = 0
        var prevTime: Double = start
        var prevKind: SpawnKind = .firefly
        for it in items {
            let c: Double = cost(it.kind) * Double(it.count)
            let mid: Double = (cum + c / 2) / max(total, 1e-9)
            cum += c
            // R2: a mixed front (the draw happens for every group after the first).
            var join: Bool = false
            if !out.isEmpty {
                let roll: Double = rng.unit()
                join = roll < recipe.front && !isBrute(it.kind) && !isBrute(prevKind)
            }
            // Density 0.7 + 0.6x over the window: F(x) = 0.7x + 0.3x², inverted.
            let x: Double = join ? prevX : (-0.7 + (0.49 + 1.2 * mid).squareRoot()) / 0.6
            let t: Double = join ? prevTime : start + window * x
            var scale: Double = recipe.speed * (0.95 + 0.1 * x)
            if case .firefly = it.kind { scale = 1 }
            out.append(SpawnGroup(time: t, kind: it.kind, count: it.count, u: it.u, formation: it.formation,
                                  speedScale: scale, surface: it.surface))
            prevX = x
            prevTime = t
            prevKind = it.kind
        }
        return out
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
