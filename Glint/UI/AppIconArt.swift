import SwiftUI

/// The App Store icon, drawn in SwiftUI (ROUND-1 App 5): a deep dawn-blue tile, a tilted brass mirror top-left
/// throwing a gold band diagonally across it, and one cheeky shadow blob with white eyes squinting in the light.
/// Opaque, readable at 60 px. `IconExport` renders it at 1024 px to an RGB PNG with no alpha (`screen=icon`).
struct AppIconArt: View {
    var side: CGFloat = 1024

    var body: some View {
        let s = side
        ZStack {
            // The tile: deep dawn blue, a peach glow behind the mirror.
            LinearGradient(colors: [Color(appHex: 0x2A3A86), Color(appHex: 0x16205A), Color(appHex: 0x0B1033)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [GlintTheme.peach.opacity(0.5), GlintTheme.rose.opacity(0.18), Color.clear],
                           center: UnitPoint(x: 0.24, y: 0.22), startRadius: 0, endRadius: s * 0.62)

            // The band: a soft wide beam, then its bright core.
            IconBandShape(spread: 0.13)
                .fill(LinearGradient(colors: [GlintTheme.goldLight.opacity(0.55), GlintTheme.gold.opacity(0.28),
                                              GlintTheme.gold.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            IconBandShape(spread: 0.07)
                .fill(LinearGradient(colors: [Color.white.opacity(0.95), GlintTheme.goldLight.opacity(0.85),
                                              GlintTheme.gold.opacity(0.35)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            // Dew glints in the beam.
            ForEach(0..<5, id: \.self) { i in
                MenuSparkle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: s * (0.05 - 0.006 * CGFloat(i)), height: s * (0.05 - 0.006 * CGFloat(i)))
                    .position(x: s * (0.5 + 0.08 * CGFloat(i)), y: s * (0.45 + 0.07 * CGFloat(i)))
            }

            // The mirror (tilted brass frame, dawn inside).
            MenuMirrorArt(sun: 0.6)
                .frame(width: s * 0.4, height: s * 0.31)
                .rotationEffect(.degrees(-22))
                .shadow(color: Color.black.opacity(0.45), radius: s * 0.02, x: 0, y: s * 0.012)
                .position(x: s * 0.28, y: s * 0.25)

            // The shadow, squinting in the light.
            MenuGloomArt(squint: 0.62)
                .frame(width: s * 0.4, height: s * 0.4)
                .shadow(color: GlintTheme.gold.opacity(0.35), radius: s * 0.02)
                .position(x: s * 0.7, y: s * 0.73)
            // Steam where the light burns it.
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: s * 0.022, height: s * 0.07)
                    .rotationEffect(.degrees(Double(i - 1) * 18))
                    .position(x: s * (0.64 + 0.06 * CGFloat(i)), y: s * 0.5)
            }
        }
        .frame(width: s, height: s)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// The beam from the mirror's face (top-left) to the far corner (bottom-right), widening as it goes.
struct IconBandShape: Shape {
    /// Half-width at the far end, as a share of the tile.
    var spread: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let start = CGPoint(x: rect.minX + w * 0.33, y: rect.minY + h * 0.31)
        let end = CGPoint(x: rect.minX + w * 1.05, y: rect.minY + h * 1.05)
        let near = spread * 0.45
        let far = spread
        // Unit normal to the beam (it runs at 45°).
        let nx: CGFloat = 0.7071
        let ny: CGFloat = -0.7071
        var p = Path()
        p.move(to: CGPoint(x: start.x + nx * w * near, y: start.y + ny * h * near))
        p.addLine(to: CGPoint(x: end.x + nx * w * far, y: end.y + ny * h * far))
        p.addLine(to: CGPoint(x: end.x - nx * w * far, y: end.y - ny * h * far))
        p.addLine(to: CGPoint(x: start.x - nx * w * near, y: start.y - ny * h * near))
        p.closeSubpath()
        return p
    }
}
