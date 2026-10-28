import Foundation

// MARK: - The autopilot (attract mode, CI screenshots, balance tests). Pure: no clock, no globals, no system RNG.
//
// It plays like a person holding the phone:
// - Every `reaction` seconds (0.35 s at skill 0 → 0.08 s at skill 1) it picks the most urgent gloom: the least slack,
//   where slack = seconds until it reaches the flowers − the light it still needs − the trip to it. Crowds count as
//   more urgent (one sweep pops them all), splitters as further along (their wisps fly 0.25 out), and a gloom that can
//   no longer be saved is let go. A lit target is kept (tracked) until it pops, unless something is clearly worse.
// - It aims at the target plus a lead (a resting hopper: on it or just ahead; a hopping one: where it lands), steps
//   the aim off any
//   firefly (to the nearest spot that leaves every firefly dark) unless the target is past d = 0.6, and moves there
//   with a soft lag and a speed cap (0.9 → 1.6 d/s).
// - Lower skill: wider aim error, more slips (picking the wrong gloom), and hesitations (freezing for a moment).

struct PilotBrain {
    let skill: Double
    /// Seconds between decisions.
    let reaction: Double
    /// d units per second.
    let speedCap: Double
    /// The aim error's half-range (d).
    let aimNoise: Double
    /// Chance a decision picks a random gloom.
    let slip: Double
    /// Hesitations per second.
    let hesitation: Double
    /// How much more urgent (seconds of slack) another gloom must be before it abandons a lit target.
    let switchMargin: Double
    /// How far (d) it keeps the band centre from a firefly.
    let fireflyMargin: Double

    /// Where it rests the band with nothing to chase (just out of the crease, where shadows appear).
    static let idleAim: Double = 0.06
    /// Past this d a target matters more than a firefly.
    static let carelessD: Double = 0.6
    /// The band closes the gap to its goal at gap / this per second (then capped).
    static let gainDistance: Double = 0.06

    private var rng: SeededRandom
    /// The band it is holding now.
    private(set) var position: Double = Tuning.bandMin
    /// The gloom it is chasing (−1: none).
    private(set) var targetID: Int = -1
    private var goal: Double = PilotBrain.idleAim
    private var decideIn: Double = 0
    private var freeze: Double = 0
    private var aimError: Double = 0
    private var errorIn: Double = 0

    /// skill 0…1 (1 = near-perfect).
    init(skill: Double, seed: UInt64) {
        let s: Double = skill.isFinite ? min(max(skill, 0), 1) : 0.5
        self.skill = s
        self.reaction = 0.35 - 0.27 * s
        self.speedCap = 0.9 + 0.7 * s
        self.aimNoise = 0.005 + 0.15 * (1 - s)
        self.slip = 0.6 * (1 - s)
        self.hesitation = 0.5 * (1 - s)
        self.switchMargin = 0.8 - 0.5 * s
        self.fireflyMargin = 0.097 + 0.035 * s
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
        if freeze > 0 {
            freeze -= dt
            return position
        }
        if rng.unit() < hesitation * dt {
            freeze = 0.2 + 0.6 * (1 - s) * rng.unit()
            return position
        }

        let gl: [GloomState] = snapshot.glooms
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
                let u: Double = urgency(gl[i], in: gl)
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
                if urgency(gl[best], in: gl) < urgency(gl[tgIndex], in: gl) + switchMargin { best = tgIndex }
            }
            targetID = best >= 0 ? gl[best].id : -1
            tgIndex = best
        }

        var aim: Double = PilotBrain.idleAim
        var careless: Bool = false
        if tgIndex >= 0 {
            let tg: GloomState = gl[tgIndex]
            if tg.kind == .hopper {
                aim = tg.tension < 0.02 ? tg.d + 0.06 : tg.d + 0.02 + 0.03 * s
            } else {
                aim = tg.d + PilotBrain.speed(of: tg) * (reaction + 0.05) * s
            }
            careless = tg.d > PilotBrain.carelessD
        }
        aim += aimError

        let ff: [FireflyState] = snapshot.fireflies
        if !careless && !ff.isEmpty {
            let m: Double = fireflyMargin
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
                for q in ff where abs(cand - q.d) < m {
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
        var v: Double = (goal - position) / PilotBrain.gainDistance
        v = min(max(v, -speedCap), speedCap)
        position = min(max(position + v * dt, Tuning.bandMin), 1)
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
    func urgency(_ g: GloomState, in glooms: [GloomState]) -> Double {
        let sp: Double = max(PilotBrain.speed(of: g), 0.02)
        let ahead: Double = g.kind == .splitter ? 0.25 : 0
        let arrive: Double = (1 - g.d - ahead) / sp
        let trip: Double = abs(position - g.d) / speedCap
        let raw: Double = arrive - g.hp - trip
        var slack: Double = raw
        var near: Int = 0
        for o in glooms where o.id != g.id && abs(o.d - g.d) < 0.06 {
            near += 1
        }
        slack -= 0.25 * Double(min(near, 4))
        if raw < -0.3 { slack += 8 }
        return -slack
    }

    /// The speed it expects of a gloom (it can't see a group's speed scale): a flung wisp flies at the fling speed.
    static func speed(of g: GloomState) -> Double {
        if g.kind == .wisp && g.tension >= 1 { return Tuning.splitFlingSpeed }
        return GloomSpec.of(g.kind).speed
    }
}
