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
    /// R5d: a full field: at least `surfaced` glooms out of the ground, `lit` of them in the light.
    case busy(surfaced: Int, lit: Int)
    /// R5d: a firefly within reach of the band AND at least `glooms` surfaced glooms on the field.
    case fireflyWith(glooms: Int)
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
    /// The (slowed) pilot plays until `pilotUntil`, then the scripted path takes over (Long Night).
    var usesPilot: Bool
    var pilotSkill: Double
    var pilotLag: Double
    var freezeFrom: Double
    var freezeBy: Double
    var want: StageWant
    /// With `usesPilot`: the session time the path takes over.
    var pilotUntil: Double = 0
}

enum DemoStages {
    /// A pop's burst counts as on screen this long after it (session s).
    static let popFX = 0.25
    /// The headless fast-forward stops this long before `freezeFrom`, so the last stretch plays live (FX in motion).
    static let liveTail = 0.6

    /// R5d: a path key with this band means "from here on, aim at the crowd" (the mean d of the surfaced glooms)...
    static let aim = -1.0
    /// ... once at least this many are out of the ground.
    static let aimCrowd = 4

    /// The band at session time `t` on `path` (linear between keys, held before the first and after the last;
    /// `aim` once an aim key is reached). Pure; tested.
    static func band(at t: Double, path: [StageKey]) -> Double {
        if path.contains(where: { $0.band <= aim + 0.01 && t >= $0.t }) { return aim }
        let path = path.filter { $0.band > aim + 0.01 }
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
            // R5d: the band waits beyond the fireflies (they drift out towards it, never through it), four murks
            // surface below it and walk up into the light: a firefly within 0.15 of the band, glooms around it.
            // (A firefly rises at 0.075 d/s: within 0.15 of the band at 0.74 by ~8.2 s; the murks, out at ~5.5 s at
            // d 0.28–0.38, reach the light (d > 0.62) only after ~9 s.)
            let s = spec(4, "Fireflies", 20, [
                group(0.1, .firefly, 2, 0.35...0.65, .stagger(1.2), 1.0, 0...0),
                group(2.8, .gloom(.murk), 5, 0.12...0.88, .line, 0.8, 0.28...0.38),
            ])
            return DemoStagePlan(name: name, mode: .level(4), spec: s,
                                 path: [StageKey(t: 0, band: 0.74), StageKey(t: 20, band: 0.74)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 6.5, freezeBy: 13.0,
                                 want: .fireflyWith(glooms: 3))
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
            // R5d: moonlit Long Night. Core takes no custom script for endless (`DawnSession.init` drops `spec` for
            // `.endless`), so its own waves play. Wave 1 is a sparse opener (the old 30 s frame was empty), so: the
            // pilot plays through dense wave 2 until 56 s, the light rests in the crease shade so the field fills,
            // and at wave 3's banner (60 s) it moves onto the crowd (once ≥ 4 are out), frozen as they light up.
            return DemoStagePlan(name: name, mode: .endless, spec: nil,
                                 path: [StageKey(t: 56, band: 0.08), StageKey(t: 60.05, band: 0.08),
                                        StageKey(t: 60.1, band: DemoStages.aim)],
                                 usesPilot: true, pilotSkill: 0.9, pilotLag: 0, freezeFrom: 60.15, freezeBy: 64.5,
                                 want: .busy(surfaced: 4, lit: 2), pilotUntil: 56)
        case .daily:
            // R5d: golden hour (sun ~0.7 at the freeze), the date chip, six murks surfacing across the field, the
            // band arriving on them (frozen while they're lit, before they pop).
            let s = spec(1, "Today's Dawn", 7, [
                group(0.3, .gloom(.murk), 6, 0.1...0.9, .line, 0.8, 0.36...0.48),
                group(1.6, .gloom(.wisp), 2, 0.3...0.7, .line, 0.6, 0.60...0.62),
            ])
            return DemoStagePlan(name: name, mode: .daily(day: today), spec: s,
                                 path: [StageKey(t: 0, band: 0.2), StageKey(t: 4.3, band: 0.2),
                                        StageKey(t: 4.7, band: 0.46), StageKey(t: 7, band: 0.5)],
                                 usesPilot: false, pilotSkill: 0, pilotLag: 0, freezeFrom: 4.6, freezeBy: 6.5,
                                 want: .busy(surfaced: 4, lit: 2))
        }
    }

    /// The stage's session.
    static func session(_ plan: DemoStagePlan, seed: UInt64) -> DawnSession {
        if let spec = plan.spec { return DawnSession(mode: plan.mode, spec: spec, seed: seed) }
        return DawnSession(mode: plan.mode, seed: seed)
    }

    /// The stage's light: the scripted path, or the pilot first (Long Night).
    @MainActor
    static func source(_ plan: DemoStagePlan, seed: UInt64) -> ScriptedBandSource {
        guard plan.usesPilot else { return ScriptedBandSource(path: plan.path) }
        let pilot = PilotSource(skill: plan.pilotSkill, seed: seed)
        pilot.lag = plan.pilotLag
        return ScriptedBandSource(path: plan.path, pilot: pilot, pilotUntil: plan.pilotUntil)
    }

    /// Runs a stage headless to its freeze (tests; the app does the same, the last stretch live). Returns the freeze
    /// and what triggered it ("want", "timeout" or "ended").
    @MainActor
    static func simulate(_ plan: DemoStagePlan, seed: UInt64 = 7) -> (snapshot: DawnSnapshot, reason: String) {
        let s = session(plan, seed: seed)
        let scripted = source(plan, seed: seed)
        var watch = StageWatch(plan: plan)
        let step = 1.0 / 120.0
        var clock: TimeInterval = 0
        var budget = Int((plan.freezeBy + 30) * 120)
        while budget > 0 && !s.isFinished {
            let input = scripted.mirror(at: clock)
            let events = s.step(dt: step, input: input)
            scripted.observe(s.snapshot)
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
        case let .busy(surfaced, lit):
            let out = snap.glooms.filter { !$0.submerged }
            if out.count >= surfaced && out.filter({ $0.lit > 0.1 }).count >= lit {
                reason = "want"
                return true
            }
        case let .fireflyWith(glooms):
            if DemoBusy.fireflyNearBand(snap) && snap.glooms.filter({ !$0.submerged }).count >= glooms {
                reason = "want"
                return true
            }
        }
        return false
    }
}

/// The band on a stage's scripted path (by session time). Starts the session at once (band 0 while waiting). R5d:
/// with a pilot, the pilot plays until `pilotUntil`; an `aim` key moves the band onto the crowd (the mean d of the
/// surfaced glooms) at most 1.5 d/s, once at least `aimCrowd` are out (until then it rests in the crease shade).
@MainActor
final class ScriptedBandSource: MirrorSource {
    let path: [StageKey]
    let pilot: PilotSource?
    let pilotUntil: Double
    private var time: Double = 0
    private var waiting = true
    private var last: Double = 0
    private var lastClock: TimeInterval?
    private var crowd: Double?
    private var surfaced = 0

    init(path: [StageKey], pilot: PilotSource? = nil, pilotUntil: Double = 0) {
        self.path = path
        self.pilot = pilot
        self.pilotUntil = pilotUntil
    }

    func observe(_ snapshot: DawnSnapshot) {
        time = snapshot.time
        waiting = snapshot.phase == .waiting
        pilot?.observe(snapshot)
        let out = snapshot.glooms.filter { !$0.submerged }
        surfaced = out.count
        let lit = out.filter { $0.d > Tuning.creaseShade }
        crowd = lit.isEmpty ? nil : lit.map { $0.d }.reduce(0, +) / Double(lit.count)
    }

    /// Forget the clock (after the headless fast-forward).
    func resetClock() {
        lastClock = nil
        pilot?.resetClock()
    }

    func mirror(at t: TimeInterval) -> MirrorInput {
        var dt = 1.0 / 120.0
        if let previous = lastClock, t.isFinite { dt = min(max(t - previous, 0), 1.0 / 30.0) }
        if t.isFinite { lastClock = t }
        if let pilot, waiting || time < pilotUntil {
            let input = pilot.mirror(at: t)
            last = input.band
            return input
        }
        var band: Double = waiting ? 0 : DemoStages.band(at: time, path: path)
        if band <= DemoStages.aim + 0.01 {
            let rest = 0.08
            let goal = surfaced >= DemoStages.aimCrowd
                ? min(max(crowd ?? rest, Tuning.creaseShade + 0.05), 0.95) : rest
            band = PilotSource.approach(last, toward: goal, maxStep: 1.5 * max(dt, 1.0 / 240.0))
        } else if pilot != nil {
            // The hand-over from the pilot glides too (no teleporting light).
            band = PilotSource.approach(last, toward: band, maxStep: 1.5 * max(dt, 1.0 / 240.0))
        }
        let speed = dt > 0 ? (band - last) / dt : 0
        last = band
        return MirrorInput(band: band, creaseGlow: PilotSource.glow(band), isShut: false, bandSpeed: speed)
    }
}
