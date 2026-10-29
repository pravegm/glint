import SwiftUI

/// The ten Game Center badges (docs/appstore/achievements.md "Images"), drawn in SwiftUI in the app icon's style: a
/// deep dawn-blue field (#141A3A) with a soft gold glow from one corner, a brass medallion whose rim shows the tier
/// (copper for 10–25 points, brass with a gold inner ring for 50, bright gold with rays for 100) and one motif. No words,
/// only short numerals. `BadgeExport` renders each at 1024 px to Documents/badges/<id>.png (`screen=badges`).
enum BadgeTier: Equatable, Sendable {
    case copper, brass, gold

    static func of(points: Int) -> BadgeTier {
        if points >= 100 { return .gold }
        if points >= 50 { return .brass }
        return .copper
    }
}

/// The App's own table of the badges' art, keyed by the achievement key (`glint.ach.<key>`). Points are the
/// Core's `Achievements` table (they pick the tier).
enum BadgeBook {
    static var prefix: String { Achievements.idPrefix }

    /// The keys with a motif drawn below (one per achievement, in Core's order).
    static let motifKeys: [String] = ["firstlight", "sweep", "brute", "firefly", "chain4", "rooftops", "harbour",
                                      "allstars", "daily", "longnight"]

    static var keys: [String] { Achievements.all.map { $0.key } }

    /// `glint.ach.firstlight` → `firstlight` (an id without the prefix is returned as it is).
    static func key(of id: String) -> String {
        id.hasPrefix(prefix) ? String(id.dropFirst(prefix.count)) : id
    }

    static func points(key: String) -> Int {
        Achievements.find(key)?.points ?? 10
    }

    static func tier(key: String) -> BadgeTier { BadgeTier.of(points: points(key: key)) }
}

/// Titles for ids (Results card chips).
enum AchievementNames {
    static func title(_ id: String) -> String {
        Achievements.find(BadgeBook.key(of: id))?.title ?? id
    }

    /// The earned description (Core's `Achievements.earnedBlurbs`), else the pre-earned one.
    static func earnedLine(_ id: String) -> String {
        let key = BadgeBook.key(of: id)
        return Achievements.earnedBlurbs[key] ?? Achievements.find(key)?.blurb ?? ""
    }
}

/// One badge (square). `earned` false draws it dimmed (an in-app list may use it).
struct AchievementBadge: View {
    let key: String
    var side: CGFloat = 1024
    var earned = true

    var body: some View {
        let s = side
        let tier = BadgeBook.tier(key: key)
        ZStack {
            Color(appHex: 0x141A3A)
            RadialGradient(colors: [GlintTheme.gold.opacity(0.42), GlintTheme.peach.opacity(0.12), Color.clear],
                           center: .center, startRadius: s * 0.2, endRadius: s * 0.7)
            if tier == .gold {
                MenuSunArt(rays: 20, glow: true)
                    .frame(width: s * 0.98, height: s * 0.98)
                    .opacity(0.75)
            }
            BadgeMedallion(tier: tier)
                .frame(width: s * 0.78, height: s * 0.78)
            BadgeMotif(key: key)
                .frame(width: s * 0.5, height: s * 0.5)
                .clipShape(Circle())
        }
        .frame(width: s, height: s)
        .saturation(earned ? 1 : 0.15)
        .opacity(earned ? 1 : 0.6)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// The medallion: a rim in the tier's metal, an inner dawn-dark disc.
struct BadgeMedallion: View {
    let tier: BadgeTier

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(Color.black.opacity(0.35)).offset(y: s * 0.025)
                Circle().fill(LinearGradient(colors: rim, startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: s * 0.012)
                    .padding(s * 0.01)
                if tier != .copper {
                    Circle()
                        .strokeBorder(LinearGradient(colors: [GlintTheme.goldLight, GlintTheme.gold], startPoint: .top,
                                                     endPoint: .bottom), lineWidth: s * 0.025)
                        .padding(s * 0.085)
                }
                Circle()
                    .fill(RadialGradient(colors: [Color(appHex: 0x3A2C6E), Color(appHex: 0x1A1440)],
                                         center: UnitPoint(x: 0.45, y: 0.35), startRadius: 0, endRadius: s * 0.4))
                    .padding(s * 0.12)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private var rim: [Color] {
        switch tier {
        case .copper: return [Color(appHex: 0xF0A877), Color(appHex: 0xB8683A), Color(appHex: 0x6E3518)]
        case .brass: return [GlintTheme.brassLight, GlintTheme.brass, GlintTheme.brassDark]
        case .gold: return [Color(appHex: 0xFFF1B8), GlintTheme.gold, GlintTheme.goldDeep]
        }
    }
}

/// The motif inside the medallion (drawn on a dark disc, so the gold and cream read).
struct BadgeMotif: View {
    let key: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s = min(w, h)
            ZStack {
                switch key {
                case "firstlight":
                    // A sun peeking over a garden edge.
                    MenuSunArt(rays: 12)
                        .frame(width: s * 0.9, height: s * 0.9)
                        .position(x: w * 0.5, y: h * 0.62)
                    Ellipse()
                        .fill(LinearGradient(colors: [GlintTheme.grass, GlintTheme.teal], startPoint: .top,
                                             endPoint: .bottom))
                        .frame(width: w * 1.4, height: h * 0.55)
                        .position(x: w * 0.5, y: h * 1.0)
                    MenuFlowerArt(petal: GlintTheme.petals[0])
                        .frame(width: s * 0.2, height: s * 0.2)
                        .position(x: w * 0.3, y: h * 0.8)
                    MenuFlowerArt(petal: GlintTheme.petals[1])
                        .frame(width: s * 0.17, height: s * 0.17)
                        .position(x: w * 0.72, y: h * 0.82)
                case "sweep":
                    // Three pops in a curved streak of light.
                    SweepArc()
                        .stroke(LinearGradient(colors: [GlintTheme.goldLight.opacity(0.2), GlintTheme.goldLight],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: s * 0.1, lineCap: .round))
                    ForEach(0..<3, id: \.self) { i in
                        MenuSparkle()
                            .fill(GlintTheme.cream)
                            .frame(width: s * 0.22, height: s * 0.22)
                            .shadow(color: GlintTheme.gold, radius: s * 0.04)
                            .position(x: w * (0.28 + 0.22 * CGFloat(i)), y: h * (0.62 - 0.14 * CGFloat(i)))
                    }
                case "brute":
                    // R3: an angry big gloom popping: heavy frowning brows, a pop ring and sparks bursting off it.
                    Circle()
                        .strokeBorder(GlintTheme.goldLight.opacity(0.85), lineWidth: s * 0.035)
                        .frame(width: s * 0.98, height: s * 0.98)
                        .position(x: w * 0.5, y: h * 0.55)
                    ForEach(0..<8, id: \.self) { i in
                        let a = Double(i) / 8.0 * 2.0 * Double.pi + 0.3
                        MenuSparkle()
                            .fill(i % 2 == 0 ? GlintTheme.goldLight : GlintTheme.cream)
                            .frame(width: s * 0.13, height: s * 0.13)
                            .position(x: w * 0.5 + CGFloat(cos(a)) * s * 0.42, y: h * 0.55 + CGFloat(sin(a)) * s * 0.42)
                    }
                    MenuGloomArt(squint: 0.35)
                        .frame(width: s * 0.74, height: s * 0.74)
                        .position(x: w * 0.5, y: h * 0.57)
                    Capsule()
                        .fill(Color(appHex: 0x0E0619))
                        .frame(width: s * 0.2, height: s * 0.07)
                        .rotationEffect(.degrees(24))
                        .position(x: w * 0.41, y: h * 0.45)
                    Capsule()
                        .fill(Color(appHex: 0x0E0619))
                        .frame(width: s * 0.2, height: s * 0.07)
                        .rotationEffect(.degrees(-24))
                        .position(x: w * 0.59, y: h * 0.45)
                    Capsule()
                        .fill(Color(appHex: 0x0E0619))
                        .frame(width: s * 0.18, height: s * 0.045)
                        .position(x: w * 0.5, y: h * 0.72)
                case "firefly":
                    // A firefly over a sprouting flower.
                    Capsule()
                        .fill(GlintTheme.leaf)
                        .frame(width: s * 0.05, height: s * 0.32)
                        .position(x: w * 0.5, y: h * 0.78)
                    MenuFlowerArt(petal: GlintTheme.petals[3])
                        .frame(width: s * 0.36, height: s * 0.36)
                        .position(x: w * 0.5, y: h * 0.58)
                    Circle()
                        .fill(RadialGradient(colors: [Color(appHex: 0xF4FFB0), Color(appHex: 0xB6E86A).opacity(0.6),
                                                      Color.clear], center: .center, startRadius: 0,
                                             endRadius: s * 0.16))
                        .frame(width: s * 0.32, height: s * 0.32)
                        .position(x: w * 0.68, y: h * 0.26)
                case "chain4":
                    // "x4" in chunky numerals, with a glint.
                    Text("x4")
                        .font(.system(size: s * 0.5, weight: .black, design: .rounded))
                        .foregroundStyle(GlintTheme.goldFace)
                        .shadow(color: GlintTheme.gold.opacity(0.7), radius: s * 0.04)
                        .position(x: w * 0.5, y: h * 0.54)
                    MenuSparkle()
                        .fill(GlintTheme.cream)
                        .frame(width: s * 0.2, height: s * 0.2)
                        .position(x: w * 0.78, y: h * 0.26)
                case "rooftops":
                    // R3: a clear roof line with the sun rising behind it.
                    MenuSunArt(rays: 12)
                        .frame(width: s * 0.72, height: s * 0.72)
                        .position(x: w * 0.56, y: h * 0.5)
                    RoofsShape()
                        .fill(Color(appHex: 0x2A1838))
                        .frame(width: w, height: h * 0.55)
                        .position(x: w * 0.5, y: h * 0.8)
                    RoofsShape()
                        .stroke(GlintTheme.goldLight, lineWidth: s * 0.025)
                        .frame(width: w, height: h * 0.55)
                        .position(x: w * 0.5, y: h * 0.8)
                case "harbour":
                    // A harbour light over water.
                    LighthouseBeam()
                        .fill(LinearGradient(colors: [GlintTheme.goldLight.opacity(0.8), Color.clear],
                                             startPoint: .leading, endPoint: .trailing))
                    Rectangle()
                        .fill(LinearGradient(colors: [GlintTheme.cream, GlintTheme.mist], startPoint: .top,
                                             endPoint: .bottom))
                        .frame(width: s * 0.14, height: s * 0.42)
                        .position(x: w * 0.36, y: h * 0.5)
                    Circle()
                        .fill(GlintTheme.goldLight)
                        .frame(width: s * 0.12, height: s * 0.12)
                        .shadow(color: GlintTheme.gold, radius: s * 0.05)
                        .position(x: w * 0.36, y: h * 0.27)
                    WavesShape()
                        .fill(LinearGradient(colors: [Color(appHex: 0x5CC3D8), GlintTheme.teal], startPoint: .top,
                                             endPoint: .bottom))
                        .frame(width: w, height: h * 0.45)
                        .position(x: w * 0.5, y: h * 0.82)
                case "allstars":
                    // A ring of small suns.
                    ForEach(0..<9, id: \.self) { i in
                        let a = Double(i) / 9.0 * 2.0 * Double.pi
                        MenuSunArt(rays: 8, glow: false)
                            .frame(width: s * 0.24, height: s * 0.24)
                            .position(x: w * 0.5 + CGFloat(cos(a)) * s * 0.34,
                                      y: h * 0.5 + CGFloat(sin(a)) * s * 0.34)
                    }
                    MenuSunArt(rays: 12)
                        .frame(width: s * 0.36, height: s * 0.36)
                        .position(x: w * 0.5, y: h * 0.5)
                case "daily":
                    // A sunrise over a calendar page.
                    MenuSunArt(rays: 10)
                        .frame(width: s * 0.6, height: s * 0.6)
                        .position(x: w * 0.5, y: h * 0.32)
                    RoundedRectangle(cornerRadius: s * 0.06, style: .continuous)
                        .fill(GlintTheme.cream)
                        .frame(width: s * 0.56, height: s * 0.46)
                        .position(x: w * 0.5, y: h * 0.66)
                    RoundedRectangle(cornerRadius: s * 0.06, style: .continuous)
                        .fill(GlintTheme.rose)
                        .frame(width: s * 0.56, height: s * 0.12)
                        .position(x: w * 0.5, y: h * 0.48)
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(GlintTheme.plum.opacity(0.7))
                            .frame(width: s * 0.06, height: s * 0.06)
                            .position(x: w * (0.36 + 0.14 * CGFloat(i % 3)), y: h * (0.64 + 0.12 * CGFloat(i / 3)))
                    }
                default:
                    // "longnight": a crescent moon and a ring of tiny stars.
                    ForEach(0..<10, id: \.self) { i in
                        let a = Double(i) / 10.0 * 2.0 * Double.pi
                        MenuSparkle()
                            .fill(GlintTheme.goldLight)
                            .frame(width: s * 0.09, height: s * 0.09)
                            .position(x: w * 0.5 + CGFloat(cos(a)) * s * 0.4,
                                      y: h * 0.5 + CGFloat(sin(a)) * s * 0.4)
                    }
                    MenuMoonArt()
                        .frame(width: s * 0.66, height: s * 0.66)
                        .position(x: w * 0.5, y: h * 0.5)
                }
            }
        }
    }
}

/// A curved streak (Clean Sweep).
struct SweepArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.78))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.9, y: rect.minY + rect.height * 0.25),
                       control: CGPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + rect.height * 0.75))
        return p
    }
}

/// A lighthouse's beam fanning out to the right.
struct LighthouseBeam: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.minY + rect.height * 0.27))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.46))
        p.closeSubpath()
        return p
    }
}

/// `screen=badges`: the ten badges on screen (for the frame), while `BadgeExport` writes the PNGs.
struct BadgeGallery: View {
    let ids: [String]
    let size: CGSize

    var body: some View {
        let cols = size.width > size.height ? 5 : 3
        let cell = min(size.width / CGFloat(cols), 200) - 12
        ZStack {
            Color(appHex: 0x141A3A).ignoresSafeArea()
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 12), count: cols), spacing: 12) {
                ForEach(0..<ids.count, id: \.self) { i in
                    AchievementBadge(key: BadgeBook.key(of: ids[i]), side: cell)
                        .frame(width: cell, height: cell)
                        .clipShape(RoundedRectangle(cornerRadius: cell * 0.12, style: .continuous))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Renders every badge at 1024 × 1024, opaque RGB (no alpha: `OpaquePNG`, flattened on #141A3A), to
/// Documents/badges/<id>.png, then prints `GLINT-T badges done <n>` (DEBUG demo only).
@MainActor
enum BadgeExport {
    static let side: CGFloat = 1024
    static let background = CGColor(red: 0x14 / 255.0, green: 0x1A / 255.0, blue: 0x3A / 255.0, alpha: 1)

    static func renderAll(ids: [String]) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            #if DEBUG
            AppTrace.demo("GLINT-T badges done 0 (no Documents directory)")
            #endif
            return
        }
        let directory = documents.appendingPathComponent("badges", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written = 0
        // R5 (store F5): the very first ImageRenderer pass came out empty (First Light was a flat #1B2349 PNG). Warm
        // the renderer with a throwaway badge, then never write a flat image: retry, and log it if it stays flat.
        _ = render(key: BadgeBook.keys.first ?? "firstlight")
        for id in ids {
            var picked: CGImage?
            for _ in 0..<3 {
                if let image = render(key: BadgeBook.key(of: id)), !isFlat(image) {
                    picked = image
                    break
                }
            }
            guard let image = picked, let data = OpaquePNG.encode(image, background: background) else {
                AppTrace.note("badge flat \(id)")
                #if DEBUG
                AppTrace.demo("GLINT-T badge flat \(id)")
                #endif
                continue
            }
            do {
                try data.write(to: directory.appendingPathComponent("\(id).png"))
                written += 1
            } catch {
                #if DEBUG
                AppTrace.demo("GLINT-T badges failed \(id): \(error.localizedDescription)")
                #endif
            }
        }
        AppTrace.note("badges \(written)")
        #if DEBUG
        AppTrace.demo("GLINT-T badges done \(written)")
        #endif
    }

    private static func render(key: String) -> CGImage? {
        let renderer = ImageRenderer(content: AchievementBadge(key: key, side: side))
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.cgImage
    }

    /// A badge with fewer than 16 colours on a 64 px sample is a failed render (a real one has hundreds). Pure given
    /// the image.
    nonisolated static func isFlat(_ image: CGImage) -> Bool {
        IconPainter.stats(image).colours < 16
    }
}
