import Combine
import Foundation

// MARK: - Stored data (pure value types; tested in GlintTests/AppTests.swift)

/// Something a finished level or run opened for the first time (Results names it).
enum UnlockNote: Equatable, Sendable {
    case endless
    case daily
    case world(Int)

    var text: String {
        switch self {
        case .endless: return "Long Night is open"
        case .daily: return "Today's Dawn is open"
        case let .world(w): return "\(LevelBook.worldName(w)) is open"
        }
    }
}

/// What recording a finished level or run changed, for the Results screen.
struct RecordOutcome: Equatable, Sendable {
    /// The best for this level / mode / day before the run (0 = none).
    var previousBest = 0
    /// The best after the run.
    var best = 0
    var isNewBest = false
    /// Level stars before and after (0 for endless / daily).
    var starsBefore = 0
    var starsAfter = 0
    /// Every star earned so far, all levels.
    var totalStars = 0
    /// Opened by this run.
    var unlocked: [UnlockNote] = []
    /// The next level, when it is open (levels only).
    var nextLevel: Int?

    /// "New best!" only when an earlier best was beaten (never on the very first try).
    var showsNewBest: Bool { isNewBest && previousBest > 0 }
}

/// Everything Glint remembers. JSON under `ProgressStore.key`, versioned, decoded tolerantly (a missing or mistyped
/// field falls back to its default and never wipes the rest).
struct ProgressData: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = ProgressData.currentVersion
    /// Stars per level (index = level − 1), 0…3.
    var levelStars: [Int]
    /// Best score per level (index = level − 1).
    var levelBest: [Int]
    /// Long Night best score.
    var endlessBest: Int = 0
    /// Today's Dawn: day number (`DailySeed.day(for:)`, as a string key) → that day's best score.
    var dailyBests: [String: Int] = [:]
    var bestDailyEver: Int = 0
    /// The last level started (Home's Play falls back on it).
    var lastLevel: Int = 1
    /// The first launch (seconds since 1970; 0 = unknown). Long Night also opens one day after it.
    var firstLaunch: Double = 0
    /// The one-line hints already shown (`HintID` raw values).
    var seenHints: [String] = []
    /// A real hinge has reported on this device at some point (the iPhone Duo flag, ROUND-1 App 2).
    var hingeSeen: Bool = false
    /// R5 (QA P1-1): the device model (`utsname.machine`) that saw the hinge. A backup restored onto another phone
    /// doesn't make it a Duo: the flag only counts on the same model.
    var hingeMachine: String = ""
    /// Levels and runs started.
    var plays: Int = 0
    /// R2: Today's Dawn days finished (ascending, the last 400 kept): the day streak.
    var dailyPlayed: [Int] = []
    /// R2: Game Center achievement ids earned (`glint.ach.<key>`), in the order earned.
    var achievements: [String] = []

    init() {
        levelStars = Array(repeating: 0, count: LevelBook.count)
        levelBest = Array(repeating: 0, count: LevelBook.count)
    }

    enum CodingKeys: String, CodingKey {
        case version, levelStars, levelBest, endlessBest, dailyBests, bestDailyEver, lastLevel, firstLaunch, seenHints
        case hingeSeen, plays, dailyPlayed, achievements, hingeMachine
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = ProgressData.currentVersion
        let count = LevelBook.count
        let stars: [Int] = (try? c.decodeIfPresent([Int].self, forKey: .levelStars)) ?? []
        let bests: [Int] = (try? c.decodeIfPresent([Int].self, forKey: .levelBest)) ?? []
        levelStars = ProgressRules.normalized(stars, count: count, maxValue: ProgressRules.maxStars)
        levelBest = ProgressRules.normalized(bests, count: count, maxValue: ProgressRules.maxScore)
        endlessBest = ProgressRules.clampScore((try? c.decodeIfPresent(Int.self, forKey: .endlessBest)) ?? 0)
        let daily: [String: Int] = (try? c.decodeIfPresent([String: Int].self, forKey: .dailyBests)) ?? [:]
        var cleanDaily: [String: Int] = [:]
        for (key, value) in daily { cleanDaily[key] = ProgressRules.clampScore(value) }
        dailyBests = cleanDaily
        bestDailyEver = ProgressRules.clampScore((try? c.decodeIfPresent(Int.self, forKey: .bestDailyEver)) ?? 0)
        let last: Int = (try? c.decodeIfPresent(Int.self, forKey: .lastLevel)) ?? 1
        lastLevel = min(max(last, 1), max(count, 1))
        let first: Double = (try? c.decodeIfPresent(Double.self, forKey: .firstLaunch)) ?? 0
        firstLaunch = first.isFinite ? max(first, 0) : 0
        seenHints = (try? c.decodeIfPresent([String].self, forKey: .seenHints)) ?? []
        hingeSeen = (try? c.decodeIfPresent(Bool.self, forKey: .hingeSeen)) ?? false
        hingeMachine = (try? c.decodeIfPresent(String.self, forKey: .hingeMachine)) ?? ""
        plays = ProgressRules.clampScore((try? c.decodeIfPresent(Int.self, forKey: .plays)) ?? 0)
        let days: [Int] = (try? c.decodeIfPresent([Int].self, forKey: .dailyPlayed)) ?? []
        dailyPlayed = ProgressRules.cleanDays(days)
        achievements = (try? c.decodeIfPresent([String].self, forKey: .achievements)) ?? []
    }
}

// MARK: - Rules (pure; tested)

/// Stars, unlocks and records (GAME-DESIGN §6): each world opens at 2/3 of the previous world's stars, levels inside
/// a world open one at a time (the one before won), Today's Dawn after level 3, Long Night after level 5 (or a day
/// after the first launch, whichever comes first).
enum ProgressRules {
    static let maxStars = 3
    static let maxScore = 1_000_000_000
    /// The level whose win opens Today's Dawn / Long Night.
    static let dailyLevel = 3
    static let endlessLevel = 5
    /// Long Night also opens this long after the first launch.
    static let endlessAfterSeconds: Double = 86_400

    static func clampScore(_ v: Int) -> Int { min(max(v, 0), maxScore) }

    /// `values` padded with zeros / cut to `count`, each clamped to 0…`maxValue`.
    static func normalized(_ values: [Int], count: Int, maxValue: Int) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(max(count, 0))
        for i in 0..<max(count, 0) {
            let v = i < values.count ? values[i] : 0
            out.append(min(max(v, 0), maxValue))
        }
        return out
    }

    static func stars(_ d: ProgressData, level n: Int) -> Int {
        let i = n - 1
        guard i >= 0, i < d.levelStars.count else { return 0 }
        return d.levelStars[i]
    }

    static func best(_ d: ProgressData, level n: Int) -> Int {
        let i = n - 1
        guard i >= 0, i < d.levelBest.count else { return 0 }
        return d.levelBest[i]
    }

    static func totalStars(_ d: ProgressData) -> Int {
        d.levelStars.reduce(0, +)
    }

    static func maxTotalStars() -> Int { LevelBook.count * maxStars }

    static func stars(_ d: ProgressData, world w: Int) -> Int {
        guard w >= 1, w <= LevelBook.worldCount else { return 0 }
        var total = 0
        for n in LevelBook.levels(inWorld: w) { total += stars(d, level: n) }
        return total
    }

    static func maxStars(world w: Int) -> Int {
        guard w >= 1, w <= LevelBook.worldCount else { return 0 }
        return LevelBook.levels(inWorld: w).count * maxStars
    }

    /// Stars needed in world w − 1 to open world w (2/3 of that world's stars, rounded up). 0 for world 1.
    static func gate(world w: Int) -> Int {
        guard w >= 2 else { return 0 }
        let previous = Double(maxStars(world: w - 1))
        return Int((previous * 2.0 / 3.0).rounded(.up))
    }

    static func isWorldOpen(_ w: Int, _ d: ProgressData) -> Bool {
        guard w >= 1, w <= LevelBook.worldCount else { return false }
        if w == 1 { return true }
        return isWorldOpen(w - 1, d) && stars(d, world: w - 1) >= gate(world: w)
    }

    /// How many more stars (in the previous world) open world w; 0 when it is open.
    static func starsMissing(toOpen w: Int, _ d: ProgressData) -> Int {
        guard w >= 2, w <= LevelBook.worldCount else { return 0 }
        if isWorldOpen(w, d) { return 0 }
        return max(gate(world: w) - stars(d, world: w - 1), 0)
    }

    static func isUnlocked(level n: Int, _ d: ProgressData) -> Bool {
        guard n >= 1, n <= LevelBook.count else { return false }
        let w = LevelBook.world(of: n)
        guard isWorldOpen(w, d) else { return false }
        if n == LevelBook.levels(inWorld: w).lowerBound { return true }
        return stars(d, level: n - 1) >= 1
    }

    static func dailyUnlocked(_ d: ProgressData) -> Bool {
        stars(d, level: dailyLevel) >= 1
    }

    static func endlessUnlocked(_ d: ProgressData, now: Date) -> Bool {
        if stars(d, level: endlessLevel) >= 1 { return true }
        guard d.firstLaunch > 0 else { return false }
        return now.timeIntervalSince1970 - d.firstLaunch >= endlessAfterSeconds
    }

    /// Home's Play: the first open level not yet won, else the highest open level.
    static func nextLevel(_ d: ProgressData) -> Int {
        guard LevelBook.count >= 1 else { return 1 }
        var highest = 1
        for n in 1...LevelBook.count where isUnlocked(level: n, d) {
            if stars(d, level: n) == 0 { return n }
            highest = n
        }
        return highest
    }

    static func dailyBest(_ d: ProgressData, day: Int) -> Int {
        d.dailyBests[String(day)] ?? 0
    }

    /// `ids` not already in `earned`, without repeats, in order. Pure; tested.
    static func newAchievements(_ ids: [String], earned: [String]) -> [String] {
        var seen = Set(earned)
        var out: [String] = []
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            out.append(id)
        }
        return out
    }

    /// Sorted, unique, the last 400.
    static func cleanDays(_ days: [Int]) -> [Int] {
        Array(Array(Set(days)).sorted().suffix(400))
    }

    /// Today's Dawn was finished today.
    static func playedDaily(_ d: ProgressData, day: Int) -> Bool {
        d.dailyPlayed.contains(day)
    }

    /// The day streak: consecutive days finished, ending today (or yesterday, so the streak still shows before
    /// today's run). 0 when the last finished day is older.
    static func dailyStreak(_ d: ProgressData, today: Int) -> Int {
        let played = Set(d.dailyPlayed)
        var day = played.contains(today) ? today : today - 1
        var streak = 0
        while played.contains(day) {
            streak += 1
            day -= 1
        }
        return streak
    }

    /// Everything open right now, in a stable order.
    static func unlockSet(_ d: ProgressData, now: Date) -> [UnlockNote] {
        var out: [UnlockNote] = []
        if dailyUnlocked(d) { out.append(.daily) }
        if endlessUnlocked(d, now: now) { out.append(.endless) }
        for w in stride(from: 2, through: LevelBook.worldCount, by: 1) where isWorldOpen(w, d) {
            out.append(.world(w))
        }
        return out
    }

    /// Files a finished level or run. Level stars only go up; bests keep the larger score.
    /// The saved Duo flag, trusted only on the model that set it (R5, QA P1-1).
    static func hingeSeen(_ d: ProgressData, machine: String) -> Bool {
        d.hingeSeen && !d.hingeMachine.isEmpty && d.hingeMachine == machine
    }

    /// `finished` false (R5, QA P2-1): a Today's Dawn left early still keeps its best, but doesn't count as the day played.
    static func record(_ d: inout ProgressData, mode: PlayMode, won: Bool, stars earned: Int, score: Int,
                       now: Date, finished: Bool = true) -> RecordOutcome {
        let before = unlockSet(d, now: now)
        let value = clampScore(score)
        var out = RecordOutcome()
        switch mode {
        case let .level(n):
            let i = n - 1
            if i >= 0, i < d.levelStars.count, i < d.levelBest.count {
                out.previousBest = d.levelBest[i]
                out.starsBefore = d.levelStars[i]
                if won {
                    d.levelStars[i] = max(d.levelStars[i], min(max(earned, 0), maxStars))
                }
                d.levelBest[i] = max(d.levelBest[i], value)
                out.starsAfter = d.levelStars[i]
                out.best = d.levelBest[i]
            }
            if n < LevelBook.count && isUnlocked(level: n + 1, d) { out.nextLevel = n + 1 }
        case .endless:
            out.previousBest = d.endlessBest
            d.endlessBest = max(d.endlessBest, value)
            out.best = d.endlessBest
        case let .daily(day):
            let key = String(day)
            out.previousBest = d.dailyBests[key] ?? 0
            let best = max(out.previousBest, value)
            d.dailyBests[key] = best
            if finished { d.dailyPlayed = cleanDays(d.dailyPlayed + [day]) }
            d.bestDailyEver = max(d.bestDailyEver, best)
            out.best = best
            // Keep the file small: the last 60 days.
            if d.dailyBests.count > 60 {
                let keep = Set(d.dailyBests.keys.compactMap { Int($0) }.sorted().suffix(60).map { String($0) })
                d.dailyBests = d.dailyBests.filter { keep.contains($0.key) }
            }
        }
        out.isNewBest = value > out.previousBest
        out.totalStars = totalStars(d)
        let after = unlockSet(d, now: now)
        out.unlocked = after.filter { !before.contains($0) }
        return out
    }
}

// MARK: - Store

/// The saved progress for SwiftUI. `defaults` nil = in memory (demo runs never touch the player's save).
@MainActor
final class ProgressStore: ObservableObject {
    static let key = "glint.progress"

    @Published private(set) var data: ProgressData
    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        var loaded = ProgressData()
        if let raw = defaults?.data(forKey: Self.key) {
            if let decoded = Self.decode(raw) {
                loaded = decoded
            } else {
                // R5 (QA P2-11): never silently throw a save away: keep the unreadable bytes beside it.
                defaults?.set(raw, forKey: Self.key + ".bad")
            }
        }
        if loaded.firstLaunch <= 0 { loaded.firstLaunch = Date().timeIntervalSince1970 }
        data = loaded
        save()
    }

    init(inMemory initial: ProgressData) {
        defaults = nil
        data = initial
    }

    nonisolated static func encode(_ data: ProgressData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> ProgressData? { try? JSONDecoder().decode(ProgressData.self, from: raw) }

    var nextLevel: Int { ProgressRules.nextLevel(data) }
    var totalStars: Int { ProgressRules.totalStars(data) }

    func record(mode: PlayMode, won: Bool, stars: Int, score: Int, now: Date, finished: Bool = true) -> RecordOutcome {
        var copy = data
        let outcome = ProgressRules.record(&copy, mode: mode, won: won, stars: stars, score: score, now: now,
                                           finished: finished)
        data = copy
        save()
        return outcome
    }

    func noteStarted(_ mode: PlayMode) {
        var copy = data
        copy.plays = ProgressRules.clampScore(copy.plays + 1)
        if case let .level(n) = mode { copy.lastLevel = min(max(n, 1), max(LevelBook.count, 1)) }
        data = copy
        save()
    }

    /// Files achievement ids; returns the ones that are new (in the given order).
    func addAchievements(_ ids: [String]) -> [String] {
        let fresh = ProgressRules.newAchievements(ids, earned: data.achievements)
        guard !fresh.isEmpty else { return [] }
        var copy = data
        copy.achievements.append(contentsOf: fresh)
        data = copy
        save()
        return fresh
    }

    func hasSeen(_ hint: HintID) -> Bool { data.seenHints.contains(hint.rawValue) }

    func markSeen(_ hint: HintID) {
        guard !hasSeen(hint) else { return }
        var copy = data
        copy.seenHints.append(hint.rawValue)
        data = copy
        save()
    }

    func noteHingeSeen(machine: String = "") {
        guard !data.hingeSeen || data.hingeMachine != machine else { return }
        var copy = data
        copy.hingeSeen = true
        copy.hingeMachine = machine
        data = copy
        save()
    }

    /// R5 (QA P1-1): the hinge API says this device has none: forget an old (restored) Duo flag.
    func clearHingeSeen() {
        guard data.hingeSeen else { return }
        var copy = data
        copy.hingeSeen = false
        copy.hingeMachine = ""
        data = copy
        save()
    }

    private func save() {
        guard let defaults, let raw = Self.encode(data) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}
