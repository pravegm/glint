import CoreGraphics
import SwiftUI
import UIKit

/// The App Store icon (R2). It matches the committed reference, Glint/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
/// (tools/make-icon.js):
/// - a deep dawn-blue sky top-left, with a peach glow behind the mirror;
/// - the dotted teal garden on the lower right, below a diagonal;
/// - a tilted brass mirror (pale glass, one glint) throwing a gold band to the bottom-right corner;
/// - a cheeky shadow blob in the band with half-lidded white eyes, and a few gold motes.
///
/// The picture is painted with plain CoreGraphics (`IconPainter`, CPU only: no SpriteKit and no GPU effects, the R1
/// "solid black" lesson). `AppIconArt` shows it, and `IconExport` renders `AppIconArt` through SwiftUI's
/// `ImageRenderer`, checks the mean luminance and falls back to the painter's own image if the renderer comes back
/// dark.
struct AppIconArt: View {
    var side: CGFloat = 1024

    var body: some View {
        Group {
            if let image = IconPainter.cached() {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color(appHex: 0x141A3A)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
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

    /// The icon at `side` × `side` px, opaque.
    static func image(side: CGFloat) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let ui = renderer.image { context in
            paint(context.cgContext, side: side)
        }
        return ui.cgImage
    }

    private static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        return CGColor(red: r, green: g, blue: b, alpha: alpha)
    }

    private static func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient? {
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)
    }

    /// Paints the icon in a y-down context of `side` points.
    static func paint(_ c: CGContext, side s: CGFloat) {
        let full = CGRect(x: 0, y: 0, width: s, height: s)
        let p: (CGFloat, CGFloat) -> CGPoint = { fx, fy in CGPoint(x: fx * s, y: fy * s) }

        // 1. Sky: deep dawn blue, darker towards the bottom left.
        c.setFillColor(rgb(0x161A44))
        c.fill(full)
        if let sky = gradient([rgb(0x241D52), rgb(0x18204E), rgb(0x0F2746)], [0, 0.55, 1]) {
            c.drawLinearGradient(sky, start: p(0.3, 0), end: p(0.1, 1), options: [])
        }
        // 2. The peach glow behind the mirror.
        if let glow = gradient([rgb(0xC98A6A, 0.75), rgb(0x8A5A6A, 0.35), rgb(0x241D52, 0)], [0, 0.45, 1]) {
            c.drawRadialGradient(glow, startCenter: p(0.27, 0.2), startRadius: 0, endCenter: p(0.27, 0.2),
                                 endRadius: s * 0.42, options: [])
        }

        // 3. The garden: teal below the diagonal, with a fine dot texture.
        let garden = CGMutablePath()
        garden.move(to: p(0.86, 0))
        garden.addLine(to: p(1, 0))
        garden.addLine(to: p(1, 1))
        garden.addLine(to: p(0, 1))
        garden.addLine(to: p(0, 0.97))
        garden.closeSubpath()
        c.saveGState()
        c.addPath(garden)
        c.clip()
        if let grass = gradient([rgb(0x0E3F40), rgb(0x0B3436)], [0, 1]) {
            c.drawLinearGradient(grass, start: p(1, 0), end: p(0, 1), options: [])
        }
        c.setFillColor(rgb(0xBFE6DA, 0.16))
        let step = s / 40
        let dot = s * 0.0036
        var y = step / 2
        var row = 0
        while y < s {
            var x = step / 2 + (row % 2 == 0 ? 0 : step / 2)
            while x < s {
                c.fillEllipse(in: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot))
                x += step
            }
            y += step
            row += 1
        }
        c.restoreGState()

        // 4. The band: from the mirror's lower end to the far corner, soft edges then a bright core.
        let a = p(0.43, 0.42)
        let b = p(1.12, 1.1)
        let nx: CGFloat = 0.7071
        let ny: CGFloat = -0.7071
        let widths: [CGFloat] = [0.115, 0.092, 0.078, 0.04]
        let colours: [CGColor] = [rgb(0xE8B94C, 0.22), rgb(0xE8BC52, 0.55), rgb(0xEABF55, 0.95), rgb(0xF5DC8E, 0.85)]
        for i in 0..<widths.count {
            let w = widths[i] * s
            let band = CGMutablePath()
            band.move(to: CGPoint(x: a.x + nx * w, y: a.y + ny * w))
            band.addLine(to: CGPoint(x: b.x + nx * w, y: b.y + ny * w))
            band.addLine(to: CGPoint(x: b.x - nx * w, y: b.y - ny * w))
            band.addLine(to: CGPoint(x: a.x - nx * w, y: a.y - ny * w))
            band.closeSubpath()
            c.setFillColor(colours[i])
            c.addPath(band)
            c.fillPath()
        }
        // Gold motes in the beam.
        c.setFillColor(rgb(0xFFE7A0, 0.95))
        let motes: [CGPoint] = [p(0.58, 0.53), p(0.53, 0.58), p(0.5, 0.66)]
        let moteSizes: [CGFloat] = [0.016, 0.014, 0.01]
        for i in 0..<motes.count {
            let d = moteSizes[i] * s
            c.fillEllipse(in: CGRect(x: motes[i].x - d / 2, y: motes[i].y - d / 2, width: d, height: d))
        }

        // 5. The mirror: a brass frame tilted 40°, pale glass, one glint.
        c.saveGState()
        c.translateBy(x: 0.305 * s, y: 0.305 * s)
        c.rotate(by: 40 * CGFloat.pi / 180)
        let length = 0.5 * s
        let thick = 0.15 * s
        let rim = CGRect(x: -length / 2, y: -thick / 2, width: length, height: thick)
        let rimPath = CGPath(roundedRect: rim, cornerWidth: 0.045 * s, cornerHeight: 0.045 * s, transform: nil)
        c.setShadow(offset: CGSize.zero, blur: 0.04 * s, color: rgb(0xF2C066, 0.6))
        c.addPath(rimPath)
        c.setFillColor(rgb(0xE0A646))
        c.fillPath()
        c.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        c.saveGState()
        c.addPath(rimPath)
        c.clip()
        if let brass = gradient([rgb(0xF4CF7A), rgb(0xDDA040), rgb(0xB47A2A)], [0, 0.5, 1]) {
            c.drawLinearGradient(brass, start: CGPoint(x: 0, y: -thick / 2), end: CGPoint(x: 0, y: thick / 2),
                                 options: [])
        }
        c.restoreGState()
        let glass = rim.insetBy(dx: 0.024 * s, dy: 0.024 * s)
        let glassPath = CGPath(roundedRect: glass, cornerWidth: 0.026 * s, cornerHeight: 0.026 * s, transform: nil)
        c.saveGState()
        c.addPath(glassPath)
        c.clip()
        if let sky = gradient([rgb(0xF4EDCF), rgb(0xCFE3E4), rgb(0x9CCDEB)], [0, 0.5, 1]) {
            c.drawLinearGradient(sky, start: CGPoint(x: glass.minX, y: 0), end: CGPoint(x: glass.maxX, y: 0),
                                 options: [])
        }
        c.restoreGState()
        // The glint: a small four-point star near the upper end.
        let gx = -length * 0.3
        let gy: CGFloat = -thick * 0.08
        let r = 0.05 * s
        let k = r * 0.16
        let star = CGMutablePath()
        star.move(to: CGPoint(x: gx, y: gy - r))
        star.addQuadCurve(to: CGPoint(x: gx + r, y: gy), control: CGPoint(x: gx + k, y: gy - k))
        star.addQuadCurve(to: CGPoint(x: gx, y: gy + r), control: CGPoint(x: gx + k, y: gy + k))
        star.addQuadCurve(to: CGPoint(x: gx - r, y: gy), control: CGPoint(x: gx - k, y: gy + k))
        star.addQuadCurve(to: CGPoint(x: gx, y: gy - r), control: CGPoint(x: gx - k, y: gy - k))
        star.closeSubpath()
        c.setFillColor(rgb(0xFFFFFF, 0.95))
        c.addPath(star)
        c.fillPath()
        c.restoreGState()

        // 6. The shadow: a wobbly inky blob with a warm rim where the light hits, half-lidded eyes.
        let centre = p(0.7, 0.745)
        let radius = 0.15 * s
        let blob = CGMutablePath()
        let count = 72
        for i in 0...count {
            let t = CGFloat(i) / CGFloat(count) * 2 * CGFloat.pi
            let wobble: CGFloat = 1 + 0.07 * sin(3 * t + 0.6) + 0.04 * cos(5 * t)
            let q = CGPoint(x: centre.x + cos(t) * radius * wobble, y: centre.y + sin(t) * radius * wobble * 0.96)
            if i == 0 {
                blob.move(to: q)
            } else {
                blob.addLine(to: q)
            }
        }
        blob.closeSubpath()
        c.setShadow(offset: CGSize.zero, blur: 0.035 * s, color: rgb(0xE59A62, 0.85))
        c.setFillColor(rgb(0x2A1240))
        c.addPath(blob)
        c.fillPath()
        c.setShadow(offset: CGSize.zero, blur: 0, color: nil)
        c.saveGState()
        c.addPath(blob)
        c.clip()
        if let inner = gradient([rgb(0x3A1C55, 0.9), rgb(0x23103A, 0)], [0, 1]) {
            c.drawRadialGradient(inner, startCenter: CGPoint(x: centre.x - radius * 0.3, y: centre.y - radius * 0.35),
                                 startRadius: 0, endCenter: centre, endRadius: radius * 1.1, options: [])
        }
        c.restoreGState()
        let eyeXs: [CGFloat] = [0.645, 0.755]
        for ex in eyeXs {
            let eye = CGRect(x: (ex - 0.04) * s, y: 0.695 * s, width: 0.08 * s, height: 0.05 * s)
            let lidY = eye.midY - eye.height * 0.12
            c.saveGState()
            // Half-lidded: only the lower part of the eye shows, under a flat lid.
            c.clip(to: CGRect(x: eye.minX, y: lidY, width: eye.width, height: eye.maxY - lidY))
            c.setFillColor(rgb(0xF4F1FA))
            c.fillEllipse(in: eye)
            c.setFillColor(rgb(0x1A0B28))
            let pr = 0.017 * s
            c.fillEllipse(in: CGRect(x: eye.midX + 0.004 * s - pr, y: eye.midY - pr * 0.6, width: pr * 2, height: pr * 2))
            c.restoreGState()
            c.setStrokeColor(rgb(0x14081F))
            c.setLineWidth(0.006 * s)
            c.move(to: CGPoint(x: eye.minX + eye.width * 0.04, y: lidY))
            c.addLine(to: CGPoint(x: eye.maxX - eye.width * 0.04, y: lidY))
            c.strokePath()
        }
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
