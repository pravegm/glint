import SpriteKit
import UIKit

/// One cosmetic particle (sparks, petals, steam, ink). Simulated by the scene, never by Core.
struct GardenParticle {
    var position: CGPoint = .zero
    var velocity: CGVector = CGVector(dx: 0, dy: 0)
    var life: CGFloat = 0
    var maxLife: CGFloat = 1
    /// Pulls velocity down the screen (negative: rises, like embers and steam).
    var gravity: CGFloat = 0
    var drag: CGFloat = 0
    var spin: CGFloat = 0
    /// Side-to-side flutter (petals), points per second.
    var sway: CGFloat = 0
    var swayPhase: CGFloat = 0
    var shrink: Bool = true
    /// Grows by this factor over its life (steam billowing, puffs).
    var growth: CGFloat = 0
    /// Fades in over the first 0.12 s (steam).
    var fadeIn: Bool = false
    /// Peak opacity.
    var alphaScale: CGFloat = 1
    var active: Bool = false
}

/// A fixed pool of sprites under one blend mode (textures swapped per spawn). Nothing is allocated per frame.
@MainActor
final class GardenFXPool {
    let root: SKNode
    private var sprites: [SKSpriteNode] = []
    private var parts: [GardenParticle] = []
    private var cursor = 0
    /// Spawns are scaled by this (fewer with Reduce Motion or in attract mode).
    var density: CGFloat = 1

    init(capacity: Int, texture: SKTexture, blend: SKBlendMode) {
        root = SKNode()
        for _ in 0..<max(capacity, 1) {
            let s = SKSpriteNode(texture: texture, size: CGSize(width: 6, height: 6))
            s.colorBlendFactor = 1
            s.blendMode = blend
            s.isHidden = true
            root.addChild(s)
            sprites.append(s)
            parts.append(GardenParticle())
        }
    }

    var capacity: Int { parts.count }

    var activeCount: Int {
        var n = 0
        for p in parts where p.active { n += 1 }
        return n
    }

    func clear() {
        for i in 0..<parts.count {
            parts[i].active = false
            sprites[i].isHidden = true
        }
    }

    /// Moves every particle by `delta` (a re-layout keeps bursts where their gloom was drawn).
    func shift(by delta: CGVector) {
        for i in 0..<parts.count where parts[i].active {
            parts[i].position.x += delta.dx
            parts[i].position.y += delta.dy
            sprites[i].position = parts[i].position
        }
    }

    func scaled(_ n: Int) -> Int { max(1, Int((CGFloat(n) * density).rounded())) }

    func update(_ dt: CGFloat) {
        guard dt > 0 else { return }
        for i in 0..<parts.count where parts[i].active {
            var p = parts[i]
            p.life -= dt
            let s = sprites[i]
            if p.life <= 0 {
                p.active = false
                s.isHidden = true
                parts[i] = p
                continue
            }
            p.velocity.dy -= p.gravity * dt
            if p.drag > 0 {
                let k = max(0, 1 - p.drag * dt)
                p.velocity.dx *= k
                p.velocity.dy *= k
            }
            let age = p.maxLife - p.life
            var vx = p.velocity.dx
            if p.sway != 0 { vx += cos(age * 5.5 + p.swayPhase) * p.sway }
            p.position.x += vx * dt
            p.position.y += p.velocity.dy * dt
            let k = max(0, min(1, p.life / max(p.maxLife, 0.001)))
            s.position = p.position
            var a = min(1, k * 3) * p.alphaScale
            if p.fadeIn { a *= min(1, age / 0.12) }
            s.alpha = a
            var scale: CGFloat = p.shrink ? (0.35 + 0.65 * k) : 1
            if p.growth > 0 { scale *= 1 + p.growth * (1 - k) }
            s.zRotation += p.spin * dt
            s.setScale(scale)
            parts[i] = p
        }
    }

    func spawn(_ p: GardenParticle, size: CGFloat, color: UIColor, texture: SKTexture? = nil, rotation: CGFloat = 0) {
        let n = parts.count
        guard n > 0 else { return }
        var slot = -1
        for k in 0..<n {
            let idx = (cursor + k) % n
            if !parts[idx].active {
                slot = idx
                break
            }
        }
        if slot < 0 { slot = cursor }
        cursor = (slot + 1) % n
        var q = p
        q.active = true
        q.maxLife = max(q.life, 0.01)
        parts[slot] = q
        let s = sprites[slot]
        if let t = texture, s.texture !== t { s.texture = t }
        s.size = CGSize(width: size, height: size)
        s.color = color
        s.colorBlendFactor = 1
        s.position = q.position
        s.zRotation = rotation
        s.setScale(1)
        s.alpha = q.fadeIn ? 0 : q.alphaScale
        s.isHidden = false
    }
}

/// Expanding rings and flashes (each a sprite with its own scale curve).
@MainActor
final class GardenRingPool {
    let root = SKNode()
    private var sprites: [SKSpriteNode] = []
    private var life: [CGFloat] = []
    private var maxLife: [CGFloat] = []
    private var from: [CGFloat] = []
    private var to: [CGFloat] = []
    private var peak: [CGFloat] = []
    private var cursor = 0

    init(capacity: Int) {
        for _ in 0..<max(capacity, 1) {
            let s = SKSpriteNode(texture: GardenArt.ring, size: CGSize(width: 2, height: 2))
            s.blendMode = .add
            s.colorBlendFactor = 1
            s.isHidden = true
            root.addChild(s)
            sprites.append(s)
            life.append(0)
            maxLife.append(1)
            from.append(0)
            to.append(1)
            peak.append(1)
        }
    }

    var activeCount: Int {
        var n = 0
        for l in life where l > 0 { n += 1 }
        return n
    }

    func clear() {
        for i in 0..<sprites.count {
            life[i] = 0
            sprites[i].isHidden = true
        }
    }

    func shift(by delta: CGVector) {
        for i in 0..<sprites.count where life[i] > 0 {
            sprites[i].position = CGPoint(x: sprites[i].position.x + delta.dx, y: sprites[i].position.y + delta.dy)
        }
    }

    /// A ring (or a flash with `texture: GardenArt.glow`) growing from `fromRadius` to `toRadius`.
    func spawn(at p: CGPoint, fromRadius: CGFloat, toRadius: CGFloat, life l: CGFloat, color: UIColor,
               alpha: CGFloat = 1, texture: SKTexture? = nil) {
        let n = sprites.count
        var slot = -1
        for k in 0..<n {
            let idx = (cursor + k) % n
            if life[idx] <= 0 {
                slot = idx
                break
            }
        }
        if slot < 0 { slot = cursor }
        cursor = (slot + 1) % n
        let s = sprites[slot]
        let tex = texture ?? GardenArt.ring
        if s.texture !== tex { s.texture = tex }
        s.size = CGSize(width: 2, height: 2)
        s.color = color
        s.position = p
        life[slot] = max(l, 0.01)
        maxLife[slot] = max(l, 0.01)
        from[slot] = max(fromRadius, 0.5)
        to[slot] = max(toRadius, 0.5)
        peak[slot] = alpha
        s.setScale(from[slot])
        s.alpha = alpha
        s.isHidden = false
    }

    func update(_ dt: CGFloat) {
        guard dt > 0 else { return }
        for i in 0..<sprites.count where life[i] > 0 {
            life[i] -= dt
            let s = sprites[i]
            if life[i] <= 0 {
                s.isHidden = true
                continue
            }
            let t = 1 - life[i] / maxLife[i]
            let e = GardenMath.easeOut(t)
            s.setScale(from[i] + (to[i] - from[i]) * e)
            s.alpha = peak[i] * (1 - t) * (1 - t)
        }
    }
}

/// Floating words ("Sweep!", "×4", "+50", "Wave 3"): rounded heavy type with a dark outline.
@MainActor
final class GardenLabels {
    let root = SKNode()
    private var labels: [SKLabelNode] = []
    private var life: [CGFloat] = []
    private var maxLife: [CGFloat] = []
    private var rise: [CGFloat] = []
    private var base: [CGPoint] = []
    private var cursor = 0

    init(capacity: Int) {
        for _ in 0..<max(capacity, 1) {
            let l = SKLabelNode()
            l.horizontalAlignmentMode = .center
            l.verticalAlignmentMode = .center
            l.numberOfLines = 1
            l.isHidden = true
            root.addChild(l)
            labels.append(l)
            life.append(0)
            maxLife.append(1)
            rise.append(0)
            base.append(.zero)
        }
    }

    var visibleCount: Int {
        var n = 0
        for l in life where l > 0 { n += 1 }
        return n
    }

    /// The text of every label on screen now (tests).
    var visibleTexts: [String] {
        var out: [String] = []
        for i in 0..<labels.count where life[i] > 0 {
            out.append(labels[i].attributedText?.string ?? "")
        }
        return out
    }

    func clear() {
        for i in 0..<labels.count {
            life[i] = 0
            labels[i].isHidden = true
        }
    }

    func shift(by delta: CGVector) {
        for i in 0..<labels.count where life[i] > 0 {
            base[i] = CGPoint(x: base[i].x + delta.dx, y: base[i].y + delta.dy)
        }
    }

    static func font(_ size: CGFloat) -> UIFont {
        let f = UIFont.systemFont(ofSize: size, weight: .heavy)
        if let d = f.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
        return f
    }

    static func attributed(_ text: String, size: CGFloat, color: GardenInk) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font(size),
            .foregroundColor: color.ui,
            .strokeColor: GardenInk(hex: 0x1A0E24).ui,
            .strokeWidth: -4.5
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    /// Shows `text` at `p` (scene points); returns its slot.
    @discardableResult
    func show(_ text: String, at p: CGPoint, size: CGFloat, color: GardenInk, rise r: CGFloat = 46,
              life l: CGFloat = 1.0) -> Int {
        let n = labels.count
        var slot = -1
        for k in 0..<n {
            let idx = (cursor + k) % n
            if life[idx] <= 0 {
                slot = idx
                break
            }
        }
        if slot < 0 { slot = cursor }
        cursor = (slot + 1) % n
        let label = labels[slot]
        label.attributedText = GardenLabels.attributed(text, size: size, color: color)
        life[slot] = max(l, 0.05)
        maxLife[slot] = max(l, 0.05)
        rise[slot] = r
        base[slot] = p
        label.position = p
        label.setScale(0.4)
        label.alpha = 1
        label.isHidden = false
        return slot
    }

    /// Re-words a label still on screen (a sweep that keeps growing) and pops it again. False if it has gone.
    func retext(_ slot: Int, _ text: String, size: CGFloat, color: GardenInk) -> Bool {
        guard slot >= 0, slot < labels.count, life[slot] > 0 else { return false }
        labels[slot].attributedText = GardenLabels.attributed(text, size: size, color: color)
        life[slot] = maxLife[slot]
        return true
    }

    func update(_ dt: CGFloat) {
        guard dt > 0 else { return }
        for i in 0..<labels.count where life[i] > 0 {
            life[i] -= dt
            let l = labels[i]
            if life[i] <= 0 {
                l.isHidden = true
                continue
            }
            let t = 1 - life[i] / maxLife[i]
            let pop: CGFloat = t < 0.18 ? GardenMath.easeOutBack(t / 0.18) : 1
            l.setScale(0.4 + 0.6 * pop)
            l.position = CGPoint(x: base[i].x, y: base[i].y + rise[i] * GardenMath.easeOut(t))
            l.alpha = t < 0.7 ? 1 : max(0, 1 - (t - 0.7) / 0.3)
        }
    }
}

/// The scene's particle effects, in scene points (upright: "up" is the screen's up whatever the layout).
@MainActor
final class GardenFX {
    let root = SKNode()
    /// Additive: sparks, glints, motes, embers.
    let glow: GardenFXPool
    /// Alpha-blended: petals, steam, ink, dust.
    let soft: GardenFXPool
    let rings: GardenRingPool
    private var rng = GardenRNG(seed: 0xF1_2E)

    /// 1 normally; lower in attract mode and with Reduce Motion.
    var density: CGFloat = 1 {
        didSet {
            glow.density = density
            soft.density = density
        }
    }

    init() {
        glow = GardenFXPool(capacity: 84, texture: GardenArt.sparkle, blend: .add)
        soft = GardenFXPool(capacity: 64, texture: GardenArt.soft, blend: .alpha)
        rings = GardenRingPool(capacity: 10)
        soft.root.zPosition = 0
        glow.root.zPosition = 1
        rings.root.zPosition = 2
        root.addChild(soft.root)
        root.addChild(glow.root)
        root.addChild(rings.root)
    }

    var activeCount: Int { glow.activeCount + soft.activeCount + rings.activeCount }

    func update(_ dt: CGFloat) {
        glow.update(dt)
        soft.update(dt)
        rings.update(dt)
    }

    func clear() {
        glow.clear()
        soft.clear()
        rings.clear()
    }

    func shift(by delta: CGVector) {
        glow.shift(by: delta)
        soft.shift(by: delta)
        rings.shift(by: delta)
    }

    private static let sparkColors: [GardenInk] = [GardenInk(hex: 0xFFD45A), GardenInk(hex: 0xFFF1B0),
                                                    GardenInk(hex: 0xFFB13D), GardenInk(hex: 0xFFFFFF)]

    /// A gloom popping: a flash, a shock ring, gold sparks, petals, a few flecks of ink.
    func pop(at p: CGPoint, radius r: CGFloat, big: Bool, chain: Int) {
        let warm = GardenPalette.goldHot.ui
        rings.spawn(at: p, fromRadius: r * 0.6, toRadius: r * (big ? 3.6 : 2.8), life: 0.42, color: warm, alpha: 0.9)
        rings.spawn(at: p, fromRadius: r * 1.2, toRadius: r * 2.6, life: 0.2, color: warm, alpha: 0.85,
                    texture: GardenArt.glow)
        let sparks = glow.scaled((big ? 18 : 11) + min(chain, 8))
        let speed = r * 6 + 90
        for _ in 0..<sparks {
            let a = rng.range(0, 2 * CGFloat.pi)
            let v = rng.range(0.35, 1) * speed
            var q = GardenParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v)
            q.life = rng.range(0.35, 0.75)
            q.drag = 3.2
            q.gravity = -30
            q.spin = rng.range(-6, 6)
            let c = GardenFX.sparkColors[Int(rng.unit() * 4) % 4]
            glow.spawn(q, size: rng.range(10, 22) * (big ? 1.2 : 1), color: c.ui, texture: GardenArt.sparkle)
        }
        let petals = soft.scaled(big ? 10 : 6)
        for i in 0..<petals {
            let a = rng.range(0, 2 * CGFloat.pi)
            let v = rng.range(0.4, 1) * (r * 4 + 60)
            var q = GardenParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v + 30)
            q.life = rng.range(0.9, 1.5)
            q.drag = 2.4
            q.gravity = 46
            q.spin = rng.range(-5, 5)
            q.sway = rng.range(10, 26)
            q.swayPhase = rng.range(0, 6)
            q.shrink = false
            q.alphaScale = 0.95
            let c = GardenPalette.petals[(i + Int(rng.unit() * 5)) % GardenPalette.petals.count]
            soft.spawn(q, size: rng.range(9, 14), color: c.ui, texture: GardenArt.petal(i), rotation: a)
        }
        let flecks = soft.scaled(big ? 5 : 3)
        for _ in 0..<flecks {
            let a = rng.range(0, 2 * CGFloat.pi)
            let v = rng.range(0.5, 1) * (r * 5 + 50)
            var q = GardenParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v)
            q.life = rng.range(0.25, 0.45)
            q.drag = 4
            q.alphaScale = 0.8
            soft.spawn(q, size: rng.range(4, 8), color: GardenPalette.inkMid.ui, texture: GardenArt.inkDrop,
                       rotation: a)
        }
    }

    /// One puff of steam off a lit gloom (rises, billows, fades).
    func steam(at p: CGPoint, radius r: CGFloat) {
        var q = GardenParticle()
        q.position = CGPoint(x: p.x + rng.range(-0.6, 0.6) * r, y: p.y + rng.range(0.1, 0.7) * r)
        q.velocity = CGVector(dx: rng.range(-12, 12), dy: rng.range(26, 52))
        q.life = rng.range(0.55, 0.9)
        q.drag = 0.8
        q.growth = 1.6
        q.shrink = false
        q.fadeIn = true
        q.alphaScale = rng.range(0.22, 0.4)
        soft.spawn(q, size: max(r * 0.55, 6), color: GardenPalette.steam.ui, texture: GardenArt.soft)
    }

    /// A tiny ember crackling off a burning gloom.
    func ember(at p: CGPoint, radius r: CGFloat) {
        let a = rng.range(0, 2 * CGFloat.pi)
        var q = GardenParticle()
        q.position = CGPoint(x: p.x + cos(a) * r * 0.8, y: p.y + sin(a) * r * 0.8)
        q.velocity = CGVector(dx: cos(a) * rng.range(20, 50), dy: sin(a) * rng.range(20, 50) + 20)
        q.life = rng.range(0.2, 0.4)
        q.drag = 2
        q.gravity = -40
        glow.spawn(q, size: rng.range(4, 7), color: GardenPalette.ember.ui, texture: GardenArt.dot)
    }

    /// Ink spattering (a gloom emerging, a splitter splitting, a flower eaten). `toward` biases the spray.
    func ink(at p: CGPoint, radius r: CGFloat, count n: Int, toward: CGVector) {
        for _ in 0..<soft.scaled(n) {
            let a = rng.range(0, 2 * CGFloat.pi)
            let v = rng.range(0.3, 1) * (r * 3 + 40)
            var q = GardenParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v + toward.dx * 50, dy: sin(a) * v + toward.dy * 50)
            q.life = rng.range(0.3, 0.6)
            q.drag = 4
            q.alphaScale = 0.85
            soft.spawn(q, size: rng.range(4, 9) * max(r / 18, 0.7), color: GardenPalette.inkDeep.ui,
                       texture: GardenArt.inkDrop, rotation: a)
        }
        var puff = GardenParticle()
        puff.position = p
        puff.life = 0.45
        puff.growth = 1.2
        puff.shrink = false
        puff.alphaScale = 0.4
        soft.spawn(puff, size: r * 1.6 + 10, color: GardenPalette.inkMid.ui, texture: GardenArt.soft)
    }

    /// A dust puff ring (a hopper taking off).
    func dust(at p: CGPoint, radius r: CGFloat, color: GardenInk) {
        let n = soft.scaled(7)
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * CGFloat.pi + rng.range(0, 0.4)
            var q = GardenParticle()
            q.position = CGPoint(x: p.x + cos(a) * r * 0.6, y: p.y + sin(a) * r * 0.3 - r * 0.5)
            q.velocity = CGVector(dx: cos(a) * rng.range(30, 60), dy: sin(a) * rng.range(10, 24))
            q.life = rng.range(0.4, 0.65)
            q.drag = 3
            q.growth = 1.3
            q.shrink = false
            q.alphaScale = 0.45
            soft.spawn(q, size: r * 0.6 + 6, color: color.ui, texture: GardenArt.soft)
        }
    }

    /// A firefly scorched: red sparks dropping, a curl of grey smoke.
    func fizzle(at p: CGPoint, size: CGFloat) {
        for _ in 0..<glow.scaled(9) {
            let a = rng.range(0, 2 * CGFloat.pi)
            let v = rng.range(30, 90)
            var q = GardenParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v)
            q.life = rng.range(0.3, 0.6)
            q.drag = 2.5
            q.gravity = 120
            let c = rng.unit() < 0.5 ? GardenPalette.fireflyHot : GardenInk(hex: 0xFF9A3A)
            glow.spawn(q, size: rng.range(5, 9), color: c.ui, texture: GardenArt.dot)
        }
        for i in 0..<soft.scaled(4) {
            var q = GardenParticle()
            q.position = CGPoint(x: p.x + rng.range(-3, 3), y: p.y + CGFloat(i) * 3)
            q.velocity = CGVector(dx: rng.range(-10, 10), dy: rng.range(24, 44))
            q.life = rng.range(0.8, 1.2)
            q.drag = 0.6
            q.growth = 2
            q.shrink = false
            q.fadeIn = true
            q.alphaScale = 0.45
            soft.spawn(q, size: size * 1.4 + 6, color: GardenInk(hex: 0x7E7A8A).ui, texture: GardenArt.soft)
        }
        rings.spawn(at: p, fromRadius: size * 0.5, toRadius: size * 2.2, life: 0.3,
                    color: GardenPalette.fireflyHot.ui, alpha: 0.6)
    }

    /// Sparkles streaming from `a` into `b` (a firefly delivered to its flower).
    func trail(from a: CGPoint, to b: CGPoint, color: GardenInk) {
        let n = glow.scaled(12)
        for i in 0..<n {
            let f = CGFloat(i) / CGFloat(max(n - 1, 1))
            let p = CGPoint(x: a.x + (b.x - a.x) * f * 0.7, y: a.y + (b.y - a.y) * f * 0.7)
            let life = 0.25 + 0.35 * (1 - f) + rng.range(0, 0.1)
            var q = GardenParticle()
            q.position = p
            q.velocity = CGVector(dx: (b.x - p.x) / life, dy: (b.y - p.y) / life)
            q.life = life
            q.spin = rng.range(-4, 4)
            glow.spawn(q, size: rng.range(8, 14), color: color.ui, texture: GardenArt.sparkle)
        }
    }

    /// A short-lived twinkle (a firefly appearing, the first light in the crease).
    func twinkle(at p: CGPoint, size: CGFloat, color: GardenInk) {
        var q = GardenParticle()
        q.position = p
        q.life = 0.5
        q.spin = 3
        q.alphaScale = 0.9
        glow.spawn(q, size: size, color: color.ui, texture: GardenArt.sparkle)
    }

    /// A dust mote drifting in the light.
    func mote(at p: CGPoint, color: GardenInk) {
        var q = GardenParticle()
        q.position = p
        q.velocity = CGVector(dx: rng.range(-7, 7), dy: rng.range(-6, 9))
        q.life = rng.range(1.2, 2.2)
        q.shrink = false
        q.fadeIn = true
        q.alphaScale = rng.range(0.25, 0.6)
        glow.spawn(q, size: rng.range(3, 6), color: color.ui, texture: GardenArt.dot)
    }

    /// A trail mote behind a firefly (or a flung wisp's ink, with `inky`).
    func trailMote(at p: CGPoint, size: CGFloat, color: GardenInk, inky: Bool) {
        var q = GardenParticle()
        q.position = p
        q.life = inky ? 0.3 : 0.45
        q.alphaScale = inky ? 0.55 : 0.5
        if inky {
            soft.spawn(q, size: size, color: color.ui, texture: GardenArt.soft)
        } else {
            glow.spawn(q, size: size, color: color.ui, texture: GardenArt.dot)
        }
    }

    /// Petals in a flower's colour bursting (a flower eaten) or drifting across `rect` (the sunrise).
    func petals(at p: CGPoint, spread: CGFloat, count n: Int, colors: [GardenInk]) {
        guard !colors.isEmpty else { return }
        for i in 0..<soft.scaled(n) {
            let a = rng.range(0, 2 * CGFloat.pi)
            let v = rng.range(0.3, 1) * spread
            var q = GardenParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v + 20)
            q.life = rng.range(0.9, 1.6)
            q.drag = 2.2
            q.gravity = 40
            q.spin = rng.range(-5, 5)
            q.sway = rng.range(10, 24)
            q.swayPhase = rng.range(0, 6)
            q.shrink = false
            let c = colors[i % colors.count]
            soft.spawn(q, size: rng.range(9, 15), color: c.ui, texture: GardenArt.petal(i), rotation: a)
        }
    }

    /// Petals and gold glitter drifting down over `rect` (the sunrise celebration).
    func confetti(in rect: CGRect, count n: Int) {
        guard rect.width > 0, rect.height > 0 else { return }
        for i in 0..<soft.scaled(n) {
            var q = GardenParticle()
            q.position = CGPoint(x: rng.range(rect.minX, rect.maxX), y: rng.range(rect.minY, rect.maxY))
            q.velocity = CGVector(dx: rng.range(-20, 20), dy: rng.range(20, 70))
            q.life = rng.range(1.2, 2.2)
            q.drag = 1
            q.gravity = 30
            q.spin = rng.range(-4, 4)
            q.sway = rng.range(12, 30)
            q.swayPhase = rng.range(0, 6)
            q.shrink = false
            q.fadeIn = true
            let c = GardenPalette.petals[i % GardenPalette.petals.count]
            soft.spawn(q, size: rng.range(10, 16), color: c.ui, texture: GardenArt.petal(i), rotation: rng.range(0, 6))
        }
        for _ in 0..<glow.scaled(n) {
            var q = GardenParticle()
            q.position = CGPoint(x: rng.range(rect.minX, rect.maxX), y: rng.range(rect.minY, rect.maxY))
            q.velocity = CGVector(dx: rng.range(-10, 10), dy: rng.range(30, 80))
            q.life = rng.range(0.6, 1.4)
            q.drag = 1
            q.spin = rng.range(-3, 3)
            q.fadeIn = true
            glow.spawn(q, size: rng.range(8, 16), color: GardenPalette.spark.ui, texture: GardenArt.sparkle)
        }
    }

    /// A gloom evaporating at sunrise: a rising wisp of golden steam.
    func evaporate(at p: CGPoint, radius r: CGFloat) {
        for _ in 0..<soft.scaled(4) {
            var q = GardenParticle()
            q.position = CGPoint(x: p.x + rng.range(-0.5, 0.5) * r, y: p.y + rng.range(0, 0.5) * r)
            q.velocity = CGVector(dx: rng.range(-10, 10), dy: rng.range(40, 80))
            q.life = rng.range(0.7, 1.1)
            q.drag = 0.6
            q.growth = 1.8
            q.shrink = false
            q.fadeIn = true
            q.alphaScale = 0.4
            soft.spawn(q, size: r * 0.8 + 6, color: GardenPalette.goldHot.ui, texture: GardenArt.soft)
        }
        for _ in 0..<glow.scaled(5) {
            var q = GardenParticle()
            q.position = CGPoint(x: p.x + rng.range(-0.7, 0.7) * r, y: p.y + rng.range(-0.3, 0.5) * r)
            q.velocity = CGVector(dx: rng.range(-14, 14), dy: rng.range(50, 100))
            q.life = rng.range(0.5, 0.9)
            q.drag = 1.2
            glow.spawn(q, size: rng.range(8, 13), color: GardenPalette.spark.ui, texture: GardenArt.sparkle)
        }
    }
}
