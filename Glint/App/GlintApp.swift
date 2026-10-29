import SwiftUI

@main
struct GlintApp: App {
    /// R5: phones portrait only (`OrientationRules`).
    @UIApplicationDelegateAdaptor(GlintAppDelegate.self) private var appDelegate
    @StateObject private var store: ProgressStore
    @StateObject private var settings: SettingsStore
    @StateObject private var controller: GameController

    init() {
        let demo = DemoMode.current
        // Demo runs never touch the player's saved progress or settings.
        let store: ProgressStore
        if let demo {
            var seeded = DemoPresets.progress(demo.progress, now: Date())
            DemoPresets.applyStreak(demo.streakDays, to: &seeded, now: Date())
            store = ProgressStore(inMemory: seeded)
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
