import CoreGraphics
import Foundation
import Testing
@testable import Glint

// MARK: - Core rules (Round 1): tuning maths, the band profile, RNG, DailySeed, LevelBook, every DawnSession rule,
// determinism, the pilot, and a 30-level smoke run with a strong pilot.
// Round 2: the crease shade, cloud shadows, the 135° edge, DawnStats by kind and by shade, the human-hinge pilot,
// achievements (each just below and at its threshold).
// Round 3: submerged travel and surfacing, the ±0.065 band core, the score-gated third star, Long Night's jump.
// Round 4: core-only firefly scorch with a dart, fireflies in the gaps, L1's quick opener, the first brute by L4.
// Round 5: every level opens at once (first surfacing ≤ 1 s), short early levels, pair fronts.

/// Shared drivers for Core tests and BalanceTests.
enum CoreHarness {
    /// One timed event.
    struct Timed {
        var time: Double
        var event: GameEvent
    }

    /// A one-off script.
    static func spec(_ groups: [SpawnGroup], duration: Double = 60, number: Int = 5) -> LevelSpec {
        return LevelSpec(number: number, world: LevelBook.world(of: number), title: "Test", duration: duration,
                         groups: groups)
    }

    static func group(_ kind: SpawnKind, at time: Double, count: Int = 1, u: ClosedRange<Double> = 0.5...0.5,
                      formation: Formation = .cluster, speed: Double = 1) -> SpawnGroup {
        return SpawnGroup(time: time, kind: kind, count: count, u: u, formation: formation, speedScale: speed)
    }

    /// Steps `s` for `seconds` at `dt`, the band from `band(t, session)`; `shut(t)` darkens the phone.
    static func run(_ s: DawnSession, seconds: Double, dt: Double = 1.0 / 120.0,
                    shut: (Double) -> Bool = { (_: Double) -> Bool in false },
                    band: (Double, DawnSession) -> Double) -> [Timed] {
        var out: [Timed] = []
        var t: Double = 0
        while t < seconds - 1e-9 && !s.isFinished {
            let b: Double = band(t, s)
            let input = MirrorInput(band: b, creaseGlow: Tuning.creaseGlow(band: b), isShut: shut(t), bandSpeed: 0)
            let events: [GameEvent] = s.step(dt: dt, input: input)
            for e in events { out.append(Timed(time: t, event: e)) }
            t += dt
        }
        return out
    }

    /// Starts on the first frame (band 0), then the phone is shut (no light at all).
    static func runDark(_ s: DawnSession, seconds: Double) -> [Timed] {
        return run(s, seconds: seconds, shut: { (t: Double) -> Bool in t > 0 }) { (_: Double, _: DawnSession) -> Double in
            return 0
        }
    }

    /// The band parked at `d` from the first frame.
    static func runParked(_ s: DawnSession, at d: Double, seconds: Double) -> [Timed] {
        return run(s, seconds: seconds) { (_: Double, _: DawnSession) -> Double in d }
    }

    /// A pilot plays `s` (the way GameController feeds a PilotSource: the previous frame's snapshot).
    static func play(_ s: DawnSession, skill: Double, pilotSeed: UInt64, dt: Double = 1.0 / 60.0,
                     cap: Double = 200) -> [GameEvent] {
        var pilot = PilotBrain(skill: skill, seed: pilotSeed)
        var out: [GameEvent] = []
        var t: Double = 0
        while !s.isFinished && t < cap {
            let input: MirrorInput = pilot.input(for: s.snapshot, dt: dt)
            out.append(contentsOf: s.step(dt: dt, input: input))
            t += dt
        }
        return out
    }

    static func pops(_ events: [Timed]) -> [Timed] {
        return events.filter { (e: Timed) -> Bool in
            if case .popped = e.event { return true }
            return false
        }
    }

    static func count(_ events: [Timed], _ match: (GameEvent) -> Bool) -> Int {
        var n: Int = 0
        for e in events where match(e.event) { n += 1 }
        return n
    }

    static func isEaten(_ e: GameEvent) -> Bool {
        if case .flowerEaten = e { return true }
        return false
    }

    static func isScorched(_ e: GameEvent) -> Bool {
        if case .fireflyScorched = e { return true }
        return false
    }
}

struct CoreTests {

    // MARK: Tuning

    @Test func angleMapsToTheBand() {
        #expect(abs(Tuning.band(angle: 80) - 0) < 1e-12)
        #expect(abs(Tuning.band(angle: 135) - 1) < 1e-12)
        #expect(abs(Tuning.band(angle: 145) - 1) < 1e-12)
        #expect(abs(Tuning.band(angle: 107.5) - 0.5) < 1e-12)
        #expect(abs(Tuning.band(angle: 129.5) - 0.9) < 1e-9)
        #expect(abs(Tuning.band(angle: 15) - Tuning.bandMin) < 1e-12)
        #expect(abs(Tuning.band(angle: 180) - 1) < 1e-12)
        #expect(abs(Tuning.band(angle: 67) - (-0.2)) < 1e-9)
        #expect(abs(Tuning.band(angle: Double.nan) - Tuning.bandMin) < 1e-12)
        #expect(abs(Tuning.angle(forBand: 0.5) - 107.5) < 1e-9)
        #expect(abs(Tuning.angle(forBand: 1) - 135) < 1e-9)
        #expect(abs(Tuning.angle(forBand: 0) - 80) < 1e-9)
        #expect(abs(Tuning.angle(forBand: 3) - 135) < 1e-9)
        #expect(abs(Tuning.band(angle: Tuning.angle(forBand: 0.37)) - 0.37) < 1e-9)
    }

    @Test func creaseGlowRisesFromShutToCrease() {
        #expect(abs(Tuning.creaseGlow(angle: 15) - 0) < 1e-12)
        #expect(abs(Tuning.creaseGlow(angle: 10) - 0) < 1e-12)
        #expect(abs(Tuning.creaseGlow(angle: 47.5) - 0.5) < 1e-12)
        #expect(abs(Tuning.creaseGlow(angle: 80) - 1) < 1e-12)
        #expect(abs(Tuning.creaseGlow(angle: 120) - 1) < 1e-12)
        #expect(abs(Tuning.creaseGlow(band: 0.3) - 1) < 1e-12)
    }

    @Test func intensityIsFlatThenSmooth() {
        #expect(abs(Tuning.intensity(d: 0.4, band: 0.4) - 1) < 1e-12)
        #expect(abs(Tuning.intensity(d: 0.45, band: 0.4) - 1) < 1e-9)
        #expect(abs(Tuning.intensity(d: 0.35, band: 0.4) - 1) < 1e-9)
        #expect(abs(Tuning.intensity(d: 0.5, band: 0.4) - 0) < 1e-9)
        #expect(abs(Tuning.intensity(d: 0.6, band: 0.4) - 0) < 1e-12)
        // Halfway down the edge (R3: 0.065…0.10) the smoothstep is exactly 0.5.
        #expect(abs(Tuning.intensity(distance: 0.0825) - 0.5) < 1e-9)
        // Symmetric and never rising with distance.
        var last: Double = 2
        var x: Double = 0
        while x < 0.1 {
            let a: Double = Tuning.intensity(d: 0.5 + x, band: 0.5)
            let b: Double = Tuning.intensity(d: 0.5 - x, band: 0.5)
            #expect(abs(a - b) < 1e-9)
            #expect(a <= last + 1e-12)
            #expect(a >= 0 && a <= 1)
            last = a
            x += 0.001
        }
    }

    @Test func intensityIsPaddedByTheRadius() {
        // A brute (r 0.085) is lit 0.034 further out than its centre.
        let r: Double = GloomSpec.of(.brute).radius
        #expect(abs(Tuning.intensity(d: 0.5 + 0.05 + 0.4 * r, radius: r, band: 0.5) - 1) < 1e-9)
        #expect(Tuning.intensity(d: 0.5 + 0.09, radius: r, band: 0.5) > 0.9)
        #expect(Tuning.intensity(d: 0.5 + 0.11, radius: 0, band: 0.5) < 1e-12)
    }

    @Test func multiplierAndLanes() {
        #expect(abs(Tuning.multiplier(chain: 0) - 1) < 1e-12)
        #expect(abs(Tuning.multiplier(chain: 1) - 1) < 1e-12)
        #expect(abs(Tuning.multiplier(chain: 2) - 1.25) < 1e-12)
        #expect(abs(Tuning.multiplier(chain: 13) - 4) < 1e-12)
        #expect(abs(Tuning.multiplier(chain: 40) - 4) < 1e-12)
        #expect(Tuning.lane(u: 0) == 0)
        #expect(Tuning.lane(u: 0.19) == 0)
        #expect(Tuning.lane(u: 0.2) == 1)
        #expect(Tuning.lane(u: 0.5) == 2)
        #expect(Tuning.lane(u: 0.999) == 4)
        #expect(Tuning.lane(u: 1) == 4)
        #expect(Tuning.lane(u: -3) == 0)
        #expect(abs(Tuning.laneCentre(2) - 0.5) < 1e-12)
    }

    @Test func starsByFlowers() {
        #expect(DawnSession.stars(flowersLeft: 5) == 3)
        #expect(DawnSession.stars(flowersLeft: 4) == 2)
        #expect(DawnSession.stars(flowersLeft: 3) == 2)
        #expect(DawnSession.stars(flowersLeft: 2) == 1)
        #expect(DawnSession.stars(flowersLeft: 1) == 1)
        #expect(DawnSession.stars(flowersLeft: 0) == 0)
        // R3: the third star also needs the level's score.
        #expect(DawnSession.stars(flowersLeft: 5, score: 1999, starScore: 2000) == 2)
        #expect(DawnSession.stars(flowersLeft: 5, score: 2000, starScore: 2000) == 3)
        #expect(DawnSession.stars(flowersLeft: 5, score: 10, starScore: 0) == 3)
        #expect(DawnSession.stars(flowersLeft: 4, score: 99_999, starScore: 2000) == 2)
        #expect(DawnSession.stars(flowersLeft: 2, score: 99_999, starScore: 2000) == 1)
        #expect(DawnSession.stars(flowersLeft: 0, score: 99_999, starScore: 0) == 0)
    }

    @Test func tuningMatchesTheDesign() {
        #expect(abs(Tuning.shutAngle - 15) < 1e-12)
        #expect(abs(Tuning.creaseAngle - 80) < 1e-12)
        #expect(abs(Tuning.edgeAngle - 135) < 1e-12)
        #expect(abs(Tuning.resumeAngle - 25) < 1e-12)
        #expect(abs(Tuning.shutDwell - 0.25) < 1e-12)
        #expect(abs(Tuning.bandCoreHalfWidth - 0.065) < 1e-12)
        #expect(abs(Tuning.bandEdgeHalfWidth - 0.10) < 1e-12)
        #expect(abs(Tuning.submergedSpeedFactor - 1.6) < 1e-12)
        #expect(Tuning.flowerCount == 5)
        #expect(abs(Tuning.chainWindow - 1.6) < 1e-12)
        #expect(abs(Tuning.sweepWindow - 0.35) < 1e-12)
        #expect(abs(Tuning.maxMultiplier - 4) < 1e-12)
        #expect(abs(Tuning.dragSpeedCap - 1.4) < 1e-12)
        #expect(abs(Tuning.creaseShade - 0.12) < 1e-12)
        #expect(abs(Tuning.resumeGrace - 0.6) < 1e-12)
    }

    // MARK: SeededRandom, DailySeed, GloomSpec

    @Test func seededRandomIsDeterministicAndInRange() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        var c = SeededRandom(seed: 43)
        var same: Bool = true
        var differs: Bool = false
        var i: Int = 0
        while i < 500 {
            let x: UInt64 = a.next()
            let y: UInt64 = b.next()
            let z: UInt64 = c.next()
            if x != y { same = false }
            if x != z { differs = true }
            i += 1
        }
        #expect(same)
        #expect(differs)
        var r = SeededRandom(seed: 7)
        i = 0
        while i < 2000 {
            let u: Double = r.unit()
            #expect(u >= 0 && u < 1)
            let k: Int = r.int(2...5)
            #expect(k >= 2 && k <= 5)
            let v: Double = r.range(0.25...0.75)
            #expect(v >= 0.25 && v <= 0.75)
            i += 1
        }
        let one: Int = r.int(3...3)
        #expect(one == 3)
    }

    @Test func dailySeedCountsUTCDays() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? utc.timeZone
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
            var c = DateComponents()
            c.year = y
            c.month = m
            c.day = d
            c.hour = h
            c.minute = min
            return utc.date(from: c) ?? Date(timeIntervalSince1970: 0)
        }
        #expect(DailySeed.day(for: date(2026, 1, 1, 0, 0)) == 0)
        #expect(DailySeed.day(for: date(2026, 1, 1, 23, 59)) == 0)
        #expect(DailySeed.day(for: date(2026, 1, 2, 0, 1)) == 1)
        #expect(DailySeed.day(for: date(2025, 12, 31, 23, 59)) == -1)
        #expect(DailySeed.day(for: date(2026, 10, 28, 12, 0)) == 300)
        #expect(DailySeed.seed(day: 300) == DailySeed.seed(day: 300))
        #expect(DailySeed.seed(day: 300) != DailySeed.seed(day: 301))
    }

    @Test func gloomSpecs() {
        for k in GloomKind.allCases {
            let s: GloomSpec = GloomSpec.of(k)
            #expect(s.kind == k)
            #expect(s.hp > 0 && s.speed > 0 && s.radius > 0 && s.points > 0)
        }
        #expect(GloomSpec.of(.murk).points == 10)
        #expect(GloomSpec.of(.wisp).points == 5)
        #expect(GloomSpec.of(.brute).points == 40)
        #expect(GloomSpec.of(.splitter).points == 15)
        #expect(GloomSpec.of(.hopper).points == 20)
        #expect(abs(GloomSpec.of(.murk).hp - 0.55) < 1e-12)
        #expect(abs(GloomSpec.of(.wisp).speed - 0.21) < 1e-12)
        #expect(GloomSpec.of(.brute).radius > GloomSpec.of(.murk).radius)
        #expect(GloomSpec.of(.wisp).radius < GloomSpec.of(.murk).radius)
    }

    // MARK: LevelBook

    @Test func levelBookShape() {
        #expect(LevelBook.count == 30)
        #expect(LevelBook.worldCount == 3)
        #expect(LevelBook.recipes.count == 30)
        #expect(LevelBook.worldName(1) == "Meadow")
        #expect(LevelBook.worldName(2) == "Rooftops")
        #expect(LevelBook.worldName(3) == "Harbour")
        #expect(LevelBook.levels(inWorld: 1) == 1...10)
        #expect(LevelBook.levels(inWorld: 2) == 11...20)
        #expect(LevelBook.levels(inWorld: 3) == 21...30)
        #expect(LevelBook.world(of: 1) == 1)
        #expect(LevelBook.world(of: 10) == 1)
        #expect(LevelBook.world(of: 11) == 2)
        #expect(LevelBook.world(of: 30) == 3)
        #expect(LevelBook.level(0).number == 1)
        #expect(LevelBook.level(99).number == 30)
        var titles: Set<String> = []
        var n: Int = 1
        while n <= 30 {
            let l: LevelSpec = LevelBook.level(n)
            #expect(l.number == n)
            #expect(l.world == LevelBook.world(of: n))
            #expect(l.duration >= 35 && l.duration <= 95)
            #expect(!l.title.isEmpty && l.title.count <= 18)
            titles.insert(l.title)
            #expect(!l.groups.isEmpty)
            var last: Double = -1
            for g in l.groups {
                #expect(g.time >= last - 1e-9)
                #expect(g.time >= 0 && g.time <= l.duration - LevelBook.endPad + 1e-6)
                #expect(g.count >= 1)
                #expect(g.u.lowerBound >= 0 && g.u.upperBound <= 1)
                #expect(g.speedScale > 0.5 && g.speedScale < 2)
                last = g.time
            }
            n += 1
        }
        #expect(titles.count == 30)
    }

    @Test func levelOneIsGentle() {
        let l: LevelSpec = LevelBook.level(1)
        #expect(l.title == "First Light")
        #expect(abs(l.duration - 35) < 1e-9)   // R5: was 60 s (founder: "slow in the beginning")
        // R5: a short, busy first sunrise: its murks plus the opener, which starts below 0.25 at t = 0.
        let recipe: LevelRecipe = LevelBook.recipes[0]
        #expect(l.duration <= 50)
        #expect(l.gloomCount == recipe.murks + 1)
        #expect(recipe.murks >= 25)
        #expect(l.kinds == [.murk])
        #expect(l.fireflyCount == 0)
        for g in l.groups {
            #expect(g.speedScale <= 0.9)
            #expect(g.count <= 2)
        }
        if let first = l.groups.first {
            #expect(abs(first.time) < 1e-12)
            #expect(abs((first.startD ?? -1) - (LevelBook.openerSurface - LevelBook.openerLead * recipe.speed)) < 1e-12)
            #expect(first.surface == LevelBook.openerSurface...LevelBook.openerSurface)
        }
    }

    /// R5 (founder, TestFlight build 2): action from second 1: on every level the first gloom surfaces ≤ 1 s after the
    /// first light, and the first five levels last 35–50 s.
    @Test func everyLevelStartsAtOnce() {
        var n: Int = 1
        while n <= LevelBook.count {
            let s = DawnSession(mode: .level(n), seed: 1)
            let events = CoreHarness.runParked(s, at: 0.3, seconds: 1.5)
            var first: Double = 99
            var depth: Double = 0
            for e in events {
                if case .surfaced(_, _, _, let d) = e.event, first > 90 {
                    first = e.time
                    depth = d
                }
            }
            #expect(first <= 1.0, "level \(n): first surfacing at \(first) s")
            #expect(abs(depth - LevelBook.openerSurface) < 0.01, "level \(n)")
            if n <= 5 { #expect(LevelBook.level(n).duration >= 35 && LevelBook.level(n).duration <= 50) }
            n += 1
        }
    }

    @Test func kindsArriveOnSchedule() {
        func first(_ kind: GloomKind) -> Int {
            var n: Int = 1
            while n <= 30 {
                if LevelBook.level(n).kinds.contains(kind) { return n }
                n += 1
            }
            return 99
        }
        func firstFirefly() -> Int {
            var n: Int = 1
            while n <= 30 {
                if LevelBook.level(n).fireflyCount > 0 { return n }
                n += 1
            }
            return 99
        }
        #expect(first(.wisp) == 3)
        #expect(first(.brute) == 2)
        #expect(first(.splitter) == 11)
        #expect(first(.hopper) == 14)
        #expect(firstFirefly() == 4)
        #expect(!LevelBook.level(3).kinds.contains(.brute))
        // R4: a first brute by L4 (after Dew's teaching brute).
        #expect(LevelBook.level(4).kinds.contains(.brute))
        #expect(LevelBook.level(5).kinds.contains(.brute))
        // Harbour has everything and fewer fireflies than Rooftops.
        let w3: [GloomKind] = LevelBook.level(25).kinds
        #expect(w3.count == GloomKind.allCases.count)
        var ff2: Int = 0
        var ff3: Int = 0
        for k in LevelBook.levels(inWorld: 2) { ff2 += LevelBook.level(k).fireflyCount }
        for k in LevelBook.levels(inWorld: 3) { ff3 += LevelBook.level(k).fireflyCount }
        #expect(ff3 < ff2)
    }

    @Test func worldsGetHarder() {
        var hp: [Double] = [0, 0, 0]
        var clouds: [Int] = [0, 0, 0]
        var width: [Double] = [0, 0, 0]
        var w: Int = 1
        while w <= 3 {
            for k in LevelBook.levels(inWorld: w) {
                let l: LevelSpec = LevelBook.level(k)
                hp[w - 1] += l.totalHP / 10
                clouds[w - 1] += l.clouds.count
                for c in l.clouds { width[w - 1] = max(width[w - 1], c.halfWidth) }
            }
            w += 1
        }
        #expect(hp[0] < hp[1] && hp[1] < hp[2])
        // R2: no clouds in Meadow; Harbour has more and wider ones than Rooftops.
        #expect(clouds[0] == 0)
        #expect(clouds[1] > 0 && clouds[2] > clouds[1])
        #expect(width[2] > width[1])
    }

    @Test func cloudsAreTelegraphedAndOnSchedule() {
        for n in LevelBook.levels(inWorld: 2) {
            let l: LevelSpec = LevelBook.level(n)
            #expect(!l.clouds.isEmpty)
            var last: Double = -1
            for c in l.clouds {
                #expect(c.time >= last - 1e-9)
                #expect(c.time >= LevelBook.firstSpawn + LevelBook.cloudLead - 1e-9)
                #expect(c.time <= l.duration - LevelBook.cloudTail + 1e-9)
                #expect(c.halfWidth >= 0.05 && c.halfWidth <= 0.2)
                #expect(c.speed >= 0.03 && c.speed <= 0.12)
                #expect(c.strength > 0 && c.strength <= 1)
                last = c.time
            }
        }
        #expect(LevelBook.level(10).clouds.isEmpty)
        #expect(!LevelBook.daily(day: 300).clouds.isEmpty)
        // R3: Long Night brings a cloud from wave 2 and two from wave 9.
        #expect(LevelBook.endlessRecipe(1).clouds == 0)
        #expect(LevelBook.endlessRecipe(2).clouds == 1)
        #expect(LevelBook.endlessRecipe(9).clouds == 2)
    }

    @Test func levelsAreDeterministic() {
        let a: LevelSpec = LevelBook.build(17)
        let b: LevelSpec = LevelBook.build(17)
        #expect(a == b)
        #expect(a == LevelBook.level(17))
        #expect(LevelBook.level(17) != LevelBook.level(18))
    }

    @Test func dailyIsSeededByTheDay() {
        let a: LevelSpec = LevelBook.daily(day: 300)
        let b: LevelSpec = LevelBook.daily(day: 300)
        let c: LevelSpec = LevelBook.daily(day: 301)
        #expect(a == b)
        #expect(a != c)
        #expect(abs(a.duration - 90) < 1e-12)
        #expect(a.number == 0)
        #expect(a.kinds.count == GloomKind.allCases.count)
    }

    @Test func endlessWavesEscalate() {
        let w1: LevelRecipe = LevelBook.endlessRecipe(1)
        #expect(w1.murks > 0 && w1.flocks == 0 && w1.brutes == 0 && w1.splitters == 0 && w1.hoppers == 0)
        #expect(w1.fireflies == 0)
        let w5: LevelRecipe = LevelBook.endlessRecipe(5)
        #expect(w5.flocks > 0 && w5.brutes > 0 && w5.splitters > 0 && w5.hoppers > 0 && w5.fireflies > 0)
        let w20: LevelRecipe = LevelBook.endlessRecipe(20)
        #expect(w20.murks > w5.murks && w20.speed > w5.speed)
        #expect(w20.speed <= 1.6 + 1e-12)
        var rng = SeededRandom(seed: 9)
        let groups: [SpawnGroup] = LevelBook.endlessWave(3, rng: &rng)
        for g in groups { #expect(g.time >= 0 && g.time <= Tuning.endlessWaveSeconds + 1e-9) }
    }

    // MARK: DawnSession: waiting and starting

    @Test func waitsForTheFirstLight() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.5)]))
        #expect(s.snapshot.phase == .waiting)
        let hidden = MirrorInput(band: -0.2, creaseGlow: 0.5)
        var i: Int = 0
        var any: Int = 0
        while i < 240 {
            let e: [GameEvent] = s.step(dt: 1.0 / 120.0, input: hidden)
            any += e.count
            i += 1
        }
        #expect(any == 0)
        #expect(s.snapshot.phase == .waiting)
        #expect(abs(s.snapshot.time) < 1e-12)
        #expect(s.snapshot.glooms.isEmpty)
        #expect(abs(s.snapshot.creaseGlow - 0.5) < 1e-12)
        let started: [GameEvent] = s.step(dt: 1.0 / 120.0, input: MirrorInput(band: 0.0, creaseGlow: 1))
        #expect(started.first == .started)
        #expect(s.snapshot.phase == .playing)
    }

    @Test func shutNeverStarts() {
        let s = DawnSession(spec: CoreHarness.spec([]))
        let shut = MirrorInput(band: 0.5, creaseGlow: 0, isShut: true)
        var i: Int = 0
        while i < 60 {
            _ = s.step(dt: 1.0 / 60.0, input: shut)
            i += 1
        }
        #expect(s.snapshot.phase == .waiting)
    }

    @Test func aDragNudgeStarts() {
        let s = DawnSession(spec: CoreHarness.spec([]))
        _ = s.step(dt: 1.0 / 60.0, input: MirrorInput(band: -0.2))
        _ = s.step(dt: 1.0 / 60.0, input: MirrorInput(band: -0.19))
        #expect(s.snapshot.phase == .waiting)
        let e: [GameEvent] = s.step(dt: 1.0 / 60.0, input: MirrorInput(band: -0.17))
        #expect(e.contains(.started))
        #expect(s.snapshot.phase == .playing)
    }

    @Test func zeroDtChangesNothing() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.1)]))
        _ = CoreHarness.runParked(s, at: 0.8, seconds: 1)
        let before: DawnSnapshot = s.snapshot
        let e: [GameEvent] = s.step(dt: 0, input: MirrorInput(band: 0.2))
        #expect(e.isEmpty)
        #expect(s.snapshot == before)
    }

    // MARK: Glooms

    @Test func gloomsEmergeFromTheCrease() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.5, u: 0.3...0.3)]))
        let events = CoreHarness.runParked(s, at: 0.9, seconds: 0.55)
        let emerged: Int = CoreHarness.count(events) { (e: GameEvent) -> Bool in
            if case .emerged(_, let kind, let u) = e { return kind == .murk && abs(u - 0.3) < 1e-9 }
            return false
        }
        #expect(emerged == 1)
        #expect(s.snapshot.glooms.count == 1)
        if let g = s.snapshot.glooms.first {
            #expect(g.d < 0 && g.d > -GloomSpec.of(.murk).radius - 1e-9)
            #expect(abs(g.radius - GloomSpec.of(.murk).radius) < 1e-12)
            #expect(abs(g.hp - g.maxHP) < 1e-9)
        }
    }

    @Test func gloomsNeverStopInTheLight() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.brute), at: 0.1)]))
        var lastD: Double = -1
        var litFrames: Int = 0
        var moving: Bool = true
        _ = CoreHarness.run(s, seconds: 6) { (_: Double, session: DawnSession) -> Double in
            if let g = session.snapshot.glooms.first {
                if g.lit > 0 {
                    litFrames += 1
                    if g.d <= lastD { moving = false }
                }
                lastD = g.d
            }
            return 0.3
        }
        #expect(litFrames > 100)
        #expect(moving)
    }

    @Test func aParkedBandPopsAMurk() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.5)]))
        let events = CoreHarness.runParked(s, at: 0.3, seconds: 15)
        let pops = CoreHarness.pops(events)
        #expect(pops.count == 1)
        if let p = pops.first, case .popped(_, let kind, _, let d, let chain, let points) = p.event {
            #expect(kind == .murk)
            #expect(chain == 1)
            #expect(points == 10)
            #expect(d < 0.3)
        }
        #expect(CoreHarness.count(events, CoreHarness.isEaten) == 0)
        #expect(s.snapshot.score == 10)
        #expect(s.snapshot.pops == 1)
    }

    @Test func aParkedBandCannotFinishABrute() {
        let parked = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.brute), at: 0.5)]))
        let a = CoreHarness.runParked(parked, at: 0.3, seconds: 25)
        #expect(CoreHarness.pops(a).isEmpty)
        #expect(CoreHarness.count(a, CoreHarness.isEaten) == 1)

        let tracked = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.brute), at: 0.5)]))
        let b = CoreHarness.run(tracked, seconds: 25) { (_: Double, session: DawnSession) -> Double in
            if let g = session.snapshot.glooms.first { return max(g.d, 0) }
            return 0
        }
        #expect(CoreHarness.pops(b).count == 1)
        #expect(CoreHarness.count(b, CoreHarness.isEaten) == 0)
    }

    @Test func leadingAHopperBeatsParking() {
        func popTime(_ s: DawnSession, _ band: (Double, DawnSession) -> Double) -> Double {
            let e = CoreHarness.run(s, seconds: 20, band: band)
            return CoreHarness.pops(e).first?.time ?? 99
        }
        let parked: Double = popTime(DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.hopper), at: 0.5)]))) {
            (_: Double, _: DawnSession) -> Double in 0.3
        }
        let led: Double = popTime(DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.hopper), at: 0.5)]))) {
            (_: Double, session: DawnSession) -> Double in
            if let g = session.snapshot.glooms.first { return g.d + (g.tension < 0.02 ? 0.06 : 0.02) }
            return 0
        }
        // R3: with the wider band a parked band never finishes a hopper; riding on it does.
        #expect(led < parked)
        #expect(led < 5)
    }

    @Test func hoppersHopAndTheLightStartlesThem() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.hopper), at: 0.2)]))
        var regular: Int = 0
        var skittish: Int = 0
        var landed: Bool = false
        let events = CoreHarness.run(s, seconds: 8, shut: { (t: Double) -> Bool in t > 0 && t < 4 }) {
            (t: Double, session: DawnSession) -> Double in
            if t < 4 { return 0 }
            // After 4 s in the dark, put the light right on the resting hopper.
            if let g = session.snapshot.glooms.first {
                if !landed && g.tension > 0.2 { landed = true }
                return landed ? g.d : -0.2
            }
            return -0.2
        }
        for e in events {
            if case .hopped(_, _, _, let sk) = e.event {
                if sk { skittish += 1 } else { regular += 1 }
            }
        }
        #expect(regular >= 2)
        #expect(skittish >= 1)
    }

    @Test func splittersPopIntoFlungWisps() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.splitter), at: 0.5)]))
        var lastSplitterD: Double = -1
        var seenWisps: Bool = false
        var flung: Bool = true
        let events = CoreHarness.run(s, seconds: 12) { (_: Double, session: DawnSession) -> Double in
            var wisps: Int = 0
            for g in session.snapshot.glooms {
                if g.kind == .splitter { lastSplitterD = g.d }
                if g.kind == .wisp { wisps += 1 }
            }
            if !seenWisps && wisps == 2 {
                seenWisps = true
                for g in session.snapshot.glooms where g.kind == .wisp {
                    if g.tension < 1 || g.d < lastSplitterD + Tuning.splitFling - 1e-6 { flung = false }
                }
            }
            return 0.45
        }
        var splits: Int = 0
        var wispEmerged: Int = 0
        var splitD: Double = -1
        for e in events {
            if case .split(_, let d) = e.event {
                splits += 1
                splitD = d
            }
            if case .emerged(_, let kind, _) = e.event, kind == .wisp { wispEmerged += 1 }
        }
        #expect(splits == 1)
        #expect(wispEmerged == Tuning.splitWispCount)
        #expect(splitD > 0)
        #expect(seenWisps)
        #expect(flung)
        #expect(s.stats.splits == 1)
    }

    // MARK: Flowers, fireflies, outcomes

    @Test func gloomsEatTheirLaneThenTheNearest() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.murk), at: 0.5, u: 0.5...0.5),
            CoreHarness.group(.gloom(.murk), at: 1.5, u: 0.5...0.5),
        ]))
        let events = CoreHarness.runDark(s, seconds: 20)
        var eaten: [Int] = []
        var left: [Int] = []
        var broken: Int = 0
        for e in events {
            if case .flowerEaten(let lane, let l, let by) = e.event {
                eaten.append(lane)
                left.append(l)
                #expect(by == .murk)
            }
            if case .chainBroken = e.event { broken += 1 }
        }
        #expect(eaten == [2, 1])
        #expect(left == [4, 3])
        #expect(broken == 0)
        #expect(s.snapshot.flowers == [true, false, false, true, true])
        #expect(s.snapshot.flowersLeft == 3)
    }

    @Test func theNightWinsWhenEveryFlowerIsGone() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.murk), at: 0.5, count: 5, u: 0.1...0.9, formation: .line),
            CoreHarness.group(.gloom(.murk), at: 0.6, count: 3),
        ]))
        let events = CoreHarness.runDark(s, seconds: 30)
        let nightWon: Bool = events.contains { (e: CoreHarness.Timed) -> Bool in e.event == .nightWins }
        #expect(nightWon)
        #expect(s.snapshot.phase == .lost)
        #expect(s.isFinished)
        #expect(s.snapshot.flowersLeft == 0)
        let after: [GameEvent] = s.step(dt: 1.0 / 60.0, input: MirrorInput(band: 0.5))
        #expect(after.isEmpty)
    }

    @Test func sunriseScoresTheFlowers() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.murk), at: 0.5),
            CoreHarness.group(.gloom(.murk), at: 9.5, u: 0.2...0.2),
        ], duration: 10))
        let events = CoreHarness.runParked(s, at: 0.3, seconds: 12)
        var sunrise: (Int, Int)? = nil
        for e in events {
            if case .sunrise(let stars, let bonus) = e.event { sunrise = (stars, bonus) }
        }
        #expect(sunrise?.0 == 3)
        #expect(sunrise?.1 == 200)
        #expect(s.snapshot.phase == .won)
        #expect(s.snapshot.glooms.isEmpty)
        // The late murk evaporated silently: one pop only.
        #expect(CoreHarness.pops(events).count == 1)
        #expect(s.snapshot.score == 10 + 200)
        #expect(abs(s.snapshot.sun - 1) < 1e-9)
    }

    @Test func chainAndMultiplier() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.murk), at: 0.5, count: 3, u: 0.2...0.8, formation: .stagger(0.5)),
        ]))
        let events = CoreHarness.runParked(s, at: 0.3, seconds: 12)
        var chains: [Int] = []
        var points: [Int] = []
        var ended: [Int] = []
        var swept: Int = 0
        for e in events {
            if case .popped(_, _, _, _, let c, let p) = e.event {
                chains.append(c)
                points.append(p)
            }
            if case .chainEnded(let was) = e.event { ended.append(was) }
            if case .swept = e.event { swept += 1 }
        }
        #expect(chains == [1, 2, 3])
        #expect(points == [10, 13, 15])
        #expect(ended == [3])
        #expect(swept == 0)
        #expect(s.snapshot.chain == 0)
        #expect(abs(s.snapshot.multiplier - 1) < 1e-12)
    }

    @Test func aFlockInOneSweep() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.wisp), at: 0.5, count: 4, u: 0.5...0.5),
        ]))
        let events = CoreHarness.runParked(s, at: 0.3, seconds: 6)
        var sweeps: [GameEvent] = []
        for e in events {
            if case .swept = e.event { sweeps.append(e.event) }
        }
        #expect(sweeps == [.swept(count: 3, bonus: 90), .swept(count: 4, bonus: 30)])
        // 5 × (1, 1.25, 1.5, 1.75) rounded = 5 + 6 + 8 + 9, plus 90 + 30.
        #expect(s.snapshot.score == 28 + 120)
        #expect(s.stats.bestSweep == 4)
        #expect(s.stats.sweeps == 1)
    }

    @Test func aScorchBreaksTheChain() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.murk), at: 0.5, u: 0.2...0.2),
            CoreHarness.group(.firefly, at: 0.5, u: 0.7...0.7),
        ]))
        let events = CoreHarness.runParked(s, at: 0.3, seconds: 8)
        var scorched: Int = 0
        var broken: [Int] = []
        for e in events {
            if case .fireflyScorched = e.event { scorched += 1 }
            if case .chainBroken(let was) = e.event { broken.append(was) }
        }
        #expect(scorched == 1)
        #expect(broken == [1])
        #expect(s.snapshot.fireflies.isEmpty)
    }

    @Test func aQuickSweepSparesAFirefly() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.firefly, at: 0.5)]))
        var maxScorch: Double = 0
        let events = CoreHarness.run(s, seconds: 7) { (t: Double, session: DawnSession) -> Double in
            if let f = session.snapshot.fireflies.first { maxScorch = max(maxScorch, f.scorch) }
            if t < 0.05 { return 0 }
            if t < 5 { return -0.2 }
            return min(-0.2 + (t - 5) * 1.6, 1)
        }
        #expect(CoreHarness.count(events, CoreHarness.isScorched) == 0)
        #expect(maxScorch > 0.05)
        #expect(maxScorch < 0.6)
    }

    @Test func fireflyEmergesAndGetsAHint() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.firefly, at: 0.5),
            CoreHarness.group(.firefly, at: 1.0),
        ]))
        let events = CoreHarness.runParked(s, at: 0.9, seconds: 2)
        var emerged: Int = 0
        var hints: Int = 0
        for e in events {
            if case .fireflyEmerged = e.event { emerged += 1 }
            if e.event == .hint(.spareTheFireflies) { hints += 1 }
        }
        #expect(emerged == 2)
        #expect(hints == 1)
        #expect(s.snapshot.fireflies.count == 2)
        if let f = s.snapshot.fireflies.first {
            #expect(f.d > -Tuning.fireflyRadius && f.d < 0.2)
            #expect(abs(f.u - 0.5) <= Tuning.fireflyWaveAmplitude + 1e-9)
        }
    }

    @Test func aFireflyReplantsALostFlower() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.murk), at: 0.5, u: 0.5...0.5),
            CoreHarness.group(.firefly, at: 0.5, u: 0.5...0.5),
        ]))
        let events = CoreHarness.runDark(s, seconds: 20)
        var delivered: [GameEvent] = []
        for e in events {
            if case .fireflyDelivered = e.event { delivered.append(e.event) }
        }
        #expect(CoreHarness.count(events, CoreHarness.isEaten) == 1)
        #expect(delivered.count == 1)
        if let d = delivered.first, case .fireflyDelivered(_, let lane, let replanted, let points) = d {
            #expect(lane == 2)
            #expect(replanted)
            #expect(points == 0)
        }
        #expect(s.snapshot.flowersLeft == 5)
        #expect(s.stats.flowersReplanted == 1)
    }

    @Test func aFireflyBloomsWhenNothingIsLost() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.firefly, at: 0.5, u: 0.1...0.1)]))
        let events = CoreHarness.runDark(s, seconds: 20)
        var bloom: Bool = false
        for e in events {
            if case .fireflyDelivered(_, let lane, let replanted, let points) = e.event {
                bloom = lane == 0 && !replanted && points == Tuning.fireflyBloomPoints
            }
        }
        #expect(bloom)
        #expect(s.snapshot.score == Tuning.fireflyBloomPoints)
    }

    // MARK: Hints, telemetry, sun

    @Test func hintsFireOnceEach() {
        let script: [SpawnGroup] = [
            CoreHarness.group(.gloom(.murk), at: 0.2),
            CoreHarness.group(.gloom(.brute), at: 0.3),
            CoreHarness.group(.gloom(.brute), at: 0.4),
            CoreHarness.group(.gloom(.splitter), at: 0.5, count: 2, formation: .line),
            CoreHarness.group(.gloom(.hopper), at: 0.6, count: 2, formation: .line),
            CoreHarness.group(.firefly, at: 0.7),
            CoreHarness.group(.firefly, at: 0.8),
        ]
        func hints(_ number: Int) -> [HintID] {
            let s = DawnSession(spec: CoreHarness.spec(script, number: number))
            let events = CoreHarness.runParked(s, at: 0.95, seconds: 1)
            var out: [HintID] = []
            for e in events {
                if case .hint(let h) = e.event { out.append(h) }
            }
            return out
        }
        #expect(hints(1) == [.lightTheShadows, .followTheBigOnes, .splitters, .hoppers, .spareTheFireflies])
        #expect(hints(2) == [.followTheBigOnes, .splitters, .hoppers, .spareTheFireflies])
    }

    @Test func telemetryAndSun() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.brute), at: 0.1)], duration: 40))
        _ = CoreHarness.run(s, seconds: 20) { (_: Double, session: DawnSession) -> Double in
            if let g = session.snapshot.glooms.first { return max(g.d, 0) }
            return 0
        }
        // 20 s in: the brute may have popped (tracked), the sun is half up.
        #expect(abs(s.snapshot.sun - 0.5) < 0.01)
        #expect(abs(s.snapshot.time - 20) < 0.01)

        let t = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.brute), at: 0.1)], duration: 40))
        _ = CoreHarness.runParked(t, at: 0.25, seconds: 4)
        let tel: Telemetry = t.snapshot.telemetry
        #expect(tel.litCount == 1)
        #expect(tel.burnRate > 0.5 && tel.burnRate <= 1 + 1e-9)
        if let g = t.snapshot.glooms.first {
            #expect(abs(tel.danger - max(g.d, 0)) < 1e-9)
            #expect(g.lit > 0.5)
            #expect(g.hp < g.maxHP)
        }
        #expect(abs(t.snapshot.band - 0.25) < 1e-12)
    }

    // MARK: Modes

    @Test func endlessWavesComeAndTheSunNeverRises() {
        let s = DawnSession(mode: .endless, seed: 5)
        #expect(s.spec == nil)
        let events = CoreHarness.play(s, skill: 1, pilotSeed: 3, cap: 65)
        var waves: [Int] = []
        for e in events {
            if case .waveUp(let n) = e { waves.append(n) }
            if case .sunrise = e { Issue.record("Long Night never rises") }
        }
        #expect(waves == [2, 3])
        #expect(s.wave == 3)
        #expect(!s.isFinished)
        #expect(abs(s.snapshot.sun - s.snapshot.time / Tuning.endlessSunSeconds) < 1e-9)
    }

    @Test func dailyUsesTheDaySeedAndScoresWithoutStars() {
        let a = DawnSession(mode: .daily(day: 300), seed: 1)
        let b = DawnSession(mode: .daily(day: 300), seed: 999)
        #expect(a.seed == DailySeed.seed(day: 300))
        #expect(a.seed == b.seed)
        #expect(a.queue == b.queue)
        #expect(abs(a.duration - 90) < 1e-12)
        _ = CoreHarness.play(a, skill: 1, pilotSeed: 8, cap: 120)
        #expect(a.isFinished)
        // A daily sunrise always gives 0 stars (a tiny daily script, parked band).
        let tiny = DawnSession(mode: .daily(day: 300),
                               spec: CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.5)], duration: 10),
                               seed: 1)
        let events = CoreHarness.runParked(tiny, at: 0.3, seconds: 12)
        var stars: Int = -1
        var bonus: Int = -1
        for e in events {
            if case .sunrise(let st, let b) = e.event {
                stars = st
                bonus = b
            }
        }
        #expect(tiny.snapshot.phase == .won)
        #expect(stars == 0)
        #expect(bonus == 200)
    }

    @Test func sameSeedSameInputsSameEvents() {
        func record(_ seed: UInt64) -> ([GameEvent], DawnSnapshot) {
            let s = DawnSession(mode: .level(23), seed: seed)
            let e: [GameEvent] = CoreHarness.play(s, skill: 0.7, pilotSeed: 11, cap: 40)
            return (e, s.snapshot)
        }
        let a = record(77)
        let b = record(77)
        let c = record(78)
        #expect(a.0 == b.0)
        #expect(a.1 == b.1)
        #expect(a.0.count > 50)
        #expect(a.0 != c.0)
    }

    @Test func subStepsMatchFineSteps() {
        let coarse = DawnSession(mode: .level(6), seed: 4)
        _ = CoreHarness.run(coarse, seconds: 12, dt: 1.0 / 30.0) { (_: Double, _: DawnSession) -> Double in 0.25 }
        let fine = DawnSession(mode: .level(6), seed: 4)
        _ = CoreHarness.run(fine, seconds: 12, dt: 1.0 / 120.0) { (_: Double, _: DawnSession) -> Double in 0.25 }
        #expect(abs(coarse.snapshot.time - fine.snapshot.time) < 1e-6)
        #expect(abs(coarse.snapshot.pops - fine.snapshot.pops) <= 1)
        #expect(abs(coarse.snapshot.glooms.count - fine.snapshot.glooms.count) <= 1)
    }

    // MARK: R2: the crease shade and cloud shadows

    /// A cloud covering u 0.05…0.95 over the band from ~2.7 s to ~7 s (slides in from the left at 0.2 u/s).
    private static let wideCloud: [CloudSpec] = [
        CloudSpec(time: 0.1, fromLeft: true, halfWidth: 0.45, speed: 0.2, strength: 1),
    ]

    @Test func theCreaseShadeGetsNoLight() {
        #expect(Tuning.isShaded(d: 0.11))
        #expect(!Tuning.isShaded(d: 0.12))
        #expect(Tuning.isShaded(d: -0.05))
        #expect(abs(Tuning.intensity(d: 0.1, band: 0.1)) < 1e-12)
        #expect(abs(Tuning.intensity(d: 0.2, band: 0.2) - 1) < 1e-12)
        #expect(abs(Tuning.intensity(d: 0.1, radius: 0.05, band: 0.1)) < 1e-12)
        #expect(abs(Tuning.unshadedIntensity(d: 0.1, radius: 0.05, band: 0.1) - 1) < 1e-12)

        // A band held in the shade can't pop a murk: it surfaces, crosses the band's edge too fast, and eats.
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.5)]))
        var litInShade: Bool = false
        let events = CoreHarness.run(s, seconds: 15) { (_: Double, session: DawnSession) -> Double in
            for g in session.snapshot.glooms where g.d < Tuning.creaseShade && g.lit > 0 { litInShade = true }
            return 0.05
        }
        #expect(!litInShade)
        #expect(CoreHarness.pops(events).isEmpty)
        #expect(CoreHarness.count(events, CoreHarness.isEaten) == 1)
        #expect(s.stats.creaseBlockedSeconds > 0.5)
    }

    @Test func cloudFactorMaths() {
        let one: [ShadeState] = [ShadeState(id: 1, u: 0.5, halfWidth: 0.1, strength: 1)]
        #expect(abs(Tuning.cloudFactor(u: 0.5, shades: one)) < 1e-12)
        #expect(abs(Tuning.cloudFactor(u: 0.58, shades: one)) < 1e-12)
        #expect(abs(Tuning.cloudFactor(u: 0.6, shades: one) - 0.5) < 1e-9)
        #expect(abs(Tuning.cloudFactor(u: 0.6 + Tuning.cloudEdge / 2, shades: one) - 1) < 1e-9)
        #expect(abs(Tuning.cloudFactor(u: 0.9, shades: one) - 1) < 1e-12)
        #expect(abs(Tuning.cloudFactor(u: 0.5, shades: []) - 1) < 1e-12)
        let half: [ShadeState] = [ShadeState(id: 1, u: 0.5, halfWidth: 0.1, strength: 0.5)]
        #expect(abs(Tuning.cloudFactor(u: 0.5, shades: half) - 0.5) < 1e-12)
        let two: [ShadeState] = [ShadeState(id: 1, u: 0.5, halfWidth: 0.1, strength: 0.5),
                                 ShadeState(id: 2, u: 0.5, halfWidth: 0.2, strength: 0.5)]
        #expect(abs(Tuning.cloudFactor(u: 0.5, shades: two) - 0.25) < 1e-12)
    }

    @Test func aCloudKeepsAGloomSafe() {
        let s = DawnSession(spec: LevelSpec(number: 15, world: 2, title: "Test", duration: 60,
                                            groups: [CoreHarness.group(.gloom(.murk), at: 0.5)],
                                            clouds: CoreTests.wideCloud))
        var shadeFrames: Int = 0
        var drifted: Bool = true
        var lastU: Double = -9
        var shapeOK: Bool = true
        let events = CoreHarness.run(s, seconds: 15) { (_: Double, session: DawnSession) -> Double in
            if let c = session.snapshot.shades.first {
                shadeFrames += 1
                if c.u < lastU { drifted = false }
                lastU = c.u
                if abs(c.halfWidth - 0.45) > 1e-12 || abs(c.strength - 1) > 1e-12 { shapeOK = false }
            }
            return 0.3
        }
        #expect(shadeFrames > 900 && shadeFrames < 1300)
        #expect(drifted)
        #expect(shapeOK)
        #expect(CoreHarness.pops(events).isEmpty)
        #expect(CoreHarness.count(events, CoreHarness.isEaten) == 1)
        #expect(s.stats.cloudBlockedSeconds > 0.5)
        #expect(s.stats.cloudedGlooms == 1)
        #expect(s.stats.eatenAfterCloud == 1)
        #expect(s.stats.eaten(by: .murk) == 1)
        #expect(s.stats.worstKind == .murk)
        #expect(s.stats.clouds == 1)
        #expect(s.snapshot.shades.isEmpty)
    }

    @Test func aCloudSparesAFirefly() {
        let clear = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.firefly, at: 0.5)]))
        let a = CoreHarness.runParked(clear, at: 0.3, seconds: 8)
        #expect(CoreHarness.count(a, CoreHarness.isScorched) == 1)
        let cloudy = DawnSession(spec: LevelSpec(number: 15, world: 2, title: "Test", duration: 60,
                                                 groups: [CoreHarness.group(.firefly, at: 0.5)],
                                                 clouds: CoreTests.wideCloud))
        let b = CoreHarness.runParked(cloudy, at: 0.3, seconds: 8)
        #expect(CoreHarness.count(b, CoreHarness.isScorched) == 0)
    }

    @Test func statsCountByKind() {
        let s = DawnSession(spec: CoreHarness.spec([
            CoreHarness.group(.gloom(.murk), at: 0.5, u: 0.1...0.1),
            CoreHarness.group(.gloom(.wisp), at: 0.5, count: 2, u: 0.9...0.9),
        ]))
        _ = CoreHarness.runDark(s, seconds: 15)
        #expect(s.stats.eaten(by: .murk) == 1)
        #expect(s.stats.eaten(by: .wisp) == 2)
        #expect(s.stats.eaten(by: .brute) == 0)
        #expect(s.stats.worstKind == .wisp)
        #expect(s.stats.flowersEaten == 3)

        let p = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.brute), at: 0.5)]))
        _ = CoreHarness.run(p, seconds: 25) { (_: Double, session: DawnSession) -> Double in
            if let g = session.snapshot.glooms.first { return max(g.d, PilotBrain.minAim) }
            return PilotBrain.minAim
        }
        #expect(p.stats.brutesPopped == 1)
        #expect(p.stats.popsBy[.brute] == 1)
        #expect(p.stats.score == p.snapshot.score)
        #expect(p.stats.worstKind == nil)
    }

    @Test func levelsFromRooftopsBringClouds() {
        let s = DawnSession(mode: .level(12), seed: 3)
        var seen: Bool = false
        _ = CoreHarness.run(s, seconds: 60, dt: 1.0 / 60.0) { (_: Double, session: DawnSession) -> Double in
            if !session.snapshot.shades.isEmpty { seen = true }
            return 0.9
        }
        #expect(seen)
        #expect(s.cloudQueue.count == LevelBook.level(12).clouds.count)
    }

    // MARK: R3: submerged travel, surfacing, the score star

    private static func surfacing(_ depth: Double) -> SpawnGroup {
        var g: SpawnGroup = CoreHarness.group(.gloom(.murk), at: 0.5)
        g.surface = depth...depth
        return g
    }

    @Test func gloomsTravelSubmergedAndSurface() {
        let s = DawnSession(spec: CoreHarness.spec([CoreTests.surfacing(0.4)]))
        var sawSubmerged: Bool = false
        var litWhileSubmerged: Bool = false
        let events = CoreHarness.run(s, seconds: 20) { (_: Double, session: DawnSession) -> Double in
            for g in session.snapshot.glooms where g.submerged {
                sawSubmerged = true
                if g.lit > 0 { litWhileSubmerged = true }
                if abs(g.surfaceD - 0.4) > 1e-9 { litWhileSubmerged = true }
            }
            return 0.2
        }
        var surfacedAt: Double = -1
        for e in events {
            if case .surfaced(_, let kind, _, let d) = e.event {
                #expect(kind == .murk)
                #expect(d >= 0.4 && d < 0.41)
                surfacedAt = e.time
            }
        }
        // (0.4 + 0.05) / (0.1 × 1.6) ≈ 2.8 s after it emerged at 0.5 s.
        #expect(abs(surfacedAt - 3.3) < 0.05)
        #expect(sawSubmerged)
        #expect(!litWhileSubmerged)
        // It travelled under the band parked at 0.2 and surfaced beyond it: never popped.
        #expect(CoreHarness.pops(events).isEmpty)
        #expect(CoreHarness.count(events, CoreHarness.isEaten) == 1)
        #expect(s.stats.submergedBlockedSeconds > 0.5)
        #expect(s.stats.surfaced == 1)

        let deeper = DawnSession(spec: CoreHarness.spec([CoreTests.surfacing(0.4)]))
        let e2 = CoreHarness.runParked(deeper, at: 0.6, seconds: 20)
        #expect(CoreHarness.pops(e2).count == 1)
    }

    @Test func onlyScriptedGloomsSubmerge() {
        // No surface range (R1/R2 scripts): never submerged. Splitters' wisps and fireflies never submerge either.
        let plain = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.1)]))
        _ = CoreHarness.runParked(plain, at: 0.9, seconds: 0.5)
        #expect(plain.snapshot.glooms.first?.submerged == false)
        var split: SpawnGroup = CoreHarness.group(.gloom(.splitter), at: 0.5)
        split.surface = 0.3...0.3
        let s = DawnSession(spec: CoreHarness.spec([split, CoreHarness.group(.firefly, at: 0.5)]))
        var wispsSubmerged: Bool = false
        _ = CoreHarness.run(s, seconds: 12) { (_: Double, session: DawnSession) -> Double in
            for g in session.snapshot.glooms where g.kind == .wisp && g.submerged { wispsSubmerged = true }
            return 0.45
        }
        #expect(!wispsSubmerged)
        #expect(s.stats.splits == 1)
    }

    @Test func levelsAuthorSurfacingDepths() {
        var n: Int = 1
        var deep: Bool = false
        while n <= LevelBook.count {
            let l: LevelSpec = LevelBook.level(n)
            let top: Double = n <= 3 ? Tuning.surfaceMaxGentle : Tuning.surfaceMax
            // R4b: L1–3 give the third star for all five flowers alone (starScore 0); score bars from L4.
            if n <= 3 { #expect(l.starScore == 0) } else { #expect(l.starScore > 0) }
            for g in l.groups {
                switch g.kind {
                case .firefly:
                    #expect(g.surface.upperBound == 0)
                case .gloom(let k):
                    #expect(g.surface.lowerBound >= Tuning.surfaceMin - 1e-9)
                    #expect(g.surface.upperBound <= top + 1e-9)
                    if k == .wisp { #expect(g.surface.lowerBound == g.surface.upperBound) }
                    if k == .brute { #expect(g.surface.upperBound <= 0.3 + 1e-9) }
                    if g.surface.upperBound > 0.45 { deep = true }
                }
            }
            n += 1
        }
        #expect(deep)
        #expect(LevelBook.daily(day: 300).starScore == 0)
    }

    @Test func theThirdStarNeedsTheScore() {
        var spec: LevelSpec = CoreHarness.spec([CoreHarness.group(.gloom(.murk), at: 0.5)], duration: 10)
        spec.starScore = 5000
        let s = DawnSession(spec: spec)
        let events = CoreHarness.runParked(s, at: 0.3, seconds: 12)
        var stars: Int = -1
        for e in events {
            if case .sunrise(let st, _) = e.event { stars = st }
        }
        #expect(s.snapshot.flowersLeft == 5)
        #expect(stars == 2)
    }

    @Test func longNightJumpsAfterTheFirstWave() {
        let one: LevelRecipe = LevelBook.endlessRecipe(1)
        #expect(one.brutes == 0 && one.splitters == 0 && one.clouds == 0)
        #expect(abs(one.surfaceMax - Tuning.surfaceMaxGentle) < 1e-12)
        let two: LevelRecipe = LevelBook.endlessRecipe(2)
        #expect(two.brutes >= 1 && two.splitters >= 1 && two.flocks >= 1 && two.clouds >= 1)
        #expect(abs(two.surfaceMax - Tuning.surfaceMax) < 1e-12)
        #expect(two.murks > one.murks)
        let six: LevelRecipe = LevelBook.endlessRecipe(6)
        #expect(six.clouds == 1 && six.hoppers >= 1 && six.speed > two.speed && six.flockSize <= 6)
        #expect(LevelBook.endlessRecipe(40).speed <= 1.2 + 1e-12)
    }

    @Test func thePilotWaitsWhereAGloomWillSurface() {
        let shot = DawnSnapshot(mode: .level(5), phase: .playing, glooms: [
            GloomState(id: 1, kind: .murk, u: 0.5, d: 0.05, radius: 0.05, hp: 0.55, maxHP: 0.55, submerged: true,
                       surfaceD: 0.45),
        ])
        var p = PilotBrain(skill: 1, seed: 6)
        var i: Int = 0
        while i < 240 {
            _ = p.band(for: shot, dt: 1.0 / 120.0)
            i += 1
        }
        #expect(abs(p.position - 0.46) < 0.05)
        #expect(abs(PilotBrain.reachD(shot.glooms[0]) - 0.45) < 1e-12)
    }

    // MARK: R4: spareable fireflies

    @Test func onlyTheCoreScorchesAFirefly() {
        // The band rides just behind a firefly: it is in the soft edge (lit) but never in the core.
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.firefly, at: 0.5)]))
        var litFrames: Int = 0
        var maxScorch: Double = 0
        let events = CoreHarness.run(s, seconds: 10) { (t: Double, session: DawnSession) -> Double in
            if t < 0.05 { return 0 }
            guard let f = session.snapshot.fireflies.first else { return -0.2 }
            if f.lit > 0 { litFrames += 1 }
            maxScorch = max(maxScorch, f.scorch)
            return f.d > 0.2 ? f.d - 0.085 : -0.2
        }
        #expect(litFrames > 100)
        #expect(maxScorch < 1e-9)
        #expect(CoreHarness.count(events, CoreHarness.isScorched) == 0)
        #expect(abs(Tuning.fireflyScorchLimit - 0.6) < 1e-12)
        #expect(abs(Tuning.fireflyScorchDecay - 0.8) < 1e-12)
    }

    @Test func aFireflyDartsWhenTheLightTouchesIt() {
        // Light touches it at d ≈ 0.3 (the band jumps to 0.09 behind it and stays): it darts 0.08 out on top of its
        // drift, so in 0.35 s it travels ≈ 0.08 + 0.075 × 0.35 instead of ≈ 0.026.
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.firefly, at: 0.5)]))
        var parked: Double? = nil
        var d0: Double? = nil
        var t0: Double = 0
        var moved: Double = 0
        _ = CoreHarness.run(s, seconds: 8) { (t: Double, session: DawnSession) -> Double in
            if t < 0.05 { return 0 }
            guard let f = session.snapshot.fireflies.first else { return parked ?? -0.2 }
            if parked == nil && f.d >= 0.3 { parked = f.d - 0.09 }
            if parked != nil && d0 == nil && f.lit > 0 {
                d0 = f.d
                t0 = t
            }
            if let start = d0, t - t0 <= 0.35 + 1e-9 { moved = f.d - start }
            return parked ?? -0.2
        }
        #expect(d0 != nil)
        #expect(moved > 0.095)
    }

    @Test func firefliesFlyInTheGaps() {
        var n: Int = 4
        var between: Int = 0
        var total: Int = 0
        while n <= LevelBook.count {
            let l: LevelSpec = LevelBook.level(n)
            var gloomTimes: [Double] = []
            for g in l.groups {
                if case .gloom = g.kind { gloomTimes.append(g.time) }
            }
            for g in l.groups {
                if case .firefly = g.kind {
                    total += 1
                    var clash: Bool = false
                    for t in gloomTimes where abs(t - g.time) < 1e-6 { clash = true }
                    if !clash { between += 1 }
                }
            }
            n += 1
        }
        #expect(total > 50)
        #expect(between == total)
    }

    // MARK: R2: the human-hinge pilot

    @Test func theHumanHingeWobblesALowSkillHand() {
        let shot = DawnSnapshot(mode: .level(5), phase: .playing, glooms: [
            GloomState(id: 1, kind: .murk, u: 0.5, d: 0.4, radius: 0.05, hp: 0.5, maxHP: 0.55),
        ])
        func spread(_ skill: Double) -> Double {
            var p = PilotBrain(skill: skill, seed: 3)
            var lo: Double = 9
            var hi: Double = -9
            var i: Int = 0
            while i < 480 {
                let b: Double = p.band(for: shot, dt: 1.0 / 120.0)
                if i >= 240 {
                    lo = min(lo, b)
                    hi = max(hi, b)
                }
                i += 1
            }
            return hi - lo
        }
        #expect(spread(0) > 0.02)
        #expect(spread(1) < 0.015)
        #expect(abs(PilotBrain(skill: 0, seed: 1).hingeLag - 0.35) < 1e-12)
        #expect(abs(PilotBrain(skill: 1, seed: 1).hingeLag - 0.1) < 1e-12)
        #expect(abs(PilotBrain(skill: 0, seed: 1).jitterAmplitude - 0.05) < 1e-12)
        #expect(abs(PilotBrain(skill: 1, seed: 1).jitterAmplitude) < 1e-12)
        #expect(abs(PilotBrain(skill: 1, seed: 1).overshootChance) < 1e-12)
    }

    @Test func thePilotWaitsOutTheShades() {
        // Never aims into the crease shade.
        let low = DawnSnapshot(mode: .level(5), phase: .playing, glooms: [
            GloomState(id: 1, kind: .murk, u: 0.5, d: 0.02, radius: 0.05, hp: 0.55, maxHP: 0.55),
        ])
        var p = PilotBrain(skill: 1, seed: 4)
        var i: Int = 0
        while i < 240 {
            _ = p.band(for: low, dt: 1.0 / 120.0)
            i += 1
        }
        #expect(p.position > PilotBrain.minAim - 0.02)
        // A gloom under a cloud is less urgent than its twin in the clear.
        let shaded = GloomState(id: 1, kind: .murk, u: 0.2, d: 0.5, radius: 0.05, hp: 0.55, maxHP: 0.55)
        let clear = GloomState(id: 2, kind: .murk, u: 0.8, d: 0.5, radius: 0.05, hp: 0.55, maxHP: 0.55)
        let shades: [ShadeState] = [ShadeState(id: 9, u: 0.2, halfWidth: 0.1, strength: 1)]
        let q = PilotBrain(skill: 1, seed: 4)
        #expect(q.urgency(clear, in: [shaded, clear], shades: shades)
                > q.urgency(shaded, in: [shaded, clear], shades: shades) + 1)
    }

    // MARK: R2: achievements

    private func earned(_ stats: DawnStats = DawnStats(), mode: PlayMode = .level(5), outcome: SessionPhase = .lost,
                        stars: Int = 0, won: Set<Int> = []) -> Set<String> {
        return Set(Achievements.earned(stats: stats, mode: mode, outcome: outcome, progressStars: stars,
                                       levelsWon: won))
    }

    @Test func achievementTable() {
        #expect(Achievements.all.count == 10)
        let keys: [String] = Achievements.all.map { (a: AchievementDef) -> String in a.key }
        #expect(keys == ["firstlight", "sweep", "brute", "firefly", "chain4", "rooftops", "harbour", "allstars",
                         "daily", "longnight"])
        var points: Int = 0
        var ids: Set<String> = []
        for a in Achievements.all {
            #expect(a.id == "glint.ach." + a.key)
            #expect(!a.title.isEmpty && a.title.count <= 30)
            #expect(!a.blurb.isEmpty && a.detail == a.blurb)
            #expect(a.points > 0 && a.points <= 100)
            #expect(Achievements.earnedBlurbs[a.key] != nil)
            points += a.points
            ids.insert(a.id)
        }
        #expect(points == 435)
        #expect(ids.count == 10)
        #expect(Achievements.chain4Chain == 13)
        #expect(Achievements.allStarsTotal == 90)
        #expect(Achievements.find("brute")?.title == "The Bigger They Come")
        #expect(earned().isEmpty)
    }

    @Test func achievementThresholds() {
        let first: String = Achievements.firstLight.id
        #expect(earned(mode: .level(3), outcome: .won).contains(first))
        #expect(!earned(mode: .level(3), outcome: .lost).contains(first))
        #expect(!earned(mode: .daily(day: 300), outcome: .won).contains(first))

        var st = DawnStats()
        st.bestSweep = 2
        #expect(!earned(st).contains(Achievements.sweep.id))
        st.bestSweep = 3
        #expect(earned(st).contains(Achievements.sweep.id))

        st = DawnStats()
        #expect(!earned(st).contains(Achievements.brute.id))
        st.brutesPopped = 1
        #expect(earned(st).contains(Achievements.brute.id))

        st = DawnStats()
        #expect(!earned(st).contains(Achievements.firefly.id))
        st.flowersReplanted = 1
        #expect(earned(st).contains(Achievements.firefly.id))

        st = DawnStats()
        st.longestChain = 12
        #expect(!earned(st).contains(Achievements.chain4.id))
        st.longestChain = 13
        #expect(earned(st).contains(Achievements.chain4.id))

        #expect(!earned(won: Set(11...19)).contains(Achievements.rooftops.id))
        #expect(earned(won: Set(11...20)).contains(Achievements.rooftops.id))
        #expect(!earned(won: Set(21...29)).contains(Achievements.harbour.id))
        #expect(earned(won: Set(21...30)).contains(Achievements.harbour.id))
        #expect(!earned(stars: 89).contains(Achievements.allStars.id))
        #expect(earned(stars: 90).contains(Achievements.allStars.id))

        #expect(!earned(mode: .daily(day: 300), outcome: .playing).contains(Achievements.daily.id))
        #expect(earned(mode: .daily(day: 300), outcome: .lost).contains(Achievements.daily.id))
        #expect(earned(mode: .daily(day: 300), outcome: .won).contains(Achievements.daily.id))
        #expect(!earned(mode: .level(2), outcome: .won).contains(Achievements.daily.id))

        st = DawnStats()
        st.score = Achievements.nightWatchScore - 1
        #expect(!earned(st, mode: .endless, outcome: .lost).contains(Achievements.longNight.id))
        st.score = Achievements.nightWatchScore
        #expect(earned(st, mode: .endless, outcome: .lost).contains(Achievements.longNight.id))
        st.score = 50_000
        #expect(!earned(st, mode: .level(30), outcome: .won).contains(Achievements.longNight.id))
    }

    @Test func aRealSweepEarnsCleanSweep() {
        let s = DawnSession(spec: CoreHarness.spec([CoreHarness.group(.gloom(.wisp), at: 0.5, count: 4, u: 0.5...0.5)]))
        _ = CoreHarness.runParked(s, at: 0.3, seconds: 6)
        let ids: [String] = Achievements.earned(stats: s.stats, mode: s.mode, outcome: s.snapshot.phase,
                                                progressStars: 0, levelsWon: [])
        #expect(ids.contains(Achievements.sweep.id))
        #expect(!ids.contains(Achievements.brute.id))
    }

    // MARK: The pilot

    @Test func pilotIsPureAndDeterministic() {
        let shot = DawnSnapshot(mode: .level(5), phase: .playing, glooms: [
            GloomState(id: 1, kind: .murk, u: 0.5, d: 0.4, radius: 0.05, hp: 0.5, maxHP: 0.55),
            GloomState(id: 2, kind: .brute, u: 0.2, d: 0.2, radius: 0.085, hp: 3, maxHP: 3.6),
        ])
        var a = PilotBrain(skill: 0.4, seed: 5)
        var b = PilotBrain(skill: 0.4, seed: 5)
        var same: Bool = true
        var i: Int = 0
        while i < 300 {
            let x: Double = a.band(for: shot, dt: 1.0 / 60.0)
            let y: Double = b.band(for: shot, dt: 1.0 / 60.0)
            if x != y { same = false }
            i += 1
        }
        #expect(same)
    }

    @Test func pilotRespectsItsSpeedCap() {
        let shot = DawnSnapshot(mode: .level(5), phase: .playing, glooms: [
            GloomState(id: 1, kind: .murk, u: 0.5, d: 0.95, radius: 0.05, hp: 0.5, maxHP: 0.55),
        ])
        var p = PilotBrain(skill: 1, seed: 1)
        var last: Double = p.position
        var maxSpeed: Double = 0
        var i: Int = 0
        while i < 120 {
            let b: Double = p.band(for: shot, dt: 1.0 / 120.0)
            maxSpeed = max(maxSpeed, abs(b - last) * 120)
            last = b
            i += 1
        }
        #expect(maxSpeed <= 1.6 + 1e-6)
        #expect(maxSpeed > 1.2)
        #expect(abs(p.speedCap - 1.6) < 1e-12)
        #expect(abs(PilotBrain(skill: 0, seed: 1).speedCap - 0.9) < 1e-12)
        #expect(abs(PilotBrain(skill: 0, seed: 1).reaction - 0.35) < 1e-12)
        #expect(abs(PilotBrain(skill: 1, seed: 1).reaction - 0.08) < 1e-12)
    }

    @Test func pilotTracksAndSparesFireflies() {
        let chase = DawnSnapshot(mode: .level(5), phase: .playing, glooms: [
            GloomState(id: 1, kind: .murk, u: 0.5, d: 0.4, radius: 0.05, hp: 0.5, maxHP: 0.55),
        ])
        var p = PilotBrain(skill: 1, seed: 2)
        var i: Int = 0
        while i < 240 {
            _ = p.band(for: chase, dt: 1.0 / 120.0)
            i += 1
        }
        #expect(abs(p.position - 0.4) < 0.04)
        #expect(p.targetID == 1)

        let guarded = DawnSnapshot(mode: .level(5), phase: .playing, glooms: [
            GloomState(id: 1, kind: .murk, u: 0.5, d: 0.4, radius: 0.05, hp: 0.5, maxHP: 0.55),
        ], fireflies: [FireflyState(id: 9, u: 0.5, d: 0.42)])
        var q = PilotBrain(skill: 1, seed: 2)
        i = 0
        while i < 240 {
            _ = q.band(for: guarded, dt: 1.0 / 120.0)
            i += 1
        }
        #expect(abs(q.position - 0.42) >= q.fireflyMargin - 0.01)
    }

    @Test func pilotLetsTheLightIn() {
        let s = DawnSession(mode: .level(1), seed: 1)
        _ = CoreHarness.play(s, skill: 0.3, pilotSeed: 1, cap: 2)
        #expect(s.snapshot.phase == .playing)
    }

    /// Every level is won by a strong pilot (skill 1, session seed 1, pilot seed 8: the JS mirror's first seed).
    @Test func strongPilotWinsEveryLevel() {
        var n: Int = 1
        var lost: [Int] = []
        while n <= LevelBook.count {
            let s = DawnSession(mode: .level(n), seed: 1)
            _ = CoreHarness.play(s, skill: 1, pilotSeed: 8, cap: 120)
            if s.snapshot.phase != .won { lost.append(n) }
            n += 1
        }
        #expect(lost.isEmpty, "strong pilot lost levels \(lost)")
    }
}
