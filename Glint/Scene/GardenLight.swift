import SpriteKit
import UIKit

/// R2: one stretch of the light along u, its light factor running linearly from `f0` (at `u0`) to `f1` (at `u1`).
struct LightPiece: Equatable {
    var u0: Double
    var u1: Double
    var f0: CGFloat
    var f1: CGFloat
}

/// R3 (REVIEW-2 P0-3): how strong each light layer is drawn (additive peak opacity). On grass (the meadow and Long
/// Night's moonlit meadow) the pool is gentle, so the lawn under the band stays under 1.8 × its unlit brightness (a
/// pool of light, not a slab); tiles and planks are lighter and take the R2 strength. The cone (beam) runs from the
/// crease shade to the band's near edge at 18 %, so it never stacks under the band.
struct LightAlphas: Equatable {
    var pool: CGFloat
    var core: CGFloat
    var halo: CGFloat
    var beam: CGFloat
    var trail: CGFloat

    static func of(_ style: GroundStyle, dawn: CGFloat, swell: CGFloat) -> LightAlphas {
        let sw = min(max(swell, 0), 1)
        switch style {
        case .meadow:
            return LightAlphas(pool: 0.09 + 0.06 * sw, core: 0.065 + 0.02 * dawn + 0.08 * sw, halo: 0.015 + 0.08 * sw,
                               beam: 0.18, trail: 0.2)
        case .moonlit:
            // Moonlight on the darker blue lawn: gentler still.
            return LightAlphas(pool: 0.07 + 0.05 * sw, core: 0.05 + 0.07 * sw, halo: 0.01 + 0.06 * sw,
                               beam: 0.14, trail: 0.16)
        case .rooftops, .harbour:
            return LightAlphas(pool: 0.34 + 0.12 * sw, core: 0.24 + 0.04 * dawn + 0.2 * sw, halo: 0.1 + 0.18 * sw,
                               beam: 0.18, trail: 0.3)
        }
    }
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
        var pts: [Double] = [0, outerFade, 1 - outerFade, 1]
        let e = shadeSoft / 2
        for s in shades where s.strength > 0.001 && s.u.isFinite && s.halfWidth.isFinite {
            let h = max(s.halfWidth, 0)
            let edges: [Double] = [s.u - h - e, s.u - h + e, s.u + h - e, s.u + h + e]
            for v in edges where v > 0 && v < 1 { pts.append(v) }
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

    init(_ profile: GardenArt.LightProfile, color: UIColor, capacity: Int = 15) {
        let ft = GardenArt.light(profile, ramp: false)
        let rt = GardenArt.light(profile, ramp: true)
        for _ in 0..<max(capacity, 1) {
            let f = SKSpriteNode(texture: ft)
            let r = SKSpriteNode(texture: rt)
            for s in [f, r] {
                s.blendMode = .add
                s.colorBlendFactor = 1
                s.color = color
                s.isHidden = true
                root.addChild(s)
            }
            flats.append(f)
            ramps.append(r)
        }
    }

    func setColor(_ c: UIColor) {
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
