# Core R5 hand-off (Core engineer)

Written after the founder played TestFlight build 2 on a Duo: "slow in the beginning, a lot of time doing nothing" and
"a little easy". None of this has been compiled yet, and nothing is committed.

The R4 sim matched CI's R4 world lines (`artifacts/r4/logs/build.log`) to within ±0.02 on every rate, so the JS sim in
`design/notes/core-R1-sim/` is still the tuning tool. Its outputs:
- `r5final.txt`: the per-level table.
- `r5worlds.txt`: the per-world summary lines.
- `r5dead.txt`: the longest empty-field stretch and the time to first surfacing, per level.
- `r5parked.txt`: the parked-band results.
- `r5modes.txt`: Long Night and Today's Dawn.
- `r5tune.log`: the tuning run.

## Dead time is gone
- **Every level has an opener** (`LevelRecipe.opener`, now set on every row, Today's Dawn and Long Night's first wave).
  It is one murk at t = 0 that starts `0.12 × speed` below d 0.25 and surfaces about 0.75 s after the first light.
  The sim measures the first surfacing at 0.75–0.77 s on every level (target ≤ 1 s).
- **Spawning starts and ends closer to the edges.** Spawns now begin at 0.5 s (`LevelBook.firstSpawn`, was 2.5) and
  continue until 3 s before sunrise (`endPad`, was 8).
- **Fronts are pairs that share one slot.** In R4, chains of joined groups landed on one instant and left 5–8 s holes
  after them. Now a front is at most two groups, never with a brute, and the pair takes a single slot in the load
  layout.
- **Smoother spacing.**
  - The load layout costs for brutes, splitters and hoppers are lower: 1.2 / 1.0 / 1.0, down from 3.0 / 1.3 / 1.3. A
    brute had been reserving a 5 s empty slot around itself.
  - The density curve is flatter: it now rises from 0.85× to 1.15× the level's average (was 0.7× to 1.3×).
- **Result:** the longest stretch with nothing on the field is under 2.3 s on every level with the 0.9 pilot, which
  clears the field fastest (target ≤ 2.5 s).
- **New tests:**
  - `BalanceTests.noDeadTime` fails if any run, at any skill, leaves the field empty for more than 3 s. Each level line
    now ends with `empty=`.
  - `CoreTests.everyLevelStartsAtOnce` checks the first surfacing is ≤ 1 s on all 30 levels and that L1–5 last 35–50 s.

## Shorter, steeper levels
- **Durations:** L1–5 last 35 / 38 / 42 / 45 / 50 s. L6–10 run 55–70 s, Rooftops 65–85 s, Harbour 75–95 s.
- **L1–3 are busy but gentle:** 36, 40 and 36 murks in 35–42 s, at speed 0.85. Every pilot wins them with all five
  flowers.
- **The curve moved about 3 levels earlier.**
  - L4–10 carry 2–6 brutes, and L5 already plays like the old L8.
  - Rooftops starts at the old L13–15 pressure.
  - Harbour carries the old late-Harbour mix from L21.
- **Re-tuning:** the speeds were re-fit and the counts re-rolled against the new targets (`targets.js`). The ★★★ score
  bars were refit too: none on L1–3, and from L4 the bar is the lower of the 0.6 pilot's ~60 % bar and the 0.9
  pilot's ~90 % bar (~85 % in Harbour).

## Per world (sim, 8 seeds × 10 levels)

| world | skill | winrate | flowers | ★★★ | scorched / level |
|---|---|---|---|---|---|
| 1 Meadow | 0.3 | 0.90 | 4.10 | 0.45 | 0.56 |
| 1 Meadow | 0.6 | 1.00 | 4.97 | 0.78 | 0.47 |
| 1 Meadow | 0.9 | 1.00 | 5.00 | 1.00 | 0.16 |
| 2 Rooftops | 0.3 | 0.69 | 2.27 | 0.05 | 1.32 |
| 2 Rooftops | 0.6 | 1.00 | 4.74 | 0.68 | 0.69 |
| 2 Rooftops | 0.9 | 1.00 | 5.00 | 0.99 | 0.07 |
| 3 Harbour | 0.3 | 0.05 | 0.09 | 0.00 | 0.68 |
| 3 Harbour | 0.6 | 0.90 | 3.06 | 0.16 | 0.74 |
| 3 Harbour | 0.9 | 1.00 | 4.89 | 0.86 | 0.13 |

**Against the founder's targets:**

| Target | Result | Met? |
|---|---|---|
| 0.3 wins Meadow ~90 % | 90 % | Yes |
| 0.3 loses ~1 flower from L4 | Keeps 4.0 on L4–5 and 3.1–3.8 on L6–10 | Yes |
| 0.3 wins Rooftops ~55 % | 69 % | High |
| 0.3 wins Harbour ~10 % | 5 % | A little hard |
| 0.6 wins Meadow 100 % | 100 % | Yes |
| 0.6 wins Rooftops ~95 % | 100 % | Close |
| 0.6 wins Harbour ~80 % | 90 % | High |
| 0.9 wins ~100 % with ★★★ ≥ 80 % | Wins 100 %; ★★★ 86–100 % per world | Yes |
| Strong pilot (skill 1.0) wins every level | 8/8 on every level | Yes |

Still holding from earlier rounds:
- **Parked band:** L6 loses 4–5 flowers at every depth; L11 and L21 lose all 5.
- **Fireflies:** still spareable. Per level, the 0.6 pilot burns ≤ 0.74 and the 0.9 pilot ≤ 0.16.
- **Night Watch:** 20,000 still fits. Long Night medians are 7,600 / 15,800 / 24,700 for skills 0.3 / 0.6 / 0.9.
- **Today's Dawn:** 0.3 wins 2/5 and keeps 1.2 flowers; 0.6 keeps 4.8; 0.9 keeps 5.0.

## Compile notes
- **Layout code:** `LevelBook.groups(for:…)` builds fronts through `[[Int]]` host lists and calls `rng.unit()` once per
  group after the first, exactly like the JS.
- **Tests changed for R5:**
  - `levelOneIsGentle` now checks the opener against the recipe.
  - `levelBookShape` now allows durations from 35 s.
