# Core R4 hand-off (Core engineer)

None of this has been compiled yet, and nothing is committed.

**Sim calibration.** The JS sim in `design/notes/core-R1-sim/` matches CI's R3 `GLINT-BAL` table closely
(`artifacts/r3/logs/build.log`). For example:
- L1 scores 320 in both.
- L6 at skill 0.3 keeps 4.0 flowers on CI and 4.1 in the sim.
- L21 at skill 0.3 wins 1/6 on CI and 2/8 in the sim.
- Harbour at skill 0.6 keeps 2.7–4.2 flowers on CI and 2.8–4.1 in the sim.

So I kept it as the tuning tool. Its raw outputs are `r4final.txt`, `r4worlds.txt`, `r4parked.txt` and
`r4modes.txt`. New in the sim folder: `worlds.js`, `ffcheck.js`, and `targets.js` updated for R4.

## What changed (ROUND-4 Core 1–4)
1. **The curve:**
   - L1–3 stay gentle but are re-rolled with crowd 2–3 and 35 % fronts, so scores spread out. Their ★★★ bar sits
     just above the skill-0.3 hand's median score.
   - L4 gets its first brute and deep surfacers; L4–5 are fast.
   - Rooftops gets harder. Harbour opens softer at L21–22 and falls from there.
   - `starScore` is refit: from L4 the bar is the 0.6 hand's ~60 % bar, capped by the 0.9 hand's (~90 %; ~75 % in
     Harbour).
2. **Fireflies can be spared:**
   - Only the band's full core scorches (|d − band| − pad ≤ 0.065). It takes 0.6 s in all (`fireflyScorchLimit`),
     draining at 0.8/s outside the core.
   - The first touch of any light makes a firefly dart outward +0.08 over 0.3 s (`fireflyDart`, `fireflyDartTime`).
     I tried "away from the band" too; it was worse (2.0–2.4 burns per level at skill 0.6).
   - Fireflies left the load layout. Each one takes the widest unused gap between gloom groups near its slot (15–85 %
     of the window). That holds in daily and Long Night too.
   - The pilot keeps 0.17 − 0.04 × skill away from them. An unsure hand gives them more room, which is how it learns to
     skip them. It only stops caring past d 0.85.
3. **L1 opener:** `LevelRecipe.opener` adds one murk at t = 0, starting at d 0.14 (`SpawnGroup.startD`, new and
   optional). It surfaces at d ≈ 0.30 after 1.25–1.3 s.
4. **BalanceTests summary:** one `GLINT-BAL world=<w> skill=<s> winrate= flowers= three= scorched=` line per world
   and skill. I also added a loose `firefliesAreSpareable` assert: per level, 0.9 ≤ 0.5 fizzles and 0.6 ≤ 1.5.

## Per world (sim, 8 seeds × 10 levels)

| world | skill | winrate | flowers | ★★★ | scorched / level |
|---|---|---|---|---|---|
| 1 Meadow | 0.3 | 1.00 | 4.26 | 0.21 | 0.85 |
| 1 Meadow | 0.6 | 1.00 | 4.97 | 0.71 | 0.31 |
| 1 Meadow | 0.9 | 1.00 | 5.00 | 0.82 | 0.05 |
| 2 Rooftops | 0.3 | 0.86 | 3.04 | 0.06 | 1.27 |
| 2 Rooftops | 0.6 | 1.00 | 4.90 | 0.65 | 0.66 |
| 2 Rooftops | 0.9 | 1.00 | 5.00 | 0.99 | 0.09 |
| 3 Harbour | 0.3 | 0.20 | 0.47 | 0.00 | 0.56 |
| 3 Harbour | 0.6 | 0.96 | 3.46 | 0.29 | 0.38 |
| 3 Harbour | 0.9 | 1.00 | 4.97 | 0.94 | 0.03 |

**Against the R4 targets:**

| Target | Result | Met? |
|---|---|---|
| L1–3: skill 0.3 gets ★★★ ≤ 50 % | 1/8, 3/8, 4/8 (the 0.9 hand gets 2/8, 5/8, 4/8) | Yes |
| L4–5: skill 0.3 loses 0.5–1 flower | Loses 0.6–0.7 | Yes |
| 0.3's win rate falls smoothly, ~100 % → ~60 % → ~15 % | 100 % → 86 % → 20 %; L21 50 %, L22–30 0–38 %, no cliff | Rooftops a little high |
| Rooftops: 0.3 wins 60–80 % | 75–100 % per level | A little high |
| Rooftops: 0.3 loses 1.5–2.5 flowers | Keeps 2.5–3.9 (loses 1.1–2.5) | Mostly |
| Harbour: 0.9 gets ★★★ ≥ 70 % on every level | 7–8/8 on every level | Yes |
| Fireflies: 0.6 burns ≤ 1 per level | 0.3–0.7 | Yes |
| Fireflies: 0.9 burns ≤ 0.3 per level | 0.03–0.09 | Yes |

The parked band still fails: L6 loses 3–5 flowers at every depth, L11 4.7–5, L21 all 5.

Long Night medians are 8,300 / 11,900 / 24,100 for skills 0.3 / 0.6 / 0.9, so Night Watch at 20,000 still sits
between the 0.6 and 0.9 medians. On Today's Dawn, 0.3 wins 1/5 of seeds, while 0.6 and 0.9 keep 4.6 flowers on average.

## Levels (sim, 8 seeds; wins / avg flowers, 3★ runs in brackets)
| # | Title | murk | br | spl | hop | ff | speed | ★★★ | field | 0.3 (3★) | 0.6 (3★) | 0.9 (3★) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | First Light | 12 | 0 | 0 | 0 | 0 | 0.80 | 400 | 0.8 | 8/8 5.0 (1) | 8/8 5.0 (3) | 8/8 5.0 (2) |
| 2 | Dew | 20 | 1 | 0 | 0 | 0 | 0.80 | 950 | 1.3 | 8/8 5.0 (3) | 8/8 5.0 (7) | 8/8 5.0 (5) |
| 3 | Ladder of Wisps | 24 | 0 | 0 | 0 | 0 | 0.82 | 1650 | 1.7 | 8/8 5.0 (4) | 8/8 5.0 (4) | 8/8 5.0 (4) |
| 4 | Fireflies | 31 | 1 | 0 | 0 | 3 | 1.53 | 2150 | 1.7 | 8/8 4.3 (1) | 8/8 4.8 (5) | 8/8 5.0 (8) |
| 5 | Big Feet | 27 | 2 | 0 | 0 | 3 | 1.58 | 1950 | 1.6 | 8/8 4.4 (0) | 8/8 5.0 (5) | 8/8 5.0 (8) |
| 6 | Clover | 66 | 3 | 0 | 0 | 4 | 1.20 | 5550 | 5.4 | 8/8 3.6 (2) | 8/8 5.0 (8) | 8/8 5.0 (8) |
| 7 | Morning Hush | 74 | 3 | 0 | 0 | 4 | 1.39 | 6000 | 5.2 | 8/8 3.8 (1) | 8/8 5.0 (6) | 8/8 5.0 (8) |
| 8 | Buttercups | 80 | 4 | 0 | 0 | 5 | 0.98 | 7250 | 7.0 | 8/8 3.6 (1) | 8/8 5.0 (8) | 8/8 5.0 (8) |
| 9 | Long Shadows | 87 | 6 | 0 | 0 | 5 | 1.03 | 7650 | 7.9 | 8/8 4.4 (4) | 8/8 5.0 (5) | 8/8 5.0 (8) |
| 10 | Meadow Sunrise | 104 | 7 | 0 | 0 | 6 | 1.30 | 8950 | 7.0 | 8/8 3.6 (0) | 8/8 5.0 (6) | 8/8 5.0 (7) |
| 11 | Chimney Pots | 53 | 3 | 2 | 0 | 4 | 0.72 | 4150 | 6.7 | 8/8 3.4 (1) | 8/8 4.9 (5) | 8/8 5.0 (8) |
| 12 | Split Ends | 53 | 3 | 3 | 0 | 4 | 0.98 | 4850 | 5.3 | 7/8 3.5 (0) | 8/8 5.0 (4) | 8/8 5.0 (8) |
| 13 | Slate Grey | 58 | 3 | 3 | 0 | 5 | 0.84 | 5100 | 6.2 | 7/8 3.9 (2) | 8/8 4.8 (5) | 8/8 5.0 (8) |
| 14 | Hop Along | 63 | 3 | 2 | 2 | 4 | 0.92 | 5100 | 6.4 | 7/8 3.3 (1) | 8/8 4.9 (6) | 8/8 5.0 (8) |
| 15 | Gutters | 66 | 3 | 3 | 2 | 5 | 0.66 | 5850 | 7.6 | 8/8 3.0 (0) | 8/8 4.6 (5) | 8/8 5.0 (8) |
| 16 | Weathervane | 65 | 4 | 3 | 3 | 5 | 0.92 | 6000 | 5.5 | 6/8 2.5 (1) | 8/8 5.0 (5) | 8/8 5.0 (8) |
| 17 | Pigeon Row | 63 | 4 | 4 | 3 | 5 | 0.81 | 6200 | 5.3 | 6/8 2.8 (0) | 8/8 5.0 (5) | 8/8 5.0 (8) |
| 18 | Tin Roofs | 67 | 4 | 4 | 3 | 6 | 0.81 | 6550 | 6.7 | 7/8 2.9 (0) | 8/8 4.9 (6) | 8/8 5.0 (8) |
| 19 | Skylight | 79 | 5 | 4 | 4 | 6 | 0.75 | 7300 | 7.9 | 6/8 2.6 (0) | 8/8 5.0 (6) | 8/8 5.0 (7) |
| 20 | Rooftop Dawn | 84 | 5 | 5 | 4 | 6 | 0.80 | 7450 | 7.9 | 7/8 2.6 (0) | 8/8 5.0 (5) | 8/8 5.0 (8) |
| 21 | Low Tide | 51 | 2 | 2 | 2 | 4 | 1.05 | 4300 | 3.7 | 4/8 1.4 (0) | 8/8 4.0 (2) | 8/8 5.0 (8) |
| 22 | Rope and Rigging | 58 | 3 | 3 | 2 | 4 | 1.17 | 5100 | 4.8 | 2/8 0.4 (0) | 8/8 3.3 (1) | 8/8 4.9 (7) |
| 23 | Gull Cry | 64 | 3 | 3 | 3 | 4 | 0.67 | 5700 | 8.1 | 2/8 0.4 (0) | 8/8 3.9 (3) | 8/8 5.0 (8) |
| 24 | Fog Bank | 56 | 4 | 4 | 3 | 4 | 0.86 | 5800 | 5.4 | 1/8 0.5 (0) | 7/8 3.9 (4) | 8/8 4.9 (7) |
| 25 | Lantern Row | 69 | 4 | 4 | 4 | 4 | 0.87 | 7350 | 7.5 | 3/8 1.0 (0) | 8/8 3.5 (3) | 8/8 5.0 (7) |
| 26 | Lighthouse | 60 | 5 | 5 | 4 | 4 | 1.01 | 6550 | 5.2 | 2/8 0.9 (0) | 8/8 4.1 (3) | 8/8 5.0 (8) |
| 27 | Undertow | 67 | 5 | 5 | 5 | 4 | 1.05 | 7300 | 5.6 | 1/8 0.1 (0) | 8/8 3.3 (2) | 8/8 5.0 (7) |
| 28 | Night Ferry | 69 | 6 | 6 | 5 | 3 | 0.75 | 8050 | 8.0 | 0/8 0.0 (0) | 7/8 3.3 (3) | 8/8 5.0 (8) |
| 29 | Last Watch | 74 | 6 | 6 | 6 | 3 | 0.75 | 8700 | 8.3 | 0/8 0.0 (0) | 8/8 2.9 (0) | 8/8 5.0 (8) |
| 30 | Harbour Sunrise | 73 | 7 | 7 | 6 | 3 | 0.70 | 9050 | 8.6 | 1/8 0.1 (0) | 7/8 2.6 (2) | 8/8 5.0 (7) |

## Tests
- **CoreTests:**
  - L1 now has 13 glooms: 12 murks plus the opener, which surfaces at d ≈ 0.3 in under 1.5 s.
  - L4 has a brute.
  - New: only the core scorches (the band riding in a firefly's soft edge never scorches it); a firefly darts when
    first lit; fireflies fly in the gaps between gloom groups.
- **BalanceTests:** the per-world lines, plus `firefliesAreSpareable`.

## Compile risks
- `SpawnGroup.startD` and `PendingSpawn.startD` are `Double?` with default `nil`.
- `LevelRecipe.opener` has a default.
- The `DawnFirefly` fields `dart` and `wasLit` have defaults.
- `groups(for:…)` merges glooms and fireflies through `[(SpawnGroup, Int)]` and sorts it with an explicitly typed
  closure.
