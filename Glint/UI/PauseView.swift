import SwiftUI

/// The pause menu: Resume, Restart, Levels / Home. Always a way back. Phones: one centred card. R2: on a Duo the
/// title card sits on the mirror half and the buttons on the garden half, clear of the crease.
struct PauseView: View {
    @ObservedObject var controller: GameController
    let score: Int
    let canvas: AppCanvas

    var body: some View {
        let c = canvas.compact
        ZStack {
            Color(appHex: 0x140F2E).opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
            SplitMenu(canvas: canvas, maxWidth: 440) {
                titleCard(compact: c)
            } bottom: {
                buttons(compact: c)
            }
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
        // R5 (QA P2-8): VoiceOver stays on the menu (never the HUD behind it).
        .accessibilityAddTraits(.isModal)
    }

    private func titleCard(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            MenuMirrorArt(sun: controller.hud.state.sun)
                .frame(width: compact ? 110 : 140, height: compact ? 78 : 98)
            Text("Paused")
                .font(GlintType.title(compact))
                .foregroundStyle(GlintTheme.cream)
            Text(AppRules.modeTitle(controller.playMode))
                .font(GlintType.body(compact))
                .foregroundStyle(GlintTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(AppRules.grouped(score))
                .font(GlintType.hero(compact ? 40 : 52))
                .foregroundStyle(GlintTheme.goldFace)
            if controller.hingeDriven {
                // R5: only where it is true (the hinge drives the light), and the menu needs Resume.
                Text("Closing the phone pauses too.")
                    .font(GlintType.caption(compact))
                    .foregroundStyle(GlintTheme.haze)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(compact ? 20 : 26)
        .frame(maxWidth: .infinity)
        .background(CardBackground())
    }

    private func buttons(compact: Bool) -> some View {
        VStack(spacing: 12) {
            Button {
                controller.resumeTapped()
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
            .buttonStyle(GlintButtonStyle(kind: .primary, compact: compact))
            Button {
                controller.restartTapped()
            } label: {
                Label("Retry", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
            HStack(spacing: 12) {
                if controller.playMode.isLevel {
                    Button("Levels") {
                        controller.openLevels()
                    }
                    .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
                }
                Button("Home") {
                    controller.goHome()
                }
                .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
            }
            // R5 (player QA #24): sound and haptics without leaving the level.
            PauseSoundToggles(settings: controller.settings)
            .padding(.top, 4)
        }
    }
}

/// Sound and haptics on the pause card (observes the settings so the icons follow).
struct PauseSoundToggles: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        HStack(spacing: 18) {
            PauseToggle(symbol: settings.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        label: settings.soundOn ? "Sound on" : "Sound off") {
                settings.soundOn.toggle()
            }
            PauseToggle(symbol: settings.hapticsOn ? "hand.tap.fill" : "hand.raised.slash.fill",
                        label: settings.hapticsOn ? "Haptics on" : "Haptics off") {
                settings.hapticsOn.toggle()
            }
        }
    }
}

/// A small round toggle on the pause card, captioned.
struct PauseToggle: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            RoundIconButton(symbol: symbol, label: label, size: 50) {
                FeedbackDirector.shared.ui(.toggle)
                action()
            }
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GlintTheme.mist)
                .accessibilityHidden(true)
        }
    }
}
