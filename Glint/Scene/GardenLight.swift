import SpriteKit
import UIKit

/// R2: one stretch of the light along u, its light factor running linearly from `f0` (at `u0`) to `f1` (at `u1`).
struct LightPiece: Equatable {
    var u0: Double
    var u1: Double
    var f0: CGFloat
    var f1: CGFloat
}

/// R3/R3b: how strong each light layer is drawn (peak opacity).
/// - Tiles and planks (founder: "perfect"): the additive pool + core at R2 strength.
/// - Grass (R3b, REVIEW-2 P0-3 retuned): the light must read unmistakably as warm sunlight without becoming a slab, so
///   the hue does the work: a gold **wash** (alpha-blended, it replaces part of the teal with gold), a narrow soft cream
///   **line** at the centre (additive), a little additive gold pool as the sun climbs. Brightness stays 1.35–2 × the
///   unlit lawn and R − B rises by ≥ 40 (tested on the real textures).
/// - Long Night: the same recipe in moonlit silver-gold, gentler.
/// The cone (beam) runs from the crease shade into the band's near half and fades out there (no edge), 16–18 %.
struct LightAlphas: Equatable {
    var pool: CGFloat
    var core: CGFloat
    var halo: CGFloat
    var beam: CGFloat
    var trail: CGFloat
    /// R3b: the alpha-blended warm wash (grass only).
    var wash: CGFloat = 0
    /// R3b: the narrow cream line at the band's centre (grass only).
    var line: CGFloat = 0

    static func of(_ style: GroundStyle, dawn: CGFloat, swell: CGFloat) -> LightAlphas {
        let sw = min(max(swell, 0), 1)
        let dw = min(max(dawn, 0), 1)
        switch style {
        case .meadow:
            return LightAlphas(pool: 0.14 * dw + 0.08 * sw, core: 0, halo: 0.015 + 0.08 * sw, beam: 0.16, trail: 0.16,
                               wash: 0.25 + 0.08 * sw, line: 0.09 + 0.28 * dw + 0.15 * sw)
        case .moonlit:
            return LightAlphas(pool: 0.05 * sw, core: 0, halo: 0.01 + 0.06 * sw, beam: 0.13, trail: 0.12,
                               wash: 0.12 + 0.06 * sw, line: 0.07 + 0.12 * sw)
        case .rooftops, .harbour:
            return LightAlphas(pool: 0.34 + 0.12 * sw, core: 0.24 + 0.04 * dw + 0.2 * sw, halo: 0.1 + 0.18 * sw,
                               beam: 0.18, trail: 0.3)
        }
    }

    /// R3b: the grass recipe's colours (the tests model them too).
    static let meadowWash = GardenInk(hex: 0xD88A2A)
    static let meadowLine = GardenInk(hex: 0xFFF4D6)
    static let moonWash = GardenInk(hex: 0xE8D08A)
    static let moonLine = GardenInk(hex: 0xF4F0E2)
}

/// R2: how much of the mirror's light reaches each `u` (REVIEW-1 P0-2/P0-3): the band fades over the outer 6 % of the
/// garden's width, and each cloud shade multiplies it by `1 − strength` with a soft 0.03 edge (Contracts'
/// `ShadeState`). Pure, so the art and the tests agree.
enum GardenLightMath {
    static let outerFade: Double = 0.06
    static let shadeSoft: Double = 0.03

    /// 1 inside a shade, 0 outside, a linear ramp `shadeSoft` wide centred on each edge.
    static func shadeMask(u: Double, _ s: ShadeState) -> Double {
        let gap = abs(u - s.u) - max(s.halfWidth, 0)
        let e = shadeSoft / 2
        if gap <= -e { return 1 }
        if gap >= e { return 0 }
        return (e - gap) / shadeSoft
    }

    static func edgeFade(u: Double) -> Double {
        let k = min(u / outerFade, (1 - u) / outerFade)
        return min(max(k, 0), 1)
    }

    /// The light factor 0…1 at `u`.
    static func factor(u: Double, shades: [ShadeState]) -> Double {
        var f = edgeFade(u: u)
        for s in shades {
            let k = min(max(s.strength.isFinite ? s.strength : 0, 0), 1)
            if k > 0 { f *= 1 - k * shadeMask(u: u, s) }
        }
        return f
    }

    /// The light cut into pieces along u at every place the factor bends (the outer fades, each shade's soft edges).
    static func pieces(shades: [ShadeState], into out: inout [LightPiece]) {
        var scratch: [Double] = []
        pieces(shades: shades, into: &out, scratch: &scratch)
    }

    /// R5 (QA P2-7): the same, reusing `scratch` for the breakpoints (no allocation in the frame loop).
    static func pieces(shades: [ShadeState], into out: inout [LightPiece], scratch pts: inout [Double]) {
        pts.removeAll(keepingCapacity: true)
        pts.append(0)
        pts.append(outerFade)
        pts.append(1 - outerFade)
        pts.append(1)
        let e = shadeSoft / 2
        for s in shades where s.strength > 0.001 && s.u.isFinite && s.halfWidth.isFinite {
            let h = max(s.halfWidth, 0)
            let a = s.u - h - e
            let b = s.u - h + e
            let c = s.u + h - e
            let d = s.u + h + e
            if a > 0 && a < 1 { pts.append(a) }
            if b > 0 && b < 1 { pts.append(b) }
            if c > 0 && c < 1 { pts.append(c) }
            if d > 0 && d < 1 { pts.append(d) }
        }
        pts.sort()
        out.removeAll(keepingCapacity: true)
        var prev = pts[0]
        for v in pts.dropFirst() {
            if v - prev < 0.000_5 { continue }
            out.append(LightPiece(u0: prev, u1: v, f0: CGFloat(factor(u: prev, shades: shades)),
                                  f1: CGFloat(factor(u: v, shades: shades))))
            prev = v
        }
    }

    /// The factor the pieces draw at `u` (linear inside each piece; tests compare it with `factor`).
    static func drawn(u: Double, pieces: [LightPiece]) -> CGFloat {
        for p in pieces where u >= p.u0 && u <= p.u1 {
            let t = p.u1 > p.u0 ? CGFloat((u - p.u0) / (p.u1 - p.u0)) : 0
            return p.f0 + (p.f1 - p.f0) * t
        }
        return 0
    }
}

/// R2: one layer of the reflected light (the pool, the core, the halo, the beam, the trail), drawn in the canonical
/// garden (x along d, y along u) as flat + ramp sprite pairs, one pair per `LightPiece`, so cloud shades cut it exactly.
/// Additive: the grass shows through.
@MainActor
final class GardenLightLayer {
    let root = SKNode()
    private var flats: [SKSpriteNode] = []
    private var ramps: [SKSpriteNode] = []
    private let flatTexture: SKTexture
    private let rampTexture: SKTexture
    private let blend: SKBlendMode
    private var color: UIColor

    /// `blend`: `.add` for light; R3b: `.alpha` for the grass's warm wash (a piece's flat + ramp pair then stacks as
    /// 1 − (1 − a)(1 − b) ≈ a + b at these low opacities).
    init(_ profile: GardenArt.LightProfile, color: UIColor, capacity: Int = 15, blend: SKBlendMode = .add) {
        flatTexture = GardenArt.light(profile, ramp: false)
        rampTexture = GardenArt.light(profile, ramp: true)
        self.blend = blend
        self.color = color
        grow(to: max(capacity, 1))
    }

    /// R5 (QA P2-2): more pieces than sprites (many clouds at once): add sprite pairs rather than drop light.
    private func grow(to n: Int) {
        while flats.count < n {
            let f = SKSpriteNode(texture: flatTexture)
            let r = SKSpriteNode(texture: rampTexture)
            for s in [f, r] {
                s.blendMode = blend
                s.colorBlendFactor = 1
                s.color = color
                s.isHidden = true
                root.addChild(s)
            }
            flats.append(f)
            ramps.append(r)
        }
    }

    /// Sprite pairs held (tests).
    var capacity: Int { flats.count }

    func setColor(_ c: UIColor) {
        color = c
        for s in flats { s.color = c }
        for s in ramps { s.color = c }
    }

    /// Sprites drawn now.
    var visibleCount: Int {
        var n = 0
        for s in flats where !s.isHidden { n += 1 }
        for s in ramps where !s.isHidden { n += 1 }
        return n
    }

    func hide() {
        for s in flats { s.isHidden = true }
        for s in ramps { s.isHidden = true }
    }

    /// Lays the layer at canonical `x` (its `anchorX` there), `width` points across d, over the garden's `span`, cut
    /// into `pieces`, at peak opacity `alpha`.
    func draw(x: CGFloat, width: CGFloat, anchorX: CGFloat, span: CGFloat, pieces: [LightPiece], alpha: CGFloat) {
        guard alpha > 0.002, width > 0.5, span > 0 else {
            hide()
            return
        }
        if pieces.count > flats.count { grow(to: pieces.count) }
        var i = 0
        for p in pieces {
            if i >= flats.count { break }
            let y0 = CGFloat(p.u0) * span
            let h = max(CGFloat(p.u1 - p.u0) * span, 0.01)
            let lo = min(p.f0, p.f1)
            let rise = abs(p.f1 - p.f0)
            let f = flats[i]
            f.anchorPoint = CGPoint(x: anchorX, y: 0)
            f.yScale = 1
            f.size = CGSize(width: width, height: h)
            f.position = CGPoint(x: x, y: y0)
            f.alpha = lo * alpha
            f.isHidden = lo * alpha < 0.002
            let r = ramps[i]
            r.anchorPoint = CGPoint(x: anchorX, y: 0)
            r.size = CGSize(width: width, height: h)
            if p.f1 >= p.f0 {
                r.yScale = 1
                r.position = CGPoint(x: x, y: y0)
            } else {
                // Brightest at u0: the ramp flipped about its top.
                r.yScale = -1
                r.position = CGPoint(x: x, y: y0 + h)
            }
            r.alpha = rise * alpha
            r.isHidden = rise * alpha < 0.002
            i += 1
        }
        while i < flats.count {
            flats[i].isHidden = true
            ramps[i].isHidden = true
            i += 1
        }
    }
}
