import Foundation

// MARK: - The shadow kinds (GAME-DESIGN §4) and the level data types (§6)

/// One kind's fixed numbers. `hp` is seconds of full light; `speed` is the creep in d units per second (before a
/// group's `speedScale`); `radius` is in floor d units.
struct GloomSpec: Equatable {
    let kind: GloomKind
    let hp: Double
    let speed: Double
    let radius: Double
    let points: Int

    /// R1: the brute's HP is 3.6 (GAME-DESIGN's 2.2 let a parked band finish it, against "parked light can't finish
    /// it": a parked band gives a brute about 3.1 s of light). Hopper `speed` is its mean speed (one hop per rest).
    static func of(_ kind: GloomKind) -> GloomSpec {
        switch kind {
        case .murk:
            return GloomSpec(kind: .murk, hp: 0.55, speed: 0.10, radius: 0.050, points: 10)
        case .wisp:
            return GloomSpec(kind: .wisp, hp: 0.12, speed: 0.21, radius: 0.030, points: 5)
        case .brute:
            return GloomSpec(kind: .brute, hp: 3.6, speed: 0.065, radius: 0.085, points: 40)
        case .splitter:
            return GloomSpec(kind: .splitter, hp: 0.7, speed: 0.09, radius: 0.060, points: 15)
        case .hopper:
            let mean: Double = Tuning.hopperHop / (Tuning.hopperRest + Tuning.hopperHopTime)
            return GloomSpec(kind: .hopper, hp: 0.8, speed: mean, radius: 0.050, points: 20)
        }
    }
}

/// What a spawn group brings.
enum SpawnKind: Equatable {
    case gloom(GloomKind)
    case firefly
}

/// How a group's members arrive. `cluster`: all at once, random u in the range. `line`: all at once, evenly spaced
/// in u. `stagger(s)`: one every s seconds, stepping evenly across the u range (a ladder).
enum Formation: Equatable {
    case cluster
    case line
    case stagger(Double)
}

/// One scripted spawn: `count` members of `kind` at `time` seconds into the level.
struct SpawnGroup: Equatable {
    var time: Double
    var kind: SpawnKind
    var count: Int
    var u: ClosedRange<Double>
    var formation: Formation
    var speedScale: Double
}

/// One sunrise: `groups` sorted by time.
struct LevelSpec: Equatable {
    var number: Int
    var world: Int
    var title: String
    var duration: Double
    var groups: [SpawnGroup]
}

extension LevelSpec {
    /// Glooms in the script (splitters' wisps not counted).
    var gloomCount: Int {
        var n: Int = 0
        for g in groups {
            if case .gloom = g.kind { n += g.count }
        }
        return n
    }

    /// Fireflies in the script.
    var fireflyCount: Int {
        var n: Int = 0
        for g in groups {
            if case .firefly = g.kind { n += g.count }
        }
        return n
    }

    /// Seconds of full light the script needs (splitters' wisps not counted).
    var totalHP: Double {
        var hp: Double = 0
        for g in groups {
            if case .gloom(let k) = g.kind { hp += GloomSpec.of(k).hp * Double(g.count) }
        }
        return hp
    }

    /// The gloom kinds that appear, in `GloomKind.allCases` order.
    var kinds: [GloomKind] {
        var seen: [GloomKind] = []
        for k in GloomKind.allCases {
            for g in groups {
                if case .gloom(let gk) = g.kind, gk == k {
                    seen.append(k)
                    break
                }
            }
        }
        return seen
    }
}
