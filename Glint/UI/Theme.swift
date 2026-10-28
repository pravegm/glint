import SwiftUI
import UIKit

/// The look (GAME-DESIGN §10): a warm dawn over a night garden. Deep indigo → plum → peach → gold, SF Rounded
/// throughout (Black for the wordmark and big numbers, Heavy for titles, Bold for buttons, Semibold for body). Every
/// menu takes colour, type, shape and motion from here; every card carries real art (drawn below in SwiftUI).
enum GlintTheme {
    // Night, darkest → lightest
    static let night = Color(appHex: 0x0A0A24)
    static let indigo = Color(appHex: 0x17154A)
    static let dusk = Color(appHex: 0x2C2066)
    static let plum = Color(appHex: 0x52306E)
    // Dawn
    static let rose = Color(appHex: 0xC75F7C)
    static let peach = Color(appHex: 0xF8A47E)
    static let gold = Color(appHex: 0xFFC94D)
    static let goldLight = Color(appHex: 0xFFE8A6)
    static let goldDeep = Color(appHex: 0xC8841C)
    // Brass (the mirror frame)
    static let brassLight = Color(appHex: 0xE9C27A)
    static let brass = Color(appHex: 0xB98B3F)
    static let brassDark = Color(appHex: 0x6F4C1D)
    // Text
    static let cream = Color(appHex: 0xFFF5E2)
    static let mist = Color(appHex: 0xDCD0EC)
    static let haze = Color(appHex: 0xA294C2)
    /// Text on gold.
    static let ink = Color(appHex: 0x2B1708)
    // Garden
    static let teal = Color(appHex: 0x1D5C66)
    static let leaf = Color(appHex: 0x63B88C)
    static let grass = Color(appHex: 0x2E7A5E)
    // Shadows (the glooms)
    static let gloom = Color(appHex: 0x1B0D2D)
    static let gloomRim = Color(appHex: 0x3D2660)
    // Surfaces
    static let card = Color(appHex: 0x211B55)
    static let cardRaised = Color(appHex: 0x2E2670)
    static let cardDeep = Color(appHex: 0x15123D)
    static let stroke = Color.white.opacity(0.12)

    /// Flower petal colours (Home art, results).
    static let petals: [Color] = [Color(appHex: 0xFF8FA3), Color(appHex: 0xFFD166), Color(appHex: 0x9BE7FF),
                                  Color(appHex: 0xC3A6FF), Color(appHex: 0xFFB38A)]

    /// Hit targets are never smaller.
    static let minTap: CGFloat = 56
    static let buttonHeight: CGFloat = 64

    /// World tints (Meadow, Rooftops, Harbour).
    static func worldTint(_ world: Int) -> Color {
        switch world {
        case 2: return Color(appHex: 0x7A3B6E)
        case 3: return Color(appHex: 0x1E4E6E)
        default: return Color(appHex: 0x2F5A4A)
        }
    }

    /// UI settle: a spring. Reduce Motion: a short crossfade.
    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)
    }

    static func pop(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.32, dampingFraction: 0.6)
    }

    static var goldFace: LinearGradient {
        LinearGradient(colors: [goldLight, gold, Color(appHex: 0xF7A93B)], startPoint: .top, endPoint: .bottom)
    }

    static var brassFace: LinearGradient {
        LinearGradient(colors: [brassLight, brass, brassDark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var dawnSky: LinearGradient {
        LinearGradient(colors: [dusk, plum, rose, peach, goldLight], startPoint: .top, endPoint: .bottom)
    }
}

/// The type scale (`compact` = a phone-sized canvas).
enum GlintType {
    static func wordmark(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func hero(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded).monospacedDigit() }
    static func title(_ compact: Bool) -> Font { .system(size: compact ? 26 : 32, weight: .heavy, design: .rounded) }
    static func headline(_ compact: Bool) -> Font { .system(size: compact ? 18 : 21, weight: .bold, design: .rounded) }
    static func body(_ compact: Bool) -> Font { .system(size: compact ? 15 : 17, weight: .semibold, design: .rounded) }
    static func caption(_ compact: Bool) -> Font { .system(size: compact ? 13 : 14, weight: .semibold, design: .rounded) }
    static func button(_ compact: Bool) -> Font { .system(size: compact ? 20 : 22, weight: .heavy, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
}

extension Color {
    /// 0xRRGGBB.
    init(appHex hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// The canvas a screen is laid out in (the whole window, safe-area insets to pad with, the garden layout).
struct AppCanvas: Equatable {
    var size: CGSize
    var insets: EdgeInsets
    var layout: GardenLayout
    /// The Duo split layout: menus keep off the crease (`AppRules.menuRegions`).
    var isDuo: Bool = false

    var compact: Bool { min(size.width, size.height) < 500 }
    var landscape: Bool { size.width > size.height }
    /// Room for two columns (a Duo's inner display, a phone held sideways).
    var wide: Bool { size.width >= 700 && size.width > size.height * 1.1 }
    var regions: AppRules.MenuRegions { AppRules.menuRegions(layout: layout, insets: insets, isDuo: isDuo) }
}

/// A menu page in two parts. On a phone: one scrolling column (`top` then `bottom`), centred. On a Duo split layout:
/// `top` (titles, art) on the mirror half and `bottom` (the controls) on the garden half, each in its own region
/// `AppRules.creaseClearance` clear of the crease, so nothing tappable ever sits across the fold (R2 addendum).
/// `scrolls` false: no scroll views (the level map lays itself out in the region it gets).
struct SplitMenu<Top: View, Bottom: View>: View {
    let canvas: AppCanvas
    let scrolls: Bool
    let maxWidth: CGFloat
    let top: () -> Top
    let bottom: () -> Bottom

    init(canvas: AppCanvas, scrolls: Bool = true, maxWidth: CGFloat = 560, @ViewBuilder top: @escaping () -> Top,
         @ViewBuilder bottom: @escaping () -> Bottom) {
        self.canvas = canvas
        self.scrolls = scrolls
        self.maxWidth = maxWidth
        self.top = top
        self.bottom = bottom
    }

    var body: some View {
        let regions = canvas.regions
        ZStack {
            if let secondary = regions.secondary {
                SplitRegion(rect: secondary, scrolls: scrolls, maxWidth: maxWidth) { top() }
                SplitRegion(rect: regions.primary, scrolls: scrolls, maxWidth: maxWidth) { bottom() }
            } else {
                SplitRegion(rect: regions.primary, scrolls: scrolls, maxWidth: maxWidth) {
                    VStack(spacing: canvas.compact ? 14 : 18) {
                        top()
                        bottom()
                    }
                }
            }
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }
}

/// One region of a `SplitMenu`: its content centred (scrolling when it is taller), placed at `rect`.
struct SplitRegion<Content: View>: View {
    let rect: CGRect
    let scrolls: Bool
    let maxWidth: CGFloat
    let content: () -> Content

    init(rect: CGRect, scrolls: Bool, maxWidth: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.rect = rect
        self.scrolls = scrolls
        self.maxWidth = maxWidth
        self.content = content
    }

    var body: some View {
        let w = max(rect.width, 1)
        let h = max(rect.height, 1)
        Group {
            if scrolls {
                ScrollView(.vertical) {
                    content()
                        .frame(maxWidth: maxWidth)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: h)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            } else {
                content()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: w, height: h)
        .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Buttons

/// Big pill buttons with real depth: a darker lip under the face that presses down.
struct GlintButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    var kind: Kind = .primary
    var height: CGFloat = GlintTheme.buttonHeight
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let h = max(height, GlintTheme.minTap)
        return configuration.label
            .font(kind == .quiet ? GlintType.body(compact) : GlintType.button(compact))
            .foregroundStyle(kind == .primary ? GlintTheme.ink : GlintTheme.cream)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: h)
            .background(GlintButtonFace(kind: kind, pressed: pressed))
            .offset(y: pressed && kind != .quiet ? 3 : 0)
            .scaleEffect(pressed ? 0.98 : 1)
            .opacity(kind == .quiet && pressed ? 0.6 : 1)
            .contentShape(Capsule())
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }
}

struct GlintButtonFace: View {
    let kind: GlintButtonStyle.Kind
    let pressed: Bool

    var body: some View {
        ZStack {
            switch kind {
            case .primary:
                Capsule().fill(GlintTheme.goldDeep).offset(y: pressed ? 1 : 5)
                Capsule().fill(GlintTheme.goldFace)
                Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5).padding(1)
                    .mask {
                        LinearGradient(colors: [Color.white, Color.clear], startPoint: .top, endPoint: .center)
                    }
                    .shadow(color: GlintTheme.gold.opacity(0.35), radius: 16, y: 4)
            case .secondary:
                Capsule().fill(GlintTheme.cardDeep).offset(y: pressed ? 1 : 4)
                Capsule().fill(LinearGradient(colors: [GlintTheme.cardRaised, GlintTheme.card], startPoint: .top,
                                              endPoint: .bottom))
                Capsule().strokeBorder(GlintTheme.stroke, lineWidth: 1)
            case .quiet:
                Color.clear
            }
        }
    }
}

/// A small press-scale for art buttons (cards, medallions, round icons).
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct RoundIconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(GlintTheme.cream)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        Circle().fill(GlintTheme.cardDeep).offset(y: 3)
                        Circle().fill(LinearGradient(colors: [GlintTheme.cardRaised, GlintTheme.card],
                                                     startPoint: .top, endPoint: .bottom))
                        Circle().strokeBorder(GlintTheme.stroke, lineWidth: 1)
                    }
                )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Surfaces

struct CardBackground: View {
    var radius: CGFloat = 26
    var tint: Color = GlintTheme.card

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [tint.opacity(0.97), GlintTheme.cardDeep.opacity(0.97)], startPoint: .top,
                                      endPoint: .bottom))
            shape.fill(RadialGradient(colors: [GlintTheme.peach.opacity(0.16), Color.clear],
                                      center: UnitPoint(x: 0.5, y: 0), startRadius: 4, endRadius: 260))
            shape.strokeBorder(LinearGradient(colors: [GlintTheme.brassLight.opacity(0.55), GlintTheme.stroke],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
        }
        .shadow(color: Color.black.opacity(0.4), radius: 18, y: 8)
    }
}

/// The dim glass over the live garden for full-screen menus. R2 (review P1-14): a real blur plus a deep #140F2E scrim,
/// so the scene's rails and the sun don't show through as clutter.
struct MenuScrim: View {
    var tint: Color = GlintTheme.dusk

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color(appHex: 0x140F2E).opacity(0.55)
            LinearGradient(colors: [GlintTheme.night.opacity(0.55), GlintTheme.indigo.opacity(0.35), tint.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [GlintTheme.peach.opacity(0.22), Color.clear], center: UnitPoint(x: 0.5, y: 0),
                           startRadius: 10, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

struct MenuHeader: View {
    let title: String
    var compact = false
    var trailing: AnyView? = nil
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundIconButton(symbol: "chevron.left", label: "Back", size: 50, action: onBack)
            Spacer(minLength: 8)
            Text(title)
                .font(GlintType.title(compact))
                .foregroundStyle(GlintTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            if let trailing {
                trailing.frame(minWidth: 50)
            } else {
                Color.clear.frame(width: 50, height: 50)
            }
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(GlintType.body(true))
            .foregroundStyle(GlintTheme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(GlintTheme.goldFace))
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
            .padding(.horizontal, 24)
            .allowsHitTesting(false)
    }
}

// MARK: - Art (drawn in SwiftUI; real art on every card)

struct MenuStarRow: View {
    let filled: Int
    var total = 3
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: size * 0.18) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(i < filled ? GlintTheme.gold : Color.white.opacity(0.18))
                    .shadow(color: i < filled ? GlintTheme.gold.opacity(0.6) : Color.clear, radius: size * 0.3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(total) stars")
    }
}

/// A warm sun with rays.
struct MenuSunArt: View {
    var rays = 12
    var glow = true

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                if glow {
                    Circle().fill(RadialGradient(colors: [GlintTheme.gold.opacity(0.55), GlintTheme.gold.opacity(0)],
                                                 center: .center, startRadius: s * 0.12, endRadius: s * 0.5))
                }
                ForEach(0..<rays, id: \.self) { i in
                    Capsule()
                        .fill(GlintTheme.goldLight.opacity(0.9))
                        .frame(width: s * 0.05, height: s * 0.14)
                        .offset(y: -s * 0.36)
                        .rotationEffect(.degrees(Double(i) * 360.0 / Double(max(rays, 1))))
                }
                Circle()
                    .fill(LinearGradient(colors: [GlintTheme.goldLight, GlintTheme.gold, GlintTheme.peach],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.46, height: s * 0.46)
                    .shadow(color: GlintTheme.gold.opacity(0.6), radius: s * 0.06)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

/// The sun half over a dark hill: Today's Dawn, sunrise results.
struct MenuSunriseArt: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                GlintTheme.dawnSky
                MenuSunArt(rays: 10)
                    .frame(width: h * 0.9, height: h * 0.9)
                    .position(x: w * 0.5, y: h * 0.72)
                Ellipse()
                    .fill(LinearGradient(colors: [GlintTheme.grass, GlintTheme.teal], startPoint: .top,
                                         endPoint: .bottom))
                    .frame(width: w * 1.5, height: h * 0.6)
                    .position(x: w * 0.5, y: h * 1.08)
                MenuFlowerArt(petal: GlintTheme.petals[0])
                    .frame(width: h * 0.2, height: h * 0.2)
                    .position(x: w * 0.25, y: h * 0.86)
                MenuFlowerArt(petal: GlintTheme.petals[1])
                    .frame(width: h * 0.17, height: h * 0.17)
                    .position(x: w * 0.75, y: h * 0.88)
            }
            .clipShape(RoundedRectangle(cornerRadius: min(w, h) * 0.2, style: .continuous))
        }
        .accessibilityHidden(true)
    }
}

/// A brass-framed mirror showing the dawn sky (the top half of the phone).
struct MenuMirrorArt: View {
    var sun: Double = 0.45

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s = min(w, h)
            let rim = s * 0.09
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.2, style: .continuous).fill(GlintTheme.brassFace)
                RoundedRectangle(cornerRadius: s * 0.2, style: .continuous)
                    .strokeBorder(GlintTheme.brassLight.opacity(0.8), lineWidth: max(s * 0.015, 1))
                ZStack {
                    GlintTheme.dawnSky
                    Circle()
                        .fill(GlintTheme.goldLight)
                        .frame(width: s * 0.24, height: s * 0.24)
                        .shadow(color: GlintTheme.gold, radius: s * 0.08)
                        .position(x: (w - rim * 2) * 0.5, y: (h - rim * 2) * CGFloat(0.78 - 0.45 * sun))
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: s * 0.07, height: h * 0.7)
                        .rotationEffect(.degrees(28))
                        .position(x: (w - rim * 2) * 0.28, y: (h - rim * 2) * 0.45)
                }
                .clipShape(RoundedRectangle(cornerRadius: s * 0.13, style: .continuous))
                .padding(rim)
            }
        }
        .accessibilityHidden(true)
    }
}

struct MenuFlowerArt: View {
    let petal: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Ellipse()
                        .fill(petal)
                        .frame(width: s * 0.36, height: s * 0.5)
                        .offset(y: -s * 0.24)
                        .rotationEffect(.degrees(Double(i) * 72))
                }
                Circle().fill(GlintTheme.goldLight).frame(width: s * 0.3, height: s * 0.3)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

/// An inky shadow blob with big white eyes (`squint` 0 = wide open, 1 = shut tight).
struct MenuGloomArt: View {
    var squint: Double = 0.2

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                MenuBlobShape()
                    .fill(RadialGradient(colors: [GlintTheme.gloomRim, GlintTheme.gloom], center: UnitPoint(x: 0.4, y: 0.35),
                                         startRadius: 0, endRadius: s * 0.62))
                MenuBlobShape()
                    .stroke(GlintTheme.peach.opacity(0.5), lineWidth: max(s * 0.025, 1))
                HStack(spacing: s * 0.1) {
                    MenuEyeArt(squint: squint)
                    MenuEyeArt(squint: squint)
                }
                .frame(width: s * 0.5, height: s * 0.2)
                .offset(y: -s * 0.04)
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

struct MenuEyeArt: View {
    var squint: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lid = h * CGFloat(min(max(squint, 0), 1)) * 0.8
            ZStack(alignment: .top) {
                Ellipse().fill(Color.white)
                Circle()
                    .fill(GlintTheme.night)
                    .frame(width: min(w, h) * 0.45, height: min(w, h) * 0.45)
                    .position(x: w * 0.55, y: h * 0.62)
                Rectangle()
                    .fill(Color(appHex: 0x2A1842))
                    .frame(width: w, height: lid)
            }
            .frame(width: w, height: h)
            .clipShape(Ellipse())
        }
    }
}

/// A wobbly blob (the glooms' body).
struct MenuBlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pt: (CGFloat, CGFloat) -> CGPoint = { fx, fy in
            CGPoint(x: rect.minX + rect.width * fx, y: rect.minY + rect.height * fy)
        }
        var p = Path()
        p.move(to: pt(0.5, 0.06))
        p.addCurve(to: pt(0.95, 0.55), control1: pt(0.8, 0.02), control2: pt(1.0, 0.3))
        p.addCurve(to: pt(0.55, 0.96), control1: pt(0.92, 0.8), control2: pt(0.78, 0.98))
        p.addCurve(to: pt(0.06, 0.62), control1: pt(0.3, 0.95), control2: pt(0.04, 0.85))
        p.addCurve(to: pt(0.5, 0.06), control1: pt(0.08, 0.3), control2: pt(0.22, 0.08))
        p.closeSubpath()
        return p
    }
}

/// A crescent moon (Long Night).
struct MenuMoonArt: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle().fill(RadialGradient(colors: [GlintTheme.mist.opacity(0.35), Color.clear], center: .center,
                                             startRadius: s * 0.2, endRadius: s * 0.5))
                Circle()
                    .fill(LinearGradient(colors: [GlintTheme.cream, GlintTheme.mist], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * 0.62, height: s * 0.62)
                    .mask {
                        ZStack {
                            Rectangle()
                            Circle()
                                .frame(width: s * 0.56, height: s * 0.56)
                                .offset(x: s * 0.2, y: -s * 0.12)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    }
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

/// A four-point sparkle (the wordmark's glint).
struct MenuSparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.22
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

/// The wordmark: the product name in gold, with a glint.
struct Wordmark: View {
    let size: CGFloat

    var body: some View {
        Text(AppBrand.name)
            .font(GlintType.wordmark(size))
            .foregroundStyle(LinearGradient(colors: [GlintTheme.goldLight, GlintTheme.gold, GlintTheme.peach],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: GlintTheme.gold.opacity(0.45), radius: size * 0.16)
            .overlay(alignment: .topTrailing) {
                MenuSparkle()
                    .fill(GlintTheme.cream)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .shadow(color: GlintTheme.goldLight, radius: size * 0.08)
                    .offset(x: size * 0.16, y: -size * 0.08)
            }
            .accessibilityAddTraits(.isHeader)
    }
}

/// The world badges (Meadow flowers, Rooftops roofs, Harbour waves).
struct WorldArt: View {
    let world: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                switch world {
                case 2:
                    RoofsShape().fill(LinearGradient(colors: [GlintTheme.rose, GlintTheme.plum], startPoint: .top,
                                                     endPoint: .bottom))
                    MenuSunArt(rays: 8, glow: false)
                        .frame(width: h * 0.45, height: h * 0.45)
                        .position(x: w * 0.78, y: h * 0.22)
                case 3:
                    WavesShape().fill(LinearGradient(colors: [Color(appHex: 0x5CC3D8), GlintTheme.teal],
                                                     startPoint: .top, endPoint: .bottom))
                    MenuMoonArt()
                        .frame(width: h * 0.5, height: h * 0.5)
                        .position(x: w * 0.25, y: h * 0.25)
                default:
                    MenuFlowerArt(petal: GlintTheme.petals[0])
                        .frame(width: h * 0.55, height: h * 0.55)
                        .position(x: w * 0.3, y: h * 0.55)
                    MenuFlowerArt(petal: GlintTheme.petals[1])
                        .frame(width: h * 0.45, height: h * 0.45)
                        .position(x: w * 0.7, y: h * 0.45)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct RoofsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let pt: (CGFloat, CGFloat) -> CGPoint = { fx, fy in
            CGPoint(x: rect.minX + rect.width * fx, y: rect.minY + rect.height * fy)
        }
        var p = Path()
        p.move(to: pt(0, 1))
        p.addLine(to: pt(0, 0.55))
        p.addLine(to: pt(0.2, 0.3))
        p.addLine(to: pt(0.4, 0.55))
        p.addLine(to: pt(0.4, 0.45))
        p.addLine(to: pt(0.62, 0.2))
        p.addLine(to: pt(0.84, 0.45))
        p.addLine(to: pt(0.84, 0.6))
        p.addLine(to: pt(1, 0.6))
        p.addLine(to: pt(1, 1))
        p.closeSubpath()
        return p
    }
}

struct WavesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let baseY = rect.minY + rect.height * 0.55
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: baseY))
        let steps = 24
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + rect.width * f
            let y = baseY + CGFloat(sin(Double(f) * Double.pi * 4)) * rect.height * 0.08
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
