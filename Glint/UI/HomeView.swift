import SwiftUI

/// Home: the live garden behind glass (the attract session: the phone's own light on a Duo, the pilot elsewhere), the
/// gold wordmark, one big Play (straight into the next sunrise: no tutorial gate), and three illustrated cards.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let canvas: AppCanvas

    var body: some View {
        let data = store.data
        let next = ProgressRules.nextLevel(data)
        let c = canvas.compact
        ZStack {
            HomeScrim()
            ScrollView(.vertical) {
                Group {
                    if canvas.wide {
                        HStack(alignment: .center, spacing: 36) {
                            titleBlock(compact: c)
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 16) {
                                playButton(next: next, compact: c)
                                cards(data: data, compact: c)
                                bottomRow
                            }
                            .frame(maxWidth: 520)
                        }
                    } else {
                        VStack(spacing: c ? 16 : 22) {
                            titleBlock(compact: c)
                            playButton(next: next, compact: c)
                            cards(data: data, compact: c)
                            bottomRow
                        }
                        .frame(maxWidth: 560)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, canvas.insets.top + 16)
                .padding(.bottom, canvas.insets.bottom + 16)
                .padding(.leading, canvas.insets.leading)
                .padding(.trailing, canvas.insets.trailing)
                .frame(maxWidth: .infinity)
                .frame(minHeight: canvas.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }

    private func titleBlock(compact: Bool) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            Wordmark(size: compact ? 64 : 92)
            Text("Catch the sun. Pop the shadows.")
                .font(GlintType.headline(compact))
                .foregroundStyle(GlintTheme.mist)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, compact ? 4 : 12)
    }

    private func playButton(next: Int, compact: Bool) -> some View {
        Button {
            controller.playNext()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: compact ? 24 : 28, weight: .black))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Play")
                        .font(GlintType.button(compact))
                    Text("Level \(next) · \(LevelBook.level(next).title)")
                        .font(GlintType.caption(compact))
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .black))
            }
        }
        .buttonStyle(GlintButtonStyle(kind: .primary, height: compact ? 70 : 78, compact: compact))
        .accessibilityLabel("Play level \(next), \(LevelBook.level(next).title)")
    }

    private func cards(data: ProgressData, compact: Bool) -> some View {
        let now = Date()
        let today = DailySeed.day(for: now)
        let endlessOpen = ProgressRules.endlessUnlocked(data, now: now)
        let dailyOpen = ProgressRules.dailyUnlocked(data)
        let total = ProgressRules.totalStars(data)
        let todayBest = ProgressRules.dailyBest(data, day: today)
        return HStack(spacing: 12) {
            ModeCard(title: "Sunrises", status: "★ \(total) / \(ProgressRules.maxTotalStars())", locked: false,
                     compact: compact, art: AnyView(MenuSunArt())) {
                controller.openLevels()
            }
            ModeCard(title: "Long Night",
                     status: endlessOpen ? (data.endlessBest > 0 ? "Best \(AppRules.grouped(data.endlessBest))" : "Endless")
                                         : "Win level \(ProgressRules.endlessLevel)",
                     locked: !endlessOpen, compact: compact,
                     art: AnyView(LongNightArt())) {
                controller.playEndless()
            }
            ModeCard(title: "Today's Dawn",
                     status: dailyOpen ? (todayBest > 0 ? "Today \(AppRules.grouped(todayBest))" : "New today")
                                       : "Win level \(ProgressRules.dailyLevel)",
                     locked: !dailyOpen, compact: compact,
                     art: AnyView(MenuSunriseArt())) {
                controller.playDaily()
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 16) {
            RoundIconButton(symbol: "gearshape.fill", label: "Settings") {
                controller.open(.settings)
            }
            RoundIconButton(symbol: "trophy.fill", label: "Game Center") {
                controller.openGameCenter()
            }
            RoundIconButton(symbol: "info", label: "About") {
                controller.open(.about)
            }
        }
        .padding(.top, 4)
    }
}

/// Lighter glass than the other menus: the live garden shows through in the middle.
struct HomeScrim: View {
    var body: some View {
        ZStack {
            LinearGradient(stops: [
                Gradient.Stop(color: GlintTheme.night.opacity(0.86), location: 0),
                Gradient.Stop(color: GlintTheme.indigo.opacity(0.45), location: 0.45),
                Gradient.Stop(color: GlintTheme.night.opacity(0.82), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [GlintTheme.peach.opacity(0.25), Color.clear], center: UnitPoint(x: 0.5, y: 0.05),
                           startRadius: 10, endRadius: 480)
        }
        .ignoresSafeArea()
    }
}

/// The moon over a sleepy shadow.
struct LongNightArt: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                MenuMoonArt()
                    .frame(width: h * 0.62, height: h * 0.62)
                    .position(x: w * 0.36, y: h * 0.36)
                MenuGloomArt(squint: 0.55)
                    .frame(width: h * 0.56, height: h * 0.56)
                    .position(x: w * 0.64, y: h * 0.64)
            }
        }
        .accessibilityHidden(true)
    }
}

/// An illustrated mode card: art on top, title, a status line (or a lock).
struct ModeCard: View {
    let title: String
    let status: String
    let locked: Bool
    let compact: Bool
    let art: AnyView
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 6 : 8) {
                art
                    .frame(height: compact ? 62 : 84)
                    .frame(maxWidth: .infinity)
                    .saturation(locked ? 0.25 : 1)
                    .opacity(locked ? 0.55 : 1)
                    .overlay {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: compact ? 20 : 24, weight: .black))
                                .foregroundStyle(GlintTheme.cream)
                                .padding(10)
                                .background(Circle().fill(GlintTheme.cardDeep.opacity(0.85)))
                        }
                    }
                Text(title)
                    .font(GlintType.headline(compact))
                    .foregroundStyle(GlintTheme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(status)
                    .font(GlintType.caption(compact))
                    .foregroundStyle(locked ? GlintTheme.haze : GlintTheme.goldLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(compact ? 10 : 14)
            .frame(maxWidth: .infinity)
            .background(CardBackground(radius: 22))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(locked ? "\(title), locked. \(status)" : "\(title). \(status)")
    }
}
