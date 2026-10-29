import Foundation

// MARK: - Game Center achievements (docs/appstore/achievements.md): ids, titles, descriptions, points and triggers.
//
// The App Store Connect tool greps the `def("<key>", …)` lines, so every achievement is one such line. Ids are
// permanent once created: `glint.ach.<key>`. Titles and pre-earned descriptions are achievements.md's, word for word.
// `earned(...)` reads one finished session (its `DawnStats`, mode and outcome) plus the player's progress after the
// result was saved; the App reports only ids it hasn't reported before, and never for attract, demo or CI sessions.

struct AchievementDef: Equatable, Sendable {
    let key: String
    /// `glint.ach.<key>`.
    let id: String
    let title: String
    /// The pre-earned description (also the in-app wording).
    let blurb: String
    let points: Int

    /// achievements.md's name for `blurb`.
    var detail: String { return blurb }
}

enum Achievements {
    static let idPrefix: String = "glint.ach."

    static func def(_ key: String, _ title: String, _ blurb: String, _ points: Int) -> AchievementDef {
        return AchievementDef(key: key, id: idPrefix + key, title: title, blurb: blurb, points: points)
    }

    static let firstLight = def("firstlight", "First Light", "Win your first sunrise.", 10)
    static let sweep = def("sweep", "Clean Sweep", "Pop 3 shadows or more in one Sweep.", 10)
    static let brute = def("brute", "The Bigger They Come", "Pop a brute.", 25)
    static let firefly = def("firefly", "Firefly Gardener", "Let a firefly replant a lost flower.", 25)
    static let chain4 = def("chain4", "Four Times Bright", "Reach a x4 chain: pop 13 shadows in a row.", 50)
    static let rooftops = def("rooftops", "Over the Rooftops", "Win all 10 Rooftops sunrises.", 50)
    static let harbour = def("harbour", "Harbour Lights", "Win all 10 Harbour sunrises.", 100)
    static let allStars = def("allstars", "Ninety Suns", "Earn all 90 stars.", 100)
    static let daily = def("daily", "Early Riser", "Finish a Today's Dawn.", 15)
    static let longNight = def("longnight", "Night Watch", "Score 20,000 in one Long Night.", 50)

    /// In achievements.md's order.
    static let all: [AchievementDef] = [firstLight, sweep, brute, firefly, chain4, rooftops, harbour, allStars, daily,
                                        longNight]

    /// The earned descriptions (Results card, Game Center's "earned" text), by key.
    static let earnedBlurbs: [String: String] = [
        "firstlight": "The sun is up. The garden is yours.",
        "sweep": "Three pops, one swish of light.",
        "brute": "Big, slow, grumpy, and gone.",
        "firefly": "A little light brought a flower back.",
        "chain4": "The chain hit x4. Dazzling.",
        "rooftops": "Every roof in the city, lit.",
        "harbour": "The whole harbour, lit at last.",
        "allstars": "Every sunrise, every flower.",
        "daily": "Up with the sun, with everyone else.",
        "longnight": "Twenty thousand points before dawn.",
    ]

    /// The chain at which the multiplier reaches ×4 (`1 + chainStep × (chain − 1)`): 13.
    static var chain4Chain: Int {
        return Int(((Tuning.maxMultiplier - 1) / Tuning.chainStep).rounded()) + 1
    }

    /// Night Watch's score (achievements.md). R2 balance note: the mirror's 0.6 pilot's median Long Night is ~17,000,
    /// so R2 raised it from 10,000 to 20,000 (between the 0.6 and 0.9 medians). R3's Long Night was retuned to keep it
    /// there: the mirror's medians are ~17,800 (skill 0.6) and ~23,600 (0.9).
    static let nightWatchScore: Int = 20_000
    /// Ninety Suns: every level's three stars.
    static var allStarsTotal: Int { return LevelBook.count * 3 }

    static func find(_ key: String) -> AchievementDef? {
        for a in all where a.key == key { return a }
        return nil
    }

    /// The ids (in `all` order) this session and the saved progress earn. `outcome` is the session's final phase
    /// (`.won` / `.lost`; a Long Night quit early may pass `.playing`). `progressStars` = total stars and
    /// `levelsWon` = levels with ≥ 1 star, both after this result was saved.
    static func earned(stats: DawnStats, mode: PlayMode, outcome: SessionPhase, progressStars: Int,
                       levelsWon: Set<Int>) -> [String] {
        var out: [String] = []
        let finished: Bool = outcome == .won || outcome == .lost
        var isEndless: Bool = false
        var isDaily: Bool = false
        switch mode {
        case .endless: isEndless = true
        case .daily: isDaily = true
        case .level: break
        }
        for a in all {
            var hit: Bool = false
            switch a.key {
            case "firstlight": hit = mode.isLevel && outcome == .won
            case "sweep": hit = stats.bestSweep >= Tuning.sweepMinimum
            case "brute": hit = stats.brutesPopped >= 1
            case "firefly": hit = stats.flowersReplanted >= 1
            case "chain4": hit = stats.longestChain >= chain4Chain
            case "rooftops": hit = LevelBook.levels(inWorld: 2).allSatisfy { (n: Int) -> Bool in levelsWon.contains(n) }
            case "harbour": hit = LevelBook.levels(inWorld: 3).allSatisfy { (n: Int) -> Bool in levelsWon.contains(n) }
            case "allstars": hit = progressStars >= allStarsTotal
            case "daily": hit = isDaily && finished
            case "longnight": hit = isEndless && stats.score >= nightWatchScore
            default: hit = false
            }
            if hit { out.append(a.id) }
        }
        return out
    }
}
