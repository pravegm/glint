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
