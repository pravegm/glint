import SwiftUI

/// The Duo's outer (cover) display: the app keeps running there when the phone is shut. The brass mirror with the
/// sun behind its glass, the title and one line:
/// - "Open the phone to play", plus Today's Dawn ("Today's Dawn is up" / "Today: 2,140 · streak 3") in the menus;
/// - "Open the phone" at a level start;
/// - "Paused · open the phone to carry on", with the score and the flowers left.
/// After 3 s it offers "Already open? Show the game" in case the window was misread (never stuck).
struct CoverView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var hud: HUDModel
    @ObservedObject var store: ProgressStore
    let size: CGSize

    @State private var offerEscape = false

    var body: some View {
        let line = AppRules.coverLine(route: controller.route, stage: controller.stage,
                                      phase: controller.route == .play && controller.stage == .live ? hud.state.phase : nil,
                                      paused: controller.pause.isPaused, score: hud.state.score)
        let s = min(size.width, size.height)
        let today = DailySeed.day(for: Date())
        let data = store.data
        let daily = AppRules.dailyCoverLine(open: ProgressRules.dailyUnlocked(data),
                                            playedToday: ProgressRules.playedDaily(data, day: today),
                                            todayBest: ProgressRules.dailyBest(data, day: today),
                                            streak: ProgressRules.dailyStreak(data, today: today))
        ZStack {
            LinearGradient(colors: [GlintTheme.night, GlintTheme.indigo, GlintTheme.dusk], startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: max(s * 0.035, 8)) {
                MenuMirrorArt(sun: 0.55)
                    .frame(width: s * 0.36, height: s * 0.25)
                Wordmark(size: max(min(s * 0.14, 52), 26))
                Text(line.text)
                    .font(.system(size: max(min(s * 0.065, 24), 15), weight: .heavy, design: .rounded))
                    .foregroundStyle(GlintTheme.cream)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                if let score = Self.pausedScore(line) {
                    HStack(spacing: 14) {
                        Text("Score \(AppRules.grouped(score))")
                        HStack(spacing: 3) {
                            ForEach(0..<max(hud.state.flowersLeft, 0), id: \.self) { i in
                                MenuFlowerArt(petal: GlintTheme.petals[i % GlintTheme.petals.count])
                                    .frame(width: max(s * 0.05, 12), height: max(s * 0.05, 12))
                            }
                        }
                        .accessibilityLabel("\(hud.state.flowersLeft) flowers left")
                    }
                    .font(GlintType.number(max(min(s * 0.06, 24), 15)))
                    .foregroundStyle(GlintTheme.goldLight)
                } else if controller.route != .play, let daily {
                    Text(daily)
                        .font(.system(size: max(min(s * 0.05, 19), 13), weight: .bold, design: .rounded))
                        .foregroundStyle(GlintTheme.goldLight)
                        .multilineTextAlignment(.center)
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
