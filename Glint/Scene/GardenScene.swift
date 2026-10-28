import Foundation
import QuartzCore
import SpriteKit
import UIKit

/// The frame loop's other half (ARCHITECTURE "Scene API"): the App's `GameController` advances the session and hands
/// back what to draw; the scene forwards drags (SwiftUI-space points, y down).
@MainActor
protocol GardenDriver: AnyObject {
    func advance(dt: Double, now: TimeInterval) -> (DawnSnapshot, [GameEvent])
    func dragBegan(_ p: CGPoint)
    func dragMoved(_ p: CGPoint)
    func dragEnded()
}

/// How the canonical garden sits on the scene for a `GardenLayout`.
///
/// The canonical garden is drawn once in its own coordinates: x = d × depth (0 at the crease, `depth` at the flower
/// edge) and y = u × span. A node with `position = origin`, `zRotation = dAngle` and `yScale = uFlip` puts it exactly on
/// `layout.point(u:d:)` (converted to SpriteKit's y-up space) for all four layouts.
struct GardenFrame {
    let layout: GardenLayout
    /// Scene point of (u 0, d 0).
    let origin: CGPoint
    /// The angle of +d in the scene.
    let dAngle: CGFloat
    /// +1 or −1: the canonical y axis's sign so it runs along +u.
    let uFlip: CGFloat
    let depth: CGFloat
    let span: CGFloat
    /// Unit vectors in the scene: towards the flowers (+d), and along +u.
    let dUnit: CGVector
    let uUnit: CGVector
    /// The garden and mirror halves in scene coordinates (y up).
    let gardenRect: CGRect
    let mirrorRect: CGRect

    init(layout: GardenLayout) {
        self.layout = layout
        let o = layout.scenePoint(layout.point(u: 0, d: 0))
        let dd = layout.dDirection
        let dScene = CGVector(dx: dd.dx, dy: -dd.dy)
        let pu = layout.scenePoint(layout.point(u: 1, d: 0))
        var uScene = CGVector(dx: pu.x - o.x, dy: pu.y - o.y)
        let ul = max(sqrt(uScene.dx * uScene.dx + uScene.dy * uScene.dy), 0.000_1)
        uScene = CGVector(dx: uScene.dx / ul, dy: uScene.dy / ul)
        let a = atan2(dScene.dy, dScene.dx)
        let localY = CGVector(dx: -sin(a), dy: cos(a))
        let dot = localY.dx * uScene.dx + localY.dy * uScene.dy
        origin = o
        dAngle = a
        uFlip = dot >= 0 ? 1 : -1
        depth = layout.gardenDepth
        span = layout.gardenSpan
        dUnit = dScene
        uUnit = uScene
        let h = layout.size.height
        gardenRect = GardenFrame.sceneRect(layout.gardenRect, height: h)
        mirrorRect = GardenFrame.sceneRect(layout.mirrorRect, height: h)
    }

    /// A floor point in scene coordinates.
    func scene(u: Double, d: Double) -> CGPoint { layout.scenePoint(layout.point(u: u, d: d)) }

    /// A floor point in the canonical garden's coordinates.
    func local(u: Double, d: Double) -> CGPoint { CGPoint(x: CGFloat(d) * depth, y: CGFloat(u) * span) }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    /// A SwiftUI-space rect (y down) in scene coordinates (y up).
    static func sceneRect(_ r: CGRect, height: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: height - r.maxY, width: r.width, height: r.height)
    }
}

/// The garden: the SpriteKit view of a `DawnSnapshot` (ARCHITECTURE "Scene API"). It draws everything inside the canvas
/// (the mirror with its dawn sky and rising sun, the crease, the lawn, the band of light, the glooms, fireflies,
/// flowers and every cosmetic FX) and never changes game state.
///
/// Composition (z, all under `world`, which shakes):
/// - 0  `garden` (canonical, rotated per layout): night lawn, dawn lawn, night veil, crease ink, dew glints, the band
///   (R2: additive light layers — beam, halo, trail, pool, core — cut along u by cloud shades), shade tints, the crease
///   shade and its rim (7.5), the crease's pooled glow; the seam (46) and the night rolling in (55) too.
/// - 11 / 45 / 47 the phone lever (R2): the rail's garden and mirror parts, the grip on the band's edge.
/// - 12 flowers, 19 contact shadows, 20 glooms (ordered by d), 24 fireflies — upright, in scene points.
/// - 30 particles and rings. 40 the mirror (it covers anything still inside the crease). 50 floating words.
/// - 56 the sunrise flood.
@MainActor
final class GardenScene: SKScene {
    weak var driver: GardenDriver?

    /// Phone fallback: draw the brass lever on the mirror half.
    var showsLever: Bool = false

    /// Menus behind glass: softer, no floating words, no shake.
    var attract: Bool = false {
        didSet { applyMood() }
    }

    /// No shimmer, no shake, gentler idle motion, fewer particles.
    var reduceMotion: Bool = false {
        didSet { applyMood() }
    }

    private(set) var layout: GardenLayout
    private(set) var gardenFrame: GardenFrame
    /// The snapshot drawn last.
    private(set) var snapshot: DawnSnapshot
    /// Frames drawn since the scene was made.
    private(set) var frameIndex: Int = 0
    /// Gloom and firefly nodes ever created (pooling: this stops growing once the pool is warm).
    private(set) var gloomNodesMade: Int = 0
    private(set) var fireflyNodesMade: Int = 0

    private let world = SKNode()
    private let garden = SKNode()
    private let groundNight = SKSpriteNode()
    private let groundDawn = SKSpriteNode()
    private let nightVeil = SKSpriteNode(color: .black, size: CGSize(width: 4, height: 4))
    private let creaseInk = SKSpriteNode()
    /// R2: the reflected light as additive layers, cut along u by cloud shades.
    private let lightHalo: GardenLightLayer
    private let lightBeam: GardenLightLayer
    private let lightTrail: GardenLightLayer
    private let lightPool: GardenLightLayer
    private let lightCore: GardenLightLayer
    private var lightPieces: [LightPiece] = []
    /// R2: the crease shade (light does nothing for d < `Tuning.creaseShade`) and its cool rim.
    private let shadeStrip = SKSpriteNode()
    private let shadeRim = SKSpriteNode()
    /// R2: cloud shades' cool tint over the light's path.
    private var shadeTints: [SKSpriteNode] = []
    /// R2: the phone's 1:1 lever: a rail from d = bandMin to 1 and a grip pill on the band's edge.
    private let railMirror = SKSpriteNode()
    private let railGarden = SKSpriteNode()
    private let grip = SKSpriteNode()
    private let gripGlow = SKSpriteNode()
    private var firstBand: Double?
    private(set) var gripPulsing = false
    /// R2: the light's lagging ghost (a warm trail where the band just was) and the sweep's swell.
    private var trailBand: CGFloat = -0.2
    private(set) var bandSwell: CGFloat = 0
    private let creaseGlow = SKSpriteNode()
    private let seam = SKSpriteNode()
    private let seamGlow = SKSpriteNode()
    private let nightRoll = SKSpriteNode()
    private let flowersRoot = SKNode()
    private let shadowsRoot = SKNode()
    private let actorsRoot = SKNode()
    private let firefliesRoot = SKNode()
    private let flood = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 4))
    private let floodRays = SKSpriteNode()
    private let mirror: GardenMirror
    private let fx: GardenFX
    private let labels: GardenLabels

    private struct DewSpot {
        let u: Double
        let d: Double
        let phase: CGFloat
        let size: CGFloat
    }

    private var dew: [SKSpriteNode] = []
    private var dewSpots: [DewSpot] = []
    private var flowers: [GardenFlower] = []
    private var laneDanger: [CGFloat] = []
    private var glooms: [Int: GloomNode] = [:]
    private var gloomPool: [GloomNode] = []
    private var dyingGlooms: [GloomNode] = []
    private var fireflies: [Int: GardenFirefly] = [:]
    private var fireflyPool: [GardenFirefly] = []
    private var dyingFireflies: [GardenFirefly] = []
    private var scratch: [Int] = []
    private var framePopped: [Int] = []
    private var frameScorched: [Int] = []
    private var frameDelivered: [Int] = []
    private var frameEatenLanes: [Int] = []
    private var frameEvaporate = false
    private var recentPops: [(CGPoint, CGFloat)] = []
    private var sweepSlot = -1
    private var hasSnapshot = false
    private var lastUpdate: TimeInterval?
    private var animTime: CGFloat = 0
    private var shakeAmp: CGFloat = 0
    private var moteClock: CGFloat = 0
    private var sunriseAge: CGFloat = -1
    private var nightAge: CGFloat = -1
    private(set) var nightLevel: CGFloat = 0
    private(set) var floodLevel: CGFloat = 0
    private var dragTouch: ObjectIdentifier?
    private var groundKeys: [String] = []
    /// R2b: the ground drawn now (by `snapshot.mode`: Meadow / Rooftops / Harbour, Long Night's moonlit meadow).
    private(set) var groundStyle: GroundStyle = .meadow
    /// R2b: the mirror shows the moon (Long Night).
    var mirrorMoonlit: Bool { mirror.moonlit }
    /// R2b: the glint spots now (floor u, d): on the harbour they sit on the puddles.
    var glintSpots: [(u: Double, d: Double)] { dewSpots.map { (u: $0.u, d: $0.d) } }
    private var rng = GardenRNG(seed: 0x6A2D)

    // MARK: Read-outs (tests, the App)

    /// Glooms drawn (alive in the snapshot), leaving (evaporating, diving, fading), and waiting in the pool.
    var activeGloomCount: Int { glooms.count }
    var dyingGloomCount: Int { dyingGlooms.count }
    var pooledGloomCount: Int { gloomPool.count }
    var activeFireflyCount: Int { fireflies.count }
    /// Live particles, rings and flashes.
    var fxActiveCount: Int { fx.activeCount }
    /// The floating words on screen now.
    var floatingTexts: [String] { labels.visibleTexts }
    /// Every node under the scene, and those actually drawn (not hidden, not transparent).
    var nodeCount: Int { GardenScene.countNodes(self, visibleOnly: false) }
    var drawnNodeCount: Int { GardenScene.countNodes(self, visibleOnly: true) }
    /// The canonical garden node (tests convert through it).
    var gardenNode: SKNode { garden }
    /// The lever is drawn (phone fallback): R2, the grip on the band's edge riding its rail.
    var leverShowing: Bool { !grip.isHidden }
    /// The grip's centre (scene points): it sits at d = band exactly (1:1).
    var leverPoint: CGPoint { grip.position }
    /// R2: the sun's glint as drawn and the sun's radius; the glass's hot spot.
    var sunGlintSize: CGFloat { mirror.glintSize }
    var sunRadius: CGFloat { mirror.sunRadius }
    var mirrorHotSpot: CGPoint { mirror.hotSpotPoint }
    /// R2: the shade clouds drawn in the mirror's sky, and light sprites drawn in the garden.
    var mirrorShadeClouds: Int { mirror.shadeCloudCount }
    var lightSpriteCount: Int {
        lightHalo.visibleCount + lightBeam.visibleCount + lightTrail.visibleCount + lightPool.visibleCount
            + lightCore.visibleCount
    }
    /// R2: where the crease shade's cool rim is drawn (scene points, its middle).
    var shadeRimCenter: CGPoint { garden.convert(shadeRim.position, to: self) }
    /// R2: the biggest scale a chain's "×n" reached (it springs past 1).
    var chainTextPeakScale: CGFloat { labels.peakBounceScale }
    /// The sun as drawn on the mirror (scene points).
    var sunPoint: CGPoint { mirror.sunPoint }
    /// The mirror's glass inside its frame (scene points).
    var mirrorGlass: CGRect { mirror.inner }
    /// The world drawn on the mirror's horizon (1…3).
    var mirrorWorld: Int { mirror.world }
    /// The canvas shake this frame (zero with Reduce Motion or in attract mode).
    var shakeOffset: CGPoint { world.position }
    /// The flowers as drawn: standing or not.
    var flowersStanding: [Bool] { flowers.map { $0.standing } }
    /// The band's core as drawn: its centre in scene points (nil while hidden).
    var bandCenter: CGPoint? {
        guard lightCore.visibleCount > 0 else { return nil }
        return gardenFrame.scene(u: 0.5, d: snapshot.band)
    }

    /// Where gloom `id` is drawn (scene points), if it is on screen.
    func gloomPoint(id: Int) -> CGPoint? { glooms[id]?.drawnPoint }
    /// Gloom `id` has its eyes squeezed shut in the light.
    func gloomSqueezing(id: Int) -> Bool { glooms[id]?.isSqueezing ?? false }
    /// R2: gloom `id` is sunk in the crease shade; its drawn radius (points); where its eyes look (scene unit vector).
    func gloomSubmerged(id: Int) -> Bool { glooms[id]?.isSubmerged ?? false }
    func gloomRadius(id: Int) -> CGFloat? { glooms[id]?.radiusPts }
    func gloomLook(id: Int) -> CGVector? { glooms[id]?.lookDir }

    /// R2: the rects the App's HUD must never cover (SwiftUI space): the flowers.
    /// Static and nonisolated, so App tests can call `GardenScene.hudSafeRects(layout:)` without a scene.
    nonisolated static func hudSafeRects(layout: GardenLayout) -> [CGRect] { flowerRects(layout: layout) }

    /// The flowers as drawn (petals and leaves), in SwiftUI space (y down), for `layout`. The App keeps its HUD clear of
    /// them. Lane i sits at u = (i + 0.5) / count, just inside the flower edge.
    nonisolated static func flowerRects(layout: GardenLayout, count: Int = GardenMath.flowerCount) -> [CGRect] {
        let n = max(count, 0)
        guard n > 0 else { return [] }
        let depth = layout.gardenDepth
        let span = layout.gardenSpan
        let r = GardenMath.flowerRadius(depth: depth, span: span, count: n) * 1.3
        let d = GardenMath.flowerD(depth: depth, span: span, count: n)
        var out: [CGRect] = []
        for i in 0..<n {
            let p = layout.point(u: (Double(i) + 0.5) / Double(n), d: d)
            out.append(CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        }
        return out
    }

    /// A floor point in scene coordinates.
    func scenePoint(u: Double, d: Double) -> CGPoint { gardenFrame.scene(u: u, d: d) }

    /// A scene point (y up) in SwiftUI space (y down), as the drag fallback wants it.
    func swiftUIPoint(fromScene p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: layout.size.height - p.y) }

    // MARK: Life cycle

    init(layout: GardenLayout) {
        self.layout = layout
        gardenFrame = GardenFrame(layout: layout)
        snapshot = DawnSnapshot(mode: .level(1))
        mirror = GardenMirror()
        fx = GardenFX()
        labels = GardenLabels(capacity: 8)
        // R2 (REVIEW-1 P0-2): reflected sunlight, additive, the grass showing through.
        lightHalo = GardenLightLayer(.halo, color: GardenInk(hex: 0xFFB04A).ui)
        lightBeam = GardenLightLayer(.beam, color: GardenInk(hex: 0xFFC86A).ui)
        lightTrail = GardenLightLayer(.pool, color: GardenInk(hex: 0xFFB24A).ui)
        lightPool = GardenLightLayer(.pool, color: GardenInk(hex: 0xFFC24A).ui)
        lightCore = GardenLightLayer(.core, color: GardenInk(hex: 0xFFF4D6).ui)
        super.init(size: layout.size)
        setUp()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GardenScene is created in code with init(layout:)")
    }

    private func setUp() {
        scaleMode = .aspectFill
        anchorPoint = .zero
        backgroundColor = GardenPalette.backdrop.ui

        // Every texture the frame loop can ask for, built now (never mid-play).
        CreatureArt.warmGlooms()
        CreatureArt.warmFlowers(count: GardenMath.flowerCount)
        MirrorArt.warm()
        for i in 0..<3 { _ = GardenArt.petal(i) }
        _ = GardenArt.inkDrop
        _ = GardenArt.ring
        _ = GardenArt.rays

        world.zPosition = 0
        addChild(world)

        garden.zPosition = 0
        world.addChild(garden)
        groundNight.texture = nil
        groundNight.zPosition = 0
        groundDawn.zPosition = 0.5
        nightVeil.color = GardenPalette.night.ui
        nightVeil.zPosition = 1
        creaseInk.texture = GardenArt.creaseInk
        creaseInk.colorBlendFactor = 1
        creaseInk.color = GardenInk(hex: 0x07040F).ui
        creaseInk.anchorPoint = CGPoint(x: 0, y: 0.5)
        creaseInk.zPosition = 2
        lightBeam.root.zPosition = 4
        lightHalo.root.zPosition = 4.5
        lightTrail.root.zPosition = 5
        lightPool.root.zPosition = 5.5
        lightCore.root.zPosition = 6
        let lightRoots: [SKNode] = [lightBeam.root, lightHalo.root, lightTrail.root, lightPool.root, lightCore.root]
        for n in lightRoots { garden.addChild(n) }
        for _ in 0..<3 {
            let t = SKSpriteNode(texture: GardenArt.shadeTint)
            t.colorBlendFactor = 1
            t.color = GardenInk(hex: 0x233F73).ui
            t.anchorPoint = CGPoint(x: 0, y: 0.5)
            t.zPosition = 7.2
            t.isHidden = true
            garden.addChild(t)
            shadeTints.append(t)
        }
        shadeStrip.texture = GardenArt.creaseShade
        shadeStrip.colorBlendFactor = 1
        shadeStrip.color = GardenInk(hex: 0x03050F).ui
        shadeStrip.anchorPoint = CGPoint(x: 0, y: 0.5)
        shadeStrip.alpha = 0.62
        shadeStrip.zPosition = 7.5
        shadeRim.texture = GardenArt.line
        shadeRim.blendMode = .add
        shadeRim.colorBlendFactor = 1
        shadeRim.color = GardenInk(hex: 0x8FC4FF).ui
        shadeRim.zPosition = 7.6
        garden.addChild(shadeStrip)
        garden.addChild(shadeRim)
        creaseGlow.texture = GardenArt.creaseGlow
        creaseGlow.blendMode = .add
        creaseGlow.colorBlendFactor = 1
        creaseGlow.color = GardenPalette.amber.ui
        creaseGlow.anchorPoint = CGPoint(x: 0, y: 0.5)
        creaseGlow.zPosition = 8
        seam.texture = GardenArt.seam
        seam.zPosition = 46
        seamGlow.texture = GardenArt.line
        seamGlow.blendMode = .add
        seamGlow.colorBlendFactor = 1
        seamGlow.color = GardenPalette.gold.ui
        seamGlow.zPosition = 46.5
        nightRoll.texture = GardenArt.nightRoll
        nightRoll.colorBlendFactor = 1
        nightRoll.color = GardenInk(hex: 0x05061A).ui
        nightRoll.anchorPoint = CGPoint(x: 1, y: 0.5)
        nightRoll.zPosition = 55
        nightRoll.isHidden = true
        for n in [groundNight, groundDawn, nightVeil, creaseInk, creaseGlow, seam, seamGlow, nightRoll] {
            garden.addChild(n)
        }
        for n in [groundNight, groundDawn, nightVeil] { n.anchorPoint = .zero }

        // Dew glints: fixed drops (R2b: puddles on the harbour's boardwalk) that sparkle where the band crosses them.
        for _ in 0..<GardenScene.glintCount {
            let s = SKSpriteNode(texture: GardenArt.sparkle)
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.color = GardenInk(hex: 0xFFF8DC).ui
            s.zPosition = 3
            s.isHidden = true
            garden.addChild(s)
            dew.append(s)
        }

        flowersRoot.zPosition = 12
        shadowsRoot.zPosition = 19
        actorsRoot.zPosition = 20
        firefliesRoot.zPosition = 24
        fx.root.zPosition = 30
        mirror.root.zPosition = 40
        labels.root.zPosition = 50
        flood.zPosition = 56
        floodRays.zPosition = 56.5
        let layers: [SKNode] = [flowersRoot, shadowsRoot, actorsRoot, firefliesRoot, fx.root, mirror.root, labels.root,
                                flood, floodRays]
        for n in layers { world.addChild(n) }
        flood.blendMode = .add
        flood.color = GardenInk(hex: 0xFFB648).ui
        flood.isHidden = true
        floodRays.texture = GardenArt.rays
        floodRays.blendMode = .add
        floodRays.colorBlendFactor = 1
        floodRays.color = GardenPalette.goldHot.ui
        floodRays.isHidden = true

        // R2: the phone's lever rides the band 1:1: a brass rail from d = bandMin (inside the mirror) to the flower
        // edge, and a gold grip pill on the band's edge. The rail's mirror part sits over the glass; its garden part
        // under the flowers.
        railMirror.texture = MirrorArt.leverTrack
        railMirror.zPosition = 45
        railGarden.texture = MirrorArt.leverTrack
        railGarden.zPosition = 11
        gripGlow.texture = GardenArt.glow
        gripGlow.blendMode = .add
        gripGlow.colorBlendFactor = 1
        gripGlow.color = GardenPalette.gold.ui
        gripGlow.zPosition = 47
        grip.texture = MirrorArt.grip
        grip.zPosition = 47.5
        let rail: [SKSpriteNode] = [railMirror, railGarden, gripGlow, grip]
        for n in rail {
            n.isHidden = true
            world.addChild(n)
        }

        // A warm pool, so the first wave never allocates nodes mid-play.
        for _ in 0..<12 {
            gloomPool.append(GloomNode())
            gloomNodesMade += 1
        }
        for _ in 0..<3 {
            fireflyPool.append(GardenFirefly())
            fireflyNodesMade += 1
        }
        rebuildFlowers(count: GardenMath.flowerCount)
        applyMood()
        applyLayoutNow()
    }

    /// Rotation, swap or resize: rebuild every position for `newLayout`, keeping each gloom's state.
    func apply(layout newLayout: GardenLayout) {
        let old = gardenFrame
        layout = newLayout
        applyLayoutNow()
        let f = gardenFrame
        if old.layout.foldVertical == f.layout.foldVertical && old.layout.gardenAfter == f.layout.gardenAfter {
            // Same way round: in-flight bursts move with the garden.
            let delta = CGVector(dx: f.origin.x - old.origin.x, dy: f.origin.y - old.origin.y)
            fx.shift(by: delta)
            labels.shift(by: delta)
        } else {
            // Turned: bursts can't follow; the glooms keep their own state (light, hops, blinks).
            fx.clear()
            labels.clear()
            for n in dyingGlooms { releaseGloom(n) }
            dyingGlooms.removeAll()
        }
    }

    /// A new session the App announces (also detected on its own when the clock runs backwards or the mode changes).
    func reset() {
        hasSnapshot = false
    }

    private func applyMood() {
        var k: CGFloat = attract ? 0.6 : 1
        if reduceMotion { k *= 0.5 }
        fx.density = k
        if attract { labels.clear() }
        if attract || reduceMotion {
            shakeAmp = 0
            world.position = .zero
        }
    }

    private func applyLayoutNow() {
        let f = GardenFrame(layout: layout)
        gardenFrame = f
        if size != layout.size { size = layout.size }
        garden.position = f.origin
        garden.zRotation = f.dAngle
        garden.xScale = 1
        garden.yScale = f.uFlip
        let depth = max(f.depth, 1)
        let span = max(f.span, 1)

        applyGround()
        for n in [groundNight, groundDawn, nightVeil] {
            n.position = .zero
            n.size = CGSize(width: depth, height: span)
        }
        creaseInk.position = CGPoint(x: 0, y: span / 2)
        creaseInk.size = CGSize(width: depth * 0.14, height: span)
        creaseGlow.position = CGPoint(x: 0, y: span / 2)
        creaseGlow.size = CGSize(width: depth * 0.22, height: span)
        seam.position = CGPoint(x: 0, y: span / 2)
        seam.size = CGSize(width: max(6, depth * 0.014), height: span)
        seamGlow.position = CGPoint(x: 0, y: span / 2)
        seamGlow.size = CGSize(width: max(12, depth * 0.035), height: span)
        nightRoll.size = CGSize(width: 1, height: span)
        // R2: the crease shade ends (and its cool rim sits) at d = Tuning.creaseShade.
        let shadeX = CGFloat(GardenMath.creaseShade) * depth
        shadeStrip.position = CGPoint(x: 0, y: span / 2)
        shadeStrip.size = CGSize(width: shadeX / GardenArt.shadeEnd, height: span)
        shadeRim.position = CGPoint(x: shadeX, y: span / 2)
        shadeRim.size = CGSize(width: max(5, depth * 0.014), height: span)
        // R2: the lever's rail runs along d at the grip's u, from bandMin to the flower edge.
        let gu = gripU
        let a = f.scene(u: gu, d: GardenMath.bandMin)
        let z = f.scene(u: gu, d: 0)
        let e = f.scene(u: gu, d: 1)
        let railAngle = atan2(-f.dUnit.dx, f.dUnit.dy)
        let railW: CGFloat = 9
        railMirror.position = CGPoint(x: (a.x + z.x) / 2, y: (a.y + z.y) / 2)
        railMirror.size = CGSize(width: railW, height: max(GardenFrame.distance(a, z), 1))
        railMirror.zRotation = railAngle
        railGarden.position = CGPoint(x: (z.x + e.x) / 2, y: (z.y + e.y) / 2)
        railGarden.size = CGSize(width: railW, height: max(GardenFrame.distance(z, e), 1))
        railGarden.zRotation = railAngle
        grip.size = CGSize(width: 44, height: 20)
        grip.zRotation = atan2(f.uUnit.dy, f.uUnit.dx)
        gripGlow.size = CGSize(width: 96, height: 64)
        gripGlow.zRotation = grip.zRotation
        placeFlowers()
        mirror.apply(rect: f.mirrorRect, towardCrease: f.dUnit)
        flood.size = layout.size
        flood.position = CGPoint(x: layout.size.width / 2, y: layout.size.height / 2)
        let fr = max(layout.size.width, layout.size.height) * 1.3
        floodRays.size = CGSize(width: fr, height: fr)
    }

    static let glintCount = 22

    /// R2b: the ground for the current style and size (cached per style and size; a few recent ones are kept for
    /// rotating and for going back to a world), and the glint spots that go with it.
    private func applyGround() {
        let f = gardenFrame
        let depth = max(f.depth, 1)
        let span = max(f.span, 1)
        let style = groundStyle
        groundNight.texture = GardenArt.ground(depth: depth, span: span, warm: false, style: style)
        groundDawn.texture = GardenArt.ground(depth: depth, span: span, warm: true, style: style)
        let keys = [GardenArt.groundKey(depth: depth, span: span, warm: false, style: style),
                    GardenArt.groundKey(depth: depth, span: span, warm: true, style: style)]
        groundKeys.removeAll { keys.contains($0) }
        groundKeys.append(contentsOf: keys)
        if groundKeys.count > 8 { groundKeys.removeFirst(groundKeys.count - 8) }
        GardenArt.purge(prefix: "ground-", keeping: groundKeys)

        // Glints: scattered dew on lawns and roofs; on the boardwalk, the puddles shine.
        var dr = GardenRNG(seed: 0xDE_77)
        dewSpots.removeAll(keepingCapacity: true)
        if style == .harbour {
            let puddles = GardenMath.puddles(depth: depth, span: span)
            for i in 0..<GardenScene.glintCount {
                guard !puddles.isEmpty else { break }
                let pd = puddles[i % puddles.count]
                let ox = dr.range(-0.5, 0.5) * pd.r
                let oy = dr.range(-0.8, 0.8) * pd.r
                dewSpots.append(DewSpot(u: pd.u + Double(oy / span), d: pd.d + Double(ox / depth),
                                        phase: dr.range(0, 6.28), size: dr.range(12, 22)))
            }
        } else {
            for _ in 0..<GardenScene.glintCount {
                dewSpots.append(DewSpot(u: Double(dr.range(0.03, 0.97)), d: Double(dr.range(0.14, 0.84)),
                                        phase: dr.range(0, 6.28), size: dr.range(9, 16)))
            }
        }
        for (i, s) in dew.enumerated() {
            guard i < dewSpots.count else {
                s.isHidden = true
                continue
            }
            let sp = dewSpots[i]
            s.position = f.local(u: sp.u, d: sp.d)
            s.size = CGSize(width: sp.size, height: sp.size)
        }
    }

    /// R2b: the light's colours: warm sunlight, or Long Night's silver-gold moonlight (still warm enough to read).
    private func applyLightPalette() {
        if groundStyle.isMoonlit {
            lightPool.setColor(GardenInk(hex: 0xF2DDA0).ui)
            lightCore.setColor(GardenInk(hex: 0xF6F2E6).ui)
            lightHalo.setColor(GardenInk(hex: 0xC8D4FF).ui)
            lightBeam.setColor(GardenInk(hex: 0xD9D2B0).ui)
            lightTrail.setColor(GardenInk(hex: 0xE0C88A).ui)
        } else {
            lightPool.setColor(GardenInk(hex: 0xFFC24A).ui)
            lightCore.setColor(GardenInk(hex: 0xFFF4D6).ui)
            lightHalo.setColor(GardenInk(hex: 0xFFB04A).ui)
            lightBeam.setColor(GardenInk(hex: 0xFFC86A).ui)
            lightTrail.setColor(GardenInk(hex: 0xFFB24A).ui)
        }
        mirror.setMoonlit(groundStyle.isMoonlit)
    }

    private func rebuildFlowers(count n: Int) {
        for fl in flowers { fl.root.removeFromParent() }
        flowers.removeAll()
        for i in 0..<max(n, 0) {
            let fl = GardenFlower(index: i)
            flowersRoot.addChild(fl.root)
            flowers.append(fl)
        }
        laneDanger = Array(repeating: 0, count: max(n, 0))
        placeFlowers()
    }

    private var flowerRadius: CGFloat {
        GardenMath.flowerRadius(depth: gardenFrame.depth, span: gardenFrame.span, count: max(flowers.count, 1))
    }

    private var flowerD: Double {
        GardenMath.flowerD(depth: gardenFrame.depth, span: gardenFrame.span, count: max(flowers.count, 1))
    }

    private func placeFlowers() {
        let n = flowers.count
        guard n > 0 else { return }
        let r = flowerRadius
        let d = flowerD
        for (i, fl) in flowers.enumerated() {
            let u = (Double(i) + 0.5) / Double(n)
            fl.place(at: gardenFrame.scene(u: u, d: d), radius: r)
        }
    }

    private func flowerPoint(_ lane: Int) -> CGPoint {
        let n = max(flowers.count, 1)
        let l = min(max(lane, 0), n - 1)
        return gardenFrame.scene(u: (Double(l) + 0.5) / Double(n), d: flowerD)
    }

    private func flowerColor(_ lane: Int) -> GardenInk {
        guard lane >= 0, lane < flowers.count else { return GardenPalette.petals[0] }
        return flowers[lane].color
    }

    private static func lane(for u: Double, count: Int) -> Int {
        guard count > 0, u.isFinite else { return 0 }
        let k = Int((min(max(u, 0), 1) * Double(count)).rounded(.down))
        return min(max(k, 0), count - 1)
    }

    // MARK: Sizes

    private var labelSize: CGFloat {
        GardenMath.clamp(min(gardenFrame.depth, gardenFrame.span) * 0.075, 24, 46)
    }

    private var fireflySize: CGFloat { GardenMath.clamp(gardenFrame.depth * 0.032, 11, 19) }

    /// R2: glooms 15 % bigger on phones.
    private var gloomScale: CGFloat { GardenMath.gloomArtScale(layout: layout) }

    /// R2: the phone grip's lane: 30 pt in from the u = 1 edge.
    private var gripU: Double { Double(1 - 30 / max(gardenFrame.span, 60)) }

    /// A kind's typical radius (points), for FX when the node isn't on screen.
    private func nominalRadius(_ kind: GloomKind) -> CGFloat {
        let d: CGFloat
        switch kind {
        case .murk: d = 0.050
        case .wisp: d = 0.030
        case .brute: d = 0.085
        case .splitter: d = 0.060
        case .hopper: d = 0.050
        }
        return max(d * gardenFrame.depth * gloomScale, 6)
    }

    /// Keeps a floating word inside the garden.
    private func clampLabel(_ p: CGPoint) -> CGPoint {
        let g = gardenFrame.gardenRect.insetBy(dx: labelSize * 1.6, dy: labelSize * 0.9)
        guard g.width > 0, g.height > 0 else { return p }
        return CGPoint(x: min(max(p.x, g.minX), g.maxX), y: min(max(p.y, g.minY), g.maxY))
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        var dt: Double = 1.0 / 120.0
        if let last = lastUpdate { dt = min(max(currentTime - last, 0), 1.0 / 30.0) }
        lastUpdate = currentTime
        if let d = driver {
            let out = d.advance(dt: dt, now: CACurrentMediaTime())
            render(out.0, events: out.1, dt: dt)
        } else {
            render(snapshot, events: [], dt: dt)
        }
    }

    private func isNewSession(_ s: DawnSnapshot) -> Bool {
        if !hasSnapshot { return true }
        if s.mode != snapshot.mode { return true }
        if s.time + 0.25 < snapshot.time { return true }
        let wasOver = snapshot.phase == .won || snapshot.phase == .lost
        if wasOver && (s.phase == .waiting || s.phase == .playing) { return true }
        return false
    }

    /// Clears every effect and draws `s` as it stands (no animations).
    private func beginSession(_ s: DawnSnapshot) {
        for (_, n) in glooms { releaseGloom(n) }
        glooms.removeAll()
        for n in dyingGlooms { releaseGloom(n) }
        dyingGlooms.removeAll()
        for (_, f) in fireflies { releaseFirefly(f) }
        fireflies.removeAll()
        for f in dyingFireflies { releaseFirefly(f) }
        dyingFireflies.removeAll()
        fx.clear()
        labels.clear()
        recentPops.removeAll()
        sweepSlot = -1
        shakeAmp = 0
        world.position = .zero
        sunriseAge = s.phase == .won ? 10 : -1
        nightAge = s.phase == .lost ? 10 : -1
        firstBand = nil
        trailBand = CGFloat(s.band.isFinite ? s.band : GardenMath.bandMin)
        bandSwell = 0
        if s.flowers.count != flowers.count { rebuildFlowers(count: s.flowers.count) }
        for (i, fl) in flowers.enumerated() where i < s.flowers.count {
            fl.setStanding(s.flowers[i], animated: false)
        }
    }

    /// Draws one frame from `s` and its `events` with `dt` seconds of animation (tests call it directly).
    func render(_ s: DawnSnapshot, events: [GameEvent], dt rawDt: Double) {
        let dt = CGFloat(min(max(rawDt.isFinite ? rawDt : 0, 0), 0.1))
        if isNewSession(s) { beginSession(s) }
        snapshot = s
        hasSnapshot = true
        frameIndex += 1
        animTime += dt
        let motion: CGFloat = reduceMotion ? 0.35 : 1
        let dawn = GardenMath.dawn(s)
        let w = GardenMath.world(for: s.mode)
        if mirror.world != w { mirror.setWorld(w) }
        // R2b: the world's ground (built on first use per world, then cached).
        let style = GroundStyle.of(s.mode)
        if style != groundStyle {
            groundStyle = style
            applyGround()
            applyLightPalette()
        }
        mirror.moonDepth = GardenMath.nightDepth(s)

        framePopped.removeAll(keepingCapacity: true)
        frameScorched.removeAll(keepingCapacity: true)
        frameDelivered.removeAll(keepingCapacity: true)
        frameEatenLanes.removeAll(keepingCapacity: true)
        frameEvaporate = false
        if !events.isEmpty { handle(events) }

        syncFlowers(s, dt: dt, dawn: dawn, motion: motion)
        syncGlooms(s, dt: dt, motion: motion)
        syncFireflies(s, dt: dt, motion: motion)
        drawLight(s, dt: dt, dawn: dawn, motion: motion)
        drawOverlays(dt: dt)

        let band = CGFloat(s.band)
        let light = max(CGFloat(GardenMath.clamp(s.creaseGlow, 0, 1)), band >= 0 ? 1 : 0)
        // R2: the lever lives on the band itself now (`drawLever`); the mirror's own slot stays hidden.
        mirror.update(dt: dt, time: animTime, dawn: dawn, band: band, light: light, veilLevel: nightLevel,
                      lever: false, leverT: 0, motion: motion)
        placeShadeClouds(s)
        drawLever(s, motion: motion)

        fx.update(dt)
        labels.update(dt)

        if shakeAmp > 0.05 && !reduceMotion && !attract {
            shakeAmp *= exp(-dt * 9)
            world.position = CGPoint(x: sin(animTime * 67) * shakeAmp, y: cos(animTime * 53) * shakeAmp)
        } else {
            shakeAmp = 0
            world.position = .zero
        }
    }

    // MARK: Events → FX

    private func recordPop(_ p: CGPoint) {
        recentPops.append((p, animTime))
        if recentPops.count > 12 { recentPops.removeFirst(recentPops.count - 12) }
    }

    /// The centre of the last pops (a sweep's burst).
    private func sweepCentre() -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var n: CGFloat = 0
        for (p, t) in recentPops where animTime - t < 0.6 {
            x += p.x
            y += p.y
            n += 1
        }
        if n > 0 { return CGPoint(x: x / n, y: y / n) }
        let g = gardenFrame.gardenRect
        return CGPoint(x: g.midX, y: g.midY)
    }

    private func handle(_ events: [GameEvent]) {
        let f = gardenFrame
        for e in events {
            switch e {
            case .emerged(_, let kind, let u):
                let p = f.scene(u: u, d: 0.03)
                fx.ink(at: p, radius: nominalRadius(kind), count: 3, toward: f.dUnit)
                fx.ripple(at: p, radius: nominalRadius(kind))
            case .popped(let id, let kind, let u, let d, let chain, _):
                framePopped.append(id)
                var p = f.scene(u: u, d: d)
                var r = nominalRadius(kind)
                if let n = glooms[id] {
                    p = n.drawnPoint
                    r = n.radiusPts
                }
                fx.pop(at: p, radius: r, big: kind == .brute || kind == .splitter, chain: chain)
                recordPop(p)
                if kind == .brute && !reduceMotion && !attract { shakeAmp = max(shakeAmp, 3.5) }
                if chain >= 3 && !attract {
                    // R2: the chain count springs in, a little bigger with each step.
                    let grow = 0.72 + 0.04 * CGFloat(min(chain - 3, 8))
                    labels.show("×\(chain)", at: clampLabel(CGPoint(x: p.x, y: p.y + r * 1.3)), size: labelSize * grow,
                                color: GardenPalette.goldHot, rise: 34, life: 0.85, bouncy: true)
                }
            case .swept(let count, _):
                // R2: a brief swell of light along the band.
                bandSwell = 1
                let c = sweepCentre()
                fx.rings.spawn(at: c, fromRadius: 10, toRadius: labelSize * 4, life: 0.55, color: GardenPalette.gold.ui,
                               alpha: 0.9)
                if !attract {
                    let text = count > 3 ? "Sweep ×\(count)!" : "Sweep!"
                    if !labels.retext(sweepSlot, text, size: labelSize, color: GardenPalette.gold) {
                        sweepSlot = labels.show(text, at: clampLabel(CGPoint(x: c.x, y: c.y + labelSize)),
                                                size: labelSize, color: GardenPalette.gold, rise: 40, life: 1.1)
                    }
                }
            case .split(let u, let d):
                fx.ink(at: f.scene(u: u, d: d), radius: nominalRadius(.splitter), count: 6,
                       toward: CGVector(dx: 0, dy: 0))
            case .hopped(let id, let u, let d, let skittish):
                var p = f.scene(u: u, d: d)
                var r = nominalRadius(.hopper)
                if let n = glooms[id] {
                    n.hop()
                    p = n.drawnPoint
                    r = n.radiusPts
                }
                fx.dust(at: p, radius: r, color: GardenInk(hex: 0xB9C7A8))
                if skittish && !attract {
                    labels.show("!", at: clampLabel(CGPoint(x: p.x + r * 0.9, y: p.y + r * 1.4)), size: labelSize * 0.8,
                                color: GardenInk.white, rise: 20, life: 0.5)
                }
            case .fireflyEmerged(_, let u):
                fx.twinkle(at: f.scene(u: u, d: 0.03), size: fireflySize * 2.4, color: GardenPalette.firefly)
            case .fireflyScorched(let id, let u, let d):
                frameScorched.append(id)
                var p = f.scene(u: u, d: d)
                if let ff = fireflies[id] { p = ff.drawnPoint }
                fx.fizzle(at: p, size: fireflySize)
            case .fireflyDelivered(let id, let lane, let replanted, let points):
                frameDelivered.append(id)
                let target = flowerPoint(lane)
                var from = CGPoint(x: target.x - f.dUnit.dx * 40, y: target.y - f.dUnit.dy * 40)
                if let ff = fireflies[id] { from = ff.drawnPoint }
                fx.trail(from: from, to: target, color: GardenPalette.firefly)
                fx.rings.spawn(at: target, fromRadius: 6, toRadius: flowerRadius * 2.4, life: 0.5,
                               color: GardenPalette.firefly.ui, alpha: 0.8)
                let col = flowerColor(lane)
                fx.petals(at: target, spread: 60, count: 6, colors: [col, col.lighter(0.35)])
                if !replanted && !attract {
                    labels.show("+\(points)", at: clampLabel(CGPoint(x: target.x, y: target.y + flowerRadius * 1.6)),
                                size: labelSize * 0.7, color: GardenPalette.firefly, rise: 30, life: 0.9)
                }
            case .flowerEaten(let lane, _, _):
                frameEatenLanes.append(lane)
                let p = flowerPoint(lane)
                let col = flowerColor(lane)
                fx.petals(at: p, spread: 120, count: 12, colors: [col, col.lighter(0.3), col.darker(0.15)])
                fx.ink(at: p, radius: flowerRadius, count: 6, toward: CGVector(dx: 0, dy: 0))
                if !reduceMotion && !attract { shakeAmp = max(shakeAmp, 7) }
            case .chainBroken(_), .chainEnded(_), .hint(_):
                break
            case .started:
                for i in 0..<7 {
                    let u = (Double(i) + 0.5) / 7
                    fx.twinkle(at: f.scene(u: u, d: 0.02), size: 18, color: GardenPalette.goldHot)
                }
            case .sunrise(_, _):
                frameEvaporate = true
                sunriseAge = 0
                fx.confetti(in: f.gardenRect, count: attract ? 10 : 22)
            case .nightWins:
                nightAge = 0
            case .waveUp(let n):
                if !attract {
                    let g = f.gardenRect
                    labels.show("Wave \(n)", at: CGPoint(x: g.midX, y: g.midY), size: labelSize * 1.1,
                                color: GardenPalette.goldHot, rise: 24, life: 1.6)
                }
            }
        }
    }

    // MARK: Glooms

    private func acquireGloom(_ kind: GloomKind, id: Int) -> GloomNode {
        let n: GloomNode
        if let last = gloomPool.popLast() {
            n = last
        } else {
            n = GloomNode()
            gloomNodesMade += 1
        }
        n.configure(kind: kind, id: id)
        if n.root.parent == nil { actorsRoot.addChild(n.root) }
        if n.shadow.parent == nil { shadowsRoot.addChild(n.shadow) }
        return n
    }

    private func releaseGloom(_ n: GloomNode) {
        n.root.removeFromParent()
        n.shadow.removeFromParent()
        gloomPool.append(n)
    }

    private func syncGlooms(_ s: DawnSnapshot, dt: CGFloat, motion: CGFloat) {
        let f = gardenFrame
        for g in s.glooms {
            let node: GloomNode
            if let n = glooms[g.id] {
                node = n
                if n.kind != g.kind { n.configure(kind: g.kind, id: g.id) }
            } else {
                node = acquireGloom(g.kind, id: g.id)
                glooms[g.id] = node
            }
            node.seenFrame = frameIndex
            let p = f.scene(u: g.u, d: g.d)
            let r = max(CGFloat(g.radius) * f.depth * gloomScale, 4)
            // Further along d draws in front.
            node.root.zPosition = CGFloat(GardenMath.clamp(g.d, -0.5, 1.5)) * 2
            // R2: the eyes track the band (towards the light, or the crease while it's hidden there).
            let towardBand = s.band >= g.d
            let look = towardBand ? f.dUnit : CGVector(dx: -f.dUnit.dx, dy: -f.dUnit.dy)
            node.update(g, at: p, radius: r, dir: look, dt: dt, time: animTime, motion: motion)
            if node.surfacedThisFrame { fx.ripple(at: node.surfacePoint, radius: r) }
            if g.lit > 0.02 && dt > 0 {
                let lit = CGFloat(g.lit)
                node.steamClock += dt * lit * 14 * fx.density
                while node.steamClock >= 1 {
                    node.steamClock -= 1
                    fx.steam(at: node.drawnPoint, radius: r)
                }
                node.emberClock += dt * lit * 9 * fx.density
                while node.emberClock >= 1 {
                    node.emberClock -= 1
                    fx.ember(at: node.drawnPoint, radius: r)
                }
            }
            if g.kind == .wisp && node.tension > 0.5 && dt > 0 {
                node.trailClock += dt * 30 * fx.density
                while node.trailClock >= 1 {
                    node.trailClock -= 1
                    fx.trailMote(at: node.drawnPoint, size: r * 1.4, color: GardenPalette.inkMid, inky: true)
                }
            }
        }

        // Gone from the snapshot: popped (the burst already played), evaporated, eaten, or simply removed.
        scratch.removeAll(keepingCapacity: true)
        for (id, n) in glooms where n.seenFrame != frameIndex { scratch.append(id) }
        for id in scratch {
            guard let n = glooms.removeValue(forKey: id) else { continue }
            if framePopped.contains(id) {
                if n.kind == .brute {
                    // R2: hit-stop feel: the brute holds flat and white for a couple of frames over its burst.
                    n.startDeath(.squash, target: nil)
                    dyingGlooms.append(n)
                } else {
                    releaseGloom(n)
                }
                continue
            }
            if frameEvaporate || s.phase == .won {
                n.startDeath(.evaporate, target: nil)
                fx.evaporate(at: n.drawnPoint, radius: n.radiusPts)
            } else if !frameEatenLanes.isEmpty && n.lastD > 0.75 {
                let lane = GardenScene.lane(for: n.lastU, count: flowers.count)
                let target = frameEatenLanes.contains(lane) ? flowerPoint(lane) : flowerPoint(frameEatenLanes[0])
                n.startDeath(.eaten, target: target)
            } else {
                n.startDeath(.fade, target: nil)
            }
            dyingGlooms.append(n)
        }
        var i = 0
        while i < dyingGlooms.count {
            if dyingGlooms[i].updateDying(dt: dt, time: animTime) {
                i += 1
            } else {
                let n = dyingGlooms.remove(at: i)
                releaseGloom(n)
            }
        }
    }

    // MARK: Fireflies

    private func acquireFirefly(id: Int) -> GardenFirefly {
        let n: GardenFirefly
        if let last = fireflyPool.popLast() {
            n = last
        } else {
            n = GardenFirefly()
            fireflyNodesMade += 1
        }
        n.configure(id: id)
        if n.root.parent == nil { firefliesRoot.addChild(n.root) }
        return n
    }

    private func releaseFirefly(_ n: GardenFirefly) {
        n.root.removeFromParent()
        fireflyPool.append(n)
    }

    private func syncFireflies(_ s: DawnSnapshot, dt: CGFloat, motion: CGFloat) {
        let f = gardenFrame
        let size = fireflySize
        for ff in s.fireflies {
            let node: GardenFirefly
            if let n = fireflies[ff.id] {
                node = n
            } else {
                node = acquireFirefly(id: ff.id)
                fireflies[ff.id] = node
            }
            node.seenFrame = frameIndex
            node.update(ff, at: f.scene(u: ff.u, d: ff.d), size: size, dt: dt, time: animTime, motion: motion)
            // R2: a red-orange warning ring the moment the light starts scorching it.
            if node.scorch > 0.12 && !node.warned {
                node.warned = true
                fx.rings.spawn(at: node.drawnPoint, fromRadius: size * 0.8, toRadius: size * 2.8, life: 0.45,
                               color: GardenInk(hex: 0xFF7A3A).ui, alpha: 0.95)
            } else if node.scorch < 0.02 {
                node.warned = false
            }
            if dt > 0 {
                node.trailClock += dt * 16 * fx.density
                while node.trailClock >= 1 {
                    node.trailClock -= 1
                    fx.trailMote(at: node.tailPoint, size: size * 0.7, color: node.tint, inky: false)
                }
            }
        }
        scratch.removeAll(keepingCapacity: true)
        for (id, n) in fireflies where n.seenFrame != frameIndex { scratch.append(id) }
        for id in scratch {
            guard let n = fireflies.removeValue(forKey: id) else { continue }
            if frameScorched.contains(id) || frameDelivered.contains(id) {
                releaseFirefly(n)
            } else {
                n.startFade()
                dyingFireflies.append(n)
            }
        }
        var i = 0
        while i < dyingFireflies.count {
            if dyingFireflies[i].updateFade(dt: dt) {
                i += 1
            } else {
                let n = dyingFireflies.remove(at: i)
                releaseFirefly(n)
            }
        }
    }

    // MARK: Flowers

    private func syncFlowers(_ s: DawnSnapshot, dt: CGFloat, dawn: CGFloat, motion: CGFloat) {
        let n = s.flowers.count
        if n != flowers.count { rebuildFlowers(count: n) }
        guard n > 0 else { return }
        for i in 0..<laneDanger.count { laneDanger[i] = 0 }
        for g in s.glooms {
            let lane = GardenScene.lane(for: g.u, count: n)
            let k = GardenMath.smooth(0.6, 0.95, CGFloat(g.d))
            if lane < laneDanger.count && k > laneDanger[lane] { laneDanger[lane] = k }
        }
        let edgeLight = CGFloat(GardenMath.intensity(d: flowerD, band: s.band))
        let r = flowerRadius
        for (i, fl) in flowers.enumerated() {
            let want = s.flowers[i]
            if fl.standing != want {
                fl.setStanding(want, animated: true)
                if want {
                    let p = flowerPoint(i)
                    fx.rings.spawn(at: p, fromRadius: r * 0.4, toRadius: r * 2.6, life: 0.6,
                                   color: fl.color.lighter(0.4).ui, alpha: 0.9)
                    fx.petals(at: p, spread: 50, count: 5, colors: [fl.color])
                }
            }
            let danger: CGFloat = i < laneDanger.count ? laneDanger[i] : 0
            fl.update(dt: dt, time: animTime, dawn: dawn, light: edgeLight, danger: danger, motion: motion)
        }
    }

    // MARK: Light, lawn and crease

    private func drawLight(_ s: DawnSnapshot, dt: CGFloat, dawn: CGFloat, motion: CGFloat) {
        let f = gardenFrame
        let depth = f.depth
        let span = f.span
        let band = CGFloat(s.band)
        let glowIn = CGFloat(GardenMath.clamp(s.creaseGlow, 0, 1))

        // R2: the band is reflected sunlight: an additive pool (Core's intensity profile) with a cream core, a faint
        // halo, a beam from the crease that brightens towards the band, and a warm trail where the band just was.
        // All of it fades over the outer 6 % of the width and is cut exactly by cloud shades.
        let x = band * depth
        // At bandMin (−0.2) every layer is still inside the crease, under the mirror.
        let visible = band > CGFloat(GardenMath.bandMin) + 0.001
        GardenLightMath.pieces(shades: s.shades, into: &lightPieces)
        bandSwell = bandSwell > 0.01 ? bandSwell * exp(-dt * 4.5) : 0
        trailBand = GardenMath.approach(trailBand, band, rate: 3.2, dt: dt)
        let shimmer: CGFloat = motion > 0.5 ? 0.95 + 0.05 * sin(animTime * 2.3) : 1
        if visible {
            let edgeW = CGFloat(GardenMath.bandEdge) * depth * 2
            lightPool.draw(x: x, width: edgeW, anchorX: 0.5, span: span, pieces: lightPieces,
                           alpha: (0.42 + 0.18 * bandSwell) * shimmer)
            lightCore.draw(x: x, width: edgeW, anchorX: 0.5, span: span, pieces: lightPieces,
                           alpha: (0.32 + 0.04 * dawn + 0.3 * bandSwell) * shimmer)
            lightHalo.draw(x: x, width: depth * 0.4 * (1 + 0.15 * bandSwell), anchorX: 0.5, span: span,
                           pieces: lightPieces, alpha: 0.15 + 0.22 * bandSwell)
            lightBeam.draw(x: 0, width: max(x, 0), anchorX: 0, span: span, pieces: lightPieces,
                           alpha: 0.16 + 0.1 * bandSwell)
            let lag = abs(band - trailBand)
            lightTrail.draw(x: trailBand * depth, width: edgeW * 1.3, anchorX: 0.5, span: span, pieces: lightPieces,
                            alpha: GardenMath.clamp(lag / 0.12, 0, 1) * 0.32)
        } else {
            lightPool.hide()
            lightCore.hide()
            lightHalo.hide()
            lightBeam.hide()
            lightTrail.hide()
        }

        // R2: cloud shades: a cool tint over the light's path where the light is cut.
        let reach = (band + CGFloat(GardenMath.bandEdge)) * depth
        for (i, t) in shadeTints.enumerated() {
            guard visible, reach > 1, i < s.shades.count else {
                t.isHidden = true
                continue
            }
            let sh = s.shades[i]
            let k = CGFloat(GardenMath.clamp(sh.strength.isFinite ? sh.strength : 0, 0, 1))
            t.isHidden = k < 0.01
            t.position = CGPoint(x: 0, y: CGFloat(sh.u) * span)
            t.size = CGSize(width: reach / 0.85, height: max(CGFloat(max(sh.halfWidth, 0)) * 2 * span / 0.88, 2))
            t.alpha = 0.3 * k
        }

        // R2: the crease shade's cool rim brightens where the light reaches it (and stops).
        let atEdge = CGFloat(GardenMath.intensity(d: GardenMath.creaseShade, band: s.band))
        let lit = max(glowIn, band >= 0 ? 1 : 0)
        shadeRim.alpha = (0.16 + 0.5 * atEdge) * max(lit, 0.3)

        // Dawn in the crease: light pooled at the seam while the band is still hidden.
        let hidden = GardenMath.clamp(1 - (band + 0.02) / 0.15, 0, 1)
        creaseGlow.alpha = glowIn * hidden * (0.8 + 0.15 * sin(animTime * 2.1) * motion)
        seamGlow.alpha = glowIn * 0.7
        creaseInk.xScale = 1 + 0.08 * sin(animTime * 1.3) * motion
        creaseInk.alpha = 0.85 * (1 - 0.45 * dawn)

        // The lawn warms from night teal to dawn gold; a night veil lifts as the light comes in.
        groundDawn.alpha = GardenMath.smooth(0.05, 0.95, dawn)
        let lightLevel = max(glowIn, band >= 0 ? 1 : 0)
        nightVeil.alpha = 0.4 * (1 - lightLevel * 0.55) * (1 - 0.8 * dawn)

        // Dew glints where the band crosses the drops.
        for (i, sp) in dewSpots.enumerated() {
            let shaded = GardenMath.isShaded(d: sp.d)
            let k: CGFloat = shaded ? 0 : CGFloat(GardenMath.intensity(d: sp.d, band: s.band)
                                                 * GardenLightMath.factor(u: sp.u, shades: s.shades))
            let tw: CGFloat = motion > 0.5 ? max(0, sin(animTime * 2.4 + sp.phase)) : 0.6
            let a = k * (0.25 + 0.75 * tw * tw)
            let glint = dew[i]
            glint.alpha = a
            glint.isHidden = a < 0.01
            if motion > 0.5 { glint.zRotation = animTime * 0.8 + sp.phase }
        }

        // Dust motes drifting in the light.
        if band > -0.03 && band < 1.05 && dt > 0 {
            moteClock += dt * 10 * fx.density
            while moteClock >= 1 {
                moteClock -= 1
                let u = Double(rng.unit())
                let dd = s.band + Double(rng.range(-1, 1)) * GardenMath.bandCore
                if !GardenMath.isShaded(d: dd) && GardenLightMath.factor(u: u, shades: s.shades) > 0.3 {
                    fx.mote(at: f.scene(u: u, d: dd), color: GardenPalette.goldHot)
                }
            }
        }
    }

    /// R2: each cloud shade's cloud in the mirror's sky: at the shade's u, on the sun's path (a cloud over the sun is
    /// what takes that stretch of light away).
    private func placeShadeClouds(_ s: DawnSnapshot) {
        let f = gardenFrame
        let sun = mirror.sunPoint
        let behind = -((sun.x - f.origin.x) * f.dUnit.dx + (sun.y - f.origin.y) * f.dUnit.dy)
        var centers: [CGPoint] = []
        var widths: [CGFloat] = []
        var strengths: [CGFloat] = []
        for sh in s.shades.prefix(3) {
            guard sh.u.isFinite, sh.halfWidth.isFinite else { continue }
            let c = f.scene(u: sh.u, d: 0)
            centers.append(CGPoint(x: c.x - f.dUnit.dx * behind, y: c.y - f.dUnit.dy * behind))
            widths.append(CGFloat(max(sh.halfWidth, 0)) * 2 * f.span * 1.15)
            strengths.append(CGFloat(sh.strength.isFinite ? sh.strength : 0))
        }
        mirror.placeShadeClouds(centers: centers, widths: widths, strengths: strengths)
    }

    /// R2 (REVIEW-1 P0-4): one control on phones. The grip sits on the band's edge at d = band exactly (the rail's ends
    /// are bandMin and 1), and pulses until the band first moves.
    private func drawLever(_ s: DawnSnapshot, motion: CGFloat) {
        let show = showsLever && !attract
        let parts: [SKSpriteNode] = [railMirror, railGarden, gripGlow, grip]
        for n in parts { n.isHidden = !show }
        guard show else {
            gripPulsing = false
            return
        }
        let b = GardenMath.clamp(s.band.isFinite ? s.band : GardenMath.bandMin, GardenMath.bandMin, 1)
        if firstBand == nil { firstBand = b }
        let start = firstBand ?? b
        gripPulsing = abs(b - start) <= 0.02
        let p = gardenFrame.scene(u: gripU, d: b)
        grip.position = p
        gripGlow.position = p
        let pulse: CGFloat = gripPulsing ? 0.5 + 0.5 * sin(animTime * 5) : 0
        grip.setScale(1 + 0.12 * pulse * (motion > 0.5 ? 1 : 0.4))
        gripGlow.alpha = 0.22 + 0.45 * pulse
    }

    private func drawOverlays(dt: CGFloat) {
        // Sunrise: a warm flood from the mirror, settling into a glow.
        if sunriseAge >= 0 {
            sunriseAge += dt
            let a: CGFloat = sunriseAge < 0.3 ? sunriseAge / 0.3 * 0.5 : 0.5 * exp(-(sunriseAge - 0.3) * 1.3) + 0.07
            floodLevel = a * (attract ? 0.5 : 1)
            flood.isHidden = false
            flood.alpha = floodLevel
            floodRays.isHidden = false
            floodRays.position = mirror.sunPoint
            floodRays.alpha = floodLevel * 0.9
            floodRays.zRotation = animTime * 0.06 * (reduceMotion ? 0 : 1)
        } else {
            floodLevel = 0
            flood.isHidden = true
            floodRays.isHidden = true
        }

        // Night wins: darkness rolls out of the crease over the garden.
        if nightAge >= 0 {
            nightAge += dt
            let k = GardenMath.easeOut(min(nightAge / 1.8, 1))
            nightLevel = k
            let lead = k * gardenFrame.depth * 1.3
            nightRoll.isHidden = lead < 1
            nightRoll.position = CGPoint(x: lead, y: gardenFrame.span / 2)
            nightRoll.size = CGSize(width: max(lead, 1), height: gardenFrame.span)
            nightRoll.alpha = 0.88
        } else {
            nightLevel = 0
            nightRoll.isHidden = true
        }
    }

    // MARK: Touches (the drag fallback; the App ignores them on a Duo)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragTouch == nil, let t = touches.first else { return }
        dragTouch = ObjectIdentifier(t)
        driver?.dragBegan(swiftUIPoint(fromScene: t.location(in: self)))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let id = dragTouch, let t = touches.first(where: { ObjectIdentifier($0) == id }) else { return }
        driver?.dragMoved(swiftUIPoint(fromScene: t.location(in: self)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(touches)
    }

    private func finishTouch(_ touches: Set<UITouch>) {
        guard let id = dragTouch, touches.contains(where: { ObjectIdentifier($0) == id }) else { return }
        dragTouch = nil
        driver?.dragEnded()
    }

    // MARK: Helpers

    private static func countNodes(_ n: SKNode, visibleOnly: Bool) -> Int {
        if visibleOnly && (n.isHidden || n.alpha <= 0.001) { return 0 }
        var c = 1
        for k in n.children { c += countNodes(k, visibleOnly: visibleOnly) }
        return c
    }
}
