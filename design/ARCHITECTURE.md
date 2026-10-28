# Glint: architecture and module contracts

Shared types live in `Glint/Shared/Contracts.swift` (founder-owned; read it first). This file says who owns what and
the exact API each module exposes, so modules compile against each other **without a compiler on our side**. CI on
GitHub's macOS runner (`runs-on: xcode-27`, Xcode 27.1, iOS 27.1 SDK) is the only compiler.

**Rules**
- Swift 5 language mode, iOS 18 deployment target. Hinge code behind `if #available(iOS 27.1, *)`.
- Everything touching views, nodes, audio or haptics is `@MainActor`.
- Core is value types and final classes with **no** actor isolation and no UIKit/SpriteKit/SwiftUI/AVFoundation
  imports (Foundation + CoreGraphics only).
- No third-party packages. No asset files except the app icon and colours: art is drawn in code (CoreGraphics →
  textures), sound is synthesised in code.
- Every type and signature below must exist **exactly** as written. Add more freely; never rename these.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`). Gotchas from the sister projects:
  - `#expect(x.mutatingMethod())` doesn't compile (the macro captures `x` immutably): `let r = x.m(); #expect(r)`.
  - Compare `CGFloat`/`Double` with a tolerance, never `==` on arithmetic.
  - Tests that touch `@MainActor` types are marked `@MainActor`.

## The frame loop
```
SpriteView(GardenScene)                     preferredFramesPerSecond 120
  GardenScene.update(currentTime)
    → driver.advance(dt:now:)               GameController (App) is the GardenDriver
         input  = source.mirror(at: now)        HingeMirrorSource (Duo) | DragMirrorSource (phones) | PilotSource (demo/attract)
         events = session.step(dt, input)       Core: DawnSession (sub-steps ≤ 1/120 s)
         FeedbackDirector.shared.handle(events, snapshot:)  +  .frame(snapshot:dt:)
         publishes HUD state to SwiftUI at ≤ 15 Hz
    ← (snapshot, events)
    GardenScene draws mirror, crease, garden, band, glooms, fireflies, flowers; FX for events
  GardenScene touches → driver.dragBegan/Moved/Ended(SwiftUI-space point)   (drag fallback only; the App ignores them on a Duo)
```
`dt` is clamped to ≤ 1/30 s by the driver. Paused (phone shut, inactive, pause menu): the driver passes `dt = 0`
(the scene keeps drawing, the session doesn't advance).

## Ownership

| Module | Folder | Owner |
|---|---|---|
| Contracts | `Glint/Shared/` | founder |
| Core rules, levels, pilot | `Glint/Core/` | Core engineer |
| Input + Feedback | `Glint/Input/`, `Glint/Feedback/` | Feel engineer |
| Scene + art | `Glint/Scene/` | Scene engineer |
| App shell, UI, saves, Game Center, demo mode | `Glint/App/`, `Glint/UI/`, `Glint/Persistence/` | App engineer |
| Tests | `GlintTests/<Module>Tests.swift` | each engineer |
| CI, project.yml | `.github/`, `ci/`, `project.yml` | founder |

Write only in your folders. Need something from another module that isn't listed? Add a line to `design/NEEDS.md`
and use a local `private` stand-in.

## Core API (Core engineer)
```swift
struct SeededRandom {                     // SplitMix64
    init(seed: UInt64)
    mutating func next() -> UInt64
    mutating func unit() -> Double                      // [0, 1)
    mutating func range(_ r: ClosedRange<Double>) -> Double
    mutating func int(_ r: ClosedRange<Int>) -> Int
}

enum Tuning {                             // every number in GAME-DESIGN §3–§6, documented
    static let shutAngle: Double          // 15
    static let creaseAngle: Double        // 80
    static let edgeAngle: Double          // 145
    static let resumeAngle: Double        // 25
    static let shutDwell: Double          // 0.25
    static let bandMin: Double            // -0.2   (band value when fully in the crease)
    static let bandCoreHalfWidth: Double  // 0.050
    static let bandEdgeHalfWidth: Double  // 0.085
    static let flowerCount: Int           // 5
    static let chainWindow: Double        // 1.6
    static let sweepWindow: Double        // 0.35
    static let maxMultiplier: Double      // 4
    static let dragSpeedCap: Double       // 2.4  d/s
    static let resumeGrace: Double        // 0.6
    static func band(angle: Double) -> Double        // θ → band centre, clamped bandMin…1
    static func creaseGlow(angle: Double) -> Double  // θ → 0…1
    static func intensity(d: Double, band: Double) -> Double   // 0…1 (smoothstep edge)
}

struct GloomSpec: Equatable { let kind: GloomKind; let hp: Double; let speed: Double; let radius: Double; let points: Int
    static func of(_ kind: GloomKind) -> GloomSpec }

enum SpawnKind: Equatable { case gloom(GloomKind), firefly }
enum Formation: Equatable { case cluster, line, stagger(Double) }       // stagger(seconds between members)
struct SpawnGroup: Equatable { var time: Double; var kind: SpawnKind; var count: Int
    var u: ClosedRange<Double>; var formation: Formation; var speedScale: Double }
struct LevelSpec: Equatable { var number: Int; var world: Int; var title: String; var duration: Double
    var groups: [SpawnGroup] }

enum LevelBook {
    static let count: Int                                // 30
    static let worldCount: Int                           // 3
    static func level(_ n: Int) -> LevelSpec             // 1…30 (clamped)
    static func world(of level: Int) -> Int              // 1…3
    static func worldName(_ world: Int) -> String        // "Meadow", "Rooftops", "Harbour"
    static func levels(inWorld w: Int) -> ClosedRange<Int>
    static func daily(day: Int) -> LevelSpec             // 90 s, seeded by day
}

enum DailySeed { static func day(for date: Date) -> Int   // days since 2026-01-01 UTC
                 static func seed(day: Int) -> UInt64 }

final class DawnSession {
    init(mode: PlayMode, seed: UInt64 = 1)
    private(set) var snapshot: DawnSnapshot
    var isFinished: Bool { get }                         // phase won or lost
    /// dt ≤ 1/30 (sub-steps internally ≤ 1/120). dt = 0 is legal (no change, no events).
    func step(dt: Double, input: MirrorInput) -> [GameEvent]
    static func stars(flowersLeft: Int) -> Int           // 5 → 3, 3–4 → 2, 1–2 → 1, 0 → 0
}

/// The autopilot (attract mode, CI screenshots, balance tests). Pure.
struct PilotBrain {
    init(skill: Double, seed: UInt64)                    // skill 0…1 (1 = near-perfect)
    /// The band position it wants this frame, given the last snapshot. Moves with the hinge's speed limits
    /// (≤ 1.6 d/s, reaction delay by skill), so it plays like a person.
    mutating func band(for snapshot: DawnSnapshot, dt: Double) -> Double
}
```
Endless: escalating waves generated on the fly by the session (seeded), `.waveUp(n)` every 30 s.

## Input API (Feel engineer)
```swift
struct HingeReader: ViewModifier {        // copied from Hush (`C:\Users\59527\Lid\Hush\Input\HingeReader.swift`), prefix GLINT-H
    init(onUpdate: @escaping (Double, TimeInterval) -> Void, onUnavailable: @escaping () -> Void = {}, refreshToken: Int = 0)
}
@MainActor final class HingeMirrorSource: MirrorSource {
    init()
    func ingest(angleDegrees: Double, at time: TimeInterval)
    private(set) var hasHinge: Bool                      // true once a sample arrived, never false again
    private(set) var angle: Double?                      // filtered
    var isShut: Bool { get }                             // filtered θ ≤ shutAngle held for shutDwell
    var canResume: Bool { get }                          // filtered θ ≥ resumeAngle
    func mirror(at time: TimeInterval) -> MirrorInput
    func reset()
    func traceText() -> String                           // diagnostics
}
@MainActor final class DragMirrorSource: MirrorSource {
    init()
    var layout: GardenLayout                             // set by the App when the canvas changes
    func dragBegan(_ p: CGPoint); func dragMoved(_ p: CGPoint); func dragEnded()   // SwiftUI-space points
    func setBand(_ band: Double)                         // jump (level start: Tuning.bandMin)
    private(set) var hasMoved: Bool
    func mirror(at time: TimeInterval) -> MirrorInput
}
```

## Feedback API (Feel engineer)
```swift
@MainActor final class FeedbackDirector {
    static let shared: FeedbackDirector
    func start()                                          // audio session (.playback, mixWithOthers), engines
    var soundOn: Bool; var hapticsOn: Bool; var musicOn: Bool
    func handle(_ events: [GameEvent], snapshot: DawnSnapshot)
    func frame(snapshot: DawnSnapshot, dt: Double)        // continuous layers: sizzle, band air, dawn pad
    func setPaused(_ paused: Bool)                        // silences continuous layers
    func ui(_ cue: UICue)
}
enum UICue: Equatable { case tap, back, toggle, star(Int), unlock, levelStart }
```

## Scene API (Scene engineer)
```swift
@MainActor protocol GardenDriver: AnyObject {
    func advance(dt: Double, now: TimeInterval) -> (DawnSnapshot, [GameEvent])
    func dragBegan(_ p: CGPoint); func dragMoved(_ p: CGPoint); func dragEnded()  // SwiftUI-space points
}
@MainActor final class GardenScene: SKScene {
    init(layout: GardenLayout)
    weak var driver: GardenDriver?
    func apply(layout: GardenLayout)                      // rotation / swap / resize: rebuild positions, keep state
    var showsLever: Bool                                  // phone fallback: draw the brass lever on the mirror
    var attract: Bool                                     // menus behind glass: no HUD-ish FX, softer
    var reduceMotion: Bool
}
```
The scene draws **everything inside the canvas**: mirror (sky, rising sun at `snapshot.sun`, brass frame, glint),
crease (dark seam, glow by `creaseGlow`), garden (grass, dew, flowers by `snapshot.flowers`), band, glooms,
fireflies, FX. SwiftUI overlays only the HUD text/buttons and menus.

## App (App engineer)
`GameController` (ObservableObject, the GardenDriver), `RootView`, routes (home, levels, play, results, settings,
about), `CoverView` (Duo outer display), `ProgressStore`, `SettingsStore`, `GameCenterManager`, `DemoMode`
(`-glintDemo "key=value;…"` launch argument for CI screenshots, DEBUG only), `PilotSource` (MirrorSource wrapping
`PilotBrain`). Details in `design/ROUND-1.md`.
