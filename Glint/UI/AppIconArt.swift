import CoreGraphics
import SwiftUI
import UIKit

/// The App Store icon (R3, REVIEW-2 fix 8). It matches the committed Glint/Assets.xcassets/AppIcon.appiconset/
/// AppIcon-1024.png exactly, because it is the same per-pixel shader as tools/make-icon.js, ported line for line
/// (`IconShader`):
/// - a round, scalloped brass hand mirror catches the sun (top right) and throws a soft beam onto one squinting shadow;
/// - one smooth indigo → dusk → teal background;
/// - no stepped bands; readable at 60 px.
///
/// It is painted on the CPU into a plain bitmap: no SpriteKit and no GPU effects (the R1 "solid black" lesson).
/// `AppIconArt` shows it, and `IconExport` renders `AppIconArt` through SwiftUI's `ImageRenderer`, checks the mean
/// luminance and falls back to the painter's own image if the renderer comes back dark.
struct AppIconArt: View {
    var side: CGFloat = 1024

    var body: some View {
        Group {
            if let image = IconPainter.cached() {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color(appHex: 0x18164A)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// tools/make-icon.js's `shade(x, y)`, ported line for line (x, y in 0…1, y down; colours 0…255). Pure.
enum IconShader {
    typealias RGB = (r: Double, g: Double, b: Double)

    static let sun: (Double, Double) = (0.78, 0.20)
    static let sunR = 0.115
    static let mirror: (Double, Double) = (0.36, 0.40)
    static let mirrorR = 0.185
    static let gloom: (Double, Double) = (0.66, 0.76)

    @inline(__always) static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    @inline(__always) static func clamp(_ x: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double {
        max(lo, min(hi, x))
    }
    @inline(__always) static func smooth(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = clamp((x - e0) / (e1 - e0))
        return t * t * (3 - 2 * t)
    }
    @inline(__always) static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        (mix(a.r, b.r, t), mix(a.g, b.g, t), mix(a.b, b.b, t))
    }
    @inline(__always) static func over(_ dst: RGB, _ src: RGB, _ a: Double) -> RGB { lerp(dst, src, clamp(a)) }
    @inline(__always) static func add(_ c: RGB, _ r: Double, _ g: Double, _ b: Double) -> RGB {
        (min(255, c.r + r), min(255, c.g + g), min(255, c.b + b))
    }

    static func shade(_ x: Double, _ y: Double) -> RGB {
        // Background: deep indigo at the top, warm dusk violet, then teal garden at the bottom, all smooth.
        var c: RGB = lerp((24, 22, 70), (92, 46, 104), smooth(0.0, 0.62, y))
        c = lerp(c, (14, 66, 72), smooth(0.55, 1.0, y))
        // Sun glow and disc.
        let ds = hypot(x - sun.0, y - sun.1)
        c = over(c, (255, 170, 96), 0.75 * exp(-ds * ds / 0.035))
        let sunFace = lerp((255, 236, 150), (255, 150, 60), clamp((y - sun.1 + sunR) / (2 * sunR)))
        c = over(c, sunFace, 1 - smooth(sunR - 0.004, sunR + 0.004, ds))
        // The beam: a soft cone from the mirror towards the gloom (additive warm light, feathered edges).
        let vx = gloom.0 - mirror.0
        let vy = gloom.1 - mirror.1
        let vl = hypot(vx, vy)
        let ux = vx / vl
        let uy = vy / vl
        let px = x - mirror.0
        let py = y - mirror.1
        let along = px * ux + py * uy
        let across = abs(-px * uy + py * ux)
        if along > 0 {
            let w = 0.07 + along * 0.22
            let a = (1 - smooth(w * 0.35, w, across)) * smooth(0.02, 0.18, along)
                * (1 - smooth(vl * 1.05, vl * 1.45, along))
            c = add(c, 220 * a, 175 * a, 40 * a)
        }
        // A pool of light on the ground under the gloom.
        let pdx = (x - gloom.0) / 1.6
        let pdy = (y - gloom.1 - 0.10) / 0.7
        let pd = hypot(pdx, pdy)
        let pool = exp(-pd * pd / 0.012) * 0.6
        c = add(c, 180 * pool, 140 * pool, 60 * pool)
        // The mirror, in its own tilted oval space (rotated −24°, 1.28 taller than wide).
        let ca = cos(-0.42)
        let sa = sin(-0.42)
        let lx = (x - mirror.0) * ca - (y - mirror.1) * sa
        let ly = (x - mirror.0) * sa + (y - mirror.1) * ca
        // Handle: short and stout, with a collar and a round knob.
        let hy0 = mirrorR * 1.28 - 0.01
        let hw = 0.034 + 0.010 * sin(clamp((ly - hy0) / 0.16) * Double.pi * 2.2)
        let handle = (1 - smooth(hw - 0.004, hw + 0.002, abs(lx))) * smooth(hy0 - 0.01, hy0, ly)
            * (1 - smooth(hy0 + 0.15, hy0 + 0.16, ly))
        let knob = 1 - smooth(0.040, 0.046, hypot(lx, ly - (hy0 + 0.17)))
        c = over(c, lerp((140, 88, 36), (240, 196, 110), clamp(0.55 - lx * 10)), max(handle, knob))
        let dm = hypot(lx, ly / 1.28)
        let theta = atan2(ly / 1.28, lx)
        let scallop = mirrorR + 0.010 * cos(theta * 14)
        let rim = 1 - smooth(scallop - 0.004, scallop + 0.003, dm)
        let rimShade = clamp(0.5 + (lx * -0.7 + ly * -0.5) * 4)
        c = over(c, lerp((160, 102, 40), (255, 224, 142), rimShade), rim)
        // An inner groove line on the brass.
        c = over(c, (120, 72, 28), (1 - smooth(0.0025, 0.006, abs(dm - (mirrorR - 0.022)))) * 0.8)
        let gr = mirrorR - 0.032
        let glass = 1 - smooth(gr - 0.003, gr + 0.003, dm)
        // Reflection: sky, with the image of the sun towards the upper right of the glass.
        var g: RGB = lerp((255, 232, 190), (150, 120, 190), clamp((ly + gr * 1.28) / (2 * gr * 1.28)))
        let ri = hypot(lx - 0.045, ly + 0.07)
        g = over(g, (255, 200, 100), 0.7 * exp(-ri * ri / 0.006))
        g = over(g, (255, 240, 170), 1 - smooth(0.040, 0.050, ri))
        g = over(g, (255, 255, 255), 0.30 * (1 - smooth(0.0, 0.018, abs(lx + ly * 0.7 + 0.05))))
        c = over(c, g, glass)
        // Glint: a small 4-point sparkle on the glass edge.
        let sx = x - (mirror.0 + 0.085)
        let sy = y - (mirror.1 - 0.095)
        let star = exp(-(sx * sx) / 0.00003 - (sy * sy) / 0.0016) + exp(-(sy * sy) / 0.00003 - (sx * sx) / 0.0016)
        c = over(c, (255, 255, 255), clamp(star))
        // The gloom: wobbly inky blob, rim-lit from the beam side, squinting.
        let cx = gloom.0
        let cy = gloom.1
        let an = atan2(y - cy, x - cx)
        let r = 0.16 * (1 + 0.045 * sin(an * 5 + 0.6) + 0.03 * sin(an * 3 - 1.1))
        let d = hypot(x - cx, (y - cy) * 1.1)
        let body = 1 - smooth(r - 0.004, r + 0.004, d)
        let lit = clamp(0.5 - ((x - cx) * ux + (y - cy) * uy) * 5)
        c = over(c, lerp((34, 16, 56), (70, 34, 92), clamp(0.5 - (y - cy) * 3)), body)
        c = over(c, (255, 196, 120), smooth(r - 0.035, r - 0.002, d) * body * lit * 0.9)
        let eyes: [Double] = [cx - 0.055, cx + 0.052]
        for ex in eyes {
            let ey = cy - 0.02
            let e = hypot((x - ex) / 0.042, (y - ey) / 0.034)
            let lid = smooth(ey - 0.010, ey - 0.003, y)
            let white = (1 - smooth(0.92, 1.03, e)) * lid
            c = over(c, (252, 250, 255), white)
            let pe = hypot((x - ex + 0.012) / 0.017, (y - ey + 0.002) / 0.017)
            c = over(c, (22, 10, 32), (1 - smooth(0.85, 1.05, pe)) * white)
            // Heavy brow on the squint, slanting down towards the middle.
            let slope = ex < cx ? -0.28 : 0.28
            let browLine = abs(y - (ey - 0.011 - (x - ex) * slope))
            let brow = (1 - smooth(0.004, 0.009, browLine)) * (1 - smooth(0.04, 0.05, abs(x - ex)))
            c = over(c, (18, 8, 28), brow)
        }
        // A small grimace.
        let mx = x - cx
        let my = y - (cy + 0.055)
        let mouth = (1 - smooth(0.004, 0.009, abs(my - mx * mx * 6))) * (1 - smooth(0.03, 0.04, abs(mx)))
        c = over(c, (250, 240, 250), mouth * 0.9)
        // Sparks where the light hits.
        let sparks: [(Double, Double, Double)] = [(0.52, 0.62, 0.012), (0.57, 0.56, 0.008), (0.49, 0.70, 0.007),
                                                  (0.80, 0.62, 0.009)]
        for spark in sparks {
            let dd = hypot(x - spark.0, y - spark.1)
            c = over(c, (255, 240, 170), 1 - smooth(spark.2 * 0.4, spark.2, dd))
        }
        return c
    }
}

@MainActor
enum IconPainter {
    static let masterSide: CGFloat = 1024
    private static var cache: CGImage?

    static func cached() -> CGImage? {
        if let cache { return cache }
        let made = image(side: masterSide)
        cache = made
        return made
    }

    /// The icon at `side` × `side` px, opaque. Supersampled 2×2 up to 512 px (make-icon.js uses 3×3 at 1024; a
    /// Debug build on the CI simulator can't afford that, and the committed PNG is the one that ships).
    static func image(side: CGFloat) -> CGImage? {
        IconPainter.render(side: Int(side.rounded()), supersample: side <= 512 ? 2 : 1)
    }

    /// The shader into an RGBX bitmap (row 0 = the top). Pure given its inputs.
    nonisolated static func render(side n: Int, supersample ss: Int) -> CGImage? {
        guard n > 0, ss > 0 else { return nil }
        var bytes = [UInt8](repeating: 255, count: n * n * 4)
        let inv = 1.0 / Double(n)
        let k = 1.0 / Double(ss * ss)
        for j in 0..<n {
            for i in 0..<n {
                var r = 0.0
                var g = 0.0
                var b = 0.0
                for sj in 0..<ss {
                    for si in 0..<ss {
                        let x = (Double(i) + (Double(si) + 0.5) / Double(ss)) * inv
                        let y = (Double(j) + (Double(sj) + 0.5) / Double(ss)) * inv
                        let c = IconShader.shade(x, y)
                        r += c.r
                        g += c.g
                        b += c.b
                    }
                }
                let o = (j * n + i) * 4
                bytes[o] = UInt8(IconShader.clamp((r * k).rounded(), 0, 255))
                bytes[o + 1] = UInt8(IconShader.clamp((g * k).rounded(), 0, 255))
                bytes[o + 2] = UInt8(IconShader.clamp((b * k).rounded(), 0, 255))
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Mean luminance (0…1, Rec. 709) and distinct colours (5 bits per channel) on a 64 × 64 sample. Pure given the
    /// image; tested.
    nonisolated static func stats(_ image: CGImage) -> (luminance: Double, colours: Int) {
        let n = 64
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8,
                                      bytesPerRow: n * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard drawn else { return (0, 0) }
        var sum = 0.0
        var seen = Set<Int>()
        for i in 0..<(n * n) {
            let ri = Int(pixels[i * 4])
            let gi = Int(pixels[i * 4 + 1])
            let bi = Int(pixels[i * 4 + 2])
            sum += 0.2126 * Double(ri) / 255 + 0.7152 * Double(gi) / 255 + 0.0722 * Double(bi) / 255
            seen.insert(((ri >> 3) << 10) | ((gi >> 3) << 5) | (bi >> 3))
        }
        return (sum / Double(n * n), seen.count)
    }

    /// The icon is too dark to ship (R1 shipped a solid-black render): below this mean luminance.
    nonisolated static let darkLuminance = 0.08
}
