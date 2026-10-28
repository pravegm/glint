# Core R2 hand-off (Core engineer)

None of this has been compiled yet. I tuned the balance with the JS mirror, which I updated for R2 in place. It lives in
`design/notes/core-R1-sim/`. Run `node sim.js` there; it reads the env vars `SEEDS`, `SKILLS`, `LEVELS` and `EXTRA=1`.
- The level rows are in `levels.json` in that folder. That file matches `LevelBook.recipes` row for row.
- Two scripts made the rows:
  - `tune.js` bisects each level's speed. It only runs with `RETUNE=1`, because it rebuilds `levels.json` from scratch.
  - `fix.js` re-rolls each level's script by changing the murk count by up to 3 either way, and keeps the variant
    closest to the targets.
- `r2final.txt` is the raw 8-seed table.

## What changed
- **Crease shade.** `Tuning.creaseShade = 0.12`, with `Tuning.isShaded(d:)`.
  - Light does nothing for d < 0.12. Glooms and fireflies there are safe. The lit test uses a gloom's centre d.
  - `Tuning.intensity(d:band:)` and `intensity(d:radius:band:)` return 0 in the shade.
  - `unshadedIntensity(d:radius:band:)` and `intensity(distance:)` give the raw light profile.
- **Cloud shadows** (the addendum).
  - New types: `CloudSpec` (time, fromLeft, halfWidth, speed, strength) and `LevelSpec.clouds` (defaults to `[]`).
  - The session spawns each cloud just off its edge (u = −hw or 1 + hw) and drifts it at its speed. It drops a cloud
    once it is fully past the far edge (by 0.02), and publishes `snapshot.shades`.
  - Light is multiplied by `Tuning.cloudFactor(u:shades:)`. That is the product over clouds of
    1 − strength × smoothstep((hw + 0.015 − |u − c|) / 0.03), which gives the 0.03 soft edge.
  - Glooms and fireflies under a cloud are safe.
  - The numbers per mode:

    | Where | Clouds | Half-width | Drift | Strength |
    |---|---|---|---|---|
    | Rooftops | 3 per level | 0.070–0.088 (±20 %) | 0.06 u/s | 0.75 |
    | Harbour | 4–5 per level | 0.090–0.117 | 0.075 u/s | 0.9 |
    | Today's Dawn | 4 | 0.1 | 0.07 u/s | 0.85 |
    | Long Night | 1 per wave from wave 4, 2 from wave 9 | widening | 0.07 u/s | 0.7 → 1 |
- **Flower edge at 135°** (band = (θ − 80) / 55) and **drag cap 1.4**. Core works in d, so neither changes the session
  or the balance.
- **Hoppers.** Light now speeds up a resting hopper's rest timer by ×(1 + 1 × lit); it was ×(1 + 2 × lit). With the shade
  and human-like hands, hoppers were outrunning everyone.
- **Mixed fronts.** `LevelRecipe.front` is the chance a group arrives at the same moment as the one before it. A brute
  never joins a front, and nothing joins a brute.
- **DawnStats for the lost-level tips:**
  - `flowersEatenBy[kind]`, `eaten(by:)` and `worstKind`.
  - `popsBy[kind]`, `brutesPopped` and `score`.
  - `cloudBlockedSeconds` and `creaseBlockedSeconds`: light-seconds the band would have given a gloom but a cloud or the
    crease shade took away.
  - `cloudedGlooms`: glooms a cloud kept under 50 % light while the band was on them, at least once.
  - `eatenAfterCloud`: how many of those then ate a flower. This drives the "Wait for the cloud to pass" tip.
  - `clouds`: clouds that crossed the garden.
  - Suggested tip rule: if `eatenAfterCloud ≥ 2`, show the cloud tip; otherwise show the tip for `worstKind`.
- **Pilot: the human-hinge model.** Everything below scales with (1 − skill):
  - The band follows the hand through a lag of 0.1 + 0.25 × (1 − skill) s.
  - A smooth ±0.05 jitter, redrawn every 0.12 s.
  - On a big move (> 0.15 d) to a new target, a 60 % chance of overshooting by 0.04–0.12 d, which settles over about
    0.2 s.
  - I shrank R1's aim error and slip chance to 0.08 and 0.4 × (1 − skill), since the hinge model now carries most of
    the noise.
  - It never aims below 0.17 (inside the shade) and idles at 0.20. It ignores fireflies still deep in the shade.
  - It adds up to 2.5 s of slack to a gloom under a cloud, so it switches to another target and comes back later.
  - New API: `hand`, `hingeLag`, `jitterAmplitude`, `overshootChance`, `PilotBrain.idleAim`, `PilotBrain.minAim`,
    `urgency(_:in:shades:)`.
- **Achievements.swift:**
  - `AchievementDef { key, id, title, blurb, points }`, plus a `detail` alias for `blurb`.
  - Ten `def("<key>", …)` lines in achievements.md's order, 435 points in total.
  - Also `earnedBlurbs`, `chain4Chain` (13), `nightWatchScore`, `find(_:)`, and
    `earned(stats:mode:outcome:progressStars:levelsWon:) -> [String]`, which returns ids in `all` order.
  - Pass progress *after* saving the result. The App filters out ids it has already reported, and never calls this for
    attract, demo or CI sessions.

## Balance
JS mirror, 8 seeds. Each skill cell is wins / average flowers left; the 0.9 column adds 3★ runs in brackets. "field" is
the mean number of glooms on the field from 25 % to 90 % of the level, with the 0.6 pilot.

| # | Title | s | murk | wisp | br | spl | hop | ff | clouds | speed | field | 0.3 | 0.6 | 0.9 (3★) | 1.0 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | First Light | 60 | 12 | – | 0 | 0 | 0 | 0 | – | 0.80 | 0.7 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 2 | Dew | 60 | 20 | – | 1 | 0 | 0 | 0 | – | 0.80 | 1.3 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 3 | Ladder of Wisps | 65 | 24 | 3×5 | 0 | 0 | 0 | 0 | – | 0.82 | 1.4 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 4 | Fireflies | 65 | 28 | 4×5 | 0 | 0 | 0 | 3 | – | 0.84 | 1.8 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 5 | Big Feet | 70 | 30 | 4×5 | 2 | 0 | 0 | 3 | – | 0.86 | 2.2 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 6 | Clover | 70 | 67 | 8×6 | 2 | 0 | 0 | 4 | – | 1.00 | 3.9 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 7 | Morning Hush | 75 | 73 | 8×6 | 3 | 0 | 0 | 4 | – | 1.02 | 3.7 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 8 | Buttercups | 75 | 82 | 10×6 | 4 | 0 | 0 | 5 | – | 1.15 | 4.2 | 8/8 4.9 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 9 | Long Shadows | 80 | 92 | 10×6 | 5 | 0 | 0 | 5 | – | 1.18 | 4.1 | 8/8 4.6 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 10 | Meadow Sunrise | 85 | 103 | 11×6 | 5 | 0 | 0 | 6 | – | 1.20 | 4.7 | 8/8 4.4 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 11 | Chimney Pots | 75 | 56 | 6×6 | 3 | 2 | 0 | 4 | 3 ×0.070 | 0.87 | 3.9 | 8/8 4.3 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 12 | Split Ends | 75 | 56 | 6×6 | 3 | 3 | 0 | 4 | 3 ×0.072 | 0.77 | 4.5 | 8/8 4.3 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 13 | Slate Grey | 80 | 58 | 6×6 | 3 | 3 | 0 | 5 | 3 ×0.074 | 1.22 | 3.0 | 6/8 2.4 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 14 | Hop Along | 80 | 62 | 6×6 | 3 | 2 | 2 | 4 | 3 ×0.076 | 0.95 | 3.4 | 8/8 3.8 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 15 | Gutters | 80 | 65 | 7×6 | 3 | 3 | 2 | 5 | 3 ×0.078 | 0.87 | 4.0 | 8/8 3.8 | 8/8 4.9 | 8/8 5.0 (8) | 8/8 5.0 |
| 16 | Weathervane | 85 | 67 | 7×6 | 4 | 3 | 3 | 5 | 3 ×0.080 | 0.82 | 4.6 | 8/8 3.5 | 8/8 4.6 | 8/8 5.0 (8) | 8/8 5.0 |
| 17 | Pigeon Row | 85 | 67 | 7×6 | 4 | 4 | 3 | 5 | 3 ×0.082 | 0.83 | 5.0 | 8/8 3.5 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 18 | Tin Roofs | 90 | 72 | 8×6 | 4 | 4 | 3 | 6 | 3 ×0.084 | 0.83 | 5.1 | 7/8 2.6 | 8/8 4.1 | 8/8 5.0 (8) | 8/8 5.0 |
| 19 | Skylight | 90 | 76 | 8×6 | 5 | 4 | 4 | 6 | 3 ×0.086 | 0.95 | 4.6 | 6/8 2.3 | 8/8 4.8 | 8/8 5.0 (8) | 8/8 5.0 |
| 20 | Rooftop Dawn | 95 | 74 | 8×6 | 5 | 5 | 4 | 6 | 3 ×0.088 | 0.86 | 4.8 | 7/8 3.3 | 8/8 4.8 | 8/8 5.0 (8) | 8/8 5.0 |
| 21 | Low Tide | 85 | 55 | 6×7 | 2 | 2 | 2 | 4 | 4 ×0.090 | 1.50 | 2.6 | 0/8 0.0 | 8/8 4.3 | 8/8 5.0 (8) | 8/8 5.0 |
| 22 | Rope and Rigging | 85 | 59 | 6×7 | 3 | 3 | 2 | 4 | 4 ×0.093 | 1.47 | 3.1 | 0/8 0.0 | 7/8 4.1 | 8/8 5.0 (8) | 8/8 5.0 |
| 23 | Gull Cry | 90 | 62 | 7×7 | 3 | 3 | 3 | 4 | 5 ×0.096 | 0.96 | 4.6 | 4/8 0.8 | 8/8 4.1 | 8/8 5.0 (8) | 8/8 5.0 |
| 24 | Fog Bank | 90 | 60 | 7×7 | 4 | 4 | 3 | 4 | 5 ×0.099 | 0.98 | 4.8 | 0/8 0.0 | 8/8 4.1 | 8/8 5.0 (8) | 8/8 5.0 |
| 25 | Lantern Row | 90 | 67 | 8×7 | 4 | 4 | 4 | 4 | 5 ×0.102 | 1.28 | 5.0 | 0/8 0.0 | 5/8 2.8 | 8/8 5.0 (8) | 8/8 5.0 |
| 26 | Lighthouse | 95 | 65 | 8×7 | 5 | 5 | 4 | 4 | 5 ×0.105 | 0.99 | 4.9 | 0/8 0.0 | 8/8 3.0 | 8/8 5.0 (8) | 8/8 5.0 |
| 27 | Undertow | 95 | 66 | 8×7 | 5 | 5 | 5 | 4 | 5 ×0.108 | 1.19 | 5.2 | 0/8 0.0 | 7/8 2.9 | 8/8 4.9 (7) | 8/8 4.9 |
| 28 | Night Ferry | 95 | 67 | 9×7 | 6 | 6 | 5 | 3 | 5 ×0.111 | 0.79 | 7.1 | 0/8 0.0 | 8/8 2.9 | 8/8 4.8 (6) | 8/8 5.0 |
| 29 | Last Watch | 95 | 74 | 9×7 | 6 | 6 | 6 | 3 | 5 ×0.114 | 1.01 | 6.3 | 0/8 0.0 | 6/8 3.1 | 8/8 5.0 (8) | 8/8 4.9 |
| 30 | Harbour Sunrise | 95 | 72 | 10×7 | 7 | 7 | 6 | 3 | 5 ×0.117 | 0.77 | 6.7 | 2/8 0.3 | 7/8 2.4 | 8/8 4.9 (7) | 8/8 4.6 |

**Against the R2 targets:**

| Target | Result | Met? |
|---|---|---|
| L1–3: 0.3 wins every time with 5 flowers | 8/8, 5.0 | Yes |
| L4–10: 0.3 always wins, loses 0–1 flower by L8–10 | Always wins; loses 0.1–0.6 at L8–10 | Yes |
| Rooftops: 0.3 wins 60–90 % | Wins 75–100 % | A little generous |
| Rooftops: 0.3 loses 1–2 flowers by L15–20 | Loses 0.7–2.7 from L13 | Yes |
| Rooftops: 0.6 wins everything, loses ≤ 1 | Wins all, loses ≤ 0.9 | Yes |
| Harbour: 0.3 wins ≤ 30 % | Wins 0–50 %; L23 is the only level over 30 % | One miss |
| Harbour: 0.6 wins 70–100 %, losing 1–3 | Wins 62–100 %, losing 0.7–2.6; L25 is 5/8, under 70 % | One miss |
| Harbour: 0.9 wins everything, mostly 3★ | Wins all, 3★ on 6–8 of 8 | Yes |
| 4–10 glooms on the field from L6 | 4–7 from L8; L6–7 and the openers L11, L13, L14, L21, L22 sit at 2.6–3.9 | Partly |

Speeds vary from level to level on purpose: the tuner picked them, and the counts were re-rolled around each one. So
Harbour has fast tides (L21–22 at 1.5×) and slow, dense fogs (L28 and L30 at 0.77×). If the critics prefer a smooth
ramp, set the speeds in `levels.json` and re-roll the counts with `fix.js`.

Today's Dawn plays like Harbour: on 4 seeds, 0.3 loses every time, 0.6 keeps 4.5 flowers and 0.9 keeps 4.8.

Long Night medians:

| Skill | Median score | Median length |
|---|---|---|
| 0.3 | 6,700 | 3.4 min |
| 0.6 | 17,400 | 4.9 min |
| 0.9 | 22,200 | 5.3 min |

**Night Watch at 10,000 sits below the 0.6 median. I recommend 20,000** (see NEEDS.md). `nightWatchScore` and the blurb
still say 10,000, as achievements.md has it.

Four Times Bright (chain 13) is reachable: the 0.6 pilot's longest chain in Rooftops is 18–35.

## Tests
- **CoreTests, existing tests updated:**
  - The angle map for the 135° edge: 107.5° gives 0.5, 129.5° gives 0.9; `angle(forBand:)` maps 0 to 80° and 1 to 135°,
    clamped.
  - Tuning constants: 135, 1.4 and 0.12.
  - Telemetry: the band now sits at 0.25, out of the shade.
  - The hopper test: with the shade, riding a hopper is no slower than parking on it, and both pop it.
  - The daily test: stars come out as 0, checked with a tiny daily script.
  - `worldsGetHarder` now checks HP and clouds (none in Meadow, more and wider in Harbour), since speeds no longer ramp.
- **CoreTests, new tests:**
  - Shade maths, and a band held in the shade can't pop a murk.
  - `cloudFactor` maths.
  - A wide cloud keeps a murk safe: blocked seconds, `cloudedGlooms`, `eatenAfterCloud` and `worstKind` all check out.
  - A wide cloud spares a firefly.
  - Stats by kind.
  - Rooftops levels bring clouds.
  - The hinge wobble is visible at skill 0 and absent at skill 1.
  - The pilot never aims into the shade, and prefers the unshaded one of two identical glooms.
  - The achievements table: 10 keys, 435 points, the ids.
  - Every achievement threshold, just below and exactly at it.
  - A real wisp flock earns Clean Sweep.
- **BalanceTests:** each line now ends with `three=<runs with 5 flowers> field=<mean glooms on the field>`. Levels 1–3
  must be won by 0.3.

## Compile risks
- `LevelSpec` and `LevelRecipe` gained stored properties with defaults, so their memberwise inits keep the R1 call
  shapes.
- `DawnStats` now holds two `[GloomKind: Int]` dictionaries; it is still Equatable. `DawnGloom.clouded` has a default.
- `Achievements` uses `allSatisfy` with an explicit closure type. `AchievementDef` is `Sendable` (Strings and Ints only).
- Per-frame cost: while clouds are up, `snapshot.shades = shades` shares a buffer that the next drift step copies. That
  is at most 2 elements.
