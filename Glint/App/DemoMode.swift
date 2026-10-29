import Foundation
import SwiftUI
import UIKit

// MARK: - Demo mode (CI screenshots, design review). DEBUG builds only: `current` is nil in Release, and the key
// parser exists only in DEBUG (the release guard greps the binary for demo keys).
//
// Launch argument: `-glintDemo "key=value;key=value"` (ci/scenarios.txt via ci/screenshots.sh). Values can't contain
// `;`. Unknown keys are ignored. Keys (design/ROUND-1.md, App 5):
// - `screen=home|levels|play|results|settings|about|cover|icon`
//     play     straight into play of `mode` / `level`. Implied by `mode=`, `level=` or `t=` without `screen`.
//     results  a REAL session of `mode` played headless at launch (pilot at `skill`, default 1; `results=lost` keeps
//              the light in the crease so the night wins), recorded into the demo progress, then Results.
//     cover    force the cover-display view (with `t=` / `mode=` / `level=`: over a paused level, with its score).
//     icon     render UI/AppIconArt.swift to Documents/AppIcon-1024.png (opaque RGB) and print `GLINT-ICON <path>`.
//              R2: `GLINT-T icon stats lum=<l> colours=<n>`, and `GLINT-T icon dark …` when the mean luminance < 0.08.
//     badges   (R2) render the ten Game Center badges (UI/AchievementArt.swift) to Documents/badges/<id>.png (1024²,
//              opaque RGB), print `GLINT-T badges done 10`, and show them on screen.
// - `progress=fresh|mid|done`   seeded in-memory progress (DemoPresets). Demo runs never write UserDefaults.
// - `level=<1…30>`, `mode=level|endless|daily`
// - `t=<s>`        fast-forward the session with the pilot to t s of play at fixed 1/120 s steps (the last 0.5 s live,
//                  still at 1/120 s steps so FX are on screen), then freeze: `GLINT-T freeze time`.
// - `skill=<0…1>`  pilot skill (default 0.8). With `t=` or `skill=` the pilot drives the light even on a Duo.
// - `band=<d>`     pin the band at the freeze (t=). Without t=: hold the band there (phones only; a real hinge wins).
// - `fold=1`       Duo split layout on any device. `swap=1`: Swap halves. `sound=0`: mute.
// - `results=won|lost`, `hint=<HintID>` (force that hint line in play), `seed=<n>` (endless / attract seed).
// - `freezeOn=<started|pop|sweep|split|hop|firefly|scorch|eaten|sunrise|night|wave|hint>`: freeze 0.3 s after the first
//                  such event (`GLINT-T freeze <tag>`); with `freezeAfter=<s>`, only once s s of play have passed.
//                  `freezeAfter=<s>` alone: freeze after s s of play (`GLINT-T freeze after`). Without `t=`/`skill=`
//                  these use the pilot only when no real hinge has reported.
// - `prompt=close|open|drag`  force that start line (static frames; the light stays in the crease).
// - `streak=<n>`   (R3) Today's Dawn finished on the last n days, today included (today's best 2,140).
// - `ignore=<kind>`  (R3) the pilot never aims at that kind (with `results=lost`: a loss with a known cause, so the
//                  tip matches it: `results=lost;level=13;ignore=brute`).
// - `duolog=1`     changes nothing (how CI launches on the Duo simulator: `screen=play;level=1;duolog=1`).
//
// Log lines (DEBUG + `-glintDemo` only, via FeelDemoLog): `GLINT-T demo '<args>' starts`, `GLINT-T screen <name>`,
// `GLINT-T canvas <W>x<H> fold=<0|1>`, `GLINT-T band <b> angle <θ> phase <p> shut <0|1>` (2 Hz in play),
// `GLINT-T prompt <close|open|drag|none>`, `GLINT-T paused shut`, `GLINT-T paused <menu|inactive>`, `GLINT-T resumed`,
// `GLINT-T freeze <tag>`, `GLINT-T event <name> …`, `GLINT-T result …`, `GLINT-T icon ok|failed`, `GLINT-ICON <path>`.

struct DemoMode: Equatable, Sendable {
    enum Screen: String, Equatable, CaseIterable, Sendable {
        case home, levels, play, results, settings, about, cover, icon, badges
    }
    enum Preset: String, Equatable, CaseIterable, Sendable { case fresh, mid, done }
    enum ModeKey: String, Equatable, CaseIterable, Sendable { case level, endless, daily }
    enum Outcome: String, Equatable, CaseIterable, Sendable { case won, lost }
    enum PromptKey: String, Equatable, CaseIterable, Sendable { case close, open, drag }
    /// `freezeOn=` moments (all events: the freeze lands 0.3 s after the event so its FX are on screen).
    enum Stop: String, Equatable, CaseIterable, Sendable {
        case started, pop, sweep, split, hop, firefly, scorch, eaten, sunrise, night, wave, hint
        /// R5b (store frames): a busy field. `busy` and `firefly` are states, checked every frame (`DemoBusy`).
        case busy

        func matches(_ event: GameEvent) -> Bool {
            switch self {
            case .started: if case .started = event { return true }
            case .pop: if case .popped = event { return true }
            case .sweep: if case .swept = event { return true }
            case .split: if case .split = event { return true }
            case .hop: if case .hopped = event { return true }
            case .firefly, .busy: return false   // states, not events (DemoBusy)
            case .scorch: if case .fireflyScorched = event { return true }
            case .eaten: if case .flowerEaten = event { return true }
            case .sunrise: if case .sunrise = event { return true }
            case .night: if case .nightWins = event { return true }
            case .wave: if case .waveUp = event { return true }
            case .hint: if case .hint = event { return true }
            }
            return false
        }
    }

    static let defaultSkill = 0.8
    static let defaultSeed: UInt64 = 7
    /// Event freezes hold this long after the event.
    static let stopDelay = 0.3

    /// R5b: how long after its event each tag freezes (a sweep at 0.12 s, so the burst and "Sweep!" are on screen).
    static func stopDelay(for tag: Stop) -> Double {
        tag == .sweep ? 0.12 : stopDelay
    }
    /// `t=`: the last stretch is played live (fixed 1/120 s steps) so the frame shows FX in motion.
    static let liveTail = 0.5

    var raw: String
    var screen: Screen?
    var progress: Preset?
    var level: Int?
    var mode: ModeKey?
    /// `t=` (seconds of play).
    var playTo: Double?
    var skill: Double?
    /// `band=`.
    var pinBand: Double?
    var fold = false
    var swap = false
    /// `results=`.
    var outcome: Outcome?
    var hint: HintID?
    /// `freezeOn=` (named apart from the key).
    var stopOn: Stop?
    /// `freezeAfter=` (named apart from the key: the release guard greps Release for the key).
    var holdAfter: Double?
    var seed: UInt64?
    var sound = true
    var prompt: PromptKey?
    var duoLog = false
    /// R3 `streak=<n>`: Today's Dawn finished on the last n days, today included (best today 2,140): the streak frames.
    var streakDays: Int?
    /// R3 `ignore=<kind>`: the pilot never aims at that gloom kind (lost-result fixtures whose cause is known).
    var ignoreKind: GloomKind?
    /// R4 `spawn=firefly`: with `t=` on a level, one extra firefly is scripted 1 s before t (frame 19: a real
    /// firefly on screen with its hint).
    var spawnFirefly = false
    /// R5b `pilotLag=<s>` (0…2): the demo pilot reacts this much later (more glooms build up), skill unchanged.
    var pilotLag: Double?
    /// R5c `stage=<name>` (store frames): a scripted real session frozen at its moment (App/DemoStages.swift).
    var stageName: DemoStageName?

    init(raw: String) { self.raw = raw }

    /// The screen the app opens on.
    var effectiveScreen: Screen {
        if let screen { return screen }
        if mode != nil || level != nil || playTo != nil || stopOn != nil || holdAfter != nil || stageName != nil {
            return .play
        }
        return .home
    }

    /// The pilot drives the light whatever the device (t= or skill= given).
    var forcesPilot: Bool { playTo != nil || skill != nil }

    /// The pilot drives the light only while no real hinge has reported (freezeOn= / freezeAfter= alone).
    /// R2 addendum: `fold=1` on a phone simulator has no hinge either, so the pilot drives the band there too.
    var wantsFallbackPilot: Bool { !forcesPilot && (stopOn != nil || holdAfter != nil || fold) }

    var pilotSkill: Double { skill ?? Self.defaultSkill }

    func playMode(today: Int) -> PlayMode {
        switch mode ?? .level {
        case .level: return .level(min(max(level ?? 1, 1), LevelBook.count))
        case .endless: return .endless
        case .daily: return .daily(day: today)
        }
    }

    #if DEBUG
    private static func flag(_ value: String) -> Bool {
        let v = value.lowercased()
        return v.isEmpty || v == "1" || v == "on" || v == "true" || v == "yes"
    }

    private static func number(_ value: String) -> Double? {
        guard let d = Double(value), d.isFinite else { return nil }
        return d
    }

    /// Parses `key=value;key` (pure; tested).
    static func parse(_ raw: String) -> DemoMode {
        var config = DemoMode(raw: raw)
        for part in raw.split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let key = pieces.first, !key.isEmpty else { continue }
            let value = pieces.count > 1 ? pieces[1] : ""
            switch key {
            case "screen": config.screen = Screen(rawValue: value.lowercased())
            case "progress": config.progress = Preset(rawValue: value.lowercased())
            case "level":
                if let n = Int(value) { config.level = min(max(n, 1), LevelBook.count) }
            case "mode": config.mode = ModeKey(rawValue: value.lowercased())
            case "t":
                if let s = number(value) { config.playTo = max(s, 0) }
            case "skill":
                if let s = number(value) { config.skill = min(max(s, 0), 1) }
            case "band":
                if let b = number(value) { config.pinBand = min(max(b, Tuning.bandMin), 1) }
            case "fold": config.fold = flag(value)
            case "swap": config.swap = flag(value)
            case "results": config.outcome = Outcome(rawValue: value.lowercased())
            case "hint": config.hint = HintID(rawValue: value)
            case "freezeOn":
                config.stopOn = Stop.allCases.first { $0.rawValue.lowercased() == value.lowercased() }
            case "freezeAfter":
                if let s = number(value) { config.holdAfter = max(s, 0) }
            case "seed": config.seed = UInt64(value)
            case "sound": config.sound = flag(value)
            case "prompt": config.prompt = PromptKey(rawValue: value.lowercased())
            case "duolog": config.duoLog = flag(value)
            case "stage": config.stageName = DemoStageName(rawValue: value.lowercased())
            case "streak":
                if let n = Int(value) { config.streakDays = min(max(n, 0), 365) }
            case "ignore": config.ignoreKind = GloomKind(rawValue: value.lowercased())
            case "spawn": config.spawnFirefly = value.lowercased() == "firefly"
            case "pilotLag":
                if let s = number(value) { config.pilotLag = min(max(s, 0), 2) }
            default: break
            }
        }
        return config
    }
    #endif

    /// The scenario for this launch: DEBUG builds with `-glintDemo` only; nil otherwise.
    static let current: DemoMode? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-glintDemo") else { return nil }
        let raw = i + 1 < args.count ? args[i + 1] : ""
        // CI redirects stdout to a file (fully buffered); line-buffer it so the scripts see GLINT- lines on time.
        setvbuf(stdout, nil, _IOLBF, 0)
        return DemoMode.parse(raw)
        #else
        return nil
        #endif
    }()
}

// MARK: - Seeded progress (`progress=`)

/// Every number a seeded profile shows agrees with every other one (stars → unlocks, bests per level).
enum DemoPresets {
    /// mid: world 1 done with 26 ★ (Rooftops open), levels 11–13 played, Long Night and Today's Dawn open.
    static let midStars: [Int] = [3, 3, 2, 3, 2, 3, 3, 2, 3, 2, 3, 2, 1]
    /// done: every level won, mostly ★★★.
    static let doneTwoStarLevels: Set<Int> = [7, 18, 26, 29]

    /// `results=lost` (R3b): a lost session's stats with a known cause: 41 popped, 1,120 points, five flowers eaten (four
    /// by `cause`, one by another kind). Pure; tested (the tip matches the cause).
    static func lostStats(cause: GloomKind) -> DawnStats {
        var s = DawnStats()
        s.emerged = 58
        s.pops = 41
        s.score = 1_120
        s.longestChain = 6
        s.flowersEaten = 5
        let other: GloomKind = cause == .murk ? .wisp : .murk
        s.flowersEatenBy = [cause: 4, other: 1]
        if cause == .brute { s.brutesPopped = 1 }
        return s
    }

    /// `streak=<n>`: Today's Dawn finished on the last n days (today included), today's best 2,140.
    /// `spawn=firefly` (R4): `spec` with one firefly scripted at `time` (in the middle of the garden), groups kept sorted.
    /// Pure; tested.
    static func withFirefly(_ spec: LevelSpec, at time: Double) -> LevelSpec {
        var out = spec
        out.groups.append(SpawnGroup(time: max(time, 0), kind: .firefly, count: 1, u: 0.4...0.6, formation: .cluster,
                                     speedScale: 1))
        out.groups.sort { $0.time < $1.time }
        return out
    }

    static func applyStreak(_ days: Int?, to data: inout ProgressData, now: Date) {
        guard let days, days > 0 else { return }
        let today = DailySeed.day(for: now)
        let played = (0..<days).map { today - $0 }
        data.dailyPlayed = ProgressRules.cleanDays(data.dailyPlayed + played)
        data.dailyBests[String(today)] = max(data.dailyBests[String(today)] ?? 0, 2_140)
        data.bestDailyEver = max(data.bestDailyEver, 2_140)
        // Today's Dawn must be open for the card to show it.
        if ProgressRules.stars(data, level: ProgressRules.dailyLevel) == 0 {
            for i in 0..<min(ProgressRules.dailyLevel, data.levelStars.count) { data.levelStars[i] = max(data.levelStars[i], 2) }
        }
    }

    static func progress(_ preset: DemoMode.Preset?, now: Date) -> ProgressData {
        var d = ProgressData()
        d.firstLaunch = now.timeIntervalSince1970
        let today = DailySeed.day(for: now)
        switch preset ?? .fresh {
        case .fresh:
            return d
        case .mid:
            for (i, s) in midStars.enumerated() where i < d.levelStars.count {
                d.levelStars[i] = s
                d.levelBest[i] = 380 + 70 * i + 60 * s
            }
            d.endlessBest = 4_250
            d.dailyBests[String(today - 1)] = 3_180
            d.bestDailyEver = 3_180
            d.lastLevel = min(midStars.count, LevelBook.count)
            d.firstLaunch -= 3 * 86_400
            d.seenHints = HintRules.all.map { $0.rawValue }
            d.plays = 24
        case .done:
            for i in 0..<d.levelStars.count {
                let n = i + 1
                let s = doneTwoStarLevels.contains(n) ? 2 : 3
                d.levelStars[i] = s
                d.levelBest[i] = 420 + 95 * i + 60 * s
            }
            d.endlessBest = 18_640
            d.dailyBests[String(today - 1)] = 6_920
            d.dailyBests[String(today - 2)] = 7_410
            d.bestDailyEver = 7_410
            d.lastLevel = LevelBook.count
            d.firstLaunch -= 40 * 86_400
            d.seenHints = HintRules.all.map { $0.rawValue }
            d.plays = 140
        }
        return d
    }
}

// MARK: - App icon render (`screen=icon`)

@MainActor
enum IconExport {
    static let side: CGFloat = 1024
    static let fileName = "AppIcon-1024.png"

    /// Renders `AppIconArt` at 1024 × 1024 px through SwiftUI's `ImageRenderer` (no SpriteKit), opaque, as an RGB PNG
    /// with NO alpha (ITMS-90717; `OpaquePNG`), to Documents/AppIcon-1024.png, and prints `GLINT-ICON <path>` (ci.yml
    /// copies it). R2: if the renderer comes back dark (R1's solid-black icon) the CoreGraphics painter's own image is
    /// used; a final image whose mean luminance is under 0.08 logs `GLINT-T icon dark`.
    static func render() {
        let renderer = ImageRenderer(content: AppIconArt(side: side))
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        renderer.scale = 1
        renderer.isOpaque = true
        var picked: CGImage? = renderer.cgImage
        if let rendered = picked, IconPainter.stats(rendered).luminance < IconPainter.darkLuminance {
            #if DEBUG
            AppTrace.demo("GLINT-T icon renderer came back black; using the CoreGraphics painter")
            #endif
            picked = nil
        }
        if picked == nil { picked = IconPainter.image(side: side) }
        guard let image = picked else {
            #if DEBUG
            AppTrace.demo("GLINT-T icon failed: no image")
            #endif
            return
        }
        let stats = IconPainter.stats(image)
        AppTrace.note("icon lum=\(AppTrace.fixed(stats.luminance, 3)) colours=\(stats.colours)")
        #if DEBUG
        if stats.luminance < IconPainter.darkLuminance {
            AppTrace.demo("GLINT-T icon dark lum=\(AppTrace.fixed(stats.luminance, 3)) colours=\(stats.colours)")
        }
        AppTrace.demo("GLINT-T icon stats lum=\(AppTrace.fixed(stats.luminance, 3)) colours=\(stats.colours)")
        #endif
        guard let data = OpaquePNG.encode(image),
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            #if DEBUG
            AppTrace.demo("GLINT-T icon failed: no PNG data")
            #endif
            return
        }
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            #if DEBUG
            AppTrace.demo("GLINT-T icon ok \(image.width)x\(image.height) rgb=\(OpaquePNG.colorType(data) == 2 ? 1 : 0)")
            AppTrace.demo("GLINT-ICON \(url.path)")
            #endif
        } catch {
            #if DEBUG
            AppTrace.demo("GLINT-T icon failed: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - R5b store-frame freeze states (pure; tested)

enum DemoBusy {
    static let minSurfaced = 5
    static let minLit = 2
    /// A pop's FX counts as "in flight" this long after it.
    static let popFX = 0.4
    /// `freezeOn=busy` gives up this long (session time) after it starts watching.
    static let timeout = 10.0
    /// `freezeOn=firefly`: a surfaced firefly this close (d) to the band.
    static let fireflyReach = 0.15

    /// ≥ 5 surfaced glooms, ≥ 2 of them lit, and a pop's FX still on screen.
    static func isBusy(_ snap: DawnSnapshot, sinceLastPop: Double?) -> Bool {
        let surfaced = snap.glooms.filter { !$0.submerged }
        let lit = surfaced.filter { $0.lit > 0 }.count
        guard let since = sinceLastPop, since >= 0, since <= popFX else { return false }
        return surfaced.count >= minSurfaced && lit >= minLit
    }

    /// A firefly out of the crease shade, within reach of the band.
    static func fireflyNearBand(_ snap: DawnSnapshot) -> Bool {
        snap.fireflies.contains { $0.d >= Tuning.creaseShade && abs($0.d - snap.band) <= fireflyReach }
    }
}
