import CoreGraphics
import Foundation
import SpriteKit
import Testing
import UIKit
@testable import Glint

/// A scripted driver: hands the scene a fixed snapshot (and one batch of events), records drags.
@MainActor
final class SceneFakeDriver: GardenDriver {
    var snapshot = DawnSnapshot(mode: .level(1))
    var events: [GameEvent] = []
    var advances = 0
    var drags: [String] = []
    var points: [CGPoint] = []

    func advance(dt: Double, now: TimeInterval) -> (DawnSnapshot, [GameEvent]) {
        advances += 1
        let e = events
        events = []
        return (snapshot, e)
    }

    func dragBegan(_ p: CGPoint) {
        drags.append("began")
        points.append(p)
    }

    func dragMoved(_ p: CGPoint) {
        drags.append("moved")
        points.append(p)
    }

    func dragEnded() { drags.append("ended") }
}

/// Scene module tests: the floor ↔ canvas mapping in all four layouts, the band profile, the texture cache (a warm
/// frame loop builds nothing), node pooling, event FX, sunrise / night, the lever, the sun, re-layout, the budget.
@MainActor
struct SceneTests {
    static let step: Double = 1.0 / 120.0

    /// Phone portrait, a laptop Duo with the halves swapped, a book Duo both ways round.
    static let layouts: [GardenLayout] = [
        GardenLayout(size: CGSize(width: 393, height: 852), foldVertical: false, gardenAfter: true, gardenFraction: 0.58),
        GardenLayout(size: CGSize(width: 900, height: 1100), foldVertical: false, gardenAfter: false, gardenFraction: 0.5),
        GardenLayout(size: CGSize(width: 1100, height: 900), foldVertical: true, gardenAfter: true, gardenFraction: 0.5),
        GardenLayout(size: CGSize(width: 1100, height: 900), foldVertical: true, gardenAfter: false, gardenFraction: 0.5)
    ]

    static let samples: [(Double, Double)] = [(0, 0), (1, 0), (0, 1), (1, 1), (0.5, 0.5), (0.25, 0.8), (0.7, -0.1)]

    static func gloom(_ id: Int, _ kind: GloomKind, u: Double, d: Double, lit: Double = 0) -> GloomState {
        GloomState(id: id, kind: kind, u: u, d: d, radius: 0.045, hp: 0.5, maxHP: 0.55, lit: lit, age: 1)
    }

    static func playing(_ mode: PlayMode = .level(3)) -> DawnSnapshot {
        var s = DawnSnapshot(mode: mode, phase: .playing)
        s.band = 0.4
        s.creaseGlow = 1
        s.time = 5
        return s
    }

    static func near(_ a: CGPoint, _ b: CGPoint, _ tol: CGFloat = 0.01) -> Bool {
        abs(a.x - b.x) < tol && abs(a.y - b.y) < tol
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    /// sRGB luma (0.299 R + 0.587 G + 0.114 B), 0…1.
    static func luma(_ c: GardenInk) -> Double { Double(0.299 * c.r + 0.587 * c.g + 0.114 * c.b) }

    /// An image's RGBA8 pixels (premultiplied; the grounds are opaque).
    static func pixels(_ img: CGImage) -> (data: [UInt8], w: Int, h: Int)? {
        let w = img.width
        let h = img.height
        guard w > 0, h > 0 else { return nil }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = data.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (data, w, h) : nil
    }

    /// The mean luma of each pixel column (the canonical ground's x = d), over the middle 60 % of its rows.
    static func columnLuma(_ img: CGImage) -> [Double]? {
        guard let px = pixels(img) else { return nil }
        var out: [Double] = []
        for x in 0..<px.w {
            var sum = 0.0
            var n = 0.0
            var y = px.h / 5
            while y < px.h * 4 / 5 {
                let i = (y * px.w + x) * 4
                sum += (0.299 * Double(px.data[i]) + 0.587 * Double(px.data[i + 1]) + 0.114 * Double(px.data[i + 2])) / 255
                n += 1
                y += 2
            }
            out.append(n > 0 ? sum / n : 0)
        }
        return out
    }

    /// The share of pixels that read as blue (B above both R and G by > 25 of 255).
    static func blueShare(_ img: CGImage) -> Double? {
        guard let px = pixels(img) else { return nil }
        var blue = 0.0
        var n = 0.0
        var i = 0
        while i + 3 < px.data.count {
            let r = Int(px.data[i])
            let g = Int(px.data[i + 1])
            let b = Int(px.data[i + 2])
            if b - max(r, g) > 25 { blue += 1 }
            n += 1
            i += 12
        }
        return n > 0 ? blue / n : nil
    }

    // MARK: Mapping

    @Test func gardenFrameMatchesTheLayoutInAllFourLayouts() {
        for layout in SceneTests.layouts {
            let f = GardenFrame(layout: layout)
            for (u, d) in SceneTests.samples {
                let want = layout.scenePoint(layout.point(u: u, d: d))
                let lx = CGFloat(d) * f.depth
                let ly = CGFloat(u) * f.span * f.uFlip
                let got = CGPoint(x: f.origin.x + lx * cos(f.dAngle) - ly * sin(f.dAngle),
                                  y: f.origin.y + lx * sin(f.dAngle) + ly * cos(f.dAngle))
                #expect(SceneTests.near(got, want))
                #expect(SceneTests.near(f.scene(u: u, d: d), want))
            }
            // +d points from the mirror into the garden.
            let g = f.gardenRect
            let m = f.mirrorRect
            let towards = CGVector(dx: g.midX - m.midX, dy: g.midY - m.midY)
            #expect(towards.dx * f.dUnit.dx + towards.dy * f.dUnit.dy > 0)
        }
    }

    @Test func gardenNodeConvertsFloorPointsInEveryLayout() {
        for layout in SceneTests.layouts {
            let scene = GardenScene(layout: layout)
            for (u, d) in SceneTests.samples {
                let want = layout.scenePoint(layout.point(u: u, d: d))
                let local = scene.gardenFrame.local(u: u, d: d)
                let got = scene.gardenNode.convert(local, to: scene)
                #expect(SceneTests.near(got, want, 0.05))
                #expect(SceneTests.near(scene.scenePoint(u: u, d: d), want))
            }
        }
    }

    @Test func floorPointsRoundTripThroughSwiftUISpace() {
        for layout in SceneTests.layouts {
            let scene = GardenScene(layout: layout)
            for (u, d) in SceneTests.samples {
                let p = scene.swiftUIPoint(fromScene: scene.scenePoint(u: u, d: d))
                let back = layout.floorPoint(at: p)
                #expect(abs(back.u - u) < 0.0001)
                #expect(abs(back.d - d) < 0.0001)
            }
        }
        let phone = GardenScene(layout: SceneTests.layouts[0])
        let p = phone.swiftUIPoint(fromScene: CGPoint(x: 10, y: 800))
        #expect(abs(p.x - 10) < 0.001 && abs(p.y - 52) < 0.001)
    }

    @Test func flowerRectsSitInsideTheGardenAtTheFlowerEdge() {
        for layout in SceneTests.layouts {
            let rects = GardenScene.flowerRects(layout: layout)
            #expect(rects.count == 5)
            let garden = layout.gardenRect.insetBy(dx: -0.5, dy: -0.5)
            for (i, r) in rects.enumerated() {
                #expect(garden.contains(r))
                let f = layout.floorPoint(at: CGPoint(x: r.midX, y: r.midY))
                #expect(abs(f.u - (Double(i) + 0.5) / 5) < 0.0001)
                #expect(f.d > 0.85 && f.d < 1)
                if i > 0 { #expect(!r.intersects(rects[i - 1].insetBy(dx: 2, dy: 2))) }
            }
        }
    }

    @Test func bandProfileMatchesTheDesign() {
        // R3: the widths come from Core's Tuning (whatever they are tuned to).
        let core = GardenMath.bandCore
        let edge = GardenMath.bandEdge
        #expect(core > 0 && edge > core)
        #expect(abs(GardenMath.intensity(d: 0.5, band: 0.5) - 1) < 0.0001)
        #expect(abs(GardenMath.intensity(d: 0.5 + core - 0.001, band: 0.5) - 1) < 0.0001)
        #expect(GardenMath.intensity(d: 0.5 + edge + 0.001, band: 0.5) < 0.0001)
        #expect(GardenMath.intensity(d: 0.5 - edge - 0.001, band: 0.5) < 0.0001)
        let mid = GardenMath.intensity(d: 0.5 + (core + edge) / 2, band: 0.5)
        #expect(abs(mid - 0.5) < 0.01)
        // The drawn pool has no hard edge: it runs on past the edge by the feather and is ~0 by edge + feather.
        #expect(GardenArt.poolValue(distance: 0) > 0.999)
        #expect(GardenArt.poolValue(distance: edge) > 0.05)
        #expect(GardenArt.poolValue(distance: edge + GardenMath.bandFeather) < 0.001)
        var last = 1.0
        for i in 0...20 {
            let v = GardenMath.intensity(d: 0.5 + Double(i) * 0.005, band: 0.5)
            #expect(v <= last + 0.000_001)
            last = v
        }
    }

    @Test func worldsAndDawnFollowTheMode() {
        #expect(GardenMath.world(for: .level(1)) == 1)
        #expect(GardenMath.world(for: .level(10)) == 1)
        #expect(GardenMath.world(for: .level(11)) == 2)
        #expect(GardenMath.world(for: .level(21)) == 3)
        #expect(GardenMath.world(for: .level(30)) == 3)
        #expect(GardenMath.world(for: .endless) == 1)
        #expect(GardenMath.world(for: .daily(day: 40)) == 1)
        for n in 1...30 { #expect(GardenMath.world(for: .level(n)) == LevelBook.world(of: n)) }
        var s = DawnSnapshot(mode: .level(4))
        s.sun = 0.6
        #expect(abs(GardenMath.dawn(s) - 0.6) < 0.0001)
        var e = DawnSnapshot(mode: .endless)
        e.sun = 0
        #expect(abs(GardenMath.dawn(e) - 0.3) < 0.0001)
        e.sun = 1
        #expect(GardenMath.dawn(e) < 0.0001)
    }

    @Test func gloomLooksFitTheirCanvas() {
        for k in GloomKind.allCases {
            let look = GloomLook.of(k)
            #expect(look.eyes.count == look.eyeSides.count)
            #expect(!look.eyes.isEmpty && !look.mouths.isEmpty)
            #expect(look.anchor.x > 0 && look.anchor.x < 1 && look.anchor.y > 0 && look.anchor.y < 1)
            for e in look.eyes {
                #expect(look.center.x + e.x - look.eyeRadius > 0)
                #expect(look.center.x + e.x + look.eyeRadius < look.canvas.width)
                #expect(abs(e.y - look.eyeY) < 0.0001)
            }
            #expect(look.hasBrow == (k == .brute))
        }
    }

    // MARK: R2: light, shade, clouds

    @Test func cloudShadesCutTheLightExactly() {
        let shades = [ShadeState(id: 1, u: 0.4, halfWidth: 0.1, strength: 1),
                      ShadeState(id: 2, u: 0.75, halfWidth: 0.08, strength: 0.5)]
        #expect(GardenLightMath.factor(u: 0.4, shades: shades) < 0.0001)
        #expect(abs(GardenLightMath.factor(u: 0.75, shades: shades) - 0.5) < 0.0001)
        #expect(abs(GardenLightMath.factor(u: 0.6, shades: shades) - 1) < 0.0001)
        #expect(GardenLightMath.factor(u: 0, shades: []) < 0.0001)
        #expect(abs(GardenLightMath.factor(u: 0.03, shades: []) - 0.5) < 0.0001)
        var pieces: [LightPiece] = []
        GardenLightMath.pieces(shades: shades, into: &pieces)
        #expect(pieces.count >= 9)
        #expect(abs(pieces.first?.u0 ?? -1) < 0.0001)
        #expect(abs((pieces.last?.u1 ?? 0) - 1) < 0.0001)
        for i in 0...200 {
            let u = Double(i) / 200
            let want = CGFloat(GardenLightMath.factor(u: u, shades: shades))
            #expect(abs(GardenLightMath.drawn(u: u, pieces: pieces) - want) < 0.001)
        }
        GardenLightMath.pieces(shades: [], into: &pieces)
        #expect(pieces.count == 3)
    }

    @Test func shadesShowCloudsInTheMirrorAndCutTheBand() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing(.level(14))
        scene.render(s, events: [], dt: SceneTests.step)
        let plain = scene.lightSpriteCount
        #expect(plain > 0)
        #expect(scene.mirrorShadeClouds == 0)
        s.shades = [ShadeState(id: 1, u: 0.3, halfWidth: 0.12), ShadeState(id: 2, u: 0.7, halfWidth: 0.09)]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.mirrorShadeClouds == 2)
        #expect(scene.lightSpriteCount > plain)
        s.band = -0.2
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.lightSpriteCount == 0)
    }

    @Test func theCreaseShadeRimSitsWhereTheLightStops() {
        for layout in SceneTests.layouts {
            let scene = GardenScene(layout: layout)
            scene.render(SceneTests.playing(), events: [], dt: SceneTests.step)
            let want = scene.scenePoint(u: 0.5, d: GardenMath.creaseShade)
            #expect(SceneTests.near(scene.shadeRimCenter, want, 0.05))
        }
    }

    /// R3 (REVIEW-2 P0-1/2): Core's `submerged` drives the art (not d). Underground: a ripple trails it; `.surfaced`
    /// bursts soil and pops it up.
    @Test func submergedGloomsTravelUnderTheGroundAndPopUp() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        var g = SceneTests.gloom(1, .murk, u: 0.5, d: 0.3)
        g.submerged = true
        g.surfaceD = 0.45
        s.glooms = [g]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.gloomSubmerged(id: 1))
        for _ in 0..<60 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.fxActiveCount > 0)
        g.submerged = false
        g.d = 0.45
        s.glooms = [g]
        let before = scene.fxActiveCount
        scene.render(s, events: [.surfaced(id: 1, kind: .murk, u: 0.5, d: 0.45)], dt: SceneTests.step)
        #expect(!scene.gloomSubmerged(id: 1))
        #expect(scene.gloomPoppingUp(id: 1))
        #expect(scene.fxActiveCount > before)
        // A gloom out in the open at the same depth is not drawn sunk.
        var open = SceneTests.gloom(2, .murk, u: 0.2, d: 0.05)
        open.submerged = false
        s.glooms = [g, open]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(!scene.gloomSubmerged(id: 2))
    }

    /// R3 (REVIEW-2 P0-2): the light does nothing in the crease shade, so only 15 % of it shows there, cool.
    @Test func lightInTheShadeIsDrawnFaint() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.band = GardenMath.creaseShade / 2
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.shadeLightAlpha > 0)
        #expect(scene.shadeLightAlpha < 0.2)
        s.band = 0.6
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.shadeLightAlpha < 0.003)
    }

    /// R3 (REVIEW-2 P0-3): the grass under the band stays under 1.8 × its unlit brightness (a pool, not a slab).
    /// Samples the real lawn texture and adds the layers the scene draws, at their real strengths and profiles.
    @Test func grassUnderTheBandIsAPoolNotASlab() {
        let layout = SceneTests.layouts[0]
        let depth = layout.gardenDepth
        let span = layout.gardenSpan
        for style in [GroundStyle.meadow, GroundStyle.moonlit] {
            for warm in [false, true] {
                let tex = GardenArt.ground(depth: depth, span: span, warm: warm, style: style)
                guard let lum = SceneTests.columnLuma(tex.cgImage()) else {
                    Issue.record("could not read the lawn texture")
                    continue
                }
                let la = LightAlphas.of(style, dawn: warm ? 1 : 0, swell: 0)
                let pool = SceneTests.luma(GardenInk(hex: 0xFFC24A))
                let core = SceneTests.luma(GardenInk(hex: 0xFFF4D6))
                let halo = SceneTests.luma(GardenInk(hex: 0xFFB04A))
                let band = 0.5
                // The scene's night veil sits over the lawn (under the light) while the band is out.
                let veil = 0.4 * (1 - 0.55) * (1 - 0.8 * (warm ? 1.0 : 0.0))
                let veilLuma = SceneTests.luma(GardenPalette.night)
                var unlit = 0.0
                var lit = 0.0
                var n = 0.0
                for (i, raw) in lum.enumerated() {
                    let d = (Double(i) + 0.5) / Double(lum.count)
                    let x = d - band
                    guard abs(x) <= GardenMath.bandEdge else { continue }
                    let base = raw * (1 - veil) + veilLuma * veil
                    let pv = Double(GardenArt.poolValue(distance: x))
                    let hx = min(abs(x) / 0.2, 1)
                    let hv = exp(-3.2 * hx * hx) * (1 - hx * hx)
                    let add = Double(la.pool) * pv * pool + Double(la.core) * pv * pv * core + Double(la.halo) * hv * halo
                    unlit += base
                    lit += min(base + add, 1)
                    n += 1
                }
                #expect(n > 0)
                if n > 0 && unlit > 0 {
                    let ratio = lit / unlit
                    #expect(ratio < 1.8, "style \(style.rawValue) warm \(warm): \(ratio)")
                    #expect(ratio > 1.15, "the light must still show: \(ratio)")
                }
            }
        }
    }

    /// R3 (REVIEW-2 P1-9): no blue on the Rooftops and Harbour grounds (cool blue is cloud shade only).
    @Test func roofsAndBoardwalkHaveNoBlue() {
        let layout = SceneTests.layouts[0]
        for style in [GroundStyle.rooftops, GroundStyle.harbour] {
            for warm in [false, true] {
                let tex = GardenArt.ground(depth: layout.gardenDepth, span: layout.gardenSpan, warm: warm, style: style)
                guard let share = SceneTests.blueShare(tex.cgImage()) else {
                    Issue.record("could not read the ground texture")
                    continue
                }
                #expect(share < 0.02, "style \(style.rawValue) warm \(warm): \(share)")
            }
        }
    }

    @Test func gloomsAreBiggerOnPhonesAndWatchTheBand() {
        let phone = GardenScene(layout: SceneTests.layouts[0])
        let duo = GardenScene(layout: SceneTests.layouts[2])
        var s = SceneTests.playing()
        s.band = 0.8
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.5, d: 0.4)]
        phone.render(s, events: [], dt: SceneTests.step)
        duo.render(s, events: [], dt: SceneTests.step)
        let rp = phone.gloomRadius(id: 1) ?? 0
        let rd = duo.gloomRadius(id: 1) ?? 0
        #expect(abs(rp - 0.045 * SceneTests.layouts[0].gardenDepth * 1.15) < 0.01)
        #expect(abs(rd - 0.045 * SceneTests.layouts[2].gardenDepth) < 0.01)
        // The band is further out: they look towards the flowers (+d); then back towards the crease.
        let f = phone.gardenFrame
        if let l = phone.gloomLook(id: 1) { #expect(l.dx * f.dUnit.dx + l.dy * f.dUnit.dy > 0.9) }
        s.band = 0.1
        phone.render(s, events: [], dt: SceneTests.step)
        if let l = phone.gloomLook(id: 1) { #expect(l.dx * f.dUnit.dx + l.dy * f.dUnit.dy < -0.9) }
    }

    @Test func juicePopsChainsSweepsAndBrutes() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .brute, u: 0.5, d: 0.5, lit: 1)]
        scene.render(s, events: [], dt: SceneTests.step)
        s.glooms = []
        scene.render(s, events: [.popped(id: 1, kind: .brute, u: 0.5, d: 0.5, chain: 5, points: 80),
                                 .swept(count: 3, bonus: 90)], dt: SceneTests.step)
        // The brute holds a white squash for a couple of frames over its burst.
        #expect(scene.dyingGloomCount == 1)
        #expect(scene.bandSwell > 0.9)
        for _ in 0..<12 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.chainTextPeakScale > 1.2)
        #expect(scene.floatingTexts.contains("×5"))
        for _ in 0..<120 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.bandSwell < 0.05)
    }

    @Test func hudSafeRectsAreTheFlowers() {
        for layout in SceneTests.layouts {
            #expect(GardenScene.hudSafeRects(layout: layout) == GardenScene.flowerRects(layout: layout))
            #expect(GardenScene.hudSafeRects(layout: layout).count == 5)
        }
    }

    // MARK: R2b: a ground per world, Long Night under the moon

    @Test func eachModeGetsItsGround() {
        #expect(GroundStyle.of(.level(1)) == .meadow)
        #expect(GroundStyle.of(.level(10)) == .meadow)
        #expect(GroundStyle.of(.level(11)) == .rooftops)
        #expect(GroundStyle.of(.level(20)) == .rooftops)
        #expect(GroundStyle.of(.level(21)) == .harbour)
        #expect(GroundStyle.of(.level(30)) == .harbour)
        #expect(GroundStyle.of(.endless) == .moonlit)
        #expect(GroundStyle.of(.daily(day: 300)) == .meadow)
        for n in 1...30 {
            let world = LevelBook.world(of: n)
            let want: GroundStyle = world == 2 ? .rooftops : (world == 3 ? .harbour : .meadow)
            #expect(GroundStyle.of(.level(n)) == want)
        }
    }

    @Test func theSceneSwitchesGroundsAndCachesThemPerWorld() {
        let layout = SceneTests.layouts[0]
        let scene = GardenScene(layout: layout)
        let cases: [(PlayMode, GroundStyle, Bool)] = [(.level(2), .meadow, false), (.level(13), .rooftops, false),
                                                      (.level(27), .harbour, false), (.endless, .moonlit, true),
                                                      (.daily(day: 9), .meadow, false)]
        for (mode, style, moon) in cases {
            var s = DawnSnapshot(mode: mode, phase: .playing)
            s.band = 0.4
            scene.render(s, events: [], dt: SceneTests.step)
            #expect(scene.groundStyle == style)
            #expect(scene.mirrorMoonlit == moon)
            for warm in [false, true] {
                let key = GardenArt.groundKey(depth: layout.gardenDepth, span: layout.gardenSpan, warm: warm,
                                              style: style)
                #expect(GardenArt.has(key))
            }
        }
        // Back to a world already seen: nothing new is drawn.
        let before = GardenArt.builds
        var again = DawnSnapshot(mode: .level(14), phase: .playing)
        again.band = 0.4
        for _ in 0..<30 { scene.render(again, events: [], dt: SceneTests.step) }
        #expect(scene.groundStyle == .rooftops)
        #expect(GardenArt.builds == before)
    }

    @Test func harbourGlintsSitOnThePuddles() {
        let layout = SceneTests.layouts[0]
        let scene = GardenScene(layout: layout)
        var s = DawnSnapshot(mode: .level(24), phase: .playing)
        s.band = 0.5
        scene.render(s, events: [], dt: SceneTests.step)
        let puddles = GardenMath.puddles(depth: layout.gardenDepth, span: layout.gardenSpan)
        #expect(!puddles.isEmpty)
        #expect(scene.glintSpots.count == GardenScene.glintCount)
        for g in scene.glintSpots {
            var near = false
            for p in puddles {
                let dx = (g.d - p.d) * Double(layout.gardenDepth)
                let dy = (g.u - p.u) * Double(layout.gardenSpan)
                if (dx * dx + dy * dy).squareRoot() <= Double(p.r) + 0.5 { near = true }
            }
            #expect(near)
        }
        // Puddles stay clear of the crease shade and the flower row.
        for p in puddles {
            #expect(p.d - Double(p.r / layout.gardenDepth) > GardenMath.creaseShade)
            #expect(p.d < 0.85)
        }
    }

    @Test func dailyIsGoldenHourAndLongNightIsAtNight() {
        var d = DawnSnapshot(mode: .daily(day: 3))
        d.sun = 0
        #expect(GardenMath.dawn(d) > 0.5)
        var e = DawnSnapshot(mode: .endless)
        e.sun = 0.7
        #expect(GardenMath.dawn(e) < 0.31)
        #expect(abs(GardenMath.nightDepth(e) - 0.7) < 0.0001)
        #expect(GardenMath.nightDepth(d) < 0.0001)
    }

    // MARK: Textures and pooling

    @Test func aWarmFrameLoopBuildsNoTextures() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing(.level(12))
        var gs: [GloomState] = []
        for (i, k) in GloomKind.allCases.enumerated() {
            gs.append(SceneTests.gloom(i + 1, k, u: 0.1 + 0.18 * Double(i), d: 0.4, lit: 0.8))
        }
        s.glooms = gs
        s.fireflies = [FireflyState(id: 1, u: 0.5, d: 0.3, scorch: 0.5, lit: 0.2, age: 1)]
        scene.render(s, events: [], dt: SceneTests.step)
        let before = GardenArt.builds
        let events: [GameEvent] = [
            .emerged(id: 9, kind: .brute, u: 0.3), .popped(id: 1, kind: .murk, u: 0.1, d: 0.4, chain: 5, points: 20),
            .swept(count: 3, bonus: 90), .split(u: 0.5, d: 0.5), .hopped(id: 5, u: 0.82, d: 0.4, skittish: true),
            .fireflyEmerged(id: 2, u: 0.4), .fireflyScorched(id: 1, u: 0.5, d: 0.3),
            .fireflyDelivered(id: 3, lane: 1, replanted: false, points: 50),
            .flowerEaten(lane: 2, flowersLeft: 4, by: .brute), .chainBroken(was: 5), .chainEnded(was: 2),
            .hint(.followTheBigOnes), .started, .waveUp(2)
        ]
        s.flowers = [true, true, false, true, true]
        scene.render(s, events: events, dt: SceneTests.step)
        for i in 0..<120 {
            s.band = 0.2 + Double(i) / 200
            s.sun = Double(i) / 120
            scene.render(s, events: [], dt: SceneTests.step)
        }
        s.phase = .won
        s.glooms = []
        scene.render(s, events: [.sunrise(stars: 2, flowerBonus: 160)], dt: SceneTests.step)
        for _ in 0..<30 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(GardenArt.builds == before)
    }

    @Test func gloomNodesArePooled() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = (1...10).map { SceneTests.gloom($0, .murk, u: Double($0) / 11, d: 0.3) }
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 10)
        let made = scene.gloomNodesMade
        #expect(made <= 12)
        s.glooms = []
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 0)
        #expect(scene.dyingGloomCount == 10)
        for _ in 0..<60 { scene.render(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.pooledGloomCount >= 10)
        s.glooms = (11...20).map { SceneTests.gloom($0, .wisp, u: Double($0 - 10) / 11, d: 0.2) }
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 10)
        #expect(scene.gloomNodesMade == made)
    }

    @Test func fireflyNodesArePooled() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.fireflies = [FireflyState(id: 1, u: 0.3, d: 0.2), FireflyState(id: 2, u: 0.6, d: 0.5)]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeFireflyCount == 2)
        s.fireflies = [FireflyState(id: 2, u: 0.6, d: 0.5)]
        scene.render(s, events: [.fireflyScorched(id: 1, u: 0.3, d: 0.2)], dt: SceneTests.step)
        #expect(scene.activeFireflyCount == 1)
        #expect(scene.fxActiveCount > 0)
        let made = scene.fireflyNodesMade
        s.fireflies = [FireflyState(id: 3, u: 0.5, d: 0.1), FireflyState(id: 4, u: 0.2, d: 0.1)]
        for _ in 0..<60 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.activeFireflyCount == 2)
        #expect(scene.fireflyNodesMade == made)
    }

    // MARK: Event FX

    @Test func aPopBurstsAndReleasesTheGloomAtOnce() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.5, d: 0.5, lit: 1)]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.gloomPoint(id: 1) != nil)
        s.glooms = []
        scene.render(s, events: [.popped(id: 1, kind: .murk, u: 0.5, d: 0.5, chain: 4, points: 17)],
                     dt: SceneTests.step)
        #expect(scene.activeGloomCount == 0)
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.fxActiveCount > 10)
        #expect(scene.floatingTexts.contains("×4"))
    }

    @Test func aLitGloomSqueezesItsEyesShut() {
        let scene = GardenScene(layout: SceneTests.layouts[2])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .brute, u: 0.5, d: 0.4, lit: 0), SceneTests.gloom(2, .murk, u: 0.2, d: 0.4, lit: 1)]
        for _ in 0..<20 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(!scene.gloomSqueezing(id: 1))
        #expect(scene.gloomSqueezing(id: 2))
        #expect(scene.fxActiveCount > 0)
    }

    @Test func sweepsShowWordsExceptInAttractMode() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        let s = SceneTests.playing()
        scene.render(s, events: [.swept(count: 3, bonus: 90)], dt: SceneTests.step)
        #expect(scene.floatingTexts.contains("Sweep!"))
        scene.render(s, events: [.swept(count: 4, bonus: 120)], dt: SceneTests.step)
        #expect(scene.floatingTexts.contains("Sweep ×4!"))
        #expect(!scene.floatingTexts.contains("Sweep!"))

        let quiet = GardenScene(layout: SceneTests.layouts[0])
        quiet.attract = true
        quiet.render(s, events: [.swept(count: 3, bonus: 90), .waveUp(3),
                                 .popped(id: 7, kind: .wisp, u: 0.4, d: 0.4, chain: 6, points: 10)],
                     dt: SceneTests.step)
        #expect(quiet.floatingTexts.isEmpty)
        #expect(quiet.fxActiveCount > 0)
    }

    @Test func sunriseEvaporatesEveryGloomAndFloodsTheGarden() {
        let scene = GardenScene(layout: SceneTests.layouts[1])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.2, d: 0.3), SceneTests.gloom(2, .hopper, u: 0.5, d: 0.6),
                    SceneTests.gloom(3, .splitter, u: 0.8, d: 0.4)]
        scene.render(s, events: [], dt: SceneTests.step)
        s.phase = .won
        s.sun = 1
        s.glooms = []
        scene.render(s, events: [.sunrise(stars: 3, flowerBonus: 200)], dt: SceneTests.step)
        #expect(scene.dyingGloomCount == 3)
        #expect(scene.floodLevel > 0)
        for _ in 0..<150 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.floodLevel > 0.05)
    }

    @Test func nightWinsRollsTheDarknessIn() {
        let scene = GardenScene(layout: SceneTests.layouts[3])
        var s = SceneTests.playing()
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.nightLevel < 0.001)
        s.phase = .lost
        s.flowers = [false, false, false, false, false]
        scene.render(s, events: [.nightWins], dt: SceneTests.step)
        for _ in 0..<240 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.nightLevel > 0.99)
        #expect(scene.flowersStanding == [false, false, false, false, false])
    }

    @Test func anEatenFlowerWiltsAndShakesTheCanvas() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.1, d: 0.97)]
        scene.render(s, events: [], dt: SceneTests.step)
        s.glooms = []
        s.flowers = [false, true, true, true, true]
        scene.render(s, events: [.flowerEaten(lane: 0, flowersLeft: 4, by: .murk)], dt: SceneTests.step)
        #expect(scene.flowersStanding[0] == false)
        #expect(scene.dyingGloomCount == 1)
        let o = scene.shakeOffset
        #expect(abs(o.x) + abs(o.y) > 0.01)

        let calm = GardenScene(layout: SceneTests.layouts[0])
        calm.reduceMotion = true
        var c = SceneTests.playing()
        calm.render(c, events: [], dt: SceneTests.step)
        c.flowers = [false, true, true, true, true]
        calm.render(c, events: [.flowerEaten(lane: 0, flowersLeft: 4, by: .murk)], dt: SceneTests.step)
        #expect(abs(calm.shakeOffset.x) + abs(calm.shakeOffset.y) < 0.0001)
    }

    @Test func aDeliveredFireflyReplantsItsFlower() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.flowers = [true, true, false, true, true]
        s.fireflies = [FireflyState(id: 1, u: 0.5, d: 0.95)]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.flowersStanding[2] == false)
        s.fireflies = []
        s.flowers = [true, true, true, true, true]
        scene.render(s, events: [.fireflyDelivered(id: 1, lane: 2, replanted: true, points: 0)], dt: SceneTests.step)
        #expect(scene.flowersStanding[2])
        #expect(scene.activeFireflyCount == 0)
        #expect(scene.fxActiveCount > 0)
    }

    @Test func aNewSessionClearsEverything() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.time = 30
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.5, d: 0.5)]
        scene.render(s, events: [.popped(id: 9, kind: .murk, u: 0.3, d: 0.3, chain: 3, points: 10)],
                     dt: SceneTests.step)
        #expect(scene.fxActiveCount > 0)
        var fresh = DawnSnapshot(mode: .level(3))
        fresh.time = 0
        scene.render(fresh, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 0)
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.floatingTexts.isEmpty)
    }

    /// R3 (REVIEW-2 P2-17): a firefly draws a 6-dot trail.
    @Test func firefliesTrailSixDots() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        for i in 0..<30 {
            s.fireflies = [FireflyState(id: 4, u: 0.3 + Double(i) * 0.004, d: 0.3 + Double(i) * 0.003)]
            scene.render(s, events: [], dt: SceneTests.step * 4)
        }
        #expect(scene.fireflyTrailDots(id: 4) == 6)
    }

    /// R3 (REVIEW-2 P1-13): behind the menus the mirror shows a warm rising sun, even when the attract garden runs a
    /// Long Night; playing Long Night shows the moon.
    @Test func menusShowTheSunNeverTheMoon() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        scene.attract = true
        var s = DawnSnapshot(mode: .endless, phase: .playing)
        s.band = 0.4
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(!scene.mirrorMoonlit)
        #expect(scene.groundStyle == .meadow)
        #expect(GardenScene.style(for: .endless, attract: true) == .meadow)
        scene.attract = false
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.mirrorMoonlit)
        #expect(scene.groundStyle == .moonlit)
    }

    // MARK: Mirror

    /// R2/R3 (REVIEW-1 P0-4, REVIEW-2 P1-5): the phone's grip sits on the band's edge at d = band exactly along the
    /// rail (d 0 … just above the flower row), parks at the rail's ends outside it, and pulses until the band first
    /// moves. The rail never crosses a flower and never reaches into the mirror. Never in attract mode.
    @Test func theLeverGripRidesTheBandOneToOne() {
        let layout = SceneTests.layouts[0]
        let scene = GardenScene(layout: layout)
        var s = SceneTests.playing()
        s.band = -0.2
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(!scene.leverShowing)
        scene.showsLever = true
        let range = scene.railRange
        #expect(abs(range.lowerBound) < 0.0001)
        #expect(range.upperBound > 0.7 && range.upperBound < 1)
        for b in [-0.2, 0.0, 0.37, 0.8, 1.0] {
            s.band = b
            scene.render(s, events: [], dt: SceneTests.step)
            #expect(scene.leverShowing)
            let f = layout.floorPoint(at: scene.swiftUIPoint(fromScene: scene.leverPoint))
            let want = min(max(b, range.lowerBound), range.upperBound)
            #expect(abs(f.d - want) < 0.001)
            #expect(f.u > 0.85 && f.u < 1)
        }
        #expect(!scene.gripPulsing)
        // The rail: from the crease to above the flowers, clear of every flower's rect, none of it on the mirror.
        let flowers = GardenScene.flowerRects(layout: layout)
        let ends = scene.railEnds
        for p in [ends.0, ends.1] {
            let q = scene.swiftUIPoint(fromScene: p)
            #expect(!flowers.contains { $0.contains(q) })
            #expect(layout.floorPoint(at: q).d >= -0.0001)
        }
        let fresh = GardenScene(layout: layout)
        fresh.showsLever = true
        var w = SceneTests.playing()
        w.band = -0.2
        fresh.render(w, events: [], dt: SceneTests.step)
        #expect(fresh.gripPulsing)
        fresh.attract = true
        fresh.render(w, events: [], dt: SceneTests.step)
        #expect(!fresh.leverShowing)
    }

    /// R2: the sun's glint is a small cross flare (a fraction of the sun), and the glass has a hot spot at its crease
    /// edge.
    @Test func theSunGlintIsSmallAndTheGlassHasAHotSpot() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.sun = 0.5
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.sunGlintSize < scene.sunRadius * 1.3)
        #expect(scene.sunGlintSize > 1)
        #expect(abs(scene.mirrorHotSpot.y - scene.mirrorGlass.minY) < 0.5)
    }

    @Test func theSunRisesWithTheLevel() {
        for layout in SceneTests.layouts {
            let scene = GardenScene(layout: layout)
            var s = SceneTests.playing(.level(25))
            s.sun = 0
            scene.render(s, events: [], dt: SceneTests.step)
            let low = scene.sunPoint
            s.sun = 1
            scene.render(s, events: [], dt: SceneTests.step)
            let high = scene.sunPoint
            #expect(high.y > low.y + 20)
            #expect(scene.mirrorGlass.contains(high))
            #expect(scene.mirrorWorld == 3)
        }
    }

    // MARK: Layout, touches, budget

    @Test func reLayoutKeepsTheGloomsAndMovesThem() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.3, d: 0.4), SceneTests.gloom(2, .brute, u: 0.7, d: 0.6)]
        scene.render(s, events: [], dt: SceneTests.step)
        for layout in SceneTests.layouts.reversed() {
            scene.apply(layout: layout)
            #expect(scene.size == layout.size)
            scene.render(s, events: [], dt: SceneTests.step)
            #expect(scene.activeGloomCount == 2)
            if let p = scene.gloomPoint(id: 1) {
                #expect(SceneTests.near(p, scene.scenePoint(u: 0.3, d: 0.4), 0.5))
            } else {
                Issue.record("gloom 1 lost on re-layout")
            }
            let local = scene.gardenFrame.local(u: 0.9, d: 0.1)
            let want = layout.scenePoint(layout.point(u: 0.9, d: 0.1))
            #expect(SceneTests.near(scene.gardenNode.convert(local, to: scene), want, 0.05))
        }
    }

    @Test func theFrameLoopAsksTheDriver() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        let driver = SceneFakeDriver()
        driver.snapshot = SceneTests.playing()
        driver.events = [.swept(count: 3, bonus: 90)]
        scene.driver = driver
        scene.update(10)
        scene.update(10.008)
        #expect(driver.advances == 2)
        #expect(scene.frameIndex == 2)
        #expect(scene.floatingTexts.contains("Sweep!"))
    }

    @Test func aBusyFrameStaysInsideTheNodeBudget() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing(.level(15))
        var gs: [GloomState] = []
        for i in 0..<12 {
            let k = GloomKind.allCases[i % GloomKind.allCases.count]
            gs.append(SceneTests.gloom(i + 1, k, u: 0.04 + Double(i) * 0.08, d: 0.15 + Double(i % 4) * 0.2))
        }
        s.glooms = gs
        s.fireflies = [FireflyState(id: 1, u: 0.2, d: 0.3), FireflyState(id: 2, u: 0.5, d: 0.6),
                       FireflyState(id: 3, u: 0.8, d: 0.2)]
        scene.render(s, events: [.popped(id: 99, kind: .brute, u: 0.5, d: 0.5, chain: 6, points: 70)],
                     dt: SceneTests.step)
        for _ in 0..<10 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.drawnNodeCount <= 300)
        // R2: the light layers keep 150 pooled piece sprites (hidden unless a cloud shade cuts the band); R3 adds the
        // fireflies' trail dots and more ripple rings.
        #expect(scene.nodeCount <= 700)
    }
}
