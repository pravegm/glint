import SpriteKit
import UIKit

/// Procedural art for the mirror half: the dawn sky, the sun, clouds, the horizon of each world, the brass frame,
/// the glass, the phone fallback's lever (cached textures).
@MainActor
enum MirrorArt {
    // MARK: Sky

    /// 0 night, 1 dawn, 2 day: vertical gradients, horizon at the bottom.
    static func sky(_ i: Int) -> SKTexture {
        let k = min(max(i, 0), 2)
        return GardenArt.make("sky-\(k)", size: CGSize(width: 4, height: 256), scale: 1) { ctx, s in
            let colors: [GardenInk]
            let locs: [CGFloat]
            switch k {
            case 0:
                colors = [GardenInk(hex: 0x5A3366), GardenInk(hex: 0x2E2659), GardenInk(hex: 0x151B40),
                          GardenInk(hex: 0x0A0F2E)]
                locs = [0, 0.3, 0.7, 1]
            case 1:
                colors = [GardenInk(hex: 0xFFC27A), GardenInk(hex: 0xFF8C7A), GardenInk(hex: 0xC25E92),
                          GardenInk(hex: 0x58438F), GardenInk(hex: 0x2A2E6E)]
                locs = [0, 0.18, 0.44, 0.76, 1]
            default:
                colors = [GardenInk(hex: 0xFFE6B0), GardenInk(hex: 0xFFD2A6), GardenInk(hex: 0xA6DAEE),
                          GardenInk(hex: 0x63B3E2), GardenInk(hex: 0x3F8FD2)]
                locs = [0, 0.14, 0.42, 0.78, 1]
            }
            GardenPainter.linear(ctx, colors, locs, from: CGPoint(x: 2, y: 0), to: CGPoint(x: 2, y: s.height))
        }
    }

    // MARK: Sun

    static var sunDisc: SKTexture {
        GardenArt.make("sun-disc", size: CGSize(width: 128, height: 128)) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            GardenPainter.radial(ctx, [GardenInk(hex: 0xFFFFF4), GardenInk(hex: 0xFFF3C4), GardenInk(hex: 0xFFD677),
                                       GardenInk(hex: 0xFFB54A), GardenInk(hex: 0xFFB54A, alpha: 0)],
                                 [0, 0.5, 0.84, 0.95, 1], center: c, radius: s.width / 2)
        }
    }

    // MARK: Clouds (near-white; tinted by the time of day)

    static func cloud(_ i: Int) -> SKTexture {
        let k = ((i % 3) + 3) % 3
        return GardenArt.make("cloud-\(k)", size: CGSize(width: 240, height: 110), scale: 1.5) { ctx, s in
            var rng = GardenRNG(seed: 0xC1_0D + UInt64(k) * 17)
            let base = s.height * 0.3
            let p = CGMutablePath()
            p.addPath(GardenPainter.roundRect(CGRect(x: s.width * 0.1, y: base - 12, width: s.width * 0.8, height: 26), 13))
            let puffs = 5 + k
            for j in 0..<puffs {
                let f = (CGFloat(j) + 0.5) / CGFloat(puffs)
                let x = s.width * (0.16 + 0.68 * f)
                let mid = 1 - abs(f - 0.5) * 1.6
                let r = (18 + 22 * mid) * rng.range(0.85, 1.15)
                p.addPath(GardenPainter.circle(CGPoint(x: x, y: base + r * 0.45), r))
            }
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 8, color: GardenInk(1, 1, 1, 0.55).cg)
            GardenPainter.fill(ctx, p, GardenInk.white)
            ctx.restoreGState()
            GardenPainter.clipped(ctx, p) {
                GardenPainter.linear(ctx, [GardenInk(hex: 0xC9C0E2), GardenInk(hex: 0xF4F0FF), GardenInk.white],
                                     [0, 0.4, 1], from: CGPoint(x: 0, y: base - 12), to: CGPoint(x: 0, y: s.height))
            }
        }
    }

    // MARK: The horizon of each world (white silhouettes, tileable across the width; tint them)

    static let hillsSize = CGSize(width: 512, height: 160)

    static func hills(world: Int, near: Bool) -> SKTexture {
        let wd = min(max(world, 1), 3)
        return GardenArt.make("hills-\(wd)-\(near ? 1 : 0)", size: hillsSize, scale: 1.5) { ctx, s in
            let W = s.width
            let H = s.height
            let p = CGMutablePath()
            switch (wd, near) {
            case (1, false):
                // Meadow: far rolling hills.
                p.move(to: CGPoint(x: 0, y: 0))
                var x: CGFloat = 0
                while x <= W {
                    let f = x / W * 2 * CGFloat.pi
                    p.addLine(to: CGPoint(x: x, y: H * (0.44 + 0.12 * sin(2 * f + 0.5) + 0.06 * sin(5 * f + 1.3))))
                    x += 4
                }
                p.addLine(to: CGPoint(x: W, y: 0))
                p.closeSubpath()
            case (1, true):
                // Meadow: near hills with round trees and a little windmill.
                func ground(_ x: CGFloat) -> CGFloat {
                    let f = x / W * 2 * CGFloat.pi
                    return H * (0.24 + 0.08 * sin(3 * f + 2) + 0.04 * sin(7 * f))
                }
                p.move(to: CGPoint(x: 0, y: 0))
                var x: CGFloat = 0
                while x <= W {
                    p.addLine(to: CGPoint(x: x, y: ground(x)))
                    x += 4
                }
                p.addLine(to: CGPoint(x: W, y: 0))
                p.closeSubpath()
                let trees: [(CGFloat, CGFloat)] = [(60, 15), (84, 11), (150, 17), (318, 13), (342, 18), (440, 12)]
                for (tx, tr) in trees {
                    let gy = ground(tx)
                    p.addRect(CGRect(x: tx - 2, y: gy - 2, width: 4, height: tr * 1.1))
                    p.addPath(GardenPainter.circle(CGPoint(x: tx, y: gy + tr * 1.3), tr))
                }
                let mx: CGFloat = 236
                let my = ground(mx)
                let tower = CGMutablePath()
                tower.move(to: CGPoint(x: mx - 9, y: my - 2))
                tower.addLine(to: CGPoint(x: mx + 9, y: my - 2))
                tower.addLine(to: CGPoint(x: mx + 4, y: my + 46))
                tower.addLine(to: CGPoint(x: mx - 4, y: my + 46))
                tower.closeSubpath()
                p.addPath(tower)
                let hub = CGPoint(x: mx, y: my + 46)
                for k in 0..<4 {
                    let a = CGFloat(k) * CGFloat.pi / 2 + 0.35
                    let blade = CGMutablePath()
                    blade.addRect(CGRect(x: 3, y: -3.5, width: 30, height: 7))
                    p.addPath(blade, transform: CGAffineTransform(translationX: hub.x, y: hub.y).rotated(by: a))
                }
            case (2, false):
                // Rooftops: a far skyline of blocks, spires and a dome.
                var rng = GardenRNG(seed: 0x5C_2A)
                var x: CGFloat = 0
                p.move(to: CGPoint(x: 0, y: 0))
                while x < W {
                    let bw = min(rng.range(22, 48), W - x)
                    let bh = H * rng.range(0.32, 0.62)
                    p.addLine(to: CGPoint(x: x, y: bh))
                    if rng.unit() < 0.22 {
                        p.addLine(to: CGPoint(x: x + bw * 0.5, y: bh + 18))
                    }
                    p.addLine(to: CGPoint(x: x + bw, y: bh))
                    x += bw
                }
                p.addLine(to: CGPoint(x: W, y: 0))
                p.closeSubpath()
                p.addPath(GardenPainter.circle(CGPoint(x: W * 0.62, y: H * 0.6), 20))
                p.addRect(CGRect(x: W * 0.62 - 1.5, y: H * 0.6, width: 3, height: 34))
            case (2, true):
                // Rooftops: near pitched roofs with chimneys and an aerial.
                var rng = GardenRNG(seed: 0x400F)
                p.addRect(CGRect(x: 0, y: 0, width: W, height: H * 0.16))
                var x: CGFloat = -10
                while x < W - 20 {
                    let hw = rng.range(40, 70)
                    let wallTop = H * rng.range(0.2, 0.32)
                    let peak = wallTop + hw * rng.range(0.3, 0.45)
                    let house = CGMutablePath()
                    house.move(to: CGPoint(x: x, y: 0))
                    house.addLine(to: CGPoint(x: x, y: wallTop))
                    house.addLine(to: CGPoint(x: x + hw / 2, y: peak))
                    house.addLine(to: CGPoint(x: x + hw, y: wallTop))
                    house.addLine(to: CGPoint(x: x + hw, y: 0))
                    house.closeSubpath()
                    p.addPath(house)
                    let cx = x + hw * rng.range(0.62, 0.78)
                    let roofY = wallTop + (peak - wallTop) * (1 - abs(cx - (x + hw / 2)) / (hw / 2))
                    p.addRect(CGRect(x: cx - 4, y: roofY - 4, width: 8, height: 16))
                    if rng.unit() < 0.35 {
                        p.addRect(CGRect(x: x + hw / 2 - 1, y: peak - 2, width: 2, height: 16))
                        p.addRect(CGRect(x: x + hw / 2 - 8, y: peak + 10, width: 16, height: 2))
                    }
                    x += hw * rng.range(0.82, 1.05)
                }
            case (3, false):
                // Harbour: a far headland with a lighthouse, the sea flat beyond.
                p.addRect(CGRect(x: 0, y: 0, width: W, height: H * 0.16))
                let head = CGMutablePath()
                head.move(to: CGPoint(x: W * 0.06, y: 0))
                head.addCurve(to: CGPoint(x: W * 0.3, y: H * 0.36), control1: CGPoint(x: W * 0.12, y: H * 0.3),
                              control2: CGPoint(x: W * 0.2, y: H * 0.36))
                head.addCurve(to: CGPoint(x: W * 0.46, y: 0), control1: CGPoint(x: W * 0.38, y: H * 0.36),
                              control2: CGPoint(x: W * 0.42, y: H * 0.2))
                head.closeSubpath()
                p.addPath(head)
                let lx = W * 0.3
                let ly = H * 0.34
                let tower = CGMutablePath()
                tower.move(to: CGPoint(x: lx - 8, y: ly))
                tower.addLine(to: CGPoint(x: lx + 8, y: ly))
                tower.addLine(to: CGPoint(x: lx + 5, y: ly + 44))
                tower.addLine(to: CGPoint(x: lx - 5, y: ly + 44))
                tower.closeSubpath()
                p.addPath(tower)
                p.addRect(CGRect(x: lx - 7, y: ly + 44, width: 14, height: 10))
                let cap = CGMutablePath()
                cap.move(to: CGPoint(x: lx - 8, y: ly + 54))
                cap.addLine(to: CGPoint(x: lx + 8, y: ly + 54))
                cap.addLine(to: CGPoint(x: lx, y: ly + 64))
                cap.closeSubpath()
                p.addPath(cap)
            default:
                // Harbour: near water, a pier and two sailing boats.
                p.addRect(CGRect(x: 0, y: 0, width: W, height: H * 0.14))
                for k in 0..<6 {
                    p.addRect(CGRect(x: W * 0.05 + CGFloat(k) * 14, y: H * 0.1, width: 4, height: H * 0.16))
                }
                p.addRect(CGRect(x: W * 0.04, y: H * 0.24, width: 84, height: 6))
                let boats: [(CGFloat, CGFloat)] = [(0.6, 1.0), (0.84, 0.75)]
                for (bx, k) in boats {
                    let x0 = W * bx
                    let y0 = H * 0.12
                    let hull = CGMutablePath()
                    hull.move(to: CGPoint(x: x0 - 26 * k, y: y0 + 8 * k))
                    hull.addLine(to: CGPoint(x: x0 + 26 * k, y: y0 + 8 * k))
                    hull.addLine(to: CGPoint(x: x0 + 18 * k, y: y0))
                    hull.addLine(to: CGPoint(x: x0 - 18 * k, y: y0))
                    hull.closeSubpath()
                    p.addPath(hull)
                    p.addRect(CGRect(x: x0 - 1.2 * k, y: y0 + 8 * k, width: 2.4 * k, height: 44 * k))
                    let sail = CGMutablePath()
                    sail.move(to: CGPoint(x: x0 + 2 * k, y: y0 + 12 * k))
                    sail.addLine(to: CGPoint(x: x0 + 22 * k, y: y0 + 12 * k))
                    sail.addLine(to: CGPoint(x: x0 + 2 * k, y: y0 + 50 * k))
                    sail.closeSubpath()
                    p.addPath(sail)
                }
            }
            GardenPainter.fill(ctx, p, GardenInk.white)
            if wd == 3 && !near {
                // The lighthouse's lamp (left transparent; the scene puts a glow there).
                ctx.setBlendMode(.clear)
                ctx.fill(CGRect(x: W * 0.3 - 4, y: H * 0.34 + 46, width: 8, height: 6))
                ctx.setBlendMode(.normal)
            }
        }
    }

    /// Where the far harbour's lighthouse lamp sits on a hills tile (fraction of the tile's size).
    static let lampFraction = CGPoint(x: 0.3, y: (160 * 0.34 + 49) / 160)

    // MARK: Brass frame

    /// One edge of moulding: length 64 along x (stretched), the profile across y from outer (y 0) to inner (top).
    static var frameEdge: SKTexture {
        GardenArt.make("frame-edge", size: CGSize(width: 64, height: 24), scale: 3) { ctx, s in
            let colors: [GardenInk] = [GardenInk(hex: 0x4A2E0C), GardenInk(hex: 0xB07A2A), GardenInk(hex: 0xFFE6A0),
                                       GardenInk(hex: 0xE0AE4E), GardenInk(hex: 0xA8732A), GardenInk(hex: 0x6E4718),
                                       GardenInk(hex: 0xF2CF7A), GardenInk(hex: 0xC48E3A), GardenInk(hex: 0x2E1C06)]
            let locs: [CGFloat] = [0, 0.1, 0.24, 0.4, 0.58, 0.7, 0.8, 0.9, 1]
            GardenPainter.linear(ctx, colors, locs, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
            // Fine brushed lines along the length.
            var rng = GardenRNG(seed: 0xB2A5)
            for _ in 0..<10 {
                let y = rng.range(1, s.height - 1)
                ctx.setFillColor(GardenInk(1, 1, 1, rng.range(0.04, 0.12)).cg)
                ctx.fill(CGRect(x: 0, y: y, width: s.width, height: 0.5))
            }
        }
    }

    /// A brass corner boss with a citrine.
    static var frameCorner: SKTexture {
        GardenArt.make("frame-corner", size: CGSize(width: 48, height: 48), scale: 3) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            // Four leaves of filigree.
            for k in 0..<4 {
                let a = CGFloat(k) * CGFloat.pi / 2 + CGFloat.pi / 4
                let leaf = CGMutablePath()
                GardenPainter.addEllipse(leaf, CGPoint(x: c.x + cos(a) * 14, y: c.y + sin(a) * 14), 9, 4.5, angle: a)
                GardenPainter.stroke(ctx, leaf, GardenInk(hex: 0x3A2408), width: 1.6)
                GardenPainter.clipped(ctx, leaf) {
                    GardenPainter.linear(ctx, [GardenInk(hex: 0xFFE39A), GardenInk(hex: 0xB07A2A)], [0, 1],
                                         from: CGPoint(x: 0, y: s.height), to: CGPoint(x: s.width, y: 0))
                }
            }
            let boss = GardenPainter.circle(c, 13)
            GardenPainter.stroke(ctx, boss, GardenInk(hex: 0x3A2408), width: 2)
            GardenPainter.clipped(ctx, boss) {
                GardenPainter.linear(ctx, [GardenInk(hex: 0xFFF0B8), GardenInk(hex: 0xD9A441), GardenInk(hex: 0x7A5214)],
                                     [0, 0.5, 1], from: CGPoint(x: c.x - 13, y: c.y + 13),
                                     to: CGPoint(x: c.x + 13, y: c.y - 13))
            }
            let gem = GardenPainter.circle(c, 6.5)
            GardenPainter.stroke(ctx, gem, GardenInk(hex: 0x5A3A0C), width: 1.4)
            GardenPainter.clipped(ctx, gem) {
                GardenPainter.radial(ctx, [GardenInk(hex: 0xFFF6C8), GardenInk(hex: 0xFFB43A), GardenInk(hex: 0xB0560E)],
                                     [0, 0.45, 1], center: CGPoint(x: c.x - 2, y: c.y + 2), radius: 8)
            }
            GardenPainter.fill(ctx, GardenPainter.circle(CGPoint(x: c.x - 2.2, y: c.y + 2.4), 1.6),
                               GardenInk(1, 1, 1, 0.9))
        }
    }

    // MARK: Glass and light

    /// Two soft diagonal streaks across the glass (white).
    static var sheen: SKTexture {
        GardenArt.make("sheen", size: CGSize(width: 256, height: 256), scale: 1) { ctx, s in
            let streaks: [(CGFloat, CGFloat, CGFloat)] = [(0.3, 40, 0.5), (0.5, 14, 0.35)]
            for (f, wd, a) in streaks {
                let p = CGMutablePath()
                let x = s.width * f
                p.move(to: CGPoint(x: x - wd, y: s.height + 10))
                p.addLine(to: CGPoint(x: x + wd, y: s.height + 10))
                p.addLine(to: CGPoint(x: x + wd - s.width * 0.6, y: -10))
                p.addLine(to: CGPoint(x: x - wd - s.width * 0.6, y: -10))
                p.closeSubpath()
                GardenPainter.clipped(ctx, p) {
                    GardenPainter.linear(ctx, [GardenInk(1, 1, 1, 0), GardenInk(1, 1, 1, a), GardenInk(1, 1, 1, 0)],
                                         [0, 0.5, 1], from: CGPoint(x: x - wd - s.width * 0.3, y: s.height / 2),
                                         to: CGPoint(x: x + wd - s.width * 0.3, y: s.height / 2))
                }
            }
        }
    }

    /// A shaft of light: narrow at the top (the sun), wide and fading at the bottom.
    static var shaft: SKTexture {
        GardenArt.make("shaft", size: CGSize(width: 128, height: 256), scale: 1) { ctx, s in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: s.width * 0.42, y: s.height))
            p.addLine(to: CGPoint(x: s.width * 0.58, y: s.height))
            p.addLine(to: CGPoint(x: s.width, y: 0))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.closeSubpath()
            GardenPainter.clipped(ctx, p) {
                GardenPainter.linear(ctx, [GardenInk(1, 1, 1, 0.15), GardenInk(1, 1, 1, 0.8), GardenInk(1, 1, 1, 0.1)],
                                     [0, 0.75, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: s.height))
            }
            // Soften the sides.
            ctx.setBlendMode(.destinationIn)
            GardenPainter.linear(ctx, [GardenInk(1, 1, 1, 0), GardenInk.white, GardenInk(1, 1, 1, 0)], [0, 0.5, 1],
                                 from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            ctx.setBlendMode(.normal)
        }
    }

    // MARK: The phone fallback's lever

    /// The lever's slot (length along y, stretched).
    static var leverTrack: SKTexture {
        GardenArt.make("lever-track", size: CGSize(width: 20, height: 200), scale: 2) { ctx, s in
            let outer = GardenPainter.roundRect(CGRect(x: 1, y: 1, width: s.width - 2, height: s.height - 2), 9)
            GardenPainter.stroke(ctx, outer, GardenInk(hex: 0x3A2408), width: 2)
            GardenPainter.clipped(ctx, outer) {
                GardenPainter.linear(ctx, [GardenInk(hex: 0xFFE39A), GardenInk(hex: 0xC48E3A), GardenInk(hex: 0x7A5214)],
                                     [0, 0.5, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            }
            let slot = GardenPainter.roundRect(CGRect(x: 6, y: 6, width: s.width - 12, height: s.height - 12), 4)
            GardenPainter.fill(ctx, slot, GardenInk(hex: 0x1A0F04))
            GardenPainter.clipped(ctx, slot) {
                GardenPainter.linear(ctx, [GardenInk(0, 0, 0, 0.6), GardenInk(0, 0, 0, 0)], [0, 1],
                                     from: CGPoint(x: 6, y: 0), to: CGPoint(x: s.width - 6, y: 0))
            }
            // Notches along the slot.
            for k in 1..<8 {
                let y = s.height * CGFloat(k) / 8
                ctx.setFillColor(GardenInk(hex: 0x3A2408, alpha: 0.8).cg)
                ctx.fill(CGRect(x: 1, y: y - 0.6, width: 4, height: 1.2))
                ctx.fill(CGRect(x: s.width - 5, y: y - 0.6, width: 4, height: 1.2))
            }
        }
    }

    /// The lever's brass knob.
    static var leverKnob: SKTexture {
        GardenArt.make("lever-knob", size: CGSize(width: 56, height: 56), scale: 3) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            GardenPainter.radial(ctx, [GardenInk(0, 0, 0, 0.45), GardenInk(0, 0, 0, 0)], [0, 1],
                                 center: CGPoint(x: c.x + 2, y: c.y - 3), radius: 27)
            let ball = GardenPainter.circle(c, 19)
            GardenPainter.stroke(ctx, ball, GardenInk(hex: 0x3A2408), width: 2.4)
            GardenPainter.clipped(ctx, ball) {
                GardenPainter.radial(ctx, [GardenInk(hex: 0xFFF6CC), GardenInk(hex: 0xE8B552), GardenInk(hex: 0x8A5A18)],
                                     [0, 0.45, 1], center: CGPoint(x: c.x - 6, y: c.y + 7), radius: 26)
            }
            // Grip ridges.
            let ridges = CGMutablePath()
            for k in -2...2 {
                let y = c.y + CGFloat(k) * 5
                let half = sqrt(max(0, 19 * 19 - (y - c.y) * (y - c.y))) * 0.62
                ridges.move(to: CGPoint(x: c.x - half, y: y))
                ridges.addLine(to: CGPoint(x: c.x + half, y: y))
            }
            GardenPainter.stroke(ctx, ridges, GardenInk(hex: 0x7A5214, alpha: 0.55), width: 1.4)
            GardenPainter.fill(ctx, GardenPainter.ellipse(CGPoint(x: c.x - 6, y: c.y + 8), 6, 3.5),
                               GardenInk(1, 1, 1, 0.7))
        }
    }

    /// Builds every mirror texture now.
    static func warm() {
        for i in 0..<3 { _ = sky(i); _ = cloud(i) }
        for w in 1...3 {
            _ = hills(world: w, near: false)
            _ = hills(world: w, near: true)
        }
        _ = sunDisc
        _ = frameEdge
        _ = frameCorner
        _ = sheen
        _ = shaft
        _ = leverTrack
        _ = leverKnob
    }
}
