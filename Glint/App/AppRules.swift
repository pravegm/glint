import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Routes and stages

/// The screens. `play` and `results` show the level's own garden; every other screen has the live attract garden
/// behind it. Raw values are the `GLINT-T screen <name>` names (and the demo `screen=` keys).
enum AppRoute: String, Equatable, CaseIterable, Sendable {
    case home, levels, play, results, settings, about

    /// The scene draws the player's session (not the attract garden).
    var showsSession: Bool { self == .play || self == .results }
}

/// Where a level start is (GAME-DESIGN §7).
enum PlayStage: String, Equatable, Sendable {
    /// Play was asked for before the hinge has reported on a device that may be a Duo (a hinge seen before, the Duo
    /// CI launch, or the first seconds after launch): no prompt and no session for up to `AppRules.hingeWait` s. The
    /// first report decides (closed first, or straight on); silence means a phone (drag).
    case checking
    /// A Duo whose phone is open: "Close the phone to start". No session yet (none is created until shut is seen).
    case closeFirst
    /// A session exists (waiting for the first light, playing, or finished).
    case live
}

/// The one start line on the garden.
enum PromptLine: Equatable, Sendable {
    case closeToStart
    case openToLight
    /// Phones: "Drag <down|up|left|right> to let the light in" (the way the crease → flowers axis points).
    case drag(direction: String)

    var text: String {
        switch self {
        case .closeToStart: return "Close the phone to start"
        case .openToLight: return "Open the phone to let the light in"
        case let .drag(direction): return "Drag \(direction) to let the light in"
        }
    }

    var detail: String {
        switch self {
        case .closeToStart: return "The light grows as the phone opens."
        case .openToLight: return "The wider you open, the further it reaches."
        case .drag: return "Drag anywhere to aim the light."
        }
    }

    /// The `GLINT-T prompt <close|open|drag|none>` word.
    var logWord: String {
        switch self {
        case .closeToStart: return "close"
        case .openToLight: return "open"
        case .drag: return "drag"
        }
    }

    static func logWord(_ prompt: PromptLine?) -> String { prompt?.logWord ?? "none" }
}

/// What the Duo's outer (cover) display says.
enum CoverLine: Equatable, Sendable {
    case openToPlay
    case openToStart
    case paused(score: Int)
    /// R5: paused from the pause button: opening the phone shows the pause menu (it doesn't resume by itself).
    case pausedMenu(score: Int)

    var text: String {
        switch self {
        case .openToPlay: return "Open the phone to play"
        case .openToStart: return "Open the phone to start"
        case .paused: return "Paused · open the phone to carry on"
        case .pausedMenu: return "Paused · open the phone to see the pause menu"
        }
    }

    /// R5: the cover shows two lines (a short title, then what to do), never one long wrapped line.
    var title: String {
        switch self {
        case .paused, .pausedMenu: return "Paused"
        case .openToPlay, .openToStart: return text
        }
    }

    var detail: String? {
        switch self {
        case .paused: return "Open the phone to carry on"
        case .pausedMenu: return "Open the phone to see the pause menu"
        case .openToPlay, .openToStart: return nil
        }
    }

    var score: Int? {
        switch self {
        case let .paused(score), let .pausedMenu(score): return score
        case .openToPlay, .openToStart: return nil
        }
    }
}

// MARK: - Pause (GAME-DESIGN §8)

/// Why play is held. Any flag pauses (glooms freeze: the session gets dt = 0).
struct PauseFlags: Equatable, Sendable {
    /// The pause button (only Resume clears it).
    var menu = false
    /// The phone shut mid-level (θ ≤ 15° for 0.25 s); cleared when the hinge can resume (θ ≥ 25°).
    var shut = false
    /// The app is inactive or in the background.
    var inactive = false
    /// R5: the app is on the Duo's cover display (the phone is shut), whatever the hinge reports or doesn't.
    var cover = false

    var isPaused: Bool { menu || shut || inactive || cover }

    /// The `GLINT-T paused <reason>` word for the strongest reason.
    var reason: String {
        if shut { return "shut" }
        if cover { return "cover" }
        if menu { return "menu" }
        if inactive { return "inactive" }
        return "none"
    }
}

/// What the pause rules look at each frame.
struct PauseInput: Equatable, Sendable {
    var phase: SessionPhase
    /// The real hinge is aiming the light (not the drag fallback or a demo pilot).
    var hingeDriven: Bool
    var hingeShut: Bool
    var canResume: Bool
}

enum PauseRules {
    /// One frame of the shut / resume rules. Shut only pauses while playing (closing is part of the start flow), and
    /// only from a real hinge. Opening to θ ≥ 25° clears it; when nothing else holds play, a grace of
    /// `Tuning.resumeGrace` (glooms still frozen) follows. The grace counts down only while nothing pauses.
    static func step(_ flags: PauseFlags, grace: Double, input: PauseInput, dt: Double) -> (flags: PauseFlags, grace: Double) {
        var f = flags
        var g = grace
        var justResumed = false
        if input.hingeDriven {
            if input.phase == .playing && input.hingeShut && !f.shut {
                f.shut = true
            } else if f.shut && input.canResume && !input.hingeShut {
                f.shut = false
                justResumed = !f.isPaused
            }
        } else if f.shut {
            // The hinge no longer drives the light (never expected): never stay stuck on a shut pause.
            f.shut = false
            justResumed = !f.isPaused
        }
        if f.isPaused {
            g = 0
        } else if justResumed {
            g = Tuning.resumeGrace
        } else {
            let step = dt.isFinite ? max(dt, 0) : 0
            g = max(0, g - step)
        }
        return (f, g)
    }

    /// The app went inactive / to the background.
    static func deactivated(_ flags: PauseFlags) -> PauseFlags {
        var f = flags
        f.inactive = true
        return f
    }

    /// Back to active. After a trip to the background mid-level the pause menu waits for the player (unless the
    /// phone is shut: then opening it resumes, as always).
    static func activated(_ flags: PauseFlags, wentToBackground: Bool, phase: SessionPhase,
                          hingeShut: Bool) -> (flags: PauseFlags, grace: Double) {
        guard flags.inactive else { return (flags, 0) }
        var f = flags
        f.inactive = false
        if wentToBackground && phase == .playing && !hingeShut { f.menu = true }
        return (f, f.isPaused ? 0 : Tuning.resumeGrace)
    }

    /// The pause menu's Resume.
    static func resumedFromMenu(_ flags: PauseFlags) -> (flags: PauseFlags, grace: Double) {
        var f = flags
        f.menu = false
        return (f, f.isPaused ? 0 : Tuning.resumeGrace)
    }

    /// The session gets dt = 0.
    static func isFrozen(_ flags: PauseFlags, grace: Double) -> Bool {
        flags.isPaused || grace > 0
    }
}

// MARK: - Hints (GAME-DESIGN §7)

enum HintRules {
    static let all: [HintID] = [.lightTheShadows, .followTheBigOnes, .spareTheFireflies, .splitters, .hoppers]

    static func text(_ id: HintID) -> String {
        switch id {
        case .lightTheShadows: return "Light the shadows."
        case .followTheBigOnes: return "Follow the big ones."
        case .spareTheFireflies: return "Spare the fireflies. They replant flowers."
        case .splitters: return "Splitters burst in two. Catch the pieces."
        case .hoppers: return "Hoppers hop when the light touches them."
        }
    }

    /// How long a hint stays up at most (s). "Light the shadows." stays until the first pop (capped).
    static func lifetime(_ id: HintID) -> Double {
        switch id {
        case .lightTheShadows: return 12
        case .followTheBigOnes, .spareTheFireflies: return 4
        case .splitters, .hoppers: return 3.5
        }
    }

    /// The event that makes a hint unnecessary.
    static func isDone(_ id: HintID, by event: GameEvent) -> Bool {
        switch id {
        case .lightTheShadows:
            if case .popped = event { return true }
            return false
        case .followTheBigOnes:
            if case let .popped(_, kind, _, _, _, _) = event { return kind == .brute }
            return false
        case .spareTheFireflies:
            if case .fireflyDelivered = event { return true }
            return false
        case .splitters:
            if case .split = event { return true }
            return false
        case .hoppers:
            if case let .popped(_, kind, _, _, _, _) = event { return kind == .hopper }
            return false
        }
    }

    static func shouldShow(_ id: HintID, seen: [String]) -> Bool {
        !seen.contains(id.rawValue)
    }
}

// MARK: - App rules (pure; tested)

enum AppRules {
    /// A Duo's cover display: the window's long side under this (ROUND-1 App 2).
    static let coverLongSide: CGFloat = 760

    /// Where Back goes.
    static func back(from route: AppRoute) -> AppRoute {
        switch route {
        case .home, .levels, .settings, .play, .results: return .home
        case .about: return .settings
        }
    }

    /// The window looks like a Duo's inner display (short/long > 0.62 and short ≥ 600).
    static func looksLikeDuoInner(_ size: CGSize) -> Bool {
        let short = min(size.width, size.height)
        let long = max(size.width, size.height)
        guard long > 0, short.isFinite, long.isFinite else { return false }
        return short / long > 0.62 && short >= 600
    }

    /// The Duo split layout: a hinge was seen (persisted), the screen looks like the inner display, or demo `fold=1`.
    static func isDuo(window: CGSize, hingeSeen: Bool, demoFold: Bool, onMac: Bool = false) -> Bool {
        // R5: an iPhone app on a Mac ("Designed for iPhone") is always a phone, whatever its window's shape.
        if onMac { return false }
        return demoFold || hingeSeen || looksLikeDuoInner(window)
    }

    /// The cover display: only on a known Duo (a hinge seen), when the window's long side is under 760. A regular
    /// small iPhone (an SE is 667 long) never gets it: it has never reported a hinge.
    static func isCover(window: CGSize, hingeSeen: Bool) -> Bool {
        guard hingeSeen, window.width > 1, window.height > 1 else { return false }
        return max(window.width, window.height) < coverLongSide
    }

    /// The frame step the session may take: ≤ 1/30 s, never negative or NaN.
    static func clampDT(_ dt: Double) -> Double {
        guard dt.isFinite, dt > 0 else { return 0 }
        return min(dt, 1.0 / 30.0)
    }

    /// How long play waits for a first hinge report before treating the device as a phone.
    static let hingeWait: Double = 1.5
    /// Within this long of launch any device may still be a Duo whose hinge hasn't reported yet.
    static let launchWindow: Double = 2.0

    /// Wait for the hinge before starting (see `PlayStage.checking`).
    static func needsHingeCheck(hasHinge: Bool, pilotOrFixed: Bool, hingeSeen: Bool, duoLog: Bool,
                                sinceLaunch: Double, unavailable: Bool = false, duoShaped: Bool = false) -> Bool {
        guard !hasHinge, !pilotOrFixed else { return false }
        // R5 fix (Duo run 40896758284): a Duo-shaped inner display, a saved Duo flag or the Duo CI launch always
        // waits for the first hinge sample: an early "no hinge" callback (sent before the first report) must not
        // make a Duo choose drag.
        if duoShaped || hingeSeen || duoLog { return true }
        // R5 (QA P2-4): elsewhere, once the hinge API has said "no hinge" this launch, never wait for it again.
        if unavailable { return false }
        return sinceLaunch < launchWindow
    }

    /// R5 fix: the per-session source lock may UPGRADE drag → hinge when the first hinge sample arrives, as long as
    /// the session is still waiting for its first light and the player hasn't dragged. Hinge → drag, or drag after a
    /// drag, never switches.
    static func mayUpgradeToHinge(phase: SessionPhase, dragMoved: Bool) -> Bool {
        phase == .waiting && !dragMoved
    }

    /// Every level starts closed on a Duo: an open phone first shows "Close the phone to start".
    static func startsClosed(hingeDriven: Bool, isShut: Bool) -> Bool {
        hingeDriven && !isShut
    }

    /// The word for the way the light grows on screen (crease → flowers).
    static func dragDirection(_ layout: GardenLayout) -> String {
        let v = layout.dDirection
        if abs(v.dy) >= abs(v.dx) { return v.dy > 0 ? "down" : "up" }
        return v.dx > 0 ? "right" : "left"
    }

    /// The start line for this moment, or nil.
    static func prompt(stage: PlayStage, phase: SessionPhase?, hingeDriven: Bool, layout: GardenLayout) -> PromptLine? {
        if stage == .closeFirst { return .closeToStart }
        if stage == .checking { return nil }
        guard let phase, phase == .waiting else { return nil }
        return hingeDriven ? .openToLight : .drag(direction: dragDirection(layout))
    }

    static func coverLine(route: AppRoute, stage: PlayStage, phase: SessionPhase?, paused: Bool, score: Int,
                          menu: Bool = false) -> CoverLine {
        guard route == .play else { return .openToPlay }
        if stage == .closeFirst || stage == .checking { return .openToStart }
        guard let phase else { return .openToStart }
        switch phase {
        case .waiting: return .openToStart
        case .playing: return menu ? .pausedMenu(score: score) : .paused(score: score)
        case .won, .lost: return .openToPlay
        }
    }

    /// R5 (player QA #4): "Already open? Show the game" only when nothing says the phone is shut (the hinge reads
    /// open, or has been silent for 3 s) AND the window is inner-display sized: never on a shut phone, and never the
    /// full game on the small outer display.
    static func coverEscapeAllowed(hingeAngle: Double?, sampleAge: Double?, window: CGSize) -> Bool {
        let innerSized = max(window.width, window.height) >= coverLongSide
        guard innerSized else { return false }
        if let a = hingeAngle, a.isFinite, a < Tuning.resumeAngle, let age = sampleAge, age <= 3 { return false }
        return true
    }

    /// R5 (QA P1-2): the screen stays awake only while a level is really being played (not paused, not waiting).
    static func keepAwake(route: AppRoute, stage: PlayStage, phase: SessionPhase?, paused: Bool) -> Bool {
        route == .play && stage == .live && phase == .playing && !paused
    }

    /// R5 (QA P1-4): a world's last level won while the next world is still shut: what it needs.
    static func worldGateNote(level n: Int, data: ProgressData) -> String? {
        let w = LevelBook.world(of: n)
        guard w < LevelBook.worldCount, n == LevelBook.levels(inWorld: w).upperBound,
              !ProgressRules.isWorldOpen(w + 1, data) else { return nil }
        let missing = ProgressRules.starsMissing(toOpen: w + 1, data)
        return "\(missing) more ★ in \(LevelBook.worldName(w)) opens \(LevelBook.worldName(w + 1))"
    }

    /// R5 (QA P1-5): the date chip shows the player's own (local) date of the run's start.
    static func localDateChip(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let wd = calendar.component(.weekday, from: date)
        let dd = calendar.component(.day, from: date)
        let mm = calendar.component(.month, from: date)
        guard wd >= 1, wd <= 7, mm >= 1, mm <= 12 else { return "Today" }
        return "\(weekdays[wd - 1]) \(dd) \(months[mm - 1])"
    }

    static func modeTitle(_ mode: PlayMode) -> String {
        switch mode {
        case let .level(n): return "Level \(n) · \(LevelBook.level(n).title)"
        case .endless: return "Long Night"
        case .daily: return "Today's Dawn"
        }
    }

    /// For logs: `level-3`, `endless`, `daily-301`.
    static func modeName(_ mode: PlayMode) -> String {
        switch mode {
        case let .level(n): return "level-\(n)"
        case .endless: return "endless"
        case let .daily(day): return "daily-\(day)"
        }
    }

    static func phaseName(_ phase: SessionPhase?) -> String {
        phase?.rawValue ?? "none"
    }

    /// The session seed: levels and the day are fixed (retry = the same sunrise); endless rolls.
    static func seed(for mode: PlayMode, rolling: UInt64) -> UInt64 {
        switch mode {
        case let .level(n): return UInt64(max(n, 1))
        case .endless: return rolling == 0 ? 1 : rolling
        case let .daily(day): return DailySeed.seed(day: day)
        }
    }

    /// The centre of a HUD item of `item` size in one of the MIRROR half's far corners (R2 decision: the edge away from
    /// the crease; u < 0.5: the u = 0 corner, else the u = 1 corner), `margin` in from both edges and inside the safe
    /// area. Nothing here can cover a flower: the flowers live on the garden half.
    static func hudCenter(u: Double, item: CGSize, layout: GardenLayout, insets: EdgeInsets, margin: CGFloat) -> CGPoint {
        let size = layout.size
        let dVec = layout.dDirection
        let axis: CGFloat = layout.foldVertical ? size.width : size.height
        let mirrorDepth = max(axis - layout.gardenDepth, 0)
        let creaseEnd = layout.point(u: u < 0.5 ? 0 : 1, d: 0)
        // The mirror's far edge: from the crease, away from the garden by the mirror's depth.
        let corner = CGPoint(x: creaseEnd.x - dVec.dx * mirrorDepth, y: creaseEnd.y - dVec.dy * mirrorDepth)
        let uVec = layout.foldVertical ? CGVector(dx: 0, dy: 1) : CGVector(dx: 1, dy: 0)
        let uSign: CGFloat = u < 0.5 ? 1 : -1
        let halfAlongD: CGFloat = layout.foldVertical ? item.width / 2 : item.height / 2
        let halfAlongU: CGFloat = layout.foldVertical ? item.height / 2 : item.width / 2
        let inD = halfAlongD + margin
        let inU = halfAlongU + margin
        var x = corner.x + dVec.dx * inD + uVec.dx * uSign * inU
        var y = corner.y + dVec.dy * inD + uVec.dy * uSign * inU
        let minX = insets.leading + item.width / 2 + 4
        let maxX = size.width - insets.trailing - item.width / 2 - 4
        let minY = insets.top + item.height / 2 + 4
        let maxY = size.height - insets.bottom - item.height / 2 - 4
        if maxX > minX { x = min(max(x, minX), maxX) }
        if maxY > minY { y = min(max(y, minY), maxY) }
        return CGPoint(x: x, y: y)
    }

    // MARK: Duo: nothing tappable near the crease (R2 addendum)

    /// No control within this distance of the crease on a Duo layout (the founder's rule is 28; the regions keep 32).
    static let creaseNoTouch: CGFloat = 28
    static let creaseClearance: CGFloat = 32

    /// The crease line's band, ± `half` (SwiftUI coordinates).
    static func creaseBand(layout: GardenLayout, half: CGFloat = creaseNoTouch) -> CGRect {
        let g = layout.gardenRect
        let size = layout.size
        if layout.foldVertical {
            let x = layout.gardenAfter ? g.minX : g.maxX
            return CGRect(x: x - half, y: 0, width: half * 2, height: size.height)
        }
        let y = layout.gardenAfter ? g.minY : g.maxY
        return CGRect(x: 0, y: y - half, width: size.width, height: half * 2)
    }

    /// Where a menu may put things. Phones: one region (the safe area). A Duo split layout: the mirror half
    /// (`secondary`: titles and art) and the garden half (`primary`: the controls), each inside the safe area and
    /// `creaseClearance` clear of the crease, so no control can sit across the fold.
    struct MenuRegions: Equatable {
        var primary: CGRect
        var secondary: CGRect?
    }

    static func menuRegions(layout: GardenLayout, insets: EdgeInsets, isDuo: Bool) -> MenuRegions {
        let size = layout.size
        let safe = CGRect(x: insets.leading, y: insets.top,
                          width: max(size.width - insets.leading - insets.trailing, 1),
                          height: max(size.height - insets.top - insets.bottom, 1))
        guard isDuo else { return MenuRegions(primary: safe, secondary: nil) }
        let band = creaseBand(layout: layout, half: creaseClearance)
        let garden = clear(layout.gardenRect.intersection(safe), of: band, layout: layout)
        var mirror = clear(layout.mirrorRect.intersection(safe), of: band, layout: layout)
        // R5 (player QA #7, #28): keep titles and cards inside the mirror's brass frame (frame + 12 pt).
        let inset = mirrorFrameThickness(layout: layout) + 12
        if mirror.width > inset * 4 && mirror.height > inset * 4 {
            mirror = mirror.insetBy(dx: inset, dy: inset)
        }
        return MenuRegions(primary: garden, secondary: mirror)
    }

    /// `r` with the part inside `band` cut off (along the fold-normal axis).
    private static func clear(_ r: CGRect, of band: CGRect, layout: GardenLayout) -> CGRect {
        guard !r.isNull, r.intersects(band) else { return r.isNull ? .zero : r }
        if layout.foldVertical {
            if r.midX >= band.midX {
                let minX = max(r.minX, band.maxX)
                return CGRect(x: minX, y: r.minY, width: max(r.maxX - minX, 1), height: r.height)
            }
            let maxX = min(r.maxX, band.minX)
            return CGRect(x: r.minX, y: r.minY, width: max(maxX - r.minX, 1), height: r.height)
        }
        if r.midY >= band.midY {
            let minY = max(r.minY, band.maxY)
            return CGRect(x: r.minX, y: minY, width: r.width, height: max(r.maxY - minY, 1))
        }
        let maxY = min(r.maxY, band.minY)
        return CGRect(x: r.minX, y: r.minY, width: r.width, height: max(maxY - r.minY, 1))
    }

    /// Where a hint line sits (R2 addendum: on the garden, at 40 % of its depth, never on the sun).
    static let hintD = 0.4

    static func hintCenter(layout: GardenLayout) -> CGPoint {
        layout.point(u: 0.5, d: overlaySpan(layout: layout).center)
    }

    /// R4 (item 9): the flowers' nearest edge to the crease, in floor d, from the Scene's own rects
    /// (`GardenScene.hudSafeRects`), so the overlays follow wherever the Scene puts the flowers (the book-pose thumb
    /// inset included). 1 when there are none.
    static func flowersInnerD(layout: GardenLayout) -> Double {
        var inner = 1.0
        for r in GardenScene.hudSafeRects(layout: layout) {
            let corners = [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                           CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)]
            for c in corners { inner = min(inner, layout.floorPoint(at: c).d) }
        }
        return min(max(inner, 0.3), 1)
    }

    /// The garden strip the prompt card and hints may use along d: from 0.04 to 0.04 short of the flowers, and its
    /// middle.
    static func overlaySpan(layout: GardenLayout) -> (center: Double, length: CGFloat) {
        let end = flowersInnerD(layout: layout) - 0.04
        let start = 0.04
        let length = CGFloat(max(end - start, 0.2)) * layout.gardenDepth
        return ((start + end) / 2, length)
    }

    /// The thing a hint is about: the oldest gloom of its kind (or firefly), as a floor point; nil if gone.
    static func hintSubject(_ id: HintID, snapshot: DawnSnapshot) -> (u: Double, d: Double)? {
        switch id {
        case .spareTheFireflies:
            guard let f = snapshot.fireflies.first else { return nil }
            return (f.u, f.d)
        case .lightTheShadows:
            guard let g = snapshot.glooms.first(where: { !$0.submerged }) else { return nil }
            return (g.u, g.d)
        case .followTheBigOnes, .splitters, .hoppers:
            let kind: GloomKind = id == .followTheBigOnes ? .brute : (id == .splitters ? .splitter : .hopper)
            guard let g = snapshot.glooms.first(where: { $0.kind == kind && !$0.submerged }) else { return nil }
            return (g.u, g.d)
        }
    }

    /// The phone lever on the mirror (R2 addendum): only in play, only for the drag fallback, never on a Duo layout.
    static func showsLever(route: AppRoute, hasHinge: Bool, isDuo: Bool) -> Bool {
        route == .play && !hasHinge && !isDuo
    }

    /// R5 (QA P2-3): the lever shows whenever drag drives the light in play (a Duo whose hinge never reports too),
    /// and never for the hinge or a demo pilot.
    static func showsLever(route: AppRoute, dragDriven: Bool) -> Bool {
        route == .play && dragDriven
    }

    /// Home's Today's Dawn card status (R2 addendum: "come back tomorrow").
    static func dailyCardStatus(open: Bool, playedToday: Bool, todayBest: Int, streak: Int) -> String {
        guard open else { return "Win level \(ProgressRules.dailyLevel)" }
        if playedToday {
            return streak >= 2 ? "✓ Day \(streak) streak" : "✓ Today \(grouped(todayBest))"
        }
        return streak >= 1 ? "Day \(streak) streak" : "New today"
    }

    /// The cover display's second line in the menus: nil when Today's Dawn isn't open yet.
    static func dailyCoverLine(open: Bool, playedToday: Bool, todayBest: Int, streak: Int) -> String? {
        guard open else { return nil }
        if playedToday { return "Today: \(grouped(todayBest)) · streak \(max(streak, 1))" }
        return "Today's Dawn is up"
    }

    /// The angle (radians, SwiftUI's y-down convention) from `from` to `to`; 0 = pointing right.
    static func angle(from: CGPoint, to: CGPoint) -> Double {
        Double(atan2(to.y - from.y, to.x - from.x))
    }

    /// The rect of an item of `size` centred on `center` (SwiftUI coordinates).
    static func rect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// Where the start prompt card sits: on the garden, towards the crease, clear of the flowers.
    static let promptD = 0.4

    static func promptCenter(layout: GardenLayout) -> CGPoint {
        layout.point(u: 0.5, d: overlaySpan(layout: layout).center)
    }

    /// The largest the start prompt card may be: along d it stays inside 0.04…0.76 of the garden (the flowers sit at
    /// the far edge), along u it keeps 16 pt from each side (at most 460 pt).
    static func promptMaxSize(layout: GardenLayout) -> CGSize {
        // R4: the strip short of the flowers (wherever the Scene puts them), not a fixed 0.72.
        let alongD: CGFloat = overlaySpan(layout: layout).length
        let alongU: CGFloat = min(max(layout.gardenSpan - 32, 120), 460)
        let w: CGFloat = layout.foldVertical ? alongD : alongU
        let h: CGFloat = layout.foldVertical ? alongU : alongD
        return CGSize(width: max(w, 120), height: max(h, 80))
    }

    /// Reduce motion (R2): the player's explicit choice in Settings, else the iOS setting.
    static func reduceMotion(choice: Bool?, system: Bool) -> Bool {
        choice ?? system
    }

    /// The level map's world tab status line: "★ 24/30" when open, "★ 20" (the stars needed) when locked.
    static func worldTabStatus(open: Bool, stars: Int, max: Int, gate: Int) -> String {
        open ? "★ \(stars)/\(max)" : "Needs ★ \(gate)"
    }

    /// 12,340 style grouping (locale independent, for HUD numbers).
    static func grouped(_ value: Int) -> String {
        let negative = value < 0
        var digits = String(abs(value))
        var out = ""
        while digits.count > 3 {
            let tail = String(digits.suffix(3))
            out = "," + tail + out
            digits = String(digits.dropLast(3))
        }
        return (negative ? "-" : "") + digits + out
    }
}

// MARK: - The level map (pure; tested)

/// Ten sun medallions on a winding path: rows that snake left → right, then right → left (5 per row on a wide map,
/// 3 per row on a tall one), with a gentle wobble.
enum LevelMapGeometry {
    static func columns(for size: CGSize) -> Int {
        size.width > size.height * 1.15 ? 5 : 3
    }

    static func points(count: Int, in size: CGSize) -> [CGPoint] {
        guard count > 0, size.width > 0, size.height > 0 else { return [] }
        let cols = min(columns(for: size), count)
        let rows = (count + cols - 1) / cols
        let cellW = size.width / CGFloat(cols)
        let cellH = size.height / CGFloat(max(rows, 1))
        var out: [CGPoint] = []
        for i in 0..<count {
            let row = i / cols
            let inRow = i % cols
            let col = row % 2 == 0 ? inRow : cols - 1 - inRow
            let wobble = CGFloat(sin(Double(i) * 1.7)) * cellH * 0.08
            let x = cellW * (CGFloat(col) + 0.5)
            let y = cellH * (CGFloat(row) + 0.42) + wobble
            out.append(CGPoint(x: x, y: y))
        }
        return out
    }

    static func nodeSize(count: Int, in size: CGSize) -> CGFloat {
        guard count > 0 else { return 60 }
        let cols = min(columns(for: size), count)
        let rows = (count + cols - 1) / cols
        let cellW = size.width / CGFloat(cols)
        let cellH = size.height / CGFloat(max(rows, 1))
        // R3: room under each medallion for its stars, name and 3rd-star target.
        return min(max(min(cellW * 0.56, cellH * 0.44), 36), 84)
    }
}

// MARK: - Lost-level tips (R2 addendum; pure, tested)

/// One tip for a lost level, from what ate the flowers (`DawnStats`).
enum TipRules {
    static let cloud = "Wait for the cloud to pass, then light them."
    static let brute = "Follow the big ones as they walk."
    static let wisp = "Sweep the flocks fast: one quick pass pops them all."
    static let hopper = "Catch hoppers after they land."
    static let splitter = "Splitters burst in two: catch the pieces as they fly."
    static let murk = "Meet the shadows in the open garden: the light can't reach the crease."
    static let fireflies = "Sweep past fireflies quickly: they bring flowers back."

    static func text(for kind: GloomKind) -> String {
        switch kind {
        case .brute: return brute
        case .wisp: return wisp
        case .hopper: return hopper
        case .splitter: return splitter
        case .murk: return murk
        }
    }

    /// Clouds first when they cost at least half the flowers; then the kind that ate the most; then fireflies.
    static func tip(won: Bool, stats: DawnStats) -> String? {
        guard !won else { return nil }
        if stats.eatenAfterCloud > 0 && stats.eatenAfterCloud * 2 >= max(stats.flowersEaten, 1) { return cloud }
        if let kind = stats.worstKind { return text(for: kind) }
        if stats.firefliesScorched >= 2 { return fireflies }
        return nil
    }
}

// MARK: - Round 3 (design/ROUND-3.md "App", REVIEW-2 fixes 5–16; pure, tested)

extension AppRules {
    /// The mirror's brass frame thickness as the Scene draws it (`GardenMirror.apply(rect:)`: 4.5 % of the mirror's
    /// short side, 9…22 pt).
    static func mirrorFrameThickness(layout: GardenLayout) -> CGFloat {
        let m = layout.mirrorRect
        return min(max(min(m.width, m.height) * 0.045, 9), 22)
    }

    /// REVIEW-2 fix 5: HUD plates sit at least 12 pt inside the brass frame.
    static func hudMargin(layout: GardenLayout) -> CGFloat {
        mirrorFrameThickness(layout: layout) + 12
    }

    /// REVIEW-2 fix 12: Swap halves exists only in book pose on a Duo (a landscape canvas, fold running top to
    /// bottom). In laptop pose it would lay the mirror on the table.
    static func swapAllowed(isDuo: Bool, size: CGSize) -> Bool {
        isDuo && size.width > size.height
    }

    /// Today's Dawn's date chip ("Thu 29 Oct") for a day number (days since 1 Jan 2026, UTC). Locale-independent
    /// English (the game's copy is English).
    static func dateChip(day: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        var start = DateComponents()
        start.year = 2026
        start.month = 1
        start.day = 1
        guard let first = calendar.date(from: start),
              let date = calendar.date(byAdding: .day, value: day, to: first) else { return "Today" }
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let wd = calendar.component(.weekday, from: date)       // 1 = Sunday
        let dd = calendar.component(.day, from: date)
        let mm = calendar.component(.month, from: date)
        guard wd >= 1, wd <= 7, mm >= 1, mm <= 12 else { return "Today" }
        return "\(weekdays[wd - 1]) \(dd) \(months[mm - 1])"
    }

    /// The day of a Today's Dawn mode (nil otherwise).
    static func dailyDay(_ mode: PlayMode) -> Int? {
        if case let .daily(day) = mode { return day }
        return nil
    }

    /// The score pill's second line: "Chain 7", "Wave 3", or both ("Chain 7 · Wave 3"); nil for neither.
    /// R5 (player QA #8): the multiplier ("×2.5", capped at ×4), never the raw chain count.
    static func multiplierText(_ multiplier: Double) -> String? {
        guard multiplier.isFinite, multiplier > 1.001 else { return nil }
        var t = String(format: "%.2f", min(multiplier, Tuning.maxMultiplier))
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return "×" + t
    }

    static func scoreSubline(multiplier: Double, wave: Int) -> String? {
        let m = multiplierText(multiplier)
        let waveText: String? = wave > 0 ? "Wave \(wave)" : nil
        switch (m, waveText) {
        case let (c?, w?): return c + " · " + w
        case let (c?, nil): return c
        case let (nil, w?): return w
        case (nil, nil): return nil
        }
    }

    static func scoreSubline(chain: Int, wave: Int) -> String? {
        let chainText: String? = chain >= 2 ? "Chain \(chain)" : nil
        let waveText: String? = wave > 0 ? "Wave \(wave)" : nil
        switch (chainText, waveText) {
        case let (c?, w?): return c + " · " + w
        case let (c?, nil): return c
        case let (nil, w?): return w
        case (nil, nil): return nil
        }
    }

    /// The centre of an item at the mirror's far edge, centred along u (the date chip), `margin` in.
    static func farEdgeCenter(item: CGSize, layout: GardenLayout, insets: EdgeInsets, margin: CGFloat) -> CGPoint {
        let corner = hudCenter(u: 0, item: item, layout: layout, insets: insets, margin: margin)
        let mirror = layout.mirrorRect
        if layout.foldVertical { return CGPoint(x: corner.x, y: mirror.midY) }
        return CGPoint(x: mirror.midX, y: corner.y)
    }

    /// The 3rd-star line ("★★★ 1,400") for a score target; nil without one.
    static func starTargetLine(_ starScore: Int?) -> String? {
        guard let s = starScore, s > 0 else { return nil }
        return "★★★ \(grouped(s))"
    }
}

/// REVIEW-2 fix 7: a hint waits for its subject. A raised hint is held (up to `waitLimit` s) until its subject is on
/// the field, then shows for its lifetime (or until done).
enum HintQueue {
    static let waitLimit: Double = 25

    enum Decision: Equatable { case wait, show, drop }

    /// What to do with a hint raised at `raisedAt`, now, given whether its subject is visible.
    static func decide(subjectVisible: Bool, raisedAt: Double, now: Double) -> Decision {
        if subjectVisible { return .show }
        return now - raisedAt > waitLimit ? .drop : .wait
    }
}

/// REVIEW-2 fix 12: the filtered hinge's jitter, for the About trace (`jitterDeg p95`). Fed the filtered angle each
/// play frame while the hinge drives the light; measures |angle − its 0.5 s running mean| while the phone is nearly
/// still. Pure value type; tested.
struct JitterMeter: Equatable {
    static let capacity = 900
    private(set) var samples: [Double] = []
    private var mean: Double?

    mutating func add(angle: Double, dt: Double) {
        guard angle.isFinite, dt.isFinite, dt > 0 else { return }
        guard let m = mean else {
            mean = angle
            return
        }
        let k = min(dt / 0.5, 1)
        let next = m + (angle - m) * k
        mean = next
        let dev = abs(angle - next)
        // Only while nearly still (a real move is not jitter).
        guard dev < 4 else { return }
        samples.append(dev)
        if samples.count > JitterMeter.capacity { samples.removeFirst(samples.count - JitterMeter.capacity) }
    }

    /// The 95th percentile (degrees), nil with fewer than 30 samples.
    var p95: Double? {
        guard samples.count >= 30 else { return nil }
        let sorted = samples.sorted()
        let i = min(Int((Double(sorted.count - 1) * 0.95).rounded()), sorted.count - 1)
        return sorted[i]
    }
}

// MARK: - Round 3b (founder: Results buttons always visible, compact achievements; pure, tested)

extension AppRules {
    /// Earned achievements on the Results card: at most this many medallions, then "+n".
    static let achievementRowMax = 4

    static func achievementRow(count: Int) -> (badges: Int, more: Int) {
        let n = max(count, 0)
        if n <= achievementRowMax { return (n, 0) }
        return (achievementRowMax - 1, n - (achievementRowMax - 1))
    }

    /// The Results buttons' block: the primary (64), a secondary (58) and the Levels / Home row (52), 12 pt apart,
    /// plus the region's 10 pt padding top and bottom.
    static func resultsButtonsHeight(compact: Bool, hasGate: Bool = false) -> CGFloat {
        let primary = max(GlintTheme.buttonHeight, GlintTheme.minTap)
        // R5: with the world-gate note: the note (two lines), Levels, Retry and Home.
        if hasGate { return 48 + 12 + primary + 12 + 52 + 12 + 52 + 20 }
        return primary + 12 + 58 + 12 + 52 + 20
    }

    /// Where the Results card and its buttons go. Phones: the buttons pinned to the bottom of the safe area, the card
    /// scrolling above them. A Duo: the card on the mirror half, the buttons on the garden half (clear of the crease).
    /// The buttons' rect is never shorter than their block, so none can be pushed off the screen.
    static func resultsPlacement(layout: GardenLayout, insets: EdgeInsets, isDuo: Bool,
                                 buttonsHeight: CGFloat) -> (card: CGRect, buttons: CGRect) {
        let regions = menuRegions(layout: layout, insets: insets, isDuo: isDuo)
        if let secondary = regions.secondary, regions.primary.height >= buttonsHeight {
            return (secondary, regions.primary)
        }
        let safe = regions.primary
        let h = min(buttonsHeight, safe.height)
        let buttons = CGRect(x: safe.minX, y: safe.maxY - h, width: safe.width, height: h)
        let card = CGRect(x: safe.minX, y: safe.minY, width: safe.width, height: max(safe.height - h, 1))
        return (card, buttons)
    }
}

// MARK: - Round 5 (QA-R5; pure, tested)

extension AppRules {
    /// R5 (player QA #6): the date chip by the real plate rects: between the score and pause plates on the same row
    /// when there's room, else one row in from them (never overlapping either).
    static func dateChipCenter(chip: CGSize, score: CGRect, pause: CGRect, layout: GardenLayout) -> CGPoint {
        let mirror = layout.mirrorRect
        if layout.foldVertical {
            // Book pose: the plates sit along the far edge, one at each end; the chip goes between them.
            let gapTop = min(score.maxY, pause.maxY)
            let gapBottom = max(score.minY, pause.minY)
            if gapBottom - gapTop >= chip.height + 16 {
                return CGPoint(x: score.midX, y: (gapTop + gapBottom) / 2)
            }
            let x = layout.gardenAfter ? max(score.maxX, pause.maxX) + 8 + chip.width / 2
                                       : min(score.minX, pause.minX) - 8 - chip.width / 2
            return CGPoint(x: x, y: mirror.midY)
        }
        let left = min(score.maxX, pause.maxX)
        let right = max(score.minX, pause.minX)
        if right - left >= chip.width + 16 {
            return CGPoint(x: (left + right) / 2, y: score.midY)
        }
        let y = layout.gardenAfter ? max(score.maxY, pause.maxY) + 8 + chip.height / 2
                                   : min(score.minY, pause.minY) - 8 - chip.height / 2
        return CGPoint(x: mirror.midX, y: y)
    }
}

extension AppRules {
    /// R5: VoiceOver's value for the "Light": how far out it reaches (0 % = in the crease, 100 % = at the flowers).
    static func lightValue(_ band: Double) -> String {
        guard band.isFinite, band > 0 else { return "In the crease" }
        return "\(Int((min(band, 1) * 100).rounded())) % of the way to the flowers"
    }
}
