import CoreGraphics
import Foundation
import Testing
@testable import Glint

// Feel engineer tests (ROUND-1): the hinge mapping, the filters, the drag maths, the shut dwell, the note ladder, the
// events → cue mapping, the bed and the haptic book. All pure: no audio engine or haptic engine is ever started (the
// synth is rendered straight into a buffer).

// MARK: - Helpers

/// A fake Duo hinge: the hand's angle as a function of time, reported like the real hinge (at `rate` Hz, and only
/// when it moved at least `step` degrees: nothing while still), with display frames at 120 Hz asking for the light.
@MainActor
private final class FeelFakeHinge {
    let source: HingeMirrorSource
    private(set) var time: Double = 100
    private var lastReported: Double?
    private var nextReport: Double = 0
    static let frame = 1.0 / 120
    static let step = 0.25
    /// Every frame's input from the last `run`.
    private(set) var inputs: [MirrorInput] = []

    init(source: HingeMirrorSource) {
        self.source = source
        source.clock = { [weak self] in self?.time ?? 0 }
    }

    /// Runs for `duration` s; `angle` gives the hand's angle at local time 0…duration. `frames: false` asks no light
    /// (the game paused, the cover display). Returns the last input.
    @discardableResult
    func run(_ duration: Double, rate: Double = 30, frames: Bool = true,
             angle: (Double) -> Double) -> MirrorInput {
        let start = time
        let steps = Int((duration / Self.frame).rounded())
        var input = MirrorInput()
        inputs.removeAll()
        for _ in 0..<steps {
            time += Self.frame
            let local = time - start
            if time >= nextReport {
                let a = angle(local)
                var moved = true
                if let previous = lastReported { moved = abs(a - previous) >= Self.step }
                if moved {
                    source.ingest(angleDegrees: a, at: time)
                    lastReported = a
                }
                nextReport = time + 1 / rate
            }
            if frames {
                input = source.mirror(at: time)
                inputs.append(input)
            }
        }
        return input
    }
}

/// Renders `seconds` of `synth` in 512-frame blocks: the RMS, the peak and whether every sample was finite. `each`
/// runs before every block (send beds and cues there).
private func feelRender(_ synth: FeelSynth, seconds: Double,
                        each: (Int) -> Void = { _ in }) -> (rms: Double, peak: Float, finite: Bool) {
    let frames = 512
    let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer { buffer.deallocate() }
    let blocks = max(Int(seconds * Double(synth.sampleRate) / Double(frames)), 1)
    var sum: Double = 0
    var peak: Float = 0
    var finite = true
    for block in 0..<blocks {
        each(block)
        synth.render(frames: frames, into: buffer)
        for index in 0..<frames {
            let value = buffer[index]
            if !value.isFinite { finite = false }
            peak = max(peak, abs(value))
            sum += Double(value * value)
        }
    }
    let count = Double(blocks * frames)
    return ((sum / count).squareRoot(), peak, finite)
}

private func feelPhoneLayout() -> GardenLayout {
    GardenLayout(size: CGSize(width: 390, height: 844), foldVertical: false, gardenAfter: true, gardenFraction: 0.58)
}

private func feelSnapshot(phase: SessionPhase = .playing, burn: Double = 0, danger: Double = 0,
                          bandSpeed: Double = 0, sun: Double = 0.5, glooms: [GloomState] = []) -> DawnSnapshot {
    var telemetry = Telemetry()
    telemetry.burnRate = burn
    telemetry.fireflyDanger = danger
    telemetry.bandSpeed = bandSpeed
    telemetry.litCount = glooms.filter { $0.lit > 0 }.count
    return DawnSnapshot(mode: .level(3), phase: phase, glooms: glooms, sun: sun, telemetry: telemetry)
}

private func feelGloom(_ id: Int, kind: GloomKind = .murk, hp: Double, maxHP: Double, lit: Double) -> GloomState {
    GloomState(id: id, kind: kind, u: 0.5, d: 0.4, radius: 0.05, hp: hp, maxHP: maxHP, lit: lit)
}

private func feelClose(_ a: Double, _ b: Double, _ tolerance: Double) -> Bool {
    abs(a - b) <= tolerance
}

// MARK: - Tests

@MainActor
struct FeelTests {
    // MARK: Filters

    @Test func feelMathBasics() {
        #expect(FeelMath.clamp01(Double.nan) == 0)
        #expect(FeelMath.clamp01(2) == 1)
        #expect(feelClose(FeelMath.smoothstep(0.5), 0.5, 1e-9))
        #expect(FeelMath.smoothstep(-1) == 0)
        #expect(FeelMath.positive(-3) == 0)
    }

    @Test func oneEuroStartsOnTheFirstSampleAndConverges() {
        var smoother = OneEuroSmoother()
        let first = smoother.filter(10, at: 0)
        #expect(first == 10)
        var value = first
        var t = 0.0
        for _ in 0..<240 {
            t += 1.0 / 120
            value = smoother.filter(20, at: t)
        }
        #expect(feelClose(value, 20, 0.01))
    }

    @Test func predictorGlidesOntoTheLastReading() {
        var predictor = HingePredictor()
        var t = 0.0
        for k in 0...30 {
            predictor.sample(90 + Double(k), at: t)
            t += 1.0 / 30
        }
        let rested = predictor.angle(at: t + 1)
        #expect(feelClose(rested, 120, 0.5))
    }

    @Test func velocityWindowReadsASteadyRampExactly() {
        var window = FeelVelocityWindow(window: 0.1)
        var t = 10.0
        var v = 0.0
        for _ in 0..<60 {
            t += 1.0 / 120
            v = window.add(0.5 * t, at: t)
        }
        #expect(feelClose(v, 0.5, 1e-6))
        // The same frame again: the same answer.
        let again = window.add(99, at: t)
        #expect(feelClose(again, 0.5, 1e-6))
        // After a long gap (frames stopped): a fresh start, no spike.
        let resumed = window.add(5, at: t + 2)
        #expect(resumed == 0)
    }

    @Test func shutGateNeedsTheDwellAndHasHysteresis() {
        var gate = FeelShutGate()
        let shut = Tuning.shutAngle
        let dwell = Tuning.shutDwell
        gate.update(angle: shut - 5, at: 0)
        #expect(!gate.isShut(at: dwell * 0.5))
        #expect(gate.isShut(at: dwell + 0.01))
        gate.update(angle: shut + 1, at: dwell + 0.02)
        #expect(gate.isShut(at: dwell + 0.03))
        gate.update(angle: shut + FeelShutGate.reopenMargin + 2, at: dwell + 0.1)
        #expect(!gate.isShut(at: dwell + 0.11))
        // A dip that lifts before the dwell never shuts.
        var quick = FeelShutGate()
        quick.update(angle: shut - 2, at: 0)
        quick.update(angle: shut + 5, at: dwell * 0.5)
        #expect(!quick.isShut(at: dwell * 3))
    }

    // MARK: The hinge source

    @Test func noHingeMeansTheBandHidesAndThePhoneIsNotShut() {
        let source = HingeMirrorSource()
        let input = source.mirror(at: 1)
        #expect(!source.hasHinge)
        #expect(feelClose(input.band, Tuning.bandMin, 1e-9))
        #expect(input.creaseGlow == 0)
        #expect(!input.isShut)
        #expect(!source.isShut)
        #expect(!source.canResume)
        #expect(source.angle == nil)
    }

    @Test func aSteadyAngleMapsThroughTuning() {
        let source = HingeMirrorSource()
        let hinge = FeelFakeHinge(source: source)
        let theta = 112.5
        let input = hinge.run(1.0) { _ in theta }
        #expect(source.hasHinge)
        #expect(feelClose(input.band, HingeMirrorSource.band(angle: theta), 0.01))
        #expect(feelClose(input.band, min(max(Tuning.band(angle: theta), Tuning.bandMin), 1), 0.01))
        #expect(feelClose(input.creaseGlow, HingeMirrorSource.glow(angle: theta), 0.01))
        #expect(!input.isShut)
        #expect(source.canResume)
        #expect(feelClose(input.bandSpeed, 0, 0.02))
        #expect(feelClose(source.angle ?? 0, theta, 0.1))
    }

    @Test func theMappingIsClampedAndMonotonic() {
        var previous = -Double.infinity
        var angle = 0.0
        while angle <= 180 {
            let band = HingeMirrorSource.band(angle: angle)
            #expect(band >= Tuning.bandMin - 1e-9)
            #expect(band <= 1 + 1e-9)
            #expect(band >= previous - 1e-9)
            let glow = HingeMirrorSource.glow(angle: angle)
            #expect(glow >= 0 && glow <= 1)
            previous = band
            angle += 2.5
        }
        #expect(feelClose(HingeMirrorSource.band(angle: Double.nan), Tuning.bandMin, 1e-9))
        #expect(HingeMirrorSource.glow(angle: Double.nan) == 0)
    }

    @Test func shuttingNeedsTheDwellThenOpeningClearsIt() {
        let source = HingeMirrorSource()
        let hinge = FeelFakeHinge(source: source)
        let low = max(Tuning.shutAngle - 10, 1)
        hinge.run(Tuning.shutDwell * 0.4) { _ in low }
        #expect(!source.isShut)
        let shutInput = hinge.run(Tuning.shutDwell + 0.2) { _ in low }
        #expect(source.isShut)
        #expect(shutInput.isShut)
        #expect(!source.canResume)
        let open = Tuning.resumeAngle + 35
        let opened = hinge.run(0.6) { _ in open }
        #expect(!source.isShut)
        #expect(!opened.isShut)
        #expect(source.canResume)
    }

    @Test func theShutDwellMaturesWithoutFrames() {
        let source = HingeMirrorSource()
        let hinge = FeelFakeHinge(source: source)
        let low = max(Tuning.shutAngle - 10, 1)
        hinge.run(Tuning.shutDwell + 0.15, frames: false) { _ in low }
        #expect(source.isShut)
    }

    @Test func canResumeFollowsTheResumeAngle() {
        let source = HingeMirrorSource()
        let hinge = FeelFakeHinge(source: source)
        hinge.run(0.8) { _ in Tuning.resumeAngle - 4 }
        #expect(!source.canResume)
        hinge.run(0.8) { _ in Tuning.resumeAngle + 6 }
        #expect(source.canResume)
    }

    @Test func bandSpeedFollowsTheHandBothWays() {
        let source = HingeMirrorSource()
        let hinge = FeelFakeHinge(source: source)
        let low = Tuning.creaseAngle
        let high = Tuning.edgeAngle
        hinge.run(0.5) { _ in low }
        hinge.run(1.0) { t in low + (high - low) * t }
        let opening = hinge.inputs[hinge.inputs.count / 2].bandSpeed
        #expect(opening > 0.4)
        hinge.run(1.0) { t in high - (high - low) * t }
        let closing = hinge.inputs[hinge.inputs.count / 2].bandSpeed
        #expect(closing < -0.4)
        let still = hinge.run(0.6) { _ in low }
        #expect(feelClose(still.bandSpeed, 0, 0.05))
    }

    @Test func theBandNeverStepsBetweenReports() {
        let source = HingeMirrorSource()
        let hinge = FeelFakeHinge(source: source)
        let low = Tuning.creaseAngle
        let high = Tuning.edgeAngle
        hinge.run(0.3) { _ in low }
        hinge.run(1.0) { t in low + (high - low) * t }
        var largest = 0.0
        var index = 1
        while index < hinge.inputs.count {
            largest = max(largest, abs(hinge.inputs[index].band - hinge.inputs[index - 1].band))
            index += 1
        }
        // A 1 d/s sweep moves ~0.008 per 120 Hz frame; a 30 Hz step would be ~0.033.
        #expect(largest < 0.025)
    }

    @Test func resetKeepsTheHingeButForgetsTheMotion() {
        let source = HingeMirrorSource()
        let hinge = FeelFakeHinge(source: source)
        hinge.run(0.5) { t in 100 + 40 * t }
        source.reset()
        #expect(source.hasHinge)
        let after = hinge.run(0.5) { _ in 120 }
        #expect(feelClose(after.band, HingeMirrorSource.band(angle: 120), 0.02))
        #expect(source.traceText().contains("reports"))
    }

    // MARK: The drag fallback

    @Test func dragDownMovesTheBandByTheGain() {
        let drag = DragMirrorSource()
        drag.layout = feelPhoneLayout()
        drag.setBand(Tuning.bandMin)
        let depth = Double(drag.layout.gardenDepth)
        drag.dragBegan(CGPoint(x: 200, y: 500))
        drag.dragMoved(CGPoint(x: 200, y: 500 + depth / 2))
        drag.dragEnded()
        #expect(drag.hasMoved)
        #expect(feelClose(drag.target, Tuning.bandMin + 0.5 * DragMirrorSource.dragGain, 1e-6))
        var t = 50.0
        var input = drag.mirror(at: t)
        for _ in 0..<120 {
            t += 1.0 / 120
            input = drag.mirror(at: t)
        }
        #expect(feelClose(input.band, drag.target, 1e-3))
        #expect(!input.isShut)
    }

    @Test func dragAcrossTheGardenDoesNothing() {
        let drag = DragMirrorSource()
        drag.layout = feelPhoneLayout()
        drag.setBand(0.3)
        drag.dragBegan(CGPoint(x: 50, y: 600))
        drag.dragMoved(CGPoint(x: 350, y: 600))
        #expect(!drag.hasMoved)
        #expect(feelClose(drag.target, 0.3, 1e-9))
    }

    @Test func dragClampsAtTheEndsAndComesBackAtOnce() {
        let drag = DragMirrorSource()
        drag.layout = feelPhoneLayout()
        drag.setBand(0)
        let depth = Double(drag.layout.gardenDepth)
        drag.dragBegan(CGPoint(x: 200, y: 400))
        drag.dragMoved(CGPoint(x: 200, y: 400 + 3 * depth))
        #expect(feelClose(drag.target, 1, 1e-9))
        drag.dragMoved(CGPoint(x: 200, y: 400 + 3 * depth - depth / 4))
        #expect(feelClose(drag.target, 1 - 0.25 * DragMirrorSource.dragGain, 1e-6))
        drag.dragMoved(CGPoint(x: 200, y: -5000))
        #expect(feelClose(drag.target, Tuning.bandMin, 1e-9))
    }

    @Test func dragSpeedIsCapped() {
        let drag = DragMirrorSource()
        drag.layout = feelPhoneLayout()
        drag.setBand(Tuning.bandMin)
        let depth = Double(drag.layout.gardenDepth)
        drag.dragBegan(CGPoint(x: 200, y: 300))
        drag.dragMoved(CGPoint(x: 200, y: 300 + depth))
        var t = 10.0
        var previous = drag.mirror(at: t).band
        var fastest = 0.0
        var largestStep = 0.0
        for _ in 0..<120 {
            t += 1.0 / 120
            let input = drag.mirror(at: t)
            fastest = max(fastest, abs(input.bandSpeed))
            largestStep = max(largestStep, abs(input.band - previous))
            previous = input.band
        }
        #expect(fastest <= Tuning.dragSpeedCap + 0.05)
        #expect(largestStep <= Tuning.dragSpeedCap / 120 + 1e-6)
        #expect(fastest > 0.5 * Tuning.dragSpeedCap)
    }

    @Test func dragFollowsABookLayoutWithTheGardenBefore() {
        let drag = DragMirrorSource()
        drag.layout = GardenLayout(size: CGSize(width: 1000, height: 700), foldVertical: true, gardenAfter: false,
                                   gardenFraction: 0.5)
        drag.setBand(Tuning.bandMin)
        let depth = Double(drag.layout.gardenDepth)
        drag.dragBegan(CGPoint(x: 400, y: 300))
        // Garden on the left: the flowers are to the left, so dragging left lets the light in.
        drag.dragMoved(CGPoint(x: 400 - depth / 2, y: 300))
        #expect(feelClose(drag.target, Tuning.bandMin + 0.5 * DragMirrorSource.dragGain, 1e-6))
    }

    @Test func setBandJumpsWithoutSpeedAndResetClearsHasMoved() {
        let drag = DragMirrorSource()
        drag.layout = feelPhoneLayout()
        drag.dragBegan(CGPoint(x: 100, y: 500))
        drag.dragMoved(CGPoint(x: 100, y: 600))
        #expect(drag.hasMoved)
        drag.setBand(0.5)
        let input = drag.mirror(at: 3)
        #expect(feelClose(input.band, 0.5, 1e-9))
        #expect(input.bandSpeed == 0)
        #expect(drag.hasMoved)
        drag.setBand(5)
        #expect(feelClose(drag.band, 1, 1e-9))
        drag.reset(band: Tuning.bandMin)
        #expect(!drag.hasMoved)
        #expect(feelClose(drag.band, Tuning.bandMin, 1e-9))
    }

    @Test func dragCreaseGlowAndEaseArePure() {
        #expect(DragMirrorSource.creaseGlow(band: Tuning.bandMin) == 0)
        #expect(DragMirrorSource.creaseGlow(band: 0) == 1)
        #expect(DragMirrorSource.creaseGlow(band: 0.6) == 1)
        let next = DragMirrorSource.ease(0, toward: 1, dt: 1.0 / 120)
        #expect(next > 0)
        #expect(next <= Tuning.dragSpeedCap / 120 + 1e-9)
        #expect(DragMirrorSource.ease(0.5, toward: 0.5001, dt: 0.1) == 0.5001)
        #expect(DragMirrorSource.ease(0.2, toward: 0.9, dt: 0) == 0.2)
    }

    // MARK: The note ladder

    @Test func theLadderClimbsTheCMajorPentatonicFromC5() {
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 1)), 523.25, 0.05))
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 2)), 587.33, 0.05))
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 3)), 659.26, 0.05))
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 4)), 783.99, 0.05))
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 5)), 880.0, 0.05))
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 6)), 1046.5, 0.1))
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 11)), 2093.0, 0.2))
        // Capped at two octaves; nonsense chains read as the first rung.
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 40)), 2093.0, 0.2))
        #expect(feelClose(Double(FeelSoundBook.ladderHz(chain: 0)), 523.25, 0.05))
        var previous: Float = 0
        for chain in 1...11 {
            let f = FeelSoundBook.ladderHz(chain: chain)
            #expect(f > previous)
            previous = f
        }
    }

    @Test func biggerGloomsPopLowerAndFuller() {
        #expect(FeelSoundBook.bubbleHz(.brute) < FeelSoundBook.bubbleHz(.murk))
        #expect(FeelSoundBook.bubbleHz(.murk) < FeelSoundBook.bubbleHz(.wisp))
        #expect(FeelSoundBook.popPitch(kind: .brute, chain: 4) < FeelSoundBook.popPitch(kind: .murk, chain: 4))
        var dice = FeelDice(seed: 7)
        let wisp = FeelSoundBook.pop(kind: .wisp, chain: 3, dice: &dice)
        let brute = FeelSoundBook.pop(kind: .brute, chain: 3, dice: &dice)
        #expect(brute.count > wisp.count)
        let wispLow = wisp.map { $0.pitch }.filter { $0 > 0 }.min() ?? 0
        let bruteLow = brute.map { $0.pitch }.filter { $0 > 0 }.min() ?? 0
        #expect(bruteLow < wispLow)
    }

    @Test func everyPopRecipeIsSane() {
        var dice = FeelDice(seed: 11)
        for kind in GloomKind.allCases {
            for chain in [1, 4, 9, 30] {
                let commands = FeelSoundBook.pop(kind: kind, chain: chain, dice: &dice)
                #expect(!commands.isEmpty)
                for command in commands {
                    #expect(command.gain > 0 && command.gain < 0.5)
                    #expect(command.delay >= 0 && command.delay < 0.6)
                    if case .ring(let spec) = command, spec.kind == .glass {
                        #expect(spec.fundamental <= 5200)
                    }
                }
            }
        }
    }

    // MARK: Events → cues

    @Test func eventsMapToCues() {
        let events: [GameEvent] = [
            .emerged(id: 1, kind: .wisp, u: 0.2),
            .popped(id: 1, kind: .murk, u: 0.5, d: 0.3, chain: 2, points: 10),
            .swept(count: 3, bonus: 90),
            .split(u: 0.4, d: 0.5),
            .hopped(id: 2, u: 0.3, d: 0.4, skittish: true),
            .fireflyEmerged(id: 3, u: 0.6),
            .fireflyScorched(id: 3, u: 0.6, d: 0.2),
            .fireflyDelivered(id: 4, lane: 2, replanted: true, points: 0),
            .flowerEaten(lane: 1, flowersLeft: 3, by: .brute),
            .chainBroken(was: 2),
            .chainBroken(was: 5),
            .chainEnded(was: 4),
            .hint(.lightTheShadows),
            .started,
            .sunrise(stars: 3, flowerBonus: 200),
            .nightWins,
            .waveUp(4),
        ]
        let cues = FeelCueMap.cues(for: events)
        let expected: [FeelCue] = [
            .emerge(.wisp),
            .pop(.murk, chain: 2),
            .sweep(count: 3),
            .split,
            .hop(skittish: true),
            .fireflyArrived,
            .fizzle,
            .delivered(replanted: true),
            .flowerEaten(flowersLeft: 3),
            .chainLost(was: 5),
            .dawn,
            .sunrise(stars: 3),
            .nightWins,
            .waveUp(4),
        ]
        #expect(cues == expected)
        #expect(FeelCueMap.cue(for: .hint(.hoppers)) == nil)
        #expect(FeelCueMap.cue(for: .chainEnded(was: 9)) == nil)
    }

    @Test func popsOnOneFrameBecomeARisingRun() {
        var sequencer = FeelPopSequencer()
        var delays: [Double] = []
        for _ in 0..<6 {
            if let d = sequencer.slot(at: 5) { delays.append(d) }
        }
        #expect(delays.count == 6)
        #expect(delays[0] == 0)
        for k in 1..<delays.count {
            #expect(feelClose(delays[k] - delays[k - 1], FeelPopSequencer.gap, 1e-9))
        }
        // A pile-up: anything waiting longer than the cap is dropped.
        var dropped = 0
        for _ in 0..<20 {
            if sequencer.slot(at: 5) == nil { dropped += 1 }
        }
        #expect(dropped > 0)
        // Later, a lone pop sounds at once.
        let later = sequencer.slot(at: 7)
        #expect(later == 0)
        #expect(FeelPopSequencer.scale(index: 0) == 1)
        #expect(FeelPopSequencer.scale(index: 50) >= 0.6)
        #expect(FeelPopSequencer.sparkles(index: 1) == nil)
        #expect(FeelPopSequencer.sparkles(index: 5) == 1)
    }

    @Test func throttleSpacesQuietCues() {
        var throttle = FeelThrottle(gap: 0.15)
        let first = throttle.allow(at: 1)
        let second = throttle.allow(at: 1.05)
        let third = throttle.allow(at: 1.2)
        #expect(first)
        #expect(!second)
        #expect(third)
    }

    // MARK: The bed

    @Test func sizzleSwellsWithTheBurn() {
        #expect(FeelSoundBook.sizzleLevel(burn: 0) == 0)
        #expect(FeelSoundBook.sizzleLevel(burn: Double.nan) == 0)
        var previous = 0.0
        for burn in [0.1, 0.5, 1.0, 2.0, 5.0] {
            let level = FeelSoundBook.sizzleLevel(burn: burn)
            #expect(level > previous)
            #expect(level <= 1)
            previous = level
        }
        #expect(FeelSoundBook.sizzleHz(heat: 1, level: 0.5) > FeelSoundBook.sizzleHz(heat: 0, level: 0.5))
        #expect(FeelSoundBook.kettleLevel(level: 1, heat: 0.2) == 0)
        #expect(FeelSoundBook.kettleLevel(level: 1, heat: 0.95) > 0.5)
    }

    @Test func heatIsTheLitGloomsWeakness() {
        let glooms = [
            feelGloom(1, hp: 0.25, maxHP: 0.5, lit: 1),
            feelGloom(2, hp: 0.1, maxHP: 1, lit: 0),
        ]
        #expect(feelClose(FeelSoundBook.heat(of: glooms), 0.5, 1e-9))
        #expect(FeelSoundBook.heat(of: []) == 0)
        let fresh = [feelGloom(3, hp: 2.2, maxHP: 2.2, lit: 0.5)]
        #expect(feelClose(FeelSoundBook.heat(of: fresh), 0, 1e-9))
    }

    @Test func theBedFollowsTheGameAndTheSwitches() {
        let glooms = [feelGloom(1, hp: 0.1, maxHP: 0.55, lit: 1)]
        let burning = feelSnapshot(burn: 1, danger: 0.6, bandSpeed: 1.2, glooms: glooms)
        let live = FeelSoundBook.playBed(snapshot: burning, sound: true, music: true, paused: false, advancing: true)
        #expect(live.master > 0)
        #expect(live.sizzle > 0)
        #expect(live.kettle > 0)
        #expect(live.alarm > 0)
        #expect(live.air > 0)
        #expect(live.pad == 1)

        let paused = FeelSoundBook.playBed(snapshot: burning, sound: true, music: true, paused: true, advancing: false)
        #expect(paused.sizzle == 0 && paused.alarm == 0 && paused.air == 0)
        #expect(feelClose(Double(paused.pad), FeelSoundBook.pausedPadShare, 1e-6))

        let held = FeelSoundBook.playBed(snapshot: burning, sound: true, music: true, paused: false, advancing: false)
        #expect(held.sizzle == 0)

        let musicOnly = FeelSoundBook.playBed(snapshot: burning, sound: false, music: true, paused: false,
                                              advancing: true)
        #expect(musicOnly.master > 0 && musicOnly.sizzle == 0 && musicOnly.pad > 0)

        let soundOnly = FeelSoundBook.playBed(snapshot: burning, sound: true, music: false, paused: false,
                                              advancing: true)
        #expect(soundOnly.pad == 0 && soundOnly.sizzle > 0)

        let silent = FeelSoundBook.playBed(snapshot: burning, sound: false, music: false, paused: false,
                                           advancing: true)
        #expect(silent.master == 0)

        let won = FeelSoundBook.playBed(snapshot: feelSnapshot(phase: .won, burn: 1, glooms: glooms), sound: true,
                                        music: true, paused: false, advancing: true)
        #expect(won.sizzle == 0)
        #expect(won.padBright == 1)
    }

    @Test func thePadBrightensWithTheSun() {
        let dark = FeelSoundBook.padBrightness(mode: .level(1), phase: .playing, sun: 0)
        let bright = FeelSoundBook.padBrightness(mode: .level(1), phase: .playing, sun: 1)
        #expect(bright > dark)
        #expect(FeelSoundBook.padBrightness(mode: .daily(day: 3), phase: .won, sun: 1) == 1)
        #expect(FeelSoundBook.padBrightness(mode: .level(2), phase: .waiting, sun: 0) < 0.1)
        let night = FeelSoundBook.padBrightness(mode: .endless, phase: .playing, sun: 0.9)
        #expect(night < 0.3)
        #expect(FeelSoundBook.airLevel(bandSpeed: 0) == 0)
        #expect(FeelSoundBook.airLevel(bandSpeed: -2) > FeelSoundBook.airLevel(bandSpeed: 0.5))
    }

    // MARK: Haptics

    @Test func hapticBookShapes() {
        #expect(FeelHapticBook.popIntensity(.brute) > FeelHapticBook.popIntensity(.wisp))
        let cue = FeelHapticBook.pops([(kind: GloomKind.wisp, chain: 1, delay: 0),
                                       (kind: GloomKind.brute, chain: 2, delay: 0.045)])
        #expect(cue.notes.count == 1 + 3)
        #expect(feelClose(cue.notes[1].time, 0.045, 1e-9))
        let strong = FeelHapticBook.adapt(FeelHapticCue(notes: [.tap(0.5, 0.8)]), to: .strong)
        #expect(strong.notes.count == 2)
        let normal = FeelHapticBook.adapt(FeelHapticCue(notes: [.tap(0.5, 0.8)]), to: .normal)
        #expect(normal.notes.count == 1)
        #expect(FeelHapticBook.sizzleLevel(0.01, profile: .normal) == 0)
        #expect(FeelHapticBook.sizzleLevel(0.8, profile: .off) == 0)
        #expect(FeelHapticBook.sizzleLevel(0.8, profile: .strong) > FeelHapticBook.sizzleLevel(0.8, profile: .normal))
        #expect(FeelHapticBook.sizzleSharpness(heat: 1) > FeelHapticBook.sizzleSharpness(heat: 0))
        #expect(FeelHapticBook.alarmLevel(0.5, profile: .normal) > 0)
        #expect(FeelHapticProfile.defaultFor(hasFold: true) == .strong)
        let cues: [UICue] = [.tap, .back, .toggle, .star(1), .star(3), .unlock, .levelStart]
        for ui in cues {
            #expect(!FeelHapticBook.ui(ui).notes.isEmpty)
        }
    }

    // MARK: Recipes and the synth (rendered into a buffer, no audio engine)

    @Test func everyMomentHasASound() {
        var dice = FeelDice(seed: 3)
        let ui: [UICue] = [.tap, .back, .toggle, .star(1), .star(2), .star(3), .unlock, .levelStart]
        for cue in ui {
            #expect(!FeelSoundBook.ui(cue, dice: &dice).isEmpty)
        }
        #expect(!FeelSoundBook.sweepStab(dice: &dice).isEmpty)
        #expect(!FeelSoundBook.sweepRung(count: 7, dice: &dice).isEmpty)
        #expect(!FeelSoundBook.fizzle(dice: &dice).isEmpty)
        #expect(!FeelSoundBook.delivered(replanted: true, dice: &dice).isEmpty)
        #expect(!FeelSoundBook.delivered(replanted: false, dice: &dice).isEmpty)
        #expect(!FeelSoundBook.flowerEaten(dice: &dice).isEmpty)
        #expect(!FeelSoundBook.nightWins().isEmpty)
        #expect(!FeelSoundBook.dawn().isEmpty)
        let small = FeelSoundBook.sunrise(stars: 1, ripple: 0, dice: &dice)
        let big = FeelSoundBook.sunrise(stars: 3, ripple: 50, dice: &dice)
        #expect(big.count > small.count)
        #expect(big.count < 140)
        #expect(FeelSoundBook.starHz(3) > FeelSoundBook.starHz(1))
    }

    @Test func theSynthStaysCleanUnderABigSweep() {
        let synth = FeelSynth(sampleRate: 48_000)
        var bed = FeelBed()
        bed.master = FeelSoundBook.masterGain
        bed.glide = 0.01
        bed.sizzle = 1
        bed.sizzleHz = 4000
        bed.crackleRate = 250
        bed.kettle = 0.8
        bed.alarm = 0.7
        bed.air = 0.6
        bed.pad = 1
        bed.padBright = 1
        bed.twinkleRate = 2
        synth.send(.bed(bed))
        var dice = FeelDice(seed: 5)
        var sequencer = FeelPopSequencer()
        let result = feelRender(synth, seconds: 1.5) { block in
            guard block == 4 else { return }
            for index in 0..<10 {
                guard let delay = sequencer.slot(at: 0) else { continue }
                let kind: GloomKind = index == 4 ? .brute : .wisp
                for command in FeelSoundBook.pop(kind: kind, chain: index + 1,
                                                 scale: FeelPopSequencer.scale(index: index), delay: Float(delay),
                                                 sparkles: FeelPopSequencer.sparkles(index: index), dice: &dice) {
                    synth.send(command)
                }
            }
            for command in FeelSoundBook.sweepStab(delay: 0.1, dice: &dice) { synth.send(command) }
        }
        #expect(result.finite)
        #expect(result.peak <= 0.98)
        #expect(result.rms > 0.005)
        #expect(synth.voiceSteals == 0)
    }

    @Test func aSilentBedIsSilent() {
        let synth = FeelSynth(sampleRate: 48_000)
        synth.send(.bed(FeelSoundBook.idleBed(master: 0, glide: 0.004)))
        let result = feelRender(synth, seconds: 0.2)
        #expect(result.finite)
        #expect(result.peak < 1e-4)
    }

    // MARK: R2: hinge precision (1° ≈ 0.018 d with 55° of travel; the full-light core is ±0.05 d)

    @Test func aNoisyStillHandBarelyMovesTheBand() {
        let theta = 110.0
        for seed in [UInt64(1), 2, 3] {
            let source = HingeMirrorSource()
            let hinge = FeelFakeHinge(source: source)
            var dice = FeelDice(seed: seed)
            hinge.run(4.0, rate: 27) { _ in theta + dice.range(-1.5, 1.5) }
            let settled = Array(hinge.inputs.dropFirst(120))
            #expect(settled.count > 200)
            let mean = settled.reduce(0.0) { $0 + $1.band } / Double(max(settled.count, 1))
            var jitter = 0.0
            var offset = 0.0
            for input in settled {
                jitter = max(jitter, abs(input.band - mean))
                offset = max(offset, abs(input.band - HingeMirrorSource.band(angle: theta)))
            }
            // Node port: ≤ 0.0056 d over 8 seeds (R1's pipeline: 0.037 d).
            #expect(jitter < 0.01)
            #expect(offset < 0.02)
        }
    }

    @Test func aSixtyDegreeMoveFollowsWithinSixtyMilliseconds() {
        let start = 85.0
        let end = 130.0
        let speed = 60.0
        let duration = (end - start) / speed
        let rate = (HingeMirrorSource.band(angle: end) - HingeMirrorSource.band(angle: start)) / duration
        #expect(rate > 0)
        for noisy in [false, true] {
            let source = HingeMirrorSource()
            let hinge = FeelFakeHinge(source: source)
            var dice = FeelDice(seed: 9)
            hinge.run(0.5, rate: 27) { _ in start + (noisy ? dice.range(-1.5, 1.5) : 0) }
            hinge.run(duration + 0.8, rate: 27) { t in
                let hand = t < duration ? start + speed * t : end
                return hand + (noisy ? dice.range(-1.5, 1.5) : 0)
            }
            var lags: [Double] = []
            for (index, input) in hinge.inputs.enumerated() {
                let t = Double(index + 1) * FeelFakeHinge.frame
                guard t > 0.3 && t < duration - 0.05 else { continue }
                let truth = HingeMirrorSource.band(angle: start + speed * t)
                lags.append((truth - input.band) / rate)
            }
            #expect(lags.count > 20)
            let meanLag = lags.reduce(0, +) / Double(max(lags.count, 1))
            // Node port: 12 ms clean, 9 ms noisy (R1: 9 / 6 ms).
            #expect(meanLag < 0.06)
            if !noisy {
                #expect((lags.max() ?? 1) < 0.06)
                // The hand stopped and the Duo went quiet: the light rests on the phone's real angle.
                #expect(feelClose(source.angle ?? 0, end, 0.3))
            }
        }
    }

    @Test func theSteadyFilterIgnoresNoiseButFollowsAMove() {
        var steady = HingeMirrorSource.steadyFilter()
        var plain = OneEuroSmoother()
        var dice = FeelDice(seed: 21)
        var t = 0.0
        var steadyWorst = 0.0
        var plainWorst = 0.0
        for k in 0..<120 {
            t += 1.0 / 27
            let x = 110 + dice.range(-1.5, 1.5)
            let a = steady.filter(x, at: t)
            let b = plain.filter(x, at: t)
            if k > 27 {
                steadyWorst = max(steadyWorst, abs(a - 110))
                plainWorst = max(plainWorst, abs(b - 110))
            }
        }
        #expect(steadyWorst < plainWorst / 2)
        // A real 10° move is followed at once (the residual boost), not after a 0.2 Hz crawl.
        var after = 0.0
        for _ in 0..<3 {
            t += 1.0 / 27
            after = steady.filter(120, at: t)
        }
        #expect(feelClose(after, 120, 0.5))
    }

    // MARK: R2: cloud shadows

    @Test func shadeCoverFollowsTheContract() {
        let shade = ShadeState(id: 1, u: 0.5, halfWidth: 0.1, strength: 1)
        #expect(feelClose(FeelSoundBook.shadeCover(u: 0.5, shades: [shade]), 1, 1e-9))
        #expect(FeelSoundBook.shadeCover(u: 0.9, shades: [shade]) == 0)
        #expect(FeelSoundBook.shadeCover(u: 0.3, shades: []) == 0)
        let half = ShadeState(id: 2, u: 0.5, halfWidth: 0.1, strength: 0.5)
        #expect(feelClose(FeelSoundBook.shadeCover(u: 0.5, shades: [half, half]), 0.75, 1e-9))
        let edge = FeelSoundBook.shadeCover(u: 0.6, shades: [shade])
        #expect(edge > 0.2 && edge < 0.8)
    }

    @Test func aShadedBurnIsMuffledNotCut() {
        let gloom = GloomState(id: 1, kind: .brute, u: 0.5, d: 0.5, radius: 0.08, hp: 1.5, maxHP: 2.2, lit: 0)
        let cloud = ShadeState(id: 1, u: 0.5, halfWidth: 0.15, strength: 1)
        var telemetry = Telemetry()
        telemetry.burnRate = 0 // Core: no light reaches it under the cloud
        let shaded = DawnSnapshot(mode: .level(12), phase: .playing, glooms: [gloom], shades: [cloud], band: 0.5,
                                  telemetry: telemetry)
        let state = FeelSoundBook.burn(of: shaded)
        #expect(state.level > 0.2)
        #expect(state.muffle > 0.95)
        let bed = FeelSoundBook.playBed(snapshot: shaded, sound: true, music: false, paused: false, advancing: true)
        #expect(bed.sizzle > 0)
        #expect(bed.sizzleMuffle > 0.95)
        #expect(bed.kettle < 0.05)

        var open = Telemetry()
        open.burnRate = 1
        var lit = gloom
        lit.lit = 1
        let clear = DawnSnapshot(mode: .level(12), phase: .playing, glooms: [lit], band: 0.5, telemetry: open)
        let clearState = FeelSoundBook.burn(of: clear)
        #expect(clearState.muffle == 0)
        #expect(clearState.level > state.level)
        #expect(FeelHapticBook.sizzleSharpness(heat: 0.5, muffle: 1) < FeelHapticBook.sizzleSharpness(heat: 0.5))
        #expect(FeelHapticBook.muffledIntensity(1) < FeelHapticBook.muffledIntensity(0))
        #expect(FeelSynth.muffleCutoff(1) < 700 && FeelSynth.muffleCutoff(0) > 10_000)
    }

    @Test func theMuffleDarkensTheSizzle() {
        func sizzleRMS(muffle: Float) -> Double {
            let synth = FeelSynth(sampleRate: 48_000)
            var bed = FeelBed()
            bed.master = FeelSoundBook.masterGain
            bed.glide = 0.004
            bed.sizzle = 1
            bed.sizzleHz = 3500
            bed.crackleRate = 150
            bed.sizzleMuffle = muffle
            synth.send(.bed(bed))
            let result = feelRender(synth, seconds: 0.6)
            #expect(result.finite)
            return result.rms
        }
        let open = sizzleRMS(muffle: 0)
        let muffled = sizzleRMS(muffle: 1)
        #expect(open > 0.005)
        #expect(muffled > 0)
        #expect(muffled < open * 0.6)
    }

    @Test func aCloudHushesOnceAsItReachesTheBand() {
        var watcher = FeelShadeWatcher()
        let outside = ShadeState(id: 1, u: -0.3, halfWidth: 0.1, strength: 1)
        let first = watcher.update(shades: [outside], phase: .playing, sessionTime: 10, now: 100)
        #expect(!first)
        let entering = ShadeState(id: 1, u: -0.05, halfWidth: 0.1, strength: 1)
        let second = watcher.update(shades: [entering], phase: .playing, sessionTime: 11, now: 101)
        #expect(second)
        let again = watcher.update(shades: [entering], phase: .playing, sessionTime: 11.1, now: 101.1)
        #expect(!again)
        // A second cloud arriving 0.3 s later makes no second hush (one sound for clouds arriving together).
        let twin = ShadeState(id: 2, u: 1.05, halfWidth: 0.1, strength: 1)
        let tooSoon = watcher.update(shades: [entering, twin], phase: .playing, sessionTime: 11.3, now: 101.3)
        #expect(!tooSoon)
        #expect(watcher.seen.contains(2))
        let faint = ShadeState(id: 3, u: 0.5, halfWidth: 0.1, strength: 0.05)
        let weak = watcher.update(shades: [faint], phase: .playing, sessionTime: 14, now: 104)
        #expect(!weak)
        let paused = ShadeState(id: 4, u: 0.5, halfWidth: 0.1, strength: 1)
        let silent = watcher.update(shades: [paused], phase: .playing, live: false, sessionTime: 15, now: 105)
        #expect(!silent)
        #expect(watcher.seen.contains(4))
        // A new level: the ids are forgotten.
        _ = watcher.update(shades: [], phase: .waiting, sessionTime: 0, now: 106)
        #expect(watcher.seen.isEmpty)
        let fresh = watcher.update(shades: [entering], phase: .playing, sessionTime: 1, now: 108)
        #expect(fresh)
        var dice = FeelDice(seed: 4)
        #expect(!FeelSoundBook.coolHush(dice: &dice).isEmpty)
        #expect(!FeelHapticBook.coolHush.notes.isEmpty)
    }
}
