# QA R5: app flow and state (App / UI / Persistence, plus how they use Input and Core)

I read GameController, AppRules, RootView, GlintApp, every UI screen, ProgressStore, SettingsStore, GameCenterManager,
DemoMode, AppTrace, PilotSource, the three Input sources, and the public parts of DawnSession and FeedbackDirector. This
was a code read only: no Mac, nothing run. Anything that depends on iOS or hardware behaviour is marked *unverified*.
Counts: **P0 1 · P1 5 · P2 14**.

## P0
**P0-1 A win (or a Long Night game-over) is lost if the player leaves during the results delay.**
- `GameController.swift:790-794` only sets `finishAt` (2.2 s after a win, 1.8 s after a loss). Nothing is recorded until
  `showResults()` (`:940-949`) runs from `:729-732`.
- Pause stays live once the level is over (`PlayHUD.swift:34-38` hides it only while the menu is up).
- Scenario: the player wins level 10 with ★★★ and taps Pause → Levels, Home or Restart. `leavePlay()` →
  `recordPartialIfNeeded()` hits `guard … !s.isFinished` (`:526`) and returns.
- Result: the stars, best, unlocks and achievements are lost, and level 11 stays locked. After `nightWins`, Long Night's
  best and its leaderboard score are lost the same way.
- The app being evicted in that window loses the win too. A pause menu opened in the window gets yanked away by Results.
- Fix: record everything (store, achievements, Game Center queue) at the `.sunrise` / `.nightWins` event and delay only
  the route change. Hide Pause once `isFinished`.

## P1
**P1-1 A Duo backup restored onto a regular iPhone turns that phone into a "Duo" for good.**
- `hingeSeen` is saved in the progress JSON (`ProgressStore.swift:64`), which travels with backups and Quick Start.
- On the new phone `isDuo` is true (`AppRules.swift:244`): a 50/50 split, menus kept off a crease that isn't there, and
  no drag lever (`:465`).
- On an SE or mini, `isCover` is true too (`:250-253`). Every launch shows "Open the phone to play" until the 3 s escape,
  and any rotation brings the cover back (`canvasChanged` clears `coverDismissed`).
- Every Play then waits a blank 1.5 s (`:267-271`).
- Fix: save the machine id (`machineName()`) with the flag and trust it only on the same model. Clear it when
  `hingeUnavailable()` fires on iOS 27.1 or later.

**P1-2 The screen never sleeps while a level is paused.**
- `isIdleTimerDisabled = route == .play` (`GameController.swift:344, 354`) also covers the pause menu, the shut pause,
  `closeFirst` and `waiting`.
- Phone: pause it and put it down, and the display stays on until the battery dies.
- Duo: closed mid-level, the cover display stays lit in a pocket (*unverified* on hardware).
- Fix: disable the idle timer only while `stage == .live`, the phase is `.playing` and nothing pauses.

**P1-3 Results chimes leak into the next level.**
- `ResultsView.animateIn()` (`ResultsView.swift:219-248`) starts an untracked `Task` that runs about 2.5 s and calls
  `ui(.star)` / `ui(.unlock)`. `ui()` plays even while feedback is paused (`FeedbackDirector.swift:361`).
- Tap Retry or Next within about 2 s and the chimes play over "Close the phone to start".
- Closing the phone on Results drops the view (`RootView.swift:74`). Opening it again replays the count-up and the chimes.
- Fix: use `.task {}`, check `Task.isCancelled` before each cue, and keep an "animated" flag per summary in the
  controller.

**P1-4 Level 10 or 20 won without enough stars for the next world: no Next button and no reason given.**
- `nextLevel` is set only when level n + 1 is open (`ProgressStore.swift:283`), and Rooftops needs 20★ in Meadow.
- A first clear of world 1 with 18★ shows only Play again / Levels / Home (`ResultsView.swift:174-194`). It looks broken.
- Fix: on a world's last level, when the next world is shut, show "x more ★ in Meadow opens Rooftops"
  (`starsMissing`) and make Levels the primary button.

**P1-5 Today's Dawn's date chip shows the UTC date, not the player's.**
- `AppRules.dateChip` (`:629-647`) and `DailySeed.day` both use UTC.
- New York at 20:00 on Wed 28 Oct sees "Thu 29 Oct". India before 05:30 sees yesterday's date. The Home card's "New
  today" flips mid-afternoon in the Americas.
- Fix: keep the UTC seed but label the chip "Today" (or the local date of the run's start), and show "New dawn in 4 h".

## P2
1. **Early quits count as a day played.** A Today's Dawn left after one pop is filed as played
   (`GameController.swift:524-531` → `ProgressStore.swift:293`). That shows "✓ Today 10" and extends the streak. Add the
   day to `dailyPlayed` only at `.sunrise` / `.nightWins`.
2. **Again after UTC midnight replays yesterday's dawn.** It uses the old `.daily(day)` (`GameController.swift:1019`), and
   Game Center silently drops its score as stale (`GameCenterManager.swift:150-154`).
3. **The light source can switch mid-level, and drag on a Duo has no lever.**
   - `playSource()` (`GameController.swift:177-182`) can go from drag to hinge mid-session, for example when a Duo's
     first report arrives after the 1.5 s check. The light jumps, and the close-first step is skipped.
   - A Duo whose hinge API returns nil is drag-driven but shows no lever (`AppRules.swift:465`).
   - Fix: lock the source for each session, and show the lever whenever drag drives the light.
4. **A Duo whose hinge API now returns nil waits a blank 1.5 s on every Play** (`AppRules.swift:267-271`). Skip later checks.
5. **The attract garden steps and renders at 120 fps behind opaque screens:** the cover view and every menu
   (`RootView.swift:104`, `GameController.swift:736`). That costs battery and heat. Drop to 30 fps on menus and pause the
   scene under the cover view.
6. **An inactive spell without a trip to the background resumes by itself.** A declined full-screen call or a
   dismissed Siri resumes after the 0.6 s grace with no menu (`AppRules.swift:149-156`). That follows §8, but the
   player's hands may be elsewhere. Suggest the menu after any inactive spell longer than 1 s.
7. **No Dynamic Type.** Every font is a fixed `.system(size:)` (`Theme.swift:83-90`): nothing truncates on a 375-pt SE,
   but nothing scales. Don't claim "Larger Text" in App Store Connect's accessibility labels.
8. **VoiceOver gaps.**
   - The garden is `accessibilityHidden` with no `.allowsDirectInteraction` (`RootView.swift:107`), so VoiceOver users
     on a phone can't drag.
   - PauseView isn't `.isModal`, so swiping reaches the HUD behind it.
   - Toasts are never announced.
   - World tabs leave out their star status (`LevelsView.swift:123`).
9. **Achievement banners may repeat** *(unverified)*. Every sign-in (every launch) clears `reported` and re-reports every
   earned achievement with `showsCompletionBanner = true` (`GameCenterManager.swift:186-191, 234`). Set it false for the
   re-sync batch.
10. **Daily board reset** *(unverified)*: `glint.daily` must reset at 00:00 UTC to match `DailySeed` (check in ASC).
11. **A corrupt save is silently replaced.** A save that isn't a JSON object is overwritten with a fresh profile
    (`ProgressStore.swift:323-328`). Copy the raw data to a `.bad` key first.
12. **Double taps.** A double tap on Play or a mode card during the fade can call `play()` twice: `plays` +2 and two tap
    cues (*unverified* that the outgoing view still takes the tap). Debounce by 0.3 s.
13. **Pause card copy.** "Closing the phone pauses too. Open it to carry on." (`PauseView.swift:42`) is wrong while the
    menu is up: only Resume resumes. Use "Closing the phone pauses too."
14. **Demo code ships in Release, unreachable.** The demo presets, icon/badge export and `runDemoResults` are compiled in,
    but `DemoMode.current` is nil outside DEBUG (`DemoMode.swift:191-201`). Optional: wrap them in `#if DEBUG`.

## Non-Duo fallback (verified unless marked)
- **isDuo detection** = `hingeSeen || looksLikeDuoInner` (short side ≥ 600 and short/long > 0.62).
  - No iPhone has a short side ≥ 600 (Pro Max is 440). The app is iPhone-only, so iPad compatibility mode runs it at
    iPhone sizes: safe.
  - Mac "Designed for iPhone" is *unverified*: a resizable window could reach 600 × 900 and count as a Duo. Turn off Mac
    availability in App Store Connect, or add `!isiOSAppOnMac`.
  - A Duo before its first sample is still caught by size on the inner display; the cover display shows Home.
- **DragMirrorSource**: the layout is pushed in `refreshLayout` and `beginSession`, and `reset(band:)` runs every level.
  Drags are ignored while paused or hinge-driven, and `maxStep` caps a stale dt after a pause.
- **Pause without a hinge**: only the button, inactive or background. The shut rule needs `hingeDriven`, and a stray
  `shut` is cleared. Not stuck.
- **Cover display**: never shows on a regular iPhone (it needs `hingeSeen`), except after a restore (P1-1).
- **Swap halves**: Duo book pose only, in both Settings (`SettingsView.swift:34`) and layout (`GameController.swift:243`).
- **Copy**: phones get the drag line, "Close the phone…" needs `hingeDriven`, and hints and tips never mention the hinge.
- **60 Hz / Low Power**: dt is clamped to 1/30 with sub-steps, the HUD runs at 15 Hz and the drag ease is dt-based.
  Below 30 fps play goes slow-motion by design. Any Play within 2 s of launch waits up to 1.5 s.

## Checked, no bug found
- **Interruptions and stuck states**: the background → menu and cover-shut → open-to-resume paths hold, as do the resume
  grace and `hinge.reset()`. Every stage reaches Home, and the 4 Hz ticker ends `.checking`.
- **Saves and Game Center**: decoding is tolerant, demo runs never write, scores queue before sign-in, and `inFlight`
  stops double submits.
- **Memory over 50 levels**: sessions are replaced, `scene.driver` is weak, no task holds a cycle, and buffers are capped.
