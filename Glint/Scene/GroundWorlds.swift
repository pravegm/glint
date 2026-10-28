import CoreGraphics
import UIKit

/// R2b: the grounds of worlds 2 and 3, painted in the canonical garden (x = d from the crease, y = u), like the lawn.
/// Rooftops: terracotta and slate tiles with moss, chimney pots near the edges, a gutter and a stone ledge as the
/// flower edge, the flowers in window boxes. Harbour: weathered boardwalk planks with rope, puddles (the band glints on
/// them: `GardenMath.puddles`), a dock beam at the edge, the flowers in pots. Each keeps the crease's ink and darkening
/// so the shade and the glooms read the same in every world; the night and dawn versions share one seed.
enum GroundWorlds {
    private static func pick(_ warm: Bool, _ night: UInt32, _ dawn: UInt32, _ a: CGFloat = 1) -> GardenInk {
        GardenInk(hex: warm ? dawn : night, alpha: a)
    }

    /// The flower row in the texture: radius and centre x.
    static func flowerGeometry(_ w: CGFloat, _ h: CGFloat) -> (r: CGFloat, x: CGFloat) {
        let r = GardenMath.flowerRadius(depth: w, span: h, count: GardenMath.flowerCount)
        let x = CGFloat(GardenMath.flowerD(depth: w, span: h, count: GardenMath.flowerCount)) * w
        return (r, x)
    }

    static func laneY(_ i: Int, _ h: CGFloat) -> CGFloat {
        (CGFloat(i) + 0.5) / CGFloat(GardenMath.flowerCount) * h
    }

    /// The crease's ink (stains reaching out, a dark gradient) and a soft vignette along the two side edges.
    static func creaseAndEdges(_ ctx: CGContext, _ w: CGFloat, _ h: CGFloat, ink: GardenInk, seed: UInt64) {
        var rng = GardenRNG(seed: seed)
        GardenPainter.linear(ctx, [ink.with(alpha: 0.88), ink.with(alpha: 0.4), ink.with(alpha: 0)], [0, 0.4, 1],
                             from: CGPoint(x: 0, y: 0), to: CGPoint(x: w * 0.11, y: 0))
        let stains = CGMutablePath()
        var y: CGFloat = rng.range(4, 14)
        while y < h {
            let len = rng.range(0.025, 0.1) * w
            let t = rng.range(5, 13)
            let wig = rng.range(-6, 6)
            stains.move(to: CGPoint(x: 0, y: y - t / 2))
            stains.addQuadCurve(to: CGPoint(x: len, y: y + wig), control: CGPoint(x: len * 0.7, y: y - t * 0.4))
            stains.addQuadCurve(to: CGPoint(x: 0, y: y + t / 2), control: CGPoint(x: len * 0.7, y: y + t * 0.4 + wig))
            stains.closeSubpath()
            y += rng.range(14, 30)
        }
        GardenPainter.fill(ctx, stains, ink.with(alpha: 0.45))
        let edge = min(h * 0.07, 40)
        GardenPainter.linear(ctx, [ink.with(alpha: 0.3), ink.with(alpha: 0)], [0, 1], from: CGPoint(x: 0, y: 0),
                             to: CGPoint(x: 0, y: edge))
        GardenPainter.linear(ctx, [ink.with(alpha: 0), ink.with(alpha: 0.3)], [0, 1], from: CGPoint(x: 0, y: h - edge),
                             to: CGPoint(x: 0, y: h))
    }

    // MARK: Rooftops

    static func drawRooftops(_ ctx: CGContext, _ s: CGSize, warm: Bool) {
        let w = s.width
        let h = s.height
        var rng = GardenRNG(seed: 0x5C0F_7EE5)
        let fg = flowerGeometry(w, h)
        let ledgeX = max(fg.x - fg.r * 1.45, w * 0.72)
        let gutterW = max(8, fg.r * 0.36)
        let tilesEnd = ledgeX - gutterW

        // Mortar under the tiles.
        ctx.setFillColor(pick(warm, 0x1A1018, 0x4A2418).cg)
        ctx.fill(CGRect(x: 0, y: 0, width: tilesEnd, height: h))

        // Tiles in staggered rows parallel to the crease; patches of slate among the terracotta.
        let th = GardenMath.clamp(w * 0.05, 18, 30)
        let tw = th * 0.92
        let colours: [GardenInk] = warm
            ? [GardenInk(hex: 0xC2603A), GardenInk(hex: 0xD4784A), GardenInk(hex: 0xA85032), GardenInk(hex: 0xE08A58),
               GardenInk(hex: 0x5E6E86), GardenInk(hex: 0x74849A)]
            : [GardenInk(hex: 0x5C3842), GardenInk(hex: 0x6C4248), GardenInk(hex: 0x50303C), GardenInk(hex: 0x764A4E),
               GardenInk(hex: 0x2E3A52), GardenInk(hex: 0x3A4862)]
        var buckets: [CGMutablePath] = []
        for _ in 0..<colours.count { buckets.append(CGMutablePath()) }
        let shadow = CGMutablePath()
        let shine = CGMutablePath()
        var row = 0
        var x0: CGFloat = 0
        while x0 < tilesEnd {
            let off: CGFloat = row % 2 == 0 ? 0 : tw / 2
            var y: CGFloat = -tw + off
            var col = 0
            while y < h {
                let tileW = min(th - 1.5, tilesEnd - x0 - 1)
                if tileW > 2 {
                    let rect = CGRect(x: x0 + 0.75, y: y + 0.75, width: tileW, height: tw - 1.5)
                    let patch = GardenRNG.hash((row / 3) * 131 + col / 3, 0x51A7)
                    let isSlate = patch < 0.14
                    let pickK = Int(rng.unit() * (isSlate ? 2 : 4))
                    let idx = isSlate ? 4 + min(pickK, 1) : min(pickK, 3)
                    buckets[idx].addPath(GardenPainter.roundRect(rect, 3))
                    shadow.addRect(CGRect(x: rect.minX, y: rect.minY, width: min(rect.width * 0.3, 7), height: rect.height))
                    shine.move(to: CGPoint(x: rect.maxX - 1.5, y: rect.minY + 2.5))
                    shine.addLine(to: CGPoint(x: rect.maxX - 1.5, y: rect.maxY - 2.5))
                }
                y += tw
                col += 1
            }
            x0 += th
            row += 1
        }
        for (i, path) in buckets.enumerated() { GardenPainter.fill(ctx, path, colours[i]) }
        GardenPainter.fill(ctx, shadow, pick(warm, 0x0E0810, 0x3A1408, 0.38))
        GardenPainter.stroke(ctx, shine, pick(warm, 0x8A6A7A, 0xFFD0A0, 0.4), width: 1.2)

        // Moss, thicker in the damp near the crease.
        let moss = pick(warm, 0x2E4E46, 0x6E8A3A)
        let mossN = Int(min(80, w * h / 4500))
        let mossDots = CGMutablePath()
        for _ in 0..<mossN {
            let c = CGPoint(x: tilesEnd * pow(rng.unit(), 1.6), y: rng.range(0, h))
            let r = rng.range(6, 20)
            GardenPainter.radial(ctx, [moss.with(alpha: 0.5), moss.with(alpha: 0)], [0, 1], center: c, radius: r)
            for _ in 0..<4 {
                let q = CGPoint(x: c.x + rng.range(-r, r) * 0.7, y: c.y + rng.range(-r, r) * 0.7)
                let dr = rng.range(0.8, 1.8)
                mossDots.addEllipse(in: CGRect(x: q.x - dr, y: q.y - dr, width: dr * 2, height: dr * 2))
            }
        }
        GardenPainter.fill(ctx, mossDots, moss.lighter(0.2).with(alpha: 0.7))

        // Chimney stacks near the side edges, out of the main play.
        let brick = pick(warm, 0x4A2A30, 0x9A4A30)
        let pot = pick(warm, 0x3E2C30, 0xB86A40)
        let chims: [(CGFloat, CGFloat)] = h > 500 ? [(0.36, 0.06), (0.64, 0.94), (0.22, 0.95)] : [(0.36, 0.07), (0.62, 0.93)]
        for (fx, fy) in chims {
            let c = CGPoint(x: tilesEnd * fx, y: h * fy)
            let cw = th * 2.3
            let chh = th * 1.5
            let body = CGRect(x: c.x - cw / 2, y: c.y - chh / 2, width: cw, height: chh)
            GardenPainter.fill(ctx, GardenPainter.roundRect(body.offsetBy(dx: 5, dy: -3), 4), GardenInk(0, 0, 0, 0.35))
            let bp = GardenPainter.roundRect(body, 4)
            GardenPainter.fill(ctx, bp, brick)
            GardenPainter.clipped(ctx, bp) {
                let lines = CGMutablePath()
                var bx = body.minX + 6
                while bx < body.maxX {
                    lines.move(to: CGPoint(x: bx, y: body.minY))
                    lines.addLine(to: CGPoint(x: bx, y: body.maxY))
                    bx += 7
                }
                GardenPainter.stroke(ctx, lines, brick.darker(0.35).with(alpha: 0.6), width: 0.8)
            }
            GardenPainter.stroke(ctx, bp, brick.darker(0.5), width: 1.6)
            for side in [CGFloat(-1), CGFloat(1)] {
                let pc = CGPoint(x: c.x + side * cw * 0.22, y: c.y)
                let pr = chh * 0.3
                GardenPainter.fill(ctx, GardenPainter.circle(pc, pr), pot)
                GardenPainter.stroke(ctx, GardenPainter.circle(pc, pr), pot.darker(0.45), width: 1.4)
                GardenPainter.fill(ctx, GardenPainter.circle(pc, pr * 0.55), GardenInk(hex: 0x0A0608))
                GardenPainter.fill(ctx, GardenPainter.circle(CGPoint(x: pc.x - pr * 0.4, y: pc.y + pr * 0.4), pr * 0.2),
                                   pot.lighter(0.35).with(alpha: 0.7))
            }
        }

        // The gutter: a metal half-pipe with brackets.
        let gr = CGRect(x: tilesEnd, y: 0, width: gutterW, height: h)
        GardenPainter.clipped(ctx, CGPath(rect: gr, transform: nil)) {
            let g0 = pick(warm, 0x1E2430, 0x4A5260)
            let g1 = pick(warm, 0x5A6478, 0xC8D0D8)
            GardenPainter.linear(ctx, [g0, g1, g0.darker(0.2)], [0, 0.45, 1], from: CGPoint(x: gr.minX, y: 0),
                                 to: CGPoint(x: gr.maxX, y: 0))
        }
        var by: CGFloat = 24
        ctx.setFillColor(pick(warm, 0x101420, 0x30343C).cg)
        while by < h {
            ctx.fill(CGRect(x: gr.minX + gutterW * 0.15, y: by, width: gutterW * 0.7, height: 3))
            by += 72
        }

        // The stone ledge (the flower edge) with window boxes.
        let ledge = pick(warm, 0x3A3446, 0xB8A890)
        let lr = CGRect(x: ledgeX, y: 0, width: w - ledgeX, height: h)
        GardenPainter.clipped(ctx, CGPath(rect: lr, transform: nil)) {
            GardenPainter.linear(ctx, [ledge.darker(0.25), ledge, ledge.darker(0.12)], [0, 0.3, 1],
                                 from: CGPoint(x: lr.minX, y: 0), to: CGPoint(x: lr.maxX, y: 0))
            let joints = CGMutablePath()
            var jy: CGFloat = 30
            while jy < h {
                joints.move(to: CGPoint(x: lr.minX, y: jy))
                joints.addLine(to: CGPoint(x: lr.maxX, y: jy))
                jy += 46
            }
            GardenPainter.stroke(ctx, joints, ledge.darker(0.4).with(alpha: 0.35), width: 1)
        }
        let wood = pick(warm, 0x4A3426, 0x8A5A32)
        let soil = pick(warm, 0x241812, 0x4A2E1A)
        for i in 0..<GardenMath.flowerCount {
            let cy = laneY(i, h)
            let bw = fg.r * 2.7
            let box = CGRect(x: fg.x - bw / 2, y: cy - bw / 2, width: bw, height: bw)
            GardenPainter.fill(ctx, GardenPainter.roundRect(box.offsetBy(dx: 3, dy: -3), 4), GardenInk(0, 0, 0, 0.35))
            let bp = GardenPainter.roundRect(box, 4)
            GardenPainter.fill(ctx, bp, wood)
            GardenPainter.stroke(ctx, bp, wood.darker(0.5), width: 1.6)
            let inner = box.insetBy(dx: fg.r * 0.22, dy: fg.r * 0.22)
            GardenPainter.fill(ctx, GardenPainter.roundRect(inner, 3), soil)
            let planks = CGMutablePath()
            planks.move(to: CGPoint(x: box.minX + 2, y: box.midY))
            planks.addLine(to: CGPoint(x: inner.minX, y: box.midY))
            planks.move(to: CGPoint(x: inner.maxX, y: box.midY))
            planks.addLine(to: CGPoint(x: box.maxX - 2, y: box.midY))
            GardenPainter.stroke(ctx, planks, wood.darker(0.4), width: 1)
            for corner in [CGPoint(x: box.minX + 4, y: box.minY + 4), CGPoint(x: box.maxX - 4, y: box.minY + 4),
                           CGPoint(x: box.minX + 4, y: box.maxY - 4), CGPoint(x: box.maxX - 4, y: box.maxY - 4)] {
                GardenPainter.fill(ctx, GardenPainter.circle(corner, 1.3), pick(warm, 0x8A8A96, 0x3A2A1A))
            }
        }

        creaseAndEdges(ctx, w, h, ink: pick(warm, 0x07040C, 0x1A0C08), seed: 0x2EAF)
    }

    // MARK: Harbour

    static func drawHarbour(_ ctx: CGContext, _ s: CGSize, warm: Bool) {
        let w = s.width
        let h = s.height
        var rng = GardenRNG(seed: 0x4A2B_0A2D)
        let fg = flowerGeometry(w, h)
        let beamW = max(10, fg.r * 0.34)
        let plankEnd = w - beamW

        // The seams between planks.
        ctx.setFillColor(pick(warm, 0x12151A, 0x3A2C20).cg)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Planks run along u; their joints are staggered.
        let pw = GardenMath.clamp(w * 0.065, 22, 38)
        let colours: [GardenInk] = warm
            ? [GardenInk(hex: 0x9A8268), GardenInk(hex: 0xA88E72), GardenInk(hex: 0x8A735C), GardenInk(hex: 0xB49C7E)]
            : [GardenInk(hex: 0x3A4048), GardenInk(hex: 0x444A50), GardenInk(hex: 0x34383E), GardenInk(hex: 0x4C5056)]
        var buckets: [CGMutablePath] = []
        for _ in 0..<colours.count { buckets.append(CGMutablePath()) }
        let grain = CGMutablePath()
        let nails = CGMutablePath()
        var x0: CGFloat = 0
        while x0 < plankEnd {
            let pwNow = min(pw, plankEnd - x0)
            var y: CGFloat = -rng.range(0, 120)
            while y < h && pwNow > 3 {
                let len = rng.range(90, 220)
                let rect = CGRect(x: x0 + 0.8, y: y + 0.8, width: pwNow - 1.6, height: len - 1.6)
                buckets[min(Int(rng.unit() * 4), 3)].addRect(rect)
                for fx in [CGFloat(0.28), CGFloat(0.72)] {
                    for ny in [rect.minY + 5, rect.maxY - 5] {
                        nails.addEllipse(in: CGRect(x: rect.minX + rect.width * fx - 1.1, y: ny - 1.1, width: 2.2, height: 2.2))
                    }
                }
                for k in 1...3 {
                    let gx = rect.minX + rect.width * CGFloat(k) / 4 + rng.range(-2, 2)
                    grain.move(to: CGPoint(x: gx, y: rect.minY + 3))
                    grain.addQuadCurve(to: CGPoint(x: gx + rng.range(-2, 2), y: rect.maxY - 3),
                                       control: CGPoint(x: gx + rng.range(-3, 3), y: rect.midY))
                }
                y += len
            }
            x0 += pw
        }
        for (i, path) in buckets.enumerated() { GardenPainter.fill(ctx, path, colours[i]) }
        GardenPainter.stroke(ctx, grain, pick(warm, 0x5A6068, 0x6A5440, 0.4), width: 0.8)
        GardenPainter.fill(ctx, nails, pick(warm, 0x7A848E, 0x3A3028, 0.9))

        // Weathering: salt-bleached and damp patches.
        for _ in 0..<Int(min(70, w * h / 4000)) {
            let c = CGPoint(x: rng.range(0, plankEnd), y: rng.range(0, h))
            let light = rng.unit() < 0.5
            let col = light ? pick(warm, 0x6A7480, 0xD8C8A8) : pick(warm, 0x0E1218, 0x4A3828)
            GardenPainter.radial(ctx, [col.with(alpha: 0.14), col.with(alpha: 0)], [0, 1], center: c,
                                 radius: rng.range(12, 40))
        }

        // Puddles (the band glints on them).
        let water = pick(warm, 0x0A1A2C, 0x2E5A70)
        let rim = pick(warm, 0x5E8AA8, 0xC8E4EE)
        let sky = pick(warm, 0x7FA8C8, 0xFFF0D0)
        for (i, pd) in GardenMath.puddles(depth: w, span: h).enumerated() {
            let c = CGPoint(x: CGFloat(pd.d) * w, y: CGFloat(pd.u) * h)
            let r = pd.r
            let ph = CGFloat(i) * 1.7
            let blob = GardenPainter.loop(16) { t in
                let k: CGFloat = 1 + 0.16 * sin(3 * t + ph) + 0.08 * sin(5 * t + ph * 2)
                return CGPoint(x: c.x + cos(t) * r * 0.85 * k, y: c.y + sin(t) * r * 1.25 * k)
            }
            GardenPainter.fill(ctx, blob, water.with(alpha: 0.86))
            GardenPainter.clipped(ctx, blob) {
                GardenPainter.linear(ctx, [sky.with(alpha: 0), sky.with(alpha: 0.32), sky.with(alpha: 0)], [0, 0.5, 1],
                                     from: CGPoint(x: c.x - r, y: c.y - r), to: CGPoint(x: c.x + r, y: c.y + r))
            }
            GardenPainter.stroke(ctx, blob, rim.with(alpha: 0.35), width: 1.4)
        }

        // A coil of rope near a side edge.
        let rope = pick(warm, 0x6A604E, 0xC8A878)
        let ropeDark = pick(warm, 0x3A3428, 0x7A6040)
        if h > 260 {
            let cc = CGPoint(x: w * 0.46, y: h * 0.06)
            let rr = min(w, h) * 0.045
            let coil = CGMutablePath()
            let turns: CGFloat = 3
            var t: CGFloat = 0
            coil.move(to: CGPoint(x: cc.x + rr * 0.2, y: cc.y))
            while t <= turns * 2 * CGFloat.pi {
                let rad = rr * (0.2 + 0.8 * t / (turns * 2 * CGFloat.pi))
                coil.addLine(to: CGPoint(x: cc.x + cos(t) * rad, y: cc.y + sin(t) * rad))
                t += 0.25
            }
            let ropeW = max(rr * 0.24, 3)
            GardenPainter.stroke(ctx, coil, GardenInk(0, 0, 0, 0.35), width: ropeW + 2)
            GardenPainter.stroke(ctx, coil, rope, width: ropeW)
            ctx.setLineDash(phase: 0, lengths: [2, 3])
            GardenPainter.stroke(ctx, coil, ropeDark.with(alpha: 0.6), width: ropeW * 0.6)
            ctx.setLineDash(phase: 0, lengths: [])
        }

        // The dock beam at the flower edge, with a rope along it.
        let beam = pick(warm, 0x22262C, 0x5A4632)
        ctx.setFillColor(beam.cg)
        ctx.fill(CGRect(x: plankEnd, y: 0, width: beamW, height: h))
        let line = CGMutablePath()
        line.move(to: CGPoint(x: plankEnd + beamW * 0.5, y: 0))
        line.addLine(to: CGPoint(x: plankEnd + beamW * 0.5, y: h))
        GardenPainter.stroke(ctx, line, rope, width: beamW * 0.42)
        ctx.setLineDash(phase: 0, lengths: [2.5, 3.5])
        GardenPainter.stroke(ctx, line, ropeDark.with(alpha: 0.6), width: beamW * 0.3)
        ctx.setLineDash(phase: 0, lengths: [])

        // Flowers in pots.
        let potCol = pick(warm, 0x5A3A36, 0xC06A42)
        let potSoil = pick(warm, 0x1E1410, 0x4A3020)
        for i in 0..<GardenMath.flowerCount {
            let c = CGPoint(x: fg.x, y: laneY(i, h))
            let pr = fg.r * 1.32
            GardenPainter.fill(ctx, GardenPainter.ellipse(CGPoint(x: c.x + 4, y: c.y - 3), pr, pr), GardenInk(0, 0, 0, 0.35))
            GardenPainter.fill(ctx, GardenPainter.circle(c, pr), potCol)
            GardenPainter.stroke(ctx, GardenPainter.circle(c, pr), potCol.darker(0.45), width: 1.6)
            GardenPainter.fill(ctx, GardenPainter.circle(c, fg.r * 1.08), potSoil)
            let arc = CGMutablePath()
            arc.addArc(center: c, radius: pr - 2, startAngle: 1.9, endAngle: 2.9, clockwise: false)
            GardenPainter.stroke(ctx, arc, potCol.lighter(0.35).with(alpha: 0.7), width: 1.6)
        }

        creaseAndEdges(ctx, w, h, ink: pick(warm, 0x04060C, 0x140C08), seed: 0x3EAF)
    }
}
