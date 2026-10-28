# Feel engineer, Round 1: Input + Feedback

Unverified: nothing here has been compiled (no CI yet). Written to compile first time: Swift 5 mode, iOS 18 target,
hinge API behind `#available(iOS 27.1, *)`, every `switch` exhaustive, no force unwraps.

## What I built

### Input (`Glint/Input/`)
| File | What |
|---|---|
| `HingeReader.swift` | Copied from Hush as is (scene-activation and `refreshToken` re-subscribe). `FeelHingeLog` prints `GLINT-H <t> <angle>` at ≤ 10 Hz, DEBUG + `-glintDemo` only. |
| `FeelFilters.swift` | `FeelMath`, `OneEuroSmoother`, `HingePredictor` and `FeelHingeTrace` (from Hush, unchanged). New: `FeelVelocityWindow` (band speed over the last 0.1 s of frames, restarts after a 0.25 s gap), `FeelShutGate` (θ ≤ `Tuning.shutAngle` held `Tuning.shutDwell`, unlatches above shutAngle + 3°, adapted from Hush's closing gate). `FeelDemoLog` (`-glintDemo`, `line(_:)` / `emit(_:)`). Hush's lid speedometer and snap logic were dropped: Glint needs the angle, not a speed. |
| `HingeMirrorSource.swift` | Hush's `HingeLidSource` pattern: predictor at display rate → One-Euro (2.0, 0.12, 1.5) → `Tuning.band(angle:)` / `creaseGlow(angle:)`. Before any report: band `Tuning.bandMin`, not shut. `isShut` matures on the clock with no frames or reports (the Duo is silent while still). `canResume` = filtered θ ≥ `Tuning.resumeAngle`. `ingest` keeps `angle` and the gate fresh while no frames run (pause, cover display). `clock` is injectable for tests. |
| `DragMirrorSource.swift` | Relative drag along `layout.dDirection`, `Δband = Δpoints / gardenDepth × 1.2`, target clamped `bandMin…1` each step (pushing past an end and back moves at once). The band chases the target at `cap · tanh(err / (cap · 0.06))`, cap `Tuning.dragSpeedCap`: small moves follow in ~60 ms, flicks are capped. `creaseGlow` = 0 at `bandMin` → 1 at d = 0 (see assumptions). |

### Feedback (`Glint/Feedback/`)
| File | What |
|---|---|
| `FeelSynth.swift` | Hush's real-time synth machinery (lock-free SPSC queue on `Synchronization.Atomic`, voice pool, modal ring bank, DC blocker → limiter (0.9) → tanh). Pool 96 → 160 voices, queue 512 → 1024 (a ten-pop sweep). New continuous layers: **sizzle** (band-passed hiss whose centre climbs 1.5 → 5 kHz as HP falls, fluttering 4–16 ms; fry above 6 kHz; random resonant crackles), **kettle** whistle (only when nearly popped), firefly **alarm** whimper (8 Hz tremolo), band **air**, **dawn pad** (C3 G3 C4 E4 A4 D5, 12 PolyBLEP saws, 24 dB low-pass opening with the sun, upper voices entering at sunrise) with pentatonic glass **twinkles**. |
| `FeelAudioEngine.swift` | Hush's, trimmed: `.playback` + `.mixWithOthers` always, interruption / route / media-reset healing, naps when idle. Every failure is logged, never thrown. |
| `FeelHaptics.swift` | Hush's Core Haptics engine with two looping players: the **sizzle texture** (intensity 0.12 + 0.5 × sizzle, sharpness 0.35 → 0.75 with heat, ±30 % jitter per 30 Hz send = crackle) and the **alarm flutter**. Normal / Strong profiles (Strong layers a 40 ms burst under every tap). Falls back to `UIImpactFeedbackGenerator`, or nothing on the simulator. `FeelHapticBook`: pops (tap by size, brute adds a thump), sweep roll, fizzle, delivered, flower eaten (the heaviest), dawn, sunrise ripple, night wins, wave, UI. |
| `FeelSoundBook.swift` | Every recipe as pure data, plus the bed (`playBed`, `menuBed`). See "The sound set". |
| `FeelCues.swift` | `FeelCue` + `FeelCueMap` (GameEvent → cue, pure, tested), `FeelPopSequencer` (spaces pops 45 ms apart into a rising run, drops any that would wait > 0.4 s, trims the 4th+ pop's level and sparkles), `FeelThrottle`. |
| `FeedbackDirector.swift` | The ARCHITECTURE API + `UICue`. Pops of one frame play as one staggered run, sound and haptic in step; the sweep stab lands with the run's last pop; losses delay the "chain lost" glint. Idle / nap / watchdog logic from Hush. |

## The sound set (GAME-DESIGN §9)
- **Pop**: a Minnaert bubble chirping up (wisp ~800 Hz … brute ~380 Hz), a puff of air, a **pluck on the ladder** with a
  chime an octave up, a warm body an octave (brute: two) under for murk and up, a sparkle tail of 2–5 glass glints from
  the pentatonic above. Brute: pluck an octave down plus a whumpf, a fifth and a landing thud.
- **Ladder**: C major pentatonic from C5; chain n = rung n (C5 D5 E5 G5 A5 C6 … C7), capped at C7 (2 octaves).
- **Sweep**: strummed C6/9 chimes (C5 E5 G5 A5 D6) over a C–G stab, a whoosh, two glints; each further pop of the
  sweep adds one rung (C6 → C7).
- **Fizzle**: a sad 1.3 kHz → 440 Hz blip with a fizz. **Delivered**: a G6 bell; a replant adds a C6–E6–G6–C7 bloom.
- **Flower eaten**: crunch (falling noise + three snaps), knock, low thud, a sad falling note.
- **Dawn** (`.started`), **sunrise** (a soft ripple of evaporating pops, a slow C major chord C4…G5 with chimes, a C3
  swell, a bell, birdsong phrases 3 + stars), **night wins** (A minor falling, a drone, a low bell), **wave up** (bells).
- **UI**: marimba taps (tap / back / toggle), star bells G5 → C6 → E6 (the third adds a shower), unlock arpeggio, a
  dawn swell for level start.
- `soundOn` gates everything except the pad; `musicOn` gates the pad. Both off: master 0, engine paused.

Node probe (`partial port, pre-limiter RMS at the 1.8 master`): a pop's first 80 ms −15 dBFS (peaks −5.4); sizzle −30
(one gloom lit) … −24.5 (full burn, nearly popped); pad −35 (night) … −29 (sunrise); air −40 at most. So the pop sits
~10–15 dB over the sizzle and ~15–20 over the pad. Not measured on a phone speaker; nobody has heard it yet.

## Assumptions
- `MirrorInput.isShut` is the dwell-gated shut (same as `isShut`), not the instant θ ≤ 15°.
- Drag fallback `creaseGlow` is 0 at `bandMin` (dark, like a shut phone) rising to 1 at d = 0, my own mapping. Core's
  `Tuning.creaseGlow(band:)` gives 0.8 at `bandMin` (θ = 67°); I kept mine so "drag down to let the light in" starts
  dark. Easy to swap if the Scene wants them identical.
- `setBand` keeps `hasMoved` (per ARCHITECTURE); added `reset(band:)` which also clears it.
- `frame(snapshot:dt:)` with `dt = 0` (held) or `setPaused(true)`: no sizzle / alarm / air; the pad stays (half when
  paused). Phase `.won` keeps the pad at full brightness; `.lost` darkens it.
- Endless (`sun` = night depth): the pad is dim (0.3) and darkens with depth.
- The sunrise ripple counts the glooms on the frame before `.sunrise` (Core evaporates them silently).
- Hint and quiet `chainEnded` events make no sound; `chainBroken(was:)` sounds only for `was ≥ 3`.

## Extra public API for the App (all additive)
- `FeedbackDirector.shared.deviceHasFold = true` when a hinge is seen → Strong haptics (also in NEEDS.md).
- `FeedbackDirector.shared.hapticProfile` (Normal / Strong), `idle` (menus), `silence()` (leaving play),
  `ambience(sun:)` (menu pad), `paused`, `popsPlayed` / `popsDropped` (diagnostics).
- `HingeMirrorSource`: `shut(at:)`, `lastRawAngle`, `lastSampleTime`, `lastMirror`, `reportCount`, `clock`,
  static `band(angle:)` / `glow(angle:)`.
- `DragMirrorSource`: `reset(band:)`, `band`, `target`, `isDragging`, `lastMirror`, static `bandDelta`, `ease`,
  `creaseGlow(band:)`.

## Compile risks (look here first if CI fails)
1. `nonisolated static let` on the `@MainActor` classes' constants (`DragMirrorSource.dragGain` etc.), used from
   `nonisolated static func`s. If rejected, drop `nonisolated` and inline the literals in those functions.
2. `import Synchronization` / `Atomic<Int>` (iOS 18) and `nonisolated(unsafe) static var` (FeelHingeLog): as in Hush.
3. `.onHingeChange(isEnabled:)` / `newContext.hinge?.angle.degrees`: copied verbatim from Hush.
4. Default values of `@MainActor` stored properties that call `@MainActor` inits (`FeedbackDirector.audio =
   FeelAudioEngine()`): the same as Hush.
5. Tuple-array parameter `FeelHapticBook.pops(_: [(kind:chain:delay:)])` built from a literal in the tests.
6. Tests compare against `Tuning` values (`creaseAngle`, `edgeAngle`, `resumeAngle`, `shutAngle`, `shutDwell`,
   `bandMin`, `dragSpeedCap`) and assume `Tuning.band(angle:)` is monotonic and roughly 1 d/s for a 65°/s sweep.
7. `theBandNeverStepsBetweenReports` asserts a per-frame band step < 0.025 for a 65°/s sweep at 30 Hz reports: the
   tightest numeric test; loosen it before touching the filters if it flakes.
