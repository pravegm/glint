import Foundation
import QuartzCore

/// The mirror on the iPhone Duo (GAME-DESIGN §3): hinge samples in (from `HingeReader`), `MirrorInput` out at display
/// rate. The phone's angle IS the light: shut = dark, opening pools light in the crease, then lifts the band out across
/// the garden, continuously, both ways.
///
/// Pipeline (the pattern of Hush's `HingeLidSource`): the raw reports (25–30 Hz while moving, none while still, about
/// ±5° accurate) feed a `HingePredictor` (alpha-beta, predicts between reports), sampled every frame and smoothed by a
/// One-Euro filter (minCutoff 2.0, β 0.12). Continuous between reports, so the band never steps. The filtered angle maps
/// through Core's `Tuning.band(angle:)` and `Tuning.creaseGlow(angle:)`. `bandSpeed` is the filtered band's change over
/// the last 0.1 s of frames (`FeelVelocityWindow`): feedback only.
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

    private var predictor = HingePredictor()
    private var smoother = OneEuroSmoother(minCutoff: 2.0, beta: 0.12, dCutoff: 1.5)
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
        predictor.sample(raw, at: stamp)
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
        predictor.reset()
        smoother.reset()
        velocity.reset()
        lastQuery = nil
        lastMirror = MirrorInput(band: lastMirror.band, creaseGlow: lastMirror.creaseGlow, isShut: lastMirror.isShut,
                                 bandSpeed: 0)
        if let raw = lastRawAngle, let stamp = lastSampleTime {
            predictor.sample(raw, at: stamp)
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
