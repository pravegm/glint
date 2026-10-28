import CoreGraphics
import Foundation
import SpriteKit
import Testing
import UIKit
@testable import Glint

/// A scripted driver: hands the scene a fixed snapshot (and one batch of events), records drags.
@MainActor
final class SceneFakeDriver: GardenDriver {
    var snapshot = DawnSnapshot(mode: .level(1))
    var events: [GameEvent] = []
    var advances = 0
    var drags: [String] = []
    var points: [CGPoint] = []

    func advance(dt: Double, now: TimeInterval) -> (DawnSnapshot, [GameEvent]) {
        advances += 1
        let e = events
        events = []
        return (snapshot, e)
    }

    func dragBegan(_ p: CGPoint) {
        drags.append("began")
        points.append(p)
    }

    func dragMoved(_ p: CGPoint) {
        drags.append("moved")
        points.append(p)
    }

    func dragEnded() { drags.append("ended") }
}

/// Scene module tests: the floor ↔ canvas mapping in all four layouts, the band profile, the texture cache (a warm
/// frame loop builds nothing), node pooling, event FX, sunrise / night, the lever, the sun, re-layout, the budget.
@MainActor
struct SceneTests {
    static let step: Double = 1.0 / 120.0

    /// Phone portrait, a laptop Duo with the halves swapped, a book Duo both ways round.
    static let layouts: [GardenLayout] = [
        GardenLayout(size: CGSize(width: 393, height: 852), foldVertical: false, gardenAfter: true, gardenFraction: 0.58),
        GardenLayout(size: CGSize(width: 900, height: 1100), foldVertical: false, gardenAfter: false, gardenFraction: 0.5),
        GardenLayout(size: CGSize(width: 1100, height: 900), foldVertical: true, gardenAfter: true, gardenFraction: 0.5),
        GardenLayout(size: CGSize(width: 1100, height: 900), foldVertical: true, gardenAfter: false, gardenFraction: 0.5)
    ]

    static let samples: [(Double, Double)] = [(0, 0), (1, 0), (0, 1), (1, 1), (0.5, 0.5), (0.25, 0.8), (0.7, -0.1)]

    static func gloom(_ id: Int, _ kind: GloomKind, u: Double, d: Double, lit: Double = 0) -> GloomState {
        GloomState(id: id, kind: kind, u: u, d: d, radius: 0.045, hp: 0.5, maxHP: 0.55, lit: lit, age: 1)
    }

    static func playing(_ mode: PlayMode = .level(3)) -> DawnSnapshot {
        var s = DawnSnapshot(mode: mode, phase: .playing)
        s.band = 0.4
        s.creaseGlow = 1
        s.time = 5
        return s
    }

    static func near(_ a: CGPoint, _ b: CGPoint, _ tol: CGFloat = 0.01) -> Bool {
        abs(a.x - b.x) < tol && abs(a.y - b.y) < tol
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: Mapping

    @Test func gardenFrameMatchesTheLayoutInAllFourLayouts() {
        for layout in SceneTests.layouts {
            let f = GardenFrame(layout: layout)
            for (u, d) in SceneTests.samples {
                let want = layout.scenePoint(layout.point(u: u, d: d))
                let lx = CGFloat(d) * f.depth
                let ly = CGFloat(u) * f.span * f.uFlip
                let got = CGPoint(x: f.origin.x + lx * cos(f.dAngle) - ly * sin(f.dAngle),
                                  y: f.origin.y + lx * sin(f.dAngle) + ly * cos(f.dAngle))
                #expect(SceneTests.near(got, want))
                #expect(SceneTests.near(f.scene(u: u, d: d), want))
            }
            // +d points from the mirror into the garden.
            let g = f.gardenRect
            let m = f.mirrorRect
            let towards = CGVector(dx: g.midX - m.midX, dy: g.midY - m.midY)
            #expect(towards.dx * f.dUnit.dx + towards.dy * f.dUnit.dy > 0)
        }
    }

    @Test func gardenNodeConvertsFloorPointsInEveryLayout() {
        for layout in SceneTests.layouts {
            let scene = GardenScene(layout: layout)
            for (u, d) in SceneTests.samples {
                let want = layout.scenePoint(layout.point(u: u, d: d))
                let local = scene.gardenFrame.local(u: u, d: d)
                let got = scene.gardenNode.convert(local, to: scene)
                #expect(SceneTests.near(got, want, 0.05))
                #expect(SceneTests.near(scene.scenePoint(u: u, d: d), want))
            }
        }
    }

    @Test func floorPointsRoundTripThroughSwiftUISpace() {
        for layout in SceneTests.layouts {
            let scene = GardenScene(layout: layout)
            for (u, d) in SceneTests.samples {
                let p = scene.swiftUIPoint(fromScene: scene.scenePoint(u: u, d: d))
                let back = layout.floorPoint(at: p)
                #expect(abs(back.u - u) < 0.0001)
                #expect(abs(back.d - d) < 0.0001)
            }
        }
        let phone = GardenScene(layout: SceneTests.layouts[0])
        let p = phone.swiftUIPoint(fromScene: CGPoint(x: 10, y: 800))
        #expect(abs(p.x - 10) < 0.001 && abs(p.y - 52) < 0.001)
    }

    @Test func flowerRectsSitInsideTheGardenAtTheFlowerEdge() {
        for layout in SceneTests.layouts {
            let rects = GardenScene.flowerRects(layout: layout)
            #expect(rects.count == 5)
            let garden = layout.gardenRect.insetBy(dx: -0.5, dy: -0.5)
            for (i, r) in rects.enumerated() {
                #expect(garden.contains(r))
                let f = layout.floorPoint(at: CGPoint(x: r.midX, y: r.midY))
                #expect(abs(f.u - (Double(i) + 0.5) / 5) < 0.0001)
                #expect(f.d > 0.85 && f.d < 1)
                if i > 0 { #expect(!r.intersects(rects[i - 1].insetBy(dx: 2, dy: 2))) }
            }
        }
    }

    @Test func bandProfileMatchesTheDesign() {
        #expect(abs(GardenMath.intensity(d: 0.5, band: 0.5) - 1) < 0.0001)
        #expect(abs(GardenMath.intensity(d: 0.549, band: 0.5) - 1) < 0.0001)
        #expect(GardenMath.intensity(d: 0.586, band: 0.5) < 0.0001)
        #expect(GardenMath.intensity(d: 0.4, band: 0.5) < 0.0001)
        let mid = GardenMath.intensity(d: 0.5 + 0.0675, band: 0.5)
        #expect(abs(mid - 0.5) < 0.01)
        var last = 1.0
        for i in 0...20 {
            let v = GardenMath.intensity(d: 0.5 + Double(i) * 0.005, band: 0.5)
            #expect(v <= last + 0.000_001)
            last = v
        }
    }

    @Test func worldsAndDawnFollowTheMode() {
        #expect(GardenMath.world(for: .level(1)) == 1)
        #expect(GardenMath.world(for: .level(10)) == 1)
        #expect(GardenMath.world(for: .level(11)) == 2)
        #expect(GardenMath.world(for: .level(21)) == 3)
        #expect(GardenMath.world(for: .level(30)) == 3)
        #expect(GardenMath.world(for: .endless) == 3)
        #expect(GardenMath.world(for: .daily(day: 40)) == 1)
        var s = DawnSnapshot(mode: .level(4))
        s.sun = 0.6
        #expect(abs(GardenMath.dawn(s) - 0.6) < 0.0001)
        var e = DawnSnapshot(mode: .endless)
        e.sun = 0
        #expect(abs(GardenMath.dawn(e) - 0.3) < 0.0001)
        e.sun = 1
        #expect(GardenMath.dawn(e) < 0.0001)
    }

    @Test func gloomLooksFitTheirCanvas() {
        for k in GloomKind.allCases {
            let look = GloomLook.of(k)
            #expect(look.eyes.count == look.eyeSides.count)
            #expect(!look.eyes.isEmpty && !look.mouths.isEmpty)
            #expect(look.anchor.x > 0 && look.anchor.x < 1 && look.anchor.y > 0 && look.anchor.y < 1)
            for e in look.eyes {
                #expect(look.center.x + e.x - look.eyeRadius > 0)
                #expect(look.center.x + e.x + look.eyeRadius < look.canvas.width)
                #expect(abs(e.y - look.eyeY) < 0.0001)
            }
            #expect(look.hasBrow == (k == .brute))
        }
    }

    // MARK: Textures and pooling

    @Test func aWarmFrameLoopBuildsNoTextures() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing(.level(12))
        var gs: [GloomState] = []
        for (i, k) in GloomKind.allCases.enumerated() {
            gs.append(SceneTests.gloom(i + 1, k, u: 0.1 + 0.18 * Double(i), d: 0.4, lit: 0.8))
        }
        s.glooms = gs
        s.fireflies = [FireflyState(id: 1, u: 0.5, d: 0.3, scorch: 0.5, lit: 0.2, age: 1)]
        scene.render(s, events: [], dt: SceneTests.step)
        let before = GardenArt.builds
        let events: [GameEvent] = [
            .emerged(id: 9, kind: .brute, u: 0.3), .popped(id: 1, kind: .murk, u: 0.1, d: 0.4, chain: 5, points: 20),
            .swept(count: 3, bonus: 90), .split(u: 0.5, d: 0.5), .hopped(id: 5, u: 0.82, d: 0.4, skittish: true),
            .fireflyEmerged(id: 2, u: 0.4), .fireflyScorched(id: 1, u: 0.5, d: 0.3),
            .fireflyDelivered(id: 3, lane: 1, replanted: false, points: 50),
            .flowerEaten(lane: 2, flowersLeft: 4, by: .brute), .chainBroken(was: 5), .chainEnded(was: 2),
            .hint(.followTheBigOnes), .started, .waveUp(2)
        ]
        s.flowers = [true, true, false, true, true]
        scene.render(s, events: events, dt: SceneTests.step)
        for i in 0..<120 {
            s.band = 0.2 + Double(i) / 200
            s.sun = Double(i) / 120
            scene.render(s, events: [], dt: SceneTests.step)
        }
        s.phase = .won
        s.glooms = []
        scene.render(s, events: [.sunrise(stars: 2, flowerBonus: 160)], dt: SceneTests.step)
        for _ in 0..<30 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(GardenArt.builds == before)
    }

    @Test func gloomNodesArePooled() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = (1...10).map { SceneTests.gloom($0, .murk, u: Double($0) / 11, d: 0.3) }
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 10)
        let made = scene.gloomNodesMade
        #expect(made <= 12)
        s.glooms = []
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 0)
        #expect(scene.dyingGloomCount == 10)
        for _ in 0..<60 { scene.render(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.pooledGloomCount >= 10)
        s.glooms = (11...20).map { SceneTests.gloom($0, .wisp, u: Double($0 - 10) / 11, d: 0.2) }
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 10)
        #expect(scene.gloomNodesMade == made)
    }

    @Test func fireflyNodesArePooled() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.fireflies = [FireflyState(id: 1, u: 0.3, d: 0.2), FireflyState(id: 2, u: 0.6, d: 0.5)]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.activeFireflyCount == 2)
        s.fireflies = [FireflyState(id: 2, u: 0.6, d: 0.5)]
        scene.render(s, events: [.fireflyScorched(id: 1, u: 0.3, d: 0.2)], dt: SceneTests.step)
        #expect(scene.activeFireflyCount == 1)
        #expect(scene.fxActiveCount > 0)
        let made = scene.fireflyNodesMade
        s.fireflies = [FireflyState(id: 3, u: 0.5, d: 0.1), FireflyState(id: 4, u: 0.2, d: 0.1)]
        for _ in 0..<60 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.activeFireflyCount == 2)
        #expect(scene.fireflyNodesMade == made)
    }

    // MARK: Event FX

    @Test func aPopBurstsAndReleasesTheGloomAtOnce() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.5, d: 0.5, lit: 1)]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.gloomPoint(id: 1) != nil)
        s.glooms = []
        scene.render(s, events: [.popped(id: 1, kind: .murk, u: 0.5, d: 0.5, chain: 4, points: 17)],
                     dt: SceneTests.step)
        #expect(scene.activeGloomCount == 0)
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.fxActiveCount > 10)
        #expect(scene.floatingTexts.contains("×4"))
    }

    @Test func aLitGloomSqueezesItsEyesShut() {
        let scene = GardenScene(layout: SceneTests.layouts[2])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .brute, u: 0.5, d: 0.4, lit: 0), SceneTests.gloom(2, .murk, u: 0.2, d: 0.4, lit: 1)]
        for _ in 0..<20 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(!scene.gloomSqueezing(id: 1))
        #expect(scene.gloomSqueezing(id: 2))
        #expect(scene.fxActiveCount > 0)
    }

    @Test func sweepsShowWordsExceptInAttractMode() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        let s = SceneTests.playing()
        scene.render(s, events: [.swept(count: 3, bonus: 90)], dt: SceneTests.step)
        #expect(scene.floatingTexts.contains("Sweep!"))
        scene.render(s, events: [.swept(count: 4, bonus: 120)], dt: SceneTests.step)
        #expect(scene.floatingTexts.contains("Sweep ×4!"))
        #expect(!scene.floatingTexts.contains("Sweep!"))

        let quiet = GardenScene(layout: SceneTests.layouts[0])
        quiet.attract = true
        quiet.render(s, events: [.swept(count: 3, bonus: 90), .waveUp(3),
                                 .popped(id: 7, kind: .wisp, u: 0.4, d: 0.4, chain: 6, points: 10)],
                     dt: SceneTests.step)
        #expect(quiet.floatingTexts.isEmpty)
        #expect(quiet.fxActiveCount > 0)
    }

    @Test func sunriseEvaporatesEveryGloomAndFloodsTheGarden() {
        let scene = GardenScene(layout: SceneTests.layouts[1])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.2, d: 0.3), SceneTests.gloom(2, .hopper, u: 0.5, d: 0.6),
                    SceneTests.gloom(3, .splitter, u: 0.8, d: 0.4)]
        scene.render(s, events: [], dt: SceneTests.step)
        s.phase = .won
        s.sun = 1
        s.glooms = []
        scene.render(s, events: [.sunrise(stars: 3, flowerBonus: 200)], dt: SceneTests.step)
        #expect(scene.dyingGloomCount == 3)
        #expect(scene.floodLevel > 0)
        for _ in 0..<150 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.floodLevel > 0.05)
    }

    @Test func nightWinsRollsTheDarknessIn() {
        let scene = GardenScene(layout: SceneTests.layouts[3])
        var s = SceneTests.playing()
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.nightLevel < 0.001)
        s.phase = .lost
        s.flowers = [false, false, false, false, false]
        scene.render(s, events: [.nightWins], dt: SceneTests.step)
        for _ in 0..<240 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.nightLevel > 0.99)
        #expect(scene.flowersStanding == [false, false, false, false, false])
    }

    @Test func anEatenFlowerWiltsAndShakesTheCanvas() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.1, d: 0.97)]
        scene.render(s, events: [], dt: SceneTests.step)
        s.glooms = []
        s.flowers = [false, true, true, true, true]
        scene.render(s, events: [.flowerEaten(lane: 0, flowersLeft: 4, by: .murk)], dt: SceneTests.step)
        #expect(scene.flowersStanding[0] == false)
        #expect(scene.dyingGloomCount == 1)
        let o = scene.shakeOffset
        #expect(abs(o.x) + abs(o.y) > 0.01)

        let calm = GardenScene(layout: SceneTests.layouts[0])
        calm.reduceMotion = true
        var c = SceneTests.playing()
        calm.render(c, events: [], dt: SceneTests.step)
        c.flowers = [false, true, true, true, true]
        calm.render(c, events: [.flowerEaten(lane: 0, flowersLeft: 4, by: .murk)], dt: SceneTests.step)
        #expect(abs(calm.shakeOffset.x) + abs(calm.shakeOffset.y) < 0.0001)
    }

    @Test func aDeliveredFireflyReplantsItsFlower() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.flowers = [true, true, false, true, true]
        s.fireflies = [FireflyState(id: 1, u: 0.5, d: 0.95)]
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.flowersStanding[2] == false)
        s.fireflies = []
        s.flowers = [true, true, true, true, true]
        scene.render(s, events: [.fireflyDelivered(id: 1, lane: 2, replanted: true, points: 0)], dt: SceneTests.step)
        #expect(scene.flowersStanding[2])
        #expect(scene.activeFireflyCount == 0)
        #expect(scene.fxActiveCount > 0)
    }

    @Test func aNewSessionClearsEverything() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.time = 30
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.5, d: 0.5)]
        scene.render(s, events: [.popped(id: 9, kind: .murk, u: 0.3, d: 0.3, chain: 3, points: 10)],
                     dt: SceneTests.step)
        #expect(scene.fxActiveCount > 0)
        var fresh = DawnSnapshot(mode: .level(3))
        fresh.time = 0
        scene.render(fresh, events: [], dt: SceneTests.step)
        #expect(scene.activeGloomCount == 0)
        #expect(scene.dyingGloomCount == 0)
        #expect(scene.floatingTexts.isEmpty)
    }

    // MARK: Mirror

    @Test func theLeverFollowsTheBandTowardsTheCrease() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.band = -0.2
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(!scene.leverShowing)
        scene.showsLever = true
        scene.render(s, events: [], dt: SceneTests.step)
        #expect(scene.leverShowing)
        let p0 = scene.leverPoint
        s.band = 1
        scene.render(s, events: [], dt: SceneTests.step)
        let p1 = scene.leverPoint
        let crease = scene.scenePoint(u: 0.5, d: 0)
        #expect(SceneTests.distance(p1, crease) + 20 < SceneTests.distance(p0, crease))
        #expect(scene.mirrorGlass.contains(p0) && scene.mirrorGlass.contains(p1))
    }

    @Test func theSunRisesWithTheLevel() {
        for layout in SceneTests.layouts {
            let scene = GardenScene(layout: layout)
            var s = SceneTests.playing(.level(25))
            s.sun = 0
            scene.render(s, events: [], dt: SceneTests.step)
            let low = scene.sunPoint
            s.sun = 1
            scene.render(s, events: [], dt: SceneTests.step)
            let high = scene.sunPoint
            #expect(high.y > low.y + 20)
            #expect(scene.mirrorGlass.contains(high))
            #expect(scene.mirrorWorld == 3)
        }
    }

    // MARK: Layout, touches, budget

    @Test func reLayoutKeepsTheGloomsAndMovesThem() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing()
        s.glooms = [SceneTests.gloom(1, .murk, u: 0.3, d: 0.4), SceneTests.gloom(2, .brute, u: 0.7, d: 0.6)]
        scene.render(s, events: [], dt: SceneTests.step)
        for layout in SceneTests.layouts.reversed() {
            scene.apply(layout: layout)
            #expect(scene.size == layout.size)
            scene.render(s, events: [], dt: SceneTests.step)
            #expect(scene.activeGloomCount == 2)
            if let p = scene.gloomPoint(id: 1) {
                #expect(SceneTests.near(p, scene.scenePoint(u: 0.3, d: 0.4), 0.5))
            } else {
                Issue.record("gloom 1 lost on re-layout")
            }
            let local = scene.gardenFrame.local(u: 0.9, d: 0.1)
            let want = layout.scenePoint(layout.point(u: 0.9, d: 0.1))
            #expect(SceneTests.near(scene.gardenNode.convert(local, to: scene), want, 0.05))
        }
    }

    @Test func theFrameLoopAsksTheDriver() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        let driver = SceneFakeDriver()
        driver.snapshot = SceneTests.playing()
        driver.events = [.swept(count: 3, bonus: 90)]
        scene.driver = driver
        scene.update(10)
        scene.update(10.008)
        #expect(driver.advances == 2)
        #expect(scene.frameIndex == 2)
        #expect(scene.floatingTexts.contains("Sweep!"))
    }

    @Test func aBusyFrameStaysInsideTheNodeBudget() {
        let scene = GardenScene(layout: SceneTests.layouts[0])
        var s = SceneTests.playing(.level(15))
        var gs: [GloomState] = []
        for i in 0..<12 {
            let k = GloomKind.allCases[i % GloomKind.allCases.count]
            gs.append(SceneTests.gloom(i + 1, k, u: 0.04 + Double(i) * 0.08, d: 0.15 + Double(i % 4) * 0.2))
        }
        s.glooms = gs
        s.fireflies = [FireflyState(id: 1, u: 0.2, d: 0.3), FireflyState(id: 2, u: 0.5, d: 0.6),
                       FireflyState(id: 3, u: 0.8, d: 0.2)]
        scene.render(s, events: [.popped(id: 99, kind: .brute, u: 0.5, d: 0.5, chain: 6, points: 70)],
                     dt: SceneTests.step)
        for _ in 0..<10 { scene.render(s, events: [], dt: SceneTests.step) }
        #expect(scene.drawnNodeCount <= 300)
        #expect(scene.nodeCount <= 460)
    }
}
