import Foundation
import QuartzCore

/// The mirror on the iPhone Duo (GAME-DESIGN §3): hinge samples in (from `HingeReader`), `MirrorInput` out at display
/// rate. The phone's angle IS the light: shut = dark, opening pools light in the crease, then lifts the band out across
/// the garden, continuously, both ways.
///
/// Pipeline (the pattern of Hush's `HingeLidSource`): the raw reports (25–30 Hz while moving, none while still, about
/// ±5° accurate) feed a `HingePredictor` (alpha-beta, predicts between reports), sampled every frame and smoothed by a
/// One-Euro filter. Continuous between reports, so the band never steps. The filtered angle maps through Core's
/// `Tuning.band(angle:)` and `Tuning.creaseGlow(angle:)`. `bandSpeed` is the filtered band's change over the last 0.1 s
/// of frames (`FeelVelocityWindow`): feedback only.
///
/// R2 (hinge precision; with 55° of travel 1° ≈ 0.018 d and the band's full-light core is ±0.05 d): every report first
/// goes through a **steady filter** (`steadyFilter`: a One-Euro at 0.2 Hz with a 25°/s speed floor and a residual boost
/// past 2°), so a still hand's report noise never reaches the predictor (whose velocity estimate amplified it: R1 showed
/// 0.037 d of jitter for ±1.5° noise; R2 0.005 d). The predictor rests on the *raw* last report, and the display
/// One-Euro is lighter (6 Hz, β 0.5). Node port numbers (design/notes/feel-R2.md): ±1.5° still hand → band jitter
/// ≤ 0.0056 d over 8 seeds; a 60°/s move lags 12 ms in steady motion (R1 9 ms); overshoot at a human stop 2.4° (R1 3.2°).
///
/// - `isShut`: the filtered angle at or under `Tuning.shutAngle` (15°) held for `Tuning.shutDwell` (0.25 s), released
///   above 18° (`FeelShutGate`). It matures on the clock even when no frame or report arrives.
/// - `canResume`: the filtered angle at or above `Tuning.resumeAngle` (25°). The App adds the 0.6 s grace.
/// - Before any report: the band hidden in the crease and NOT shut (an unknown angle must never count as the close that
///   starts a level; Hush R14).
///
/// Never use the hinge's `status` (it reads `.closed` at ~85° on hardware); everything here is the angle.
@MainActor
final class HingeMirrorSource: MirrorSource {
    /// The band's speed is measured over this many seconds of frames.
    nonisolated static let speedWindow: Double = 0.1
    /// When no frame has asked for this long (s), a report updates `angle` and the shut gate itself (pause card,
    /// cover display, menus); frames take over at once when they resume.
    nonisolated static let framesLiveWindow: Double = 0.1

    /// R2: the per-report steady filter (see the type comment).
    nonisolated static func steadyFilter() -> OneEuroSmoother {
        OneEuroSmoother(minCutoff: 0.2, beta: 0.15, dCutoff: 3.0, speedFloor: 25, residualStart: 2.0, residualGain: 10)
    }

    /// R2: the display-rate smoother after the predictor (R1: 2.0 / 0.12 / 1.5).
    nonisolated static func displaySmoother() -> OneEuroSmoother {
        OneEuroSmoother(minCutoff: 6.0, beta: 0.5, dCutoff: 2.0)
    }

    private var steady = OneEuroSmoother(minCutoff: 0.2, beta: 0.15, dCutoff: 3.0, speedFloor: 25, residualStart: 2.0,
                                         residualGain: 10) // = `steadyFilter()`
    private var predictor = HingePredictor()
    private var smoother = OneEuroSmoother(minCutoff: 6.0, beta: 0.5, dCutoff: 2.0) // = `displaySmoother()`
    private var gate = FeelShutGate()
    private var velocity = FeelVelocityWindow(window: 0.1) // = `speedWindow` (a literal: a plain default value)
    private var trace = FeelHingeTrace()

    /// True once any real hinge sample has arrived (never goes back to false).
    private(set) var hasHinge = false
    /// The filtered hinge angle (degrees, 180 = flat); nil before any sample.
    private(set) var angle: Double?
    /// The last raw reading and when it arrived (diagnostics).
    private(set) var lastRawAngle: Double?
    private(set) var lastSampleTime: TimeInterval?
    /// The value returned by the last `mirror(at:)`.
    private(set) var lastMirror = MirrorInput(band: Tuning.bandMin, creaseGlow: 0, isShut: false, bandSpeed: 0)
    /// How many reports have arrived (diagnostics).
    private(set) var reportCount = 0

    /// The clock `isShut` judges its dwell against (the hinge samples' clock). Tests set their own.
    var clock: () -> TimeInterval = { CACurrentMediaTime() }

    private var lastQuery: TimeInterval?

    init() {}

    /// The latest time anything has told us about: the clock, the last frame, the last report.
    private var now: TimeInterval {
        max(clock(), lastQuery ?? -Double.infinity, lastSampleTime ?? -Double.infinity)
    }

    /// The phone is shut: the filtered angle at or under 15° for 0.25 s (released above 18°). False before any report.
    var isShut: Bool {
        shut(at: now)
    }

    /// `isShut` judged at `time`.
    func shut(at time: TimeInterval) -> Bool {
        hasHinge && gate.isShut(at: time)
    }

    /// A paused level may resume: the filtered angle (or, before any frame, the last report) is at or above
    /// `Tuning.resumeAngle` (25°). False before any report. Works with or without frames, so poll it while paused.
    var canResume: Bool {
        guard hasHinge else { return false }
        guard let current = angle ?? lastRawAngle, current.isFinite else { return false }
        return current >= Tuning.resumeAngle
    }

    /// One hinge report: degrees (180 = flat), stamped on receipt with `CACurrentMediaTime()`.
    func ingest(angleDegrees: Double, at time: TimeInterval) {
        guard angleDegrees.isFinite, time.isFinite else { return }
        let raw = FeelMath.clamp(angleDegrees, 0, 180)
        // Never let a sample go back in time (it would make the filters' dt negative).
        let stamp = max(time, lastSampleTime ?? time)
        trace.record(angle: angleDegrees, at: stamp)
        hasHinge = true
        reportCount += 1
        lastRawAngle = raw
        lastSampleTime = stamp
        let steadied = steady.filter(raw, at: stamp)
        predictor.sample(steadied, at: stamp, rest: raw)
        // Keep `angle` (and the shut gate) fresh while no frame asks: the pause card, the cover display, menus.
        let framesLive = stamp - (lastQuery ?? -Double.infinity) <= Self.framesLiveWindow
        if angle == nil || !framesLive {
            let tracked = predictor.estimate ?? raw
            angle = tracked
            gate.update(angle: tracked, at: stamp)
        }
    }

    /// The light for the frame at `time` (`CACurrentMediaTime()` clock). Asked twice for the same frame (or an older
    /// one): the same answer, and the filters don't advance.
    func mirror(at time: TimeInterval) -> MirrorInput {
        guard hasHinge, time.isFinite else {
            return MirrorInput(band: Tuning.bandMin, creaseGlow: 0, isShut: false, bandSpeed: 0)
        }
        if let previous = lastQuery, time <= previous { return lastMirror }
        lastQuery = time
        let predicted = predictor.angle(at: time)
        let smoothed = smoother.filter(predicted, at: time)
        angle = smoothed
        gate.update(angle: smoothed, at: time)
        let shutNow = gate.isShut(at: time)
        let band = Self.band(angle: smoothed)
        let speed = velocity.add(band, at: time)
        let input = MirrorInput(band: band, creaseGlow: Self.glow(angle: smoothed), isShut: shutNow,
                                bandSpeed: speed)
        lastMirror = input
        return input
    }

    /// Forget the motion history (keeps `hasHinge`, the last reading and the shut latch). Call it when a paused level
    /// resumes and when the app becomes active, so a stale glide can't leak into the first frames.
    func reset() {
        steady.reset()
        predictor.reset()
        smoother.reset()
        velocity.reset()
        lastQuery = nil
        lastMirror = MirrorInput(band: lastMirror.band, creaseGlow: lastMirror.creaseGlow, isShut: lastMirror.isShut,
                                 bandSpeed: 0)
        if let raw = lastRawAngle, let stamp = lastSampleTime {
            let seeded = steady.filter(raw, at: stamp)
            predictor.sample(seeded, at: stamp, rest: raw)
        }
    }

    /// The last 10 s of raw hinge reports as a compact text block (diagnostics): a summary (count, rate, gaps, step
    /// sizes), then `ms:angle` pairs from the oldest kept report.
    func traceText() -> String {
        trace.text(now: hasHinge ? now : nil)
    }

    /// The band centre for a filtered angle (Core's mapping, clamped `Tuning.bandMin…1`). NaN → hidden.
    nonisolated static func band(angle: Double) -> Double {
        guard angle.isFinite else { return Tuning.bandMin }
        return FeelMath.clamp(Tuning.band(angle: angle), Tuning.bandMin, 1)
    }

    /// The crease glow for a filtered angle (Core's mapping, 0…1). NaN → 0.
    nonisolated static func glow(angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        return FeelMath.clamp01(Tuning.creaseGlow(angle: angle))
    }
}
