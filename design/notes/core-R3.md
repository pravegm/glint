# Core R3 hand-off (Core engineer)

None of this has been compiled yet, and nothing is committed. I updated the JS sim in place, in
`design/notes/core-R1-sim/`. `levels.json` there is exactly `LevelBook.recipes`. New tools:
- `targets.js`: the R3 targets.
- `speedfit.js`: bisects each level's speed against those targets.
- `fix.js`: now also checks the parked band.
- `starscore.js`: sets `starScore`.
- `parked.js`: the parked-band table.

Raw output is in `r3final.txt`, `r3parked.txt` and `r3modes.txt`.

## What changed
- **Submerged travel (REVIEW-2 #1):**
  - Each spawn has a `surfaceD`. It is authored per group in `SpawnGroup.surface`, a range; each member draws a depth
    from it.
  - A gloom leaves the crease submerged and moves at 1.6 × its speed (`Tuning.submergedSpeedFactor`). It is immune to
    light and its eyes still show (`GloomState.submerged`, `surfaceD`).
  - When it reaches its depth it raises `.surfaced(id:kind:u:d:)` and plays normally from there. The crease shade is
    still in place.
- **Surfacing depths, from `LevelBook.groups(for:…)`:**
  - L1–3 surface at 0.15–0.35. From L4 the range spreads to 0.15–0.60 (`Tuning.surfaceMin`, `surfaceMaxGentle`,
    `surfaceMax`).
  - A murk pack spreads ±0.05 around one depth. Lines, ladders and wisp flocks surface together at one depth, in a line.
  - Per-kind caps: brutes surface by 0.30 so they can still be tracked, splitters by 0.45, hoppers by 0.40, wisps by
    0.55. Fireflies and splitters' flung wisps never submerge.
  - A script with no surface range (`0...0`, the default) behaves as in R2. That keeps the older unit tests valid.
- **Band core ±0.065, edge ±0.10 (#12).** The brute's HP goes to 4.5 (from 3.6), because the wider band would
  otherwise let a parked band finish a brute. Hoppers no longer pop under a parked band at all; a band that rides on
  one pops it in about 2.6 s.
- **Clouds at full strength (1.0) from Rooftops.** In R2 a parked band at d 0.6–0.8 still caught every gloom on its
  way to the flowers. Full-strength clouds are what make it leak.
- **The third star (#4).** `LevelSpec.starScore` (and `LevelRecipe.starScore`) holds the score bar.
  - `DawnSession.stars(flowersLeft:score:starScore:)` returns 3 only for all 5 flowers AND a score at or above
    `starScore`; 5 flowers with a lower score gives 2.
  - The old `stars(flowersLeft:)` stays as the flowers-only rule, documented for callers that don't have the score.
  - `.sunrise` uses the new rule, with the final score including the flower bonus.
  - `starscore.js` set each bar: the 0.6 pilot clears it with 5 flowers on ~60 % of seeds, the 0.9 pilot on ~95 %
    (whichever bar is lower, rounded down to 50). Today's Dawn has none.
- **Long Night (#11).** Wave 1 (the first 30 s) is a gentle Meadow wave. From wave 2 it jumps to step k = n + 3: every
  kind, a cloud, deep surfacing. After that it escalates gently: speed +0.012 and murks +1.5 per wave, two clouds from
  wave 9, cloud strength 0.75 → 0.95, flocks capped at 6 so one cloud over one flock can't end a run on its own.
- **Pilot:** while a target is submerged it aims at the target's surfacing depth plus a lead, waiting where it will
  rise. Urgency counts the underground travel (`PilotBrain.reachD`).
- **DawnStats:** `submergedBlockedSeconds` (light-seconds the band spent on glooms still underground) and `surfaced`.

## The camping line is dead
I ran a ParkedPilot (the band held at one d for the whole level) at d = 0.15, 0.25, 0.4, 0.6 and 0.8, 3 seeds each.
Flowers lost by the band that did best:

| Level | Best parked band's flowers lost | Win rate (parked) |
|---|---|---|
| L6 | 3 (bands at 0.6 and 0.8); 5 for lower bands | 0/3 for bands ≤ 0.4 |
| L11 | 5 at every d | 0/3 |
| L21 | 5 at every d | 0/3 |

`BalanceTests.aParkedBandLoses` asserts this for the same 3 seeds and prints `GLINT-BAL parked …` lines.

## Balance
JS sim, 8 seeds. Each skill cell is wins / average flowers left; brackets show 3★ runs under the score-gated rule.
"field" is the mean number of glooms on the field (submerged ones included) from 25 % to 90 % of the level, with the
0.6 pilot.

| # | Title | murk | wisp | br | spl | hop | ff | clouds | speed | ★★★ score | field | 0.3 | 0.6 (3★) | 0.9 (3★) | 1.0 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | First Light | 12 | – | 0 | 0 | 0 | 0 | – | 0.80 | 300 | 0.7 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 (8) | 8/8 5.0 |
| 2 | Dew | 20 | – | 1 | 0 | 0 | 0 | – | 0.80 | 600 | 1.4 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 (8) | 8/8 5.0 |
| 3 | Ladder of Wisps | 24 | 3×5 | 0 | 0 | 0 | 0 | – | 0.82 | 1400 | 1.7 | 8/8 5.0 | 8/8 5.0 (7) | 8/8 5.0 (7) | 8/8 5.0 |
| 4 | Fireflies | 28 | 4×5 | 0 | 0 | 0 | 3 | – | 0.84 | 1900 | 2.5 | 8/8 5.0 | 8/8 5.0 (8) | 8/8 5.0 (8) | 8/8 5.0 |
| 5 | Big Feet | 30 | 4×5 | 2 | 0 | 0 | 3 | – | 0.86 | 2050 | 2.7 | 8/8 5.0 | 8/8 5.0 (5) | 8/8 5.0 (8) | 8/8 5.0 |
| 6 | Clover | 66 | 8×6 | 3 | 0 | 0 | 4 | – | 1.36 | 5200 | 4.8 | 8/8 4.1 | 8/8 4.9 (6) | 8/8 5.0 (8) | 8/8 5.0 |
| 7 | Morning Hush | 73 | 8×6 | 3 | 0 | 0 | 4 | – | 1.01 | 5450 | 5.8 | 8/8 4.3 | 8/8 5.0 (7) | 8/8 5.0 (8) | 8/8 5.0 |
| 8 | Buttercups | 82 | 10×6 | 4 | 0 | 0 | 5 | – | 1.17 | 7050 | 6.4 | 7/8 3.1 | 8/8 4.9 (7) | 8/8 5.0 (7) | 8/8 5.0 |
| 9 | Long Shadows | 88 | 10×6 | 6 | 0 | 0 | 5 | – | 1.23 | 7700 | 5.9 | 7/8 3.8 | 8/8 4.9 (5) | 8/8 5.0 (8) | 8/8 5.0 |
| 10 | Meadow Sunrise | 104 | 11×6 | 7 | 0 | 0 | 6 | – | 1.11 | 8450 | 7.0 | 7/8 3.6 | 8/8 5.0 (5) | 8/8 5.0 (7) | 8/8 5.0 |
| 11 | Chimney Pots | 52 | 6×6 | 3 | 2 | 0 | 4 | 3 | 0.83 | 3900 | 5.8 | 8/8 4.0 | 8/8 4.8 (5) | 8/8 5.0 (7) | 8/8 5.0 |
| 12 | Split Ends | 56 | 6×6 | 3 | 3 | 0 | 4 | 3 | 0.62 | 4400 | 7.5 | 8/8 4.0 | 8/8 5.0 (6) | 8/8 5.0 (8) | 8/8 5.0 |
| 13 | Slate Grey | 59 | 6×6 | 3 | 3 | 0 | 5 | 3 | 0.80 | 5100 | 6.4 | 7/8 3.8 | 8/8 5.0 (6) | 8/8 5.0 (7) | 8/8 5.0 |
| 14 | Hop Along | 62 | 6×6 | 3 | 2 | 2 | 4 | 3 | 0.75 | 4900 | 6.0 | 8/8 3.8 | 8/8 4.9 (7) | 8/8 5.0 (8) | 8/8 5.0 |
| 15 | Gutters | 66 | 7×6 | 3 | 3 | 2 | 5 | 3 | 0.61 | 5400 | 7.8 | 8/8 3.5 | 8/8 4.6 (5) | 8/8 5.0 (8) | 8/8 5.0 |
| 16 | Weathervane | 66 | 7×6 | 4 | 3 | 3 | 5 | 3 | 0.70 | 5450 | 6.7 | 8/8 3.5 | 8/8 5.0 (5) | 8/8 5.0 (8) | 8/8 5.0 |
| 17 | Pigeon Row | 63 | 7×6 | 4 | 4 | 3 | 5 | 3 | 0.61 | 5700 | 7.1 | 7/8 3.1 | 8/8 4.8 (4) | 8/8 5.0 (8) | 8/8 4.9 |
| 18 | Tin Roofs | 70 | 8×6 | 4 | 4 | 3 | 6 | 3 | 0.62 | 6250 | 7.6 | 7/8 3.3 | 8/8 5.0 (6) | 8/8 5.0 (8) | 8/8 5.0 |
| 19 | Skylight | 77 | 8×6 | 5 | 4 | 4 | 6 | 3 | 0.61 | 6200 | 8.7 | 8/8 3.0 | 8/8 4.5 (5) | 8/8 5.0 (8) | 8/8 5.0 |
| 20 | Rooftop Dawn | 80 | 8×6 | 5 | 5 | 4 | 6 | 3 | 0.61 | 7300 | 8.9 | 7/8 3.0 | 8/8 4.9 (6) | 8/8 5.0 (8) | 8/8 5.0 |
| 21 | Low Tide | 55 | 6×7 | 2 | 2 | 2 | 4 | 4 | 0.80 | 4550 | 6.5 | 2/8 0.3 | 8/8 4.1 (2) | 8/8 4.9 (7) | 8/8 4.9 |
| 22 | Rope and Rigging | 56 | 6×7 | 3 | 3 | 2 | 4 | 4 | 0.98 | 4550 | 4.6 | 2/8 0.6 | 8/8 3.3 (2) | 8/8 5.0 (8) | 8/8 5.0 |
| 23 | Gull Cry | 63 | 7×7 | 3 | 3 | 3 | 4 | 5 | 0.69 | 5550 | 7.5 | 5/8 1.3 | 8/8 3.4 (0) | 8/8 4.9 (7) | 8/8 5.0 |
| 24 | Fog Bank | 57 | 7×7 | 4 | 4 | 3 | 4 | 5 | 0.61 | 6100 | 8.9 | 2/8 0.4 | 8/8 3.1 (0) | 8/8 4.4 (3) | 8/8 4.6 |
| 25 | Lantern Row | 69 | 8×7 | 4 | 4 | 4 | 4 | 5 | 0.61 | 6800 | 8.8 | 5/8 1.3 | 8/8 3.4 (2) | 8/8 5.0 (8) | 8/8 5.0 |
| 26 | Lighthouse | 64 | 8×7 | 5 | 5 | 4 | 4 | 5 | 0.84 | 6700 | 5.8 | 1/8 0.3 | 8/8 3.6 (2) | 8/8 4.9 (7) | 8/8 4.9 |
| 27 | Undertow | 67 | 8×7 | 5 | 5 | 5 | 4 | 5 | 0.66 | 7150 | 7.8 | 3/8 0.6 | 8/8 3.4 (0) | 8/8 4.5 (4) | 8/8 4.1 |
| 28 | Night Ferry | 70 | 9×7 | 6 | 6 | 5 | 3 | 5 | 0.64 | 8150 | 9.3 | 1/8 0.1 | 8/8 2.8 (0) | 8/8 5.0 (8) | 8/8 5.0 |
| 29 | Last Watch | 75 | 9×7 | 6 | 6 | 6 | 3 | 5 | 0.75 | 9150 | 8.7 | 0/8 0.0 | 7/8 2.8 (1) | 8/8 5.0 (8) | 8/8 4.9 |
| 30 | Harbour Sunrise | 72 | 10×7 | 7 | 7 | 6 | 3 | 5 | 0.64 | 8450 | 9.2 | 2/8 0.9 | 7/8 3.4 (3) | 8/8 5.0 (8) | 8/8 5.0 |

**Against the R3 targets:**

| Target | Result | Met? |
|---|---|---|
| L1–3 stay gentle | 0.3 wins 8/8 with 5 flowers | Yes |
| World 1 stakes: 0.3 loses 1–2 flowers by L7–10 | Loses 0.7–1.9 at L6–10 | Yes |
| World 1 stakes: 0.3 wins L9–10 ≤ 80 % | 7/8 (87 %) | Just over |
| Field 4–10 glooms from L6 | 4.6–9.3 on every level from L6 | Yes |
| Rooftops: 0.3 wins 60–90 % | Wins 87–100 %, losing 1.0–2.0 flowers | Generous |
| Rooftops: 0.6 | Wins every level, keeps ≥ 4.5 | Yes |
| Harbour: 0.3 wins ≤ 30 % | Wins 0–62 %; L23 and L25 are 5/8 | Two misses |
| Harbour: 0.6 wins 70–100 %, losing 1–3 | Wins 87–100 %, losing 0.9–2.2 | Yes |
| Harbour: 0.9 wins everything | Wins all | Yes |
| 3★: 0.6 ~60 % of the time | ~65 % in Meadow and Rooftops; 0–40 % in Harbour, where it rarely keeps all 5 flowers | Harbour misses |
| 3★: 0.9 ~95 % of the time | Mostly 7–8/8, but 3/8 on L24 and 4/8 on L27 | Mostly |

Speeds came out slow in Rooftops and Harbour (0.61–0.98): deep surfacing and full-strength clouds supply the pressure,
and the field holds 6–9 glooms.

**Long Night:**

| Skill | Median score | Median length |
|---|---|---|
| 0.3 | 5,300 | 1.9 min |
| 0.6 | 17,800 | 3.75 min |
| 0.9 | 23,600 | 4.3 min |

So Night Watch at 20,000 still sits between the 0.6 and 0.9 medians.

**Today's Dawn**, 5 seeds: 0.3 wins 1/5 and keeps 0.2 flowers on average, 0.6 keeps 3.4, 0.9 keeps 5.0.

## Tests
- **CoreTests, existing tests updated:**
  - The band profile for the new edge: 0.0825 is now the smoothstep midpoint, and the zero point moved to 0.10.
  - Tuning constants (core 0.065, edge 0.10, submerged factor 1.6).
  - Hoppers: riding beats parking, which now never pops one.
  - Long Night's cloud schedule.
- **CoreTests, new tests:**
  - Submerged travel: under a parked band, never lit, surfaces at 3.3 s, then gets eaten. A deeper band pops it.
  - Only scripted glooms submerge: flung wisps and fireflies never do.
  - Authored depths stay within their ranges: L1–3 ≤ 0.35, brutes ≤ 0.30, wisp flocks at one depth, some deep groups,
    and every level has a `starScore`.
  - The score-gated third star (the `stars(…)` mapping, and a sunrise below the score gives 2).
  - Long Night's jump after wave 1.
  - The pilot waits where a gloom will surface.
- **BalanceTests:**
  - `aParkedBandLoses` for L6, L11 and L21.
  - The `three=` column now counts score-gated 3★.

## Compile risks
- `SpawnGroup.surface`, `LevelSpec.starScore`, `LevelRecipe.surfaceMin/surfaceMax/starScore` and
  `PendingSpawn.surfaceD` are all defaulted stored properties, so existing memberwise call sites still compile.
- `GloomState(…, submerged:, surfaceD:)` uses the founder's new Contracts init.
- The `.surfaced` event is new. Core only emits it and never switches over `GameEvent` exhaustively.
- `ParkedPilot.run` returns a tuple `(Int, Bool)`.
