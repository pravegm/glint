import SwiftUI

/// The play overlay. Score and chain sit in the MIRROR half's far corner on the u = 0 side, the pause button in its far
/// corner on the u = 1 side (away from the crease; `AppRules.hudCenter`), R3: at least 12 pt inside the brass frame
/// (`AppRules.hudMargin`). No SwiftUI plate ever covers a flower (`GardenScene.hudSafeRects`, tested in all four
/// layouts). Today's Dawn adds a date chip at the mirror's far edge, centred. The start line sits on the garden towards
/// the crease, with the 3rd-star target under it; hints sit on the garden, only while their subject is on the field,
/// with an arrow and a ring at it. Nothing here draws light: the scene draws only what the hinge (or the finger) makes.
struct PlayHUD: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDModel
    let canvas: AppCanvas

    /// The HUD plates' sizes (the overlap tests use the same numbers).
    static func scoreSize(compact: Bool) -> CGSize { CGSize(width: compact ? 132 : 152, height: compact ? 54 : 60) }
    static let pauseSize = CGSize(width: 56, height: 56)
    static let dateChipSize = CGSize(width: 128, height: 36)

    var body: some View {
        let layout = canvas.layout
        let c = canvas.compact
        let scoreSize = Self.scoreSize(compact: c)
        let pauseSize = Self.pauseSize
        let margin = AppRules.hudMargin(layout: layout)
        let mirror = layout.mirrorRect
        let isDaily = AppRules.dailyDay(controller.playMode) != nil
        let scoreCenter = AppRules.hudCenter(u: 0, item: scoreSize, layout: layout, insets: canvas.insets,
                                             margin: margin)
        let pauseCenter = AppRules.hudCenter(u: 1, item: pauseSize, layout: layout, insets: canvas.insets,
                                             margin: margin)
        ZStack {
            // R5 (VoiceOver, phones): the garden is an adjustable "Light": swipe up or down to move the band.
            if controller.dragDriven && controller.stage == .live && !controller.levelOver {
                Color.clear
                    .frame(width: layout.gardenRect.width, height: layout.gardenRect.height)
                    .position(x: layout.gardenRect.midX, y: layout.gardenRect.midY)
                    .allowsHitTesting(false)
                    .accessibilityElement()
                    .accessibilityLabel("Light")
                    .accessibilityValue(AppRules.lightValue(hud.state.band))
                    .accessibilityHint("Swipe up or down to move the light towards or away from the flowers")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: controller.nudgeLight(0.1)
                        case .decrement: controller.nudgeLight(-0.1)
                        @unknown default: break
                        }
                    }
            }

            ScorePill(state: hud.state, compact: c)
                .frame(width: scoreSize.width, height: scoreSize.height)
                .position(scoreCenter)
                .allowsHitTesting(false)

            if !controller.levelOver {
                // R5 (QA P0-1): no pause once the level is over (its result is already saved).
                RoundIconButton(symbol: "pause.fill", label: "Pause", size: pauseSize.width) {
                    controller.pauseTapped()
                }
                .position(pauseCenter)
                .opacity(controller.pause.menu ? 0 : 1)
            }

            if isDaily {
                // Today's Dawn's date chip (R5: the player's local date of this run), placed by the plates' real rects.
                Text(AppRules.localDateChip(controller.runStart))
                    .font(GlintType.caption(c))
                    .foregroundStyle(GlintTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(height: Self.dateChipSize.height)
                    .background(Capsule().fill(GlintTheme.goldFace))
                    .position(AppRules.dateChipCenter(chip: Self.dateChipSize,
                                                      score: AppRules.rect(center: scoreCenter, size: scoreSize),
                                                      pause: AppRules.rect(center: pauseCenter, size: pauseSize),
                                                      layout: layout))
                    .allowsHitTesting(false)
            }

            if let prompt = controller.prompt {
                let maxSize = AppRules.promptMaxSize(layout: layout)
                PromptCard(prompt: prompt, compact: c, starLine: controller.startStarLine,
                           reduceMotion: controller.reduceMotion, bookPose: layout.foldVertical)
                    .frame(maxWidth: maxSize.width, maxHeight: maxSize.height)
                    .position(AppRules.promptCenter(layout: layout))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let hint = controller.hint, let target = hud.hintTarget {
                // On the garden (never over the sun), only while its subject is on the field, pointing at it.
                let at = AppRules.hintCenter(layout: layout)
                HintRing(target: target, firefly: hint == .spareTheFireflies, reduceMotion: controller.reduceMotion)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                HintLine(text: HintRules.text(hint), compact: c)
                    .frame(maxWidth: min(AppRules.promptMaxSize(layout: layout).width, 420))
                    .opacity(0.88)
                    .position(at)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                HintArrow(from: at, to: target)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let banner = hud.banner {
                Text(banner)
                    .font(GlintType.wordmark(c ? 34 : 44))
                    .foregroundStyle(GlintTheme.goldFace)
                    .shadow(color: GlintTheme.night.opacity(0.8), radius: 8)
                    .position(x: mirror.midX, y: mirror.midY)
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
        let back: CGFloat = 40
        let ux = dist > 0 ? dx / dist : 0
        let uy = dist > 0 ? dy / dist : 0
        let angle = AppRules.angle(from: from, to: to)
        Image(systemName: "arrowtriangle.right.fill")
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(GlintTheme.gold)
            .shadow(color: GlintTheme.night.opacity(0.8), radius: 4)
            .rotationEffect(.radians(angle))
            .position(x: to.x - ux * back, y: to.y - uy * back)
            .opacity(dist > 80 ? 1 : 0)
    }
}

/// REVIEW-2 fix 7: a soft ring around the hint's subject (lime-green for a firefly, gold for a shadow), breathing.
struct HintRing: View {
    let target: CGPoint
    let firefly: Bool
    let reduceMotion: Bool
    @State private var breathe = false

    var body: some View {
        Circle()
            .strokeBorder(firefly ? Color(appHex: 0xC8FF6A) : GlintTheme.gold, lineWidth: 3)
            .frame(width: 58, height: 58)
            .scaleEffect(breathe ? 1.12 : 0.94)
            .opacity(breathe ? 0.65 : 1)
            .position(target)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { breathe = true }
            }
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
            // R5: the multiplier ("×2.5", up to ×4), never the raw chain count. Long Night's wave always shows.
            if let line = AppRules.scoreSubline(multiplier: state.multiplier, wave: state.wave) {
                Text(line)
                    .font(GlintType.caption(compact))
                    .foregroundStyle(GlintTheme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Capsule().fill(GlintTheme.night.opacity(0.6))
                Capsule().strokeBorder(GlintTheme.brassLight.opacity(0.4), lineWidth: 1)
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(state.score)")
    }
}

/// The start card. R3 (REVIEW-2 fix 6): one line of instruction only (no second line saying the same thing) and an
/// animated drawing; the level's 3rd-star target under it ("★★★ 1,400").
struct PromptCard: View {
    let prompt: PromptLine
    let compact: Bool
    var starLine: String? = nil
    var reduceMotion = false
    /// R5 (player QA #26): the phone drawing turns to the book pose's vertical fold.
    var bookPose = false

    var body: some View {
        VStack(spacing: 8) {
            PromptArt(prompt: prompt, reduceMotion: reduceMotion)
                .rotationEffect(.degrees(bookPose && !isDrag ? -90 : 0))
                .frame(width: compact ? 64 : 80, height: compact ? 64 : 80)
            Text(prompt.text)
                .font(GlintType.headline(compact))
                .foregroundStyle(GlintTheme.cream)
                .multilineTextAlignment(.center)
            if let starLine {
                Text(starLine)
                    .font(GlintType.caption(compact))
                    .foregroundStyle(GlintTheme.goldLight)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(CardBackground(radius: 24))
        .accessibilityElement(children: .combine)
    }

    private var isDrag: Bool {
        if case .drag = prompt { return true }
        return false
    }
}

/// A tiny drawing for the start line: the phone shutting (close), half open with the sun (open), or a finger sliding
/// the way the light grows (drag; R3: it animates, unless Reduce motion).
struct PromptArt: View {
    let prompt: PromptLine
    var reduceMotion = false
    @State private var slide = false

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
                        .rotationEffect(.degrees(slide ? -6 : -32), anchor: .leading)
                    Image(systemName: "arrow.down")
                        .font(.system(size: s * 0.24, weight: .black))
                        .foregroundStyle(GlintTheme.goldLight)
                        .offset(x: s * 0.2, y: -s * 0.26)
                case .openToLight:
                    MenuSunArt(rays: 8)
                        .frame(width: s * 0.6, height: s * 0.6)
                        .offset(y: slide ? -s * 0.2 : -s * 0.08)
                    RoundedRectangle(cornerRadius: s * 0.1, style: .continuous)
                        .fill(GlintTheme.brassFace)
                        .frame(width: s * 0.7, height: s * 0.16)
                        .offset(y: s * 0.22)
                case let .drag(direction):
                    let travel = s * 0.22
                    let v = PromptArt.unit(direction)
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: s * 0.46, weight: .bold))
                        .foregroundStyle(GlintTheme.goldLight)
                        .offset(x: v.dx * (slide ? travel : -travel), y: v.dy * (slide ? travel : -travel))
                }
            }
            .frame(width: s, height: s)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { slide = true }
        }
    }

    /// The finger's direction for the drag word.
    static func unit(_ direction: String) -> CGVector {
        switch direction {
        case "up": return CGVector(dx: 0, dy: -1)
        case "left": return CGVector(dx: -1, dy: 0)
        case "right": return CGVector(dx: 1, dy: 0)
        default: return CGVector(dx: 0, dy: 1)
        }
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
            MenuMirrorArt(sun: 0.4).frame(width: 90, height: 64)
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
