import SpriteKit
import SwiftUI

/// The whole app: the SpriteKit garden underneath (full window, the layout follows the canvas: no orientation locks,
/// no pose cards), the SwiftUI screens on top, the cover view on a Duo's outer display. The hinge is read here, once,
/// for the whole app (HingeReader → GameController.hingeSample → HingeMirrorSource).
struct RootView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    @ObservedObject var settings: SettingsStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        GeometryReader { safeGeo in
            let insets = safeGeo.safeAreaInsets
            GeometryReader { geo in
                let size = geo.size
                let cover = isCover(size)
                content(size: size, insets: insets, cover: cover)
                    .frame(width: size.width, height: size.height)
                    .onAppear {
                        controller.canvasChanged(size)
                        controller.setSystemReduceMotion(systemReduceMotion)
                        controller.launch()
                        controller.coverChanged(cover)
                    }
                    .onChange(of: size) { _, newSize in
                        controller.canvasChanged(newSize)
                    }
                    .onChange(of: cover) { _, shown in
                        controller.coverChanged(shown)
                    }
            }
            .ignoresSafeArea()
        }
        .background(GlintTheme.night.ignoresSafeArea())
        .modifier(HingeReader(onUpdate: { angle, time in
            controller.hingeSample(angle: angle, time: time)
        }, onUnavailable: {
            controller.hingeUnavailable()
        }, refreshToken: controller.hingeRefresh))
        .onChange(of: scenePhase) { _, phase in
            controller.setScenePhase(phase)
        }
        .onChange(of: systemReduceMotion) { _, on in
            controller.setSystemReduceMotion(on)
        }
        .onChange(of: settings.reduceMotionChoice) { _, _ in
            controller.refreshMotion()
        }
        .onChange(of: settings.swapHalves) { _, _ in
            controller.swapChanged()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    /// The Duo's outer display (or demo `screen=cover`), unless the player said it's already open.
    private func isCover(_ size: CGSize) -> Bool {
        if controller.forcedCover { return true }
        if controller.coverDismissed { return false }
        return AppRules.isCover(window: size, hingeSeen: controller.hingeSeen)
    }

    @ViewBuilder
    private func content(size: CGSize, insets: EdgeInsets, cover: Bool) -> some View {
        let canvas = AppCanvas(size: size, insets: insets, layout: controller.layout, isDuo: controller.isDuo)
        ZStack {
            GlintTheme.night
            gameLayer(size, cover: cover)
            if !cover {
                screens(canvas)
            }
            if cover {
                CoverView(controller: controller, hud: controller.hud, store: store, size: size)
                    .transition(.opacity)
            }
            if let toast = controller.toast {
                ToastView(text: toast)
                    .frame(maxWidth: 520)
                    .position(x: size.width / 2, y: insets.top + 44)
                    .transition(.opacity)
            }
            if controller.showsIcon {
                iconLayer(size)
            }
            if controller.showsBadges {
                BadgeGallery(ids: GameCenterManager.achievementIDs, size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(GlintTheme.settle(controller.reduceMotion), value: cover)
        .animation(.easeInOut(duration: 0.25), value: controller.toast)
        .defersSystemGestures(on: controller.route == .play ? Edge.Set.all : Edge.Set())
    }

    /// The garden: always in the hierarchy (it keeps stepping on the cover display, so closing the phone is seen).
    @ViewBuilder
    private func gameLayer(_ size: CGSize, cover: Bool) -> some View {
        if let scene = controller.scene {
            // R5 (QA P2-5): 120 fps only for the level itself; 30 behind the menus; stopped under the cover view
            // (the 4 Hz ticker and the hinge samples still run the close-first gate there).
            SpriteView(scene: scene, isPaused: cover && !controller.forcedCover,
                       preferredFramesPerSecond: controller.route.showsSession ? 120 : 30)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(controller.route == .play)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func screens(_ canvas: AppCanvas) -> some View {
        ZStack {
            switch controller.route {
            case .home:
                HomeView(controller: controller, store: store, canvas: canvas)
                    .transition(.opacity)
            case .levels:
                LevelsView(controller: controller, store: store, canvas: canvas)
                    .transition(.opacity)
            case .play:
                PlayHUD(controller: controller, hud: controller.hud, canvas: canvas)
                    .transition(.opacity)
            case .results:
                if let summary = controller.summary {
                    ResultsView(controller: controller, summary: summary, canvas: canvas)
                        .transition(.opacity)
                }
            case .settings:
                SettingsView(controller: controller, settings: settings, canvas: canvas)
                    .transition(.opacity)
            case .about:
                AboutView(controller: controller, canvas: canvas)
                    .transition(.opacity)
            }
        }
        .frame(width: canvas.size.width, height: canvas.size.height)
        .animation(GlintTheme.settle(controller.reduceMotion), value: controller.route)
    }

    @ViewBuilder
    private func iconLayer(_ size: CGSize) -> some View {
        let side = min(size.width, size.height)
        ZStack {
            Color.black
            AppIconArt(side: side)
                .frame(width: side, height: side)
        }
        .frame(width: size.width, height: size.height)
    }
}
