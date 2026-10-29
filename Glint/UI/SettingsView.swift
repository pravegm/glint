import SwiftUI

/// Settings: a warm card of switches (never a plain system list), then Game Center and About.
struct SettingsView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var settings: SettingsStore
    let canvas: AppCanvas

    var body: some View {
        let c = canvas.compact
        ZStack {
            MenuScrim()
            // R2: on a Duo the title and art on the mirror half, every switch on the garden half (off the crease).
            // R3 (REVIEW-2 fix 16): the title at the top safe area, no empty band above it.
            SplitMenu(canvas: canvas, alignTop: true) {
                VStack(spacing: c ? 14 : 18) {
                    MenuHeader(title: "Settings", compact: c) {
                        controller.back()
                    }
                    MenuMirrorArt(sun: 0.6)
                        .frame(width: c ? 120 : 150, height: c ? 84 : 104)
                }
            } bottom: {
                VStack(spacing: c ? 14 : 18) {
                    VStack(spacing: 0) {
                        SettingRow(symbol: "speaker.wave.2.fill", title: "Sound", detail: "Pops, sizzle and chimes",
                                   isOn: $settings.soundOn, compact: c)
                        divider
                        SettingRow(symbol: "music.note", title: "Music", detail: "The dawn pad",
                                   isOn: $settings.musicOn, compact: c)
                        divider
                        SettingRow(symbol: "hand.tap.fill", title: "Haptics", detail: "Feel every pop",
                                   isOn: $settings.hapticsOn, compact: c)
                        if AppRules.swapAllowed(isDuo: canvas.isDuo, size: canvas.size) {
                            // Only a Duo in book pose swaps halves (REVIEW-2 fix 12; laptop pose would lay the mirror flat).
                            divider
                            SettingRow(symbol: "rectangle.split.2x1.fill", title: "Swap halves",
                                       detail: "Put the garden on the other half of the screen",
                                       isOn: $settings.swapHalves, compact: c)
                        }
                        divider
                        SettingRow(symbol: "sparkles", title: "Reduce motion",
                                   detail: "Calmer light, no shimmer. Follows iOS until you change it",
                                   isOn: $settings.reduceMotionShown, compact: c)
                    }
                    .padding(.vertical, 6)
                    .background(CardBackground())
                    HStack(spacing: 12) {
                        Button {
                            controller.openGameCenter()
                        } label: {
                            Label("Game Center", systemImage: "trophy.fill")
                        }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: c))
                        Button {
                            controller.open(.about)
                        } label: {
                            Label("About", systemImage: "info.circle.fill")
                        }
                        .buttonStyle(GlintButtonStyle(kind: .secondary, height: 58, compact: c))
                    }
                }
            }
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }

    private var divider: some View {
        Rectangle()
            .fill(GlintTheme.stroke)
            .frame(height: 1)
            .padding(.leading, 64)
    }
}

struct SettingRow: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let compact: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GlintTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(GlintTheme.goldFace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(GlintType.headline(compact))
                        .foregroundStyle(GlintTheme.cream)
                    Text(detail)
                        .font(GlintType.caption(compact))
                        .foregroundStyle(GlintTheme.haze)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(GlintTheme.gold)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: GlintTheme.minTap)
        .onChange(of: isOn) { _, _ in
            FeedbackDirector.shared.ui(.toggle)
        }
    }
}
