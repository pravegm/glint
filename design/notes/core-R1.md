# Core R1 hand-off (Core engineer)

Unverified until CI compiles it (no Swift on this host). Balance was tuned against a line-by-line JS mirror
(`design/notes/core-R1-sim/`, `node sim.js`; env `SEEDS`, `SKILLS`, `LEVELS`, `EXTRA=1` for Long Night and daily).
Same SplitMix64, same level layout, same session rules, same pilot, so the Swift should reproduce its numbers up to
floating-point noise. If CI's GLINT-BAL lines disagree badly with the table below, the port has a bug: diff first.

## What's in `Glint/Core/`
| File | What |
|---|---|
| `Tuning.swift` | Every gameplay number (GAME-DESIGN §3–§6) + `band(angle:)`, `creaseGlow(angle:)`, `intensity(d:band:)` |
| `SeededRandom.swift` | SplitMix64 (`next`, `unit`, `range`, `int`, + `between`, `chance`) |
| `DailySeed.swift` | `day(for:)` (UTC days since 2026-01-01), `seed(day:)` |
| `GloomSpec.swift` | `GloomSpec`, `SpawnKind`, `Formation`, `SpawnGroup`, `LevelSpec` (+ `gloomCount`, `fireflyCount`, `totalHP`, `kinds`) |
| `LevelBook.swift` | 30 recipes, the layout formula, `daily(day:)`, Long Night's `endlessWave(_:rng:)` |
| `DawnSession.swift` | The rules; `DawnStats`; internal `DawnGloom` / `DawnFirefly` / `PendingSpawn` |
| `PilotBrain.swift` | The autopilot |

Tests: `GlintTests/CoreTests.swift` (≈ 50 tests: tuning maths, RNG, DailySeed, LevelBook shape and schedule, every
session rule with tiny custom scripts, modes, determinism, sub-steps, the pilot, a 30-level strong-pilot smoke run)
and `GlintTests/BalanceTests.swift` (prints `GLINT-BAL level=<n> skill=<s> won=<k>/<seeds> flowers=<avg> score=<avg>
eaten=<avg> scorched=<avg>` for 0.3/0.6/0.9, `GLINT_BAL_SEEDS` default 3, as one block between `GLINT-BAL ====` lines).
`CoreHarness` (in CoreTests.swift) has `spec`, `group`, `run`, `runDark`, `runParked`, `play` for anyone's tests.

## API additions (beyond ARCHITECTURE, all internal)
- `Tuning`: `angle(forBand:)` (inverse map, for levers/demos), `creaseGlow(band:)`, `intensity(distance:)`,
  `intensity(d:radius:band:)` (the padded body light the session uses), `multiplier(chain:)`, `lane(u:)`,
  `laneCentre(_:)`, `smoothstep`, and constants: `burnRate`, `litPadFraction`, `chainStep`, `sweepMinimum`,
  `sweepBonusPerPop`, `flowerBonus`, firefly/splitter/hopper numbers, `maxSubstep`, `endlessWaveSeconds`,
  `endlessSunSeconds`, `dailyDuration`, `startNudge`.
- `DawnSession`: `init(mode:spec:seed:)` (designated; `init(mode:seed:)` is a convenience over it),
  `convenience init(spec:seed:)` (a custom script as a level), `mode`, `spec`, `seed` (daily: the day's), `duration`
  (0 = Long Night), `wave` (Long Night's wave), `stats: DawnStats` (pops, longestChain, sweeps, bestSweep,
  flowersEaten, flowersReplanted, firefliesScorched/Delivered, hops, splits, emerged), `pendingCount`,
  `static clampBand(_:)`. Results / Game Center / achievements can read `stats` instead of counting events.
- `PilotBrain`: `input(for:dt:) -> MirrorInput` (band + matching crease glow + band speed; PilotSource can use it),
  `position`, `targetID`, the per-skill parameters (`reaction`, `speedCap`, …), `urgency(_:in:)`, `speed(of:)`.
- `LevelBook`: `all`, `recipes: [LevelRecipe]`, `levelsPerWorld`, `firstSpawn`, `endPad`, `build(_:)`,
  `levelSeed(_:)`, `dailyRecipe(_:)`, `endlessRecipe(_:)`, `endlessWave(_:rng:)`, `groups(for:rng:start:span:endPad:)`.

## Rules as built (interpretations)
- **Waiting → playing**: first non-shut input with band ≥ 0, or band moved > 0.02 from the first input. dt = 0 →
  `[]`, nothing changes. A `step` after `won`/`lost` returns `[]`.
- **Sub-steps** ≤ 1/120 s; the band is interpolated linearly from last frame's band to this frame's across them.
  `isShut` with dt > 0 = no light (the driver normally passes dt = 0 while paused).
- **Light**: `intensity` at `max(0, |d − band| − 0.4 r)`. Negative bands light too (light pooling in the crease
  catches glooms still emerging); a firefly uses r = 0.02.
- **Formations**: cluster = random u per member; line = evenly spaced `(i + 0.5)/n`; stagger(s) = one every s seconds
  stepping evenly from the range's low to high end (a ladder). u clamped 0.03…0.97.
- **Hoppers**: rest `0.9 / speedScale`, hop +0.14 in 0.22 s (smoothstep). A first touch of light (lit goes 0 → > 0)
  on a resting hopper makes it hop at once (`skittish: true`); while lit, the rest clock runs ×(1 + 2 × lit).
  `tension` = rest progress (0 while hopping).
- **Splitters**: on pop, `.split`, then 2 wisps at u ± 0.06, d + 0.07, flung at 0.30 d/s for 0.6 s (`tension` 1),
  then normal wisp speed × the splitter's speed scale. Popping one near the edge flings its wisps into the flowers.
- **Eating**: lane `Tuning.lane(u)`; if gone, the nearest standing (left first on ties). The gloom is removed; chain
  broken. **Fireflies** replant their lane if lost, else the nearest lost one (left first); else +50 (not multiplied).
- **Sweep**: a run of pops each ≤ 0.35 s after the previous. At 3: `.swept(3, 90)`; each further pop
  `.swept(n, 30)`. Broken with the chain; reset when the chain times out.
- **Sunrise** at `duration`: glooms and fireflies cleared silently, `+40 × flowers`, `.sunrise(stars, bonus)`
  (daily stars 0). Phase `won` (it can't be reached with 0 flowers).
- **Hints**: `.lightTheShadows` only in `.level(1)` (first emerge); the others once per session on the first of their
  kind (splitter wisps don't count) in every mode. The App filters by level.
- **Long Night**: wave 1 at the start, then every 30 s (`.waveUp(n)` from 2): murks 8 + 2k, flocks from wave 2,
  brutes + fireflies from 3, splitters from 4, hoppers from 5, speed 0.95 + 0.04k (≤ 1.6), crowds and pairs growing.
  `sun = min(t / 600, 1)`. The mirror predicts runs of ≈ 5.3 / 6.3 / 6.8 min for skill 0.3 / 0.6 / 0.9.
- **Today's Dawn**: `LevelBook.daily(day:)` (90 s, about level 17's mix, five fireflies), session seed always
  `DailySeed.seed(day:)` whatever `seed` is passed.

## Levels (`LevelBook.recipes`)
The layout: groups are shuffled by a seeded key (brutes lean late +0.3, hoppers +0.2, splitters +0.15, wisps and
fireflies +0.1), then placed by cumulative *cost* (murk 0.55, wisp 0.22, brute 3.0, splitter 1.3, hopper 1.3,
firefly 0.7) along a density rising 0.7× → 1.3× from 2.5 s to `duration − 8`. Speed scale rises 0.95× → 1.05× of the
row's speed through the level. The result builds smoothly instead of spiking (raw random times gave cliffs where one
unlucky pile-up lost a level for every skill).

JS-mirror predictions, 8 seeds (wins / avg flowers left), pilot skill 0.3 / 0.6 / 0.9 / 1.0:

| # | Title | s | murk | wisp | brute | split | hop | ff | speed | HP | 0.3 | 0.6 | 0.9 | 1.0 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | First Light | 60 | 12 | – | 0 | 0 | 0 | 0 | 0.80 | 7 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 2 | Dew | 60 | 18 | – | 1 | 0 | 0 | 0 | 0.85 | 13 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 3 | Ladder of Wisps | 65 | 18 | 3×4 | 0 | 0 | 0 | 0 | 0.90 | 11 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 4 | Fireflies | 65 | 20 | 3×4 | 0 | 0 | 0 | 3 | 0.92 | 12 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 5 | Big Feet | 70 | 20 | 3×5 | 2 | 0 | 0 | 3 | 0.95 | 20 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 6 | Clover | 70 | 24 | 4×5 | 2 | 0 | 0 | 4 | 0.98 | 23 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 7 | Morning Hush | 75 | 26 | 4×5 | 3 | 0 | 0 | 4 | 1.01 | 28 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 8 | Buttercups | 75 | 29 | 5×5 | 3 | 0 | 0 | 5 | 1.04 | 30 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 9 | Long Shadows | 80 | 31 | 5×6 | 4 | 0 | 0 | 5 | 1.07 | 35 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 10 | Meadow Sunrise | 85 | 35 | 6×6 | 4 | 0 | 0 | 6 | 1.10 | 38 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 11 | Chimney Pots | 75 | 32 | 4×5 | 3 | 6 | 0 | 4 | 1.10 | 36 | 8/8 4.8 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 12 | Split Ends | 75 | 32 | 4×5 | 3 | 9 | 0 | 4 | 1.12 | 39 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 13 | Slate Grey | 80 | 38 | 5×6 | 4 | 9 | 0 | 5 | 1.14 | 47 | 8/8 4.9 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 14 | Hop Along | 80 | 35 | 4×6 | 3 | 6 | 6 | 4 | 1.14 | 44 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 15 | Gutters | 80 | 41 | 5×6 | 4 | 9 | 6 | 5 | 1.16 | 57 | 8/8 4.8 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 16 | Weathervane | 85 | 48 | 6×6 | 5 | 10 | 7 | 5 | 1.18 | 66 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 17 | Pigeon Row | 85 | 50 | 7×6 | 6 | 11 | 8 | 5 | 1.20 | 73 | 8/8 3.9 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 18 | Tin Roofs | 90 | 54 | 7×7 | 7 | 13 | 9 | 6 | 1.22 | 79 | 4/8 2.3 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 19 | Skylight | 90 | 57 | 8×7 | 7 | 13 | 10 | 6 | 1.25 | 88 | 5/8 2.6 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 20 | Rooftop Dawn | 95 | 63 | 8×7 | 8 | 14 | 11 | 6 | 1.28 | 97 | 4/8 1.9 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 21 | Low Tide | 85 | 52 | 7×7 | 7 | 11 | 8 | 4 | 1.20 | 78 | 7/8 3.5 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 22 | Rope and Rigging | 85 | 54 | 8×7 | 8 | 11 | 8 | 4 | 1.22 | 88 | 6/8 3.1 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 23 | Gull Cry | 90 | 57 | 9×8 | 8 | 13 | 10 | 4 | 1.24 | 94 | 3/8 1.4 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 24 | Fog Bank | 90 | 60 | 9×8 | 9 | 13 | 10 | 4 | 1.26 | 99 | 6/8 3.3 | 8/8 5.0 | 8/8 5.0 | 8/8 5.0 |
| 25 | Lantern Row | 90 | 62 | 10×8 | 9 | 14 | 11 | 4 | 1.28 | 106 | 2/8 1.0 | 8/8 4.6 | 8/8 5.0 | 8/8 5.0 |
| 26 | Lighthouse | 95 | 62 | 10×8 | 9 | 14 | 11 | 4 | 1.30 | 104 | 0/8 0.0 | 8/8 3.9 | 8/8 5.0 | 8/8 5.0 |
| 27 | Undertow | 95 | 64 | 11×8 | 10 | 15 | 13 | 4 | 1.32 | 115 | 2/8 0.8 | 6/8 2.8 | 8/8 4.9 | 8/8 4.4 |
| 28 | Night Ferry | 95 | 67 | 11×9 | 11 | 15 | 13 | 3 | 1.34 | 123 | 0/8 0.0 | 8/8 3.8 | 8/8 5.0 | 8/8 5.0 |
| 29 | Last Watch | 95 | 70 | 12×9 | 11 | 17 | 14 | 3 | 1.36 | 128 | 1/8 0.3 | 7/8 4.4 | 8/8 5.0 | 8/8 5.0 |
| 30 | Harbour Sunrise | 95 | 68 | 12×9 | 10 | 16 | 13 | 3 | 1.38 | 120 | 0/8 0.0 | 8/8 4.8 | 8/8 5.0 | 8/8 5.0 |

(`split` / `hop` = groups of 1, or 2 with the row's `pair` chance; HP excludes splitter wisps.)

Reading it: world 1 teaches (nobody loses a flower); world 2 starts costing a weak hand at 17 and beats it half the
time from 18; world 3 beats a weak hand from 23 and costs the 0.6 hand 1–2 flowers from 25. The pilot reads exact d
positions with ±0.005…±0.11 aim error; a real Duo hand has ±5° hinge noise (±0.08 d) plus perception, so a human is
probably nearer the 0.3–0.6 rows than the table suggests. Expect device play to feel harder than this, not easier.
The difficulty is a capacity cliff (each gloom over capacity eats a flower, and a flock of 8 eats up to 5 at once),
so small recipe changes move outcomes a lot: change one row at a time and re-run the mirror.

## The pilot
Slack-based, not the brief's "highest d + remaining HP × speed": that rule chased brutes while wisp flocks walked
into the flowers. Slack = (1 − d) / speed − hp − trip time; crowds (−0.25 s per neighbour within 0.06 d, ≤ 4),
splitters (+0.25 d along, their wisps fly), and hopeless glooms (raw slack < −0.3 s) let go. Decisions every
`reaction` (0.35 → 0.08 s); slips (0.6 × (1 − skill) chance of a random target), hesitations (0.5 × (1 − skill) per
second, 0.2–0.8 s), aim error 0.005 + 0.15 × (1 − skill), switch margin 0.8 − 0.5 × skill s, firefly margin
0.097 + 0.035 × skill d (ignored once the target is past d 0.6), speed cap 0.9 → 1.6 d/s, goal lag ½ reaction.

## Assumptions
- One brute in level 2 (GAME-DESIGN §7's hint) despite §6's "brutes from 5" (NEEDS.md).
- Brute HP 3.6, hopper light-hurry rule (NEEDS.md). Every other GAME-DESIGN number is as written.
- `snapshot.creaseGlow` is the input's, clamped 0…1. `telemetry.danger` = max gloom d clamped ≥ 0.

## Compile / runtime risks (no compiler here)
- Tuples and optional chaining in tests (`sunrise?.0 == 3`), enum patterns without labels (`case .popped(_, let kind,
  _, let d, let chain, let points)`), `for … where` loops, and default closure arguments in `CoreHarness.run(shut:)`.
  All standard Swift 5, but the first CI run is the proof.
- `DawnSession.init(mode:seed:)` is a `convenience` init over the designated `init(mode:spec:seed:)`; call sites
  look exactly as ARCHITECTURE says.
- `LevelBook.all` is a lazily built `static let` (thread-safe); BalanceTests touches it before going parallel.
- BalanceTests uses `DispatchQueue.concurrentPerform` with `@unchecked Sendable` boxes (the Snapjaw pattern that
  passed CI). 270 runs × ≤ 95 s at 60 Hz: expect ~10–30 s in a Debug test build. The 30-level smoke run in
  CoreTests is another ~30 runs.
- Allocation: `step` reuses its working arrays and rebuilds `snapshot.glooms/fireflies` with
  `removeAll(keepingCapacity:)`. If the caller keeps a copy of the previous snapshot (GameController does), those
  two arrays copy-on-write once per frame; harmless, but that's the one per-frame allocation.
- Most exact-number tests (chain points 10/13/15, flock score 148, eaten lanes [2, 1], sunrise 210) were checked
  against the JS mirror. Timing-sensitive ones use tolerances.
