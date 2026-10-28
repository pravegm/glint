import SwiftUI

/// The play overlay. R2: score and chain sit in the MIRROR half's far corner on the u = 0 side, the pause button in
/// its far corner on the u = 1 side (away from the crease; `AppRules.hudCenter`), so no SwiftUI plate ever covers a
/// flower (`GardenScene.flowerRects`, tested in all four layouts). The start line sits on the garden towards the crease
/// (nothing moves there yet), the one-line hints and banners on the mirror half. Nothing here draws light: the scene
/// draws only what the hinge (or the finger) makes.
struct PlayHUD: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDModel
    let canvas: AppCanvas

    /// The HUD plates' sizes (the overlap test uses the same numbers).
    static func scoreSize(compact: Bool) -> CGSize { CGSize(width: compact ? 120 : 140, height: compact ? 52 : 58) }
    static let pauseSize = CGSize(width: 56, height: 56)
    static let margin: CGFloat = 10

    var body: some View {
        let layout = canvas.layout
        let c = canvas.compact
        let scoreSize = Self.scoreSize(compact: c)
        let pauseSize = Self.pauseSize
        let mirror = layout.mirrorRect
        ZStack {
            ScorePill(state: hud.state, compact: c)
                .frame(width: scoreSize.width, height: scoreSize.height)
                .position(AppRules.hudCenter(u: 0, item: scoreSize, layout: layout, insets: canvas.insets,
                                             margin: Self.margin))
                .allowsHitTesting(false)

            RoundIconButton(symbol: "pause.fill", label: "Pause", size: pauseSize.width) {
                controller.pauseTapped()
            }
            .position(AppRules.hudCenter(u: 1, item: pauseSize, layout: layout, insets: canvas.insets,
                                         margin: Self.margin))
            .opacity(controller.pause.menu ? 0 : 1)

            if let prompt = controller.prompt {
                let maxSize = AppRules.promptMaxSize(layout: layout)
                PromptCard(prompt: prompt, compact: c)
                    .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
                    .position(AppRules.promptCenter(layout: layout))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let hint = controller.hint {
                // R2 addendum: on the garden (never over the sun), with a small arrow at the thing it is about.
                let at = AppRules.hintCenter(layout: layout)
                HintLine(text: HintRules.text(hint), compact: c)
                    .frame(maxWidth: min(AppRules.promptMaxSize(layout: layout).width, 420))
                    .position(at)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                if let target = hud.hintTarget {
                    HintArrow(from: at, to: target)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }

            if let banner = hud.banner {
                Text(banner)
                    .font(GlintType.wordmark(c ? 34 : 44))
                    .foregroundStyle(GlintTheme.goldFace)
                    .shadow(color: GlintTheme.night.opacity(0.8), radius: 8)
                    .position(x: mirror.midX, y: mirror.midY + (controller.hint == nil ? 0 : 64))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if controller.pause.shut && !controller.pause.menu {
                // Normally the cover display shows this; if the inner display is still up, say so (and offer Home).
                ShutCard(score: hud.state.score, compact: c) {
                    controller.goHome()
                }
                .position(x: canvas.size.width / 2, y: canvas.size.height / 2)
                .transition(.opacity)
            }

            if controller.pause.menu {
                PauseView(controller: controller, score: hud.state.score, canvas: canvas)
                    .transition(.opacity)
            }
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
        .animation(.easeInOut(duration: 0.3), value: controller.prompt)
        .animation(.easeInOut(duration: 0.3), value: controller.hint)
        .animation(.easeInOut(duration: 0.25), value: controller.pause)
        .animation(.easeInOut(duration: 0.25), value: hud.banner)
    }
}

/// A small gold arrow between the hint line and its subject (pointing at it). Hidden when the subject is too close.
struct HintArrow: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = (dx * dx + dy * dy).squareRoot()
        // Just short of the subject, pointing at it (the hint plate stays where it is).
        let back: CGFloat = 34
        let ux = dist > 0 ? dx / dist : 0
        let uy = dist > 0 ? dy / dist : 0
        let angle = AppRules.angle(from: from, to: to)
        Image(systemName: "arrowtriangle.right.fill")
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(GlintTheme.gold)
            .shadow(color: GlintTheme.night.opacity(0.8), radius: 4)
            .rotationEffect(.radians(angle))
            .position(x: to.x - ux * back, y: to.y - uy * back)
            .opacity(dist > 70 ? 1 : 0)
    }
}

struct ScorePill: View {
    let state: HUDState
    let compact: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(AppRules.grouped(state.score))
                .font(GlintType.number(compact ? 24 : 28))
                .foregroundStyle(GlintTheme.cream)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if state.chain >= 2 {
                // R2 (review P2-16): a whole count, no arithmetic to read.
                Text("Chain \(state.chain)")
                    .font(GlintType.caption(compact))
                    .foregroundStyle(GlintTheme.gold)
            } else if state.wave > 0 {
                Text("Wave \(state.wave)")
                    .font(GlintType.caption(compact))
                    .foregroundStyle(GlintTheme.mist)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Capsule().fill(GlintTheme.night.opacity(0.55))
                Capsule().strokeBorder(GlintTheme.brassLight.opacity(0.4), lineWidth: 1)
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(state.score)")
    }
}

struct PromptCard: View {
    let prompt: PromptLine
    let compact: Bool

    var body: some View {
        VStack(spacing: 8) {
            PromptArt(prompt: prompt)
                .frame(width: compact ? 64 : 80, height: compact ? 64 : 80)
            Text(prompt.text)
                .font(GlintType.headline(compact))
                .foregroundStyle(GlintTheme.cream)
                .multilineTextAlignment(.center)
            Text(prompt.detail)
                .font(GlintType.caption(compact))
                .foregroundStyle(GlintTheme.mist)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(CardBackground(radius: 24))
        .accessibilityElement(children: .combine)
    }
}

/// A tiny phone drawing for the start line: shut (close), half-open with light (open), or a finger (drag).
struct PromptArt: View {
    let prompt: PromptLine

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                switch prompt {
                case .closeToStart:
                    RoundedRectangle(cornerRadius: s * 0.1, style: .continuous)
                        .fill(GlintTheme.brassFace)
                        .frame(width: s * 0.7, height: s * 0.16)
                        .offset(y: s * 0.12)
                    RoundedRectangle(cornerRadius: s * 0.1, style: .continuous)
                        .fill(GlintTheme.cardRaised)
                        .frame(width: s * 0.7, height: s * 0.16)
                        .rotationEffect(.degrees(-28), anchor: .leading)
                        .offset(y: s * 0.0)
                    Image(systemName: "arrow.down")
                        .font(.system(size: s * 0.24, weight: .black))
                        .foregroundStyle(GlintTheme.goldLight)
                        .offset(x: s * 0.2, y: -s * 0.26)
                case .openToLight:
                    MenuSunArt(rays: 8)
                        .frame(width: s * 0.6, height: s * 0.6)
                        .offset(y: -s * 0.15)
                    RoundedRectangle(cornerRadius: s * 0.1, style: .continuous)
                        .fill(GlintTheme.brassFace)
                        .frame(width: s * 0.7, height: s * 0.16)
                        .offset(y: s * 0.22)
                case .drag:
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: s * 0.5, weight: .bold))
                        .foregroundStyle(GlintTheme.goldLight)
                }
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityHidden(true)
    }
}

struct HintLine: View {
    let text: String
    let compact: Bool

    var body: some View {
        Text(text)
            .font(GlintType.headline(compact))
            .foregroundStyle(GlintTheme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(GlintTheme.goldFace))
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
    }
}

/// The phone shut mid-level while the inner display is still showing (the cover view normally takes over).
struct ShutCard: View {
    let score: Int
    let compact: Bool
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            MenuMoonArt().frame(width: 64, height: 64)
            Text(CoverLine.paused(score: score).text)
                .font(GlintType.headline(compact))
                .foregroundStyle(GlintTheme.cream)
                .multilineTextAlignment(.center)
            Text("Score \(AppRules.grouped(score))")
                .font(GlintType.body(compact))
                .foregroundStyle(GlintTheme.goldLight)
            Button("Home", action: onHome)
                .buttonStyle(GlintButtonStyle(kind: .secondary, height: 56, compact: compact))
                .frame(maxWidth: 240)
        }
        .padding(22)
        .frame(maxWidth: 380)
        .background(CardBackground())
    }
}
