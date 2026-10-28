import Combine
import Foundation

/// The player's settings (kept apart from progress). Versioned JSON, decoded tolerantly.
struct SettingsData: Codable, Equatable {
    static let currentVersion = 1

    var version: Int = SettingsData.currentVersion
    /// Everything but the dawn pad (GAME-DESIGN §9). Plays on silent (`.playback`).
    var soundOn: Bool = true
    /// The dawn pad.
    var musicOn: Bool = true
    var hapticsOn: Bool = true
    /// Settings › Swap halves: the garden on the other half (`GardenLayout.gardenAfter` false).
    var swapHalves: Bool = false
    /// R2: Settings › Reduce motion as the player chose it; nil = follow the iOS setting (the default).
    var reduceMotionChoice: Bool?

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, soundOn, musicOn, hapticsOn, swapHalves, reduceMotionChoice
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = SettingsData.currentVersion
        soundOn = (try? c.decodeIfPresent(Bool.self, forKey: .soundOn)) ?? true
        musicOn = (try? c.decodeIfPresent(Bool.self, forKey: .musicOn)) ?? true
        hapticsOn = (try? c.decodeIfPresent(Bool.self, forKey: .hapticsOn)) ?? true
        swapHalves = (try? c.decodeIfPresent(Bool.self, forKey: .swapHalves)) ?? false
        reduceMotionChoice = (try? c.decodeIfPresent(Bool.self, forKey: .reduceMotionChoice)) ?? nil
    }
}

/// Player settings for SwiftUI. Sound, music and haptics are pushed to `FeedbackDirector.shared` on every change (and
/// once at launch, `apply()`). `defaults` nil = in memory (demo runs): nothing is written.
@MainActor
final class SettingsStore: ObservableObject {
    static let key = "glint.settings"

    @Published var soundOn: Bool { didSet { changed() } }
    @Published var musicOn: Bool { didSet { changed() } }
    @Published var hapticsOn: Bool { didSet { changed() } }
    @Published var swapHalves: Bool { didSet { save() } }
    /// nil = follow iOS. Use `reduceMotion(system:)` for the effective value.
    @Published var reduceMotionChoice: Bool? { didSet { save() } }

    /// The effective Reduce motion: the player's choice, else iOS.
    func reduceMotion(system: Bool) -> Bool { AppRules.reduceMotion(choice: reduceMotionChoice, system: system) }

    /// iOS's Reduce Motion (the controller keeps it current; never saved).
    @Published var systemReduceMotion: Bool = false

    /// Settings' Reduce motion switch: shows the effective value, and flipping it records the player's choice.
    var reduceMotionShown: Bool {
        get { reduceMotion(system: systemReduceMotion) }
        set { reduceMotionChoice = newValue }
    }

    /// Demo `sound=0`: silent for this launch, never saved (pushed by the next `apply()`, which launch calls).
    var muted: Bool = false

    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        var stored = SettingsData()
        if let raw = defaults?.data(forKey: Self.key), let decoded = Self.decode(raw) {
            stored = decoded
        }
        soundOn = stored.soundOn
        musicOn = stored.musicOn
        hapticsOn = stored.hapticsOn
        swapHalves = stored.swapHalves
        reduceMotionChoice = stored.reduceMotionChoice
    }

    var snapshot: SettingsData {
        var d = SettingsData()
        d.soundOn = soundOn
        d.musicOn = musicOn
        d.hapticsOn = hapticsOn
        d.swapHalves = swapHalves
        d.reduceMotionChoice = reduceMotionChoice
        return d
    }

    nonisolated static func encode(_ data: SettingsData) -> Data? { try? JSONEncoder().encode(data) }
    nonisolated static func decode(_ raw: Data) -> SettingsData? { try? JSONDecoder().decode(SettingsData.self, from: raw) }

    /// Pushes sound, music and haptics to the feedback engines.
    func apply() {
        let feedback = FeedbackDirector.shared
        let sound = soundOn && !muted
        let music = musicOn && !muted
        if feedback.soundOn != sound { feedback.soundOn = sound }
        if feedback.musicOn != music { feedback.musicOn = music }
        if feedback.hapticsOn != hapticsOn { feedback.hapticsOn = hapticsOn }
    }

    private func changed() {
        apply()
        save()
    }

    private func save() {
        guard let defaults, let raw = Self.encode(snapshot) else { return }
        defaults.set(raw, forKey: Self.key)
    }
}
