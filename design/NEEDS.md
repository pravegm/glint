# Cross-module needs

Add a line under your role when you need something from another module. The owner answers by doing it (or saying why
not) and deleting the line.

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
- **Night Watch is too easy at 10,000.** The R2 mirror's Long Night medians: skill 0.3 ≈ 6,700 (3.4 min), 0.6 ≈
  17,400 (4.9 min), 0.9 ≈ 22,200 (5.3 min). achievements.md's own check wants the bar above the 0.6 median and at or
  below the 0.9 one: **20,000** fits. `Achievements.nightWatchScore` and the blurb still say 10,000 as written; change
  the number in achievements.md (both descriptions and the trigger) and tell Core to change the constant and the
  blurb together, before the tool creates it.
- achievements.md sketches `AchievementDef(id:title:detail:)` and `def(key, title, detail)`; ROUND-2 asked for
  `{ key, id, title, blurb, points }`, which is what Core built (`def("<key>", title, blurb, points)`, plus a `detail`
  alias). If the ASC tool's grep expects exactly three arguments to `def(`, it needs the fourth (points) allowed.
- Four Times Bright (chain 13) is fine: the 0.6 pilot's longest chain in Rooftops is 18–35. Ninety Suns is fine: the
  0.9 pilot gets 3★ on 6–8 of 8 seeds on every Harbour level.

## Scene (R2) → App
- `GardenScene.hudSafeRects(layout:)` (static, nonisolated) = `flowerRects(layout:)`, SwiftUI space, for the HUD
  overlap test. It is static only (no instance overload, to keep the call unambiguous).
- R2 lever: the scene no longer draws a slot on the mirror. On phones (`showsLever`) a brass rail runs along d at
  u = 1 − 30 pt / span, from d = bandMin (≈ 0.2 × garden depth up into the mirror) to the flower edge. The 44 × 20
  grip rides it at d = band exactly and pulses until the band first moves. Keep the pause button clear of that
  strip: it is the right-most 50 pt of the canvas, from 0.2 × depth above the crease down to the bottom. The mirror's
  far-right corner above that is free. The scene hides the rail and grip when `attract` is set.
