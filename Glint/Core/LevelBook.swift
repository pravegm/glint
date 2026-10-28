import Foundation

// MARK: - The 30 sunrises, Today's Dawn and Long Night's waves (GAME-DESIGN §6)
//
// "Handcrafted by formula": each level is one row of `recipes` (what comes, how fast, how crowded), and
// `groups(for:rng:start:span:endPad:)` lays the row out on the clock, seeded by the level number, so a level is the
// same script on every device. The session then draws each member's exact `u` from its own seed.
//
// The layout keeps the load smooth: groups are shuffled (brutes and hoppers lean later), then placed by cumulative
// cost (seconds of attention each kind needs) along a density that rises from 0.7× to 1.3× of the level's average,
// so a level builds instead of spiking. The last spawns land `endPad` seconds before sunrise.
//
// Balance (design/notes/core-R1.md, BalanceTests prints GLINT-BAL): world 1 teaches (every pilot wins), world 2 costs
// a weak hand flowers from level 15, world 3 is lost by a weak hand and costs a decent one flowers; a strong pilot wins
// all 30.

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
}

enum LevelBook {
    static let count: Int = 30
    static let worldCount: Int = 3
    static let levelsPerWorld: Int = 10

    /// Seconds into a level of the first spawn, and how long before sunrise the last one lands.
    static let firstSpawn: Double = 2.5
    static let endPad: Double = 8

    // swiftlint:disable line_length
    static let recipes: [LevelRecipe] = [
        // World 1: Meadow. Murks, wisps (from 3), one teaching brute (2) then brutes (from 5), fireflies (from 4).
        LevelRecipe(title: "First Light", duration: 60, murks: 12, flocks: 0, flockSize: 0, brutes: 0, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.80, crowd: 1, pair: 0),
        LevelRecipe(title: "Dew", duration: 60, murks: 18, flocks: 0, flockSize: 0, brutes: 1, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.85, crowd: 2, pair: 0),
        LevelRecipe(title: "Ladder of Wisps", duration: 65, murks: 18, flocks: 3, flockSize: 4, brutes: 0, splitters: 0, hoppers: 0, fireflies: 0, speed: 0.90, crowd: 2, pair: 0),
        LevelRecipe(title: "Fireflies", duration: 65, murks: 20, flocks: 3, flockSize: 4, brutes: 0, splitters: 0, hoppers: 0, fireflies: 3, speed: 0.92, crowd: 2, pair: 0),
        LevelRecipe(title: "Big Feet", duration: 70, murks: 20, flocks: 3, flockSize: 5, brutes: 2, splitters: 0, hoppers: 0, fireflies: 3, speed: 0.95, crowd: 3, pair: 0),
        LevelRecipe(title: "Clover", duration: 70, murks: 24, flocks: 4, flockSize: 5, brutes: 2, splitters: 0, hoppers: 0, fireflies: 4, speed: 0.98, crowd: 3, pair: 0),
        LevelRecipe(title: "Morning Hush", duration: 75, murks: 26, flocks: 4, flockSize: 5, brutes: 3, splitters: 0, hoppers: 0, fireflies: 4, speed: 1.01, crowd: 3, pair: 0),
        LevelRecipe(title: "Buttercups", duration: 75, murks: 29, flocks: 5, flockSize: 5, brutes: 3, splitters: 0, hoppers: 0, fireflies: 5, speed: 1.04, crowd: 3, pair: 0),
        LevelRecipe(title: "Long Shadows", duration: 80, murks: 31, flocks: 5, flockSize: 6, brutes: 4, splitters: 0, hoppers: 0, fireflies: 5, speed: 1.07, crowd: 3, pair: 0),
        LevelRecipe(title: "Meadow Sunrise", duration: 85, murks: 35, flocks: 6, flockSize: 6, brutes: 4, splitters: 0, hoppers: 0, fireflies: 6, speed: 1.10, crowd: 4, pair: 0),
        // World 2: Rooftops. Splitters (from 11), hoppers (from 14), mixed flocks.
        LevelRecipe(title: "Chimney Pots", duration: 75, murks: 32, flocks: 4, flockSize: 5, brutes: 3, splitters: 6, hoppers: 0, fireflies: 4, speed: 1.10, crowd: 3, pair: 0.2),
        LevelRecipe(title: "Split Ends", duration: 75, murks: 32, flocks: 4, flockSize: 5, brutes: 3, splitters: 9, hoppers: 0, fireflies: 4, speed: 1.12, crowd: 3, pair: 0.3),
        LevelRecipe(title: "Slate Grey", duration: 80, murks: 38, flocks: 5, flockSize: 6, brutes: 4, splitters: 9, hoppers: 0, fireflies: 5, speed: 1.14, crowd: 3, pair: 0.3),
        LevelRecipe(title: "Hop Along", duration: 80, murks: 35, flocks: 4, flockSize: 6, brutes: 3, splitters: 6, hoppers: 6, fireflies: 4, speed: 1.14, crowd: 3, pair: 0.2),
        LevelRecipe(title: "Gutters", duration: 80, murks: 41, flocks: 5, flockSize: 6, brutes: 4, splitters: 9, hoppers: 6, fireflies: 5, speed: 1.16, crowd: 4, pair: 0.3),
        LevelRecipe(title: "Weathervane", duration: 85, murks: 48, flocks: 6, flockSize: 6, brutes: 5, splitters: 10, hoppers: 7, fireflies: 5, speed: 1.18, crowd: 4, pair: 0.3),
        LevelRecipe(title: "Pigeon Row", duration: 85, murks: 50, flocks: 7, flockSize: 6, brutes: 6, splitters: 11, hoppers: 8, fireflies: 5, speed: 1.20, crowd: 4, pair: 0.4),
        LevelRecipe(title: "Tin Roofs", duration: 90, murks: 54, flocks: 7, flockSize: 7, brutes: 7, splitters: 13, hoppers: 9, fireflies: 6, speed: 1.22, crowd: 4, pair: 0.4),
        LevelRecipe(title: "Skylight", duration: 90, murks: 57, flocks: 8, flockSize: 7, brutes: 7, splitters: 13, hoppers: 10, fireflies: 6, speed: 1.25, crowd: 4, pair: 0.4),
        LevelRecipe(title: "Rooftop Dawn", duration: 95, murks: 63, flocks: 8, flockSize: 7, brutes: 8, splitters: 14, hoppers: 11, fireflies: 6, speed: 1.28, crowd: 5, pair: 0.5),
        // World 3: Harbour. Everything, faster, denser, fewer fireflies.
        LevelRecipe(title: "Low Tide", duration: 85, murks: 52, flocks: 7, flockSize: 7, brutes: 7, splitters: 11, hoppers: 8, fireflies: 4, speed: 1.20, crowd: 4, pair: 0.4),
        LevelRecipe(title: "Rope and Rigging", duration: 85, murks: 54, flocks: 8, flockSize: 7, brutes: 8, splitters: 11, hoppers: 8, fireflies: 4, speed: 1.22, crowd: 4, pair: 0.4),
        LevelRecipe(title: "Gull Cry", duration: 90, murks: 57, flocks: 9, flockSize: 8, brutes: 8, splitters: 13, hoppers: 10, fireflies: 4, speed: 1.24, crowd: 5, pair: 0.5),
        LevelRecipe(title: "Fog Bank", duration: 90, murks: 60, flocks: 9, flockSize: 8, brutes: 9, splitters: 13, hoppers: 10, fireflies: 4, speed: 1.26, crowd: 5, pair: 0.5),
        LevelRecipe(title: "Lantern Row", duration: 90, murks: 62, flocks: 10, flockSize: 8, brutes: 9, splitters: 14, hoppers: 11, fireflies: 4, speed: 1.28, crowd: 5, pair: 0.5),
        LevelRecipe(title: "Lighthouse", duration: 95, murks: 62, flocks: 10, flockSize: 8, brutes: 9, splitters: 14, hoppers: 11, fireflies: 4, speed: 1.30, crowd: 5, pair: 0.5),
        LevelRecipe(title: "Undertow", duration: 95, murks: 64, flocks: 11, flockSize: 8, brutes: 10, splitters: 15, hoppers: 13, fireflies: 4, speed: 1.32, crowd: 5, pair: 0.6),
        LevelRecipe(title: "Night Ferry", duration: 95, murks: 67, flocks: 11, flockSize: 9, brutes: 11, splitters: 15, hoppers: 13, fireflies: 3, speed: 1.34, crowd: 6, pair: 0.6),
        LevelRecipe(title: "Last Watch", duration: 95, murks: 70, flocks: 12, flockSize: 9, brutes: 11, splitters: 17, hoppers: 14, fireflies: 3, speed: 1.36, crowd: 6, pair: 0.6),
        LevelRecipe(title: "Harbour Sunrise", duration: 95, murks: 68, flocks: 12, flockSize: 9, brutes: 10, splitters: 16, hoppers: 13, fireflies: 3, speed: 1.38, crowd: 6, pair: 0.6),
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

    /// Today's Dawn for `day` (days since 2026-01-01 UTC): a 90 s sunrise, about a late Rooftops level, seeded by
    /// the day. `number` is 0, `world` 2.
    static func daily(day: Int) -> LevelSpec {
        var rng = SeededRandom(seed: DailySeed.seed(day: day) ^ 0x5A5A_5A5A)
        let recipe: LevelRecipe = dailyRecipe(&rng)
        let groups: [SpawnGroup] = LevelBook.groups(for: recipe, rng: &rng, start: firstSpawn,
                                                    span: Tuning.dailyDuration - firstSpawn, endPad: endPad)
        return LevelSpec(number: 0, world: 2, title: recipe.title, duration: Tuning.dailyDuration, groups: groups)
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
        let groups: [SpawnGroup] = LevelBook.groups(for: recipe, rng: &rng, start: firstSpawn,
                                                    span: recipe.duration - firstSpawn, endPad: endPad)
        return LevelSpec(number: k, world: world(of: k), title: recipe.title, duration: recipe.duration, groups: groups)
    }

    static func dailyRecipe(_ rng: inout SeededRandom) -> LevelRecipe {
        let murks: Int = 46 + rng.int(0...6)
        let flocks: Int = 7 + rng.int(0...1)
        let brutes: Int = 6 + rng.int(0...1)
        let splitters: Int = 10 + rng.int(0...2)
        let hoppers: Int = 7 + rng.int(0...2)
        return LevelRecipe(title: "Today's Dawn", duration: Tuning.dailyDuration, murks: murks, flocks: flocks,
                           flockSize: 7, brutes: brutes, splitters: splitters, hoppers: hoppers, fireflies: 5,
                           speed: 1.2, crowd: 4, pair: 0.4)
    }

    /// Long Night's wave `n` (1, 2, …): more, faster, and new kinds as the night deepens (wisps from wave 2, brutes
    /// and fireflies from 3, splitters from 4, hoppers from 5).
    static func endlessRecipe(_ n: Int) -> LevelRecipe {
        let w: Int = max(n, 1)
        let k: Int = w - 1
        let flocks: Int = w >= 2 ? 1 + k / 2 : 0
        let brutes: Int = w >= 3 ? 1 + (k - 2) / 2 : 0
        let splitters: Int = w >= 4 ? 1 + Int((Double(k - 3) * 0.75).rounded(.down)) : 0
        let hoppers: Int = w >= 5 ? 1 + Int((Double(k - 4) * 0.6).rounded(.down)) : 0
        let fireflies: Int = w >= 3 ? (w % 2 == 1 ? 2 : 1) : 0
        return LevelRecipe(title: "Long Night", duration: Tuning.endlessWaveSeconds, murks: 8 + 2 * k,
                           flocks: flocks, flockSize: min(4 + k / 2, 9), brutes: brutes, splitters: splitters,
                           hoppers: hoppers, fireflies: fireflies, speed: min(0.95 + 0.04 * Double(k), 1.6),
                           crowd: min(2 + k / 2, 6), pair: min(0.1 * Double(k), 0.6))
    }

    /// Long Night's wave `n`, times relative to the wave's start (0…30 s).
    static func endlessWave(_ n: Int, rng: inout SeededRandom) -> [SpawnGroup] {
        return groups(for: endlessRecipe(n), rng: &rng, start: 0, span: Tuning.endlessWaveSeconds, endPad: 0)
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
    }

    private static func uRange(_ width: Double, _ rng: inout SeededRandom) -> ClosedRange<Double> {
        let w: Double = min(max(width, 0), 0.8)
        let c: Double = rng.between(0.1 + w / 2, 0.9 - w / 2)
        return (c - w / 2)...(c + w / 2)
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
        for it in items {
            let c: Double = cost(it.kind) * Double(it.count)
            let mid: Double = (cum + c / 2) / max(total, 1e-9)
            cum += c
            // Density 0.7 + 0.6x over the window: F(x) = 0.7x + 0.3x², inverted.
            let x: Double = (-0.7 + (0.49 + 1.2 * mid).squareRoot()) / 0.6
            let t: Double = start + window * x
            var scale: Double = recipe.speed * (0.95 + 0.1 * x)
            if case .firefly = it.kind { scale = 1 }
            out.append(SpawnGroup(time: t, kind: it.kind, count: it.count, u: it.u, formation: it.formation,
                                  speedScale: scale))
        }
        return out
    }
}
