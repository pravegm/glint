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
// Each line also prints three=<runs with 5 flowers> and field=<mean glooms on the field from 25 % to 90 % of the level>.

struct BalanceRun {
    var won: Bool
    var flowers: Int
    var score: Int
    var eaten: Int
    var scorched: Int
    /// R2: mean glooms on the field between 25 % and 90 % of the level.
    var field: Double = 0
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
        return BalanceRun(won: s.snapshot.phase == .won, flowers: s.snapshot.flowersLeft, score: s.snapshot.score,
                          eaten: eaten, scorched: scorched, field: fieldN > 0 ? fieldSum / Double(fieldN) : 0)
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
            if r.flowers == Tuning.flowerCount { three += 1 }
            flowers += Double(r.flowers)
            score += Double(r.score)
            eaten += Double(r.eaten)
            scorched += Double(r.scorched)
        }
        let n: Double = Double(count)
        return String(format: "GLINT-BAL level=%d skill=%.1f won=%d/%d flowers=%.1f score=%.0f eaten=%.1f scorched=%.1f three=%d field=%.1f",
                      level, skill, won, runs.count, flowers / n, score / n, eaten / n, scorched / n, three, field / n)
    }
}

struct BalanceTests {

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
