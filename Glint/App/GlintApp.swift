import SwiftUI

@main
struct GlintApp: App {
    @StateObject private var store: ProgressStore
    @StateObject private var settings: SettingsStore
    @StateObject private var controller: GameController

    init() {
        let demo = DemoMode.current
        // Demo runs never touch the player's saved progress or settings.
        let store: ProgressStore
        if let demo {
            store = ProgressStore(inMemory: DemoPresets.progress(demo.progress, now: Date()))
        } else {
            store = ProgressStore(defaults: .standard)
        }
        let settings = SettingsStore(defaults: demo == nil ? UserDefaults.standard : nil)
        if let demo {
            settings.swapHalves = demo.swap
            settings.muted = !demo.sound
        }
        _store = StateObject(wrappedValue: store)
        _settings = StateObject(wrappedValue: settings)
        _controller = StateObject(wrappedValue: GameController(store: store, settings: settings, demo: demo))
    }

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller, store: store, settings: settings)
        }
    }
}
