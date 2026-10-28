# App engineer, round 1

Nothing has been compiled (CI is the compiler). Nothing is committed. I coded against the real Core, Input, Feedback
and Scene files on disk (28 Oct), not only ARCHITECTURE.md.

## Files
- `Glint/App/`
  - `GlintApp` (@main)
  - `GameController`: the `GardenDriver`, plus `HUDModel`, `HUDState` and `ResultSummary`
  - `AppRules`: `AppRoute`, `PlayStage`, `PromptLine`, `CoverLine`, `PauseFlags`, `PauseRules`, `HintRules`,
    `LevelMapGeometry`
  - `DemoMode`, plus `DemoPresets` and `IconExport`
  - `PilotSource`, plus `FixedBandSource`
  - `GameCenterManager`
  - `AppTrace`
  - `OpaquePNG` (copied from Hush)
- `Glint/UI/`: `Theme` (`GlintTheme`, `GlintType`, buttons, cards, all menu art), `RootView`, `HomeView`, `LevelsView`,
  `PlayHUD`, `PauseView`, `ResultsView`, `SettingsView`, `AboutView`, `CoverView`, `AppIconArt`.
- `Glint/Persistence/`: `ProgressStore` (`ProgressData`, `ProgressRules`, `RecordOutcome`, `UnlockNote`),
  `SettingsStore` (`SettingsData`).
- `GlintTests/AppTests.swift`: about 55 Swift Testing tests, all on pure rules. One test is `@MainActor` (the in-memory
  store).

All menu art types are prefixed `Menu…` (for example `MenuSunArt` and `MenuGloomArt`). The Scene already has
`MirrorArt`, `GardenArt` and `CreatureArt`. I checked every top-level type name against the other modules: no
collisions.

## Screens
- **Home.** The live attract garden sits behind a light scrim:
  - on a Duo, the real hinge's light;
  - elsewhere, the pilot at skill 0.85.
  Home shows the gold wordmark with its glint and "Catch the sun. Pop the shadows.". The big Play button goes straight
  to the next level: no tutorial gate. Three illustrated cards follow:
  - Sunrises (★ total);
  - Long Night (best score, or a lock with "Win level 5");
  - Today's Dawn (today's best, or a lock with "Win level 3").
  At the bottom are Settings, Game Center and About. A wide canvas gets two columns.
- **Levels.** Three illustrated world tabs, then 10 sun medallions on a winding serpentine path (5 per row when wide,
  3 when tall). Medallions get warmer with more stars, and the next level pulses. Locks:
  - each locked level shows a lock;
  - a closed world shows a card: "Rooftops opens at 20 ★ in Meadow · N more ★ to go".
  Tapping a locked level gives a toast saying why.
- **Play HUD.**
  - Score and the ×multiplier sit in the u = 0 flower-edge corner; the pause button in the u = 1 corner. Both come
    from `GardenLayout`, so they work in all four layouts.
  - The start prompt card sits at the garden's centre, with a tiny phone drawing.
  - Hints and the "Wave n" banner sit at the mirror's centre.
  - If the phone shuts while the inner display is still up, a "Paused · open the phone to carry on" card shows, with
    a Home button.
- **Pause.** Resume, Restart, Levels (levels only) and Home. On a Duo it adds "Closing the phone pauses too."
- **Results.**
  - Sunrise or night art, then "Sunrise!" or "The night won" ("Dawn!" or "The night is over" for endless and daily).
  - Stars land one by one with `ui(.star(i))`, and the score rolls up.
  - Then "New best!" or the best (for daily, "Best today"), flowers saved and shadows popped.
  - Unlock chips (with `ui(.unlock)`).
  - Buttons for levels: Next sunrise, Retry, Levels, Home. For endless and daily: Again, Leaderboards, Home.
- **Settings.** A warm card of five toggles: Sound, Music, Haptics, Swap halves, Reduce motion. Then Game Center and
  About buttons.
- **About.** Art, the wordmark, credits ("Designed and built by Praveg, with Claude…", for the founder to edit), and
  "\(AppBrand.name) collects no data." The version line: hold it for 2 s and it copies a diagnostics log to the
  clipboard. The log has:
  - device, canvas, layout, hinge state, settings and progress;
  - the last 200 `AppTrace.note` lines;
  - `HingeMirrorSource.traceText()`.
- **Cover.** On a Duo's outer display:
  - the sun, the wordmark, and one line: "Open the phone to play", "Open the phone", or "Paused · open the phone to
    carry on" with the score;
  - after 3 s, "Already open? Show the game" (in case the window was misread).

## Flow (GAME-DESIGN §7–§8)
- **Play.** The Duo case works in three steps:
  1. If the hinge hasn't reported yet on a device that might be a Duo, the app waits up to 1.5 s with no prompt
     (`PlayStage.checking`). That means a hinge was seen before, demo `duolog=1`, or the first 2 s after launch.
  2. If the phone is open, it shows "Close the phone to start", and no session exists yet (`closeFirst`).
  3. Once shut is seen, the session starts in `.waiting`, and "Open the phone to let the light in" shows until
     `.started`.

  On phones, the session starts at once. `drag.reset(band: Tuning.bandMin)` runs, and "Drag down|up|left|right to let
  the light in" shows (the direction comes from `layout.dDirection`).

  The gate is checked on every frame, every hinge sample and a 4 Hz ticker, so it can never get stuck. If the hinge
  never drives the light, the session simply starts.
- **Pause** (`PauseRules`):
  - **Shut.** `hinge.isShut` pauses, only while playing and only when the hinge drives the light. `canResume` clears
    it, then a 0.6 s grace follows (dt = 0).
  - **Menu.** Only Resume clears it, then the same grace.
  - **Inactive.** It pauses. After a trip to the background mid-level, it becomes the menu pause unless the phone is
    shut.
  - There is nothing near 90°.
  - `hinge.reset()` runs on activation and on resume.
- **Hints.** They come from `.hint` events, once per player (they are saved in `seenHints`). Each fades after its
  lifetime (3.5–4 s, or 12 s for "Light the shadows.") or when it is done (the first pop, a brute popped, a firefly
  delivered…).
- **Results.** They show 2.2 s after `.sunrise` and 1.8 s after `.nightWins`. Recording updates level stars (only up)
  and bests, the endless best and the daily best per day. Game Center gets:
  - `glint.stars` (the star total) after levels;
  - `glint.endless`;
  - `glint.daily` (with the day as context).
  Endless and daily runs left early still record their score.
- **Unlocks.** World w opens at ⌈2/3⌉ of world w−1's stars (20). Inside a world, a level opens once the previous one
  is won. Daily opens after a level-3 win. Endless opens after a level-5 win, or 1 day after the first launch.
- **Duo hints.** `isDuo` means a hinge seen (persisted in `ProgressData.hingeSeen`), a Duo-shaped window, or demo
  `fold=1`. The cover display needs a hinge seen and a long side under 760. The layout is
  `GardenLayout.make(size:isDuo:swapHalves:)`, rebuilt on every size change and on Swap halves.
- **Feedback wiring.** Done, and the Feel NEEDS lines are deleted:
  - `deviceHasFold = true` once a hinge is seen, and at launch when it was persisted;
  - `ambience(sun: 0.45)` on every menu frame;
  - `silence()` when leaving play;
  - `setPaused` on every freeze, pause or grace change;
  - `handle` and `frame` only in play (not in attract, not when frozen).
- **Idle timer.** It is off during play: nobody touches a Duo while playing.

## DemoMode keys (DEBUG only; `DemoMode.parse` is inside `#if DEBUG`)
`screen=home|levels|play|results|settings|about|cover|icon`, `progress=fresh|mid|done`, `level`,
`mode=level|endless|daily`, `t`, `skill`, `band`, `fold`, `swap`, `results=won|lost`, `hint=<HintID>`, `seed`,
`sound=0`, `duolog=1`. These extra keys were needed by `ci/screenshots.sh`:
- `freezeOn=<started|pop|sweep|split|hop|firefly|scorch|eaten|sunrise|night|wave|hint>`: freezes 0.3 s after the
  event;
- `freezeAfter=<s>`;
- `prompt=close|open|drag`: static frames of the start line.

How the keys behave:
- `t=` plays headless at 1/120 s steps up to t − 0.5, then live at fixed 1/120 s steps up to t, then freezes
  (`GLINT-T freeze time`).
- `band=` pins the band in the returned snapshot once frozen. Without `t=` it holds the band there, but only until a
  real hinge reports.
- With a real hinge present, `screen=play` uses `HingeMirrorSource` unless `t=` or `skill=` is given.
  `freezeOn`/`freezeAfter` alone use the pilot only while no hinge has reported.
- `screen=results` plays a real session headless at launch and records it into the in-memory demo progress. `won`
  uses a pilot at skill 1. `lost` gives one frame of band 0 (to start), then the band stays in the crease.
- `screen=cover`, with `t=`, `mode=` or `level=`, shows a paused level with its score.
- `screen=icon` renders `AppIconArt` through `ImageRenderer` at 1024 px, scale 1, writes an opaque RGB PNG
  (`OpaquePNG`, colour type 2) to Documents/AppIcon-1024.png, and prints `GLINT-ICON <path>`.

Field names avoid the key names (`holdAfter`, `stopOn`, `playTo`, `pinBand`). Reflection metadata would otherwise
put "freezeAfter" in the Release binary, and the release guard greps for it.

## Log lines
Every one prints via `FeelDemoLog.line`, and every call site sits inside `#if DEBUG` with the full literal, so
"GLINT-T paused shut" exists only in DEBUG code:
- `GLINT-T demo '<args>' starts`
- `GLINT-T screen <home|levels|play|results|settings|about|icon>`, and `GLINT-T screen cover` when CoverView appears
  (the route is re-logged when it goes)
- `GLINT-T canvas <W>x<H> fold=<0|1>` (fold = the Duo split layout)
- `GLINT-T band <b %.3f> angle <θ %.1f | -1> phase <waiting|playing|won|lost|none> shut <0|1>` at 2 Hz while the play
  screen is up. Before the session exists the phase is `none`; shut is `hinge.isShut` with a hinge, else
  `input.isShut`.
- `GLINT-T prompt <close|open|drag|none>` on every change
- `GLINT-T paused shut`, `GLINT-T paused menu`, `GLINT-T paused inactive`, `GLINT-T resumed`
- `GLINT-T freeze <time|after|tag>`, `GLINT-T skipped <s>`, `GLINT-T event <name> …`, `GLINT-T result <mode>
  won= stars= score= flowers= pops=`
- `GLINT-T icon ok WxH rgb=1`, `GLINT-ICON <path>`

## Assumptions about other modules (checked against the files on disk)
- **Core:**
  - `DawnSession(mode:seed:)` (the convenience init), `step(dt:input:)`, `snapshot`, `isFinished`,
    `stars(flowersLeft:)`;
  - `LevelBook.count/worldCount/level(_:)/world(of:)/worldName(_:)/levels(inWorld:)/daily(day:)`, with
    `LevelSpec.title/duration`;
  - `DailySeed.day(for:)` and `seed(day:)`;
  - `PilotBrain(skill:seed:)` and `mutating band(for:dt:)`;
  - `Tuning.bandMin/resumeGrace/dragSpeedCap`.
  Level seeds are `UInt64(n)`: the session takes the level's script from `LevelBook` anyway, and daily overrides the
  seed itself.
- **Input:**
  - `HingeReader(onUpdate:onUnavailable:refreshToken:)`. `refreshToken` is bumped on every cover ↔ inner change.
  - `HingeMirrorSource`: `ingest`, `hasHinge`, `angle`, `isShut`, `canResume`, `mirror(at:)`, `reset()`,
    `traceText()`.
  - `DragMirrorSource`: `layout`, the `drag*` methods, `reset(band:)` (additive in Feel's file; the coordinator
    asked for it).
- **Feedback:** `FeedbackDirector.shared` with `start`, `soundOn/musicOn/hapticsOn`, `deviceHasFold`, `handle`,
  `frame`, `setPaused`, `ambience(sun:)`, `silence()`, `ui(_:)`, plus `UICue`, `FeelDemoLog.line/isEnabled`.
- **Scene:**
  - `GardenScene(layout:)`, `driver`, `apply(layout:)`, `showsLever`, `attract`, `reduceMotion`;
  - `GardenDriver.advance(dt:now:)`, where `now` is `CACurrentMediaTime()`, which matches my timers.
  The App never touches the scene's size or `scaleMode`. `showsLever` is `!hinge.hasHinge`.

## Compile risks (what I'd check first on the first CI run)
- `playSource() === hinge` and `!== drag`: identity comparison between `any MirrorSource` (class-constrained) and
  concrete classes. It should compile, because `MirrorSource: AnyObject`.
- The `HingeReader` closures in `RootView` call `@MainActor` controller methods from a closure the modifier types as
  non-isolated. This is the same pattern Hush compiles in Swift 5 mode.
- `GKLocalPlayer.authenticateHandler` captures a `UIViewController` into a MainActor Task (Swift 5 mode: a warning at
  most, the same as Hush).
- `ImageRenderer.isOpaque` and `scrollBounceBehavior(.basedOnSize)` (iOS 16.4+, under our iOS 18 deployment target).
- `.mask { … }` with `.blendMode(.destinationOut)` + `.compositingGroup()` for the crescent moon.
- `setvbuf(stdout, …)` in `DemoMode.current` (a concurrency warning only in Swift 5 mode).
- The tests assume Core's numbers: 30 levels, 3 worlds of 10, `Tuning.bandMin` −0.2. `DemoPresets` `mid` gives
  next level 14, and `done` totals 86 ★.

## Open points for the founder
- The menus' dawn pad uses a fixed brightness of 0.45.
- The attract garden is endless mode, silent apart from the pad, restarted 2.5 s after the night wins.
- On a Duo the attract light is the real hinge (founder rule: never draw light the hinge hasn't made), not the pilot.
  The brief said "attract with PilotSource"; I read the founder rule as overriding it.
- Daily can be replayed; the best of the day is kept, and Game Center keeps the best.
