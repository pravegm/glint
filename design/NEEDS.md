# Cross-module needs

Add a line under your role when you need something from another module. The owner answers by doing it (or saying why
not) and deleting the line.

## Core (R5b) → founder / Scene (from QA-R5)
- **Clouds:** Core now caps the band at `Tuning.maxLiveClouds` = 4 live clouds in every mode. A later cloud waits just
  off its edge until one leaves. This is tested, and the balance effect is nil (Harbour rarely has more than 3 at once).
- **Floating ×n (QA-R5-player #8):** Scene can show the multiplier instead of the chain count:
  `Tuning.multiplier(chain:)` on `.popped`'s `chain`, or `snapshot.multiplier`. It tops out at ×4.
- **Achievement copy (QA-R5-player):** the suggested rewordings are "Reach a ×4 multiplier: 13 pops in a row." and
  "Pop 3 or more shadows in one Sweep." The App Store Connect tool reads these strings from both `Achievements.swift`
  and docs/appstore/achievements.md, so say the word and Core will change `Achievements.swift` to match.
- **GAME-DESIGN §3–§6 is stale (QA-R5-store F11).** The current rules in `Tuning`:
  - edge 135°
  - band core ±0.065, edge ±0.10
  - firefly scorch: 0.6 s, core only, plus a dart
  - drag cap 1.4
  - brute HP 4.5
  - crease shade 0.12
  - glooms travel submerged to 0.15–0.60
  - ★★★ score bars from L4
  - levels last 35–95 s

## Core (R1) → founder (docs only; Core already does the right thing)
- Contracts.swift `MirrorInput` comments say the band hides "θ < 85°" and the crease glow spans "θ 15°…85°";
  GAME-DESIGN §3 and `Tuning` use 80° (band 0 at 80°, glow full at 80°). Please fix the two comments.
- GAME-DESIGN §6 says brutes arrive "from 5", §7 says "Level 2, first brute: Follow the big ones". Core puts one slow
  teaching brute in level 2 (Dew), none in 3–4, and brutes in every level from 5. Confirm or say which.
- GAME-DESIGN §4: brute HP 2.2 contradicts "parked light can't finish it" (a parked band gives a brute ≈ 3.1 s of
  light). `Tuning`/`GloomSpec` use 3.6. Hoppers also got one rule: light hurries a resting hopper's clock ×(1 + 2 ×
  intensity), so it hops on through a parked band (popping there takes ≈ 3 s of luck) while a band that rides on it
  pops it in ≈ 1.3 s. Please update §4. (R2: the hurry is now ×(1 + 1 × intensity).)

## Core (R2) → founder / launch lead (docs/appstore/achievements.md is not Core's file)
- **R3: Night Watch stays at 20,000.** I retuned Long Night for R3's 30 s jump so that 20,000 still sits between the
  medians. The mirror's medians are 0.3 ≈ 5,300, 0.6 ≈ 17,800 and 0.9 ≈ 23,600. The R2 note below is kept for the
  record.
- (R2) **Night Watch is too easy at 10,000.** The R2 mirror's Long Night medians: skill 0.3 ≈ 6,700 (3.4 min), 0.6 ≈
  17,400 (4.9 min), 0.9 ≈ 22,200 (5.3 min). achievements.md's own check wants the bar above the 0.6 median and at or
  below the 0.9 one: **20,000** fits. `Achievements.nightWatchScore` and the blurb still say 10,000 as written; change
  the number in achievements.md (both descriptions and the trigger) and tell Core to change the constant and the
  blurb together, before the tool creates it.
- achievements.md sketches `AchievementDef(id:title:detail:)` and `def(key, title, detail)`; ROUND-2 asked for
  `{ key, id, title, blurb, points }`, which is what Core built (`def("<key>", title, blurb, points)`, plus a `detail`
  alias). If the ASC tool's grep expects exactly three arguments to `def(`, it needs the fourth (points) allowed.
- Four Times Bright (chain 13) is fine: the 0.6 pilot's longest chain in Rooftops is 18–35. Ninety Suns is fine: the
  0.9 pilot gets 3★ on 6–8 of 8 seeds on every Harbour level.

## App (R3) → Scene (answered by Scene R4)
- Done: `GardenScene.sunRect(layout:dawn:moonlit:)` (nonisolated, SwiftUI space) is the menus' sun disc, padded to its
  glow (1.4 × r + 4 pt). It uses the mirror's own formula (`GardenMirror.sunCircle`), so it can't drift. The menus'
  sun is the warm half-risen one (dawn 0.5), even when the attract garden runs a Long Night.
- Done: `GardenScene.mirrorFrameThickness(layout:)` is the same rule the frame draws with
  (`GardenMirror.frameThickness`). Please call it instead of copying the number.

## Scene (R4) → App (ROUND-4 item 9: book-pose thumb room)
- **In book layouts (`foldVertical`), the garden's d = 1 line is now 60 pt in from its outer edge**
  (`GardenMath.flowerInset(layout:)`: 60 pt, at most 20 % of the garden's depth; 0 in laptop and phone layouts). The
  flower row moves in with it, and the ground carries on under the thumb. Core's floor space is unchanged: the scene
  maps d 0…1 onto the inset depth.
- `GardenScene.hudSafeRects(layout:)` / `flowerRects(layout:)` already return the moved rects (tested: ≥ 60 pt from
  the outer edge at 951 × 669, both ways round). Keep pause and score clear of them as before.
- **If any overlay points at something in the garden** (hint arrows, rings on a firefly or brute), map with
  `GardenScene.canvasPoint(layout:u:d:)` (SwiftUI space), **not** `layout.point(u:d:)`. In book layouts the two
  differ by up to 60 pt near the flowers. They are identical in laptop and phone layouts.
- No Contracts change needed (no `flowerInset` field).

## Feel (R5) → App (from QA-R5-scene-feel)
- Optional: call `FeedbackDirector.shared.prepare()` when the "Close the phone to start" card appears (Play tapped).
  It wakes the audio and haptic engines on their own task, off the frame loop. `ui(.levelStart)` already calls it, so
  this only helps the time spent on the card.
- QA-R5-app P1-3 (Results chimes leaking into the next level) is App-side: Feel plays `ui(.star)`/`ui(.unlock)` when
  asked. Cancel the Results task before Retry/Next.

## App (R5) → Scene (answered by Scene R5)
- Done: the floating word is the multiplier (`GardenScene.multiplierText(chain:)` from `Tuning.multiplier(chain:)`:
  "×1.5", "×2.25", "×4"). Sweeps say "Sweep of 5!" (no "×" outside the multiplier).

## Scene (R5) → App
- Multi-touch drag: the scene now enables `isMultipleTouchEnabled`, and the newest finger takes over the drag
  (`dragEnded` then `dragBegan`). When the dragging finger lifts and another is still down, the next one that moves
  sends `dragBegan`. The scene also ends the drag inside `apply(layout:)`. The App side of QA P1-3 is still open: a
  finger that landed while paused is refused by `GameController.dragBegan`. Please treat a `dragMoved` with
  `dragging == false` (playing, not paused) as a `dragBegan` at that point. The drag is relative, so nothing jumps.
- QA P2-5: ground textures for every world are now prewarmed in the background per canvas size and kept until a
  memory warning. Skipping `apply(layout:)` while the cover is shown is no longer needed (it costs nothing now), but it
  is harmless.
- Player QA #19: the garden keeps its "Wave n" label; drop the HUD's banner.
- Player QA #11: the rail now runs on the garden's outer margin (13 pt in), and the grip lies along it, starting
  30 pt below the crease (clear of the frame's corner bolt). The store copy "a brass lever beside the garden" fits.

## App (R5) → Core / founder
- Player QA #18: a `.wisps` hint ("Wisps come in flocks. Sweep them in one pass.") needs a new `HintID` case
  (Contracts) and Core raising it on L3. The App will add the copy and the subject rule once the case exists.
- Player QA copy for `Achievements.swift`: "Pop 3 or more shadows in one Sweep." and "Reach a ×4 multiplier: 13 pops
  in a row." (these are Core strings).

## App (R5d) → Scene / founder
- **Fireflies read small (store P04):** at store-frame scale a firefly is a tiny dot beside a murk. Could the Scene
  give fireflies a bigger lime halo and a short trail that shows even at the drift speed (0.075 d/s), not only
  during a dart? `stage=fireflies` now freezes one just past the band, mid-dart, plus two higher up.
- **Demo freezes hold the view:** a demo freeze now pauses the `SpriteView` (`GameController.sceneHeld`), so FX stay
  exactly as drawn at the freeze. If a Scene effect needs frames after a freeze, tell App.
- **Dynamic Island pill in raw P04 (run 40933534304):** nothing in the app differs for that stage. The status bar
  and system overlays are always hidden, no hint, toast or alert was up at capture (log), and the app has no Live
  Activity or Now Playing. The black pill is the simulator's own island state at that capture. Re-capture, or have
  `ci/store-set.sh` flag a dark pill at the top centre (CI is not App's file).
