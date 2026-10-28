# Feel engineer, Round 2

Not compiled yet (R1 compiled and passed on CI 40782324566; R2 is unverified until the next run). Not committed.

## 1. Tuning changes (edge 145 → 135, drag cap 2.4 → 1.4)
No Feel code holds those numbers: the mapping is `Tuning.band(angle:)` and the drag ease reads `Tuning.dragSpeedCap`.
Every FeelTest reads Tuning (`creaseAngle`, `edgeAngle`, `dragSpeedCap`, …), not literals. Checked against both the
old and the new values: sweeps go crease → edge in 1 s (1 d/s either way), and the drag tests run long enough for a
1.4 d/s cap (a full 1.2 d sweep takes 0.86 s).

## 2. Cloud shadows
- `FeelSoundBook.shadeCover(u:shades:)` mirrors the contract (light × Π(1 − strength·edge), 0.03 soft edge).
  `shadedBurn` is each gloom's *unshaded* light (`Tuning.intensity(d:band:)`, padded 40 % of the radius as Core does)
  × its cover. `burn(of:)` counts it in the sizzle level (up to 40 % quieter) and sets `FeelBurn.muffle` =
  shaded / (real + shaded).
- Synth: `FeelBed.sizzleMuffle` drives a 24 dB low-pass on the sizzle, from 14 kHz (open) to 600 Hz (log sweep). It
  is always in the path, so it never clicks in. The kettle is scaled by (1 − muffle). Haptics: the texture goes
  softer (× 0.65) and rounder (sharpness down by up to 0.25). A test confirms a fully muffled sizzle renders at
  < 0.6 × the open RMS.
- **Cool hush**: `FeelShadeWatcher` fires once per shade id when any of it first reaches u 0…1 (the band is full
  width) with strength ≥ 0.15, only on live playing frames. It allows at most one per 0.6 s and forgets the ids when a
  session restarts. Sound: a soft cool exhale falling 2.6 kHz → 700 Hz, a low breath, an open fifth of faint glass
  (A5, E6). Haptic: a faint, slow, dull swell.
- No new public API. The director reads `snapshot.shades` itself.

## 3. Hinge precision
REVIEW-1's worry was right. A Node port of R1's pipeline, with a still hand of ±1.5° uniform noise at 25–30 Hz, gave
**0.037 d of band jitter** (≈ 2°, three-quarters of the core's half-width). The predictor's velocity estimate amplified
the report noise. R2 pipeline:
1. **Steady filter per report** (`HingeMirrorSource.steadyFilter()`): a One-Euro at 0.2 Hz, β 0.15, dCutoff 3 Hz,
   with two new optional terms on `OneEuroSmoother`:
   - a **25°/s speed floor**, so noise-driven derivative doesn't open the cutoff;
   - a **residual boost** of +10 Hz per degree beyond 2°, so a real move is caught at once.
2. The predictor gets the steadied reports but **rests on the raw last report**: `sample(_:at:rest:)`. Without that, a
   hand that stops (the Duo then sends nothing) left the light 0.67° short.
3. The display One-Euro is lighter: 6 Hz, β 0.5 (R1: 2 Hz, 0.12).

Node port results (random 25–30 Hz reports). The 60°/s rows use a clean signal; the noisy runs came out within a few
ms.

| | R1 | R2 |
|---|---|---|
| Still ±1.5°: worst band jitter (8 seeds) | 0.037 d | **0.0056 d** |
| 60°/s move: steady lag | 9 ms | **12 ms** |
| Abrupt 60°/s start: lag under 60 ms after | 100 ms | 100 ms |
| Human-like move (0.15 s accel): worst error | 3.3° | 3.9° |
| Human-like stop: overshoot | 3.2° | **2.4°** |
| Per-frame step at 1 d/s | 0.0135 d | 0.0137 d |

The worst-error row is the price of the change: the light trails ~0.6° more while a move speeds up. Under ±1.5°
noise, a real move under ~2° can't be told from noise without waiting, so the first ~100 ms of a gentle move is
within ~2° (0.035 d) of the hand rather than exact. That is inside the ±0.05 d core.

New tests (fixed 27 Hz, FeelDice noise; the Node port of these exact harnesses gives the numbers in brackets):
- `aNoisyStillHandBarelyMovesTheBand`: jitter < 0.01 d, offset < 0.02 d over 3 seeds [0.003 / 0.004].
- `aSixtyDegreeMoveFollowsWithinSixtyMilliseconds`, from 85° to 130°:
  - clean: mean and max lag < 60 ms [12 / 13 ms], and it rests at 130° ± 0.3;
  - noisy: mean lag < 60 ms [9 ms].
- `theSteadyFilterIgnoresNoiseButFollowsAMove`: the steady filter's worst noise is under half of plain One-Euro's
  [0.2–0.27 ×], and a 10° step is followed within 0.5° in 3 reports [119.9].
- Shade tests: `shadeCoverFollowsTheContract`, `aShadedBurnIsMuffledNotCut`, `theMuffleDarkensTheSizzle` and
  `aCloudHushesOnceAsItReachesTheBand`.

**Not measured on a real Duo.** The ±1.5° trace is the brief's model. If real tremor is smaller, the residual boost
(2°) and the speed floor (25°/s) can come down for snappier onsets.

## Compile risks
- `OneEuroSmoother.init` gained three defaulted parameters; all old call sites still compile.
- `HingePredictor.sample(_:at:rest:)` has a defaulted `rest`.
- `HingeMirrorSource.steadyFilter()` and `displaySmoother()` are `nonisolated static func`s. They duplicate the stored
  properties' literal defaults on purpose (isolated default values); keep the two in step.
- `DawnSnapshot(… shades: …, band: …)` in the tests relies on the founder's R2 Contracts init order.
- `FeelShadeWatcher.update` has a defaulted `live` parameter.
