# App engineer, round 2

Nothing here has been compiled (CI is the compiler). Nothing is committed: the founder pushes. I coded against the
real files on disk:
- Core `Achievements.swift` (`def(key, title, blurb, points)`, `earned(stats:mode:outcome:progressStars:levelsWon:)`)
  and `DawnStats` (`flowersEatenBy`, `worstKind`, `eatenAfterCloud`, …);
- Scene `GardenScene.flowerRects` / `hudSafeRects` (nonisolated static);
- Feel `FeedbackDirector`.

## ROUND-2 "App engineer"
- **HUD at the mirror's far corners.**
  - `AppRules.hudCenter` now measures from the mirror's far edge (away from the crease): score + chain on the u = 0
    side, pause on the u = 1 side. In book pose these are the mirror's two outer corners.
  - The plates' sizes are in `PlayHUD.scoreSize(compact:)`, `pauseSize` and `margin`, shared with the tests.
  - Test `hudNeverCoversAFlower`: all four layouts on 951 × 669, 669 × 951 and 402 × 874. The plates never meet
    `GardenScene.hudSafeRects`, never meet the crease band on a Duo, and sit on the mirror.
  - Test `pauseClearsTheLeverRail` checks Scene's R2 rail strip on phones.
- **World tabs: no truncation at 402 pt.** Two short lines ("Meadow" / "★ 24/30"; locked: "🔒 ★ 20", from
  `AppRules.worldTabStatus`). The art sits beside them only on wide canvases.
- **Game Center.**
  - `GameCenterManager.achievementIDs` (`nonisolated static let … = Achievements.all.map(\.id)`).
  - `enum Leaderboard` has the exact literals.
  - Results run `Achievements.earned` on the finished session plus the saved progress, file new ids in
    `ProgressData.achievements` and report them.
  - `setHoldBanners(route == .play)` holds achievement reports while a level is on screen, so banners land with the
    Results card. A Long Night left early still gets checked (for Night Watch).
  - On every sign-in, all earned achievements and the star total are re-sent.
  - `glint.stars` gets the total stars after every level result.
- **`screen=badges`.**
  - `UI/AchievementArt.swift`:
    - `AchievementBadge` draws a dawn-blue field, a medallion whose metal shows the tier (copper 10–25, brass with a
      gold ring for 50, gold with rays for 100), and one motif per key, matching achievements.md "Images";
    - `BadgeExport` renders each at 1024² as an opaque RGB PNG flattened on #141A3A, to `Documents/badges/<id>.png`;
    - `BadgeGallery` shows them on screen.
  - It logs `GLINT-T badges done 10`.
- **Reduce motion follows iOS.** The setting is `SettingsData.reduceMotionChoice: Bool?` (nil = follow iOS, a new
  JSON key). The Settings switch (`reduceMotionShown`) shows the effective value, and flipping it records a choice.
  The rule is `AppRules.reduceMotion(choice:system:)`.

## R2 addendum
1. **Icon.**
   - `IconPainter` paints the reference composition (the committed `AppIcon-1024.png`) with plain CoreGraphics
     (`UIGraphicsImageRenderer`, CPU: no SpriteKit, no GPU effects).
   - `AppIconArt` shows it. `IconExport` renders `AppIconArt` through `ImageRenderer`.
   - If the render's mean luminance is < 0.08, it falls back to the painter's own image (`GLINT-T icon renderer came
     back black; …`).
   - It always logs `GLINT-T icon stats lum= colours=`, and logs `GLINT-T icon dark …` when the final image is still
     < 0.08.
   - Tested: the painter's image has luminance ≥ 0.08, ≥ 40 colours, and colour type 2.
2. **No control within ±28 pt of the crease on Duo layouts.**
   - `AppRules.menuRegions` returns two regions, each 32 pt clear of the crease and inside the safe area: the mirror
     half (`secondary`: titles and art) and the garden half (`primary`: controls).
   - `SplitMenu` (UI/Theme.swift) lays out Home, Levels, Settings, About, Pause and Results this way on a Duo, and as
     one centred column on phones. Home's Play is on the garden half.
   - Test `menusKeepEveryControlOffTheCrease`: four layouts × both Duo sizes, plus the phone.
3. **`fold=1` on a phone simulator.**
   - The pilot drives the band (`DemoMode.wantsFallbackPilot` includes `fold`; a real hinge still takes over).
   - The lever shows only when `AppRules.showsLever` allows it: in play, drag-driven, never on a Duo layout, never in
     menus.
   - Swap halves is now Duo-only: hidden in Settings on phones and ignored in their layout.
4. **Hints.**
   - The line sits on the garden at d = 0.4 (`AppRules.hintCenter`), sized like the prompt card so it stays off the
     flowers (tested), never on the sun.
   - A gold arrow points at the subject (`AppRules.hintSubject`: the first gloom of that kind, or the first firefly),
     published at 15 Hz as `HUDModel.hintTarget`.
   - The banner stays on the mirror.
5. **Lost-level tip.** `TipRules.tip(won:stats:)`:
   - cloud, when clouds cost at least half the eaten flowers;
   - else the kind that ate the most (brute, wisp, hopper, splitter, murk);
   - else fireflies.
   Results also show the five flowers (eaten ones greyed), and "New best!" on a first clear too.
6. **Today's Dawn streak.**
   - `ProgressData.dailyPlayed`; `ProgressRules.dailyStreak` (ending today, or yesterday).
   - The Home card says "Day 3 streak" / "✓ Day 3 streak" / "✓ Today 2,140" / "New today".
   - The cover display, in menus, says "Today's Dawn is up" or "Today: 2,140 · streak 3". When paused it shows the
     score and the flowers left.
   - The cover art is now the brass mirror.

## Founder notes
- **Store pipeline** (all hold):
  - `GLINT-T band` keeps logging after a freeze, and logs the band the frame draws (`snap.band`, the pinned band
    when frozen), not the moving input.
  - `freezeOn=sweep` (with or without `t=`) prints `GLINT-T freeze sweep` 0.3 s after the first Sweep.
  - With a real hinge, `t=` / `skill=` skip "Close the phone to start" and the pilot drives.
  - `GLINT-T canvas … fold=1` on the Duo (hinge seen or inner-display shape), `fold=0` on phones.
- **About.** "Designed and built with Claude. Every picture and every sound is made in code." plus "© 2026 pravegm".
  No personal names.
- **Review extras done:**
  - Home "Sunrises" → "Levels", with 13 pt captions under the round buttons;
  - chain shown as "Chain 7";
  - won Results = Next sunrise + Retry, with Levels / Home as quiet links;
  - menus get a real blur plus the #140F2E scrim.

## CI / workflow changes needed (founder-owned files)
1. `ci/scenarios.txt`: add `20-badges|screen=badges|12|the ten Game Center badges|GLINT-T badges done`.
   `screenshots.sh` already copies `Documents/badges/` because the args contain "badges".
2. `ci/store-set.sh` / `ci/duo-store.sh`: the book angle is now θ = 80 + 55 × band (flower edge at 135°, Core R2), not
   80 + 65 × band.
3. Optional: ci.yml's icon step could fail on a `GLINT-T icon dark` line.
4. `ci/scenarios.txt` captions 03/05/06/10 still describe the R1 layout (HUD on the garden corner, the menu centred
   across the fold, a lever on fold frames).

## Compile risks
- `nonisolated static let achievementIDs` inside the `@MainActor` `GameCenterManager`. It's a Sendable `[String]`
  built from Core's nonisolated `Achievements`.
- The generic `SplitMenu` / `SplitRegion` views take `@escaping @ViewBuilder` closures, stored as properties.
- `IconPainter` uses CoreGraphics only (`CGGradient(colorsSpace:colors:locations:)` with a `[CGFloat]`, and
  `setShadow(offset:blur:color:)` with nil). `IconPainter.stats` and `darkLuminance` are nonisolated; one icon test is
  `@MainActor`.
- `SettingsStore.reduceMotionShown` is a get/set computed property on an `ObservableObject`, used as
  `$settings.reduceMotionShown`.
- `MenuScrim` uses `.ultraThinMaterial`.
- The tests construct `DawnStats()`, `GloomState`, `FireflyState` and `GardenLayout(size:foldVertical:gardenAfter:gardenFraction:)`
  directly.

## Not done
- Review P0-6 (switch to drag if the hinge goes silent for 1.5 s mid-level, with "Can't read the hinge: drag to aim").
  It wasn't in the addendum; it is a small follow-up.
- Level names under the medallions, locked-node silhouettes, the "★★★ 1,200" score target, and per-mode looks
  (Long Night moonlit, the daily date chip): these are Scene or later rounds.
