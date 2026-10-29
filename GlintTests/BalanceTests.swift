import Foundation
import Testing
@testable import Glint

// MARK: - Headless balance playtest (Round 1)
//
// PilotBrain plays every level at skills 0.3 / 0.6 / 0.9 on GLINT_BAL_SEEDS seeds (default 3; session seed
// 1 + 7919 i, pilot seed session × 7 + 1), 60 Hz frames, the pilot fed the previous frame's snapshot the way
// GameController feeds a PilotSource. Every run is simulated once, in parallel, the first time a test asks, and the
// table is printed as one block:
//   GLINT-BAL level=<n> skill=<s> won=<k>/<seeds> flowers=<avg> score=<avg>
// R2 (design/notes/core-R2.md): the pilot has the human-hinge model, light skips the crease shade, clouds from L11.
// The JS mirror (design/notes/core-R1-sim) predicts, on 8 seeds: 0.3 wins every Meadow level (4.4–5 flowers),
// 75–100 % of Rooftops (2.3–4.3 flowers), 0–50 % of Harbour; 0.6 wins every Rooftops level losing ≤ 1 and 62–100 %
// of Harbour losing 1–2.6; 0.9 wins all 30 with 3★ on most seeds. Mid-level fields (0.6 pilot) hold 4–7 glooms from
// L8 on (Meadow 6–7 and a few Rooftops/Harbour openers sit near 3).
// The asserts are loose sanity only: levels 1–3 won by 0.3 every time, level 30 lost by 0.3 most of the time, every
// level won at least once by 0.9, and in Harbour the 0.9 hand keeps more flowers than the 0.3 hand.
// Each line also prints three=<runs with 3 stars> and field=<mean glooms on the field from 25 % to 90 % of the level>.
// R3 (design/notes/core-R3.md): glooms travel submerged to authored depths, the band core is ±0.065, the third star
// needs LevelSpec.starScore. A ParkedPilot (the band held at one d all level) must lose ≥ 2 flowers on L6 and L11 and
// fail L21, for d = 0.15, 0.25, 0.4, 0.6, 0.8 (the mirror: L6 loses 3–5, L11 and L21 lose all 5 at every d).

struct BalanceRun {
    var won: Bool
    var flowers: Int
    var score: Int
    var eaten: Int
    var scorched: Int
    /// R2: mean glooms on the field between 25 % and 90 % of the level.
    var field: Double = 0
    /// R3: the stars the run earned (score-gated third star).
    var stars: Int = 0
}

/// The parallel runs' results (one lock; written from DispatchQueue.concurrentPerform's workers).
final class GlintBalanceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var done: [Int: BalanceRun] = [:]

    func put(_ k: Int, _ r: BalanceRun) {
        lock.lock()
        done[k] = r
        lock.unlock()
    }

    func all() -> [Int: BalanceRun] {
        lock.lock()
        defer { lock.unlock() }
        return done
    }
}

final class GlintBalanceMemo: @unchecked Sendable {
    static let shared = GlintBalanceMemo()
    static let skills: [Double] = [0.3, 0.6, 0.9]
    static let frameDt: Double = 1.0 / 60.0
    static let capSeconds: Double = 120

    static var seedCount: Int {
        if let raw = ProcessInfo.processInfo.environment["GLINT_BAL_SEEDS"], let n = Int(raw), n > 0 { return n }
        return 3
    }

    static func sessionSeed(_ i: Int) -> UInt64 {
        return UInt64(1 + i * 7919)
    }

    static func pilotSeed(_ i: Int) -> UInt64 {
        return sessionSeed(i) &* 7 &+ 1
    }

    private let lock = NSLock()
    private var built: Bool = false
    /// [level][skill index] → runs.
    private var table: [Int: [Int: [BalanceRun]]] = [:]

    private struct Job {
        var level: Int
        var skill: Int
        var seed: Int
    }

    func runs(level: Int, skill: Int) -> [BalanceRun] {
        build()
        lock.lock()
        defer { lock.unlock() }
        return table[level]?[skill] ?? []
    }

    static func runOne(level: Int, skill: Double, seedIndex: Int) -> BalanceRun {
        let s = DawnSession(mode: .level(level), seed: sessionSeed(seedIndex))
        var pilot = PilotBrain(skill: skill, seed: pilotSeed(seedIndex))
        var t: Double = 0
        var eaten: Int = 0
        var scorched: Int = 0
        var fieldSum: Double = 0
        var fieldN: Int = 0
        let lo: Double = 0.25 * s.duration
        let hi: Double = 0.9 * s.duration
        while !s.isFinished && t < capSeconds {
            let input: MirrorInput = pilot.input(for: s.snapshot, dt: frameDt)
            for e in s.step(dt: frameDt, input: input) {
                switch e {
                case .flowerEaten: eaten += 1
                case .fireflyScorched: scorched += 1
                default: break
                }
            }
            t += frameDt
            if s.snapshot.time >= lo && s.snapshot.time <= hi {
                fieldSum += Double(s.snapshot.glooms.count)
                fieldN += 1
            }
        }
        let stars: Int = s.snapshot.phase == .won
            ? DawnSession.stars(flowersLeft: s.snapshot.flowersLeft, score: s.snapshot.score,
                                starScore: s.spec?.starScore ?? 0)
            : 0
        return BalanceRun(won: s.snapshot.phase == .won, flowers: s.snapshot.flowersLeft, score: s.snapshot.score,
                          eaten: eaten, scorched: scorched, field: fieldN > 0 ? fieldSum / Double(fieldN) : 0,
                          stars: stars)
    }

    private func build() {
        lock.lock()
        defer { lock.unlock() }
        if built { return }
        _ = LevelBook.all.count
        let seeds: Int = GlintBalanceMemo.seedCount
        var jobs: [Job] = []
        var level: Int = 1
        while level <= LevelBook.count {
            var k: Int = 0
            while k < GlintBalanceMemo.skills.count {
                var i: Int = 0
                while i < seeds {
                    jobs.append(Job(level: level, skill: k, seed: i))
                    i += 1
                }
                k += 1
            }
            level += 1
        }
        let list: [Job] = jobs
        let box = GlintBalanceBox()
        DispatchQueue.concurrentPerform(iterations: list.count) { (n: Int) in
            let j: Job = list[n]
            let r: BalanceRun = GlintBalanceMemo.runOne(level: j.level, skill: GlintBalanceMemo.skills[j.skill],
                                                        seedIndex: j.seed)
            box.put(n, r)
        }
        let done: [Int: BalanceRun] = box.all()
        var out: [Int: [Int: [BalanceRun]]] = [:]
        var n: Int = 0
        while n < list.count {
            let j: Job = list[n]
            if let r = done[n] {
                var bySkill: [Int: [BalanceRun]] = out[j.level] ?? [:]
                var runs: [BalanceRun] = bySkill[j.skill] ?? []
                runs.append(r)
                bySkill[j.skill] = runs
                out[j.level] = bySkill
            }
            n += 1
        }
        table = out
        built = true
        var lines: [String] = []
        lines.append("GLINT-BAL ==== table (\(seeds) seeds per skill, 60 Hz) ====")
        level = 1
        while level <= LevelBook.count {
            var k: Int = 0
            while k < GlintBalanceMemo.skills.count {
                let runs: [BalanceRun] = out[level]?[k] ?? []
                lines.append(GlintBalanceMemo.line(level: level, skill: GlintBalanceMemo.skills[k], runs: runs))
                k += 1
            }
            level += 1
        }
        // R4 (ROUND-4 Core 4): one summary line per world and skill.
        var w: Int = 1
        while w <= LevelBook.worldCount {
            var k: Int = 0
            while k < GlintBalanceMemo.skills.count {
                var runs: [BalanceRun] = []
                for n in LevelBook.levels(inWorld: w) { runs.append(contentsOf: out[n]?[k] ?? []) }
                lines.append(GlintBalanceMemo.worldLine(world: w, skill: GlintBalanceMemo.skills[k], runs: runs))
                k += 1
            }
            w += 1
        }
        lines.append("GLINT-BAL ==== end ====")
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    static func line(level: Int, skill: Double, runs: [BalanceRun]) -> String {
        let won: Int = runs.filter { (r: BalanceRun) -> Bool in r.won }.count
        let count: Int = max(runs.count, 1)
        var flowers: Double = 0
        var score: Double = 0
        var eaten: Double = 0
        var scorched: Double = 0
        var field: Double = 0
        var three: Int = 0
        for r in runs {
            field += r.field
            if r.stars == 3 { three += 1 }
            flowers += Double(r.flowers)
            score += Double(r.score)
            eaten += Double(r.eaten)
            scorched += Double(r.scorched)
        }
        let n: Double = Double(count)
        return String(format: "GLINT-BAL level=%d skill=%.1f won=%d/%d flowers=%.1f score=%.0f eaten=%.1f scorched=%.1f three=%d field=%.1f",
                      level, skill, won, runs.count, flowers / n, score / n, eaten / n, scorched / n, three, field / n)
    }

    /// R4: `GLINT-BAL world=<w> skill=<s> winrate=<x> flowers=<y> three=<z> scorched=<q>` (rates per run; scorched =
    /// fireflies fizzled per level).
    static func worldLine(world: Int, skill: Double, runs: [BalanceRun]) -> String {
        let n: Double = Double(max(runs.count, 1))
        var won: Double = 0
        var flowers: Double = 0
        var three: Double = 0
        var scorched: Double = 0
        for r in runs {
            if r.won { won += 1 }
            flowers += Double(r.flowers)
            if r.stars == 3 { three += 1 }
            scorched += Double(r.scorched)
        }
        return String(format: "GLINT-BAL world=%d skill=%.1f winrate=%.2f flowers=%.2f three=%.2f scorched=%.2f",
                      world, skill, won / n, flowers / n, three / n, scorched / n)
    }
}

/// R3: the band held at one depth for a whole level (the camping line REVIEW-2 #1 kills).
enum ParkedPilot {
    static let bands: [Double] = [0.15, 0.25, 0.4, 0.6, 0.8]
    static let seeds: Int = 3

    /// (flowers left, won) for level `level`, band parked at `band`, session seed index `i`.
    static func run(level: Int, band: Double, seedIndex i: Int) -> (Int, Bool) {
        let s = DawnSession(mode: .level(level), seed: GlintBalanceMemo.sessionSeed(i))
        let input = MirrorInput(band: band, creaseGlow: Tuning.creaseGlow(band: band))
        var t: Double = 0
        while !s.isFinished && t < GlintBalanceMemo.capSeconds {
            _ = s.step(dt: GlintBalanceMemo.frameDt, input: input)
            t += GlintBalanceMemo.frameDt
        }
        return (s.snapshot.flowersLeft, s.snapshot.phase == .won)
    }
}

struct BalanceTests {

    @Test(arguments: [6, 11, 21])
    func aParkedBandLoses(level: Int) {
        var lines: [String] = []
        var ok: Bool = true
        for b in ParkedPilot.bands {
            var i: Int = 0
            while i < ParkedPilot.seeds {
                let r = ParkedPilot.run(level: level, band: b, seedIndex: i)
                let lost: Int = Tuning.flowerCount - r.0
                lines.append(String(format: "GLINT-BAL parked level=%d band=%.2f seed=%d lost=%d won=%d", level, b, i,
                                    lost, r.1 ? 1 : 0))
                if level == 21 {
                    if r.1 { ok = false }
                } else if lost < 2 {
                    ok = false
                }
                i += 1
            }
        }
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
        #expect(ok, "\(lines.joined(separator: "; "))")
    }

    @Test(arguments: [1, 2, 3])
    func firstLevelsAreWonByAWeakHand(level: Int) {
        let runs: [BalanceRun] = GlintBalanceMemo.shared.runs(level: level, skill: 0)
        let line: String = GlintBalanceMemo.line(level: level, skill: 0.3, runs: runs)
        #expect(runs.count == GlintBalanceMemo.seedCount)
        let won: Int = runs.filter { (r: BalanceRun) -> Bool in r.won }.count
        #expect(won == runs.count, "\(line)")
    }

    @Test func levelThirtyBeatsAWeakHand() {
        let runs: [BalanceRun] = GlintBalanceMemo.shared.runs(level: 30, skill: 0)
        let line: String = GlintBalanceMemo.line(level: 30, skill: 0.3, runs: runs)
        let lost: Int = runs.filter { (r: BalanceRun) -> Bool in !r.won }.count
        #expect(lost * 2 > runs.count, "\(line)")
    }

    @Test(arguments: Array(1...30))
    func everyLevelIsWinnable(level: Int) {
        let runs: [BalanceRun] = GlintBalanceMemo.shared.runs(level: level, skill: 2)
        let line: String = GlintBalanceMemo.line(level: level, skill: 0.9, runs: runs)
        let won: Int = runs.filter { (r: BalanceRun) -> Bool in r.won }.count
        #expect(won >= 1, "\(line)")
    }

    /// R4 (ROUND-4 Core 2): fireflies are spareable: the 0.9 hand fizzles ≤ 0.5 a level, the 0.6 hand ≤ 1.5 (the
    /// mirror: ≤ 0.1 and ≤ 0.7).
    @Test func firefliesAreSpareable() {
        var strong: Double = 0
        var mid: Double = 0
        var n: Double = 0
        for level in 1...LevelBook.count {
            for r in GlintBalanceMemo.shared.runs(level: level, skill: 2) {
                strong += Double(r.scorched)
                n += 1
            }
            for r in GlintBalanceMemo.shared.runs(level: level, skill: 1) { mid += Double(r.scorched) }
        }
        let k: Double = max(n, 1)
        #expect(strong / k <= 0.5, "0.9 fizzles \(strong / k) per level")
        #expect(mid / k <= 1.5, "0.6 fizzles \(mid / k) per level")
    }

    @Test func skillKeepsFlowersInHarbour() {
        var weak: Double = 0
        var strong: Double = 0
        for level in LevelBook.levels(inWorld: 3) {
            for r in GlintBalanceMemo.shared.runs(level: level, skill: 0) { weak += Double(r.flowers) }
            for r in GlintBalanceMemo.shared.runs(level: level, skill: 2) { strong += Double(r.flowers) }
        }
        #expect(weak < strong, "Harbour flowers: skill 0.3 \(weak), skill 0.9 \(strong)")
    }
}
