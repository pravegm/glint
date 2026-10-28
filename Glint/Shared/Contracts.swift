import CoreGraphics
import Foundation

// MARK: - Contracts between the modules (owned by the founder; change only in a founder round)
//
// Core     (Glint/Core)      pure Swift game rules: Foundation + CoreGraphics only. Deterministic. Unit-tested.
// Input    (Glint/Input)     hinge / drag → MirrorInput (where the band of light is).
// Scene    (Glint/Scene)     SpriteKit rendering of a DawnSnapshot + cosmetic FX from GameEvents; forwards drags.
// Feedback (Glint/Feedback)  live audio synth + Core Haptics from GameEvents + Telemetry.
// App/UI   (Glint/App, Glint/UI, Glint/Persistence) SwiftUI shell, the frame-loop glue, menus, saves, Game Center.
//
// FLOOR SPACE (Core): the garden half. `u` 0…1 across the garden, `d` 0…1 from the crease (d = 0, where shadows come
// from) to the flower edge (d = 1). The band of light is a full-width stripe centred on `d = band`.
// SCREEN: `GardenLayout` (below) maps floor space onto the canvas for the current orientation. Scene and UI both use it,
// so the HUD and the art always agree.

// MARK: - Kinds

/// A shadow kind (GAME-DESIGN §4). Raw values are stable (saves, Game Center ids, demo scenarios).
public enum GloomKind: String, CaseIterable, Codable, Sendable {
    case murk, wisp, brute, splitter, hopper
}

/// What a session is playing.
public enum PlayMode: Hashable, Codable, Sendable {
    /// Levels 1…30 (`LevelBook.count`).
    case level(Int)
    /// Long Night: escalates forever.
    case endless
    /// Today's Dawn: `day` = days since 1 Jan 2026 (UTC), the seed.
    case daily(day: Int)

    public var isLevel: Bool { if case .level = self { return true } else { return false } }
}

/// Where a session is.
public enum SessionPhase: String, Codable, Sendable {
    /// Waiting for the first light: no time passes and nothing spawns until the band first reaches d ≥ 0
    /// (or the drag fallback first moves). Lets the "Close / Open the phone" lines run without a clock.
    case waiting
    case playing
    /// Sunrise: the level is won (glooms evaporate). Final.
    case won
    /// Every flower eaten. Final.
    case lost
}

/// The one-line hints the App may show (GAME-DESIGN §7). Core raises `.hint` events once per session when the
/// situation first arises; the App decides whether the player still needs them.
public enum HintID: String, Codable, Sendable {
    case lightTheShadows      // first gloom emerged (level 1 only)
    case followTheBigOnes     // first brute emerged
    case spareTheFireflies    // first firefly emerged
    case splitters            // first splitter
    case hoppers              // first hopper
}

// MARK: - Input

/// The light, as the input side sees it at one frame. Produced by a `MirrorSource`.
public struct MirrorInput: Equatable, Sendable {
    /// Band centre in floor `d` units. < 0: the band is still hidden in the crease (θ < 85°); clamped ≤ 1.
    public var band: Double
    /// 0…1: how bright the light pooled in the crease is (θ 15°…85°; 1 once the band is out). Cosmetic.
    public var creaseGlow: Double
    /// The phone is shut (θ ≤ 15°). Always false for the drag fallback.
    public var isShut: Bool
    /// The band's speed, d units per second (signed: + = moving towards the flowers). Feedback only.
    public var bandSpeed: Double

    public init(band: Double = -0.2, creaseGlow: Double = 0, isShut: Bool = false, bandSpeed: Double = 0) {
        self.band = band; self.creaseGlow = creaseGlow; self.isShut = isShut; self.bandSpeed = bandSpeed
    }
}

/// Anything that can aim the light. `HingeMirrorSource` (Duo), `DragMirrorSource` (other iPhones), `Pilot` (demo/CI).
@MainActor
public protocol MirrorSource: AnyObject {
    /// The light at `time` (`CACurrentMediaTime()` clock). Called once per frame.
    func mirror(at time: TimeInterval) -> MirrorInput
}

// MARK: - Snapshot (Core → Scene/UI/Feedback)

public struct GloomState: Equatable, Sendable {
    /// Unique within a session, never reused.
    public var id: Int
    public var kind: GloomKind
    public var u: Double
    public var d: Double
    /// Radius in floor `d` units (the scene scales by the garden's d length).
    public var radius: Double
    public var hp: Double
    public var maxHP: Double
    /// Light intensity on it this frame, 0…1.
    public var lit: Double
    /// Seconds since it emerged.
    public var age: Double
    /// Hopper: 0…1 crouch before a hop (0 for other kinds). Splitter wisps: 1 while flung.
    public var tension: Double

    public init(id: Int, kind: GloomKind, u: Double, d: Double, radius: Double, hp: Double, maxHP: Double,
                lit: Double = 0, age: Double = 0, tension: Double = 0) {
        self.id = id; self.kind = kind; self.u = u; self.d = d; self.radius = radius; self.hp = hp; self.maxHP = maxHP
        self.lit = lit; self.age = age; self.tension = tension
    }
}

public struct FireflyState: Equatable, Sendable {
    public var id: Int
    public var u: Double
    public var d: Double
    /// 0…1 towards fizzling.
    public var scorch: Double
    public var lit: Double
    public var age: Double

    public init(id: Int, u: Double, d: Double, scorch: Double = 0, lit: Double = 0, age: Double = 0) {
        self.id = id; self.u = u; self.d = d; self.scorch = scorch; self.lit = lit; self.age = age
    }
}

/// Per-frame numbers for Feedback and the HUD.
public struct Telemetry: Equatable, Sendable {
    /// Total HP burned per second this frame, over every lit gloom (0 = nothing burning).
    public var burnRate: Double = 0
    /// Glooms with lit > 0.
    public var litCount: Int = 0
    /// The highest scorch of any firefly in light (0 = none in light).
    public var fireflyDanger: Double = 0
    /// The largest gloom `d` (how close the nearest threat is to the flowers), 0 if none.
    public var danger: Double = 0
    /// The band speed passed in (d/s).
    public var bandSpeed: Double = 0

    public init() {}
}

public struct DawnSnapshot: Equatable, Sendable {
    public var mode: PlayMode
    public var phase: SessionPhase
    public var glooms: [GloomState]
    public var fireflies: [FireflyState]
    /// One per lane (`Tuning.flowerCount`, left → right in `u`): true = still standing.
    public var flowers: [Bool]
    /// The band centre (d) and the crease glow used this frame (copied from the input).
    public var band: Double
    public var creaseGlow: Double
    public var score: Int
    public var chain: Int
    /// The current chain multiplier (1…4).
    public var multiplier: Double
    /// Sunrise progress 0…1 (levels and daily). Endless: the night's "depth" 0…1 for art (slowly rising, never wins).
    public var sun: Double
    /// Seconds of play (excludes waiting and pauses).
    public var time: Double
    /// Pops so far this session.
    public var pops: Int
    public var telemetry: Telemetry

    public var flowersLeft: Int { flowers.filter { $0 }.count }

    public init(mode: PlayMode, phase: SessionPhase = .waiting, glooms: [GloomState] = [], fireflies: [FireflyState] = [],
                flowers: [Bool] = Array(repeating: true, count: 5), band: Double = -0.2, creaseGlow: Double = 0,
                score: Int = 0, chain: Int = 0, multiplier: Double = 1, sun: Double = 0, time: Double = 0, pops: Int = 0,
                telemetry: Telemetry = Telemetry()) {
        self.mode = mode; self.phase = phase; self.glooms = glooms; self.fireflies = fireflies; self.flowers = flowers
        self.band = band; self.creaseGlow = creaseGlow; self.score = score; self.chain = chain
        self.multiplier = multiplier; self.sun = sun; self.time = time; self.pops = pops; self.telemetry = telemetry
    }
}

// MARK: - Events (Core → Scene FX, Feedback, App)

public enum GameEvent: Equatable, Sendable {
    /// A gloom came out of the crease.
    case emerged(id: Int, kind: GloomKind, u: Double)
    /// A gloom popped. `chain` is the chain count after this pop (1 = first), `points` already includes the multiplier.
    case popped(id: Int, kind: GloomKind, u: Double, d: Double, chain: Int, points: Int)
    /// 3+ pops within `Tuning.sweepWindow`: fired once per sweep, when it reaches 3 (then again at each further pop
    /// with the running count). `bonus` is the points added by this event.
    case swept(count: Int, bonus: Int)
    /// A splitter popped into wisps (the wisps also get `.emerged`).
    case split(u: Double, d: Double)
    /// A hopper hopped (`skittish`: the light made it jump).
    case hopped(id: Int, u: Double, d: Double, skittish: Bool)
    case fireflyEmerged(id: Int, u: Double)
    case fireflyScorched(id: Int, u: Double, d: Double)
    /// A firefly reached the flowers. `replanted`: it brought back the flower in `lane`; else it bloomed for points.
    case fireflyDelivered(id: Int, lane: Int, replanted: Bool, points: Int)
    case flowerEaten(lane: Int, flowersLeft: Int, by: GloomKind)
    /// The chain was reset by a scorch or an eaten flower (not by timing out).
    case chainBroken(was: Int)
    /// The chain timed out quietly.
    case chainEnded(was: Int)
    case hint(HintID)
    /// The first light: `waiting` → `playing`.
    case started
    /// Level / daily won. `stars` 1…3 (daily: 0), `flowerBonus` already added to the score.
    case sunrise(stars: Int, flowerBonus: Int)
    /// Every flower gone.
    case nightWins
    /// Endless only: the wave number went up (for a banner).
    case waveUp(Int)
}

// MARK: - Layout (founder-owned; Scene and UI both use it)

/// How the canvas is split. On an iPhone Duo the two physical halves are the mirror and the garden (the fold is the
/// crease). On other iPhones the canvas is portrait and the garden takes `Tuning`-free `gardenFraction` of the height.
public struct GardenLayout: Equatable, Sendable {
    /// The canvas size in points (SwiftUI's view size; SpriteKit scene size).
    public var size: CGSize
    /// The fold runs top to bottom (book pose, landscape canvas). Else it runs left to right (laptop / phone).
    public var foldVertical: Bool
    /// Fold vertical: garden on the right half (default). Fold horizontal: garden on the bottom half (default).
    /// "Swap halves" in Settings sets this false.
    public var gardenAfter: Bool
    /// The share of the canvas (along the fold-normal axis) given to the garden: 0.5 on a Duo, 0.58 on a phone.
    public var gardenFraction: CGFloat

    public init(size: CGSize, foldVertical: Bool, gardenAfter: Bool = true, gardenFraction: CGFloat = 0.5) {
        self.size = size; self.foldVertical = foldVertical; self.gardenAfter = gardenAfter
        self.gardenFraction = min(max(gardenFraction, 0.3), 0.8)
    }

    /// The layout for a canvas: landscape canvases fold vertically. `isDuo` picks the 0.5 split, else 0.58.
    public static func make(size: CGSize, isDuo: Bool, swapHalves: Bool) -> GardenLayout {
        GardenLayout(size: size, foldVertical: isDuo && size.width > size.height, gardenAfter: !swapHalves,
                     gardenFraction: isDuo ? 0.5 : 0.58)
    }

    /// The length of the fold-normal axis.
    private var axis: CGFloat { foldVertical ? size.width : size.height }
    /// Garden length along `d` (points).
    public var gardenDepth: CGFloat { axis * gardenFraction }
    /// Garden length along `u` (points).
    public var gardenSpan: CGFloat { foldVertical ? size.height : size.width }
    /// Points per floor `d` unit (use for radii).
    public var pointsPerD: CGFloat { gardenDepth }

    // Rects are in SwiftUI coordinates (origin top-left, y down). Scene code converts with `sceneY(_:)`.

    /// The garden half.
    public var gardenRect: CGRect {
        let depth = gardenDepth
        if foldVertical {
            return gardenAfter ? CGRect(x: size.width - depth, y: 0, width: depth, height: size.height)
                               : CGRect(x: 0, y: 0, width: depth, height: size.height)
        }
        return gardenAfter ? CGRect(x: 0, y: size.height - depth, width: size.width, height: depth)
                           : CGRect(x: 0, y: 0, width: size.width, height: depth)
    }

    /// The mirror half (everything that isn't garden).
    public var mirrorRect: CGRect {
        let g = gardenRect
        if foldVertical {
            return gardenAfter ? CGRect(x: 0, y: 0, width: g.minX, height: size.height)
                               : CGRect(x: g.maxX, y: 0, width: size.width - g.maxX, height: size.height)
        }
        return gardenAfter ? CGRect(x: 0, y: 0, width: size.width, height: g.minY)
                           : CGRect(x: 0, y: g.maxY, width: size.width, height: size.height - g.maxY)
    }

    /// A floor point (u, d) on the canvas (SwiftUI coordinates). d may be outside 0…1 (the crease art, off-edge FX).
    /// u runs left → right in a laptop layout and top → bottom in a book layout (u = 0 at the top).
    public func point(u: Double, d: Double) -> CGPoint {
        let g = gardenRect
        let uu = CGFloat(u), dd = CGFloat(d)
        if foldVertical {
            let x = gardenAfter ? g.minX + dd * g.width : g.maxX - dd * g.width
            return CGPoint(x: x, y: g.minY + uu * g.height)
        }
        let y = gardenAfter ? g.minY + dd * g.height : g.maxY - dd * g.height
        return CGPoint(x: g.minX + uu * g.width, y: y)
    }

    /// The inverse of `point(u:d:)` (unclamped).
    public func floorPoint(at p: CGPoint) -> (u: Double, d: Double) {
        let g = gardenRect
        guard g.width > 0, g.height > 0 else { return (0, 0) }
        if foldVertical {
            let d = gardenAfter ? (p.x - g.minX) / g.width : (g.maxX - p.x) / g.width
            return (Double((p.y - g.minY) / g.height), Double(d))
        }
        let d = gardenAfter ? (p.y - g.minY) / g.height : (g.maxY - p.y) / g.height
        return (Double((p.x - g.minX) / g.width), Double(d))
    }

    /// The crease line's midpoint (SwiftUI coordinates).
    public var creasePoint: CGPoint { point(u: 0.5, d: 0) }

    /// Unit vector (SwiftUI coordinates) pointing from the crease towards the flowers (+d).
    public var dDirection: CGVector {
        if foldVertical { return CGVector(dx: gardenAfter ? 1 : -1, dy: 0) }
        return CGVector(dx: 0, dy: gardenAfter ? 1 : -1)
    }

    /// Converts a SwiftUI y to SpriteKit's (origin bottom-left).
    public func sceneY(_ y: CGFloat) -> CGFloat { size.height - y }
    /// A SwiftUI-space point in SpriteKit coordinates.
    public func scenePoint(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }
}

// MARK: - Brand

public enum AppBrand {
    /// The product name (`CFBundleDisplayName`), never a literal in code.
    public static var name: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "Glint"
    }
}
