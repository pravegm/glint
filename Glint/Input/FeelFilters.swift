import Foundation

// Smoothing building blocks for the hinge → light pipeline. Copied from Hush (`Hush/Input/FeelFilters.swift`, itself
// from Swoop, Brim and Squish, all battle-tested on a real Duo) and trimmed for Glint: no lid speedometer, no closing
// gate (Glint's shut gate is below). Pure value types with explicit times, so every one is unit-testable off-device.

/// Small pure helpers for the Input and Feedback modules.
enum FeelMath {
    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    /// 0…1, NaN → 0.
    static func clamp01(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : 0
    }

    /// Hermite smoothstep of `x` clamped to 0…1: 3x² − 2x³ (zero slope at both ends).
    static func smoothstep(_ x: Double) -> Double {
        let u = clamp01(x)
        return u * u * (3 - 2 * u)
    }

    /// A finite, non-negative value (NaN and negatives → 0, +∞ → `cap`).
    static func positive(_ value: Double, cap: Double = 1_000) -> Double {
        guard !value.isNaN else { return 0 }
        return min(max(value, 0), cap)
    }
}

/// One-Euro filter (Casiez et al., CHI 2012): heavy smoothing while the input is slow, low lag while it moves fast.
/// Squish's tuning for the Duo hinge: minCutoff 2.0, β 0.12, dCutoff 1.5; dt clamped to 1/240…0.2 s.
///
/// R2 (Glint, hinge precision): two optional terms for noisy, irregular reports, both off by default (R1 behaviour):
/// - `speedFloor`: the speed term is `β · max(|derivative| − speedFloor, 0)`, so a still hand's noise-driven derivative
///   (±1.5° at 30 Hz reads tens of °/s) doesn't open the cutoff.
/// - `residualStart` / `residualGain`: a sample more than `residualStart` away from the filtered value (beyond the
///   noise) adds `residualGain` Hz per unit of excess, so a real move is followed at once.
///   `cutoff = minCutoff + β·max(|ẋ| − speedFloor, 0) + residualGain·max(|x − x̂| − residualStart, 0)`.
struct OneEuroSmoother {
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double
    var speedFloor: Double
    var residualStart: Double
    var residualGain: Double

    private(set) var value: Double?
    /// Filtered derivative of the input (units per second).
    private(set) var derivative: Double = 0
    private var lastTime: Double?

    init(minCutoff: Double = 2.0, beta: Double = 0.12, dCutoff: Double = 1.5, speedFloor: Double = 0,
         residualStart: Double = 0, residualGain: Double = 0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
        self.speedFloor = max(speedFloor, 0)
        self.residualStart = max(residualStart, 0)
        self.residualGain = max(residualGain, 0)
    }

    mutating func reset() {
        value = nil
        derivative = 0
        lastTime = nil
    }

    mutating func filter(_ x: Double, at time: Double) -> Double {
        guard x.isFinite else { return value ?? 0 }
        guard let previous = value, let previousTime = lastTime else {
            value = x
            lastTime = time
            derivative = 0
            return x
        }
        let dt = min(max(time - previousTime, 1.0 / 240.0), 0.2)
        let rawDerivative = (x - previous) / dt
        derivative += (rawDerivative - derivative) * Self.alpha(cutoff: dCutoff, dt: dt)
        var cutoff = minCutoff + beta * max(abs(derivative) - speedFloor, 0)
        if residualGain > 0 {
            cutoff += residualGain * max(abs(x - previous) - residualStart, 0)
        }
        let filtered = previous + (x - previous) * Self.alpha(cutoff: cutoff, dt: dt)
        value = filtered
        lastTime = time
        return filtered
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let r = 2 * Double.pi * cutoff * dt
        return r / (r + 1)
    }
}

/// The hinge at display rate (Squish `HingeTracker`, via Swoop and Hush, unchanged). The Duo reports 25–30 Hz while
/// moving and nothing while still, so the light must move continuously *between* reports and never hold, then jump.
///
/// An alpha-beta tracker on the raw samples: between samples it extrapolates at the tracked velocity for about one
/// sample interval, then eases to a stop; each correction is blended in over ~40 ms; once reports stop it glides onto
/// the last raw reading. Jumps larger than `snapDegrees` snap.
struct HingePredictor {
    static let alpha = 0.75
    static let beta = 0.35
    static let maxSpeed = 900.0
    static let coast = 1.0
    static let ease = 0.3
    static let horizonMin = 0.03
    static let horizonMax = 0.2
    static let snapDegrees = 90.0
    static let restGlide = 0.05

    /// The tracked (alpha-beta) angle as of the last report.
    private(set) var estimate: Double?
    /// °/s, positive while the angle grows (opening).
    private(set) var velocity = 0.0
    private(set) var lastSampleTime = 0.0
    /// Smoothed time between samples (s).
    private(set) var interval = 1.0 / 30
    private var offset = 0.0
    private var offsetTime = 0.0
    private var lastReading = 180.0

    init() {}

    mutating func reset() {
        estimate = nil
        velocity = 0
        offset = 0
    }

    /// One report. `rest` (R2): the reading to glide onto once reports stop (default: `angle`). Glint feeds the
    /// predictor pre-smoothed reports but rests on the raw one, so a hand that stops (the Duo then sends nothing) is
    /// never left a smoothing-lag short of where the phone really is.
    mutating func sample(_ angle: Double, at time: Double, rest: Double? = nil) {
        lastReading = rest ?? angle
        guard estimate != nil else {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        let shown = self.angle(at: time)
        let dt = min(max(time - lastSampleTime, 1.0 / 240), 0.5)
        let predicted = raw(at: time)
        let tau = max(0.03, Self.ease * interval)
        let prior = velocity * exp(-max(0, (time - lastSampleTime) - 2 * horizon) / tau)
        interval += (min(dt, 0.25) - interval) * 0.3
        let surprise = angle - predicted
        if abs(surprise) > Self.snapDegrees {
            estimate = angle
            velocity = 0
            lastSampleTime = time
            offset = 0
            offsetTime = time
            return
        }
        estimate = predicted + Self.alpha * surprise
        velocity = FeelMath.clamp(prior + Self.beta / dt * surprise, -Self.maxSpeed, Self.maxSpeed)
        lastSampleTime = time
        offset = shown - raw(at: time)
        offsetTime = time
    }

    var horizon: Double { FeelMath.clamp(Self.coast * interval, Self.horizonMin, Self.horizonMax) }

    private func extrapolation(at time: Double) -> Double {
        let age = max(time - lastSampleTime, 0)
        if age <= horizon { return age }
        let tau = max(0.03, Self.ease * interval)
        return horizon + tau * (1 - exp(-(age - horizon) / tau))
    }

    private func raw(at time: Double) -> Double {
        (estimate ?? 180) + velocity * extrapolation(at: time)
    }

    /// The hinge angle to use at `time` (degrees, 0…180).
    func angle(at time: Double) -> Double {
        guard estimate != nil else { return 180 }
        let blend = exp(-max(time - offsetTime, 0) / max(0.04, 0.35 * interval))
        let moving = FeelMath.clamp(raw(at: time) + offset * blend, 0, 180)
        let rest = horizon + 3 * max(0.03, Self.ease * interval)
        let age = max(time - lastSampleTime, 0)
        guard age > rest else { return moving }
        let k = 1 - exp(-(age - rest) / Self.restGlide)
        return moving + (lastReading - moving) * k
    }

    /// Reports per second, from the smoothed interval.
    var rate: Double { 1 / max(interval, 1e-3) }
}

/// The band's speed (d/s, signed) from per-frame positions: the change over the last `window` seconds of frames
/// (ROUND-1: "bandSpeed from the filtered band over ~0.1 s"). A steady move reads exactly; a pinned band reads 0.
/// A silence longer than `restartGap` (frames stopped: a pause, the cover display) restarts it, so a resume never
/// reads as a jump. Pure, with explicit times.
struct FeelVelocityWindow {
    /// Frames kept at most (≥ 0.1 s of 120 Hz frames).
    static let capacity = 64
    /// No derivative across a gap longer than this (s).
    static let restartGap = 0.25
    /// The smallest elapsed time a change is divided by (two frames at one instant can't make a spike).
    static let minElapsed = 1.0 / 240
    /// No band moves faster than this (d/s); a sanity cap.
    static let maxSpeed = 20.0

    let window: Double
    private var times: [Double] = []
    private var values: [Double] = []
    /// The velocity as of the last `add` (d/s).
    private(set) var velocity: Double = 0

    init(window: Double = 0.1) {
        self.window = window > 0 ? window : 0.1
        times.reserveCapacity(Self.capacity + 1)
        values.reserveCapacity(Self.capacity + 1)
    }

    mutating func reset() {
        times.removeAll(keepingCapacity: true)
        values.removeAll(keepingCapacity: true)
        velocity = 0
    }

    /// One frame's value at `time`; returns the velocity. The same (or an older) time returns the last answer.
    @discardableResult
    mutating func add(_ value: Double, at time: Double) -> Double {
        guard value.isFinite, time.isFinite else { return velocity }
        if let last = times.last {
            if time <= last { return velocity }
            if time - last > Self.restartGap { reset() }
        }
        times.append(time)
        values.append(value)
        // Keep exactly one frame at or before the window's start (the base), and nothing older.
        let start = time - window
        while times.count >= 2 && times[1] <= start {
            times.removeFirst()
            values.removeFirst()
        }
        if times.count > Self.capacity {
            times.removeFirst(times.count - Self.capacity)
            values.removeFirst(values.count - Self.capacity)
        }
        guard times.count >= 2 else {
            velocity = 0
            return 0
        }
        let elapsed = max(time - times[0], Self.minElapsed)
        let raw = (value - values[0]) / elapsed
        velocity = FeelMath.clamp(raw, -Self.maxSpeed, Self.maxSpeed)
        return velocity
    }
}

/// The "phone is shut" gate (GAME-DESIGN §8): shut when the filtered angle stays at or under `Tuning.shutAngle` (15°)
/// for `Tuning.shutDwell` (0.25 s). It opens again above `shutAngle + reopenMargin` (18°), so ±1° report jitter at 15°
/// can't flicker the pause. Opening is not resuming: play resumes on `HingeMirrorSource.canResume` (θ ≥ 25°).
/// Pure, with explicit times; `isShut(at:)` lets the dwell mature with time alone (the Duo sends nothing while still).
/// Adapted from Hush's `FeelClosingGate`.
struct FeelShutGate {
    static var shutAngle: Double { Tuning.shutAngle }
    static var dwell: Double { Tuning.shutDwell }
    /// Degrees above `shutAngle` the angle must rise to unlatch (three times the hinge's ±1° report jitter).
    static let reopenMargin = 3.0
    static var reopenAbove: Double { shutAngle + reopenMargin }

    /// Latched shut (until above `reopenAbove`).
    private(set) var latched = false
    /// When the angle went to or under `shutAngle` (the dwell running), if it has.
    private(set) var belowSince: Double?

    init() {}

    /// Shut at `time`: latched, or at or under the shut angle for the whole dwell.
    func isShut(at time: Double) -> Bool {
        if latched { return true }
        guard let since = belowSince, time.isFinite else { return false }
        return time - since >= Self.dwell
    }

    /// Feed an angle at `time`.
    mutating func update(angle: Double, at time: Double) {
        guard angle.isFinite, time.isFinite else { return }
        if isShut(at: time) {
            latched = true
            belowSince = nil
        }
        if latched {
            if angle > Self.reopenAbove { latched = false }
            return
        }
        if angle <= Self.shutAngle {
            if belowSince == nil { belowSince = time }
        } else {
            belowSince = nil
        }
    }

    mutating func reset() {
        latched = false
        belowSince = nil
    }
}

/// The hinge flight recorder (Hush R7): the last `span` seconds of raw hinge reports (time, angle) in a fixed ring (no
/// allocation per report), and a compact text block for diagnostics. Pure, with explicit times.
struct FeelHingeTrace {
    struct Report: Equatable, Sendable {
        var time: Double
        var angle: Double
    }

    /// Seconds kept (counted back from the newest report).
    static let span = 10.0
    /// Ring size: 10 s at up to ~100 Hz.
    static let capacity = 1_024
    /// Reports per text line.
    static let perLine = 8

    private var times: [Double]
    private var angles: [Double]
    private var head = 0
    private(set) var count = 0

    init() {
        times = Array(repeating: 0, count: Self.capacity)
        angles = Array(repeating: 0, count: Self.capacity)
    }

    /// Keep one raw report (non-finite values are skipped).
    mutating func record(angle: Double, at time: Double) {
        guard angle.isFinite, time.isFinite else { return }
        times[head] = time
        angles[head] = angle
        head = (head + 1) % Self.capacity
        count = min(count + 1, Self.capacity)
    }

    mutating func removeAll() {
        head = 0
        count = 0
    }

    /// The kept reports, oldest first, within `span` s of the newest.
    var reports: [Report] {
        guard count > 0 else { return [] }
        var all: [Report] = []
        all.reserveCapacity(count)
        let first = (head - count + Self.capacity) % Self.capacity
        for k in 0..<count {
            let i = (first + k) % Self.capacity
            all.append(Report(time: times[i], angle: angles[i]))
        }
        let newest = all[all.count - 1].time
        return all.filter { $0.time >= newest - Self.span }
    }

    /// The diagnostics block: a summary line (count, span, rate, gaps, steps), then `ms:angle` pairs, times relative
    /// to the oldest kept report. `now` (the same clock) says how long ago the newest report came.
    func text(now: Double?) -> String {
        let kept = reports
        guard let oldest = kept.first, let newest = kept.last else {
            return "Hinge trace (raw, last 10 s): no reports"
        }
        var gaps: [Double] = []
        var smallest = Double.infinity
        var largest = 0.0
        var index = 1
        while index < kept.count {
            gaps.append(kept[index].time - kept[index - 1].time)
            let step = abs(kept[index].angle - kept[index - 1].angle)
            if step > 0 { smallest = min(smallest, step) }
            largest = max(largest, step)
            index += 1
        }
        let spanSeconds = newest.time - oldest.time
        var lines: [String] = []
        var summary = String(format: "Hinge trace (raw, last 10 s): %ld reports over %.2f s", kept.count, spanSeconds)
        if let now, now.isFinite { summary += String(format: ", newest %.2f s ago", max(now - newest.time, 0)) }
        lines.append(summary)
        if !gaps.isEmpty {
            let sorted = gaps.sorted()
            let median = sorted[sorted.count / 2]
            let rate = spanSeconds > 0 ? Double(gaps.count) / spanSeconds : 0
            lines.append(String(format: "rate %.1f Hz; gap median %.0f ms, max %.0f ms; step min %.2f, max %.2f deg",
                                rate, median * 1_000, (sorted.last ?? 0) * 1_000,
                                smallest.isFinite ? smallest : 0, largest))
        }
        var line: [String] = []
        for report in kept {
            line.append(String(format: "%.0f:%.2f", (report.time - oldest.time) * 1_000, report.angle))
            if line.count == Self.perLine {
                lines.append(line.joined(separator: " "))
                line.removeAll(keepingCapacity: true)
            }
        }
        if !line.isEmpty { lines.append(line.joined(separator: " ")) }
        return lines.joined(separator: "\n")
    }
}

/// `GLINT-…` demo/timing lines for CI, only in DEBUG builds launched with the `-glintDemo` argument (Release carries
/// neither the check nor the output). Flushed at once. The App and the Scene may use it.
enum FeelDemoLog {
    #if DEBUG
    static let isEnabled: Bool = ProcessInfo.processInfo.arguments.contains("-glintDemo")
    #else
    static let isEnabled: Bool = false
    #endif

    /// Prints `s` (which should start with `GLINT-`) when enabled.
    static func line(_ s: String) {
        guard isEnabled else { return }
        print(s)
        fflush(stdout)
    }

    /// Same as `line(_:)` (Swoop's name, for copied code).
    static func emit(_ s: String) {
        line(s)
    }
}
