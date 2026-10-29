import Foundation

// MARK: - The autopilot (attract mode, CI screenshots, balance tests). Pure: no clock, no globals, no system RNG.
//
// It plays like a person holding the phone:
// - Every `reaction` seconds (0.35 s at skill 0 → 0.08 s at skill 1) it picks the most urgent gloom: the least slack,
//   where slack = seconds until it reaches the flowers − the light it still needs − the trip to it. Crowds count as
//   more urgent (one sweep pops them all), splitters as further along (their wisps fly 0.25 out), a gloom under a
//   cloud's shadow as less urgent (R2: wait for the cloud, take someone else), and a gloom that can no longer be saved
//   is let go. A lit target is kept (tracked) until it pops, unless something is clearly worse.
// - It aims at the target plus a lead (a resting hopper: on it or just ahead; a hopping one: where it lands), never
//   inside the crease shade (R2: no light there), steps the aim off any firefly near the open garden (to the nearest
//   spot that leaves every firefly dark) unless the target is past d = 0.6, and moves its hand there with a soft lag
//   and a speed cap (0.9 → 1.6 d/s).
// - Lower skill: wider aim error, more slips (picking the wrong gloom) and hesitations (freezing for a moment).
// - R2, the human hinge, all scaled by (1 − skill): the band follows the hand through a 0.1 + 0.25 × (1 − skill) s lag
//   (a hinge's filtered angle trails the hand), plus a smooth ±0.05 jitter (hinge noise, redrawn every 0.12 s), and
//   on a big move (> 0.15 d) to a new target it sometimes overshoots by 0.04…0.12 d, settling over ~0.2 s.

struct PilotBrain {
    let skill: Double
    /// Seconds between decisions.
    let reaction: Double
    /// d units per second (the hand).
    let speedCap: Double
    /// The aim error's half-range (d).
    let aimNoise: Double
    /// Chance a decision picks a random gloom.
    let slip: Double
    /// Hesitations per second.
    let hesitation: Double
    /// How much more urgent (seconds of slack) another gloom must be before it abandons a lit target.
    let switchMargin: Double
    /// How far (d) it keeps the band centre from a firefly (R4: 0.17 − 0.04 × skill; an unsure hand gives them more
    /// room, which is how it learns to skip them).
    let fireflyMargin: Double
    /// R2 human hinge: the jitter's half-range (d), the hinge lag (s) and the overshoot chance per big move.
    let jitterAmplitude: Double
    let hingeLag: Double
    let overshootChance: Double

    /// Where it rests the band with nothing to chase (just past the crease shade, where shadows surface).
    static let idleAim: Double = Tuning.creaseShade + 0.08
    /// It never aims closer to the crease than this (light does nothing in the shade).
    static let minAim: Double = Tuning.creaseShade + 0.05
    /// Past this d a target matters more than a firefly.
    static let carelessD: Double = 0.85
    /// The hand closes the gap to its goal at gap / this per second (then capped).
    static let gainDistance: Double = 0.06
    /// Below this cloud factor a gloom counts as shaded (less urgent).
    static let shadedFactor: Double = 0.6
    /// Seconds of slack a fully shaded gloom gets added.
    static let shadePenalty: Double = 2.5

    private var rng: SeededRandom
    /// The band it shows now (what the session sees).
    private(set) var position: Double = Tuning.bandMin
    /// The gloom it is chasing (−1: none).
    private(set) var targetID: Int = -1
    /// The hand (before the hinge lag and jitter).
    private(set) var hand: Double = Tuning.bandMin
    private var lagged: Double = Tuning.bandMin
    private var goal: Double = 0.2
    private var decideIn: Double = 0
    private var freeze: Double = 0
    private var aimError: Double = 0
    private var errorIn: Double = 0
    private var jitter: Double = 0
    private var jitterTarget: Double = 0
    private var jitterIn: Double = 0
    private var overshoot: Double = 0

    /// skill 0…1 (1 = near-perfect).
    init(skill: Double, seed: UInt64) {
        let s: Double = skill.isFinite ? min(max(skill, 0), 1) : 0.5
        let w: Double = 1 - s
        self.skill = s
        self.reaction = 0.35 - 0.27 * s
        self.speedCap = 0.9 + 0.7 * s
        self.aimNoise = 0.005 + 0.08 * w
        self.slip = 0.4 * w
        self.hesitation = 0.5 * w
        self.switchMargin = 0.8 - 0.5 * s
        self.fireflyMargin = 0.17 - 0.04 * s
        self.jitterAmplitude = 0.05 * w
        self.hingeLag = 0.1 + 0.25 * w
        self.overshootChance = 0.6 * w
        self.rng = SeededRandom(seed: seed)
    }

    /// The band position it wants this frame, given the last snapshot. Moves with the hinge's speed limits
    /// (≤ 1.6 d/s, reaction delay by skill), so it plays like a person.
    mutating func band(for snapshot: DawnSnapshot, dt: Double) -> Double {
        if !(dt > 0) || !dt.isFinite { return position }
        let s: Double = skill
        errorIn -= dt
        if errorIn <= 0 {
            errorIn = 0.3 + 0.5 * rng.unit()
            aimError = aimNoise * (2 * rng.unit() - 1)
        }
        jitterIn -= dt
        if jitterIn <= 0 {
            jitterIn = 0.12
            jitterTarget = jitterAmplitude * (2 * rng.unit() - 1)
        }
        jitter += (jitterTarget - jitter) * min(1, dt / 0.06)
        overshoot *= exp(-dt / 0.2)
        if freeze > 0 {
            freeze -= dt
            return output(dt)
        }
        if rng.unit() < hesitation * dt {
            freeze = 0.2 + 0.6 * (1 - s) * rng.unit()
            return output(dt)
        }

        let gl: [GloomState] = snapshot.glooms
        let sh: [ShadeState] = snapshot.shades
        var tgIndex: Int = -1
        if targetID >= 0 {
            var i: Int = 0
            while i < gl.count {
                if gl[i].id == targetID {
                    tgIndex = i
                    break
                }
                i += 1
            }
        }
        decideIn -= dt
        if tgIndex < 0 && decideIn > reaction { decideIn = reaction }
        if decideIn <= 0 {
            decideIn = reaction
            var best: Int = -1
            var bestUrgency: Double = -1e9
            var i: Int = 0
            while i < gl.count {
                let u: Double = urgency(gl[i], in: gl, shades: sh)
                if u > bestUrgency {
                    bestUrgency = u
                    best = i
                }
                i += 1
            }
            if gl.count > 1 && rng.unit() < slip {
                best = rng.int(0...(gl.count - 1))
            }
            if best >= 0 && tgIndex >= 0 && gl[tgIndex].lit > 0.3 && gl[best].id != gl[tgIndex].id {
                if urgency(gl[best], in: gl, shades: sh) < urgency(gl[tgIndex], in: gl, shades: sh) + switchMargin {
                    best = tgIndex
                }
            }
            let newID: Int = best >= 0 ? gl[best].id : -1
            if best >= 0 && newID != targetID {
                let jump: Double = max(PilotBrain.reachD(gl[best]), Tuning.creaseShade) - hand
                let roll: Double = rng.unit()
                if abs(jump) > 0.15 && roll < overshootChance {
                    let size: Double = (0.04 + 0.08 * rng.unit()) * (1 - s)
                    overshoot = jump > 0 ? size : -size
                }
            }
            targetID = newID
            tgIndex = best
        }

        var aim: Double = PilotBrain.idleAim
        var careless: Bool = false
        if tgIndex >= 0 {
            let tg: GloomState = gl[tgIndex]
            if tg.submerged {
                // R3: wait where it will surface.
                aim = tg.surfaceD + PilotBrain.speed(of: tg) * (reaction + 0.05) * s
            } else if tg.kind == .hopper {
                aim = tg.tension < 0.02 ? tg.d + 0.06 : tg.d + 0.02 + 0.03 * s
            } else {
                aim = tg.d + PilotBrain.speed(of: tg) * (reaction + 0.05) * s
            }
            aim = max(aim, PilotBrain.minAim)
            careless = tg.d > PilotBrain.carelessD
        }
        aim += aimError + overshoot

        let ff: [FireflyState] = snapshot.fireflies
        if !careless && !ff.isEmpty {
            let m: Double = fireflyMargin
            let watchFrom: Double = Tuning.creaseShade - 0.1
            var bestAim: Double = aim
            var bestCost: Double = 1e9
            var c: Int = -1
            while c < 2 * ff.count {
                var cand: Double = aim
                if c >= 0 {
                    let side: Double = c % 2 == 0 ? -m : m
                    cand = ff[c / 2].d + side * 1.0001
                }
                var ok: Bool = true
                for q in ff where q.d > watchFrom && abs(cand - q.d) < m {
                    ok = false
                    break
                }
                if ok {
                    let cost: Double = abs(cand - aim)
                    if cost < bestCost {
                        bestCost = cost
                        bestAim = cand
                    }
                }
                c += 1
            }
            aim = bestAim
        }

        aim = min(max(aim, Tuning.bandMin), 1)
        goal += (aim - goal) * min(1, dt / (0.5 * reaction))
        var v: Double = (goal - hand) / PilotBrain.gainDistance
        v = min(max(v, -speedCap), speedCap)
        hand = min(max(hand + v * dt, Tuning.bandMin), 1)
        return output(dt)
    }

    /// The hinge: the band follows the hand through the lag, plus the jitter.
    private mutating func output(_ dt: Double) -> Double {
        lagged += (hand - lagged) * min(1, dt / hingeLag)
        position = min(max(lagged + jitter, Tuning.bandMin), 1)
        return position
    }

    /// The whole `MirrorInput` for this frame (band, the matching crease glow, the band speed). Never shut.
    mutating func input(for snapshot: DawnSnapshot, dt: Double) -> MirrorInput {
        let before: Double = position
        let b: Double = band(for: snapshot, dt: dt)
        let speed: Double = dt > 0 ? (b - before) / dt : 0
        return MirrorInput(band: b, creaseGlow: Tuning.creaseGlow(band: b), isShut: false, bandSpeed: speed)
    }

    /// −(seconds of slack): bigger is more urgent.
    func urgency(_ g: GloomState, in glooms: [GloomState], shades: [ShadeState] = []) -> Double {
        let sp: Double = max(PilotBrain.speed(of: g), 0.02)
        let ahead: Double = g.kind == .splitter ? 0.25 : 0
        let dEff: Double = PilotBrain.reachD(g)
        let under: Double = g.submerged ? max(g.surfaceD - g.d, 0) / (sp * Tuning.submergedSpeedFactor) : 0
        let arrive: Double = (1 - dEff - ahead) / sp + under
        let trip: Double = abs(lagged - max(dEff, Tuning.creaseShade)) / speedCap
        let raw: Double = arrive - g.hp - trip
        var slack: Double = raw
        var near: Int = 0
        for o in glooms where o.id != g.id && abs(o.d - g.d) < 0.06 {
            near += 1
        }
        slack -= 0.25 * Double(min(near, 4))
        if !shades.isEmpty {
            let cf: Double = Tuning.cloudFactor(u: g.u, shades: shades)
            if cf < PilotBrain.shadedFactor { slack += PilotBrain.shadePenalty * (1 - cf) }
        }
        if raw < -0.3 { slack += 8 }
        return -slack
    }

    /// R3: where a gloom can first be lit: its surfacing depth while submerged, else where it is.
    static func reachD(_ g: GloomState) -> Double {
        return g.submerged ? g.surfaceD : g.d
    }

    /// The speed it expects of a gloom (it can't see a group's speed scale): a flung wisp flies at the fling speed.
    static func speed(of g: GloomState) -> Double {
        if g.kind == .wisp && g.tension >= 1 { return Tuning.splitFlingSpeed }
        return GloomSpec.of(g.kind).speed
    }
}
