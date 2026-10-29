import Combine
import Foundation
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

// MARK: - HUD state (published at ≤ 15 Hz, observed only by the HUD and the cover view)

struct HUDState: Equatable {
    var score = 0
    var chain = 0
    var multiplier = 1.0
    var flowersLeft = 5
    var sun = 0.0
    var phase: SessionPhase = .waiting
    var wave = 0
}

@MainActor
final class HUDModel: ObservableObject {
    @Published private(set) var state = HUDState()
    /// A short banner on the mirror half ("Wave 3").
    @Published private(set) var banner: String?
    /// R2 addendum: what the hint line points at (SwiftUI coordinates), nil when gone.
    @Published private(set) var hintTarget: CGPoint?

    func update(_ s: HUDState) {
        if s != state { state = s }
    }

    func setBanner(_ text: String?) {
        if text != banner { banner = text }
    }

    func setHintTarget(_ p: CGPoint?) {
        guard let p else {
            if hintTarget != nil { hintTarget = nil }
            return
        }
        // Rounded to whole points so a still target doesn't republish.
        let q = CGPoint(x: p.x.rounded(), y: p.y.rounded())
        if q != hintTarget { hintTarget = q }
    }
}

/// What the Results screen shows.
struct ResultSummary: Equatable {
    var mode: PlayMode
    var title: String
    var won: Bool
    var stars: Int
    var score: Int
    var flowersLeft: Int
    var pops: Int
    var outcome: RecordOutcome
    /// R2: the flowers at the end (eaten ones greyed under the stars).
    var flowers: [Bool] = []
    /// R2 addendum: a lost level's one tip (from what ate the flowers).
    var tip: String?
    /// R2: achievement ids earned by this run (named on the card; banners held until now).
    var newAchievements: [String] = []
}

// MARK: - The controller

/// The app's brain and the scene's `GardenDriver` (design/ARCHITECTURE.md "The frame loop"): it picks the light's
/// source (the hinge on a Duo, drag on other iPhones, the pilot for the attract garden and CI), steps the session,
/// feeds Feedback, runs the level flow (GAME-DESIGN §7–§8: every level starts closed on a Duo, closing pauses and
/// opening resumes, always a way back to Home) and the routes.
@MainActor
final class GameController: ObservableObject, GardenDriver {
    // Published (changes are rare; nothing here is set per frame unless it changed)
    @Published private(set) var route: AppRoute = .home
    @Published var levelsWorld: Int = 1
    @Published private(set) var stage: PlayStage = .live
    @Published private(set) var pause = PauseFlags()
    @Published private(set) var prompt: PromptLine?
    @Published private(set) var hint: HintID?
    @Published private(set) var summary: ResultSummary?
    @Published private(set) var layout: GardenLayout
    @Published private(set) var isDuo = false
    @Published private(set) var hingeSeen: Bool
    @Published private(set) var scene: GardenScene?
    @Published private(set) var hingeRefresh = 0
    @Published private(set) var showsIcon = false
    /// Demo `screen=badges`: the ten Game Center badges on screen (while they are written to Documents/badges).
    @Published private(set) var showsBadges = false
    @Published private(set) var forcedCover = false
    @Published var coverDismissed = false
    @Published private(set) var playMode: PlayMode = .level(1)
    @Published private(set) var toast: String?
    /// R3: the level's 3rd-star target on the start card ("★★★ 1,400"); nil for endless / daily.
    @Published private(set) var startStarLine: String?
    @Published private(set) var reduceMotion = false

    let hud: HUDModel
    let store: ProgressStore
    let settings: SettingsStore
    let demo: DemoMode?
    let hinge: HingeMirrorSource
    let drag: DragMirrorSource
    let demoFold: Bool

    // Sessions and sources
    private var session: DawnSession?
    private var attract: DawnSession?
    private let attractPilot: PilotSource
    private var attractRestartAt: TimeInterval?
    private var attractRuns: UInt64 = 0
    private var playPilot: PilotSource?
    /// The pilot only stands in until a real hinge reports (demo `freezeOn=` / `freezeAfter=` alone).
    private var pilotIsFallback = false
    private var fixedSource: FixedBandSource?
    private var fixedIsFallback = false

    // Frame state
    private var canvas: CGSize = .zero
    private var graceLeft: Double = 0
    private var wentBackground = false
    private var finishAt: TimeInterval?
    private var sunriseStars: Int?
    private var hintShownAt: TimeInterval = 0
    /// R3 (REVIEW-2 fix 7): a raised hint waits here until its subject is on the field.
    private var pendingHint: HintID?
    /// R4: the hint whose "shown" line has been logged this session.
    private var hintLogged: HintID?
    private var pendingHintAt: TimeInterval = 0
    /// R3 (REVIEW-2 fix 12): the filtered hinge's jitter while it drives the light (About trace).
    private var jitter = JitterMeter()
    private var hintForced = false
    private var lastHUDPublish: TimeInterval = -1
    private var bannerUntil: TimeInterval = 0
    private var dragging = false
    private var feedbackPaused = true
    private var systemReduceMotion = false
    private var launched = false
    private var ticker: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var coverShown = false
    private var lastBandLog: TimeInterval = -1
    private var launchTime: TimeInterval = CACurrentMediaTime()
    /// `PlayStage.checking`: when to give up waiting for the hinge.
    private var checkUntil: TimeInterval = 0

    // Demo state
    private var demoFrozen = false
    private var freezeAt: TimeInterval?
    private var freezeTag = ""
    private var fixedStep = false
    private var demoTarget: Double?

    init(store: ProgressStore, settings: SettingsStore, demo: DemoMode?) {
        self.store = store
        self.settings = settings
        self.demo = demo
        self.hud = HUDModel()
        self.hinge = HingeMirrorSource()
        self.drag = DragMirrorSource()
        self.demoFold = demo?.fold ?? false
        self.hingeSeen = store.data.hingeSeen
        self.attractPilot = PilotSource(skill: 0.85, seed: demo?.seed ?? 11)
        self.layout = GardenLayout.make(size: CGSize(width: 390, height: 844), isDuo: false, swapHalves: false)
    }

    // MARK: - Derived

    var isPaused: Bool { pause.isPaused }

    /// The level being played (levels only).
    var currentLevel: Int? {
        if case let .level(n) = playMode { return n }
        return nil
    }

    /// The light source in play right now.
    private func playSource() -> any MirrorSource {
        if let p = playPilot, !(pilotIsFallback && hinge.hasHinge) { return p }
        if let f = fixedSource, !(fixedIsFallback && hinge.hasHinge) { return f }
        if hinge.hasHinge { return hinge }
        return drag
    }

    /// The real hinge aims the light in play.
    var hingeDriven: Bool {
        playSource() === hinge
    }

    /// A demo pilot / fixed band that drives the light whatever the device (t=, skill=, prompt=).
    private var firmDemoSource: Bool {
        (playPilot != nil && !pilotIsFallback) || (fixedSource != nil && !fixedIsFallback)
    }

    /// Drags move the light (phones, and a Duo whose hinge has never reported).
    private var dragDriven: Bool {
        playSource() === drag
    }

    // MARK: - Launch

    func launch() {
        guard !launched else { return }
        launched = true
        launchTime = CACurrentMediaTime()
        settings.apply()
        FeedbackDirector.shared.start()
        settings.apply()
        if hingeSeen { FeedbackDirector.shared.deviceHasFold = true }
        FeedbackDirector.shared.setPaused(true)
        feedbackPaused = true
        startTicker()
        AppTrace.note("launch duo=\(isDuo ? 1 : 0) hingeSeen=\(hingeSeen ? 1 : 0)")
        if let demo {
            #if DEBUG
            AppTrace.demo("GLINT-T demo '\(demo.raw)' starts")
            #endif
            applyDemo(demo)
        } else {
            GameCenterManager.shared.syncProgress(achievements: store.data.achievements, totalStars: store.totalStars)
            GameCenterManager.shared.authenticate()
            logScreen()
        }
    }

    // MARK: - Canvas and layout

    func canvasChanged(_ size: CGSize) {
        guard size.width > 1, size.height > 1, size.width.isFinite, size.height.isFinite else { return }
        if size != canvas {
            canvas = size
            coverDismissed = false
        }
        refreshLayout()
    }

    /// Rebuilds the layout from the canvas, the Duo flag and Swap halves; pushes it to the scene and the drag source.
    func refreshLayout() {
        guard canvas.width > 1, canvas.height > 1 else { return }
        let duo = AppRules.isDuo(window: canvas, hingeSeen: hingeSeen, demoFold: demoFold)
        if duo != isDuo { isDuo = duo }
        // Swap halves is a Duo setting (hidden on phones, where it would also put the lever under the pause button).
        // R3 (REVIEW-2 fix 12): only in book pose on a Duo (in laptop pose it would lay the mirror on the table).
        let swap = AppRules.swapAllowed(isDuo: duo, size: canvas) && settings.swapHalves
        let fresh = GardenLayout.make(size: canvas, isDuo: duo, swapHalves: swap)
        let changed = fresh != layout || scene == nil
        if fresh != layout { layout = fresh }
        drag.layout = fresh
        if let scene {
            if changed { scene.apply(layout: fresh) }
        } else {
            makeScene(fresh)
        }
        refreshLever()
        scene?.reduceMotion = reduceMotion
        if changed {
            AppTrace.note("canvas \(Int(canvas.width.rounded()))x\(Int(canvas.height.rounded())) fold=\(duo ? 1 : 0)")
            #if DEBUG
            AppTrace.demo("GLINT-T canvas \(Int(canvas.width.rounded()))x\(Int(canvas.height.rounded())) fold=\(duo ? 1 : 0)")
            #endif
        }
    }

    private func makeScene(_ layout: GardenLayout) {
        let s = GardenScene(layout: layout)
        s.driver = self
        s.attract = !route.showsSession
        s.showsLever = AppRules.showsLever(route: route, hasHinge: hinge.hasHinge, isDuo: isDuo)
        s.reduceMotion = reduceMotion
        scene = s
    }

    func setSystemReduceMotion(_ on: Bool) {
        systemReduceMotion = on
        if settings.systemReduceMotion != on { settings.systemReduceMotion = on }
        refreshMotion()
    }

    func refreshMotion() {
        let on = settings.reduceMotion(system: systemReduceMotion)
        if on != reduceMotion { reduceMotion = on }
        scene?.reduceMotion = on
    }

    // MARK: - Hinge

    func hingeSample(angle: Double, time: TimeInterval) {
        hinge.ingest(angleDegrees: angle, at: time)
        if !hingeSeen {
            hingeSeen = true
            store.noteHingeSeen()
            // The Duo's Taptic Engine is weak: Strong haptics (Feel NEEDS).
            FeedbackDirector.shared.deviceHasFold = true
            AppTrace.note("hinge seen \(AppTrace.fixed(angle, 1))")
            refreshLayout()
        }
        refreshLever()
        checkGates()
    }

    func hingeUnavailable() {
        AppTrace.note("hinge unavailable")
    }

    /// The cover display came or went (RootView).
    func coverChanged(_ shown: Bool) {
        guard shown != coverShown else { return }
        coverShown = shown
        // iOS may go silent after a display hand-off: re-subscribe to the hinge (Hush QA-5).
        hingeRefresh &+= 1
        if shown {
            AppTrace.note("cover shown")
            #if DEBUG
            AppTrace.demo("GLINT-T screen cover")
            #endif
        } else {
            AppTrace.note("cover hidden")
            logScreen()
        }
    }

    // MARK: - Scene phase (GAME-DESIGN §8: inactive pauses)

    func setScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            hinge.reset()
            let r = PauseRules.activated(pause, wentToBackground: wentBackground,
                                         phase: session?.snapshot.phase ?? .waiting,
                                         hingeShut: hingeDriven && hinge.isShut)
            wentBackground = false
            setPause(r.flags)
            if r.grace > 0 { graceLeft = r.grace }
            AppTrace.note("phase active")
        case .inactive:
            if route == .play { setPause(PauseRules.deactivated(pause)) }
            AppTrace.note("phase inactive")
        case .background:
            wentBackground = true
            if route == .play { setPause(PauseRules.deactivated(pause)) }
            AppTrace.note("phase background")
        @unknown default:
            break
        }
        UIApplication.shared.isIdleTimerDisabled = route == .play
    }

    // MARK: - Routes

    func go(_ next: AppRoute) {
        if route != next { route = next }
        refreshLever()
        scene?.attract = !next.showsSession
        // On a Duo nobody touches the screen in play: keep it awake there.
        UIApplication.shared.isIdleTimerDisabled = next == .play
        // R2: achievement banners wait while a level is on screen (they land with the Results card).
        GameCenterManager.shared.setHoldBanners(next == .play)
        logScreen()
    }

    /// The phone lever: play only, drag only, never on a Duo split layout (R2 addendum).
    private func refreshLever() {
        let on = AppRules.showsLever(route: route, hasHinge: hinge.hasHinge, isDuo: isDuo)
        if scene?.showsLever != on { scene?.showsLever = on }
    }

    private func logScreen() {
        AppTrace.note("screen \(route.rawValue)")
        guard !coverShown else { return }
        #if DEBUG
        AppTrace.demo("GLINT-T screen \(route.rawValue)")
        #endif
    }

    func back() {
        FeedbackDirector.shared.ui(.back)
        let target = AppRules.back(from: route)
        if route == .play || route == .results {
            leavePlay()
        }
        go(target)
    }

    func open(_ next: AppRoute) {
        FeedbackDirector.shared.ui(.tap)
        go(next)
    }

    func openLevels(world: Int? = nil) {
        FeedbackDirector.shared.ui(.tap)
        let w = world ?? LevelBook.world(of: currentLevel ?? store.nextLevel)
        levelsWorld = min(max(w, 1), LevelBook.worldCount)
        if route == .play || route == .results { leavePlay() }
        go(.levels)
    }

    func selectWorld(_ w: Int) {
        let clamped = min(max(w, 1), LevelBook.worldCount)
        guard clamped != levelsWorld else { return }
        FeedbackDirector.shared.ui(.toggle)
        levelsWorld = clamped
    }

    func goHome() {
        FeedbackDirector.shared.ui(.back)
        leavePlay()
        go(.home)
    }

    // MARK: - Starting play

    /// Home's Play: the next level.
    func playNext() {
        play(.level(store.nextLevel))
    }

    func playLevel(_ n: Int) {
        guard ProgressRules.isUnlocked(level: n, store.data) else {
            FeedbackDirector.shared.ui(.back)
            let w = LevelBook.world(of: n)
            if !ProgressRules.isWorldOpen(w, store.data) {
                let missing = ProgressRules.starsMissing(toOpen: w, store.data)
                showToast("\(missing) more ★ in \(LevelBook.worldName(w - 1)) to open \(LevelBook.worldName(w))")
            } else {
                showToast("Win level \(n - 1) to open this sunrise")
            }
            return
        }
        play(.level(n))
    }

    func playEndless() {
        guard ProgressRules.endlessUnlocked(store.data, now: Date()) else {
            FeedbackDirector.shared.ui(.back)
            showToast("Win level \(ProgressRules.endlessLevel) to open Long Night")
            return
        }
        play(.endless)
    }

    func playDaily() {
        guard ProgressRules.dailyUnlocked(store.data) else {
            FeedbackDirector.shared.ui(.back)
            showToast("Win level \(ProgressRules.dailyLevel) to open Today's Dawn")
            return
        }
        play(.daily(day: DailySeed.day(for: Date())))
    }

    /// Starts `mode`: on a Duo with the phone open, "Close the phone to start" first (no session until shut is seen).
    func play(_ mode: PlayMode) {
        if route == .play { recordPartialIfNeeded() }
        FeedbackDirector.shared.ui(.tap)
        playMode = mode
        summary = nil
        session = nil
        finishAt = nil
        sunriseStars = nil
        demoFrozen = false
        freezeAt = nil
        graceLeft = 0
        setPause(PauseFlags())
        hint = nil
        hintForced = false
        pendingHint = nil
        hintLogged = nil
        startStarLine = mode.isLevel ? AppRules.starTargetLine(Self.starScore(for: mode)) : nil
        hud.update(HUDState())
        hud.setBanner(nil)
        store.noteStarted(mode)
        drag.dragEnded()
        dragging = false
        go(.play)
        if demo?.prompt == .close {
            stage = .closeFirst
            refreshPrompt()
            return
        }
        let now = CACurrentMediaTime()
        if AppRules.needsHingeCheck(hasHinge: hinge.hasHinge, pilotOrFixed: firmDemoSource,
                                    hingeSeen: hingeSeen, duoLog: demo?.duoLog ?? false,
                                    sinceLaunch: now - launchTime) {
            stage = .checking
            checkUntil = now + AppRules.hingeWait
            setFeedbackPaused(true)
            AppTrace.note("stage checking")
            refreshPrompt()
        } else if AppRules.startsClosed(hingeDriven: hingeDriven, isShut: hinge.isShut) {
            stage = .closeFirst
            AppTrace.note("stage closeFirst \(AppRules.modeName(mode))")
            setFeedbackPaused(true)
            refreshPrompt()
        } else {
            beginSession()
        }
    }

    private func beginSession() {
        let rolling = demo?.seed ?? UInt64(truncatingIfNeeded: Int(Date().timeIntervalSince1970 * 1000))
        let seed = AppRules.seed(for: playMode, rolling: rolling)
        let s: DawnSession
        if let demo, demo.spawnFirefly, let t = demo.playTo, case let .level(n) = playMode {
            // R4 demo `spawn=firefly`: the level's own script plus one firefly 1 s before the freeze.
            s = DawnSession(mode: playMode, spec: DemoPresets.withFirefly(LevelBook.level(n), at: t - 1), seed: seed)
        } else {
            s = DawnSession(mode: playMode, seed: seed)
        }
        session = s
        stage = .live
        drag.layout = layout
        // A fresh level: band in the crease, finger forgotten, hasMoved cleared ("Drag … to let the light in" again).
        drag.reset(band: Tuning.bandMin)
        playPilot?.observe(s.snapshot)
        playPilot?.resetClock()
        if let forced = demo?.hint {
            showHint(forced, now: CACurrentMediaTime(), forced: true)
        }
        FeedbackDirector.shared.ui(.levelStart)
        setFeedbackPaused(false)
        refreshPrompt()
        publishHUD(s.snapshot, now: CACurrentMediaTime(), force: true)
        AppTrace.note("session \(AppRules.modeName(playMode))")
    }

    /// Endless / daily left early: the score so far still counts as a run (bests keep the larger).
    private func recordPartialIfNeeded() {
        guard let s = session, !s.isFinished, !playMode.isLevel, s.snapshot.score > 0 else { return }
        let outcome = store.record(mode: playMode, won: false, stars: 0, score: s.snapshot.score, now: Date())
        reportGameCenter(mode: playMode, score: s.snapshot.score, outcome: outcome)
        // A Long Night left early still counts for Night Watch (Core reads the score from the stats).
        _ = recordAchievements(stats: s.stats, phase: s.snapshot.phase)
    }

    private func leavePlay() {
        recordPartialIfNeeded()
        session = nil
        stage = .live
        graceLeft = 0
        setPause(PauseFlags())
        if prompt != nil {
            prompt = nil
            logPrompt()
        }
        hint = nil
        pendingHint = nil
        finishAt = nil
        demoFrozen = false
        freezeAt = nil
        fixedStep = false
        demoTarget = nil
        dragging = false
        drag.dragEnded()
        hud.setBanner(nil)
        setFeedbackPaused(true)
        FeedbackDirector.shared.silence()
    }

    // MARK: - Pause buttons (always a way back to Home)

    func pauseTapped() {
        guard route == .play else { return }
        FeedbackDirector.shared.ui(.tap)
        var f = pause
        f.menu = true
        graceLeft = 0
        setPause(f)
    }

    func resumeTapped() {
        FeedbackDirector.shared.ui(.tap)
        let r = PauseRules.resumedFromMenu(pause)
        setPause(r.flags)
        graceLeft = r.grace
        hinge.reset()
    }

    func restartTapped() {
        play(playMode)
    }

    private func setPause(_ next: PauseFlags) {
        guard next != pause else { return }
        let before = pause
        pause = next
        if next.shut && !before.shut {
            AppTrace.note("paused shut")
            #if DEBUG
            AppTrace.demo("GLINT-T paused shut")
            #endif
        }
        if next.menu && !before.menu {
            AppTrace.note("paused menu")
            #if DEBUG
            AppTrace.demo("GLINT-T paused menu")
            #endif
        }
        if next.inactive && !before.inactive {
            AppTrace.note("paused inactive")
            #if DEBUG
            AppTrace.demo("GLINT-T paused inactive")
            #endif
        }
        if before.isPaused && !next.isPaused {
            AppTrace.note("resumed angle \(hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-")")
            #if DEBUG
            AppTrace.demo("GLINT-T resumed")
            #endif
        }
        setFeedbackPaused(PauseRules.isFrozen(next, grace: graceLeft) || route != .play)
    }

    private func setFeedbackPaused(_ paused: Bool) {
        guard paused != feedbackPaused else { return }
        feedbackPaused = paused
        FeedbackDirector.shared.setPaused(paused)
    }

    // MARK: - Gates (frames, hinge samples and a 4 Hz ticker all check them: never stuck)

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self else { return }
                self.checkGates()
            }
        }
    }

    private func checkGates() {
        guard route == .play, demo?.prompt != .close else { return }
        if stage == .checking {
            if hinge.hasHinge && hingeDriven {
                if AppRules.startsClosed(hingeDriven: true, isShut: hinge.isShut) {
                    stage = .closeFirst
                    AppTrace.note("stage closeFirst (hinge reported)")
                    refreshPrompt()
                } else {
                    beginSession()
                }
            } else if CACurrentMediaTime() >= checkUntil || firmDemoSource {
                AppTrace.note("no hinge: drag")
                beginSession()
            }
            return
        }
        guard stage == .closeFirst else { return }
        if !hingeDriven {
            // The hinge isn't aiming the light (it never reported): nothing to close, start at once.
            beginSession()
        } else if hinge.isShut {
            AppTrace.note("shut seen")
            beginSession()
        }
    }

    // MARK: - GardenDriver

    func advance(dt rawDT: Double, now: TimeInterval) -> (DawnSnapshot, [GameEvent]) {
        let dt = AppRules.clampDT(rawDT)
        if route.showsSession {
            return playFrame(dt: dt, now: now)
        }
        return attractFrame(dt: dt, now: now)
    }

    func dragBegan(_ p: CGPoint) {
        guard route == .play, dragDriven, !pause.isPaused else { return }
        dragging = true
        drag.dragBegan(p)
    }

    func dragMoved(_ p: CGPoint) {
        guard dragging, route == .play, dragDriven else { return }
        drag.dragMoved(p)
    }

    func dragEnded() {
        guard dragging else { return }
        dragging = false
        drag.dragEnded()
    }

    // MARK: - Frames

    private func playFrame(dt: Double, now: TimeInterval) -> (DawnSnapshot, [GameEvent]) {
        let source = playSource()
        let input = source.mirror(at: now)
        if stage != .live {
            checkGates()
        }
        guard stage == .live, let session else {
            var placeholder = DawnSnapshot(mode: playMode)
            // The light the hinge really makes (shut = dark): never more.
            placeholder.band = input.band
            placeholder.creaseGlow = input.creaseGlow
            logBand(input: input, drawn: input.band, phase: nil, now: now)
            refreshPrompt()
            return (placeholder, [])
        }
        let phaseBefore = session.snapshot.phase
        stepPause(dt: dt, phase: phaseBefore)
        let frozen = demoFrozen || PauseRules.isFrozen(pause, grace: graceLeft) || session.isFinished || route != .play
        var stepDT = frozen ? 0 : dt
        if fixedStep && stepDT > 0 { stepDT = 1.0 / 120.0 }
        var events: [GameEvent] = []
        if stepDT > 0 {
            events = session.step(dt: stepDT, input: input)
        }
        var snap = session.snapshot
        playPilot?.observe(snap)
        if route == .play && !demoFrozen {
            if !events.isEmpty {
                FeedbackDirector.shared.handle(events, snapshot: snap)
            }
            FeedbackDirector.shared.frame(snapshot: snap, dt: stepDT)
        }
        handleEvents(events, snapshot: snap, now: now)
        demoChecks(snap, events: events, now: now)
        if demoFrozen, let pinned = demo?.pinBand {
            snap.band = pinned
            snap.creaseGlow = 1
        }
        publishHUD(snap, now: now, force: false)
        tickHint(now: now, snapshot: snap)
        refreshPrompt()
        logBand(input: input, drawn: snap.band, phase: snap.phase, now: now)
        if stepDT > 0, hingeDriven, let a = hinge.angle { jitter.add(angle: a, dt: stepDT) }
        if let at = finishAt, now >= at, !demoFrozen, route == .play {
            finishAt = nil
            showResults()
        }
        return (snap, events)
    }

    private func attractFrame(dt: Double, now: TimeInterval) -> (DawnSnapshot, [GameEvent]) {
        if attract == nil { newAttract() }
        if let at = attractRestartAt, now >= at {
            attractRestartAt = nil
            newAttract()
        }
        guard let attract else { return (DawnSnapshot(mode: .endless), []) }
        // On a Duo the phone's angle is the light, even behind the menus; elsewhere the pilot plays.
        let useHinge = hinge.hasHinge && demo == nil
        let input = useHinge ? hinge.mirror(at: now) : attractPilot.mirror(at: now)
        let events = dt > 0 ? attract.step(dt: dt, input: input) : []
        let snap = attract.snapshot
        attractPilot.observe(snap)
        if attract.isFinished && attractRestartAt == nil {
            attractRestartAt = now + 2.5
        }
        // The menus' music: only the dawn pad, softer (Feel).
        FeedbackDirector.shared.ambience(sun: Self.menuSun)
        return (snap, events)
    }

    /// The dawn pad's brightness behind the menus.
    static let menuSun = 0.45

    private func newAttract() {
        attractRuns &+= 1
        let base = demo?.seed ?? 11
        let s = DawnSession(mode: .endless, seed: base &+ attractRuns)
        attract = s
        attractPilot.observe(s.snapshot)
        attractPilot.resetClock()
    }

    private func stepPause(dt: Double, phase: SessionPhase) {
        guard route == .play else { return }
        let input = PauseInput(phase: phase, hingeDriven: hingeDriven, hingeShut: hinge.isShut,
                               canResume: hinge.canResume)
        let r = PauseRules.step(pause, grace: graceLeft, input: input, dt: dt)
        let wasShut = pause.shut
        graceLeft = r.grace
        setPause(r.flags)
        if wasShut && !r.flags.shut { hinge.reset() }
        setFeedbackPaused(PauseRules.isFrozen(pause, grace: graceLeft) || demoFrozen)
    }

    private func handleEvents(_ events: [GameEvent], snapshot: DawnSnapshot, now: TimeInterval) {
        guard !events.isEmpty else { return }
        for e in events {
            if let h = hint, !hintForced, HintRules.isDone(h, by: e) { hint = nil }
            switch e {
            case .started:
                AppTrace.note("started")
            case let .hint(id):
                offerHint(id, now: now)
            case let .sunrise(stars, _):
                sunriseStars = stars
                if finishAt == nil { finishAt = now + 2.2 }
            case .nightWins:
                if finishAt == nil { finishAt = now + 1.8 }
            case let .waveUp(n):
                var s = hud.state
                s.wave = n
                hud.update(s)
                hud.setBanner("Wave \(n)")
                bannerUntil = now + 2.0
            default:
                break
            }
            #if DEBUG
            if AppTrace.demoEnabled, let line = Self.describe(e) {
                AppTrace.demo("GLINT-T event " + line)
            }
            #endif
        }
    }

    #if DEBUG
    /// The part after `GLINT-T event ` for the events CI cares about (nil for the rest).
    private static func describe(_ e: GameEvent) -> String? {
        switch e {
        case .started: return "started"
        case let .surfaced(_, kind, _, d): return "surfaced kind=\(kind.rawValue) d=\(AppTrace.fixed(d, 2))"
        case let .popped(_, kind, _, _, chain, points): return "popped kind=\(kind.rawValue) chain=\(chain) points=\(points)"
        case let .swept(count, bonus): return "swept count=\(count) bonus=\(bonus)"
        case let .flowerEaten(lane, left, kind): return "flowerEaten lane=\(lane) left=\(left) by=\(kind.rawValue)"
        case let .fireflyDelivered(_, lane, replanted, _): return "fireflyDelivered lane=\(lane) replanted=\(replanted ? 1 : 0)"
        case .fireflyScorched: return "fireflyScorched"
        case let .sunrise(stars, bonus): return "sunrise stars=\(stars) bonus=\(bonus)"
        case .nightWins: return "nightWins"
        case let .waveUp(n): return "waveUp \(n)"
        case let .hint(id): return "hint \(id.rawValue)"
        default: return nil
        }
    }
    #endif

    // MARK: - Prompt, hints, HUD

    private func refreshPrompt() {
        var next: PromptLine?
        if route == .play {
            if let forced = demo?.prompt {
                switch forced {
                case .close: next = .closeToStart
                case .open: next = session?.snapshot.phase == .waiting ? .openToLight : nil
                case .drag: next = session?.snapshot.phase == .waiting ? .drag(direction: AppRules.dragDirection(layout)) : nil
                }
            } else {
                next = AppRules.prompt(stage: stage, phase: session?.snapshot.phase, hingeDriven: hingeDriven,
                                       layout: layout)
            }
        }
        if next != prompt {
            prompt = next
            logPrompt()
        }
    }

    private func logPrompt() {
        AppTrace.note("prompt \(PromptLine.logWord(prompt))")
        #if DEBUG
        AppTrace.demo("GLINT-T prompt \(PromptLine.logWord(prompt))")
        #endif
    }

    /// `GLINT-T band <b> angle <θ> phase <p> shut <0|1>` at 2 Hz while the play screen is up (DEBUG demo only).
    private func logBand(input: MirrorInput, drawn: Double, phase: SessionPhase?, now: TimeInterval) {
        #if DEBUG
        guard AppTrace.demoEnabled, route == .play else { return }
        guard now - lastBandLog >= 0.5 || lastBandLog < 0 || now < lastBandLog else { return }
        lastBandLog = now
        let angleText: String = hinge.hasHinge ? AppTrace.fixed(hinge.angle ?? -1, 1) : "-1"
        let shut: Bool = hinge.hasHinge ? hinge.isShut : input.isShut
        AppTrace.demo("GLINT-T band \(AppTrace.fixed(drawn, 3)) angle \(angleText) phase "
                      + "\(AppRules.phaseName(phase)) shut \(shut ? 1 : 0)")
        #endif
    }

    /// R3 (REVIEW-2 fix 7): a hint waits for its subject (up to `HintQueue.waitLimit`), and is marked seen only
    /// once it has actually been shown.
    private func offerHint(_ id: HintID, now: TimeInterval) {
        guard !hintForced else { return }
        guard HintRules.shouldShow(id, seen: store.data.seenHints) else { return }
        pendingHint = id
        pendingHintAt = now
    }

    private func showHint(_ id: HintID, now: TimeInterval, forced: Bool) {
        hint = id
        hintShownAt = now
        hintForced = forced
        AppTrace.note("hint \(id.rawValue)")
    }

    private func tickHint(now: TimeInterval, snapshot: DawnSnapshot) {
        if let p = pendingHint, hint == nil || !hintForced {
            let visible = AppRules.hintSubject(p, snapshot: snapshot) != nil
            switch HintQueue.decide(subjectVisible: visible, raisedAt: pendingHintAt, now: now) {
            case .show:
                pendingHint = nil
                store.markSeen(p)
                showHint(p, now: now, forced: false)
            case .drop:
                pendingHint = nil
            case .wait:
                break
            }
        }
        guard let h = hint, !hintForced else { return }
        if now - hintShownAt >= HintRules.lifetime(h) || now < hintShownAt { hint = nil }
    }

    private func publishHUD(_ snap: DawnSnapshot, now: TimeInterval, force: Bool) {
        if hud.banner != nil && now >= bannerUntil { hud.setBanner(nil) }
        guard force || now - lastHUDPublish >= 1.0 / 15.0 || now < lastHUDPublish else { return }
        lastHUDPublish = now
        var s = hud.state
        s.score = snap.score
        s.chain = snap.chain
        s.multiplier = snap.multiplier
        s.flowersLeft = snap.flowersLeft
        s.sun = snap.sun
        s.phase = snap.phase
        // R3: the wave comes from the session itself (a fast-forward skips the .waveUp events).
        if let session, case .endless = playMode { s.wave = session.wave }
        hud.update(s)
        if let h = hint, let subject = AppRules.hintSubject(h, snapshot: snap) {
            // R4: the Scene's own mapping (book layouts inset the flower edge for the thumb).
            hud.setHintTarget(GardenScene.canvasPoint(layout: layout, u: subject.u, d: max(subject.d, 0)))
            // R4: the first frame a hint is really on screen (its subject on the field) is logged once.
            if hintLogged != h {
                hintLogged = h
                AppTrace.note("hint \(h.rawValue) shown")
                #if DEBUG
                AppTrace.demo("GLINT-T hint \(h.rawValue) shown")
                #endif
            }
        } else {
            hud.setHintTarget(nil)
        }
    }

    // MARK: - Results

    private func showResults() {
        guard let s = session else { return }
        let snap = s.snapshot
        let won = snap.phase == .won
        var stars = 0
        if won && playMode.isLevel {
            stars = sunriseStars ?? DawnSession.stars(flowersLeft: snap.flowersLeft, score: snap.score,
                                                       starScore: Self.starScore(for: playMode) ?? 0)
        }
        let outcome = store.record(mode: playMode, won: won, stars: stars, score: snap.score, now: Date())
        let fresh = recordAchievements(stats: s.stats, phase: snap.phase)
        var result = ResultSummary(mode: playMode, title: AppRules.modeTitle(playMode), won: won, stars: stars,
                                   score: snap.score, flowersLeft: snap.flowersLeft, pops: snap.pops, outcome: outcome)
        result.flowers = snap.flowers
        result.tip = playMode.isLevel ? TipRules.tip(won: won, stats: s.stats) : nil
        result.newAchievements = fresh
        summary = result
        reportGameCenter(mode: playMode, score: snap.score, outcome: outcome)
        hint = nil
        if prompt != nil {
            prompt = nil
            logPrompt()
        }
        setFeedbackPaused(true)
        AppTrace.note("result \(AppRules.modeName(playMode)) won=\(won ? 1 : 0) stars=\(stars) score=\(snap.score)")
        #if DEBUG
        AppTrace.demo("GLINT-T result \(AppRules.modeName(playMode)) won=\(won ? 1 : 0) stars=\(stars) "
                      + "score=\(snap.score) flowers=\(snap.flowersLeft) pops=\(snap.pops)")
        #endif
        go(.results)
    }

    /// R2: Core's `Achievements.earned` for this finished session and the saved progress; files the new ones and
    /// reports them (Game Center shows their banners now: the Results card is up). Never in demo runs' Game Center.
    /// R3: a level's 3rd-star score target (Core's `LevelSpec.starScore`); nil for endless / daily or no target.
    static func starScore(for mode: PlayMode) -> Int? {
        guard case let .level(n) = mode else { return nil }
        let target = LevelBook.level(n).starScore
        return target > 0 ? target : nil
    }

    private func recordAchievements(stats: DawnStats, phase: SessionPhase) -> [String] {
        let d = store.data
        var won = Set<Int>()
        for n in 0..<d.levelStars.count where d.levelStars[n] >= 1 { won.insert(n + 1) }
        let ids = Achievements.earned(stats: stats, mode: playMode, outcome: phase,
                                      progressStars: ProgressRules.totalStars(d), levelsWon: won)
        let fresh = store.addAchievements(ids)
        if !fresh.isEmpty {
            AppTrace.note("achievements \(fresh.joined(separator: ","))")
            #if DEBUG
            AppTrace.demo("GLINT-T achievements \(fresh.joined(separator: ","))")
            #endif
        }
        if demo == nil {
            GameCenterManager.shared.syncProgress(achievements: store.data.achievements, totalStars: store.totalStars)
            GameCenterManager.shared.unlock(fresh)
        }
        return fresh
    }

    private func reportGameCenter(mode: PlayMode, score: Int, outcome: RecordOutcome) {
        guard demo == nil else { return }
        let gc = GameCenterManager.shared
        switch mode {
        case .level:
            gc.submitStars(outcome.totalStars)
        case .endless:
            gc.submitEndless(score)
        case let .daily(day):
            gc.submitDaily(score, day: day)
        }
    }

    func nextTapped() {
        guard let n = summary?.outcome.nextLevel else { return }
        play(.level(n))
    }

    func retryTapped() {
        play(playMode)
    }

    // MARK: - Game Center, toasts, diagnostics

    func openGameCenter() {
        FeedbackDirector.shared.ui(.tap)
        switch GameCenterManager.shared.showDashboard() {
        case .shown, .signingIn:
            break
        case .signedOut:
            showToast("Sign in to Game Center in the Settings app to see the leaderboards")
        }
    }

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard let self, !Task.isCancelled else { return }
            self.toast = nil
        }
    }

    /// About's hold-the-version gesture: a plain-text report (nothing leaves the phone unless the player pastes it).
    func copyDiagnostics() {
        UIPasteboard.general.string = diagnosticsText()
        FeedbackDirector.shared.ui(.unlock)
        showToast("Diagnostics copied")
    }

    func diagnosticsText() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info["CFBundleVersion"] as? String) ?? "?"
        let d = store.data
        var lines: [String] = []
        lines.append("\(AppBrand.name) \(version) (\(build)) diagnostics")
        lines.append("device \(Self.machineName()) iOS \(UIDevice.current.systemVersion)")
        lines.append("canvas \(Int(canvas.width))x\(Int(canvas.height)) duo=\(isDuo ? 1 : 0) foldVertical="
                     + "\(layout.foldVertical ? 1 : 0) gardenAfter=\(layout.gardenAfter ? 1 : 0)")
        lines.append("jitterDeg p95 \(jitter.p95.map { AppTrace.fixed($0, 2) } ?? "-") samples \(jitter.samples.count)")
        lines.append("hinge seen=\(hingeSeen ? 1 : 0) live=\(hinge.hasHinge ? 1 : 0) angle="
                     + "\(hinge.angle.map { AppTrace.fixed($0, 1) } ?? "-") shut=\(hinge.isShut ? 1 : 0) "
                     + "canResume=\(hinge.canResume ? 1 : 0)")
        lines.append("route \(route.rawValue) stage \(stage.rawValue) pause \(pause.reason) mode "
                     + "\(AppRules.modeName(playMode)) phase \(AppRules.phaseName(session?.snapshot.phase))")
        let s = settings.snapshot
        lines.append("settings sound=\(s.soundOn ? 1 : 0) music=\(s.musicOn ? 1 : 0) haptics=\(s.hapticsOn ? 1 : 0) "
                     + "swap=\(s.swapHalves ? 1 : 0) reduceMotion=\(reduceMotion ? 1 : 0) chosen="
                     + "\(s.reduceMotionChoice.map { $0 ? "1" : "0" } ?? "-")")
        lines.append("progress stars=\(ProgressRules.totalStars(d))/\(ProgressRules.maxTotalStars()) next="
                     + "\(ProgressRules.nextLevel(d)) endlessBest=\(d.endlessBest) dailyBest=\(d.bestDailyEver) "
                     + "plays=\(d.plays)")
        lines.append("")
        lines.append("Recent:")
        lines.append(AppTrace.recentNotes())
        lines.append("")
        lines.append("Hinge trace:")
        lines.append(hinge.traceText())
        return lines.joined(separator: "\n")
    }

    private static func machineName() -> String {
        var info = utsname()
        uname(&info)
        let name: String = withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return name.isEmpty ? UIDevice.current.model : name
    }

    // MARK: - Demo

    private func applyDemo(_ demo: DemoMode) {
        let today = DailySeed.day(for: Date())
        let mode = demo.playMode(today: today)
        switch demo.effectiveScreen {
        case .home:
            go(.home)
        case .levels:
            levelsWorld = LevelBook.world(of: demo.level ?? store.nextLevel)
            go(.levels)
        case .settings:
            go(.settings)
        case .about:
            go(.about)
        case .play:
            startDemoPlay(demo, mode: mode)
        case .results:
            runDemoResults(demo, mode: mode)
        case .cover:
            forcedCover = true
            if demo.playTo != nil || demo.mode != nil || demo.level != nil {
                startDemoPlay(demo, mode: mode)
                var f = pause
                f.menu = true
                setPause(f)
                demoFrozen = true
            } else {
                go(.home)
            }
        case .badges:
            showsBadges = true
            #if DEBUG
            AppTrace.demo("GLINT-T screen badges")
            #endif
            BadgeExport.renderAll(ids: GameCenterManager.achievementIDs)
        case .icon:
            showsIcon = true
            #if DEBUG
            AppTrace.demo("GLINT-T screen icon")
            #endif
            IconExport.render()
        }
    }

    private func startDemoPlay(_ demo: DemoMode, mode: PlayMode) {
        let seed = demo.seed ?? DemoMode.defaultSeed
        if demo.prompt == .open || demo.prompt == .drag {
            fixedSource = FixedBandSource(band: Tuning.bandMin)
            fixedIsFallback = false
        } else if demo.forcesPilot || (demo.wantsFallbackPilot && demo.pinBand == nil) {
            playPilot = PilotSource(skill: demo.pilotSkill, seed: seed)
            pilotIsFallback = demo.wantsFallbackPilot
        } else if let b = demo.pinBand {
            fixedSource = FixedBandSource(band: b)
            fixedIsFallback = true
        }
        play(mode)
        if let t = demo.playTo {
            fastForward(to: t, tail: demo.stopOn == nil)
        }
    }

    /// `t=`: headless 1/120 s steps with the pilot up to t − 0.5 s, then live 1/120 s steps to t, then freeze.
    private func fastForward(to t: Double, tail: Bool) {
        guard let session, let pilot = playPilot else { return }
        let step = 1.0 / 120.0
        let target = max(t - (tail ? DemoMode.liveTail : 0), 0)
        var clock: TimeInterval = 0
        var budget = Int((t + 120) * 120)
        pilot.resetClock()
        while session.snapshot.time < target && !session.isFinished && budget > 0 {
            let input = pilot.mirror(at: clock)
            let events = session.step(dt: step, input: input)
            pilot.observe(session.snapshot)
            for e in events {
                if case let .sunrise(stars, _) = e { sunriseStars = stars }
                if case let .hint(id) = e, demo?.hint == nil {
                    store.markSeen(id)
                    showHint(id, now: CACurrentMediaTime(), forced: false)
                }
            }
            clock += step
            budget -= 1
        }
        pilot.resetClock()
        publishHUD(session.snapshot, now: CACurrentMediaTime(), force: true)
        AppTrace.note("skipped \(AppTrace.fixed(session.snapshot.time, 2))")
        #if DEBUG
        AppTrace.demo("GLINT-T skipped \(AppTrace.fixed(session.snapshot.time, 2))")
        #endif
        if tail {
            fixedStep = true
            demoTarget = t
        } else {
            fixedStep = true
        }
    }

    private func demoChecks(_ snap: DawnSnapshot, events: [GameEvent], now: TimeInterval) {
        guard let demo, route == .play, !demoFrozen, let session else { return }
        if let at = freezeAt {
            if now >= at { freeze(freezeTag) }
            return
        }
        if let target = demoTarget, demo.stopOn == nil {
            if snap.time >= target - 1e-9 || session.isFinished { freeze("time") }
            return
        }
        let afterOK = demo.holdAfter.map { snap.time >= $0 } ?? true
        if let tag = demo.stopOn {
            if afterOK && events.contains(where: { tag.matches($0) }) {
                freezeAt = now + DemoMode.stopDelay
                freezeTag = tag.rawValue
            }
        } else if let after = demo.holdAfter, snap.time >= after {
            freeze("after")
        }
    }

    private func freeze(_ tag: String) {
        demoFrozen = true
        freezeAt = nil
        setFeedbackPaused(true)
        AppTrace.note("freeze \(tag)")
        #if DEBUG
        AppTrace.demo("GLINT-T freeze \(tag)")
        #endif
    }

    /// `screen=results`: a real session played headless, recorded into the demo progress, then Results.
    private func runDemoResults(_ demo: DemoMode, mode: PlayMode) {
        playMode = mode
        let rolling = demo.seed ?? DemoMode.defaultSeed
        let s = DawnSession(mode: mode, seed: AppRules.seed(for: mode, rolling: rolling))
        session = s
        stage = .live
        if demo.outcome == .lost {
            // R3b: a lost fixture is built, not played (a pilot run may win): fixed numbers and a cause.
            showDemoLost(demo, mode: mode)
            return
        }
        let p = PilotSource(skill: demo.skill ?? 1.0, seed: demo.seed ?? DemoMode.defaultSeed)
        p.ignoring = demo.ignoreKind
        let pilot: PilotSource? = p
        let fixed = FixedBandSource(band: Tuning.bandMin, first: 0)
        let cap: Double
        switch mode {
        case let .level(n): cap = LevelBook.level(n).duration + 60
        case let .daily(day): cap = LevelBook.daily(day: day).duration + 60
        case .endless: cap = 300
        }
        let step = 1.0 / 120.0
        var clock: TimeInterval = 0
        var budget = Int(cap * 120)
        while !s.isFinished && budget > 0 {
            let input: MirrorInput
            if let pilot {
                input = pilot.mirror(at: clock)
            } else {
                input = fixed.mirror(at: clock)
            }
            let events = s.step(dt: step, input: input)
            pilot?.observe(s.snapshot)
            for e in events {
                if case let .sunrise(stars, _) = e { sunriseStars = stars }
            }
            clock += step
            budget -= 1
        }
        store.noteStarted(mode)
        publishHUD(s.snapshot, now: CACurrentMediaTime(), force: true)
        demoFrozen = true
        showResults()
    }

    /// `results=lost` (R3b): a deterministic lost result. `DemoPresets.lostStats(cause:)` (cause = `ignore=`, else murks)
    /// with real-looking numbers; the tip comes from the same `TipRules` a real loss uses.
    private func showDemoLost(_ demo: DemoMode, mode: PlayMode) {
        let stats = DemoPresets.lostStats(cause: demo.ignoreKind ?? .murk)
        let score = stats.score
        store.noteStarted(mode)
        let outcome = store.record(mode: mode, won: false, stars: 0, score: score, now: Date())
        var result = ResultSummary(mode: mode, title: AppRules.modeTitle(mode), won: false, stars: 0, score: score,
                                   flowersLeft: 0, pops: stats.pops, outcome: outcome)
        result.flowers = Array(repeating: false, count: Tuning.flowerCount)
        result.tip = mode.isLevel ? TipRules.tip(won: false, stats: stats) : nil
        summary = result
        demoFrozen = true
        setFeedbackPaused(true)
        AppTrace.note("result \(AppRules.modeName(mode)) won=0 (built)")
        #if DEBUG
        AppTrace.demo("GLINT-T result \(AppRules.modeName(mode)) won=0 stars=0 score=\(score) flowers=0 "
                      + "pops=\(stats.pops) tip=\(result.tip ?? "-")")
        #endif
        go(.results)
    }
}
