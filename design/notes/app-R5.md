# App engineer, round 5

Nothing here has been compiled (CI is the compiler). Nothing is committed. Sources:
- design/QA-R5-app.md (P0, every P1 and the real P2s);
- design/QA-R5-player.md (the App rows and the App strings in the copy list);
- QA-R5-store.md F4 and F5;
- the founder's addenda (Mac, VoiceOver, the sunrise test, portrait phones).

## QA-R5-app
- **P0-1 Wins are saved at the finish.** `.sunrise` and `.nightWins` call `recordFinish` at once, which files:
  - stars, best and unlocks;
  - achievements;
  - the Game Center queue;
  - the summary.
  Only the route change waits 2.2 s / 1.8 s. `levelOver` hides the pause button, and leaving early loses nothing
  (`recordPartialIfNeeded` sees a finished session). Tests `aWinIsSavedAtSunriseNotAtResults` (a real
  `GameController`) and `aLongNightGameOverIsSavedAtOnce`.
- **P1-1 Restored Duo flag.** `ProgressData.hingeMachine` holds the `utsname.machine` that saw the hinge, and
  `ProgressRules.hingeSeen(_:machine:)` trusts the flag only on that model. `hingeUnavailable()` with no sample this
  launch clears it.
- **P1-2 Sleep.** `AppRules.keepAwake`: the idle timer is off only while a live level is playing and nothing pauses.
  It is re-checked on every pause, route, phase and start change.
- **P1-3 Results chimes.**
  - The count-up runs in `.task(id: summary.id)`, so it is cancelled with the view, and each cue checks
    `Task.isCancelled`.
  - The controller remembers `animatedResultID`, so coming back from the cover display shows the card already
    settled.
- **P1-4 World gate.** A world's last level won while the next world is shut shows "10 more ★ in Meadow opens
  Rooftops" (`AppRules.worldGateNote`), and Levels becomes the primary button. The buttons' height allows for the note.
- **P1-5 Date chip.** It shows the player's local date of the run's start (`AppRules.localDateChip(runStart)`). The
  seed stays UTC.
- **P2 fixes:**
  - **1:** a Today's Dawn left early keeps its best but isn't a day played (`record(…, finished: false)`).
  - **2:** Retry after UTC midnight plays the new day.
  - **3:** the light source is locked per session (`lockedSource`). The lever shows whenever drag drives the light
    (`showsLever(route:dragDriven:)`), so a Duo with no hinge has one.
  - **4:** after `hingeUnavailable` there are no more 1.5 s checks.
  - **5:** the scene runs at 30 fps behind menus and is paused under the cover view; the ticker and hinge samples
    still run the gates.
  - **6:** an inactive spell over 1 s returns to the pause menu.
  - **8:** VoiceOver:
    - the garden is an adjustable "Light" on drag levels (swipe up / down moves the band ±0.1, with a value);
    - the pause menu is `.isModal`;
    - toasts are announced;
    - world tabs read their star status.
  - **9:** the sign-in re-sync reports quietly (no banners); only new achievements on Results show one.
  - **11:** an unreadable save is kept under `glint.progress.bad`.
  - **12:** `play()` is debounced by 0.3 s.
  - **13:** the pause card says "Closing the phone pauses too." only when the hinge drives the light.
- **Not done:**
  - P2-7 Dynamic Type: don't tick "Larger Text" in App Store Connect.
  - P2-10 is an App Store Connect setting.
  - P2-14 is optional: the demo code stays compiled but unreachable.

## QA-R5-player (App rows)
- **#2 Cover pause.** A new `PauseFlags.cover` is set whenever the cover view is up mid-level, whatever the hinge
  reports or doesn't, and logs `GLINT-T paused cover`. Opening the phone resumes after the 0.6 s grace; a pause-button
  pause stays on its menu.
- **#4 Cover escape.** "Already open? Show the game" shows only when the window is inner-display sized AND the hinge
  doesn't read shut (open, or silent for 3 s) (`AppRules.coverEscapeAllowed`). It never appears on a shut phone and
  never puts the game on the outer display.
- **#5, #29 Cover copy.** Two lines: "Paused" / "Open the phone to carry on", or after a pause-button pause "Open the
  phone to see the pause menu". "Open the phone to start" at a level start. Score and flowers underneath.
- **#6 Date chip.** `AppRules.dateChipCenter` places it by the plates' real rects: between them on their row when
  there's room, else one row in. A test covers 402×874, 375×667 and both Duo poses.
- **#7, #28 Duo menus.** The mirror region is inset by the frame thickness + 12, so the tagline and cards stay off the
  brass. Home's title is pinned to the top of the mirror, centred, above the low dawn sun.
- **#8 Pill.** The score pill shows the multiplier ("×2.5 · Wave 3", capped at ×4), never the chain count. The
  Scene's floating ×n is a NEEDS line.
- **#10 About.** "Best on iPhone Duo" (store F4: no "Made for"). Below it: on a Duo "One half of your phone is a
  mirror. Open it…"; on phones "Plays on every iPhone by dragging. …".
- **#17** The hint plate is at 88 % opacity.
- **#19** The HUD's duplicate "Wave n" banner is gone (the Scene label stays).
- **#20, #21** "The night won" for every loss; "Retry" everywhere ("Play again" only after level 30); "Next level".
- **#22** The Long Night card says "Win level 5 or come back tomorrow" (two lines allowed).
- **#23** The locked tab reads "Needs ★ 20".
- **#24** The pause card has Sound and Haptics toggles.
- **#25** Swap halves applies when the player leaves Settings.
- **#26** The close-the-phone drawing turns for book pose.
- **#30** No "New best!" pill on a loss.
- **Copy list (App strings):**
  - hints: "Spare the fireflies. They replant flowers.", "Hoppers hop when the light touches them.";
  - toasts: "… to open this level", "Win level 5 (or come back tomorrow) …";
  - lock card: "in the Meadow";
  - Settings: "A soft dawn soundtrack", "Calmer light and no shimmer. Matches iOS until you change it."

## Store and founder
- **F5 blank badge.** `BadgeExport` warms the renderer with a throwaway badge and retries a flat render up to 3
  times. It never writes an image with fewer than 16 colours; it logs `GLINT-T badge flat <id>` instead.
- **Mac ("Designed for iPhone").** `isiOSAppOnMac` means: never a Duo layout, never the cover, no hinge flags, no
  hinge wait.
- **Portrait phones.** `OrientationRules` with `GlintAppDelegate`: `.portrait` unless the canvas is a Duo (then
  every orientation). It is applied on the first canvas and on every change.
- **Pacing.** I checked the R5 level durations (L1 35 s … L16 75 s): every `ci/scenarios.txt` `t=` still falls
  inside its level, so no values changed. Captions 14, 15 and 24 are updated.

## NEEDS (added)
- Scene: float the multiplier, not the chain count.
- Core / founder: a `.wisps` hint needs a `HintID` case. Two achievement strings are Core's.

## Compile risks
- `private lazy var appliedSwap` in the `@MainActor` controller.
- `GlintAppDelegate` relies on its `UIApplicationDelegate` conformance to be main-actor.
- `requestGeometryUpdate(.iOS(interfaceOrientations:)) { _ in }`.
- `SpriteView(scene:isPaused:preferredFramesPerSecond:)`.
- `.accessibilityAdjustableAction` with `@unknown default`.
- `ResultsView`'s `.task(id:)` calling an `async` method.
- The new tests build a real `GameController` (`demo: DemoMode(raw: "")`, so no Game Center traffic). They touch
  `UIApplication.shared` (idle timer) inside the hosted test bundle.

## R5b (store frames)
- New `freezeOn=` triggers (DEBUG only; every one prints `GLINT-T freeze <tag>`):
  - `freezeOn=busy` freezes on the first frame after `t=` with ≥ 5 surfaced glooms, ≥ 2 of them lit, and a pop within
    0.4 s (so its FX is still in flight). If that never happens, it freezes 10 s of session time after it started
    watching, printing `GLINT-T freeze busy-timeout`. The rule is `DemoBusy.isBusy`.
  - `freezeOn=sweep` now freezes 0.12 s after the first `.swept` event (`DemoMode.stopDelay(for:)`).
  - `freezeOn=firefly` freezes when a firefly out of the crease shade is within 0.15 d of the band
    (`DemoBusy.fireflyNearBand`).
  - `freezeOn=eaten` freezes 0.3 s after a flower is eaten.
- `pilotLag=<s>` (0…2): the demo pilot acts on the band it wanted `s` seconds ago, so more glooms build up; the skill
  is unchanged.
- Tests: `R5bTests`.

## R5 fix: Duo regression (run 40896758284)
- **Cause.** On the Duo simulator the hinge API's early "no hinge" callback (it fires before the first report) set
  R5's `hingeUnavailableSeen`. That skipped the 1.5 s hinge wait (QA P2-4), so the session started on drag. R5's
  per-session lock then kept it on drag after the first report (`GLINT-H … 156.1`) arrived.
- **Fix 1.** `needsHingeCheck` now always waits on a Duo-shaped inner display, a saved Duo flag, or `duolog=1`,
  whatever an early "no hinge" says. Only other canvases skip the wait after "unavailable". An early nil on a
  Duo-shaped canvas never clears the saved flag.
- **Fix 2.** The source lock may upgrade drag (or a demo fallback source) to the hinge on the first report, while the
  session is still `.waiting` and nobody has dragged (`AppRules.mayUpgradeToHinge`). The session is then dropped and
  the level restarts at "Close the phone to start" (rule 1). Hinge → drag, or a switch after the player has dragged,
  never happens. This is checked on every hinge sample and every play frame; it logs
  `GLINT-T source hinge (upgraded from drag)`.
- **A fresh install** reaches the hinge without any stored flag: the Duo shape alone makes it wait, and the first
  report drives it.
- **Tests: `DuoHingeRegressionTests`.**
  - The exact CI sequence on a real `GameController`: 951×669, `duolog=1`, an early "no hinge", Play. It stays
    `.checking` with no prompt. The 156° report gives `closeFirst` and "Close the phone to start". Shutting starts the
    session on the hinge with "Open the phone to let the light in". The cover display pauses and resumes.
  - Drag upgrades to the hinge while waiting.
  - No switch after a drag.
  - The pure rules.

## R5c store stages (`stage=<name>`, DEBUG)
- **What a stage is.** `App/DemoStages.swift`: a real session built from a custom `LevelSpec` via Core's
  `DawnSession(mode:spec:seed:)`, with no Core change.
  - Spawns are timed to surface just before the freeze (submerged speed = speed × scale × 1.6).
  - The band follows a scripted path (`ScriptedBandSource`, by session time). It overrides the hinge on a Duo
    (`stageOverridesHinge`, store frames only).
  - Long Night uses Core's own waves with the slowed pilot.
- **How it runs.** Headless 1/120 s steps up to 0.6 s before the freeze window, then live 1/120 s steps until
  `StageWatch` fires, or `freezeBy` as a timeout. Then it prints `GLINT-T freeze stage-<name>`, a
  `GLINT-T band <b> angle … phase … shut 0` line, and `GLINT-T stage <name> reason=<want|timeout> …`.
- **Stages:**

  | Stage | Mode | What it waits for |
  |---|---|---|
  | `hero` | L3, golden dawn | a 2nd pop with its burst live |
  | `sweep` | 6 wisps in a line | 0.12 s after the Sweep |
  | `brute` | L6 | a surfaced brute lit ≥ 0.5 |
  | `fireflies` | L4 | a firefly within 0.15 d of the band |
  | `rooftops` | L14, a cloud | 0.35 s after a split |
  | `harbour` | L27, a dense wave | 0.3 s after a flower is eaten |
  | `longnight` | endless | 0.6 s after a wave-up (the banner) |
  | `daily` | golden hour, date chip | a pop |

- **Tests: `StageTests`.**
  - Parsing, and the scripted path.
  - Each plan's freeze comes before its sunrise.
  - Each stage, run headless in a real session, reaches a freeze ("want" or "timeout") while still playing. The test
    prints `GLINT-STAGE <name> reason=…` in the CI log so the timings can be tuned from one run.

## R5d stage retime (CI 40923297015: daily, longnight, fireflies froze on empty fields)
- **New wants.** `busy(surfaced:lit:)`: N glooms out of the ground, M of them lit > 0.1 (frozen before they pop).
  `fireflyWith(glooms:)`: a firefly within 0.15 d of the band plus N surfaced glooms.
- **`daily`.** Golden hour (spec duration 7), six murks surfacing at d 0.36–0.48 plus two wisps; the band arrives
  from 0.2 to 0.46 over 4.3–4.7 s. Wants `busy(4, 2)` from 4.6 s.
- **`fireflies`.** The band waits at 0.74, beyond the fireflies, so they rise towards it and never cross the core
  (the old path scorched them on the way). Five murks are out by about 5.5 s at d 0.28–0.38, below the light until
  about 9 s. Wants `fireflyWith(3)` from 6.5 s (a firefly is in reach at about 8.2 s).
- **`longnight`.** Core drops `spec` for `.endless`, so no custom script is possible without a Core change; it plays
  Core's moonlit waves. Wave 1 is a sparse opener (that is why the 30 s frame was empty), so:
  - the pilot (skill 0.9) plays through dense wave 2 until 56 s;
  - the band rests at 0.08 (crease shade) so the field fills;
  - from 60.1 s (wave 3's banner, which plays live) an `aim` path key moves it onto the crowd at ≤ 1.5 d/s, once
    ≥ 4 are out (`DemoStages.aimCrowd`).
  - Wants `busy(4, 2)` from 60.15 s, by 64.5 s.
- **Source.** `ScriptedBandSource` now wraps the optional pilot (`pilotUntil`) and is the one stage source in the
  app and in `simulate` (`DemoStages.source`), with `resetClock()` after the headless run.
- **Tests.** `everyStageReachesItsFreeze` asserts `reason == "want"` for all eight, glooms ≥ 3 (sweep ≥ 2), and for
  daily/longnight ≥ 4 surfaced with ≥ 2 lit. For fireflies it asserts a firefly near the band and ≥ 3 surfaced, and
  for Long Night t ≥ 60. `GLINT-STAGE` now prints surfaced, lit and fireflies. New: `busyWantsAFullLitField`,
  `aimKeyFollowsTheCrowd`.
- **Caveat.** The app's Long Night seed is the demo's rolling seed, not the test's 7, so its waves differ. The
  crowd-gated aim is what makes the app's frame land anyway.
