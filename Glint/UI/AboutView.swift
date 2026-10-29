import SwiftUI

/// About: credits, the privacy line, the version. Holding the version for 2 s copies a diagnostics log (including the
/// hinge trace) to the clipboard; nothing leaves the phone unless the player pastes it somewhere. R2: on a Duo the art
/// and title sit on the mirror half, the text and the version on the garden half (nothing tappable on the crease).
struct AboutView: View {
    @ObservedObject var controller: GameController
    let canvas: AppCanvas

    var body: some View {
        let c = canvas.compact
        ZStack {
            MenuScrim()
            SplitMenu(canvas: canvas) {
                VStack(spacing: c ? 14 : 18) {
                    MenuHeader(title: "About", compact: c) {
                        controller.back()
                    }
                    ZStack {
                        MenuMirrorArt(sun: 0.75)
                            .frame(width: c ? 150 : 190, height: c ? 104 : 130)
                        MenuGloomArt(squint: 0.7)
                            .frame(width: c ? 54 : 66, height: c ? 54 : 66)
                            .offset(x: c ? 80 : 100, y: c ? 44 : 56)
                    }
                    .padding(.vertical, 6)
                    Wordmark(size: c ? 48 : 60)
                    Text("Catch the sun. Pop the shadows.")
                        .font(GlintType.headline(c))
                        .foregroundStyle(GlintTheme.mist)
                }
            } bottom: {
                VStack(spacing: c ? 14 : 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        // R5: "Made for iPhone" is Apple's MFi wording (store F4); phones never get a Duo line.
                        Text(AboutView.heading)
                            .font(GlintType.headline(c))
                            .foregroundStyle(GlintTheme.cream)
                        Text(AboutView.blurb(isDuo: canvas.isDuo))
                            .font(GlintType.body(c))
                            .foregroundStyle(GlintTheme.mist)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Self.credit)
                            .font(GlintType.body(c))
                            .foregroundStyle(GlintTheme.mist)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Self.copyright)
                            .font(GlintType.caption(c))
                            .foregroundStyle(GlintTheme.haze)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CardBackground())

                    HStack(spacing: 14) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(GlintTheme.ink)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(GlintTheme.goldFace))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(AppBrand.name) collects no data.")
                                .font(GlintType.headline(c))
                                .foregroundStyle(GlintTheme.cream)
                            Text("No accounts, no ads, no tracking. Game Center is optional and run by Apple.")
                                .font(GlintType.caption(c))
                                .foregroundStyle(GlintTheme.haze)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(CardBackground())

                    Text(Self.versionLine)
                        .font(GlintType.caption(c))
                        .foregroundStyle(GlintTheme.haze)
                        .padding(.horizontal, 16)
                        .frame(minHeight: GlintTheme.minTap)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 2) {
                            controller.copyDiagnostics()
                        }
                        .accessibilityHint("Hold for two seconds to copy a diagnostics log")
                }
            }
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
    }

    static let heading = "Best on iPhone Duo"

    /// R5 (player QA #10): the Duo's own words on a Duo, the drag words on every other iPhone. Pure; tested.
    static func blurb(isDuo: Bool) -> String {
        if isDuo {
            return "One half of your phone is a mirror. Open it to catch the sunrise and pop the shadows creeping out "
                + "of the crease."
        }
        return "Plays on every iPhone by dragging. The mirror catches the sunrise: drag anywhere to aim the light and "
            + "pop the shadows creeping out of the crease."
    }

    /// No personal names in the binary (founder, R2).
    static let credit = "Designed and built with Claude. Every picture and every sound is made in code."
    static let copyright = "© 2026 pravegm"

    static var versionLine: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (info["CFBundleVersion"] as? String) ?? "1"
        return "Version \(version) (\(build))"
    }
}
