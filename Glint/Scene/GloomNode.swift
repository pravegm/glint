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
    /// R3: the soft mound of ground over a submerged gloom (a feathered ellipse: never a box).
    private let pool = SKSpriteNode()

    /// R3: 1 = travelling under the ground (`GloomState.submerged`: a ghost of the body, the eyes peeking, a mound),
    /// 0 = out in the garden. Smoothed.
    private(set) var sink: CGFloat = 0
    private var fresh = true
    /// Where the ground's surface is over it (scene points: ripples and the surfacing burst start there).
    private(set) var surfacePoint: CGPoint = .zero
    /// Where it looks (scene unit vector, as passed: towards the band).
    private(set) var lookDir = CGVector(dx: 0, dy: -1)
    /// R3: the pop-up as it surfaces.
    private var popLeft: CGFloat = 0
    static let popTime: CGFloat = 0.32
    var rippleClock: CGFloat = 0

    var isSubmerged: Bool { sink > 0.5 }
    var isPoppingUp: Bool { popLeft > 0 }

    private var soilTint = GardenInk(hex: 0x8A7A5A)

    /// R4: the ground's soil colour (the lip it peeks over).
    func setSoil(_ c: GardenInk) {
        guard c != soilTint else { return }
        soilTint = c
        pool.color = c.ui
    }

    /// R3: it rises out of the ground (`.surfaced`): a springy pop up.
    func popUp() {
        popLeft = GloomNode.popTime
        sink = 0
    }

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
        // R4: the soil lip its eyes peek over (in front of the puppet), tinted with the ground's soil.
        pool.texture = CreatureArt.soilLip
        pool.colorBlendFactor = 1
        pool.color = soilTint.ui
        pool.anchorPoint = CGPoint(x: 0.5, y: CreatureArt.soilLipTop / CreatureArt.soilLipSize.height)
        pool.zPosition = 0.5
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
        fresh = true
        popLeft = 0
        rippleClock = 0
        pool.isHidden = true
        body.alpha = 1
        mouth.alpha = 1
        brow.alpha = 1
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

        // R3: under the ground (Core's `submerged`) or out in the open; a new node starts where Core says.
        let sinkTarget = GardenMath.sink(g)
        sink = fresh ? sinkTarget : GardenMath.approach(sink, sinkTarget, rate: 12, dt: dt)
        if abs(sink - sinkTarget) < 0.002 { sink = sinkTarget }
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
        // R3: surfacing pops up: a springy overshoot and a little lift.
        var pop: CGFloat = 0
        if popLeft > 0 {
            popLeft = max(0, popLeft - dt)
            let k = 1 - popLeft / GloomNode.popTime
            pop = sin(k * CGFloat.pi) * (1 - 0.4 * k)
            lift += 0.45 * pop
            sy *= 1 + 0.22 * pop
            sx *= 1 - 0.08 * pop
        }
        // R3: under the ground it is a flattened ghost (the body faint, the eyes peeking).
        sy *= 1 - 0.3 * sink
        sx *= 1 + 0.06 * sink
        let s = r * hpScale * grow
        scaleNow = s
        puppet.xScale = s * sx
        puppet.yScale = s * sy
        let crouch: CGFloat = kind == .hopper ? 0.1 * tension : 0
        puppet.position = CGPoint(x: 0, y: (lift - crouch - 0.12 * sink) * r)
        // R4 (REVIEW-3 P1-7): underground it is dim and desaturated (no rim, no gloss, no light), its eyes at 50 %
        // peeking over a lip of soil; never a box.
        body.alpha = 1 - 0.78 * sink
        body.colorBlendFactor = 0.8 * sink
        body.color = GardenInk(hex: 0x3A3842).ui
        mouth.alpha = 1 - sink
        brow.alpha = 1 - sink
        let eyeAlpha: CGFloat = 1 - 0.5 * sink
        eyes.alpha = eyeAlpha
        pupils.alpha = eyeAlpha
        squeeze.alpha = eyeAlpha
        let eyeLine = puppet.position.y + look.eyeY * s * sy
        if sink > 0.01 {
            pool.isHidden = false
            let lw = s * 2.7
            pool.size = CGSize(width: lw, height: lw * CreatureArt.soilLipSize.height / CreatureArt.soilLipSize.width)
            pool.position = CGPoint(x: 0, y: eyeLine)
            pool.alpha = sink
        } else {
            pool.isHidden = true
        }
        surfacePoint = CGPoint(x: p.x, y: p.y + (sink > 0.5 ? eyeLine : -0.15 * s))
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

        // The lit rim: gold, hotter (whiter) as it nears popping (R4: never while underground).
        lit.alpha = shownLit * (1 - sink)
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
            // (Round eyes even while the body is flattened under the ground.)
            let unsquash: CGFloat = 1 / max(1 - 0.3 * sink, 0.1)
            eyes.yScale = open * unsquash
            pupils.yScale = open * unsquash
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
    private let wings = SKSpriteNode()
    private let core = SKSpriteNode()
    /// R3: a 6-dot trail along its recent path (children of `root`, placed relative to it).
    static let trailCount = 6
    private var dots: [SKSpriteNode] = []
    private var history: [CGPoint] = []
    private var historyClock: CGFloat = 0
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
        wings.texture = CreatureArt.fireflyWings
        wings.zPosition = 0.15
        core.texture = GardenArt.dot
        core.blendMode = .add
        core.colorBlendFactor = 1
        core.zPosition = 0.2
        root.addChild(halo)
        root.addChild(bug)
        root.addChild(wings)
        root.addChild(core)
        for i in 0..<GardenFirefly.trailCount {
            let d = SKSpriteNode(texture: GardenArt.dot)
            d.blendMode = .add
            d.colorBlendFactor = 1
            d.color = GardenPalette.firefly.ui
            d.zPosition = -0.1 - CGFloat(i) * 0.001
            d.isHidden = true
            root.addChild(d)
            dots.append(d)
        }
    }

    /// The trail dots drawn now.
    var trailDotsShowing: Int { dots.filter { !$0.isHidden }.count }

    func configure(id i: Int) {
        id = i
        rng = GardenRNG(seed: UInt64(bitPattern: Int64(i)) &+ 0xF1F1)
        phase = rng.range(0, 2 * CGFloat.pi)
        hasLast = false
        fadeLeft = 0
        trailClock = 0
        history.removeAll(keepingCapacity: true)
        historyClock = 0
        for d in dots { d.isHidden = true }
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
        // R3 (REVIEW-2 P2-17): a big lime body you can't mistake for a white dot; the halo is saturated lime, softer.
        let body = sz * 1.7
        let haloK: CGFloat = 3.2 * (0.9 + 0.15 * pulse)
        halo.size = CGSize(width: sz * haloK, height: sz * haloK)
        halo.alpha = (0.26 + 0.24 * pulse) * flick
        halo.color = GardenInk(hex: 0x9CFF2E).mixed(GardenPalette.fireflyHot, scorch).ui
        bug.size = CGSize(width: body, height: body)
        bug.zRotation = heading - CGFloat.pi / 2
        bug.colorBlendFactor = 0.8 * scorch
        bug.color = GardenPalette.fireflyHot.ui
        // Wings flicker: a fast flutter of size and opacity.
        wings.size = CGSize(width: body, height: body)
        wings.zRotation = bug.zRotation
        let flutter = sin(time * 52 + phase)
        wings.xScale = 1 + 0.16 * flutter * motion
        wings.alpha = 0.55 + 0.35 * abs(flutter)
        let back = CGPoint(x: -cos(heading) * body * 0.2, y: -sin(heading) * body * 0.2)
        core.position = back
        core.size = CGSize(width: body * 0.62, height: body * 0.62)
        core.alpha = 0.7 * flick * (0.7 + 0.3 * pulse)
        core.color = tint.ui

        // The 6-dot trail: points along its path, oldest the smallest and faintest.
        historyClock += dt
        let keep = GardenFirefly.trailCount + 1
        if history.isEmpty {
            for _ in 0..<keep { history.append(root.position) }
        } else if historyClock >= 0.045 {
            historyClock = 0
            history.insert(root.position, at: 0)
            if history.count > keep { history.removeLast(history.count - keep) }
        }
        for (i, d) in dots.enumerated() {
            guard i + 1 < history.count else {
                d.isHidden = true
                continue
            }
            let h = history[i + 1]
            let k = 1 - CGFloat(i) / CGFloat(GardenFirefly.trailCount)
            let ds = sz * (0.25 + 0.4 * k)
            d.isHidden = false
            d.position = CGPoint(x: h.x - root.position.x, y: h.y - root.position.y)
            d.size = CGSize(width: ds, height: ds)
            d.alpha = 0.15 + 0.55 * k
            d.color = tint.ui
        }
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
