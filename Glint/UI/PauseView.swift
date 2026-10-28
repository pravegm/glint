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
            if controller.isDuo {
                Text("Closing the phone pauses too. Open it to carry on.")
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
                Label("Restart", systemImage: "arrow.counterclockwise")
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
        }
    }
}
