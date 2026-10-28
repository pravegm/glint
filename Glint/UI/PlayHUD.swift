import SwiftUI

/// The play overlay. Score and chain sit in the garden half's flower-edge corner (u = 0), the pause button in the
/// other flower-edge corner (u = 1): both follow `GardenLayout`, so they agree with the art in every layout. The start
/// line sits on the garden (nothing moves there yet), the one-line hints and banners on the mirror half. Nothing here
/// draws light: the scene draws only what the hinge (or the finger) makes.
struct PlayHUD: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDModel
    let canvas: AppCanvas

    var body: some View {
        let layout = canvas.layout
        let c = canvas.compact
        let scoreSize = CGSize(width: c ? 120 : 140, height: c ? 52 : 58)
        let pauseSize = CGSize(width: 56, height: 56)
        let garden = layout.gardenRect
        let mirror = layout.mirrorRect
        ZStack {
            ScorePill(state: hud.state, compact: c)
                .frame(width: scoreSize.width, height: scoreSize.height)
                .position(AppRules.hudCenter(u: 0, item: scoreSize, layout: layout, insets: canvas.insets, margin: 10))
                .allowsHitTesting(false)

            RoundIconButton(symbol: "pause.fill", label: "Pause", size: pauseSize.width) {
                controller.pauseTapped()
            }
            .position(AppRules.hudCenter(u: 1, item: pauseSize, layout: layout, insets: canvas.insets, margin: 10))
            .opacity(controller.pause.menu ? 0 : 1)

            if let prompt = controller.prompt {
                PromptCard(prompt: prompt, compact: c)
                    .frame(maxWidth: max(min(garden.width - 32, 460), 200))
                    .position(x: garden.midX, y: garden.midY)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let hint = controller.hint {
                HintLine(text: HintRules.text(hint), compact: c)
                    .frame(maxWidth: max(mirror.width - 32, 200))
                    .position(x: mirror.midX, y: mirror.midY)
                    .allowsHitTesting(false)
                    .transition(.opacity)
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
            if state.multiplier > 1.001 {
                Text("×" + AppTrace.fixed(state.multiplier, state.multiplier.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2))
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
