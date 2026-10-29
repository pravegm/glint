import SpriteKit
import UIKit

// MARK: - Gloom art

/// The layers of a gloom's puppet. Every layer of a kind shares one canvas and anchor, so they overlay exactly.
enum GloomLayer: String, CaseIterable {
    case body, lit, eyes, pupils, squeeze, mouth, mouthOpen, brow
}

/// Where each feature sits on a kind's art, in body-radius units (R = 1), the body centre at the origin.
struct GloomLook {
    /// The canvas, R units.
    let canvas: CGSize
    /// The body centre inside the canvas (R units from the bottom-left).
    let center: CGPoint
    let eyes: [CGPoint]
    /// −1: the left eye of a pair, +1: the right one (which way the "> <" squeeze points).
    let eyeSides: [CGFloat]
    let eyeRadius: CGFloat
    /// The eyes' common height (blinks squash about it).
    let eyeY: CGFloat
    let mouths: [CGPoint]
    let mouthWidth: CGFloat
    let gloss: [CGPoint]
    let hasBrow: Bool
    /// The body's lit-side colour (the rest is shaded from it).
    let top: GardenInk

    /// The sprites' anchor point (the body centre, unit coordinates).
    var anchor: CGPoint { CGPoint(x: center.x / canvas.width, y: center.y / canvas.height) }

    static func of(_ kind: GloomKind) -> GloomLook {
        switch kind {
        case .murk:
            return GloomLook(canvas: CGSize(width: 2.8, height: 2.7), center: CGPoint(x: 1.4, y: 1.3),
                             eyes: [CGPoint(x: -0.36, y: 0.14), CGPoint(x: 0.36, y: 0.14)], eyeSides: [-1, 1],
                             eyeRadius: 0.3, eyeY: 0.14, mouths: [CGPoint(x: 0, y: -0.38)], mouthWidth: 0.2,
                             gloss: [CGPoint(x: -0.42, y: 0.52)], hasBrow: false, top: GardenInk(hex: 0x4E3676))
        case .wisp:
            return GloomLook(canvas: CGSize(width: 2.6, height: 3.1), center: CGPoint(x: 1.3, y: 1.25),
                             eyes: [CGPoint(x: -0.32, y: 0.0), CGPoint(x: 0.32, y: 0.0)], eyeSides: [-1, 1],
                             eyeRadius: 0.31, eyeY: 0.0, mouths: [CGPoint(x: 0, y: -0.48)], mouthWidth: 0.14,
                             gloss: [CGPoint(x: -0.34, y: 0.42)], hasBrow: false, top: GardenInk(hex: 0x40448A))
        case .brute:
            return GloomLook(canvas: CGSize(width: 3.0, height: 2.7), center: CGPoint(x: 1.5, y: 1.3),
                             eyes: [CGPoint(x: -0.36, y: 0.08), CGPoint(x: 0.36, y: 0.08)], eyeSides: [-1, 1],
                             eyeRadius: 0.22, eyeY: 0.08, mouths: [CGPoint(x: 0, y: -0.42)], mouthWidth: 0.36,
                             gloss: [CGPoint(x: -0.48, y: 0.5)], hasBrow: true, top: GardenInk(hex: 0x52305E))
        case .splitter:
            return GloomLook(canvas: CGSize(width: 3.4, height: 2.5), center: CGPoint(x: 1.7, y: 1.2),
                             eyes: [CGPoint(x: -0.72, y: 0.1), CGPoint(x: -0.32, y: 0.1), CGPoint(x: 0.32, y: 0.1),
                                    CGPoint(x: 0.72, y: 0.1)], eyeSides: [-1, 1, -1, 1],
                             eyeRadius: 0.17, eyeY: 0.1, mouths: [CGPoint(x: -0.52, y: -0.3), CGPoint(x: 0.52, y: -0.3)],
                             mouthWidth: 0.13, gloss: [CGPoint(x: -0.76, y: 0.38), CGPoint(x: 0.3, y: 0.38)],
                             hasBrow: false, top: GardenInk(hex: 0x3A4A7A))
        case .hopper:
            return GloomLook(canvas: CGSize(width: 2.6, height: 3.4), center: CGPoint(x: 1.3, y: 1.25),
                             eyes: [CGPoint(x: -0.32, y: 0.08), CGPoint(x: 0.32, y: 0.08)], eyeSides: [-1, 1],
                             eyeRadius: 0.27, eyeY: 0.08, mouths: [CGPoint(x: 0, y: -0.36)], mouthWidth: 0.16,
                             gloss: [CGPoint(x: -0.38, y: 0.45)], hasBrow: false, top: GardenInk(hex: 0x5C3470))
        }
    }
}

/// Procedural art for the glooms, the fireflies and the flowers (cached textures).
@MainActor
enum CreatureArt {
    /// Texture points per body radius.
    static let gloomRef: CGFloat = 44
    /// Texture points per flower radius.
    static let flowerRef: CGFloat = 30
    /// The flowers' canvas, flower-radius units (square).
    static let flowerCanvas: CGFloat = 2.8

    static func gloomKey(_ kind: GloomKind, _ layer: GloomLayer) -> String { "gloom-\(kind.rawValue)-\(layer.rawValue)" }

    static func gloom(_ kind: GloomKind, _ layer: GloomLayer) -> SKTexture {
        let look = GloomLook.of(kind)
        let size = CGSize(width: look.canvas.width * gloomRef, height: look.canvas.height * gloomRef)
        return GardenArt.make(gloomKey(kind, layer), size: size, scale: 2) { ctx, _ in
            ctx.translateBy(x: look.center.x * gloomRef, y: look.center.y * gloomRef)
            ctx.scaleBy(x: gloomRef, y: gloomRef)
            switch layer {
            case .body: drawBody(ctx, kind, look)
            case .lit: drawLit(ctx, kind)
            case .eyes: drawEyes(ctx, look)
            case .pupils: drawPupils(ctx, look)
            case .squeeze: drawSqueeze(ctx, look)
            case .mouth: drawMouth(ctx, kind, look, open: false)
            case .mouthOpen: drawMouth(ctx, kind, look, open: true)
            case .brow: drawBrow(ctx, look)
            }
        }
    }

    /// Builds every gloom texture now (scene set-up), so no kind's first appearance draws mid-play.
    static func warmGlooms() {
        for k in GloomKind.allCases {
            for l in GloomLayer.allCases { _ = gloom(k, l) }
        }
        _ = soilLip
    }

    /// R4 (REVIEW-3 P1-7): the lip of soil a submerged gloom's eyes peek over: a low mound, lit along its top, darker
    /// below, feathered at the sides, with a few crumbs. Greys (tint it with the ground's soil colour). 120 × 48 pt;
    /// the lip's top runs at y = `soilLipTop`.
    static let soilLipSize = CGSize(width: 120, height: 48)
    static let soilLipTop: CGFloat = 34

    static var soilLip: SKTexture {
        GardenArt.make("soil-lip", size: soilLipSize, scale: 2) { ctx, s in
            let top = soilLipTop
            let mound = CGMutablePath()
            mound.move(to: CGPoint(x: 0, y: 4))
            mound.addCurve(to: CGPoint(x: s.width / 2, y: top), control1: CGPoint(x: s.width * 0.16, y: top - 2),
                           control2: CGPoint(x: s.width * 0.3, y: top))
            mound.addCurve(to: CGPoint(x: s.width, y: 4), control1: CGPoint(x: s.width * 0.7, y: top),
                           control2: CGPoint(x: s.width * 0.84, y: top - 2))
            mound.addLine(to: CGPoint(x: s.width, y: 0))
            mound.addLine(to: CGPoint(x: 0, y: 0))
            mound.closeSubpath()
            GardenPainter.clipped(ctx, mound) {
                GardenPainter.linear(ctx, [GardenInk(0.42, 0.42, 0.42, 0.0), GardenInk(0.5, 0.5, 0.5, 0.95),
                                           GardenInk(0.85, 0.85, 0.85, 1)], [0, 0.45, 1],
                                     from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: top))
            }
            let rim = CGMutablePath()
            rim.move(to: CGPoint(x: s.width * 0.12, y: top - 6))
            rim.addCurve(to: CGPoint(x: s.width * 0.88, y: top - 6), control1: CGPoint(x: s.width * 0.32, y: top + 1),
                         control2: CGPoint(x: s.width * 0.68, y: top + 1))
            GardenPainter.stroke(ctx, rim, GardenInk(1, 1, 1, 0.55), width: 1.6)
            var rng = GardenRNG(seed: 0x5011)
            let crumbs = CGMutablePath()
            for _ in 0..<9 {
                let c = CGPoint(x: rng.range(s.width * 0.12, s.width * 0.88), y: rng.range(top - 10, top + 4))
                let r = rng.range(1.2, 2.6)
                crumbs.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
            GardenPainter.fill(ctx, crumbs, GardenInk(0.62, 0.62, 0.62, 0.95))
            // Feather the sides.
            ctx.setBlendMode(.destinationIn)
            GardenPainter.linear(ctx, [GardenInk(1, 1, 1, 0), GardenInk.white, GardenInk.white, GardenInk(1, 1, 1, 0)],
                                 [0, 0.18, 0.82, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            ctx.setBlendMode(.normal)
        }
    }

    /// R2: the dark seam a submerged gloom sits in: ink below a gently wavy surface with a cool rim of light, soft at
    /// the sides and bottom. 132 × 80 pt; the surface runs at y = `poolSurface`.
    static let poolSize = CGSize(width: 132, height: 80)
    static let poolSurface: CGFloat = 68

    static var pool: SKTexture {
        GardenArt.make("gloom-pool", size: poolSize, scale: 2) { ctx, s in
            let top = poolSurface
            func surface(_ x: CGFloat) -> CGFloat {
                let f = x / s.width
                return top + sin(f * 4 * CGFloat.pi) * 1.8 - abs(f - 0.5) * 9
            }
            let body = CGMutablePath()
            let edge = CGMutablePath()
            body.move(to: CGPoint(x: 0, y: 0))
            var x: CGFloat = 0
            while x <= s.width + 0.1 {
                let p = CGPoint(x: x, y: surface(x))
                body.addLine(to: p)
                if x == 0 { edge.move(to: p) } else { edge.addLine(to: p) }
                x += 4
            }
            body.addLine(to: CGPoint(x: s.width, y: 0))
            body.closeSubpath()
            GardenPainter.clipped(ctx, body) {
                GardenPainter.linear(ctx, [GardenInk(hex: 0x03050E, alpha: 0), GardenInk(hex: 0x03050E, alpha: 0.96),
                                           GardenInk(hex: 0x060A1C, alpha: 0.98)], [0, 0.45, 1],
                                     from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: top))
                // A cool sheen just under the surface.
                GardenPainter.linear(ctx, [GardenInk(hex: 0x5C8FD8, alpha: 0), GardenInk(hex: 0x5C8FD8, alpha: 0.22)],
                                     [0, 1], from: CGPoint(x: 0, y: top - 14), to: CGPoint(x: 0, y: top))
            }
            GardenPainter.stroke(ctx, edge, GardenInk(hex: 0x9CCBFF, alpha: 0.14), width: 6)
            GardenPainter.stroke(ctx, edge, GardenInk(hex: 0xB8DCFF, alpha: 0.6), width: 1.6)
            // Soften the sides.
            ctx.setBlendMode(.destinationIn)
            GardenPainter.linear(ctx, [GardenInk(1, 1, 1, 0), GardenInk.white, GardenInk.white, GardenInk(1, 1, 1, 0)],
                                 [0, 0.2, 0.8, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            ctx.setBlendMode(.normal)
        }
    }

    // MARK: Shapes (R units, centred; every loop runs counter-clockwise so unions fill with nonzero winding)

    static func ellipseLoop(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, angle: CGFloat) -> CGPath {
        let ca = cos(angle)
        let sa = sin(angle)
        return GardenPainter.loop(16) { t in
            let x = cos(t) * rx
            let y = sin(t) * ry
            return CGPoint(x: c.x + x * ca - y * sa, y: c.y + x * sa + y * ca)
        }
    }

    static func bodyPath(_ kind: GloomKind) -> CGPath {
        switch kind {
        case .murk:
            return GardenPainter.loop(30) { t in
                let k: CGFloat = 1 + 0.045 * sin(3 * t + 0.7) + 0.03 * sin(5 * t + 1.9)
                let s = sin(t)
                let widen: CGFloat = 1 + 0.07 * max(0, -s)
                let y: CGFloat = s < 0 ? s * k * 0.86 : s * k
                return CGPoint(x: cos(t) * k * 1.04 * widen, y: y)
            }
        case .wisp:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: -0.95))
            p.addCurve(to: CGPoint(x: 0.88, y: -0.12), control1: CGPoint(x: 0.56, y: -0.95),
                       control2: CGPoint(x: 0.88, y: -0.6))
            p.addCurve(to: CGPoint(x: 0.28, y: 1.38), control1: CGPoint(x: 0.88, y: 0.42),
                       control2: CGPoint(x: 0.5, y: 0.9))
            p.addCurve(to: CGPoint(x: -0.88, y: -0.12), control1: CGPoint(x: 0.02, y: 0.98),
                       control2: CGPoint(x: -0.88, y: 0.52))
            p.addCurve(to: CGPoint(x: 0, y: -0.95), control1: CGPoint(x: -0.88, y: -0.6),
                       control2: CGPoint(x: -0.56, y: -0.95))
            p.closeSubpath()
            return p
        case .brute:
            return GardenPainter.loop(34) { t in
                let k: CGFloat = 1 + 0.06 * sin(4 * t + 0.3) + 0.035 * sin(7 * t + 1.1)
                let s = sin(t)
                let y: CGFloat = s < 0 ? s * k * 0.84 : s * k * 0.96
                return CGPoint(x: cos(t) * k * 1.1, y: y)
            }
        case .splitter:
            let p = CGMutablePath()
            p.addPath(GardenPainter.loop(24) { t in
                let k: CGFloat = 1 + 0.05 * sin(3 * t + 0.4)
                return CGPoint(x: -0.52 + cos(t) * 0.68 * k, y: sin(t) * 0.7 * k)
            })
            p.addPath(GardenPainter.loop(24) { t in
                let k: CGFloat = 1 + 0.05 * sin(3 * t + 2.1)
                return CGPoint(x: 0.52 + cos(t) * 0.68 * k, y: sin(t) * 0.7 * k)
            })
            return p
        case .hopper:
            let p = CGMutablePath()
            p.addPath(GardenPainter.loop(28) { t in
                let k: CGFloat = 1 + 0.03 * sin(3 * t + 0.5)
                let s = sin(t)
                let wide: CGFloat = s < 0 ? 1.06 : 0.94
                return CGPoint(x: cos(t) * 0.92 * k * wide, y: s * 0.9 * k)
            })
            p.addPath(ellipseLoop(CGPoint(x: -0.4, y: 1.0), 0.2, 0.52, angle: 0.24))
            p.addPath(ellipseLoop(CGPoint(x: 0.4, y: 1.0), 0.2, 0.52, angle: -0.24))
            return p
        }
    }

    static func drawBody(_ ctx: CGContext, _ kind: GloomKind, _ look: GloomLook) {
        let path = bodyPath(kind)
        // A faint violet aura so the ink reads on the dark lawn.
        let auraSteps: [(CGFloat, CGFloat)] = [(0.5, 0.07), (0.34, 0.11), (0.2, 0.2)]
        for (lw, a) in auraSteps {
            GardenPainter.stroke(ctx, path, GardenPalette.inkAura.with(alpha: a), width: lw)
        }
        // Ink drips under the heavier kinds.
        if kind == .murk || kind == .brute {
            let drips = CGMutablePath()
            drips.addPath(GardenPainter.circle(CGPoint(x: -0.42, y: -0.93), 0.1))
            drips.addPath(GardenPainter.circle(CGPoint(x: 0.3, y: -0.97), 0.075))
            GardenPainter.stroke(ctx, drips, GardenPalette.inkOutline, width: 0.08)
            GardenPainter.fill(ctx, drips, look.top.darker(0.7))
        }
        GardenPainter.stroke(ctx, path, GardenPalette.inkOutline, width: 0.11)
        let top = look.top
        GardenPainter.clipped(ctx, path) {
            GardenPainter.radial(ctx, [top, top.darker(0.45), top.darker(0.76)], [0, 0.5, 1],
                                 center: CGPoint(x: -0.3, y: 0.45), radius: 1.75)
            if kind == .hopper {
                let inner = CGMutablePath()
                inner.addPath(ellipseLoop(CGPoint(x: -0.42, y: 1.04), 0.09, 0.36, angle: 0.24))
                inner.addPath(ellipseLoop(CGPoint(x: 0.42, y: 1.04), 0.09, 0.36, angle: -0.24))
                GardenPainter.fill(ctx, inner, GardenInk(hex: 0x9A62B8, alpha: 0.55))
            }
            // Rim light on the upper left.
            ctx.saveGState()
            ctx.addPath(GardenPainter.circle(CGPoint(x: -0.62, y: 0.72), 1.12))
            ctx.clip()
            GardenPainter.stroke(ctx, path, GardenPalette.inkRim.with(alpha: 0.6), width: 0.2)
            ctx.restoreGState()
            // A teal bounce from the lawn on the lower right.
            ctx.saveGState()
            ctx.addPath(GardenPainter.circle(CGPoint(x: 0.6, y: -0.85), 0.95))
            ctx.clip()
            GardenPainter.stroke(ctx, path, GardenInk(hex: 0x5FC7C0, alpha: 0.22), width: 0.14)
            ctx.restoreGState()
            for g in look.gloss {
                ctx.saveGState()
                ctx.translateBy(x: g.x, y: g.y)
                ctx.scaleBy(x: 1.3, y: 0.85)
                GardenPainter.radial(ctx, [GardenInk(1, 1, 1, 0.34), GardenInk(1, 1, 1, 0)], [0, 1],
                                     center: .zero, radius: 0.26)
                ctx.restoreGState()
            }
            // Tiny starry specks in the ink.
            let specks: [CGPoint] = [CGPoint(x: 0.42, y: 0.5), CGPoint(x: 0.6, y: -0.2), CGPoint(x: -0.55, y: -0.4),
                                     CGPoint(x: 0.12, y: -0.62)]
            for sp in specks {
                GardenPainter.fill(ctx, GardenPainter.circle(sp, 0.03), GardenPalette.inkRim.with(alpha: 0.45))
            }
        }
    }

    static func drawLit(_ ctx: CGContext, _ kind: GloomKind) {
        let path = bodyPath(kind)
        let outer: [(CGFloat, CGFloat)] = [(0.8, 0.08), (0.5, 0.16), (0.28, 0.3)]
        for (lw, a) in outer {
            GardenPainter.stroke(ctx, path, GardenInk(1, 1, 1, a), width: lw)
        }
        GardenPainter.clipped(ctx, path) {
            let inner: [(CGFloat, CGFloat)] = [(0.7, 0.16), (0.42, 0.32), (0.18, 0.85)]
            for (lw, a) in inner {
                GardenPainter.stroke(ctx, path, GardenInk(1, 1, 1, a), width: lw)
            }
            GardenPainter.radial(ctx, [GardenInk(1, 1, 1, 0.22), GardenInk(1, 1, 1, 0)], [0, 1],
                                 center: CGPoint(x: 0, y: 0.1), radius: 1.0)
        }
    }

    static func drawEyes(_ ctx: CGContext, _ look: GloomLook) {
        let r = look.eyeRadius
        for e in look.eyes {
            let p = GardenPainter.ellipse(e, r * 0.9, r * 1.06)
            GardenPainter.stroke(ctx, p, GardenPalette.inkOutline, width: max(0.07, r * 0.26))
            GardenPainter.clipped(ctx, p) {
                GardenPainter.linear(ctx, [GardenPalette.eyeWhite, GardenPalette.eyeWhite, GardenPalette.eyeShade],
                                     [0, 0.55, 1], from: CGPoint(x: e.x, y: e.y + r), to: CGPoint(x: e.x, y: e.y - r))
            }
        }
    }

    static func drawPupils(_ ctx: CGContext, _ look: GloomLook) {
        let r = look.eyeRadius
        for e in look.eyes {
            let c = CGPoint(x: e.x, y: e.y - r * 0.08)
            GardenPainter.fill(ctx, GardenPainter.circle(c, r * 0.56), GardenPalette.pupil)
            GardenPainter.fill(ctx, GardenPainter.circle(CGPoint(x: c.x - r * 0.2, y: c.y + r * 0.2), r * 0.2),
                               GardenInk.white)
            GardenPainter.fill(ctx, GardenPainter.circle(CGPoint(x: c.x + r * 0.17, y: c.y - r * 0.2), r * 0.09),
                               GardenInk(1, 1, 1, 0.8))
        }
    }

    /// Eyes squeezed shut against the light: "> <".
    static func drawSqueeze(_ ctx: CGContext, _ look: GloomLook) {
        let r = look.eyeRadius
        for (i, e) in look.eyes.enumerated() {
            let side: CGFloat = i < look.eyeSides.count ? look.eyeSides[i] : -1
            let back = e.x + side * r * 0.6
            let tip = e.x - side * r * 0.5
            let p = CGMutablePath()
            p.move(to: CGPoint(x: back, y: e.y + r * 0.55))
            p.addLine(to: CGPoint(x: tip, y: e.y))
            p.addLine(to: CGPoint(x: back, y: e.y - r * 0.55))
            GardenPainter.stroke(ctx, p, GardenPalette.inkOutline, width: r * 0.62)
            GardenPainter.stroke(ctx, p, GardenInk.white, width: r * 0.34)
        }
    }

    static func drawMouth(_ ctx: CGContext, _ kind: GloomKind, _ look: GloomLook, open: Bool) {
        let mw = look.mouthWidth
        for m in look.mouths {
            if open {
                let o = GardenPainter.ellipse(CGPoint(x: m.x, y: m.y - 0.04), mw * 0.95, mw * 0.8)
                GardenPainter.stroke(ctx, o, GardenPalette.inkOutline, width: 0.09)
                GardenPainter.fill(ctx, o, GardenInk(hex: 0x3B0C2C))
                GardenPainter.clipped(ctx, o) {
                    GardenPainter.fill(ctx, GardenPainter.ellipse(CGPoint(x: m.x, y: m.y - 0.04 - mw * 0.72),
                                                                  mw * 0.6, mw * 0.42), GardenInk(hex: 0xE0607E))
                }
                GardenPainter.stroke(ctx, o, GardenPalette.inkLip.with(alpha: 0.8), width: 0.045)
                if kind == .brute { drawTusks(ctx, m, mw, baseY: m.y - 0.04 - mw * 0.66) }
            } else if kind == .brute {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: m.x - mw, y: m.y - 0.02))
                p.addQuadCurve(to: CGPoint(x: m.x + mw, y: m.y - 0.02), control: CGPoint(x: m.x, y: m.y + 0.1))
                GardenPainter.stroke(ctx, p, GardenPalette.inkLip, width: 0.08)
                drawTusks(ctx, m, mw, baseY: m.y + 0.02)
            } else {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: m.x - mw, y: m.y + 0.04))
                p.addQuadCurve(to: CGPoint(x: m.x + mw, y: m.y + 0.04), control: CGPoint(x: m.x, y: m.y - 0.16))
                GardenPainter.stroke(ctx, p, GardenPalette.inkLip, width: 0.075)
                let fx = m.x + mw * 0.42
                let fang = CGMutablePath()
                fang.move(to: CGPoint(x: fx - 0.045, y: m.y - 0.03))
                fang.addLine(to: CGPoint(x: fx + 0.045, y: m.y - 0.03))
                fang.addLine(to: CGPoint(x: fx, y: m.y - 0.13))
                fang.closeSubpath()
                GardenPainter.fill(ctx, fang, GardenInk.white)
            }
        }
    }

    /// The brute's underbite: two tusks pointing up from `baseY`.
    static func drawTusks(_ ctx: CGContext, _ m: CGPoint, _ mw: CGFloat, baseY: CGFloat) {
        for side in [CGFloat(-1), CGFloat(1)] {
            let tx = m.x + side * mw * 0.55
            let t = CGMutablePath()
            t.move(to: CGPoint(x: tx - 0.065, y: baseY))
            t.addLine(to: CGPoint(x: tx + 0.065, y: baseY))
            t.addLine(to: CGPoint(x: tx + side * 0.015, y: baseY + 0.18))
            t.closeSubpath()
            GardenPainter.stroke(ctx, t, GardenPalette.inkOutline, width: 0.04)
            GardenPainter.fill(ctx, t, GardenInk(hex: 0xFFF6E8))
        }
    }

    /// The brute's heavy brows.
    static func drawBrow(_ ctx: CGContext, _ look: GloomLook) {
        guard look.hasBrow else { return }
        for side in [CGFloat(-1), CGFloat(1)] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: side * 0.64, y: 0.44))
            p.addQuadCurve(to: CGPoint(x: side * 0.13, y: 0.3), control: CGPoint(x: side * 0.4, y: 0.47))
            GardenPainter.stroke(ctx, p, GardenInk(hex: 0x0A0614), width: 0.21)
            let hi = CGMutablePath()
            hi.move(to: CGPoint(x: side * 0.6, y: 0.5))
            hi.addQuadCurve(to: CGPoint(x: side * 0.2, y: 0.39), control: CGPoint(x: side * 0.4, y: 0.53))
            GardenPainter.stroke(ctx, hi, GardenPalette.inkRim.with(alpha: 0.4), width: 0.05)
        }
    }

    // MARK: Firefly (top-down: wings, body, a glowing tail)

    /// R3 (REVIEW-2 P2-17): the body only (the wings are their own sprite, so they flicker), with a big lime lantern.
    static var firefly: SKTexture {
        GardenArt.make("firefly-3", size: CGSize(width: 28, height: 28), scale: 3) { ctx, s in
            ctx.translateBy(x: s.width / 2, y: s.height / 2)
            ctx.scaleBy(x: 12, y: 12)
            GardenPainter.fill(ctx, GardenPainter.ellipse(CGPoint(x: 0, y: 0.12), 0.24, 0.42), GardenInk(hex: 0x2E3A14))
            GardenPainter.stroke(ctx, GardenPainter.ellipse(CGPoint(x: 0, y: 0.12), 0.24, 0.42),
                                 GardenInk(hex: 0x141A08), width: 0.06)
            GardenPainter.fill(ctx, GardenPainter.circle(CGPoint(x: 0, y: 0.6), 0.17), GardenInk(hex: 0x1E2410))
            let tail = GardenPainter.ellipse(CGPoint(x: 0, y: -0.38), 0.34, 0.44)
            GardenPainter.stroke(ctx, tail, GardenInk(hex: 0x4A7A10), width: 0.08)
            GardenPainter.fill(ctx, tail, GardenPalette.firefly)
            GardenPainter.clipped(ctx, tail) {
                GardenPainter.radial(ctx, [GardenInk(hex: 0xF4FFC8), GardenPalette.firefly.with(alpha: 0)], [0, 1],
                                     center: CGPoint(x: -0.06, y: -0.3), radius: 0.32)
            }
            let ant = CGMutablePath()
            for side in [CGFloat(-1), CGFloat(1)] {
                ant.move(to: CGPoint(x: side * 0.05, y: 0.66))
                ant.addQuadCurve(to: CGPoint(x: side * 0.3, y: 0.98), control: CGPoint(x: side * 0.06, y: 0.9))
            }
            GardenPainter.stroke(ctx, ant, GardenInk(hex: 0x2A2418), width: 0.05)
        }
    }

    /// R3: the firefly's two wings (they flicker), pale lime-white.
    static var fireflyWings: SKTexture {
        GardenArt.make("firefly-wings", size: CGSize(width: 28, height: 28), scale: 3) { ctx, s in
            ctx.translateBy(x: s.width / 2, y: s.height / 2)
            ctx.scaleBy(x: 12, y: 12)
            for side in [CGFloat(-1), CGFloat(1)] {
                let wing = CGMutablePath()
                GardenPainter.addEllipse(wing, CGPoint(x: side * 0.42, y: 0.22), 0.34, 0.62, angle: -side * 0.55)
                GardenPainter.fill(ctx, wing, GardenInk(hex: 0xEFFFD8, alpha: 0.5))
                GardenPainter.stroke(ctx, wing, GardenInk(hex: 0xEFFFD8, alpha: 0.85), width: 0.06)
            }
        }
    }

    // MARK: Flowers (top-down)

    struct FlowerLook {
        let petal: GardenInk
        let shade: GardenInk
        let heart: GardenInk
        let seeds: GardenInk
        let count: Int
        /// 0 round, 1 narrow, 2 heart-tipped, 3 pointed.
        let shape: Int
        let width: CGFloat
        let layers: Int
    }

    static let flowerLooks: [FlowerLook] = [
        FlowerLook(petal: GardenInk(hex: 0xFF7FA0), shade: GardenInk(hex: 0xD9466E), heart: GardenInk(hex: 0xFFD45A),
                   seeds: GardenInk(hex: 0xE39A2A), count: 8, shape: 0, width: 0.36, layers: 2),
        FlowerLook(petal: GardenInk(hex: 0xFFC23D), shade: GardenInk(hex: 0xEE7F1A), heart: GardenInk(hex: 0x8A4A1A),
                   seeds: GardenInk(hex: 0x5A2E0E), count: 14, shape: 1, width: 0.17, layers: 2),
        FlowerLook(petal: GardenInk(hex: 0xB58DFF), shade: GardenInk(hex: 0x7650D6), heart: GardenInk(hex: 0xFFE27A),
                   seeds: GardenInk(hex: 0xE0A030), count: 5, shape: 2, width: 0.48, layers: 1),
        FlowerLook(petal: GardenInk(hex: 0x7CCBFF), shade: GardenInk(hex: 0x3E8FE0), heart: GardenInk(hex: 0xFFF6C0),
                   seeds: GardenInk(hex: 0xF2C24A), count: 6, shape: 3, width: 0.34, layers: 1),
        FlowerLook(petal: GardenInk(hex: 0xFFF4E6), shade: GardenInk(hex: 0xFFC7A6), heart: GardenInk(hex: 0xFF9A3C),
                   seeds: GardenInk(hex: 0xD86A1A), count: 11, shape: 1, width: 0.19, layers: 1)
    ]

    static func flowerLook(_ i: Int) -> FlowerLook {
        let n = flowerLooks.count
        return flowerLooks[((i % n) + n) % n]
    }

    /// One petal pointing up (+y) from the flower's centre, length `len`.
    static func petalPath(shape: Int, len: CGFloat, width wd: CGFloat) -> CGPath {
        let p = CGMutablePath()
        switch shape {
        case 0, 1:
            p.addPath(ellipseLoop(CGPoint(x: 0, y: len * 0.55), wd, len * (shape == 0 ? 0.45 : 0.47), angle: 0))
        case 2:
            p.move(to: CGPoint(x: 0, y: 0.1))
            p.addCurve(to: CGPoint(x: 0, y: len * 0.86), control1: CGPoint(x: wd * 1.5, y: len * 0.3),
                       control2: CGPoint(x: wd * 1.3, y: len * 1.08))
            p.addCurve(to: CGPoint(x: 0, y: 0.1), control1: CGPoint(x: -wd * 1.3, y: len * 1.08),
                       control2: CGPoint(x: -wd * 1.5, y: len * 0.3))
            p.closeSubpath()
        default:
            p.move(to: CGPoint(x: 0, y: 0.1))
            p.addCurve(to: CGPoint(x: 0, y: len), control1: CGPoint(x: wd * 1.3, y: len * 0.35),
                       control2: CGPoint(x: wd * 0.5, y: len * 0.85))
            p.addCurve(to: CGPoint(x: 0, y: 0.1), control1: CGPoint(x: -wd * 0.5, y: len * 0.85),
                       control2: CGPoint(x: -wd * 1.3, y: len * 0.35))
            p.closeSubpath()
        }
        return p
    }

    private static func flowerTexture(_ key: String, draw: (CGContext) -> Void) -> SKTexture {
        let side = flowerCanvas * flowerRef
        return GardenArt.make(key, size: CGSize(width: side, height: side), scale: 2.5) { ctx, s in
            ctx.translateBy(x: s.width / 2, y: s.height / 2)
            ctx.scaleBy(x: flowerRef, y: flowerRef)
            draw(ctx)
        }
    }

    /// The flower's petals and heart (flower radius 1).
    static func flowerPetals(_ i: Int) -> SKTexture {
        let look = flowerLook(i)
        return flowerTexture("flower-petals-\(i)") { ctx in
            for layer in 0..<look.layers {
                let scale: CGFloat = layer == 0 ? 1 : 0.66
                let offset: CGFloat = layer == 0 ? 0 : CGFloat.pi / CGFloat(look.count)
                let base: GardenInk = layer == 0 ? look.petal : look.petal.lighter(0.25)
                let shade: GardenInk = layer == 0 ? look.shade : look.shade.lighter(0.15)
                let petal = petalPath(shape: look.shape, len: scale, width: look.width * scale)
                for k in 0..<look.count {
                    let a = offset + CGFloat(k) / CGFloat(look.count) * 2 * CGFloat.pi
                    let t = CGAffineTransform(rotationAngle: a)
                    let p = CGMutablePath()
                    p.addPath(petal, transform: t)
                    GardenPainter.stroke(ctx, p, shade.darker(0.35).with(alpha: 0.45), width: 0.05)
                    let tip = CGPoint(x: -sin(a) * scale, y: cos(a) * scale)
                    GardenPainter.clipped(ctx, p) {
                        GardenPainter.linear(ctx, [shade, base, base.lighter(0.18)], [0, 0.55, 1], from: .zero,
                                             to: tip)
                    }
                    let vein = CGMutablePath()
                    vein.move(to: CGPoint(x: -sin(a) * scale * 0.25, y: cos(a) * scale * 0.25))
                    vein.addLine(to: CGPoint(x: -sin(a) * scale * 0.72, y: cos(a) * scale * 0.72))
                    GardenPainter.stroke(ctx, vein, shade.with(alpha: 0.35), width: 0.03)
                }
            }
            let heart = GardenPainter.circle(.zero, 0.27)
            GardenPainter.stroke(ctx, heart, look.seeds.darker(0.3).with(alpha: 0.6), width: 0.05)
            GardenPainter.clipped(ctx, heart) {
                GardenPainter.radial(ctx, [look.heart.lighter(0.3), look.heart, look.heart.darker(0.25)], [0, 0.6, 1],
                                     center: CGPoint(x: -0.06, y: 0.07), radius: 0.3)
            }
            let seeds = CGMutablePath()
            for k in 0..<9 {
                let a = CGFloat(k) / 9 * 2 * CGFloat.pi
                seeds.addPath(GardenPainter.circle(CGPoint(x: cos(a) * 0.16, y: sin(a) * 0.16), 0.032))
            }
            for k in 0..<4 {
                let a = CGFloat(k) / 4 * 2 * CGFloat.pi + 0.4
                seeds.addPath(GardenPainter.circle(CGPoint(x: cos(a) * 0.07, y: sin(a) * 0.07), 0.028))
            }
            GardenPainter.fill(ctx, seeds, look.seeds.with(alpha: 0.85))
            GardenPainter.fill(ctx, GardenPainter.circle(CGPoint(x: -0.09, y: 0.11), 0.05), GardenInk(1, 1, 1, 0.55))
        }
    }

    static func leafPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 0.2))
        p.addCurve(to: CGPoint(x: 0, y: 1.3), control1: CGPoint(x: 0.44, y: 0.5), control2: CGPoint(x: 0.3, y: 1.1))
        p.addCurve(to: CGPoint(x: 0, y: 0.2), control1: CGPoint(x: -0.3, y: 1.1), control2: CGPoint(x: -0.44, y: 0.5))
        p.closeSubpath()
        return p
    }

    /// The rosette of leaves under a flower.
    static func flowerLeaves(_ i: Int) -> SKTexture {
        flowerTexture("flower-leaves-\(i)") { ctx in
            let leaf = leafPath()
            let n = 5
            let turn = GardenRNG.hash(i, 0x1EAF) * 2 * CGFloat.pi
            for k in 0..<n {
                let a = turn + CGFloat(k) / CGFloat(n) * 2 * CGFloat.pi + GardenRNG.hash(k + i * 7, 0x2EAF) * 0.4
                let len: CGFloat = 0.86 + GardenRNG.hash(k + i * 11, 0x3EAF) * 0.16
                let t = CGAffineTransform(rotationAngle: a).scaledBy(x: len, y: len)
                let p = CGMutablePath()
                p.addPath(leaf, transform: t)
                GardenPainter.stroke(ctx, p, GardenInk(hex: 0x0F3A20, alpha: 0.6), width: 0.05)
                let tip = CGPoint(x: -sin(a) * 1.3 * len, y: cos(a) * 1.3 * len)
                GardenPainter.clipped(ctx, p) {
                    GardenPainter.linear(ctx, [GardenInk(hex: 0x1F5E36), GardenInk(hex: 0x3F9452),
                                               GardenInk(hex: 0x5DB566)], [0, 0.6, 1], from: .zero, to: tip)
                }
                let vein = CGMutablePath()
                vein.move(to: CGPoint(x: -sin(a) * 0.25 * len, y: cos(a) * 0.25 * len))
                vein.addLine(to: CGPoint(x: -sin(a) * 1.15 * len, y: cos(a) * 1.15 * len))
                GardenPainter.stroke(ctx, vein, GardenInk(hex: 0x8FD89A, alpha: 0.45), width: 0.04)
            }
        }
    }

    /// An eaten flower: a bitten stalk, a wilted leaf, two fallen petals.
    static func flowerStalk(_ i: Int) -> SKTexture {
        let look = flowerLook(i)
        return flowerTexture("flower-stalk-\(i)") { ctx in
            let mound = GardenPainter.ellipse(CGPoint(x: 0, y: -0.05), 0.5, 0.42)
            GardenPainter.fill(ctx, mound, GardenInk(hex: 0x3A2A20, alpha: 0.85))
            GardenPainter.fill(ctx, GardenPainter.ellipse(CGPoint(x: -0.06, y: 0.02), 0.32, 0.26),
                               GardenInk(hex: 0x4E3A2C, alpha: 0.9))
            let stem = CGMutablePath()
            stem.move(to: .zero)
            stem.addQuadCurve(to: CGPoint(x: 0.6, y: -0.36), control: CGPoint(x: 0.38, y: 0.16))
            GardenPainter.stroke(ctx, stem, GardenInk(hex: 0x3E4A22), width: 0.16)
            GardenPainter.stroke(ctx, stem, GardenInk(hex: 0x7A8A42), width: 0.09)
            GardenPainter.fill(ctx, GardenPainter.circle(.zero, 0.1), GardenInk(hex: 0x9AAA52))
            let leaf = CGMutablePath()
            leaf.addPath(leafPath(), transform: CGAffineTransform(translationX: 0.6, y: -0.36)
                .rotated(by: -2.3).scaledBy(x: 0.42, y: 0.42))
            GardenPainter.fill(ctx, leaf, GardenInk(hex: 0x76763A, alpha: 0.95))
            let wilted = look.petal.mixed(GardenInk(hex: 0x8A8090), 0.55)
            let petal = petalPath(shape: 1, len: 0.42, width: 0.12)
            let spots: [(CGFloat, CGFloat, CGFloat)] = [(-0.55, 0.32, 0.6), (-0.3, -0.6, 2.4)]
            for (x, y, a) in spots {
                let p = CGMutablePath()
                p.addPath(petal, transform: CGAffineTransform(translationX: x, y: y).rotated(by: a))
                GardenPainter.fill(ctx, p, wilted.with(alpha: 0.85))
            }
        }
    }

    /// Builds every flower and firefly texture now.
    static func warmFlowers(count: Int) {
        _ = firefly
        _ = fireflyWings
        for i in 0..<max(count, 1) {
            _ = flowerPetals(i)
            _ = flowerLeaves(i)
            _ = flowerStalk(i)
        }
    }
}
