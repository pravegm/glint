import SwiftUI

/// Results: the sunrise (or the night), stars that land one by one, the score rolling up, the best, anything this
/// run opened, then Next / Retry / Levels (levels) or Again / Home (Long Night, Today's Dawn). The finished garden
/// stays behind the glass.
struct ResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let canvas: AppCanvas

    @State private var shownStars = 0
    @State private var shownScore = 0
    @State private var showRest = false

    var body: some View {
        let c = canvas.compact
        ZStack {
            LinearGradient(colors: [GlintTheme.night.opacity(0.72), GlintTheme.indigo.opacity(0.5),
                                    GlintTheme.night.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView(.vertical) {
                card(compact: c)
                    .frame(maxWidth: 480)
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
        .onAppear { animateIn() }
    }

    private var isLevel: Bool { summary.mode.isLevel }

    private var headline: String {
        if summary.won { return isLevel ? "Sunrise!" : "Dawn!" }
        return isLevel ? "The night won" : "The night is over"
    }

    private func card(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            Group {
                if summary.won {
                    MenuSunriseArt()
                } else {
                    LongNightArt()
                }
            }
            .frame(width: compact ? 180 : 220, height: compact ? 96 : 118)

            Text(headline)
                .font(GlintType.wordmark(compact ? 38 : 48))
                .foregroundStyle(summary.won ? AnyShapeStyle(GlintTheme.goldFace) : AnyShapeStyle(GlintTheme.mist))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(summary.title)
                .font(GlintType.body(compact))
                .foregroundStyle(GlintTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if isLevel {
                HStack(spacing: compact ? 10 : 14) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: compact ? 40 : 50, weight: .black))
                            .foregroundStyle(i < shownStars ? GlintTheme.gold : Color.white.opacity(0.15))
                            .shadow(color: i < shownStars ? GlintTheme.gold.opacity(0.8) : Color.clear, radius: 12)
                            .scaleEffect(i < shownStars ? 1 : 0.78)
                            .rotationEffect(.degrees(i == 1 ? 0 : (i == 0 ? -8 : 8)))
                            .offset(y: i == 1 ? -8 : 0)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(summary.stars) of 3 stars")
            }

            Text(AppRules.grouped(shownScore))
                .font(GlintType.hero(compact ? 46 : 60))
                .foregroundStyle(GlintTheme.cream)
                .contentTransition(.numericText())
                .accessibilityLabel("Score \(summary.score)")

            if summary.outcome.showsNewBest {
                Text("New best!")
                    .font(GlintType.headline(compact))
                    .foregroundStyle(GlintTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GlintTheme.goldFace))
            } else if summary.outcome.best > 0 {
                Text("\(bestLabel) \(AppRules.grouped(summary.outcome.best))")
                    .font(GlintType.body(compact))
                    .foregroundStyle(GlintTheme.goldLight)
            }

            Text(detailLine)
                .font(GlintType.caption(compact))
                .foregroundStyle(GlintTheme.haze)
                .multilineTextAlignment(.center)

            if showRest {
                ForEach(0..<summary.outcome.unlocked.count, id: \.self) { i in
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                        Text(summary.outcome.unlocked[i].text)
                    }
                    .font(GlintType.body(compact))
                    .foregroundStyle(GlintTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(GlintTheme.goldFace))
                    .transition(.scale.combined(with: .opacity))
                }
            }

            buttons(compact: compact)
                .padding(.top, 6)
        }
        .padding(compact ? 20 : 26)
        .background(CardBackground())
    }

    private var bestLabel: String {
        if case .daily = summary.mode { return "Best today" }
        return "Best"
    }

    private var detailLine: String {
        let flowers = summary.flowersLeft == 1 ? "1 flower" : "\(summary.flowersLeft) flowers"
        let pops = summary.pops == 1 ? "1 shadow popped" : "\(summary.pops) shadows popped"
        return "\(flowers) saved · \(pops)"
    }

    @ViewBuilder
    private func buttons(compact: Bool) -> some View {
        VStack(spacing: 12) {
            if isLevel {
                if summary.won && summary.outcome.nextLevel != nil {
                    Button {
                        controller.nextTapped()
                    } label: {
                        Label("Next sunrise", systemImage: "sun.max.fill")
                    }
                    .buttonStyle(GlintButtonStyle(kind: .primary, compact: compact))
                    Button {
                        controller.retryTapped()
                    } label: {
                        Label("Retry", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
                } else {
                    Button {
                        controller.retryTapped()
                    } label: {
                        Label(summary.won ? "Play again" : "Try again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(GlintButtonStyle(kind: .primary, compact: compact))
                }
                HStack(spacing: 12) {
                    Button("Levels") { controller.openLevels() }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
                    Button("Home") { controller.goHome() }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
                }
            } else {
                Button {
                    controller.retryTapped()
                } label: {
                    Label("Again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(GlintButtonStyle(kind: .primary, compact: compact))
                HStack(spacing: 12) {
                    Button("Leaderboards") { controller.openGameCenter() }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
                    Button("Home") { controller.goHome() }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: compact))
                }
            }
        }
    }

    private func animateIn() {
        let stars = summary.stars
        let score = summary.score
        let reduce = controller.reduceMotion
        let unlocked = !summary.outcome.unlocked.isEmpty
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let steps = 24
            for k in 1...steps {
                shownScore = score * k / steps
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
            shownScore = score
            if stars > 0 {
                for i in 1...stars {
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    withAnimation(GlintTheme.pop(reduce)) { shownStars = i }
                    FeedbackDirector.shared.ui(.star(i))
                }
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(GlintTheme.settle(reduce)) { showRest = true }
            if unlocked { FeedbackDirector.shared.ui(.unlock) }
        }
    }
}
