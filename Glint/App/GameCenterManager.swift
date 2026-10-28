import Foundation
import GameKit
import UIKit

/// Thin, polite Game Center wrapper (ported from Hush, `Hush/App/GameCenterManager.swift`). Optional and never
/// gating: authentication is quiet (a sign-in view controller handed to us is only shown when the player taps the
/// Game Center button), scores earned while signed out are queued in UserDefaults and sent once a player is
/// authenticated, and every failure is silent. The access point stays off. Skipped entirely in demo runs.
/// R2: achievements (`achievementIDs` = Core's `Achievements.all`) are reported at the Results card. While a level is
/// on screen (`holdBanners`) nothing is reported, so a banner never lands mid-level. Every earned one, and the star
/// total, is re-sent on each sign-in (achievements.md).
@MainActor
final class GameCenterManager {
    static let shared = GameCenterManager()

    enum Leaderboard {
        /// Long Night: best score (classic, all-time).
        static let endless = "glint.endless"
        /// Today's Dawn: the day's best (a recurring leaderboard that resets daily).
        static let daily = "glint.daily"
        /// Total stars across the 30 sunrises.
        static let stars = "glint.stars"
    }

    /// Every achievement id (`glint.ach.<key>`), in Core's order (the ASC tool reads them from here too).
    nonisolated static let achievementIDs: [String] = Achievements.all.map(\.id)

    private(set) var isAuthenticated = false
    /// True while a level is on screen: achievements wait (no banner mid-level).
    private(set) var holdBanners = false
    private let reportedKey = "glint.gc.reported"
    private let pendingKey = "glint.gc.pending"
    /// The progress's earned ids and star total, re-sent on each sign-in.
    private var knownEarned: [String] = []
    private var knownStars = 0
    private var started = false
    private var disabled = false
    private let pendingScoresKey = "glint.gc.pendingScores"
    private var inFlight: Set<String> = []
    private var signInController: UIViewController?

    private init() {}

    /// Called once at launch (never in demo runs).
    func authenticate() {
        guard !started else { return }
        started = true
        if DemoMode.current != nil {
            disabled = true
            return
        }
        GKAccessPoint.shared.isActive = false
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            Task { @MainActor in
                GameCenterManager.shared.authenticationChanged(signIn: viewController)
            }
        }
    }

    enum DashboardResult: Equatable { case shown, signingIn, signedOut }

    /// Home's / Settings' Game Center button (it must never do nothing: signed out, the App says so).
    func showDashboard() -> DashboardResult {
        if disabled { return .signedOut }
        if GKLocalPlayer.local.isAuthenticated {
            GKAccessPoint.shared.trigger(handler: {})
            return .shown
        }
        if let signIn = signInController, let top = Self.topViewController() {
            signInController = nil
            top.present(signIn, animated: true)
            return .signingIn
        }
        return .signedOut
    }

    func submitEndless(_ score: Int) {
        guard !disabled, score > 0 else { return }
        queueScore(score, leaderboard: Leaderboard.endless, day: nil)
    }

    func submitDaily(_ score: Int, day: Int) {
        guard !disabled, score > 0 else { return }
        queueScore(score, leaderboard: Leaderboard.daily, day: day)
    }

    func submitStars(_ total: Int) {
        guard !disabled, total > 0 else { return }
        queueScore(total, leaderboard: Leaderboard.stars, day: nil)
    }

    /// The App's progress (launch, and after every result): re-sent on sign-in.
    func syncProgress(achievements: [String], totalStars: Int) {
        knownEarned = achievements
        knownStars = totalStars
    }

    /// Earned ids to report (now, unless a level is on screen; else when it ends).
    func unlock(_ ids: [String]) {
        guard !disabled, !ids.isEmpty else { return }
        let reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        let queued = UserDefaults.standard.stringArray(forKey: pendingKey) ?? []
        let pending = Self.pendingAchievements(earned: queued + ids, reported: reported, known: Self.achievementIDs)
        UserDefaults.standard.set(pending, forKey: pendingKey)
        flush()
    }

    /// The App says whether a level is on screen (banners wait until it isn't).
    func setHoldBanners(_ hold: Bool) {
        guard hold != holdBanners else { return }
        holdBanners = hold
        if !hold { flush() }
    }

    /// `earned` not yet reported and known to Game Center, without repeats, in order. Pure; tested.
    nonisolated static func pendingAchievements(earned: [String], reported: Set<String>, known: [String]) -> [String] {
        let knownSet = Set(known)
        var seen = reported
        var out: [String] = []
        for id in earned where knownSet.contains(id) && !seen.contains(id) {
            seen.insert(id)
            out.append(id)
        }
        return out
    }

    // MARK: - Queue entries (pure; tested)

    struct QueuedScore: Equatable {
        var leaderboard: String
        var score: Int
        var day: Int?
        var token: String
    }

    nonisolated static func encode(leaderboard: String, score: Int, day: Int?, token: String) -> String {
        "\(leaderboard)|\(score)|\(day ?? -1)|\(token)"
    }

    nonisolated static func parse(_ entry: String) -> QueuedScore? {
        let parts = entry.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, let value = Int(parts[1]) else { return nil }
        var day: Int?
        if parts.count >= 3, let d = Int(parts[2]), d >= 0 { day = d }
        let token = parts.count >= 4 ? parts[3] : entry
        return QueuedScore(leaderboard: parts[0], score: value, day: day, token: token)
    }

    /// A daily score flushed after its day ended would land on the next day's board, so it is dropped.
    nonisolated static func isStale(_ score: QueuedScore, today: Int) -> Bool {
        guard score.leaderboard == Leaderboard.daily else { return false }
        guard let day = score.day else { return true }
        return day != today
    }

    /// One pending entry per board (per day for the daily board); the larger score wins. At most `cap` entries.
    nonisolated static func enqueue(_ entry: String, into queue: [String], cap: Int = 20) -> [String] {
        guard let new = parse(entry) else { return queue }
        var out = queue
        if let i = out.firstIndex(where: { e in
            guard let p = parse(e) else { return false }
            return p.leaderboard == new.leaderboard && p.day == new.day
        }) {
            if let old = parse(out[i]), old.score >= new.score { return out }
            out.remove(at: i)
        }
        out.append(entry)
        while out.count > max(cap, 1) { out.removeFirst() }
        return out
    }

    // MARK: - Internals

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private func authenticationChanged(signIn: UIViewController?) {
        if let signIn { signInController = signIn }
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        if isAuthenticated {
            signInController = nil
            // Re-send everything earned (Game Center keeps the best; achievements are idempotent).
            UserDefaults.standard.removeObject(forKey: reportedKey)
            if knownStars > 0 { submitStars(knownStars) }
            if !knownEarned.isEmpty { unlock(knownEarned) }
        }
        GKAccessPoint.shared.isActive = false
        flush()
    }

    private func queueScore(_ score: Int, leaderboard: String, day: Int?) {
        let queue = UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []
        let entry = Self.encode(leaderboard: leaderboard, score: score, day: day, token: UUID().uuidString)
        UserDefaults.standard.set(Self.enqueue(entry, into: queue), forKey: pendingScoresKey)
        flush()
    }

    private func flush() {
        guard isAuthenticated, !disabled else { return }
        let today = DailySeed.day(for: Date())
        let queued = UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []
        let kept = queued.filter { entry in
            guard let parsed = Self.parse(entry) else { return false }
            return !Self.isStale(parsed, today: today)
        }
        if kept.count != queued.count { UserDefaults.standard.set(kept, forKey: pendingScoresKey) }
        flushAchievements()
        for entry in kept where !inFlight.contains(entry) {
            guard let parsed = Self.parse(entry) else { continue }
            inFlight.insert(entry)
            GKLeaderboard.submitScore(parsed.score, context: max(parsed.day ?? 0, 0), player: GKLocalPlayer.local,
                                      leaderboardIDs: [parsed.leaderboard]) { error in
                let ok = error == nil
                Task { @MainActor in
                    GameCenterManager.shared.didSubmit(entry, ok: ok)
                }
            }
        }
    }

    private func flushAchievements() {
        guard isAuthenticated, !disabled, !holdBanners else { return }
        let ids = UserDefaults.standard.stringArray(forKey: pendingKey) ?? []
        guard !ids.isEmpty else { return }
        let achievements: [GKAchievement] = ids.map { id in
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = true
            return achievement
        }
        GKAchievement.report(achievements) { error in
            let ok = error == nil
            Task { @MainActor in
                GameCenterManager.shared.didReport(ids, ok: ok)
            }
        }
    }

    private func didReport(_ ids: [String], ok: Bool) {
        guard ok else { return }
        var reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        reported.formUnion(ids)
        UserDefaults.standard.set(Array(reported).sorted(), forKey: reportedKey)
        let pending = (UserDefaults.standard.stringArray(forKey: pendingKey) ?? []).filter { !reported.contains($0) }
        UserDefaults.standard.set(pending, forKey: pendingKey)
    }

    private func didSubmit(_ entry: String, ok: Bool) {
        inFlight.remove(entry)
        guard ok else { return }
        let queue = (UserDefaults.standard.stringArray(forKey: pendingScoresKey) ?? []).filter { $0 != entry }
        UserDefaults.standard.set(queue, forKey: pendingScoresKey)
    }
}
