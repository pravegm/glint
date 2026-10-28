import SwiftUI

/// The pause menu: Resume, Restart, Levels / Home. Always a way back. Centred on the whole canvas.
struct PauseView: View {
    @ObservedObject var controller: GameController
    let score: Int
    let canvas: AppCanvas

    var body: some View {
        let c = canvas.compact
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
            ScrollView(.vertical) {
                card(compact: c)
                    .frame(maxWidth: 440)
                    .padding(.horizontal, 24)
                    .padding(.top, canvas.insets.top + 20)
                    .padding(.bottom, canvas.insets.bottom + 20)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: canvas.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }

    private func card(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 16) {
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
            if controller.isDuo {
                Text("Closing the phone pauses too. Open it to carry on.")
                    .font(GlintType.caption(compact))
                    .foregroundStyle(GlintTheme.haze)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(compact ? 20 : 26)
        .background(CardBackground())
    }
}
