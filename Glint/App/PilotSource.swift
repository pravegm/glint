import Foundation

/// A `MirrorSource` over Core's `PilotBrain`: the autopilot for the attract garden behind the menus on phones, CI
/// screenshots (`-glintDemo "t=…"` / `skill=`) and headless demo runs. It plays like a person: the brain moves with the
/// hinge's speed limits, and this source eases towards it (never teleports).
///
/// The brain sees the snapshot the App hands it after each step (`observe(_:)`). While the session is still waiting
/// for the first light, the source lifts the band out of the crease by itself, so a demo never waits for ever.
@MainActor
final class PilotSource: MirrorSource {
    /// The fastest the eased band moves (d/s).
    static let maxSpeed = 2.0
    /// Where the band rises to while the session waits for the first light.
    static let wakeBand = 0.3

    let skill: Double
    private var brain: PilotBrain
    private var last: DawnSnapshot?
    private var lastTime: TimeInterval?
    private(set) var band: Double = Tuning.bandMin

    /// R3 demo `ignore=<kind>`: glooms of this kind are hidden from the brain (it never aims at them).
    var ignoring: GloomKind?

    init(skill: Double, seed: UInt64) {
        let s = skill.isFinite ? min(max(skill, 0), 1) : 0.8
        self.skill = s
        brain = PilotBrain(skill: s, seed: seed)
    }

    /// The session's latest snapshot (call after every step).
    func observe(_ snapshot: DawnSnapshot) {
        guard let kind = ignoring else {
            last = snapshot
            return
        }
        var seen = snapshot
        seen.glooms = snapshot.glooms.filter { $0.kind != kind }
        last = seen
    }

    /// Forget the clock (a jump in time, e.g. after a headless fast-forward, is not a frame step).
    func resetClock() {
        lastTime = nil
    }

    func mirror(at time: TimeInterval) -> MirrorInput {
        var dt = 1.0 / 120.0
        if let previous = lastTime, time.isFinite {
            dt = min(max(time - previous, 0), 1.0 / 30.0)
        }
        if time.isFinite { lastTime = time }
        let snapshot = last ?? DawnSnapshot(mode: .endless)
        let wanted = brain.band(for: snapshot, dt: dt)
        let before = band
        let goal: Double
        if snapshot.phase == .waiting {
            goal = Self.wakeBand
        } else {
            goal = wanted.isFinite ? min(max(wanted, Tuning.bandMin), 1) : before
        }
        band = Self.approach(before, toward: goal, maxStep: Self.maxSpeed * dt)
        let speed = dt > 0 ? (band - before) / dt : 0
        return MirrorInput(band: band, creaseGlow: Self.glow(band), isShut: false, bandSpeed: speed)
    }

    /// `current` moved towards `goal` by at most `maxStep`. Pure; tested.
    nonisolated static func approach(_ current: Double, toward goal: Double, maxStep: Double) -> Double {
        let step = max(maxStep, 0)
        if abs(goal - current) <= step { return goal }
        return goal > current ? current + step : current - step
    }

    /// The crease glow for a band position: 0 at `Tuning.bandMin`, 1 from the crease out. Pure; tested.
    nonisolated static func glow(_ band: Double) -> Double {
        let low = Tuning.bandMin
        guard low < 0, band.isFinite else { return band >= 0 ? 1 : 0 }
        return min(max((band - low) / (0 - low), 0), 1)
    }
}

/// A band held still (demo `band=`, the start-prompt frames, and the headless "lost" result: one frame at `first`, so
/// the session starts, then `band` for ever).
@MainActor
final class FixedBandSource: MirrorSource {
    var band: Double
    private var first: Double?

    init(band: Double, first: Double? = nil) {
        self.band = band.isFinite ? min(max(band, Tuning.bandMin), 1) : Tuning.bandMin
        self.first = first
    }

    func mirror(at time: TimeInterval) -> MirrorInput {
        if let f = first {
            first = nil
            return MirrorInput(band: f, creaseGlow: PilotSource.glow(f), isShut: false, bandSpeed: 0)
        }
        return MirrorInput(band: band, creaseGlow: PilotSource.glow(band), isShut: false, bandSpeed: 0)
    }
}
