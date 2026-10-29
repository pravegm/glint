import CoreGraphics
import Foundation

// MARK: - One sunrise (or one Long Night): the rules of GAME-DESIGN §3–§6
//
// Deterministic: the same mode, seed and input sequence give the same events. `step` sub-steps at ≤ 1/120 s with the
// band interpolated across the frame (a quick flick crosses a firefly in the sub-steps, not in one jump), and keeps
// its working arrays between frames (it runs at 120 Hz on device).
//
// Rules in one place:
// - `waiting` until the band first reaches d ≥ 0, or moves more than `Tuning.startNudge` from its first value (the
//   drag fallback). Shut inputs never start it. No clock, no spawns while waiting.
// - Glooms enter at d = −radius and creep outward; they never stop in the light. Light burns `intensity × burnRate`
//   HP/s, measured at the centre moved 40 % of the radius toward the band. Splitters pop into two flung wisps; hoppers
//   rest, crouch and hop (a first touch of light makes a resting hopper hop at once, and light hurries its rest).
// - A gloom reaching d = 1 eats the flower in its lane (`Tuning.lane`), else the nearest standing one. A firefly
//   reaching d = 1 replants the lane's flower (else the nearest lost one), or blooms for points if none is lost.
//   0.35 s of light (draining at 0.6 s/s unlit) fizzles a firefly.
// - Chain: a pop within `chainWindow` of the last one adds 1 (multiplier 1 + 0.25 × (chain − 1), ≤ 4). Scorches and
//   eaten flowers break it (`.chainBroken`); timing out ends it quietly (`.chainEnded`). Sweep: a run of pops each within
//   `sweepWindow` of the previous; at 3 it scores 90 and each further pop +30.
// - Sunrise at `duration`: every shadow left evaporates silently, +40 per flower, stars (daily: 0). All flowers gone:
//   the night wins. Long Night never rises: a new wave every 30 s (`.waveUp(n)` from wave 2).
// - R2: the crease shade (`d < Tuning.creaseShade`) gets no light: glooms and fireflies there are safe. Cloud shadows
//   (`LevelSpec.clouds`, from world 2) slide across in u and multiply the light by `Tuning.cloudFactor`.

/// Running totals (results, achievements, balance).
struct DawnStats: Equatable {
    var emerged: Int = 0
    var pops: Int = 0
    var longestChain: Int = 0
    var sweeps: Int = 0
    var bestSweep: Int = 0
    var flowersEaten: Int = 0
    var flowersReplanted: Int = 0
    var firefliesScorched: Int = 0
    var firefliesDelivered: Int = 0
    var hops: Int = 0
    var splits: Int = 0
    /// R2: pops of brutes (achievements), the final score, and pops and eaten flowers by gloom kind (lost-level tips).
    var brutesPopped: Int = 0
    var score: Int = 0
    var popsBy: [GloomKind: Int] = [:]
    var flowersEatenBy: [GloomKind: Int] = [:]
    /// R2: light-seconds the band would have given glooms but a cloud's shadow (or the crease shade) took away.
    var cloudBlockedSeconds: Double = 0
    var creaseBlockedSeconds: Double = 0
    /// R2: glooms a cloud kept mostly dark while the band was on them, and how many of those then ate a flower.
    var cloudedGlooms: Int = 0
    var eatenAfterCloud: Int = 0
    /// R2: clouds that crossed the garden.
    var clouds: Int = 0
    /// R3: light-seconds the band shone on glooms still under the ground, and glooms that surfaced.
    var submergedBlockedSeconds: Double = 0
    var surfaced: Int = 0

    /// Flowers eaten by `kind`.
    func eaten(by kind: GloomKind) -> Int { return flowersEatenBy[kind] ?? 0 }

    /// What ate the most flowers (nil if none; ties go to `GloomKind.allCases` order).
    var worstKind: GloomKind? {
        var best: GloomKind? = nil
        var most: Int = 0
        for k in GloomKind.allCases {
            let n: Int = flowersEatenBy[k] ?? 0
            if n > most {
                most = n
                best = k
            }
        }
        return best
    }
}

/// R2: a scheduled cloud (a `CloudSpec` with the session offset applied).
struct PendingCloud: Equatable {
    var spec: CloudSpec
    var seq: Int
}

/// A scheduled arrival.
struct PendingSpawn: Equatable {
    var time: Double
    var kind: SpawnKind
    var u: Double
    var speedScale: Double
    /// Fireflies: the phase of the wavy drift (0…1).
    var phase: Double
    /// Creation order (ties on `time` keep it).
    var seq: Int
    /// R3: where a gloom surfaces (0 = it doesn't travel submerged).
    var surfaceD: Double = 0
}

/// A live gloom (the session's working copy; `state` is what the snapshot shows).
struct DawnGloom {
    var id: Int
    var kind: GloomKind
    var u: Double
    var d: Double
    var radius: Double
    var hp: Double
    var maxHP: Double
    var lit: Double
    var age: Double
    var tension: Double
    var speed: Double
    var speedScale: Double
    /// Hopper: seconds of rest between hops; `timer` counts the rest or the hop.
    var rest: Double
    var timer: Double
    var hopping: Bool
    var hopFrom: Double
    /// Splitter wisps: seconds of fling left.
    var fling: Double
    var wasLit: Bool
    /// R2: a cloud kept it mostly dark under the band at least once.
    var clouded: Bool = false
    /// R3: travelling under the ground to `surfaceD` (immune to light).
    var submerged: Bool = false
    var surfaceD: Double = 0

    var state: GloomState {
        return GloomState(id: id, kind: kind, u: u, d: d, radius: radius, hp: max(hp, 0), maxHP: maxHP, lit: lit,
                          age: age, tension: tension, submerged: submerged, surfaceD: submerged ? surfaceD : 0)
    }
}

/// A live firefly.
struct DawnFirefly {
    var id: Int
    var u: Double
    var baseU: Double
    var d: Double
    /// Seconds of cumulative light.
    var scorchTime: Double
    var lit: Double
    var age: Double
    var speed: Double
    var phase: Double

    var state: FireflyState {
        let s: Double = min(max(scorchTime / Tuning.fireflyScorchLimit, 0), 1)
        return FireflyState(id: id, u: u, d: d, scorch: s, lit: lit, age: age)
    }
}

final class DawnSession {
    let mode: PlayMode
    /// The script (nil in Long Night).
    let spec: LevelSpec?
    /// The seed actually used (Today's Dawn: `DailySeed.seed(day:)`).
    let seed: UInt64
    /// Seconds to sunrise (0 in Long Night: it never rises).
    let duration: Double

    private(set) var snapshot: DawnSnapshot
    private(set) var stats: DawnStats = DawnStats()
    /// Long Night's current wave (0 before the start).
    private(set) var wave: Int = 0

    var isFinished: Bool { return snapshot.phase == .won || snapshot.phase == .lost }

    private var rng: SeededRandom
    private(set) var queue: [PendingSpawn] = []
    private var queueIndex: Int = 0
    private var seqCounter: Int = 0
    private(set) var glooms: [DawnGloom] = []
    private(set) var fireflies: [DawnFirefly] = []
    private var popped: [DawnGloom] = []
    private(set) var cloudQueue: [PendingCloud] = []
    private var cloudIndex: Int = 0
    /// R2: the clouds on the band now, and each one's signed drift (u/s).
    private(set) var shades: [ShadeState] = []
    private var shadeDrift: [Double] = []
    private var nextID: Int = 1
    private var firstBand: Double? = nil
    private var band: Double = Tuning.bandMin
    private var clock: Double = 0
    private var lastPop: Double = -1_000_000
    private var sweepRun: Int = 0
    private var hintedLight: Bool = false
    private var hintedBrute: Bool = false
    private var hintedFirefly: Bool = false
    private var hintedSplitter: Bool = false
    private var hintedHopper: Bool = false

    /// The full initialiser: `spec` overrides the mode's script (tests, demos). Today's Dawn always uses the day's
    /// seed so everyone gets the same dawn.
    init(mode: PlayMode, spec: LevelSpec?, seed: UInt64) {
        self.mode = mode
        var resolved: LevelSpec? = spec
        var s: UInt64 = seed
        switch mode {
        case .level(let n):
            if resolved == nil { resolved = LevelBook.level(n) }
        case .daily(let day):
            if resolved == nil { resolved = LevelBook.daily(day: day) }
            s = DailySeed.seed(day: day)
        case .endless:
            resolved = nil
        }
        self.spec = resolved
        self.seed = s
        self.duration = resolved?.duration ?? 0
        self.rng = SeededRandom(seed: s)
        self.snapshot = DawnSnapshot(mode: mode, phase: .waiting,
                                     flowers: Array(repeating: true, count: Tuning.flowerCount), band: Tuning.bandMin)
        glooms.reserveCapacity(64)
        fireflies.reserveCapacity(8)
        popped.reserveCapacity(8)
        if let script = resolved {
            expand(script.groups, offset: 0)
            addClouds(script.clouds, offset: 0)
        }
    }

    convenience init(mode: PlayMode, seed: UInt64 = 1) {
        self.init(mode: mode, spec: nil, seed: seed)
    }

    /// A custom script played as level `spec.number` (tests, demos).
    convenience init(spec: LevelSpec, seed: UInt64 = 1) {
        self.init(mode: .level(spec.number), spec: spec, seed: seed)
    }

    /// 5 → 3, 3–4 → 2, 1–2 → 1, 0 → 0.
    /// R3: the stars a sunrise gives: 3 = all five flowers AND `score ≥ starScore` (0 = flowers only); five flowers
    /// below the score = 2; 3–4 = 2; 1–2 = 1; 0 = 0.
    static func stars(flowersLeft: Int, score: Int, starScore: Int) -> Int {
        let byFlowers: Int = stars(flowersLeft: flowersLeft)
        if byFlowers == 3 && score < starScore { return 2 }
        return byFlowers
    }

    /// The flowers-only rule (R1/R2; kept for callers that don't know the score): 5 → 3, 3–4 → 2, 1–2 → 1, 0 → 0.
    static func stars(flowersLeft: Int) -> Int {
        if flowersLeft >= 5 { return 3 }
        if flowersLeft >= 3 { return 2 }
        if flowersLeft >= 1 { return 1 }
        return 0
    }

    /// Spawns still to come.
    var pendingCount: Int { return queue.count - queueIndex }

    // MARK: Step

    /// dt ≤ 1/30 (sub-steps internally ≤ 1/120). dt = 0 is legal (no change, no events).
    func step(dt: Double, input: MirrorInput) -> [GameEvent] {
        if !(dt > 0) || !dt.isFinite || isFinished { return [] }
        let frame: Double = min(dt, 1)
        var events: [GameEvent] = []
        let target: Double = DawnSession.clampBand(input.band)
        if snapshot.phase == .waiting {
            if firstBand == nil { firstBand = target }
            let first: Double = firstBand ?? target
            let starts: Bool = !input.isShut && (target >= 0 || abs(target - first) > Tuning.startNudge)
            if !starts {
                band = target
                publish(input)
                return events
            }
            snapshot.phase = .playing
            events.append(.started)
            if case .endless = mode { startWave(&events) }
        }
        let n: Int = max(1, Int((frame / Tuning.maxSubstep - 1e-9).rounded(.up)))
        let h: Double = frame / Double(n)
        let b0: Double = band
        let lightOn: Bool = !input.isShut
        var k: Int = 1
        while k <= n && snapshot.phase == .playing {
            let b: Double = b0 + (target - b0) * Double(k) / Double(n)
            substep(h, band: b, lightOn: lightOn, events: &events)
            k += 1
        }
        band = target
        publish(input)
        return events
    }

    static func clampBand(_ b: Double) -> Double {
        if !b.isFinite { return Tuning.bandMin }
        return min(max(b, Tuning.bandMin), 1)
    }

    // MARK: Spawning

    private func expand(_ groups: [SpawnGroup], offset: Double) {
        for g in groups {
            let n: Int = max(g.count, 0)
            let lo: Double = g.u.lowerBound
            let hi: Double = g.u.upperBound
            var i: Int = 0
            while i < n {
                var t: Double = g.time + offset
                var u: Double
                switch g.formation {
                case .cluster:
                    u = rng.between(lo, hi)
                case .line:
                    u = lo + (hi - lo) * (Double(i) + 0.5) / Double(n)
                case .stagger(let gap):
                    u = lo + (hi - lo) * (n > 1 ? Double(i) / Double(n - 1) : 0.5)
                    t += max(gap, 0) * Double(i)
                }
                let phase: Double = rng.unit()
                var sd: Double = 0
                if case .gloom = g.kind {
                    sd = g.surface.lowerBound + (g.surface.upperBound - g.surface.lowerBound) * rng.unit()
                }
                u = min(max(u, Tuning.spawnUMin), Tuning.spawnUMax)
                queue.append(PendingSpawn(time: t, kind: g.kind, u: u, speedScale: g.speedScale, phase: phase,
                                          seq: seqCounter, surfaceD: sd))
                seqCounter += 1
                i += 1
            }
        }
        if queueIndex > 0 {
            queue.removeFirst(min(queueIndex, queue.count))
            queueIndex = 0
        }
        queue.sort { (a: PendingSpawn, b: PendingSpawn) -> Bool in
            if a.time != b.time { return a.time < b.time }
            return a.seq < b.seq
        }
    }

    private func startWave(_ events: inout [GameEvent]) {
        wave += 1
        if wave > 1 { events.append(.waveUp(wave)) }
        let groups: [SpawnGroup] = LevelBook.endlessWave(wave, rng: &rng)
        expand(groups, offset: clock)
        let clouds: [CloudSpec] = LevelBook.endlessClouds(wave, rng: &rng)
        addClouds(clouds, offset: clock)
    }

    private func addClouds(_ clouds: [CloudSpec], offset: Double) {
        if clouds.isEmpty { return }
        for c in clouds {
            var shifted: CloudSpec = c
            shifted.time += offset
            cloudQueue.append(PendingCloud(spec: shifted, seq: seqCounter))
            seqCounter += 1
        }
        if cloudIndex > 0 {
            cloudQueue.removeFirst(min(cloudIndex, cloudQueue.count))
            cloudIndex = 0
        }
        cloudQueue.sort { (a: PendingCloud, b: PendingCloud) -> Bool in
            if a.spec.time != b.spec.time { return a.spec.time < b.spec.time }
            return a.seq < b.seq
        }
    }

    /// Clouds arrive just off their edge and drift across; gone once fully past the far edge.
    private func moveClouds(_ h: Double, now: Double) {
        while cloudIndex < cloudQueue.count && cloudQueue[cloudIndex].spec.time <= now {
            let c: CloudSpec = cloudQueue[cloudIndex].spec
            cloudIndex += 1
            let hw: Double = max(c.halfWidth, 0.01)
            shades.append(ShadeState(id: nextID, u: c.fromLeft ? -hw : 1 + hw, halfWidth: hw,
                                     strength: min(max(c.strength, 0), 1)))
            shadeDrift.append(c.fromLeft ? abs(c.speed) : -abs(c.speed))
            nextID += 1
        }
        if shades.isEmpty { return }
        var w: Int = 0
        var r: Int = 0
        let count: Int = shades.count
        while r < count {
            var c: ShadeState = shades[r]
            let v: Double = shadeDrift[r]
            r += 1
            c.u += v * h
            let gone: Bool = v > 0 ? c.u - c.halfWidth > 1.02 : c.u + c.halfWidth < -0.02
            if gone {
                stats.clouds += 1
                continue
            }
            shades[w] = c
            shadeDrift[w] = v
            w += 1
        }
        if w < shades.count {
            shades.removeSubrange(w..<shades.count)
            shadeDrift.removeSubrange(w..<shadeDrift.count)
        }
    }

    private func spawnGloom(_ kind: GloomKind, u: Double, d: Double?, speedScale: Double, flung: Bool,
                            surfaceD: Double = 0, events: inout [GameEvent]) {
        let spec: GloomSpec = GloomSpec.of(kind)
        let scale: Double = max(speedScale, 0.05)
        var g = DawnGloom(id: nextID, kind: kind, u: u, d: d ?? -spec.radius, radius: spec.radius, hp: spec.hp,
                          maxHP: spec.hp, lit: 0, age: 0, tension: flung ? 1 : 0, speed: spec.speed * scale,
                          speedScale: scale, rest: Tuning.hopperRest / scale, timer: 0, hopping: false, hopFrom: 0,
                          fling: flung ? Tuning.splitFlingTime : 0, wasLit: false)
        if !flung && surfaceD > g.d {
            g.submerged = true
            g.surfaceD = surfaceD
        }
        nextID += 1
        glooms.append(g)
        stats.emerged += 1
        events.append(.emerged(id: g.id, kind: kind, u: u))
        if !hintedLight && mode == .level(1) {
            hintedLight = true
            events.append(.hint(.lightTheShadows))
        }
        switch kind {
        case .brute:
            if !hintedBrute {
                hintedBrute = true
                events.append(.hint(.followTheBigOnes))
            }
        case .splitter:
            if !hintedSplitter {
                hintedSplitter = true
                events.append(.hint(.splitters))
            }
        case .hopper:
            if !hintedHopper {
                hintedHopper = true
                events.append(.hint(.hoppers))
            }
        case .murk, .wisp:
            break
        }
    }

    private func spawnFirefly(_ e: PendingSpawn, events: inout [GameEvent]) {
        let f = DawnFirefly(id: nextID, u: e.u, baseU: e.u, d: -Tuning.fireflyRadius, scorchTime: 0, lit: 0, age: 0,
                            speed: Tuning.fireflySpeed * max(e.speedScale, 0.05), phase: e.phase)
        nextID += 1
        fireflies.append(f)
        events.append(.fireflyEmerged(id: f.id, u: f.u))
        if !hintedFirefly {
            hintedFirefly = true
            events.append(.hint(.spareTheFireflies))
        }
    }

    // MARK: One sub-step

    private func substep(_ h: Double, band b: Double, lightOn: Bool, events: inout [GameEvent]) {
        clock += h
        let now: Double = clock
        if case .endless = mode, now >= Double(wave) * Tuning.endlessWaveSeconds {
            startWave(&events)
        }
        while queueIndex < queue.count && queue[queueIndex].time <= now {
            let e: PendingSpawn = queue[queueIndex]
            queueIndex += 1
            switch e.kind {
            case .firefly:
                spawnFirefly(e, events: &events)
            case .gloom(let kind):
                spawnGloom(kind, u: e.u, d: nil, speedScale: e.speedScale, flung: false, surfaceD: e.surfaceD,
                           events: &events)
            }
        }
        moveClouds(h, now: now)
        let clouded: Bool = !shades.isEmpty

        // Glooms: burn, move, pop or eat (compacted in place).
        var w: Int = 0
        var r: Int = 0
        let count: Int = glooms.count
        while r < count {
            var g: DawnGloom = glooms[r]
            r += 1
            if snapshot.phase != .playing {
                glooms[w] = g
                w += 1
                continue
            }
            let raw: Double = lightOn ? Tuning.unshadedIntensity(d: g.d, radius: g.radius, band: b) : 0
            if g.submerged {
                // R3: under the ground: immune, hurrying to its surfacing depth.
                if raw > 0 { stats.submergedBlockedSeconds += raw * h }
                g.lit = 0
                g.wasLit = false
                g.age += h
                g.tension = 0
                g.d += g.speed * Tuning.submergedSpeedFactor * h
                if g.d >= g.surfaceD {
                    g.submerged = false
                    stats.surfaced += 1
                    events.append(.surfaced(id: g.id, kind: g.kind, u: g.u, d: g.d))
                }
                glooms[w] = g
                w += 1
                continue
            }
            let cf: Double = clouded ? Tuning.cloudFactor(u: g.u, shades: shades) : 1
            let inCrease: Bool = Tuning.isShaded(d: g.d)
            let lit: Double = inCrease ? 0 : raw * cf
            if raw > 0 {
                if inCrease {
                    stats.creaseBlockedSeconds += raw * h
                } else {
                    stats.cloudBlockedSeconds += raw * (1 - cf) * h
                    if cf < 0.5 && !g.clouded {
                        g.clouded = true
                        stats.cloudedGlooms += 1
                    }
                }
            }
            g.lit = lit
            g.hp -= lit * h * Tuning.burnRate
            if g.kind == .hopper {
                if !g.hopping {
                    if lit > 0 && !g.wasLit {
                        g.hopping = true
                        g.timer = 0
                        g.hopFrom = g.d
                        stats.hops += 1
                        events.append(.hopped(id: g.id, u: g.u, d: g.d, skittish: true))
                    } else {
                        g.timer += h * (1 + Tuning.hopperLitHurry * lit)
                        if g.timer >= g.rest {
                            g.hopping = true
                            g.timer = 0
                            g.hopFrom = g.d
                            stats.hops += 1
                            events.append(.hopped(id: g.id, u: g.u, d: g.d, skittish: false))
                        }
                    }
                    g.tension = g.hopping ? 0 : min(g.timer / max(g.rest, 1e-6), 1)
                } else {
                    g.timer += h
                    let f: Double = min(g.timer / Tuning.hopperHopTime, 1)
                    g.d = g.hopFrom + Tuning.hopperHop * Tuning.smoothstep(f)
                    g.tension = 0
                    if f >= 1 {
                        g.hopping = false
                        g.timer = 0
                    }
                }
            } else if g.fling > 0 {
                g.d += Tuning.splitFlingSpeed * h
                g.fling -= h
                g.tension = g.fling > 0 ? 1 : 0
            } else {
                g.d += g.speed * h
            }
            g.wasLit = lit > 0
            g.age += h
            if g.hp <= 0 {
                pop(g, events: &events)
                if g.kind == .splitter { popped.append(g) }
                continue
            }
            if g.d >= 1 {
                eat(g, events: &events)
                continue
            }
            glooms[w] = g
            w += 1
        }
        if w < glooms.count { glooms.removeSubrange(w..<glooms.count) }
        if snapshot.phase != .playing {
            popped.removeAll(keepingCapacity: true)
            return
        }

        // Splitters' wisps.
        if !popped.isEmpty {
            for p in popped {
                stats.splits += 1
                events.append(.split(u: p.u, d: p.d))
                let n: Int = Tuning.splitWispCount
                var i: Int = 0
                while i < n {
                    let side: Double = n > 1 ? (2 * Double(i) / Double(n - 1) - 1) : 0
                    let u: Double = min(max(p.u + side * Tuning.splitSpreadU, Tuning.spawnUMin), Tuning.spawnUMax)
                    spawnGloom(.wisp, u: u, d: p.d + Tuning.splitFling, speedScale: p.speedScale, flung: true,
                               events: &events)
                    i += 1
                }
            }
            popped.removeAll(keepingCapacity: true)
        }

        // Fireflies: scorch, drift, fizzle or deliver.
        w = 0
        r = 0
        let fcount: Int = fireflies.count
        while r < fcount {
            var f: DawnFirefly = fireflies[r]
            r += 1
            var lit: Double = lightOn ? Tuning.intensity(d: f.d, radius: Tuning.fireflyRadius, band: b) : 0
            if clouded && lit > 0 { lit *= Tuning.cloudFactor(u: f.u, shades: shades) }
            f.lit = lit
            if lit > 0 {
                f.scorchTime += lit * h
            } else {
                f.scorchTime = max(0, f.scorchTime - Tuning.fireflyScorchDecay * h)
            }
            f.d += f.speed * h
            f.age += h
            let drift: Double = Tuning.fireflyWaveAmplitude
                * sin(2 * Double.pi * (f.age * Tuning.fireflyWaveFrequency + f.phase))
            f.u = min(max(f.baseU + drift, Tuning.spawnUMin), Tuning.spawnUMax)
            if f.scorchTime >= Tuning.fireflyScorchLimit {
                stats.firefliesScorched += 1
                events.append(.fireflyScorched(id: f.id, u: f.u, d: f.d))
                breakChain(&events)
                continue
            }
            if f.d >= 1 {
                deliver(f, events: &events)
                continue
            }
            fireflies[w] = f
            w += 1
        }
        if w < fireflies.count { fireflies.removeSubrange(w..<fireflies.count) }

        // The chain times out quietly.
        if snapshot.chain > 0 && now - lastPop > Tuning.chainWindow {
            events.append(.chainEnded(was: snapshot.chain))
            snapshot.chain = 0
            sweepRun = 0
        }

        // Sunrise.
        if duration > 0 && now >= duration {
            sunrise(&events)
        }
    }

    // MARK: Outcomes

    private func pop(_ g: DawnGloom, events: inout [GameEvent]) {
        let now: Double = clock
        let chain: Int = (snapshot.chain > 0 && now - lastPop <= Tuning.chainWindow) ? snapshot.chain + 1 : 1
        sweepRun = (sweepRun > 0 && now - lastPop <= Tuning.sweepWindow) ? sweepRun + 1 : 1
        lastPop = now
        snapshot.chain = chain
        let base: Double = Double(GloomSpec.of(g.kind).points)
        let points: Int = Int((base * Tuning.multiplier(chain: chain)).rounded())
        snapshot.score += points
        snapshot.pops += 1
        stats.pops += 1
        stats.longestChain = max(stats.longestChain, chain)
        stats.popsBy[g.kind, default: 0] += 1
        if g.kind == .brute { stats.brutesPopped += 1 }
        events.append(.popped(id: g.id, kind: g.kind, u: g.u, d: g.d, chain: chain, points: points))
        if sweepRun >= Tuning.sweepMinimum {
            let bonus: Int = sweepRun == Tuning.sweepMinimum
                ? Tuning.sweepBonusPerPop * Tuning.sweepMinimum : Tuning.sweepBonusPerPop
            if sweepRun == Tuning.sweepMinimum { stats.sweeps += 1 }
            stats.bestSweep = max(stats.bestSweep, sweepRun)
            snapshot.score += bonus
            events.append(.swept(count: sweepRun, bonus: bonus))
        }
    }

    private func breakChain(_ events: inout [GameEvent]) {
        if snapshot.chain > 0 { events.append(.chainBroken(was: snapshot.chain)) }
        snapshot.chain = 0
        sweepRun = 0
    }

    private var flowersLeft: Int {
        var n: Int = 0
        for f in snapshot.flowers where f { n += 1 }
        return n
    }

    /// The nearest lane to `lane` whose flower is `standing` (left first on a tie), or −1.
    private func nearest(to lane: Int, standing: Bool) -> Int {
        let n: Int = snapshot.flowers.count
        var k: Int = 1
        while k < n {
            let left: Int = lane - k
            if left >= 0 && left < n && snapshot.flowers[left] == standing { return left }
            let right: Int = lane + k
            if right >= 0 && right < n && snapshot.flowers[right] == standing { return right }
            k += 1
        }
        return -1
    }

    private func eat(_ g: DawnGloom, events: inout [GameEvent]) {
        var lane: Int = Tuning.lane(u: g.u)
        if lane >= snapshot.flowers.count { return }
        if !snapshot.flowers[lane] { lane = nearest(to: lane, standing: true) }
        if lane < 0 { return }
        snapshot.flowers[lane] = false
        stats.flowersEaten += 1
        stats.flowersEatenBy[g.kind, default: 0] += 1
        if g.clouded { stats.eatenAfterCloud += 1 }
        let left: Int = flowersLeft
        events.append(.flowerEaten(lane: lane, flowersLeft: left, by: g.kind))
        breakChain(&events)
        if left == 0 {
            snapshot.phase = .lost
            events.append(.nightWins)
        }
    }

    private func deliver(_ f: DawnFirefly, events: inout [GameEvent]) {
        stats.firefliesDelivered += 1
        var lane: Int = Tuning.lane(u: f.u)
        if lane >= snapshot.flowers.count { return }
        if flowersLeft < snapshot.flowers.count {
            if snapshot.flowers[lane] { lane = nearest(to: lane, standing: false) }
            if lane >= 0 {
                snapshot.flowers[lane] = true
                stats.flowersReplanted += 1
                events.append(.fireflyDelivered(id: f.id, lane: lane, replanted: true, points: 0))
            }
        } else {
            snapshot.score += Tuning.fireflyBloomPoints
            events.append(.fireflyDelivered(id: f.id, lane: lane, replanted: false, points: Tuning.fireflyBloomPoints))
        }
    }

    private func sunrise(_ events: inout [GameEvent]) {
        let left: Int = flowersLeft
        let bonus: Int = Tuning.flowerBonus * left
        snapshot.score += bonus
        glooms.removeAll(keepingCapacity: true)
        fireflies.removeAll(keepingCapacity: true)
        shades.removeAll(keepingCapacity: true)
        shadeDrift.removeAll(keepingCapacity: true)
        snapshot.phase = left > 0 ? .won : .lost
        var stars: Int = DawnSession.stars(flowersLeft: left, score: snapshot.score, starScore: spec?.starScore ?? 0)
        if case .daily = mode { stars = 0 }
        events.append(.sunrise(stars: stars, flowerBonus: bonus))
    }

    // MARK: Snapshot

    private func publish(_ input: MirrorInput) {
        snapshot.glooms.removeAll(keepingCapacity: true)
        var burn: Double = 0
        var litCount: Int = 0
        var danger: Double = 0
        for g in glooms {
            snapshot.glooms.append(g.state)
            if g.lit > 0 {
                burn += g.lit * Tuning.burnRate
                litCount += 1
            }
            danger = max(danger, g.d)
        }
        snapshot.fireflies.removeAll(keepingCapacity: true)
        var ffDanger: Double = 0
        for f in fireflies {
            let s: FireflyState = f.state
            snapshot.fireflies.append(s)
            if f.lit > 0 { ffDanger = max(ffDanger, s.scorch) }
        }
        if snapshot.shades != shades { snapshot.shades = shades }
        stats.score = snapshot.score
        snapshot.band = band
        snapshot.creaseGlow = min(max(input.creaseGlow, 0), 1)
        snapshot.time = clock
        if duration > 0 {
            snapshot.sun = min(max(clock / duration, 0), 1)
        } else {
            snapshot.sun = min(max(clock / Tuning.endlessSunSeconds, 0), 1)
        }
        snapshot.multiplier = Tuning.multiplier(chain: snapshot.chain)
        var t = Telemetry()
        t.burnRate = burn
        t.litCount = litCount
        t.fireflyDanger = ffDanger
        t.danger = max(danger, 0)
        t.bandSpeed = input.bandSpeed
        snapshot.telemetry = t
    }
}
