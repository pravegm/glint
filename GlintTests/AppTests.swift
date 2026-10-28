import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Glint

// App engineer's tests (design/ROUND-1.md App 6): pure rules only. Routing, pause / resume, cover detection, unlocks,
// stars aggregation, demo argument parsing, the progress codec.

private func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) <= tolerance }
private func near(_ a: CGFloat, _ b: CGFloat, _ tolerance: CGFloat = 0.001) -> Bool { abs(a - b) <= tolerance }

/// A progress with stars on levels 1…n (all 3 by default).
private func progress(won n: Int, stars: Int = 3) -> ProgressData {
    var d = ProgressData()
    for i in 0..<min(n, d.levelStars.count) { d.levelStars[i] = stars }
    return d
}

struct RoutingTests {
    @Test func backGoesHomeExceptAbout() {
        #expect(AppRules.back(from: .levels) == .home)
        #expect(AppRules.back(from: .settings) == .home)
        #expect(AppRules.back(from: .results) == .home)
        #expect(AppRules.back(from: .play) == .home)
        #expect(AppRules.back(from: .home) == .home)
        #expect(AppRules.back(from: .about) == .settings)
    }

    @Test func routeNamesAreTheDemoScreenKeys() {
        for route in AppRoute.allCases {
            #expect(DemoMode.Screen(rawValue: route.rawValue) != nil)
        }
        #expect(AppRoute.play.showsSession)
        #expect(AppRoute.results.showsSession)
        #expect(!AppRoute.home.showsSession)
        #expect(!AppRoute.levels.showsSession)
    }

    @Test func everyLevelStartsClosedOnADuo() {
        #expect(AppRules.startsClosed(hingeDriven: true, isShut: false))
        #expect(!AppRules.startsClosed(hingeDriven: true, isShut: true))
        #expect(!AppRules.startsClosed(hingeDriven: false, isShut: false))
    }

    @Test func waitsBrieflyForAHingeThatMightReport() {
        // A Duo seen before, the Duo CI launch, or the first seconds after launch: wait for the first report.
        #expect(AppRules.needsHingeCheck(hasHinge: false, pilotOrFixed: false, hingeSeen: true, duoLog: false,
                                         sinceLaunch: 100))
        #expect(AppRules.needsHingeCheck(hasHinge: false, pilotOrFixed: false, hingeSeen: false, duoLog: true,
                                         sinceLaunch: 100))
        #expect(AppRules.needsHingeCheck(hasHinge: false, pilotOrFixed: false, hingeSeen: false, duoLog: false,
                                         sinceLaunch: 0.3))
        // A phone long after launch, a hinge already reporting, or a demo pilot: no wait.
        #expect(!AppRules.needsHingeCheck(hasHinge: false, pilotOrFixed: false, hingeSeen: false, duoLog: false,
                                          sinceLaunch: 100))
        #expect(!AppRules.needsHingeCheck(hasHinge: true, pilotOrFixed: false, hingeSeen: true, duoLog: true,
                                          sinceLaunch: 0))
        #expect(!AppRules.needsHingeCheck(hasHinge: false, pilotOrFixed: true, hingeSeen: true, duoLog: true,
                                          sinceLaunch: 0))
        let phone = GardenLayout.make(size: CGSize(width: 402, height: 874), isDuo: false, swapHalves: false)
        #expect(AppRules.prompt(stage: .checking, phase: nil, hingeDriven: false, layout: phone) == nil)
        #expect(AppRules.coverLine(route: .play, stage: .checking, phase: nil, paused: false, score: 0) == .openToStart)
    }

    @Test func promptsFollowTheStage() {
        let phone = GardenLayout.make(size: CGSize(width: 402, height: 874), isDuo: false, swapHalves: false)
        #expect(AppRules.prompt(stage: .closeFirst, phase: nil, hingeDriven: true, layout: phone) == .closeToStart)
        #expect(AppRules.prompt(stage: .live, phase: .waiting, hingeDriven: true, layout: phone) == .openToLight)
        #expect(AppRules.prompt(stage: .live, phase: .waiting, hingeDriven: false, layout: phone)
                == .drag(direction: "down"))
        #expect(AppRules.prompt(stage: .live, phase: .playing, hingeDriven: true, layout: phone) == nil)
        #expect(AppRules.prompt(stage: .live, phase: nil, hingeDriven: false, layout: phone) == nil)
        #expect(PromptLine.closeToStart.text == "Close the phone to start")
        #expect(PromptLine.openToLight.text == "Open the phone to let the light in")
        #expect(PromptLine.drag(direction: "down").text == "Drag down to let the light in")
        #expect(PromptLine.logWord(nil) == "none")
        #expect(PromptLine.closeToStart.logWord == "close")
        #expect(PromptLine.openToLight.logWord == "open")
        #expect(PromptLine.drag(direction: "up").logWord == "drag")
    }

    @Test func dragWordFollowsTheLayout() {
        let size = CGSize(width: 400, height: 800)
        let down = GardenLayout(size: size, foldVertical: false, gardenAfter: true)
        let up = GardenLayout(size: size, foldVertical: false, gardenAfter: false)
        let right = GardenLayout(size: size, foldVertical: true, gardenAfter: true)
        let left = GardenLayout(size: size, foldVertical: true, gardenAfter: false)
        #expect(AppRules.dragDirection(down) == "down")
        #expect(AppRules.dragDirection(up) == "up")
        #expect(AppRules.dragDirection(right) == "right")
        #expect(AppRules.dragDirection(left) == "left")
    }

    @Test func dtIsClamped() {
        #expect(near(AppRules.clampDT(0.5), 1.0 / 30.0))
        #expect(near(AppRules.clampDT(0.01), 0.01))
        #expect(AppRules.clampDT(-1) == 0)
        #expect(AppRules.clampDT(Double.nan) == 0)
        #expect(AppRules.clampDT(Double.infinity) == 0)
    }

    @Test func coverLines() {
        #expect(AppRules.coverLine(route: .home, stage: .live, phase: nil, paused: false, score: 0) == .openToPlay)
        #expect(AppRules.coverLine(route: .play, stage: .closeFirst, phase: nil, paused: false, score: 0) == .openToStart)
        #expect(AppRules.coverLine(route: .play, stage: .live, phase: .waiting, paused: false, score: 0) == .openToStart)
        #expect(AppRules.coverLine(route: .play, stage: .live, phase: .playing, paused: true, score: 120)
                == .paused(score: 120))
        #expect(CoverLine.paused(score: 1).text == "Paused · open the phone to carry on")
        #expect(CoverLine.openToPlay.text == "Open the phone to play")
    }

    @Test func modeTitlesAndNames() {
        #expect(AppRules.modeTitle(.endless) == "Long Night")
        #expect(AppRules.modeTitle(.daily(day: 3)) == "Today's Dawn")
        #expect(AppRules.modeTitle(.level(1)).hasPrefix("Level 1 · "))
        #expect(AppRules.modeName(.level(4)) == "level-4")
        #expect(AppRules.modeName(.daily(day: 301)) == "daily-301")
        #expect(AppRules.modeName(.endless) == "endless")
        #expect(AppRules.phaseName(nil) == "none")
        #expect(AppRules.phaseName(.playing) == "playing")
    }

    @Test func seedsAreStableForLevelsAndTheDay() {
        #expect(AppRules.seed(for: .level(3), rolling: 99) == AppRules.seed(for: .level(3), rolling: 12345))
        #expect(AppRules.seed(for: .daily(day: 40), rolling: 1) == DailySeed.seed(day: 40))
        #expect(AppRules.seed(for: .endless, rolling: 77) == 77)
        #expect(AppRules.seed(for: .endless, rolling: 0) != 0)
    }

    @Test func groupedNumbers() {
        #expect(AppRules.grouped(0) == "0")
        #expect(AppRules.grouped(999) == "999")
        #expect(AppRules.grouped(1_000) == "1,000")
        #expect(AppRules.grouped(12_345_678) == "12,345,678")
    }

    @Test func hudSitsInsideTheCanvasAtTheFlowerEdge() {
        let phone = GardenLayout.make(size: CGSize(width: 402, height: 874), isDuo: false, swapHalves: false)
        let item = CGSize(width: 120, height: 52)
        let insets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        let left = AppRules.hudCenter(u: 0, item: item, layout: phone, insets: insets, margin: 10)
        let right = AppRules.hudCenter(u: 1, item: item, layout: phone, insets: insets, margin: 10)
        // Bottom corners (the flower edge is the bottom on a phone), inside the safe area.
        #expect(left.x < 201 && right.x > 201)
        #expect(left.y > phone.gardenRect.midY)
        #expect(left.y + item.height / 2 <= 874 - 34)
        #expect(left.x - item.width / 2 >= 0)
        #expect(right.x + item.width / 2 <= 402)
        // Book pose, garden on the right: the corners are on the right edge.
        let book = GardenLayout.make(size: CGSize(width: 1100, height: 800), isDuo: true, swapHalves: false)
        let top = AppRules.hudCenter(u: 0, item: item, layout: book, insets: EdgeInsets(), margin: 10)
        #expect(top.x > 1100 - 120)
        #expect(top.y < 400)
    }

    @Test func levelMapPointsFitAndDontOverlap() {
        for size in [CGSize(width: 360, height: 520), CGSize(width: 900, height: 420)] {
            let pts = LevelMapGeometry.points(count: 10, in: size)
            let node = LevelMapGeometry.nodeSize(count: 10, in: size)
            #expect(pts.count == 10)
            for p in pts {
                #expect(p.x >= 0 && p.x <= size.width)
                #expect(p.y >= 0 && p.y <= size.height)
            }
            for i in 0..<pts.count {
                for j in (i + 1)..<pts.count {
                    let dx = pts[i].x - pts[j].x
                    let dy = pts[i].y - pts[j].y
                    #expect((dx * dx + dy * dy).squareRoot() >= node * 0.9)
                }
            }
        }
        #expect(LevelMapGeometry.points(count: 0, in: CGSize(width: 100, height: 100)).isEmpty)
    }
}

struct PauseRulesTests {
    private func input(_ phase: SessionPhase, shut: Bool, resume: Bool, hinge: Bool = true) -> PauseInput {
        PauseInput(phase: phase, hingeDriven: hinge, hingeShut: shut, canResume: resume)
    }

    @Test func shutPausesOnlyWhilePlaying() {
        let waiting = PauseRules.step(PauseFlags(), grace: 0, input: input(.waiting, shut: true, resume: false), dt: 0.01)
        #expect(!waiting.flags.shut)
        let playing = PauseRules.step(PauseFlags(), grace: 0, input: input(.playing, shut: true, resume: false), dt: 0.01)
        #expect(playing.flags.shut)
        #expect(playing.flags.isPaused)
        #expect(playing.flags.reason == "shut")
    }

    @Test func dragNeverShutPauses() {
        let r = PauseRules.step(PauseFlags(), grace: 0, input: input(.playing, shut: true, resume: false, hinge: false),
                                dt: 0.01)
        #expect(!r.flags.isPaused)
    }

    @Test func openingResumesWithGrace() {
        var f = PauseFlags()
        f.shut = true
        let still = PauseRules.step(f, grace: 0, input: input(.playing, shut: true, resume: false), dt: 0.1)
        #expect(still.flags.shut)
        let opened = PauseRules.step(f, grace: 0, input: input(.playing, shut: false, resume: true), dt: 0.1)
        #expect(!opened.flags.shut)
        #expect(near(opened.grace, Tuning.resumeGrace))
        #expect(PauseRules.isFrozen(opened.flags, grace: opened.grace))
        // The grace counts down, then play runs.
        var g = opened.grace
        var flags = opened.flags
        for _ in 0..<10 {
            let r = PauseRules.step(flags, grace: g, input: input(.playing, shut: false, resume: true), dt: 0.1)
            flags = r.flags
            g = r.grace
        }
        #expect(g == 0)
        #expect(!PauseRules.isFrozen(flags, grace: g))
    }

    @Test func halfOpenIsNotAPause() {
        // Never a pause near 90°: an open hinge (not shut) never pauses.
        let r = PauseRules.step(PauseFlags(), grace: 0, input: input(.playing, shut: false, resume: true), dt: 0.02)
        #expect(!r.flags.isPaused)
        #expect(r.grace == 0)
    }

    @Test func menuPauseNeedsResume() {
        var f = PauseFlags()
        f.menu = true
        let r = PauseRules.step(f, grace: 0, input: input(.playing, shut: false, resume: true), dt: 0.1)
        #expect(r.flags.menu)
        #expect(r.grace == 0)
        let resumed = PauseRules.resumedFromMenu(r.flags)
        #expect(!resumed.flags.isPaused)
        #expect(near(resumed.grace, Tuning.resumeGrace))
    }

    @Test func openingWhileMenuPausedKeepsTheMenu() {
        var f = PauseFlags()
        f.menu = true
        f.shut = true
        let r = PauseRules.step(f, grace: 0, input: input(.playing, shut: false, resume: true), dt: 0.1)
        #expect(!r.flags.shut)
        #expect(r.flags.menu)
        #expect(r.grace == 0)
    }

    @Test func inactiveAndBackground() {
        let off = PauseRules.deactivated(PauseFlags())
        #expect(off.inactive && off.isPaused)
        let back = PauseRules.activated(off, wentToBackground: false, phase: .playing, hingeShut: false)
        #expect(!back.flags.isPaused)
        #expect(near(back.grace, Tuning.resumeGrace))
        let fromBackground = PauseRules.activated(off, wentToBackground: true, phase: .playing, hingeShut: false)
        #expect(fromBackground.flags.menu)
        #expect(fromBackground.grace == 0)
        let shutPhone = PauseRules.activated(off, wentToBackground: true, phase: .playing, hingeShut: true)
        #expect(!shutPhone.flags.menu)
        let notInactive = PauseRules.activated(PauseFlags(), wentToBackground: true, phase: .playing, hingeShut: false)
        #expect(notInactive.flags == PauseFlags())
    }

    @Test func lostHingeNeverStaysShut() {
        var f = PauseFlags()
        f.shut = true
        let r = PauseRules.step(f, grace: 0, input: input(.playing, shut: true, resume: false, hinge: false), dt: 0.1)
        #expect(!r.flags.shut)
    }
}

struct CoverDetectionTests {
    @Test func onlyAKnownDuoGetsTheCover() {
        let small = CGSize(width: 375, height: 667)   // an iPhone SE is this small too
        #expect(!AppRules.isCover(window: small, hingeSeen: false))
        #expect(AppRules.isCover(window: small, hingeSeen: true))
        #expect(!AppRules.isCover(window: CGSize(width: 1100, height: 820), hingeSeen: true))
        #expect(!AppRules.isCover(window: CGSize(width: 402, height: 874), hingeSeen: true))
        #expect(!AppRules.isCover(window: .zero, hingeSeen: true))
    }

    @Test func duoShapes() {
        #expect(AppRules.looksLikeDuoInner(CGSize(width: 1100, height: 820)))
        #expect(AppRules.looksLikeDuoInner(CGSize(width: 820, height: 1100)))
        #expect(!AppRules.looksLikeDuoInner(CGSize(width: 402, height: 874)))
        #expect(!AppRules.looksLikeDuoInner(CGSize(width: 500, height: 600)))
        #expect(AppRules.isDuo(window: CGSize(width: 402, height: 874), hingeSeen: false, demoFold: true))
        #expect(AppRules.isDuo(window: CGSize(width: 402, height: 874), hingeSeen: true, demoFold: false))
        #expect(!AppRules.isDuo(window: CGSize(width: 402, height: 874), hingeSeen: false, demoFold: false))
    }
}

struct UnlockTests {
    @Test func freshProgress() {
        let d = ProgressData()
        #expect(ProgressRules.isUnlocked(level: 1, d))
        #expect(!ProgressRules.isUnlocked(level: 2, d))
        #expect(!ProgressRules.isUnlocked(level: 11, d))
        #expect(!ProgressRules.isUnlocked(level: 0, d))
        #expect(!ProgressRules.isUnlocked(level: 31, d))
        #expect(ProgressRules.nextLevel(d) == 1)
        #expect(!ProgressRules.dailyUnlocked(d))
        #expect(!ProgressRules.endlessUnlocked(d, now: Date()))
    }

    @Test func levelsOpenOneAtATime() {
        let d = progress(won: 3, stars: 1)
        #expect(ProgressRules.isUnlocked(level: 4, d))
        #expect(!ProgressRules.isUnlocked(level: 5, d))
        #expect(ProgressRules.nextLevel(d) == 4)
    }

    @Test func dailyAfterLevel3EndlessAfterLevel5() {
        #expect(!ProgressRules.dailyUnlocked(progress(won: 2)))
        #expect(ProgressRules.dailyUnlocked(progress(won: 3)))
        #expect(!ProgressRules.endlessUnlocked(progress(won: 4), now: Date()))
        #expect(ProgressRules.endlessUnlocked(progress(won: 5), now: Date()))
    }

    @Test func endlessAlsoOpensADayAfterTheFirstLaunch() {
        var d = ProgressData()
        let now = Date()
        d.firstLaunch = now.timeIntervalSince1970 - 3_600
        #expect(!ProgressRules.endlessUnlocked(d, now: now))
        d.firstLaunch = now.timeIntervalSince1970 - 90_000
        #expect(ProgressRules.endlessUnlocked(d, now: now))
    }

    @Test func worldsOpenAtTwoThirdsOfTheStars() {
        #expect(ProgressRules.gate(world: 2) == 20)
        #expect(ProgressRules.gate(world: 3) == 20)
        #expect(ProgressRules.gate(world: 1) == 0)
        // All of world 1 won with 1 star each: 10 stars, not enough.
        let few = progress(won: 10, stars: 1)
        #expect(!ProgressRules.isWorldOpen(2, few))
        #expect(!ProgressRules.isUnlocked(level: 11, few))
        #expect(ProgressRules.starsMissing(toOpen: 2, few) == 10)
        // 2 stars each: exactly 20.
        let enough = progress(won: 10, stars: 2)
        #expect(ProgressRules.isWorldOpen(2, enough))
        #expect(ProgressRules.isUnlocked(level: 11, enough))
        #expect(!ProgressRules.isUnlocked(level: 12, enough))
        #expect(ProgressRules.starsMissing(toOpen: 2, enough) == 0)
        #expect(!ProgressRules.isWorldOpen(3, enough))
    }

    @Test func nextLevelWhenEverythingIsWon() {
        let all = progress(won: 30)
        #expect(ProgressRules.nextLevel(all) == 30)
        #expect(ProgressRules.unlockSet(all, now: Date()).contains(.world(3)))
    }
}

struct StarsTests {
    @Test func aggregation() {
        var d = ProgressData()
        d.levelStars[0] = 3
        d.levelStars[1] = 2
        d.levelStars[10] = 1
        #expect(ProgressRules.totalStars(d) == 6)
        #expect(ProgressRules.stars(d, world: 1) == 5)
        #expect(ProgressRules.stars(d, world: 2) == 1)
        #expect(ProgressRules.stars(d, world: 3) == 0)
        #expect(ProgressRules.stars(d, world: 9) == 0)
        #expect(ProgressRules.maxStars(world: 1) == 30)
        #expect(ProgressRules.maxTotalStars() == 90)
        #expect(ProgressRules.stars(d, level: 99) == 0)
    }

    @Test func recordingKeepsTheBestStarsAndScore() {
        var d = ProgressData()
        let now = Date()
        let first = ProgressRules.record(&d, mode: .level(1), won: true, stars: 2, score: 500, now: now)
        #expect(first.starsAfter == 2)
        #expect(first.isNewBest)
        #expect(!first.showsNewBest)
        #expect(first.nextLevel == 2)
        let worse = ProgressRules.record(&d, mode: .level(1), won: true, stars: 1, score: 300, now: now)
        #expect(worse.starsAfter == 2)
        #expect(worse.best == 500)
        #expect(!worse.isNewBest)
        let better = ProgressRules.record(&d, mode: .level(1), won: true, stars: 3, score: 900, now: now)
        #expect(better.starsAfter == 3)
        #expect(better.showsNewBest)
        #expect(better.previousBest == 500)
        // A loss never adds stars.
        let lost = ProgressRules.record(&d, mode: .level(2), won: false, stars: 3, score: 50, now: now)
        #expect(lost.starsAfter == 0)
        #expect(lost.nextLevel == nil)
        #expect(ProgressRules.stars(d, level: 1) == 3)
    }

    @Test func recordingNamesWhatOpened() {
        var d = progress(won: 2)
        let r = ProgressRules.record(&d, mode: .level(3), won: true, stars: 3, score: 400, now: Date())
        #expect(r.unlocked.contains(.daily))
        var e = progress(won: 4)
        let r2 = ProgressRules.record(&e, mode: .level(5), won: true, stars: 3, score: 400, now: Date())
        #expect(r2.unlocked.contains(.endless))
        var w = progress(won: 9, stars: 2)
        let r3 = ProgressRules.record(&w, mode: .level(10), won: true, stars: 2, score: 400, now: Date())
        #expect(r3.unlocked.contains(.world(2)))
        #expect(r3.nextLevel == 11)
    }

    @Test func endlessAndDailyBests() {
        var d = ProgressData()
        let now = Date()
        _ = ProgressRules.record(&d, mode: .endless, won: false, stars: 0, score: 1_200, now: now)
        let r = ProgressRules.record(&d, mode: .endless, won: false, stars: 0, score: 800, now: now)
        #expect(r.best == 1_200)
        #expect(d.endlessBest == 1_200)
        _ = ProgressRules.record(&d, mode: .daily(day: 10), won: true, stars: 0, score: 700, now: now)
        let r2 = ProgressRules.record(&d, mode: .daily(day: 10), won: true, stars: 0, score: 900, now: now)
        #expect(r2.showsNewBest)
        #expect(ProgressRules.dailyBest(d, day: 10) == 900)
        #expect(ProgressRules.dailyBest(d, day: 11) == 0)
        #expect(d.bestDailyEver == 900)
    }
}

struct DemoParseTests {
    @Test func keys() {
        let d = DemoMode.parse("screen=play;level=4;t=12.5;skill=0.6;band=0.4;fold=1;swap=1;results=lost;"
                               + "hint=followTheBigOnes;progress=mid;sound=0;seed=9;duolog=1")
        #expect(d.screen == .play)
        #expect(d.level == 4)
        #expect(d.playTo.map { near($0, 12.5) } == true)
        #expect(d.skill.map { near($0, 0.6) } == true)
        #expect(d.pinBand.map { near($0, 0.4) } == true)
        #expect(d.fold)
        #expect(d.swap)
        #expect(d.outcome == .lost)
        #expect(d.hint == .followTheBigOnes)
        #expect(d.progress == .mid)
        #expect(!d.sound)
        #expect(d.seed == 9)
        #expect(d.duoLog)
        #expect(d.forcesPilot)
        #expect(d.playMode(today: 5) == .level(4))
    }

    @Test func defaultsAndImpliedScreens() {
        let empty = DemoMode.parse("")
        #expect(empty.effectiveScreen == .home)
        #expect(!empty.fold)
        #expect(empty.sound)
        #expect(near(empty.pilotSkill, DemoMode.defaultSkill))
        #expect(DemoMode.parse("mode=endless").effectiveScreen == .play)
        #expect(DemoMode.parse("mode=endless").playMode(today: 1) == .endless)
        #expect(DemoMode.parse("mode=daily").playMode(today: 77) == .daily(day: 77))
        #expect(DemoMode.parse("level=3").effectiveScreen == .play)
        #expect(DemoMode.parse("screen=icon").effectiveScreen == .icon)
        #expect(DemoMode.parse("screen=cover").effectiveScreen == .cover)
    }

    @Test func clampsAndJunk() {
        let d = DemoMode.parse("level=99;skill=4;band=-3;t=-2;screen=nope;bogus=1;;=x")
        #expect(d.level == LevelBook.count)
        #expect(d.skill.map { near($0, 1) } == true)
        #expect(d.pinBand.map { near($0, Tuning.bandMin) } == true)
        #expect(d.playTo.map { near($0, 0) } == true)
        #expect(d.screen == nil)
    }

    @Test func freezeKeys() {
        let d = DemoMode.parse("freezeOn=sunrise;freezeAfter=8")
        #expect(d.stopOn == .sunrise)
        #expect(d.holdAfter.map { near($0, 8) } == true)
        #expect(d.wantsFallbackPilot)
        #expect(!d.forcesPilot)
        #expect(d.effectiveScreen == .play)
        #expect(DemoMode.Stop.sunrise.matches(.sunrise(stars: 3, flowerBonus: 200)))
        #expect(DemoMode.Stop.pop.matches(.popped(id: 1, kind: .murk, u: 0.5, d: 0.5, chain: 1, points: 10)))
        #expect(!DemoMode.Stop.pop.matches(.nightWins))
        #expect(DemoMode.parse("freezeOn=SWEEP").stopOn == .sweep)
        #expect(DemoMode.parse("prompt=close").prompt == .close)
    }

    @Test func presetsAgreeWithTheirUnlocks() {
        let now = Date()
        let mid = DemoPresets.progress(.mid, now: now)
        #expect(ProgressRules.isWorldOpen(2, mid))
        #expect(ProgressRules.endlessUnlocked(mid, now: now))
        #expect(ProgressRules.dailyUnlocked(mid))
        #expect(ProgressRules.nextLevel(mid) == 14)
        let done = DemoPresets.progress(.done, now: now)
        #expect(ProgressRules.isWorldOpen(3, done))
        #expect(ProgressRules.totalStars(done) == 86)
        let fresh = DemoPresets.progress(.fresh, now: now)
        #expect(ProgressRules.totalStars(fresh) == 0)
    }
}

struct ProgressCodecTests {
    @Test func roundTrip() {
        var d = ProgressData()
        d.levelStars[0] = 3
        d.levelBest[0] = 1_234
        d.endlessBest = 9_000
        d.dailyBests["300"] = 777
        d.seenHints = ["lightTheShadows"]
        d.hingeSeen = true
        d.firstLaunch = 1_800_000_000
        let raw = ProgressStore.encode(d)
        #expect(raw != nil)
        let back = raw.flatMap { ProgressStore.decode($0) }
        #expect(back == d)
    }

    @Test func tolerantDecode() {
        let json = #"{"levelStars":[3,9,-1],"endlessBest":"oops","dailyBests":{"5":-20},"lastLevel":400,"future":true}"#
        let d = ProgressStore.decode(Data(json.utf8))
        #expect(d != nil)
        guard let d else { return }
        #expect(d.levelStars.count == LevelBook.count)
        #expect(d.levelStars[0] == 3)
        #expect(d.levelStars[1] == 3)
        #expect(d.levelStars[2] == 0)
        #expect(d.endlessBest == 0)
        #expect(d.dailyBests["5"] == 0)
        #expect(d.lastLevel == LevelBook.count)
        #expect(d.levelBest.count == LevelBook.count)
    }

    @Test func emptyObjectDecodesToDefaults() {
        let d = ProgressStore.decode(Data("{}".utf8))
        #expect(d == ProgressData())
    }

    @Test func settingsRoundTripAndTolerance() {
        var s = SettingsData()
        s.soundOn = false
        s.swapHalves = true
        let back = SettingsStore.encode(s).flatMap { SettingsStore.decode($0) }
        #expect(back == s)
        let partial = SettingsStore.decode(Data(#"{"musicOn":false,"hapticsOn":"x"}"#.utf8))
        #expect(partial?.musicOn == false)
        #expect(partial?.hapticsOn == true)
        #expect(partial?.soundOn == true)
    }

    @Test @MainActor func inMemoryStoreRecordsAndRemembersHints() {
        let store = ProgressStore(inMemory: ProgressData())
        let r = store.record(mode: .level(1), won: true, stars: 3, score: 640, now: Date())
        #expect(r.starsAfter == 3)
        #expect(store.totalStars == 3)
        #expect(store.nextLevel == 2)
        #expect(!store.hasSeen(.lightTheShadows))
        store.markSeen(.lightTheShadows)
        #expect(store.hasSeen(.lightTheShadows))
        store.noteHingeSeen()
        #expect(store.data.hingeSeen)
        store.noteStarted(.level(2))
        #expect(store.data.lastLevel == 2)
    }
}

struct HintAndQueueTests {
    @Test func hintCopyAndDone() {
        #expect(HintRules.text(.lightTheShadows) == "Light the shadows.")
        #expect(HintRules.text(.followTheBigOnes) == "Follow the big ones.")
        #expect(HintRules.text(.spareTheFireflies) == "Spare the fireflies.")
        let pop = GameEvent.popped(id: 1, kind: .murk, u: 0.5, d: 0.5, chain: 1, points: 10)
        let brute = GameEvent.popped(id: 2, kind: .brute, u: 0.5, d: 0.5, chain: 1, points: 40)
        #expect(HintRules.isDone(.lightTheShadows, by: pop))
        #expect(!HintRules.isDone(.followTheBigOnes, by: pop))
        #expect(HintRules.isDone(.followTheBigOnes, by: brute))
        #expect(HintRules.isDone(.spareTheFireflies, by: .fireflyDelivered(id: 1, lane: 0, replanted: true, points: 0)))
        #expect(HintRules.shouldShow(.hoppers, seen: []))
        #expect(!HintRules.shouldShow(.hoppers, seen: ["hoppers"]))
        #expect(HintRules.all.count == 5)
    }

    @Test func gameCenterQueue() {
        let a = GameCenterManager.encode(leaderboard: "glint.endless", score: 100, day: nil, token: "a")
        let b = GameCenterManager.encode(leaderboard: "glint.endless", score: 300, day: nil, token: "b")
        let c = GameCenterManager.encode(leaderboard: "glint.endless", score: 200, day: nil, token: "c")
        var q = GameCenterManager.enqueue(a, into: [])
        q = GameCenterManager.enqueue(b, into: q)
        #expect(q == [b])
        q = GameCenterManager.enqueue(c, into: q)
        #expect(q == [b])
        let daily = GameCenterManager.encode(leaderboard: "glint.daily", score: 50, day: 7, token: "d")
        q = GameCenterManager.enqueue(daily, into: q)
        #expect(q.count == 2)
        let parsed = GameCenterManager.parse(daily)
        #expect(parsed?.day == 7)
        if let parsed {
            #expect(GameCenterManager.isStale(parsed, today: 8))
            #expect(!GameCenterManager.isStale(parsed, today: 7))
        }
        #expect(GameCenterManager.parse("junk") == nil)
    }

    @Test func pilotMaths() {
        #expect(near(PilotSource.approach(0, toward: 1, maxStep: 0.25), 0.25))
        #expect(near(PilotSource.approach(0.9, toward: 1, maxStep: 0.25), 1))
        #expect(near(PilotSource.approach(0.5, toward: 0, maxStep: 0.1), 0.4))
        #expect(near(PilotSource.glow(Tuning.bandMin), 0))
        #expect(near(PilotSource.glow(0.3), 1))
    }

    @Test func opaquePNGHasNoAlpha() {
        let w = 4
        let h = 3
        let rgba = [UInt8](repeating: 200, count: w * h * 4)
        let png = OpaquePNG.encodeRGB(rgbaRows: rgba, width: w, height: h)
        #expect(png != nil)
        if let png { #expect(OpaquePNG.colorType(png) == 2) }
    }
}
