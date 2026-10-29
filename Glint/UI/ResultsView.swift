import SwiftUI

/// Results: the sunrise (or the night), stars that land one by one, the five flowers (eaten ones greyed), the score
/// rolling up, the best ("New best!" on a first clear too), a lost level's one tip, anything this run opened or
/// earned (achievements: their Game Center banners are held until this card), then the buttons. R2: won = Next
/// sunrise + Retry with Levels / Home as small links; on a Duo the card sits on the mirror half and the buttons on the
/// garden half, clear of the crease. The finished garden stays behind the glass.
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
            SplitMenu(canvas: canvas, maxWidth: 480) {
                card(compact: c)
            } bottom: {
                buttons(compact: c)
            }
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
            // R3 (REVIEW-2 fix 14): the player's own garden at the end (its real flowers), not clip art.
            ResultGardenArt(flowers: summary.flowers, won: summary.won, night: summary.mode == .endless)
                .frame(width: compact ? 220 : 260, height: compact ? 104 : 124)

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

            if summary.outcome.isNewBest && summary.score > 0 {
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

            if !summary.flowers.isEmpty {
                HStack(spacing: compact ? 6 : 10) {
                    ForEach(0..<summary.flowers.count, id: \.self) { i in
                        MenuFlowerArt(petal: GlintTheme.petals[i % GlintTheme.petals.count])
                            .frame(width: compact ? 24 : 30, height: compact ? 24 : 30)
                            .saturation(summary.flowers[i] ? 1 : 0)
                            .opacity(summary.flowers[i] ? 1 : 0.3)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(detailLine)
            }

            Text(detailLine)
                .font(GlintType.caption(compact))
                .foregroundStyle(GlintTheme.haze)
                .multilineTextAlignment(.center)

            if let tip = summary.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(GlintTheme.gold)
                    Text(tip)
                        .foregroundStyle(GlintTheme.cream)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(GlintType.body(compact))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GlintTheme.cardDeep.opacity(0.9)))
            }

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
                ForEach(0..<summary.newAchievements.count, id: \.self) { i in
                    HStack(spacing: 8) {
                        AchievementBadge(key: BadgeBook.key(of: summary.newAchievements[i]), side: 30)
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                        Text(AchievementNames.title(summary.newAchievements[i]))
                    }
                    .font(GlintType.body(compact))
                    .foregroundStyle(GlintTheme.cream)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GlintTheme.cardDeep.opacity(0.95)))
                    .overlay(Capsule().strokeBorder(GlintTheme.brassLight.opacity(0.6), lineWidth: 1))
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(compact ? 20 : 26)
        .frame(maxWidth: .infinity)
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
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 52, compact: compact))
                    Button("Home") { controller.goHome() }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 52, compact: compact))
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
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 52, compact: compact))
                    Button("Home") { controller.goHome() }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 52, compact: compact))
                }
            }
        }
        .frame(maxWidth: 480)
    }

    private func animateIn() {
        let stars = summary.stars
        let score = summary.score
        let reduce = controller.reduceMotion
        let unlocked = !summary.outcome.unlocked.isEmpty || !summary.newAchievements.isEmpty
        if controller.demo != nil {
            shownScore = score
            shownStars = stars
            showRest = true
            return
        }
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

/// The Results hero (R3): a small picture of the player's own garden as it ended. Sunrise (or the night, or Long
/// Night's moon) over the grass, and the five flowers as they were: standing ones in bloom, eaten ones a bare stalk.
struct ResultGardenArt: View {
    let flowers: [Bool]
    let won: Bool
    let night: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lanes = max(flowers.count, 5)
            ZStack {
                LinearGradient(colors: won && !night ? [GlintTheme.plum, GlintTheme.rose, GlintTheme.peach, GlintTheme.goldLight]
                                                     : [GlintTheme.night, GlintTheme.indigo, GlintTheme.dusk],
                               startPoint: .top, endPoint: .bottom)
                if night || !won {
                    MenuMoonArt()
                        .frame(width: h * 0.5, height: h * 0.5)
                        .position(x: w * 0.78, y: h * 0.28)
                } else {
                    MenuSunArt(rays: 12)
                        .frame(width: h * 0.85, height: h * 0.85)
                        .position(x: w * 0.5, y: h * 0.5)
                }
                Rectangle()
                    .fill(LinearGradient(colors: [GlintTheme.grass, GlintTheme.teal], startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.38)
                    .position(x: w * 0.5, y: h * 0.81)
                ForEach(0..<lanes, id: \.self) { i in
                    let x = w * (CGFloat(i) + 0.5) / CGFloat(lanes)
                    let standing = i < flowers.count ? flowers[i] : true
                    Capsule()
                        .fill(GlintTheme.leaf.opacity(standing ? 1 : 0.5))
                        .frame(width: max(w * 0.012, 2), height: h * 0.2)
                        .position(x: x, y: h * 0.8)
                    if standing {
                        MenuFlowerArt(petal: GlintTheme.petals[i % GlintTheme.petals.count])
                            .frame(width: h * 0.24, height: h * 0.24)
                            .position(x: x, y: h * 0.68)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: min(w, h) * 0.18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: min(w, h) * 0.18, style: .continuous)
                .strokeBorder(GlintTheme.brassFace, lineWidth: 3))
        }
        .accessibilityHidden(true)
    }
}
