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

    var text: String {
        switch self {
        case .openToPlay: return "Open the phone to play"
        case .openToStart: return "Open the phone"
        case .paused: return "Paused · open the phone to carry on"
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

    var isPaused: Bool { menu || shut || inactive }

    /// The `GLINT-T paused <reason>` word for the strongest reason.
    var reason: String {
        if shut { return "shut" }
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
        case .spareTheFireflies: return "Spare the fireflies."
        case .splitters: return "Splitters burst in two. Catch the pieces."
        case .hoppers: return "Hoppers jump when the light touches them."
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
    static func isDuo(window: CGSize, hingeSeen: Bool, demoFold: Bool) -> Bool {
        demoFold || hingeSeen || looksLikeDuoInner(window)
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
                                sinceLaunch: Double) -> Bool {
        guard !hasHinge, !pilotOrFixed else { return false }
        return hingeSeen || duoLog || sinceLaunch < launchWindow
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

    static func coverLine(route: AppRoute, stage: PlayStage, phase: SessionPhase?, paused: Bool, score: Int) -> CoverLine {
        guard route == .play else { return .openToPlay }
        if stage == .closeFirst || stage == .checking { return .openToStart }
        guard let phase else { return .openToStart }
        switch phase {
        case .waiting: return .openToStart
        case .playing: return .paused(score: score)
        case .won, .lost: return paused ? .paused(score: score) : .openToPlay
        }
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

    /// The centre of a HUD item of `item` size in the garden's flower-edge corner on the `u` side (u < 0.5: the
    /// u = 0 corner), `margin` in from both edges and inside the safe area.
    static func hudCenter(u: Double, item: CGSize, layout: GardenLayout, insets: EdgeInsets, margin: CGFloat) -> CGPoint {
        let size = layout.size
        let corner = layout.point(u: u < 0.5 ? 0 : 1, d: 1)
        let dVec = layout.dDirection
        let uVec = layout.foldVertical ? CGVector(dx: 0, dy: 1) : CGVector(dx: 1, dy: 0)
        let uSign: CGFloat = u < 0.5 ? 1 : -1
        let halfAlongD: CGFloat = layout.foldVertical ? item.width / 2 : item.height / 2
        let halfAlongU: CGFloat = layout.foldVertical ? item.height / 2 : item.width / 2
        let inD = halfAlongD + margin
        let inU = halfAlongU + margin
        var x = corner.x - dVec.dx * inD + uVec.dx * uSign * inU
        var y = corner.y - dVec.dy * inD + uVec.dy * uSign * inU
        let minX = insets.leading + item.width / 2 + 4
        let maxX = size.width - insets.trailing - item.width / 2 - 4
        let minY = insets.top + item.height / 2 + 4
        let maxY = size.height - insets.bottom - item.height / 2 - 4
        if maxX > minX { x = min(max(x, minX), maxX) }
        if maxY > minY { y = min(max(y, minY), maxY) }
        return CGPoint(x: x, y: y)
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
        return min(max(min(cellW * 0.62, cellH * 0.6), 40), 96)
    }
}
