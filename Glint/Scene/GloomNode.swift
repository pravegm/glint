import SpriteKit
import UIKit

/// How a gloom leaves when it vanishes from the snapshot without a pop.
enum GloomDeath: Equatable {
    case none
    /// Sunrise: it steams away upwards.
    case evaporate
    /// It reached the flowers: it dives into the eaten flower.
    case eaten
    /// Anything else (a new phase, an unannounced removal).
    case fade
    /// R2: a brute popping: a two-frame white squash (hit-stop feel) over its burst.
    case squash
}

/// One shadow on the lawn: an upright puppet (body, lit rim, eyes, pupils, squeeze, mouth, brow) plus a contact
/// shadow in the scene's shadow layer. Pooled: the scene reconfigures a node for each new gloom.
@MainActor
final class GloomNode {
    static let hopTime: CGFloat = 0.22

    let root = SKNode()
    /// The contact shadow (the scene parents it in its shadow layer, under every gloom).
    let shadow = SKSpriteNode()
    private let puppet = SKNode()
    private let body = SKSpriteNode()
    private let lit = SKSpriteNode()
    private let eyes = SKSpriteNode()
    private let pupils = SKSpriteNode()
    private let squeeze = SKSpriteNode()
    private let mouth = SKSpriteNode()
    private let brow = SKSpriteNode()
    /// R2: the dark seam a gloom in the crease shade sits in (over its lower half).
    private let pool = SKSpriteNode()

    /// R2: 1 = sunk in the crease shade (lower half hidden, eyes peeking), 0 = out in the garden.
    private(set) var sink: CGFloat = 0
    private var wasSunk = false
    private var fresh = true
    /// It came up out of the shade this frame (the scene adds a ripple).
    private(set) var surfacedThisFrame = false
    /// Where the seam's surface is drawn (scene points).
    private(set) var surfacePoint: CGPoint = .zero
    /// Where it looks (scene unit vector, as passed: towards the band).
    private(set) var lookDir = CGVector(dx: 0, dy: -1)

    var isSubmerged: Bool { sink > 0.5 }

    private(set) var kind: GloomKind = .murk
    private(set) var id: Int = -1
    /// The scene's frame stamp when this gloom was last in a snapshot.
    var seenFrame: Int = -1
    private(set) var look: GloomLook = GloomLook.of(.murk)
    private var mouthClosed: SKTexture?
    private var mouthOpen: SKTexture?
    private var mouthOpenShown = false
    private var rng = GardenRNG(seed: 1)
    private var phase: CGFloat = 0
    private var blinkWait: CGFloat = 2
    private var blinkLeft: CGFloat = 0
    private var hopLeft: CGFloat = 0
    private(set) var death: GloomDeath = .none
    private var deathLeft: CGFloat = 0
    private var deathTotal: CGFloat = 1
    private var deathFrom: CGPoint = .zero
    private var deathTarget: CGPoint = .zero
    private var scaleNow: CGFloat = 1
    /// The light on it as drawn (smoothed: fast in, slower out).
    private(set) var shownLit: CGFloat = 0
    private(set) var radiusPts: CGFloat = 10
    /// Where its body is drawn (scene points, hop lift included).
    private(set) var drawnPoint: CGPoint = .zero
    private(set) var lastU: Double = 0
    private(set) var lastD: Double = 0
    private(set) var tension: CGFloat = 0
    var steamClock: CGFloat = 0
    var emberClock: CGFloat = 0
    var trailClock: CGFloat = 0

    /// The eyes are squeezed shut ("> <") this frame.
    var isSqueezing: Bool { !squeeze.isHidden }
    var isHopping: Bool { hopLeft > 0 }

    init() {
        shadow.texture = GardenArt.shadow
        shadow.color = GardenInk(hex: 0x02040A).ui
        shadow.colorBlendFactor = 1
        shadow.size = CGSize(width: 20, height: 8)

        lit.blendMode = .add
        lit.colorBlendFactor = 1
        lit.color = GardenPalette.gold.ui
        brow.isHidden = true

        // Explicit z inside the puppet, so the stacking holds even when the view ignores sibling order.
        body.zPosition = 0.0
        lit.zPosition = 0.05
        mouth.zPosition = 0.1
        eyes.zPosition = 0.15
        pupils.zPosition = 0.2
        squeeze.zPosition = 0.2
        brow.zPosition = 0.25
        root.addChild(puppet)
        for n in [body, lit, mouth, eyes, pupils, squeeze, brow] { puppet.addChild(n) }
        pool.texture = CreatureArt.pool
        pool.anchorPoint = CGPoint(x: 0.5, y: CreatureArt.poolSurface / CreatureArt.poolSize.height)
        pool.zPosition = 0.4
        pool.isHidden = true
        root.addChild(pool)
        configure(kind: .murk, id: -1)
    }

    /// Dresses the node for a new gloom.
    func configure(kind k: GloomKind, id i: Int) {
        id = i
        kind = k
        look = GloomLook.of(k)
        let size = CGSize(width: look.canvas.width, height: look.canvas.height)
        let layers: [(SKSpriteNode, GloomLayer)] = [(body, .body), (lit, .lit), (eyes, .eyes), (pupils, .pupils),
                                                     (squeeze, .squeeze), (mouth, .mouth), (brow, .brow)]
        for (node, layer) in layers {
            node.texture = CreatureArt.gloom(k, layer)
            node.size = size
            node.anchorPoint = look.anchor
            node.position = .zero
            node.setScale(1)
        }
        mouthClosed = CreatureArt.gloom(k, .mouth)
        mouthOpen = CreatureArt.gloom(k, .mouthOpen)
        mouthOpenShown = false
        brow.isHidden = !look.hasBrow
        squeeze.isHidden = true
        eyes.isHidden = false
        pupils.isHidden = false
        rng = GardenRNG(seed: UInt64(bitPattern: Int64(i)) &+ 0x6100)
        phase = rng.range(0, 2 * CGFloat.pi)
        blinkWait = rng.range(0.8, 3.2)
        blinkLeft = 0
        hopLeft = 0
        death = .none
        deathLeft = 0
        shownLit = 0
        lit.alpha = 0
        steamClock = 0
        emberClock = 0
        trailClock = 0
        tension = 0
        root.alpha = 1
        root.isHidden = false
        shadow.alpha = 0.42
        shadow.isHidden = false
        puppet.zRotation = 0
        puppet.position = .zero
        sink = 0
        wasSunk = false
        fresh = true
        surfacedThisFrame = false
        pool.isHidden = true
    }

    /// A hop starts (Core moves the gloom; the node adds the arc).
    func hop() { hopLeft = GloomNode.hopTime }

    /// Draws the gloom from its state at scene point `p`. `dir`: where it looks (scene unit vector). `motion` 0…1.
    func update(_ g: GloomState, at p: CGPoint, radius r: CGFloat, dir: CGVector, dt: CGFloat, time: CGFloat,
                motion: CGFloat) {
        lastU = g.u
        lastD = g.d
        radiusPts = r
        let litTarget = CGFloat(GardenMath.clamp(g.lit, 0, 1))
        shownLit = GardenMath.approach(shownLit, litTarget, rate: litTarget > shownLit ? 30 : 6, dt: dt)
        if shownLit < 0.002 { shownLit = 0 }
        tension = CGFloat(GardenMath.clamp(g.tension, 0, 1))
        lookDir = dir

        // R2: sunk in the crease shade, or out in the open.
        sink = GardenMath.sink(d: g.d)
        let sunkNow = sink > 0.5
        surfacedThisFrame = !fresh && wasSunk && !sunkNow
        wasSunk = sunkNow
        fresh = false

        // Blinks (more often while peeking out of the seam).
        if blinkLeft > 0 {
            blinkLeft = max(0, blinkLeft - dt)
        } else {
            blinkWait -= dt * (1 + sink)
            if blinkWait <= 0 {
                blinkLeft = 0.14
                blinkWait = rng.range(1.6, 4.4)
            }
        }
        let blink: CGFloat = blinkLeft > 0 ? max(0.08, abs(blinkLeft / 0.14 * 2 - 1)) : 1

        // Size: shrinks as it burns; pops in as it emerges.
        let hpFrac: CGFloat = g.maxHP > 0 ? CGFloat(GardenMath.clamp(g.hp / g.maxHP, 0, 1)) : 1
        let hpScale: CGFloat = 0.62 + 0.38 * hpFrac
        let age = CGFloat(max(g.age, 0))
        let grow: CGFloat = age < 0.4 ? 0.7 + 0.3 * GardenMath.easeOutBack(age / 0.4) : 1

        // Breathing squash, crouch, hop.
        let freq: CGFloat = kind == .wisp ? 7.5 : 4.2
        let w = sin(time * freq + phase) * 0.05 * motion
        var sx: CGFloat = 1 + w
        var sy: CGFloat = 1 - w
        var lift: CGFloat = 0
        if kind == .hopper {
            sy *= 1 - 0.24 * tension
            sx *= 1 + 0.12 * tension
        }
        if hopLeft > 0 {
            hopLeft = max(0, hopLeft - dt)
            let k = 1 - hopLeft / GloomNode.hopTime
            let arc = sin(k * CGFloat.pi)
            lift = arc * 0.75
            sy *= 1 + 0.12 * arc
            sx *= 1 - 0.06 * arc
        }
        if kind == .wisp && tension > 0.5 {
            sx *= 0.88
            sy *= 1.14
        }
        if shownLit > 0.05 {
            // Wince: a squeeze down and out in the light.
            sy *= 1 - 0.06 * shownLit
            sx *= 1 + 0.04 * shownLit
        }
        let s = r * hpScale * grow
        scaleNow = s
        puppet.xScale = s * sx
        puppet.yScale = s * sy
        let crouch: CGFloat = kind == .hopper ? 0.1 * tension : 0
        puppet.position = CGPoint(x: 0, y: (lift - crouch - 0.1 * sink) * r)
        // The seam: its surface rises to just under the eyes as the gloom sinks.
        if sink > 0.005 {
            let top = GardenMath.lerp(-1.3, -0.04, sink) * s
            let pw = 3.0 * s
            pool.isHidden = false
            pool.size = CGSize(width: pw, height: pw * CreatureArt.poolSize.height / CreatureArt.poolSize.width)
            pool.position = CGPoint(x: 0, y: top)
            pool.alpha = GardenMath.smooth(0, 0.3, sink)
            surfacePoint = CGPoint(x: p.x, y: p.y + top)
        } else {
            pool.isHidden = true
            surfacePoint = CGPoint(x: p.x, y: p.y - 0.04 * s)
        }
        puppet.zRotation = sin(time * 1.7 + phase * 1.3) * 0.06 * motion

        // A sizzling shiver while lit.
        var jx: CGFloat = 0
        var jy: CGFloat = 0
        if shownLit > 0.05 && motion > 0.5 {
            jx = sin(time * 91 + phase) * 0.9 * shownLit
            jy = cos(time * 77 + phase) * 0.6 * shownLit
        }
        root.position = CGPoint(x: p.x + jx, y: p.y + jy)
        drawnPoint = CGPoint(x: p.x, y: p.y + lift * r)

        // The lit rim: gold, hotter (whiter) as it nears popping.
        lit.alpha = shownLit
        if shownLit > 0.01 {
            lit.color = GardenPalette.gold.mixed(GardenInk.white, (1 - hpFrac) * 0.65).ui
        }

        // Eyes: squint in the light, squeeze shut "> <" when it really burns, blink otherwise.
        let squeezed = shownLit > 0.5
        squeeze.isHidden = !squeezed
        eyes.isHidden = squeezed
        pupils.isHidden = squeezed
        if squeezed {
            squeeze.yScale = 1 + 0.08 * sin(time * 30) * motion
        } else {
            let open = (1 - 0.9 * shownLit) * blink
            let ey = look.eyeY * (1 - open)
            eyes.yScale = open
            pupils.yScale = open
            eyes.position = CGPoint(x: 0, y: ey)
            let off = look.eyeRadius * 0.26
            let wx = sin(time * 0.7 + phase) * 0.35
            let wy = cos(time * 0.5 + phase) * 0.25
            var lx = dir.dx + wx
            var ly = dir.dy + wy
            let ll = max(sqrt(lx * lx + ly * ly), 0.001)
            lx /= ll
            ly /= ll
            pupils.position = CGPoint(x: lx * off, y: ey + ly * off * open)
        }

        // Mouth: a cheeky grin; an "ouch" in the light.
        let wantOpen = shownLit > 0.22
        if wantOpen != mouthOpenShown {
            mouthOpenShown = wantOpen
            mouth.texture = wantOpen ? mouthOpen : mouthClosed
        }
        if look.hasBrow {
            brow.position = CGPoint(x: 0, y: -0.09 * shownLit)
        }

        // Contact shadow (separates from the body during a hop).
        let lifted: CGFloat = 1 - 0.4 * (lift / 0.75)
        shadow.position = CGPoint(x: p.x + r * 0.12, y: p.y - r * 0.6 * hpScale)
        shadow.size = CGSize(width: max(r * 2.1 * hpScale * grow * lifted, 1),
                             height: max(r * 0.8 * hpScale * grow * lifted, 1))
        shadow.alpha = 0.42 * (0.6 + 0.4 * lifted) * (1 - sink)
    }

    /// Starts leaving without a pop. `target`: where an eating gloom dives (scene points).
    func startDeath(_ mode: GloomDeath, target: CGPoint?) {
        death = mode
        switch mode {
        case .evaporate: deathTotal = 0.9
        case .eaten: deathTotal = 0.32
        case .squash: deathTotal = 0.05
        case .fade, .none: deathTotal = 0.22
        }
        deathLeft = deathTotal
        deathFrom = root.position
        deathTarget = target ?? root.position
        if mode == .squash {
            lit.alpha = 1
            lit.color = GardenInk.white.ui
            pool.isHidden = true
        }
        if mode == .evaporate || mode == .squash {
            squeeze.isHidden = false
            eyes.isHidden = true
            pupils.isHidden = true
            mouth.texture = mouthOpen
        }
    }

    /// Advances a death; false once it is over (release the node).
    func updateDying(dt: CGFloat, time: CGFloat) -> Bool {
        deathLeft -= dt
        if deathLeft <= 0 { return false }
        let t = 1 - deathLeft / max(deathTotal, 0.001)
        switch death {
        case .evaporate:
            root.position = CGPoint(x: deathFrom.x + sin(t * 7 + phase) * 3, y: deathFrom.y + 48 * t * t)
            puppet.xScale = scaleNow * (1 - 0.35 * t)
            puppet.yScale = scaleNow * (1 + 0.45 * t)
            lit.alpha = 1 - t * 0.5
            root.alpha = 1 - t
        case .eaten:
            let e = GardenMath.easeOut(t)
            root.position = CGPoint(x: deathFrom.x + (deathTarget.x - deathFrom.x) * e,
                                    y: deathFrom.y + (deathTarget.y - deathFrom.y) * e)
            puppet.setScale(scaleNow * (1 - 0.7 * t))
            root.alpha = 1 - t * t
        case .squash:
            // Held flat and white for a beat, then gone (the burst is already flying).
            puppet.xScale = scaleNow * 1.32
            puppet.yScale = scaleNow * 0.62
            lit.alpha = 1
            root.alpha = t < 0.6 ? 1 : max(0, (1 - t) / 0.4)
        case .fade, .none:
            root.alpha = 1 - t
        }
        shadow.alpha = 0.42 * (1 - t)
        return true
    }
}

// MARK: - Fireflies

/// A firefly: a top-down bug with a glowing tail and a halo; it flickers red as it scorches.
@MainActor
final class GardenFirefly {
    let root = SKNode()
    private let halo = SKSpriteNode()
    private let bug = SKSpriteNode()
    private let core = SKSpriteNode()
    private(set) var id: Int = -1
    var seenFrame: Int = -1
    private var phase: CGFloat = 0
    private var heading: CGFloat = 0
    private var last: CGPoint = .zero
    private var hasLast = false
    private var rng = GardenRNG(seed: 7)
    private var fadeLeft: CGFloat = 0
    private(set) var drawnPoint: CGPoint = .zero
    private(set) var scorch: CGFloat = 0
    private(set) var size: CGFloat = 12
    var trailClock: CGFloat = 0
    /// R2: the scorch warning ring has shown (re-armed once it cools).
    var warned = false
    /// The colour as drawn (lime → red with scorch).
    private(set) var tint: GardenInk = GardenPalette.firefly

    init() {
        halo.texture = GardenArt.glow
        halo.blendMode = .add
        halo.colorBlendFactor = 1
        halo.zPosition = 0
        bug.texture = CreatureArt.firefly
        bug.zPosition = 0.1
        core.texture = GardenArt.dot
        core.blendMode = .add
        core.colorBlendFactor = 1
        core.zPosition = 0.2
        root.addChild(halo)
        root.addChild(bug)
        root.addChild(core)
    }

    func configure(id i: Int) {
        id = i
        rng = GardenRNG(seed: UInt64(bitPattern: Int64(i)) &+ 0xF1F1)
        phase = rng.range(0, 2 * CGFloat.pi)
        hasLast = false
        fadeLeft = 0
        trailClock = 0
        warned = false
        scorch = 0
        root.alpha = 1
        root.isHidden = false
    }

    func update(_ f: FireflyState, at p: CGPoint, size sz: CGFloat, dt: CGFloat, time: CGFloat, motion: CGFloat) {
        size = sz
        if hasLast {
            let dx = p.x - last.x
            let dy = p.y - last.y
            if dx * dx + dy * dy > 0.0025 {
                let h = atan2(dy, dx)
                var diff = h - heading
                while diff > CGFloat.pi { diff -= 2 * CGFloat.pi }
                while diff < -CGFloat.pi { diff += 2 * CGFloat.pi }
                heading += diff * min(1, dt * 10)
            }
        } else {
            heading = CGFloat.pi / 2
        }
        last = p
        hasLast = true
        let bob = sin(time * 2.2 + phase) * 2 * motion
        root.position = CGPoint(x: p.x, y: p.y + bob)
        drawnPoint = root.position
        scorch = CGFloat(GardenMath.clamp(f.scorch, 0, 1))
        tint = GardenPalette.firefly.mixed(GardenPalette.fireflyHot, scorch)
        let pulse = 0.5 + 0.5 * sin(time * 2.6 + phase)
        let flick: CGFloat = scorch > 0.15 ? 1 - scorch * 0.6 * rng.unit() : 1
        halo.size = CGSize(width: sz * 4.4 * (0.9 + 0.15 * pulse), height: sz * 4.4 * (0.9 + 0.15 * pulse))
        halo.alpha = (0.42 + 0.4 * pulse) * flick
        halo.color = tint.ui
        bug.size = CGSize(width: sz, height: sz)
        bug.zRotation = heading - CGFloat.pi / 2
        bug.xScale = 1 + 0.1 * sin(time * 48 + phase) * motion
        let back = CGPoint(x: -cos(heading) * sz * 0.32, y: -sin(heading) * sz * 0.32)
        core.position = back
        core.size = CGSize(width: sz * 0.95, height: sz * 0.95)
        core.alpha = 0.95 * flick
        core.color = tint.lighter(0.3).ui
    }

    /// The point just behind the tail (trail motes).
    var tailPoint: CGPoint {
        CGPoint(x: root.position.x - cos(heading) * size * 0.5, y: root.position.y - sin(heading) * size * 0.5)
    }

    func startFade() { fadeLeft = 0.25 }

    /// False once faded (release it).
    func updateFade(dt: CGFloat) -> Bool {
        fadeLeft -= dt
        if fadeLeft <= 0 { return false }
        root.alpha = fadeLeft / 0.25
        return true
    }
}

// MARK: - Flowers

/// One flower at the flower edge (the flowers are the lives). Eaten: a sad stalk. Replanted: it blooms.
@MainActor
final class GardenFlower {
    static let bloomTime: CGFloat = 0.7
    static let chompTime: CGFloat = 0.38

    let root = SKNode()
    let index: Int
    private let leaves = SKSpriteNode()
    private let petals = SKSpriteNode()
    private let stalk = SKSpriteNode()
    private let glow = SKSpriteNode()
    private(set) var standing = true
    private var bloomLeft: CGFloat = 0
    private var chompLeft: CGFloat = 0
    private let phase: CGFloat
    private(set) var radius: CGFloat = 20
    /// The petals' colour (bursts use it).
    let color: GardenInk

    var isBlooming: Bool { bloomLeft > 0 }
    var petalsShowing: Bool { !petals.isHidden && petals.alpha > 0.01 }

    init(index i: Int) {
        index = i
        phase = GardenRNG.hash(i, 0xF10E) * 2 * CGFloat.pi
        color = CreatureArt.flowerLook(i).petal
        leaves.texture = CreatureArt.flowerLeaves(i)
        petals.texture = CreatureArt.flowerPetals(i)
        stalk.texture = CreatureArt.flowerStalk(i)
        glow.texture = GardenArt.glow
        glow.blendMode = .add
        glow.colorBlendFactor = 1
        glow.color = color.lighter(0.4).ui
        glow.alpha = 0
        leaves.zPosition = 0
        stalk.zPosition = 0.05
        petals.zPosition = 0.1
        glow.zPosition = 0.2
        leaves.colorBlendFactor = 0
        petals.colorBlendFactor = 0
        leaves.color = GardenInk(hex: 0x1C2A5C).ui
        petals.color = GardenInk(hex: 0x2A2F66).ui
        stalk.isHidden = true
        root.addChild(leaves)
        root.addChild(stalk)
        root.addChild(petals)
        root.addChild(glow)
    }

    func place(at p: CGPoint, radius r: CGFloat) {
        radius = r
        root.position = p
        let side = CreatureArt.flowerCanvas * r
        for n in [leaves, petals, stalk] { n.size = CGSize(width: side, height: side) }
        glow.size = CGSize(width: r * 3.4, height: r * 3.4)
    }

    func setStanding(_ s: Bool, animated: Bool) {
        guard s != standing else { return }
        standing = s
        if s {
            bloomLeft = animated ? GardenFlower.bloomTime : 0
            chompLeft = 0
        } else {
            chompLeft = animated ? GardenFlower.chompTime : 0
            bloomLeft = 0
        }
    }

    /// `dawn` 0…1 opens the petals; `light` 0…1: the band on the flower edge; `danger` 0…1: a gloom closing in.
    func update(dt: CGFloat, time: CGFloat, dawn: CGFloat, light: CGFloat, danger: CGFloat, motion: CGFloat) {
        let open: CGFloat = 0.8 + 0.2 * GardenMath.smooth(0, 0.6, dawn)
        let night: CGFloat = (1 - GardenMath.smooth(0, 0.55, dawn)) * 0.42
        leaves.colorBlendFactor = night
        petals.colorBlendFactor = night * 0.55
        let sway = sin(time * 1.3 + phase) * 0.05 * motion
        if standing {
            stalk.isHidden = true
            leaves.isHidden = false
            petals.isHidden = false
            petals.alpha = 1
            var s: CGFloat = 1
            var spin: CGFloat = 0
            var flash: CGFloat = 0
            if bloomLeft > 0 {
                bloomLeft = max(0, bloomLeft - dt)
                let k = 1 - bloomLeft / GardenFlower.bloomTime
                s = max(GardenMath.easeOutBack(k), 0.01)
                spin = (1 - k) * 1.4
                flash = 1 - k
            }
            let tremble = danger * sin(time * 38 + phase) * 0.1 * (motion > 0.5 ? 1 : 0.3)
            petals.setScale(s * open * (1 + 0.04 * danger))
            petals.zRotation = sway + tremble + spin
            leaves.setScale(min(1, s * 1.15))
            leaves.zRotation = sway * 0.4
            glow.alpha = min(1, light * 0.5 + flash * 0.9)
        } else {
            leaves.isHidden = true
            glow.alpha = 0
            if chompLeft > 0 {
                chompLeft = max(0, chompLeft - dt)
                let k = 1 - chompLeft / GardenFlower.chompTime
                petals.isHidden = false
                petals.setScale(max((1 - k) * open * (1 + 0.25 * sin(k * CGFloat.pi * 3)), 0.01))
                petals.zRotation = sway + k * 0.8
                petals.alpha = 1 - k * k
                stalk.isHidden = false
                stalk.alpha = k
            } else {
                petals.isHidden = true
                stalk.isHidden = false
                stalk.alpha = 1
                stalk.zRotation = sway * 0.3
            }
        }
    }
}
