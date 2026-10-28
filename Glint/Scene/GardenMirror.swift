import SpriteKit
import UIKit

/// The mirror half: a brass-framed mirror showing the dawn sky. The sun rises with the level (`dawn` 0 → 1), clouds
/// drift, the horizon is the world's (meadow hills, rooftops, a harbour), a shaft of light falls towards the crease,
/// and the reflection shifts a little with the band. On phones (`lever`) a brass lever follows the band.
///
/// Drawn upright in scene points (sky up = the screen's up) whatever the layout; `towardCrease` says which side of
/// the mirror meets the garden.
@MainActor
final class GardenMirror {
    let root = SKNode()
    private let crop = SKCropNode()
    private let mask = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 4))
    /// The reflected scene (shifts with the band).
    private let content = SKNode()
    private let skyNight = SKSpriteNode()
    private let skyDawn = SKSpriteNode()
    private let skyDay = SKSpriteNode()
    private let sunGlow = SKSpriteNode()
    private let sunRays = SKSpriteNode()
    private let sun = SKSpriteNode()
    private let glint = SKSpriteNode()
    private let shaft = SKSpriteNode()
    /// R2: the warm spot on the glass where the light leaves for the garden.
    private let hotSpot = SKSpriteNode()
    private let vignette = SKSpriteNode()
    private let sheen = SKSpriteNode()
    private let shine = SKSpriteNode()
    private let veil = SKSpriteNode(color: .black, size: CGSize(width: 4, height: 4))
    private let leverTrack = SKSpriteNode()
    private let leverKnob = SKSpriteNode()
    private let leverGlow = SKSpriteNode()
    private var stars: [SKSpriteNode] = []
    private var starSpots: [CGPoint] = []
    private var starPhase: [CGFloat] = []
    private var clouds: [SKSpriteNode] = []
    /// R2: the clouds that cast the band's shades (one per `ShadeState`, placed by the scene).
    private var shadeClouds: [SKSpriteNode] = []
    private var cloudX: [CGFloat] = []
    private var cloudY: [CGFloat] = []
    private var cloudSpeed: [CGFloat] = []
    private var cloudScale: [CGFloat] = []
    private var far: [SKSpriteNode] = []
    private var near: [SKSpriteNode] = []
    private var lamps: [SKSpriteNode] = []
    private var flares: [SKSpriteNode] = []
    private var edges: [SKSpriteNode] = []
    private var corners: [SKSpriteNode] = []

    /// The mirror's whole rect and the glass inside the frame (scene points).
    private(set) var outer: CGRect = .zero
    private(set) var inner: CGRect = .zero
    private var toward = CGVector(dx: 0, dy: -1)
    private var hillsHeight: CGFloat = 0
    private var tileWidth: CGFloat = 0
    private var frameThickness: CGFloat = 12
    private(set) var world: Int = 1
    /// The sun's centre as drawn (scene points) and its radius.
    private(set) var sunPoint: CGPoint = .zero
    private(set) var sunRadius: CGFloat = 20
    /// R2: the sun's glint as drawn (its side, points) and the glass's hot spot (scene points).
    var glintSize: CGFloat { glint.size.width }
    private(set) var hotSpotPoint: CGPoint = .zero
    /// The lever's knob as drawn (scene points).
    private(set) var leverPoint: CGPoint = .zero
    private var leverFar: CGPoint = .zero
    private var leverNear: CGPoint = .zero
    private var shineClock: CGFloat = 0
    private var tintKey: Int = -1

    var leverShowing: Bool { !leverKnob.isHidden }

    static let tiles = 4

    init() {
        root.addChild(crop)
        crop.maskNode = mask
        crop.zPosition = 0
        crop.addChild(content)

        let skies: [(SKSpriteNode, Int)] = [(skyNight, 0), (skyDawn, 1), (skyDay, 2)]
        for (n, i) in skies {
            n.texture = MirrorArt.sky(i)
            n.zPosition = CGFloat(i) * 0.1
            content.addChild(n)
        }
        var rng = GardenRNG(seed: 0x57A2)
        for i in 0..<16 {
            let s = SKSpriteNode(texture: i % 3 == 0 ? GardenArt.sparkle : GardenArt.dot)
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.color = GardenInk(hex: 0xFFF6E0).ui
            s.zPosition = 0.3
            content.addChild(s)
            stars.append(s)
            starSpots.append(CGPoint(x: rng.range(0.04, 0.96), y: rng.range(0.4, 0.97)))
            starPhase.append(rng.range(0, 6.28))
        }
        sunRays.texture = GardenArt.rays
        sunRays.blendMode = .add
        sunRays.colorBlendFactor = 1
        sunRays.zPosition = 0.4
        sunGlow.texture = GardenArt.glow
        sunGlow.blendMode = .add
        sunGlow.colorBlendFactor = 1
        sunGlow.zPosition = 0.45
        sun.texture = MirrorArt.sunDisc
        sun.colorBlendFactor = 0
        sun.zPosition = 0.5
        for n in [sunRays, sunGlow, sun] { content.addChild(n) }
        for i in 0..<4 {
            let c = SKSpriteNode(texture: MirrorArt.cloud(i))
            c.colorBlendFactor = 0.5
            c.zPosition = 0.6 + CGFloat(i) * 0.01
            content.addChild(c)
            clouds.append(c)
            cloudX.append(rng.range(0, 1))
            cloudY.append(rng.range(0.35, 0.85))
            cloudSpeed.append(rng.range(0.006, 0.014))
            cloudScale.append(rng.range(0.7, 1.15))
        }
        for i in 0..<3 {
            let c = SKSpriteNode(texture: MirrorArt.cloud(i + 1))
            c.colorBlendFactor = 0.62
            c.color = GardenInk(hex: 0x6A76A6).ui
            c.zPosition = 0.7 + CGFloat(i) * 0.01
            c.isHidden = true
            content.addChild(c)
            shadeClouds.append(c)
        }
        for i in 0..<GardenMirror.tiles {
            let f = SKSpriteNode()
            f.anchorPoint = .zero
            f.colorBlendFactor = 1
            f.zPosition = 1.0
            content.addChild(f)
            far.append(f)
            let lamp = SKSpriteNode(texture: GardenArt.glow)
            lamp.blendMode = .add
            lamp.colorBlendFactor = 1
            lamp.color = GardenInk(hex: 0xFFE08A).ui
            lamp.zPosition = 1.05
            lamp.isHidden = true
            content.addChild(lamp)
            lamps.append(lamp)
            let n = SKSpriteNode()
            n.anchorPoint = .zero
            n.colorBlendFactor = 1
            n.zPosition = 1.1 + CGFloat(i) * 0.001
            content.addChild(n)
            near.append(n)
        }
        shaft.texture = MirrorArt.shaft
        shaft.blendMode = .add
        shaft.colorBlendFactor = 1
        shaft.anchorPoint = CGPoint(x: 0.5, y: 1)
        shaft.zPosition = 1.2
        content.addChild(shaft)
        for i in 0..<2 {
            let fl = SKSpriteNode(texture: i == 0 ? GardenArt.ring : GardenArt.glow)
            fl.blendMode = .add
            fl.colorBlendFactor = 1
            fl.zPosition = 1.3
            content.addChild(fl)
            flares.append(fl)
        }
        glint.texture = MirrorArt.crossFlare
        glint.blendMode = .add
        glint.colorBlendFactor = 1
        glint.color = GardenInk(hex: 0xFFFBE8).ui
        glint.zPosition = 1.4
        content.addChild(glint)

        // On the glass (not reflected, so not shifted).
        vignette.texture = GardenArt.vignette
        vignette.colorBlendFactor = 1
        vignette.color = GardenInk(hex: 0x1B0E26).ui
        vignette.alpha = 0.55
        vignette.zPosition = 2
        sheen.texture = MirrorArt.sheen
        sheen.blendMode = .add
        sheen.alpha = 0.09
        sheen.zPosition = 2.1
        shine.texture = MirrorArt.sheen
        shine.blendMode = .add
        shine.alpha = 0
        shine.zPosition = 2.15
        veil.color = GardenPalette.night.ui
        veil.alpha = 0
        veil.zPosition = 2.2
        hotSpot.texture = GardenArt.glow
        hotSpot.blendMode = .add
        hotSpot.colorBlendFactor = 1
        hotSpot.color = GardenInk(hex: 0xFFD98A).ui
        hotSpot.alpha = 0
        hotSpot.zPosition = 2.12
        for n in [vignette, sheen, shine, hotSpot, veil] { crop.addChild(n) }

        // The frame (over the glass).
        for i in 0..<4 {
            let e = SKSpriteNode(texture: MirrorArt.frameEdge)
            e.zPosition = 3 + CGFloat(i) * 0.001
            root.addChild(e)
            edges.append(e)
        }
        for i in 0..<4 {
            let c = SKSpriteNode(texture: MirrorArt.frameCorner)
            c.zPosition = 3.1
            c.zRotation = CGFloat(i) * CGFloat.pi / 2
            root.addChild(c)
            corners.append(c)
        }

        // The phone fallback's lever.
        leverTrack.texture = MirrorArt.leverTrack
        leverTrack.zPosition = 4
        leverGlow.texture = GardenArt.glow
        leverGlow.blendMode = .add
        leverGlow.colorBlendFactor = 1
        leverGlow.color = GardenPalette.gold.ui
        leverGlow.zPosition = 4.05
        leverKnob.texture = MirrorArt.leverKnob
        leverKnob.zPosition = 4.1
        for n in [leverTrack, leverGlow, leverKnob] {
            n.isHidden = true
            root.addChild(n)
        }
        setWorld(1)
    }

    /// R2: places the shade-casting clouds: `centers` in scene points (on the sun's path, at the shade's u), each
    /// `widths[i]` wide, `strengths[i]` 0…1 (how dark). Extra clouds hide.
    func placeShadeClouds(centers: [CGPoint], widths: [CGFloat], strengths: [CGFloat]) {
        for (i, c) in shadeClouds.enumerated() {
            guard i < centers.count, i < widths.count, i < strengths.count else {
                c.isHidden = true
                continue
            }
            let w = GardenMath.clamp(widths[i], 70, max(inner.width * 0.95, 70))
            c.isHidden = false
            c.size = CGSize(width: w, height: w * 110 / 240)
            c.position = CGPoint(x: centers[i].x - content.position.x, y: centers[i].y - content.position.y)
            c.alpha = 0.55 + 0.45 * GardenMath.clamp(strengths[i], 0, 1)
        }
    }

    /// The shade clouds on screen now.
    var shadeCloudCount: Int { shadeClouds.filter { !$0.isHidden }.count }

    /// The world's horizon (1 Meadow, 2 Rooftops, 3 Harbour).
    func setWorld(_ w: Int) {
        let k = min(max(w, 1), 3)
        world = k
        let ft = MirrorArt.hills(world: k, near: false)
        let nt = MirrorArt.hills(world: k, near: true)
        for f in far { f.texture = ft }
        for n in near { n.texture = nt }
        for l in lamps { l.isHidden = k != 3 }
        tintKey = -1
    }

    /// Places the mirror in `rect` (scene points); `towardCrease`: the unit vector from the mirror to the garden.
    func apply(rect: CGRect, towardCrease: CGVector) {
        outer = rect
        toward = towardCrease
        let t = GardenMath.clamp(min(rect.width, rect.height) * 0.045, 9, 22)
        frameThickness = t
        let inset = t * 0.82
        inner = rect.insetBy(dx: min(inset, rect.width / 3), dy: min(inset, rect.height / 3))
        let margin: CGFloat = 14
        let skySize = CGSize(width: inner.width + margin * 2, height: inner.height + margin * 2)
        let mid = CGPoint(x: inner.midX, y: inner.midY)
        mask.size = inner.size
        mask.position = mid
        for n in [skyNight, skyDawn, skyDay] {
            n.size = skySize
            n.position = mid
        }
        for n in [vignette, sheen, veil] {
            n.size = inner.size
            n.position = mid
        }
        shine.size = CGSize(width: inner.width * 0.6, height: inner.height)

        // The horizon: tiles of the world's silhouettes along the bottom of the glass.
        var hh = min(inner.height * 0.27, inner.width * 0.34)
        var tw = hh * MirrorArt.hillsSize.width / MirrorArt.hillsSize.height
        let needed = inner.width + margin * 2
        if tw * CGFloat(GardenMirror.tiles - 1) < needed {
            tw = needed / CGFloat(GardenMirror.tiles - 1)
            hh = tw * MirrorArt.hillsSize.height / MirrorArt.hillsSize.width
        }
        hillsHeight = hh
        tileWidth = tw
        for i in 0..<GardenMirror.tiles {
            let x = inner.minX - margin + CGFloat(i) * (tw - 1)
            far[i].size = CGSize(width: tw, height: hh)
            far[i].position = CGPoint(x: x - tw * 0.37, y: inner.minY - margin * 0.5)
            near[i].size = CGSize(width: tw, height: hh * 0.82)
            near[i].position = CGPoint(x: x, y: inner.minY - margin)
            let lf = MirrorArt.lampFraction
            lamps[i].position = CGPoint(x: far[i].position.x + tw * lf.x, y: far[i].position.y + hh * lf.y)
            lamps[i].size = CGSize(width: hh * 0.32, height: hh * 0.32)
        }
        let starSize = max(min(inner.width, inner.height) * 0.018, 3)
        for (i, s) in stars.enumerated() {
            let sp = starSpots[i]
            s.position = CGPoint(x: inner.minX + sp.x * inner.width, y: inner.minY + sp.y * inner.height)
            let k: CGFloat = i % 3 == 0 ? 2.4 : 1
            s.size = CGSize(width: starSize * k, height: starSize * k)
        }
        for (i, c) in clouds.enumerated() {
            let w = max(inner.width * 0.42, 80) * cloudScale[i]
            c.size = CGSize(width: w, height: w * 110 / 240)
        }
        sunRadius = max(min(inner.width, inner.height) * 0.1, 10)

        // The frame: four mouldings and four bosses.
        let ot = t
        edges[0].size = CGSize(width: rect.width, height: ot)
        edges[0].position = CGPoint(x: rect.midX, y: rect.minY + ot / 2)
        edges[0].zRotation = 0
        edges[1].size = CGSize(width: rect.width, height: ot)
        edges[1].position = CGPoint(x: rect.midX, y: rect.maxY - ot / 2)
        edges[1].zRotation = CGFloat.pi
        edges[2].size = CGSize(width: rect.height, height: ot)
        edges[2].position = CGPoint(x: rect.minX + ot / 2, y: rect.midY)
        edges[2].zRotation = -CGFloat.pi / 2
        edges[3].size = CGSize(width: rect.height, height: ot)
        edges[3].position = CGPoint(x: rect.maxX - ot / 2, y: rect.midY)
        edges[3].zRotation = CGFloat.pi / 2
        let cs = ot * 1.9
        let cornerPoints: [CGPoint] = [CGPoint(x: rect.minX + ot / 2, y: rect.minY + ot / 2),
                                       CGPoint(x: rect.maxX - ot / 2, y: rect.minY + ot / 2),
                                       CGPoint(x: rect.maxX - ot / 2, y: rect.maxY - ot / 2),
                                       CGPoint(x: rect.minX + ot / 2, y: rect.maxY - ot / 2)]
        for (i, c) in corners.enumerated() {
            c.size = CGSize(width: cs, height: cs)
            c.position = cornerPoints[i]
        }

        // The lever's slot runs along the fold-normal axis, at the side of the glass.
        let tc = toward
        let alongExtent = abs(tc.dx) > 0.5 ? inner.width : inner.height
        let acrossExtent = abs(tc.dx) > 0.5 ? inner.height : inner.width
        let perp = CGVector(dx: -tc.dy, dy: tc.dx)
        let side = acrossExtent / 2 - max(30, acrossExtent * 0.08)
        // The far end stops well short of the glass's far corner (room for the App's corner plate there).
        let nearMargin = max(34, alongExtent * 0.12)
        let farMargin = nearMargin + 64
        let len = max(alongExtent - nearMargin - farMargin, 40)
        let slide = (farMargin - nearMargin) / 2
        let c0 = CGPoint(x: mid.x + perp.dx * side + tc.dx * slide, y: mid.y + perp.dy * side + tc.dy * slide)
        leverFar = CGPoint(x: c0.x - tc.dx * len / 2, y: c0.y - tc.dy * len / 2)
        leverNear = CGPoint(x: c0.x + tc.dx * len / 2, y: c0.y + tc.dy * len / 2)
        leverTrack.size = CGSize(width: 20, height: len + 26)
        leverTrack.position = c0
        leverTrack.zRotation = atan2(-tc.dx, tc.dy)
        let ks = GardenMath.clamp(min(inner.width, inner.height) * 0.13, 40, 60)
        leverKnob.size = CGSize(width: ks, height: ks)
        leverGlow.size = CGSize(width: ks * 2.2, height: ks * 2.2)
    }

    private static func skyTint(_ dawn: CGFloat) -> (GardenInk, CGFloat, GardenInk, GardenInk) {
        // (cloud tint, cloud blend, far hills, near hills)
        let nightCloud = GardenInk(hex: 0x48477E)
        let dawnCloud = GardenInk(hex: 0xFFB2A0)
        let dayCloud = GardenInk.white
        let farNight = GardenInk(hex: 0x2B2B60)
        let farDawn = GardenInk(hex: 0x8A5A8E)
        let farDay = GardenInk(hex: 0x8CB4D6)
        let nearNight = GardenInk(hex: 0x131534)
        let nearDawn = GardenInk(hex: 0x472C58)
        let nearDay = GardenInk(hex: 0x4A7C9E)
        if dawn < 0.45 {
            let k = dawn / 0.45
            return (nightCloud.mixed(dawnCloud, k), 0.75 - 0.25 * k, farNight.mixed(farDawn, k),
                    nearNight.mixed(nearDawn, k))
        }
        let k = (dawn - 0.45) / 0.55
        return (dawnCloud.mixed(dayCloud, k), 0.5 - 0.42 * k, farDawn.mixed(farDay, k), nearDawn.mixed(nearDay, k))
    }

    /// One frame. `dawn` 0…1 (the sun's climb), `band` the band (d), `light` 0…1 (how much light the mirror is
    /// throwing), `veilLevel` 0…1 (night wins), `lever`/`leverT` the phone fallback's lever and its 0…1 travel.
    func update(dt: CGFloat, time: CGFloat, dawn: CGFloat, band: CGFloat, light: CGFloat, veilLevel: CGFloat,
                lever: Bool, leverT: CGFloat, motion: CGFloat) {
        guard inner.width > 1, inner.height > 1 else { return }
        let d = GardenMath.clamp(dawn, 0, 1)

        // The sky's three gradients.
        skyDawn.alpha = GardenMath.smooth(0.02, 0.45, d)
        skyDay.alpha = GardenMath.smooth(0.45, 0.95, d)

        // The reflection shifts with the band (towards the crease as the phone opens).
        let shiftK = (GardenMath.clamp(band, -0.2, 1) - 0.4) * 7
        content.position = CGPoint(x: toward.dx * shiftK, y: toward.dy * shiftK)

        // The sun: half-hidden on the horizon at 0, high and bright at 1.
        let horizon = inner.minY + hillsHeight * 0.5
        let top = inner.maxY - inner.height * 0.2
        let climb = pow(d, 0.85)
        let r = sunRadius * (1.15 - 0.2 * d)
        sunPoint = CGPoint(x: inner.midX + inner.width * 0.12, y: horizon - r * 0.35 + climb * max(top - horizon, 0))
        sun.position = sunPoint
        sun.size = CGSize(width: r * 2, height: r * 2)
        sun.colorBlendFactor = 0.55 * (1 - d)
        sun.color = GardenInk(hex: 0xFF5A36).ui
        sunGlow.position = sunPoint
        sunGlow.size = CGSize(width: r * 7.5, height: r * 7.5)
        sunGlow.color = GardenInk(hex: 0xFF7A45).mixed(GardenInk(hex: 0xFFE6A8), d).ui
        sunGlow.alpha = 0.55 + 0.3 * d
        sunRays.position = sunPoint
        sunRays.size = CGSize(width: r * 9, height: r * 9)
        sunRays.color = GardenInk(hex: 0xFFC27A).mixed(GardenInk(hex: 0xFFF2C8), d).ui
        sunRays.alpha = 0.18 + 0.32 * d
        sunRays.zRotation = time * 0.05 * motion
        // R2: a small soft cross flare on the sun's upper-left rim, slowly twinkling (not a star over the sun).
        let gp: CGFloat = motion > 0.5 ? 0.5 + 0.5 * sin(time * 1.3) : 0.5
        glint.position = CGPoint(x: sunPoint.x - r * 0.42, y: sunPoint.y + r * 0.42)
        let gs = r * (1.0 + 0.14 * gp)
        glint.size = CGSize(width: gs, height: gs)
        glint.alpha = (0.32 + 0.22 * gp) * (0.6 + 0.4 * light)
        glint.zRotation = 0.2 + sin(time * 0.4) * 0.12 * motion

        // Lens flares along the line from the sun through the glass's centre.
        let cx = inner.midX - sunPoint.x
        let cy = inner.midY - sunPoint.y
        for (i, fl) in flares.enumerated() {
            let k: CGFloat = i == 0 ? 1.45 : 1.9
            fl.position = CGPoint(x: sunPoint.x + cx * k, y: sunPoint.y + cy * k)
            let fs = r * (i == 0 ? 1.3 : 0.8)
            fl.size = CGSize(width: fs, height: fs)
            fl.color = GardenInk(hex: 0xFFD9A0).ui
            fl.alpha = (i == 0 ? 0.06 : 0.09) * light * (0.4 + 0.6 * d)
        }

        // A shaft of light from the sun to the crease (brighter as the phone opens).
        let target = CGPoint(x: abs(toward.dx) > 0.5 ? inner.midX + toward.dx * inner.width / 2 : sunPoint.x,
                             y: abs(toward.dy) > 0.5 ? inner.midY + toward.dy * inner.height / 2 : inner.midY)
        let vx = target.x - sunPoint.x
        let vy = target.y - sunPoint.y
        let len = max(sqrt(vx * vx + vy * vy), 1)
        shaft.position = sunPoint
        shaft.zRotation = atan2(vx, -vy)
        shaft.size = CGSize(width: r * 3.2, height: len)
        shaft.color = GardenInk(hex: 0xFFD27A).ui
        shaft.alpha = 0.24 * light

        // R2: a hot spot on the glass where the light leaves the mirror for the garden.
        hotSpotPoint = target
        hotSpot.position = target
        hotSpot.size = CGSize(width: max(r * 5.5, 40), height: max(r * 1.4, 12))
        hotSpot.zRotation = atan2(toward.dx, -toward.dy)
        let breathe: CGFloat = motion > 0.5 ? 0.9 + 0.1 * sin(time * 1.7) : 1
        hotSpot.alpha = 0.42 * light * breathe

        // Stars fade as the sun climbs; they twinkle.
        let starK = 1 - GardenMath.smooth(0.0, 0.45, d)
        for (i, s) in stars.enumerated() {
            let tw: CGFloat = motion > 0.5 ? 0.55 + 0.45 * sin(time * 2.3 + starPhase[i]) : 0.8
            s.alpha = starK * tw * 0.9
            s.isHidden = starK < 0.01
        }

        // Clouds drift and wrap; tinted by the hour.
        let tints = GardenMirror.skyTint(d)
        let tk = Int(d * 40)
        let retint = tk != tintKey
        tintKey = tk
        let skyH = max(inner.maxY - horizon, 1)
        for (i, c) in clouds.enumerated() {
            cloudX[i] += cloudSpeed[i] * dt * (0.35 + 0.65 * motion)
            if cloudX[i] > 1.25 { cloudX[i] -= 1.5 }
            let x = inner.minX - c.size.width / 2 + cloudX[i] * (inner.width + c.size.width)
            c.position = CGPoint(x: x, y: horizon + skyH * cloudY[i])
            if retint {
                c.color = tints.0.ui
                c.colorBlendFactor = tints.1
            }
        }
        if retint {
            for f in far { f.color = tints.2.ui }
            for n in near { n.color = tints.3.ui }
        }
        // The lighthouse's lamp glows before dawn.
        if world == 3 {
            let lampK = (1 - GardenMath.smooth(0.3, 0.8, d)) * (0.7 + 0.3 * sin(time * 2.0))
            for l in lamps { l.alpha = lampK }
        }

        // A slow shine sweeps across the glass now and then.
        if motion > 0.5 {
            shineClock += dt
            let period: CGFloat = 7
            if shineClock > period { shineClock -= period }
            let k = shineClock / 1.3
            if k < 1 {
                shine.isHidden = false
                shine.position = CGPoint(x: inner.minX - inner.width * 0.4 + k * inner.width * 1.8, y: inner.midY)
                shine.alpha = 0.16 * sin(k * CGFloat.pi)
            } else {
                shine.isHidden = true
            }
        } else {
            shine.isHidden = true
        }
        veil.alpha = GardenMath.clamp(veilLevel, 0, 1) * 0.6

        // The lever.
        for n in [leverTrack, leverGlow, leverKnob] { n.isHidden = !lever }
        if lever {
            let tt = GardenMath.clamp(leverT, 0, 1)
            leverPoint = CGPoint(x: leverFar.x + (leverNear.x - leverFar.x) * tt,
                                 y: leverFar.y + (leverNear.y - leverFar.y) * tt)
            leverKnob.position = leverPoint
            leverGlow.position = leverPoint
            leverGlow.alpha = 0.25 + 0.35 * light
        }
    }
}
