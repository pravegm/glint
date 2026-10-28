import SpriteKit
import UIKit

// MARK: - Colour

/// An sRGB colour for the scene's procedural art. Scene-private (Contracts has no colour type, and nothing here
/// extends a shared type, so nothing can clash with another module's helpers).
struct GardenInk: Equatable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat

    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(hex: UInt32, alpha: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
        a = alpha
    }

    func mixed(_ o: GardenInk, _ t: CGFloat) -> GardenInk {
        let k = min(max(t, 0), 1)
        return GardenInk(r + (o.r - r) * k, g + (o.g - g) * k, b + (o.b - b) * k, a + (o.a - a) * k)
    }

    func with(alpha: CGFloat) -> GardenInk { GardenInk(r, g, b, alpha) }
    func lighter(_ t: CGFloat) -> GardenInk { mixed(GardenInk(1, 1, 1, a), t) }
    func darker(_ t: CGFloat) -> GardenInk { mixed(GardenInk(0, 0, 0, a), t) }

    var cg: CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
    var ui: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }

    static let white = GardenInk(1, 1, 1)
    static let black = GardenInk(0, 0, 0)
}

/// The scene's named colours (GAME-DESIGN §10: a dawn garden, warm gold light, inky shadows).
enum GardenPalette {
    static let backdrop = GardenInk(hex: 0x0B1030)
    static let gold = GardenInk(hex: 0xFFC94A)
    static let goldHot = GardenInk(hex: 0xFFE7A6)
    static let amber = GardenInk(hex: 0xFFA43A)
    static let bandWash = GardenInk(hex: 0xFFB04A)
    static let bandCore = GardenInk(hex: 0xFFD78A)
    static let spark = GardenInk(hex: 0xFFE28A)
    static let ember = GardenInk(hex: 0xFFB347)
    static let inkDeep = GardenInk(hex: 0x120B22)
    static let inkMid = GardenInk(hex: 0x261A40)
    static let inkTop = GardenInk(hex: 0x4A3470)
    static let inkOutline = GardenInk(hex: 0x07040D)
    static let inkAura = GardenInk(hex: 0x8A66E0)
    static let inkRim = GardenInk(hex: 0xBBA4FF)
    static let inkLip = GardenInk(hex: 0xA88FE6)
    static let steam = GardenInk(hex: 0xE9E0FF)
    static let eyeWhite = GardenInk(hex: 0xFFFFFF)
    static let eyeShade = GardenInk(hex: 0xDCD5F2)
    static let pupil = GardenInk(hex: 0x150E26)
    static let night = GardenInk(hex: 0x050A1E)
    static let firefly = GardenInk(hex: 0xD8FF6A)
    static let fireflyHot = GardenInk(hex: 0xFF4A32)
    static let petals: [GardenInk] = [GardenInk(hex: 0xFF8FB0), GardenInk(hex: 0xFFC46A), GardenInk(hex: 0xC6A6FF),
                                      GardenInk(hex: 0xFFE6A0), GardenInk(hex: 0xFFB3A0)]
}

// MARK: - Randomness (cosmetic only, never the simulation's SeededRandom)

/// xorshift64 seeded through SplitMix, for cosmetic placement and FX.
struct GardenRNG {
    private var state: UInt64

    init(seed: UInt64) {
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        state = z == 0 ? 0x9E37_79B9_7F4A_7C15 : z
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// 0 ..< 1
    mutating func unit() -> CGFloat {
        CGFloat(Double(next() >> 11) / 9_007_199_254_740_992.0)
    }

    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }

    mutating func sign() -> CGFloat { unit() < 0.5 ? -1 : 1 }

    /// A stateless 0 ..< 1 hash of an index (stable per-item phases).
    static func hash(_ i: Int, _ salt: UInt64) -> CGFloat {
        var z = UInt64(bitPattern: Int64(i)) &+ (salt &+ 1) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return CGFloat(Double(z >> 11) / 9_007_199_254_740_992.0)
    }
}

// MARK: - Maths

enum GardenMath {
    /// The band's profile, copied from Core so the art never waits on Core to compile:
    /// `Tuning.bandCoreHalfWidth` = 0.050, `Tuning.bandEdgeHalfWidth` = 0.085, `Tuning.bandMin` = −0.2.
    static let bandCore: Double = 0.050
    static let bandEdge: Double = 0.085
    static let bandMin: Double = -0.2
    /// Flowers per row (`Tuning.flowerCount`); the scene follows `snapshot.flowers.count` when it differs.
    static let flowerCount: Int = 5

    static func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }
    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }

    static func smooth(_ e0: CGFloat, _ e1: CGFloat, _ x: CGFloat) -> CGFloat {
        if abs(e1 - e0) < 0.000_001 { return x < e0 ? 0 : 1 }
        let t = clamp((x - e0) / (e1 - e0), 0, 1)
        return t * t * (3 - 2 * t)
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    /// Frame-rate independent exponential approach.
    static func approach(_ v: CGFloat, _ target: CGFloat, rate: CGFloat, dt: CGFloat) -> CGFloat {
        let k: CGFloat = 1 - exp(-rate * max(dt, 0))
        return v + (target - v) * k
    }

    static func easeOutBack(_ t: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.70158
        let c3: CGFloat = c1 + 1
        let x: CGFloat = clamp(t, 0, 1) - 1
        return 1 + c3 * x * x * x + c1 * x * x
    }

    static func easeOut(_ t: CGFloat) -> CGFloat {
        let x = clamp(t, 0, 1)
        return 1 - (1 - x) * (1 - x)
    }

    /// The band's light at floor distance `d` (Core's `Tuning.intensity`): 1 within ±core of the centre, a smoothstep
    /// down to 0 at ±edge.
    static func intensity(d: Double, band: Double) -> Double {
        let x = abs(d - band)
        if x <= bandCore { return 1 }
        if x >= bandEdge { return 0 }
        let t = (x - bandCore) / (bandEdge - bandCore)
        return 1 - t * t * (3 - 2 * t)
    }

    /// The world a mode is drawn in (1 Meadow, 2 Rooftops, 3 Harbour). Levels 1–10, 11–20, 21–30 (GAME-DESIGN §6);
    /// Long Night plays by the harbour; Today's Dawn in the meadow.
    static func world(for mode: PlayMode) -> Int {
        switch mode {
        case .level(let n):
            return min(max((n - 1) / 10 + 1, 1), 3)
        case .endless:
            return 3
        case .daily(_):
            return 1
        }
    }

    /// How far the dawn has come for the art, 0…1. Levels and the daily: `snapshot.sun`. Long Night: `sun` is the
    /// night's depth, so the sun hangs low and sinks as the night deepens.
    static func dawn(_ s: DawnSnapshot) -> CGFloat {
        let v = CGFloat(clamp(s.sun.isFinite ? s.sun : 0, 0, 1))
        switch s.mode {
        case .endless:
            return 0.3 * (1 - v)
        case .level(_), .daily(_):
            return v
        }
    }

    /// The flowers' radius (points) for a garden.
    static func flowerRadius(depth: CGFloat, span: CGFloat, count: Int) -> CGFloat {
        let lane = span / CGFloat(max(count, 1))
        return max(min(lane * 0.34, depth * 0.072), 8)
    }

    /// The flowers' row, in floor `d` (their centres): just inside the flower edge.
    static func flowerD(depth: CGFloat, span: CGFloat, count: Int) -> Double {
        guard depth > 0 else { return 0.93 }
        let r = flowerRadius(depth: depth, span: span, count: count)
        return Double(1 - r * 1.3 / depth)
    }
}

// MARK: - CoreGraphics painting (every context here is y up)

enum GardenPainter {
    static func fill(_ ctx: CGContext, _ path: CGPath, _ c: GardenInk) {
        ctx.addPath(path)
        ctx.setFillColor(c.cg)
        ctx.fillPath()
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ c: GardenInk, width: CGFloat) {
        ctx.addPath(path)
        ctx.setStrokeColor(c.cg)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    static func linear(_ ctx: CGContext, _ colors: [GardenInk], _ locations: [CGFloat], from a: CGPoint,
                       to b: CGPoint) {
        guard colors.count >= 2, colors.count == locations.count else { return }
        let cgs: [CGColor] = colors.map { $0.cg }
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgs as CFArray,
                                 locations: locations) else { return }
        ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radial(_ ctx: CGContext, _ colors: [GardenInk], _ locations: [CGFloat], center: CGPoint,
                       radius: CGFloat) {
        guard radius > 0, colors.count >= 2, colors.count == locations.count else { return }
        let cgs: [CGColor] = colors.map { $0.cg }
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgs as CFArray,
                                 locations: locations) else { return }
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                               options: [])
    }

    /// Runs `body` clipped to `path`.
    static func clipped(_ ctx: CGContext, _ path: CGPath, _ body: () -> Void) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        body()
        ctx.restoreGState()
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry), transform: nil)
    }

    /// An ellipse centred at `c`, turned by `angle`, added to `path`.
    static func addEllipse(_ path: CGMutablePath, _ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, angle: CGFloat) {
        let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: angle)
        path.addEllipse(in: CGRect(x: -rx, y: -ry, width: 2 * rx, height: 2 * ry), transform: t)
    }

    static func roundRect(_ r: CGRect, _ corner: CGFloat) -> CGPath {
        let k = max(0, min(corner, min(r.width, r.height) / 2 - 0.01))
        return CGPath(roundedRect: r, cornerWidth: k, cornerHeight: k, transform: nil)
    }

    /// A closed Catmull-Rom curve through `pts`.
    static func smoothClosed(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        let n = pts.count
        guard n > 2 else { return p }
        p.move(to: pts[0])
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n]
            let p1 = pts[i]
            let p2 = pts[(i + 1) % n]
            let p3 = pts[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        p.closeSubpath()
        return p
    }

    /// A smooth closed loop sampled from `f(angle)` at `count` points.
    static func loop(_ count: Int, _ f: (CGFloat) -> CGPoint) -> CGPath {
        var pts: [CGPoint] = []
        let n = max(count, 3)
        pts.reserveCapacity(n)
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(n) * 2 * CGFloat.pi
            pts.append(f(t))
        }
        return smoothClosed(pts)
    }
}

// MARK: - The texture cache

/// Textures generated in code once and cached (no texture work in the frame loop).
@MainActor
enum GardenArt {
    private static var cache: [String: SKTexture] = [:]
    /// Textures drawn since launch (tests: a warm frame loop never adds any).
    private(set) static var builds: Int = 0

    /// Textures in the cache now.
    static var count: Int { cache.count }

    static func has(_ key: String) -> Bool { cache[key] != nil }

    /// Drops cached textures whose key starts with `prefix`, except `keeping`.
    static func purge(prefix: String, keeping: [String]) {
        let doomed = cache.keys.filter { $0.hasPrefix(prefix) && !keeping.contains($0) }
        for k in doomed { cache[k] = nil }
    }

    /// Draws into a fresh image (y-up context, origin bottom-left, in points) and caches it under `key`.
    static func make(_ key: String, size: CGSize, scale: CGFloat = 2, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let sz = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = max(scale, 0.25)
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: sz, format: fmt).image { rc in
            let ctx = rc.cgContext
            ctx.translateBy(x: 0, y: sz.height)
            ctx.scaleBy(x: 1, y: -1)
            draw(ctx, sz)
        }
        let t = SKTexture(image: img)
        t.filteringMode = .linear
        cache[key] = t
        builds += 1
        return t
    }

    private static func w(_ a: CGFloat) -> GardenInk { GardenInk(1, 1, 1, a) }

    // MARK: Soft shapes (white; tint with the sprite colour)

    static var dot: SKTexture {
        make("dot", size: CGSize(width: 32, height: 32)) { ctx, s in
            GardenPainter.radial(ctx, [w(1), w(1), w(0)], [0, 0.5, 1], center: CGPoint(x: s.width / 2, y: s.height / 2),
                                 radius: s.width / 2)
        }
    }

    static var soft: SKTexture {
        make("soft", size: CGSize(width: 64, height: 64), scale: 1) { ctx, s in
            GardenPainter.radial(ctx, [w(1), w(0.5), w(0)], [0, 0.42, 1],
                                 center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    static var glow: SKTexture {
        make("glow", size: CGSize(width: 128, height: 128)) { ctx, s in
            GardenPainter.radial(ctx, [w(1), w(0.42), w(0.12), w(0)], [0, 0.22, 0.55, 1],
                                 center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    /// A four-point twinkle with a soft halo (glints, dew, sparks).
    static var sparkle: SKTexture {
        make("sparkle", size: CGSize(width: 48, height: 48)) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            GardenPainter.radial(ctx, [w(0.6), w(0)], [0, 1], center: c, radius: s.width * 0.3)
            let r = s.width * 0.48
            let k = s.width * 0.06
            let p = CGMutablePath()
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
            p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
            p.closeSubpath()
            GardenPainter.fill(ctx, p, GardenInk.white)
        }
    }

    /// A thin ring with a soft halo (pop shock rings, sweeps).
    static var ring: SKTexture {
        make("ring", size: CGSize(width: 128, height: 128)) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let r = s.width * 0.42
            let steps: [(CGFloat, CGFloat)] = [(16, 0.08), (10, 0.18), (6, 0.4), (3, 0.95)]
            for (lw, a) in steps {
                GardenPainter.stroke(ctx, GardenPainter.circle(c, r), w(a), width: lw)
            }
        }
    }

    /// A sunburst of soft rays (the sun, the sunrise flood).
    static var rays: SKTexture {
        make("rays", size: CGSize(width: 256, height: 256)) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let n = 12
            for i in 0..<n {
                let a0 = CGFloat(i) / CGFloat(n) * 2 * CGFloat.pi
                let half: CGFloat = i % 2 == 0 ? 0.11 : 0.06
                let p = CGMutablePath()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a0 - half) * 140, y: c.y + sin(a0 - half) * 140))
                p.addLine(to: CGPoint(x: c.x + cos(a0 + half) * 140, y: c.y + sin(a0 + half) * 140))
                p.closeSubpath()
                GardenPainter.clipped(ctx, p) {
                    GardenPainter.radial(ctx, [w(0.9), w(0.45), w(0)], [0, 0.4, 1], center: c, radius: 128)
                }
            }
            GardenPainter.radial(ctx, [w(0.8), w(0)], [0, 1], center: c, radius: 40)
        }
    }

    /// A soft dark ellipse for contact shadows (white: tint it).
    static var shadow: SKTexture {
        make("shadow", size: CGSize(width: 64, height: 32), scale: 1) { ctx, s in
            ctx.saveGState()
            ctx.scaleBy(x: 1, y: s.height / s.width)
            GardenPainter.radial(ctx, [w(0.95), w(0.55), w(0)], [0, 0.5, 1],
                                 center: CGPoint(x: s.width / 2, y: s.width / 2), radius: s.width / 2)
            ctx.restoreGState()
        }
    }

    /// Edges dark, centre clear (the mirror's inner shadow). White: tint it.
    static var vignette: SKTexture {
        make("vignette", size: CGSize(width: 256, height: 256), scale: 1) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let cgs: [CGColor] = [w(0).cg, w(0).cg, w(0.5).cg, w(1).cg]
            let locs: [CGFloat] = [0, 0.5, 0.78, 1]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgs as CFArray, locations: locs) {
                ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: s.width * 0.71,
                                       options: [.drawsAfterEndLocation])
            }
        }
    }

    /// Petals for bursts (white with a little shading; tint per colour). Three shapes.
    static func petal(_ i: Int) -> SKTexture {
        let k = ((i % 3) + 3) % 3
        return make("petal-\(k)", size: CGSize(width: 24, height: 32)) { ctx, s in
            let p = CGMutablePath()
            let cx = s.width / 2
            switch k {
            case 0:
                // Teardrop.
                p.move(to: CGPoint(x: cx, y: 2))
                p.addCurve(to: CGPoint(x: cx, y: s.height - 2), control1: CGPoint(x: s.width + 4, y: s.height * 0.35),
                           control2: CGPoint(x: s.width * 0.8, y: s.height))
                p.addCurve(to: CGPoint(x: cx, y: 2), control1: CGPoint(x: s.width * 0.2, y: s.height),
                           control2: CGPoint(x: -4, y: s.height * 0.35))
            case 1:
                // Round.
                p.addEllipse(in: CGRect(x: 2, y: 3, width: s.width - 4, height: s.height - 6))
            default:
                // Heart-tipped.
                p.move(to: CGPoint(x: cx, y: 2))
                p.addCurve(to: CGPoint(x: cx, y: s.height - 7), control1: CGPoint(x: s.width + 2, y: s.height * 0.3),
                           control2: CGPoint(x: s.width + 2, y: s.height + 2))
                p.addCurve(to: CGPoint(x: cx, y: 2), control1: CGPoint(x: -2, y: s.height + 2),
                           control2: CGPoint(x: -2, y: s.height * 0.3))
            }
            p.closeSubpath()
            GardenPainter.clipped(ctx, p) {
                GardenPainter.linear(ctx, [w(0.78), GardenInk.white, GardenInk.white], [0, 0.45, 1],
                                     from: CGPoint(x: cx, y: 0), to: CGPoint(x: cx, y: s.height))
            }
            let vein = CGMutablePath()
            vein.move(to: CGPoint(x: cx, y: 5))
            vein.addLine(to: CGPoint(x: cx, y: s.height * 0.62))
            GardenPainter.stroke(ctx, vein, GardenInk(0.82, 0.82, 0.82, 0.6), width: 1.2)
        }
    }

    /// An irregular droplet of ink (white; tint it dark).
    static var inkDrop: SKTexture {
        make("inkdrop", size: CGSize(width: 32, height: 32)) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let p = GardenPainter.loop(9) { t in
                let k: CGFloat = 1 + 0.16 * sin(3 * t + 0.4) + 0.08 * sin(5 * t + 1.7)
                return CGPoint(x: c.x + cos(t) * 11 * k, y: c.y + sin(t) * 11 * k)
            }
            GardenPainter.fill(ctx, p, GardenInk.white)
            GardenPainter.fill(ctx, GardenPainter.circle(CGPoint(x: c.x + 12, y: c.y + 9), 2.6), GardenInk.white)
        }
    }

    // MARK: Band of light (canonical: x across the band = floor d, y along the garden = u)

    /// The band's intensity profile across ±edge (Core's smoothstep), white. `lines`: faint crisp lips at ±core so the
    /// burning zone reads.
    static func bandProfile(lines: Bool) -> SKTexture {
        make(lines ? "band-core" : "band-wash", size: CGSize(width: 512, height: 4), scale: 1) { ctx, s in
            var colors: [GardenInk] = []
            var locs: [CGFloat] = []
            let n = 40
            for i in 0...n {
                let f = CGFloat(i) / CGFloat(n)
                let dNorm = Double(f) * 2 - 1
                let a = GardenMath.intensity(d: dNorm * GardenMath.bandEdge, band: 0)
                colors.append(w(CGFloat(a)))
                locs.append(f)
            }
            GardenPainter.linear(ctx, colors, locs, from: CGPoint(x: 0, y: 2), to: CGPoint(x: s.width, y: 2))
            if lines {
                let core = CGFloat(GardenMath.bandCore / GardenMath.bandEdge)
                let x0 = s.width * (0.5 - core / 2)
                let x1 = s.width * (0.5 + core / 2)
                ctx.setFillColor(w(0.35).cg)
                ctx.fill(CGRect(x: x0 - 1.5, y: 0, width: 3, height: s.height))
                ctx.fill(CGRect(x: x1 - 1.5, y: 0, width: 3, height: s.height))
            }
        }
    }

    /// A wide, faint glow around the band (atmosphere; ±1 of the sprite's half-width).
    static var bandBloom: SKTexture {
        make("band-bloom", size: CGSize(width: 256, height: 4), scale: 1) { ctx, s in
            var colors: [GardenInk] = []
            var locs: [CGFloat] = []
            let n = 24
            for i in 0...n {
                let f = CGFloat(i) / CGFloat(n)
                let x = f * 2 - 1
                colors.append(w(exp(-3.2 * x * x) * (1 - x * x)))
                locs.append(f)
            }
            GardenPainter.linear(ctx, colors, locs, from: CGPoint(x: 0, y: 2), to: CGPoint(x: s.width, y: 2))
        }
    }

    /// Soft light streaks along d inside the band profile (the shimmer layer).
    static var bandRays: SKTexture {
        make("band-rays", size: CGSize(width: 128, height: 512), scale: 1) { ctx, s in
            var rng = GardenRNG(seed: 0xBA_4D)
            for _ in 0..<46 {
                let y = rng.range(0, s.height)
                let t = rng.range(3, 16)
                let a = rng.range(0.25, 0.75)
                GardenPainter.linear(ctx, [w(0), w(a), w(0)], [0, 0.5, 1], from: CGPoint(x: 0, y: y - t),
                                     to: CGPoint(x: 0, y: y + t))
            }
            // Keep only what lies inside the band's profile.
            ctx.setBlendMode(.destinationIn)
            var colors: [GardenInk] = []
            var locs: [CGFloat] = []
            let n = 20
            for i in 0...n {
                let f = CGFloat(i) / CGFloat(n)
                let dNorm = Double(f) * 2 - 1
                colors.append(w(CGFloat(GardenMath.intensity(d: dNorm * GardenMath.bandEdge, band: 0))))
                locs.append(f)
            }
            GardenPainter.linear(ctx, colors, locs, from: CGPoint(x: 0, y: 0), to: CGPoint(x: s.width, y: 0))
            ctx.setBlendMode(.normal)
        }
    }

    /// Light pooled in the crease: brightest at x = 0, falling away into the garden.
    static var creaseGlow: SKTexture {
        make("crease-glow", size: CGSize(width: 256, height: 4), scale: 1) { ctx, s in
            var colors: [GardenInk] = []
            var locs: [CGFloat] = []
            let n = 16
            for i in 0...n {
                let f = CGFloat(i) / CGFloat(n)
                colors.append(w(exp(-3.4 * f) * (1 - f)))
                locs.append(f)
            }
            GardenPainter.linear(ctx, colors, locs, from: CGPoint(x: 0, y: 2), to: CGPoint(x: s.width, y: 2))
        }
    }

    /// A thin gaussian line (the crease's lit seam), white.
    static var line: SKTexture {
        make("line", size: CGSize(width: 16, height: 4), scale: 1) { ctx, s in
            GardenPainter.linear(ctx, [w(0), w(1), w(0)], [0, 0.5, 1], from: CGPoint(x: 0, y: 2),
                                 to: CGPoint(x: s.width, y: 2))
        }
    }

    /// The crease seam: a dark fold with faint lips (coloured; not tinted).
    static var seam: SKTexture {
        make("seam", size: CGSize(width: 16, height: 4), scale: 1) { ctx, s in
            let d = GardenInk(hex: 0x03040A)
            GardenPainter.linear(ctx, [d.with(alpha: 0), GardenInk(1, 1, 1, 0.10), d.with(alpha: 0.9),
                                       GardenInk(1, 1, 1, 0.06), d.with(alpha: 0)],
                                 [0, 0.22, 0.5, 0.78, 1], from: CGPoint(x: 0, y: 2), to: CGPoint(x: s.width, y: 2))
        }
    }

    /// Ink pooled along the crease, reaching out in soft tendrils (white; tint it dark). x = 0 at the crease.
    static var creaseInk: SKTexture {
        make("crease-ink", size: CGSize(width: 160, height: 640), scale: 1) { ctx, s in
            GardenPainter.linear(ctx, [w(0.92), w(0.55), w(0)], [0, 0.18, 0.42], from: CGPoint(x: 0, y: 0),
                                 to: CGPoint(x: s.width, y: 0))
            var rng = GardenRNG(seed: 0x1C_4E)
            var y: CGFloat = 8
            let tendrils = CGMutablePath()
            while y < s.height - 8 {
                let len = rng.range(0.28, 0.9) * s.width
                let t = rng.range(7, 18)
                let wig = rng.range(-10, 10)
                tendrils.move(to: CGPoint(x: 0, y: y - t / 2))
                tendrils.addCurve(to: CGPoint(x: len, y: y + wig), control1: CGPoint(x: len * 0.45, y: y - t * 0.5),
                                  control2: CGPoint(x: len * 0.8, y: y + wig - t * 0.3))
                tendrils.addCurve(to: CGPoint(x: 0, y: y + t / 2), control1: CGPoint(x: len * 0.8, y: y + wig + t * 0.3),
                                  control2: CGPoint(x: len * 0.45, y: y + t * 0.5))
                tendrils.closeSubpath()
                if rng.unit() < 0.5 {
                    tendrils.addEllipse(in: CGRect(x: len + rng.range(3, 9), y: y + wig - 2.5, width: 5, height: 5))
                }
                y += rng.range(20, 40)
            }
            GardenPainter.fill(ctx, tendrils, w(0.42))
        }
    }

    /// Night rolling in: opaque, then a soft leading edge at x = width.
    static var nightRoll: SKTexture {
        make("night-roll", size: CGSize(width: 256, height: 4), scale: 1) { ctx, s in
            GardenPainter.linear(ctx, [w(0.9), w(0.9), w(0.55), w(0)], [0, 0.72, 0.88, 1], from: CGPoint(x: 0, y: 2),
                                 to: CGPoint(x: s.width, y: 2))
        }
    }

    // MARK: The lawn (canonical: x = d from the crease, y = u)

    static func groundKey(depth: CGFloat, span: CGFloat, warm: Bool) -> String {
        let w = Int((max(depth, 8) / 4).rounded() * 4)
        let h = Int((max(span, 8) / 4).rounded() * 4)
        return "ground-\(w)x\(h)-\(warm ? 1 : 0)"
    }

    /// The whole lawn for a garden of `depth` × `span` points (cached per size). `warm`: the sunrise palette.
    static func ground(depth: CGFloat, span: CGFloat, warm: Bool) -> SKTexture {
        let w = (max(depth, 8) / 4).rounded() * 4
        let h = (max(span, 8) / 4).rounded() * 4
        let scale: CGFloat = min(1.5, 1800 / max(w, h))
        let pal = warm ? GroundPalette.dawn : GroundPalette.night
        return make(groundKey(depth: depth, span: span, warm: warm), size: CGSize(width: w, height: h), scale: scale) {
            ctx, s in
            drawGround(ctx, s, pal)
        }
    }

    /// Paints the lawn. Both palettes use the same seed, so the night and dawn lawns line up exactly and crossfade.
    static func drawGround(_ ctx: CGContext, _ s: CGSize, _ p: GroundPalette) {
        let w = s.width
        let h = s.height
        let area = w * h
        // Base: dark at the crease (shadows live there), lighter towards the flowers.
        GardenPainter.linear(ctx, [p.crease, p.low, p.mid, p.edge], [0, 0.17, 0.62, 1],
                             from: CGPoint(x: 0, y: h / 2), to: CGPoint(x: w, y: h / 2))
        var rng = GardenRNG(seed: 0x6A2D_51C3)

        // Mowing stripes along d (very soft).
        let stripes = 9
        ctx.setFillColor(p.light.with(alpha: 0.05).cg)
        for i in 0..<stripes where i % 2 == 0 {
            ctx.fill(CGRect(x: 0, y: h * CGFloat(i) / CGFloat(stripes), width: w, height: h / CGFloat(stripes)))
        }

        // Soft blotches of lighter and darker grass.
        let blotches = Int(min(240, area / 2400))
        for _ in 0..<blotches {
            let c = CGPoint(x: rng.range(0, w), y: rng.range(0, h))
            let r = rng.range(16, 60)
            let col = rng.unit() < 0.5 ? p.light : p.dark
            let a = rng.range(0.08, 0.2)
            GardenPainter.radial(ctx, [col.with(alpha: a), col.with(alpha: 0)], [0, 1], center: c, radius: r)
        }

        // Clover patches.
        let clovers = Int(min(90, area / 7000))
        let cloverPath = CGMutablePath()
        for _ in 0..<clovers {
            let c = CGPoint(x: rng.range(w * 0.12, w * 0.84), y: rng.range(0, h))
            let n = Int(rng.range(3, 7))
            for _ in 0..<n {
                let q = CGPoint(x: c.x + rng.range(-9, 9), y: c.y + rng.range(-9, 9))
                let lr = rng.range(1.6, 2.6)
                let turn = rng.range(0, 1)
                for k in 0..<3 {
                    let a = CGFloat(k) * 2.094 + turn
                    cloverPath.addEllipse(in: CGRect(x: q.x + cos(a) * lr - lr, y: q.y + sin(a) * lr - lr,
                                                     width: lr * 2, height: lr * 2))
                }
            }
        }
        GardenPainter.fill(ctx, cloverPath, p.clover.with(alpha: 0.55))

        // Grass tufts, seen from above (three short blades each).
        let tufts = Int(min(1800, area / 200))
        let tuftLight = CGMutablePath()
        let tuftDark = CGMutablePath()
        for i in 0..<tufts {
            let x = rng.range(0, w)
            let y = rng.range(0, h)
            let len = rng.range(2.4, 5.2)
            let base = rng.range(0, 2 * CGFloat.pi)
            let path = i % 3 == 0 ? tuftDark : tuftLight
            for k in 0..<3 {
                let a = base + CGFloat(k - 1) * 0.55
                let tip = CGPoint(x: x + cos(a) * len, y: y + sin(a) * len)
                path.move(to: CGPoint(x: x, y: y))
                path.addQuadCurve(to: tip, control: CGPoint(x: x + cos(a + 0.3) * len * 0.6,
                                                            y: y + sin(a + 0.3) * len * 0.6))
            }
        }
        GardenPainter.stroke(ctx, tuftDark, p.tuftDark.with(alpha: 0.5), width: 1.1)
        GardenPainter.stroke(ctx, tuftLight, p.tuft.with(alpha: 0.32), width: 0.9)

        // Tiny wildflowers (away from the crease).
        let blooms = Int(min(70, area / 9000))
        let bloomPath = CGMutablePath()
        let heartPath = CGMutablePath()
        for _ in 0..<blooms {
            let c = CGPoint(x: rng.range(w * 0.22, w * 0.84), y: rng.range(4, h - 4))
            let pr = rng.range(0.9, 1.4)
            for k in 0..<5 {
                let a = CGFloat(k) * 1.2566
                bloomPath.addEllipse(in: CGRect(x: c.x + cos(a) * pr * 1.3 - pr, y: c.y + sin(a) * pr * 1.3 - pr,
                                                width: pr * 2, height: pr * 2))
            }
            heartPath.addEllipse(in: CGRect(x: c.x - pr * 0.7, y: c.y - pr * 0.7, width: pr * 1.4, height: pr * 1.4))
        }
        GardenPainter.fill(ctx, bloomPath, p.bloom.with(alpha: 0.7))
        GardenPainter.fill(ctx, heartPath, p.bloomHeart.with(alpha: 0.9))

        // Dew: hundreds of tiny drops (the band makes some of them glint).
        let dews = Int(min(520, area / 900))
        let dewPath = CGMutablePath()
        let dewBig = CGMutablePath()
        for i in 0..<dews {
            let c = CGPoint(x: rng.range(w * 0.05, w * 0.86), y: rng.range(0, h))
            let r = rng.range(0.55, 1.25)
            if i % 7 == 0 {
                dewBig.addEllipse(in: CGRect(x: c.x - r * 1.5, y: c.y - r * 1.5, width: r * 3, height: r * 3))
            } else {
                dewPath.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
        }
        GardenPainter.fill(ctx, dewPath, p.dew.with(alpha: 0.4))
        GardenPainter.fill(ctx, dewBig, p.dew.with(alpha: 0.6))

        // Ink stains reaching out of the crease.
        GardenPainter.linear(ctx, [p.ink.with(alpha: 0.85), p.ink.with(alpha: 0.35), p.ink.with(alpha: 0)],
                             [0, 0.4, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: w * 0.1, y: 0))
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
        GardenPainter.fill(ctx, stains, p.ink.with(alpha: 0.45))

        // The flower bed along the flower edge: soil, pebbles, overhanging grass.
        let fr = GardenMath.flowerRadius(depth: w, span: h, count: GardenMath.flowerCount)
        let bedX = max(w - fr * 2.7, w * 0.78)
        let bed = CGMutablePath()
        bed.move(to: CGPoint(x: w + 2, y: -2))
        bed.addLine(to: CGPoint(x: bedX, y: -2))
        var yy: CGFloat = 0
        while yy < h + 12 {
            let ny = yy + 12
            bed.addQuadCurve(to: CGPoint(x: bedX + sin(ny * 0.37) * 2.5, y: ny),
                             control: CGPoint(x: bedX - 3, y: yy + 6))
            yy = ny
        }
        bed.addLine(to: CGPoint(x: w + 2, y: h + 14))
        bed.closeSubpath()
        GardenPainter.clipped(ctx, bed) {
            GardenPainter.linear(ctx, [p.soilDark, p.soil, p.soil.darker(0.15)], [0, 0.35, 1],
                                 from: CGPoint(x: bedX, y: 0), to: CGPoint(x: w, y: 0))
            let specks = CGMutablePath()
            for _ in 0..<Int(min(400, h * 1.2)) {
                let c = CGPoint(x: rng.range(bedX, w), y: rng.range(0, h))
                let r = rng.range(0.5, 1.4)
                specks.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
            GardenPainter.fill(ctx, specks, p.soilDark.with(alpha: 0.6))
        }
        // Pebbles along the bed's edge.
        var py: CGFloat = rng.range(2, 8)
        let stones = CGMutablePath()
        let glints = CGMutablePath()
        while py < h {
            let rx = rng.range(3.6, 5.6)
            let ry = rng.range(3.0, 4.6)
            let c = CGPoint(x: bedX + rng.range(-1.5, 1.5), y: py)
            stones.addEllipse(in: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
            glints.addEllipse(in: CGRect(x: c.x - rx * 0.55, y: c.y + ry * 0.05, width: rx * 0.7, height: ry * 0.6))
            py += rng.range(9, 13)
        }
        GardenPainter.stroke(ctx, stones, p.soilDark.with(alpha: 0.55), width: 1.6)
        GardenPainter.fill(ctx, stones, p.stone)
        GardenPainter.fill(ctx, glints, p.stone.lighter(0.35).with(alpha: 0.7))
        // Grass overhanging the pebbles.
        let over = CGMutablePath()
        var oy: CGFloat = 0
        while oy < h {
            let x = bedX - rng.range(1, 4)
            let len = rng.range(3, 6)
            let a = rng.range(-0.6, 0.6)
            over.move(to: CGPoint(x: x, y: oy))
            over.addLine(to: CGPoint(x: x + cos(a) * len, y: oy + sin(a) * len))
            oy += rng.range(2.5, 5)
        }
        GardenPainter.stroke(ctx, over, p.tuft.with(alpha: 0.45), width: 1)

        // A gentle vignette along the garden's two side edges.
        GardenPainter.linear(ctx, [p.ink.with(alpha: 0.28), p.ink.with(alpha: 0)], [0, 1],
                             from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: min(h * 0.07, 40)))
        GardenPainter.linear(ctx, [p.ink.with(alpha: 0), p.ink.with(alpha: 0.28)], [0, 1],
                             from: CGPoint(x: 0, y: h - min(h * 0.07, 40)), to: CGPoint(x: 0, y: h))
    }
}

/// The lawn's two palettes (GAME-DESIGN §10: deep blue-teal at night, warming to gold at sunrise).
struct GroundPalette {
    let crease: GardenInk
    let low: GardenInk
    let mid: GardenInk
    let edge: GardenInk
    let light: GardenInk
    let dark: GardenInk
    let tuft: GardenInk
    let tuftDark: GardenInk
    let clover: GardenInk
    let dew: GardenInk
    let bloom: GardenInk
    let bloomHeart: GardenInk
    let soil: GardenInk
    let soilDark: GardenInk
    let stone: GardenInk
    let ink: GardenInk

    static let night = GroundPalette(
        crease: GardenInk(hex: 0x040E17), low: GardenInk(hex: 0x0A2B37), mid: GardenInk(hex: 0x114452),
        edge: GardenInk(hex: 0x175258), light: GardenInk(hex: 0x2F7C7C), dark: GardenInk(hex: 0x06212B),
        tuft: GardenInk(hex: 0x56A89E), tuftDark: GardenInk(hex: 0x09323E), clover: GardenInk(hex: 0x0E4A48),
        dew: GardenInk(hex: 0xC8F6FF), bloom: GardenInk(hex: 0xBFD9FF), bloomHeart: GardenInk(hex: 0xFFE9A8),
        soil: GardenInk(hex: 0x261C31), soilDark: GardenInk(hex: 0x140E1C), stone: GardenInk(hex: 0x4E496A),
        ink: GardenInk(hex: 0x0A0614))

    static let dawn = GroundPalette(
        crease: GardenInk(hex: 0x1F1A12), low: GardenInk(hex: 0x465B28), mid: GardenInk(hex: 0x748B38),
        edge: GardenInk(hex: 0x8A9C44), light: GardenInk(hex: 0xC6C268), dark: GardenInk(hex: 0x3B5121),
        tuft: GardenInk(hex: 0xE0DA88), tuftDark: GardenInk(hex: 0x405822), clover: GardenInk(hex: 0x4B772C),
        dew: GardenInk(hex: 0xFFF7D6), bloom: GardenInk(hex: 0xFFFFFF), bloomHeart: GardenInk(hex: 0xFFC94A),
        soil: GardenInk(hex: 0x5E3B24), soilDark: GardenInk(hex: 0x3A2416), stone: GardenInk(hex: 0xB49A72),
        ink: GardenInk(hex: 0x1A1020))
}
