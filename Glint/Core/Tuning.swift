import CoreGraphics
import Foundation

// MARK: - Every gameplay number (GAME-DESIGN §3–§6)
//
// Core reads its numbers from here and nowhere else. Input reads the angle mapping (`band(angle:)`,
// `creaseGlow(angle:)`), Scene reads the band shape (`intensity`) and the radii (GloomSpec), Feedback reads nothing
// but events. Deviations from GAME-DESIGN's starting values are marked "R1" with the reason (design/notes/core-R1.md).

enum Tuning {

    // MARK: The hinge (GAME-DESIGN §3, §8)

    /// θ ≤ this is shut: no light, and (held `shutDwell`) the level pauses.
    static let shutAngle: Double = 15
    /// θ where the band leaves the crease (band centre d = 0).
    static let creaseAngle: Double = 80
    /// θ where the band reaches the flower edge (d = 1). The hinge only holds its position up to about here.
    static let edgeAngle: Double = 145
    /// A paused level resumes once θ ≥ this.
    static let resumeAngle: Double = 25
    /// Seconds θ must stay ≤ `shutAngle` before a level pauses.
    static let shutDwell: Double = 0.25
    /// Seconds of grace after a resume (glooms frozen, then fade back in).
    static let resumeGrace: Double = 0.6

    // MARK: The band (GAME-DESIGN §3)

    /// The band value when it is fully hidden in the crease (θ ≤ 67°).
    static let bandMin: Double = -0.2
    /// Full intensity within ± this of the band centre (floor d units).
    static let bandCoreHalfWidth: Double = 0.050
    /// Intensity falls (smoothstep) to 0 at ± this.
    static let bandEdgeHalfWidth: Double = 0.085
    /// HP burned per second at full intensity.
    static let burnRate: Double = 1.0
    /// Light is measured at the gloom's centre, moved toward the band by this share of its radius.
    static let litPadFraction: Double = 0.4

    // MARK: The phone fallback (GAME-DESIGN §3)

    /// The drag fallback's soft band speed cap (d units per second).
    static let dragSpeedCap: Double = 2.4

    // MARK: Flowers, score, chain (GAME-DESIGN §4–§5)

    static let flowerCount: Int = 5
    /// A pop within this many seconds of the last one extends the chain.
    static let chainWindow: Double = 1.6
    /// Each chain step adds this to the multiplier (`1 + step × (chain − 1)`).
    static let chainStep: Double = 0.25
    static let maxMultiplier: Double = 4
    /// Pops each within this many seconds of the previous one form a sweep run.
    static let sweepWindow: Double = 0.35
    /// A sweep run scores once it reaches this many pops.
    static let sweepMinimum: Int = 3
    /// Sweep bonus per popped gloom (+30 × the run: 90 at 3 pops, then +30 per further pop).
    static let sweepBonusPerPop: Int = 30
    /// Points per flower left at sunrise.
    static let flowerBonus: Int = 40

    // MARK: Fireflies (GAME-DESIGN §4)

    static let fireflySpeed: Double = 0.075
    /// Floor radius (for the light pad and the art).
    static let fireflyRadius: Double = 0.02
    /// Seconds of cumulative light that fizzle a firefly.
    static let fireflyScorchLimit: Double = 0.35
    /// Unlit, the scorch drains at this many seconds per second.
    static let fireflyScorchDecay: Double = 0.6
    /// Points when a firefly arrives and no flower is missing.
    static let fireflyBloomPoints: Int = 50
    /// The wavy drift in `u`: amplitude and frequency (Hz).
    static let fireflyWaveAmplitude: Double = 0.06
    static let fireflyWaveFrequency: Double = 0.35

    // MARK: Splitters (GAME-DESIGN §4)

    static let splitWispCount: Int = 2
    /// The wisps appear this much further out (d) than the splitter popped...
    static let splitFling: Double = 0.07
    /// ...and are flung outwards at this speed (d/s) for `splitFlingTime` seconds.
    static let splitFlingSpeed: Double = 0.30
    static let splitFlingTime: Double = 0.6
    /// The two wisps sit ± this in `u` from the splitter.
    static let splitSpreadU: Double = 0.06

    // MARK: Hoppers (GAME-DESIGN §4)

    /// Seconds of rest between hops (divided by the group's speed scale).
    static let hopperRest: Double = 0.9
    /// One hop's length (d) and duration (s).
    static let hopperHop: Double = 0.14
    static let hopperHopTime: Double = 0.22
    /// R1: lit while resting, the rest clock runs `1 + hurry × intensity` times as fast (shadows never stand still in
    /// the light: a hopper hops on through a parked band; a band that rides on it pops it about twice as fast).
    static let hopperLitHurry: Double = 2.0

    // MARK: Session

    /// The session sub-steps at most this long.
    static let maxSubstep: Double = 1.0 / 120.0
    /// A drag fallback starts the clock once the band moved this far from its first value.
    static let startNudge: Double = 0.02
    /// Spawns stay inside u in this margin.
    static let spawnUMin: Double = 0.03
    static let spawnUMax: Double = 0.97
    /// Long Night: a new wave every this many seconds.
    static let endlessWaveSeconds: Double = 30
    /// Long Night: `sun` reaches 1 (deepest night art) after this many seconds.
    static let endlessSunSeconds: Double = 600
    /// Today's Dawn lasts this long.
    static let dailyDuration: Double = 90

    // MARK: Mapping

    /// θ (degrees) → band centre: `(θ − creaseAngle) / (edgeAngle − creaseAngle)`, clamped `bandMin…1`.
    static func band(angle: Double) -> Double {
        if !angle.isFinite { return bandMin }
        let b: Double = (angle - creaseAngle) / (edgeAngle - creaseAngle)
        return min(max(b, bandMin), 1)
    }

    /// θ (degrees) → the crease glow 0…1: `(θ − shutAngle) / (creaseAngle − shutAngle)`, clamped.
    static func creaseGlow(angle: Double) -> Double {
        if !angle.isFinite { return 0 }
        let g: Double = (angle - shutAngle) / (creaseAngle - shutAngle)
        return min(max(g, 0), 1)
    }

    /// The inverse of `band(angle:)` (for the pilot, demos and the phone fallback's lever art).
    static func angle(forBand band: Double) -> Double {
        let b: Double = min(max(band, bandMin), 1)
        return creaseAngle + b * (edgeAngle - creaseAngle)
    }

    /// The crease glow that goes with a band value (1 once the band is out of the crease).
    static func creaseGlow(band: Double) -> Double {
        return creaseGlow(angle: angle(forBand: band))
    }

    /// 0…1 light at floor distance `d` from a band centred on `band`: 1 within `bandCoreHalfWidth`, smoothstep to 0
    /// at `bandEdgeHalfWidth`.
    static func intensity(d: Double, band: Double) -> Double {
        return intensity(distance: abs(d - band))
    }

    /// The band profile by distance from its centre (≥ 0).
    static func intensity(distance: Double) -> Double {
        let x: Double = abs(distance)
        if x <= bandCoreHalfWidth { return 1 }
        if x >= bandEdgeHalfWidth { return 0 }
        let t: Double = (bandEdgeHalfWidth - x) / (bandEdgeHalfWidth - bandCoreHalfWidth)
        return smoothstep(t)
    }

    /// The light on a body of `radius` centred at `d`: the band measured at its centre moved `litPadFraction ×
    /// radius` toward the band.
    static func intensity(d: Double, radius: Double, band: Double) -> Double {
        let gap: Double = abs(d - band) - litPadFraction * max(radius, 0)
        return intensity(distance: max(gap, 0))
    }

    /// The chain multiplier for a chain count (1 for 0 or 1).
    static func multiplier(chain: Int) -> Double {
        if chain <= 1 { return 1 }
        return min(1 + chainStep * Double(chain - 1), maxMultiplier)
    }

    /// The flower lane of a `u` (0…flowerCount − 1).
    static func lane(u: Double) -> Int {
        if !u.isFinite { return 0 }
        let raw: Double = (min(max(u, 0), 1) * Double(flowerCount)).rounded(.down)
        return min(max(Int(raw), 0), flowerCount - 1)
    }

    /// The centre `u` of a flower lane.
    static func laneCentre(_ lane: Int) -> Double {
        let l: Int = min(max(lane, 0), flowerCount - 1)
        return (Double(l) + 0.5) / Double(flowerCount)
    }

    /// 3t² − 2t³ on t clamped to 0…1.
    static func smoothstep(_ t: Double) -> Double {
        let x: Double = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }
}
