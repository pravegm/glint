import Foundation

// MARK: - Store-frame stages (DEBUG demo key `stage=<name>`)
//
// A stage is a REAL session (Core's `DawnSession(mode:spec:seed:)` with a custom `LevelSpec`) whose spawns are timed to
// surface just before the freeze, with the band moved along a scripted path (not the pilot), frozen while its FX are
// live. The real Scene draws it: nothing is faked. `stageOverridesHinge`: on a Duo the scripted band overrides the
// hinge, for store frames only (the key exists only in DEBUG builds). Every stage prints `GLINT-T freeze stage-<name>`
// and a `GLINT-T band <b> …` line at its freeze (the Duo book frame's drawn angle follows the band).

enum DemoStageName: String, CaseIterable, Equatable, Sendable {
    case hero, sweep, brute, fireflies, rooftops, harbour, longnight, daily
}

/// What a stage waits for before it freezes (after `freezeFrom`, at the latest at `freezeBy`).
enum StageWant: Equatable, Sendable {
    /// At least n pops so far, the latest within `DemoStages.popFX` s (bursts on screen).
    case pops(Int)
    /// A gloom of this kind surfaced and lit (≥ 0.5).
    case lit(GloomKind)
    /// A firefly out of the crease shade within reach of the band.
    case firefly
    /// An event (freezes `delay` s after it): `.sweep` 0.12 s, `.split` 0.35 s, `.eaten` 0.3 s, `.wave` 0.6 s.
    case event(DemoMode.Stop, Double)
}

/// One point of the band's scripted path: session time → band (d).
struct StageKey: Equatable, Sendable {
    var t: Double
    var band: Double
}

struct DemoStagePlan: Equatable, Sendable {
    var name: DemoStageName
    var mode: PlayMode
    /// nil = the mode's own script (Long Night).
    var spec: LevelSpec?
    var path: [StageKey]
    /// Long Night is played by the pilot (its waves are Core's own), with a lag so the field fills.
    var usesPilot: Bool
    var pilotSkill: Double
    var pilotLag: Double
    var freezeFrom: Double
    var freezeBy: Double
    var want: StageWant
}

enum DemoStages {
    /// A pop's burst counts as on screen this long after it (session s).
    static let popFX = 0.25
    /// The headless fast-forward stops this long before `freezeFrom`, so the last stretch plays live (FX in motion).
    static let liveTail = 0.6

    /// The band at session time `t` on `path` (linear between keys, held before the first and after the last).
    /// Pure; tested.
    static func band(at t: Double, path: [StageKey]) -> Double {
        guard let first = path.first else { return 0 }
        if t <= first.t { return first.band }
        for i in 1..<max(path.count, 1) where i < path.count {
            let a = path[i - 1]
            let b = path[i]
            if t <= b.t {
                let span = max(b.t - a.t, 1e-9)
                return a.band + (b.band - a.band) * (t - a.t) / span
            }
        }
        return path[path.count - 1].band
    }

    private static func group(_ t: Double, _ kind: SpawnKind, _ n: Int, _ u: ClosedRange<Double>, _ f: Formation,
                              _ speed: Double, _ surface: ClosedRange<Double>) -> SpawnGroup {
        SpawnGroup(time: t, kind: kind, count: n, u: u, formation: f, speedScale: speed, surface: surface)
    }

    private static func spec(_ n: Int, _ title: String, _ duration: Double, _ groups: [SpawnGroup],
                             clouds: [CloudSpec] = []) -> LevelSpec {
        LevelSpec(number: n, world: LevelBook.world(of: n), title: title, duration: duration,
                  groups: groups.sorted { $0.time < $1.time }, clouds: clouds)
    }

    // Timings: a submerged gloom travels at its speed × speedScale × 1.6 (`Tuning.submergedSpeedFactor`) from
    // d = −radius to its surface depth; surfaced, at speed × speedScale. Murk 0.10, wisp 0.21, brute 0.065,
    // splitter 0.09 (GloomSpec).

    static func plan(_ name: DemoStageName, today: Int) -> DemoStagePlan {
        switch name {
        case .hero:
            // Meadow at golden dawn (sun 0.6 at the freeze), a loose arc of murks and wisps, the band on them.
            let s = spec(3, "First Light", 10, [
                group(0.3, .gloom(.murk), 4, 0.2...0.8, .line, 0.8, 0.44...0.48),
                group(2.0, .gloom(.murk), 2, 0.3...0.7, .line, 0.8, 0.30...0.34),
                group(2.2, .gloom(.wisp), 2, 0.4...0.6, .line, 0.6, 0.46...0.46),
                group(0.5, .firefly, 1, 0.45...0.55, .cluster, 1.0, 0...0),
            ])
            return DemoStagePlan(name: name, mode: .level(3), spec: s,
                                 path: [StageKey(t: 0, band: 0.2), StageKey(t: 4.2, band: 0.2),
                                        StageKey(t: 4.6, band: 0.47), StageKey(t: 9, band: 0.47)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 5.0, freezeBy: 7.0,
                                 want: .pops(2))
        case .sweep:
            // A flock of six wisps surfacing in a line at d 0.5; the band sweeps through them.
            let s = spec(3, "Ladder of Wisps", 12, [
                group(0.5, .gloom(.wisp), 6, 0.15...0.85, .line, 0.6, 0.5...0.5),
                group(1.5, .gloom(.murk), 2, 0.25...0.75, .line, 0.8, 0.30...0.35),
            ])
            return DemoStagePlan(name: name, mode: .level(3), spec: s,
                                 path: [StageKey(t: 0, band: 0.2), StageKey(t: 3.3, band: 0.2),
                                        StageKey(t: 3.9, band: 0.72), StageKey(t: 9, band: 0.72)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 3.0, freezeBy: 6.0,
                                 want: .event(.sweep, 0.12))
        case .brute:
            // A brute surfacing at d 0.5, tracked by the band (lit and steaming), murks around, one still underground.
            let s = spec(6, "Clover", 20, [
                group(0.3, .gloom(.brute), 1, 0.48...0.52, .cluster, 1.0, 0.48...0.50),
                group(3.0, .gloom(.murk), 2, 0.2...0.8, .line, 0.6, 0.35...0.40),
                group(6.5, .gloom(.murk), 1, 0.3...0.35, .cluster, 0.6, 0.55...0.55),
            ])
            return DemoStagePlan(name: name, mode: .level(6), spec: s,
                                 path: [StageKey(t: 0, band: 0.2), StageKey(t: 5.8, band: 0.2),
                                        StageKey(t: 6.1, band: 0.51), StageKey(t: 8.5, band: 0.66),
                                        StageKey(t: 12, band: 0.8)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 7.5, freezeBy: 9.5,
                                 want: .lit(.brute))
        case .fireflies:
            // Two fireflies drifting out (one just past the band), three murks surfacing beyond them.
            let s = spec(4, "Fireflies", 20, [
                group(0.5, .firefly, 2, 0.35...0.65, .stagger(1.5), 1.0, 0...0),
                group(1.0, .gloom(.murk), 3, 0.2...0.8, .line, 0.8, 0.55...0.60),
            ])
            return DemoStagePlan(name: name, mode: .level(4), spec: s,
                                 path: [StageKey(t: 0, band: 0.2), StageKey(t: 5.5, band: 0.2),
                                        StageKey(t: 5.8, band: 0.58), StageKey(t: 12, band: 0.6)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 6.0, freezeBy: 8.5,
                                 want: .firefly)
        case .rooftops:
            // L14's tiles, a cloud shadow cutting the band, a splitter popping into wisps, a hopper hopping.
            let s = spec(14, "Hop Along", 20, [
                group(0.5, .gloom(.splitter), 1, 0.58...0.62, .cluster, 0.8, 0.45...0.45),
                group(1.0, .gloom(.hopper), 1, 0.28...0.32, .cluster, 1.0, 0.35...0.35),
                group(1.5, .gloom(.murk), 2, 0.15...0.85, .line, 0.8, 0.40...0.48),
            ], clouds: [CloudSpec(time: 3.0, fromLeft: true, halfWidth: 0.12, speed: 0.08, strength: 1.0)])
            return DemoStagePlan(name: name, mode: .level(14), spec: s,
                                 path: [StageKey(t: 0, band: 0.2), StageKey(t: 5.0, band: 0.2),
                                        StageKey(t: 5.3, band: 0.47), StageKey(t: 12, band: 0.52)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 5.0, freezeBy: 9.0,
                                 want: .event(.split, 0.35))
        case .harbour:
            // L27's boardwalk, a dense wave, one fast murk slipping past (it eats a flower), the band busy mid-field.
            let s = spec(27, "Harbour", 20, [
                group(0.0, .gloom(.murk), 1, 0.08...0.12, .cluster, 2.0, 0.15...0.15),
                group(0.4, .gloom(.murk), 5, 0.2...0.9, .line, 1.2, 0.35...0.55),
                group(1.2, .gloom(.wisp), 3, 0.3...0.8, .line, 0.8, 0.45...0.50),
                group(1.5, .gloom(.brute), 1, 0.55...0.6, .cluster, 1.0, 0.30...0.32),
            ])
            return DemoStagePlan(name: name, mode: .level(27), spec: s,
                                 path: [StageKey(t: 0, band: 0.08), StageKey(t: 3.6, band: 0.08),
                                        StageKey(t: 4.0, band: 0.5), StageKey(t: 12, band: 0.55)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 4.0, freezeBy: 9.0,
                                 want: .event(.eaten, 0.3))
        case .longnight:
            // Moonlit, Core's own waves; the pilot (slowed) plays until the second wave's banner.
            return DemoStagePlan(name: name, mode: .endless, spec: nil, path: [],
                                 usesPilot: true, pilotSkill: 0.75, pilotLag: 0.4, freezeFrom: 29.0, freezeBy: 36.0,
                                 want: .event(.wave, 0.6))
        case .daily:
            // Golden hour (sun 0.7 at the freeze), the date chip, a row of murks lit.
            let s = spec(1, "Today's Dawn", 12, [
                group(0.3, .gloom(.murk), 5, 0.15...0.85, .line, 0.8, 0.40...0.50),
            ])
            return DemoStagePlan(name: name, mode: .daily(day: today), spec: s,
                                 path: [StageKey(t: 0, band: 0.2), StageKey(t: 4.3, band: 0.2),
                                        StageKey(t: 4.7, band: 0.46), StageKey(t: 12, band: 0.5)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 5.2, freezeBy: 8.4,
                                 want: .pops(1))
        }
    }

    /// The stage's session.
    static func session(_ plan: DemoStagePlan, seed: UInt64) -> DawnSession {
        if let spec = plan.spec { return DawnSession(mode: plan.mode, spec: spec, seed: seed) }
        return DawnSession(mode: plan.mode, seed: seed)
    }

    /// Runs a stage headless to its freeze (tests; the app does the same, the last stretch live). Returns the freeze
    /// and what triggered it ("want", "timeout" or "ended").
    @MainActor
    static func simulate(_ plan: DemoStagePlan, seed: UInt64 = 7) -> (snapshot: DawnSnapshot, reason: String) {
        let s = session(plan, seed: seed)
        let scripted = ScriptedBandSource(path: plan.path)
        let pilot = PilotSource(skill: plan.pilotSkill, seed: seed)
        pilot.lag = plan.pilotLag
        var watch = StageWatch(plan: plan)
        let step = 1.0 / 120.0
        var clock: TimeInterval = 0
        var budget = Int((plan.freezeBy + 30) * 120)
        while budget > 0 && !s.isFinished {
            let input = plan.usesPilot ? pilot.mirror(at: clock) : scripted.mirror(at: clock)
            let events = s.step(dt: step, input: input)
            scripted.observe(s.snapshot)
            pilot.observe(s.snapshot)
            if watch.step(snapshot: s.snapshot, events: events) { return (s.snapshot, watch.reason) }
            clock += step
            budget -= 1
        }
        return (s.snapshot, "ended")
    }
}

/// Decides a stage's freeze, frame by frame (session time). Pure value type; tested.
struct StageWatch: Equatable {
    let plan: DemoStagePlan
    private(set) var pops = 0
    private(set) var lastPop: Double?
    private var pendingAt: Double?
    private(set) var reason = ""

    init(plan: DemoStagePlan) { self.plan = plan }

    /// True when the stage should freeze now.
    mutating func step(snapshot snap: DawnSnapshot, events: [GameEvent]) -> Bool {
        for e in events {
            if case .popped = e {
                pops += 1
                lastPop = snap.time
            }
        }
        if let at = pendingAt {
            if snap.time >= at {
                reason = "want"
                return true
            }
            return false
        }
        if snap.time >= plan.freezeBy {
            reason = "timeout"
            return true
        }
        guard snap.time >= plan.freezeFrom else { return false }
        switch plan.want {
        case let .pops(n):
            if pops >= n, let last = lastPop, snap.time - last <= DemoStages.popFX {
                reason = "want"
                return true
            }
        case let .lit(kind):
            if snap.glooms.contains(where: { $0.kind == kind && !$0.submerged && $0.lit >= 0.5 }) {
                reason = "want"
                return true
            }
        case .firefly:
            if DemoBusy.fireflyNearBand(snap) {
                reason = "want"
                return true
            }
        case let .event(tag, delay):
            if events.contains(where: { tag.matches($0) }) { pendingAt = snap.time + delay }
        }
        return false
    }
}

/// The band on a stage's scripted path (by session time). Starts the session at once (band 0 while waiting).
@MainActor
final class ScriptedBandSource: MirrorSource {
    let path: [StageKey]
    private var time: Double = 0
    private var waiting = true
    private var last: Double = 0

    init(path: [StageKey]) { self.path = path }

    func observe(_ snapshot: DawnSnapshot) {
        time = snapshot.time
        waiting = snapshot.phase == .waiting
    }

    func mirror(at t: TimeInterval) -> MirrorInput {
        let band = waiting ? 0 : DemoStages.band(at: time, path: path)
        let speed = (band - last) * 120
        last = band
        return MirrorInput(band: band, creaseGlow: PilotSource.glow(band), isShut: false, bandSpeed: speed)
    }
}
