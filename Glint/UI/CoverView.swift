import SwiftUI

/// The Duo's outer (cover) display: the app keeps running there when the phone is shut. Title, a small rising sun,
/// one line ("Open the phone to play" / "Open the phone" / "Paused · open the phone to carry on" with the score).
/// After 3 s it offers "Already open? Show the game" in case the window was misread (never stuck).
struct CoverView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDModel
    let size: CGSize

    @State private var offerEscape = false

    var body: some View {
        let line = AppRules.coverLine(route: controller.route, stage: controller.stage,
                                      phase: controller.route == .play && controller.stage == .live ? hud.state.phase : nil,
                                      paused: controller.pause.isPaused, score: hud.state.score)
        let s = min(size.width, size.height)
        ZStack {
            LinearGradient(colors: [GlintTheme.night, GlintTheme.indigo, GlintTheme.dusk], startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: max(s * 0.04, 8)) {
                MenuSunArt(rays: 10)
                    .frame(width: s * 0.3, height: s * 0.3)
                Wordmark(size: max(min(s * 0.16, 56), 28))
                Text(line.text)
                    .font(.system(size: max(min(s * 0.065, 24), 15), weight: .heavy, design: .rounded))
                    .foregroundStyle(GlintTheme.cream)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                if let score = Self.pausedScore(line) {
                    Text("Score \(AppRules.grouped(score))")
                        .font(GlintType.number(max(min(s * 0.07, 26), 16)))
                        .foregroundStyle(GlintTheme.goldLight)
                }
                if offerEscape && !controller.forcedCover {
                    Button("Already open? Show the game") {
                        controller.coverDismissed = true
                    }
                    .font(GlintType.caption(true))
                    .foregroundStyle(GlintTheme.haze)
                    .frame(minHeight: 44)
                }
            }
            .padding(16)
        }
        .frame(width: size.width, height: size.height)
        .task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            offerEscape = true
        }
    }

    static func pausedScore(_ line: CoverLine) -> Int? {
        if case let .paused(score) = line { return score }
        return nil
    }
}
