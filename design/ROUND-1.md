# Round 1: build the whole game (founder brief)

Everyone reads `CLAUDE.md`, `design/GAME-DESIGN.md`, `design/ARCHITECTURE.md` and `Glint/Shared/Contracts.swift`
first. Nothing compiles on our side, so write Swift as if a strict reviewer is the compiler: explicit types where
inference is shaky, no APIs you are unsure exist, every `switch` exhaustive, no force unwraps in play code.
When done, write `design/notes/<role>-R1.md`: what you built, what you assumed, anything risky for the compiler.

## Core engineer (`Glint/Core/`, `GlintTests/CoreTests.swift`, `GlintTests/BalanceTests.swift`)
1. Everything in ARCHITECTURE "Core API", exactly.
2. `DawnSession` rules per GAME-DESIGN §3–§6:
   - `waiting` until `input.band >= 0` (or `input.band` changes by > 0.02 from the first input: the drag fallback),
     then `.started`. No spawns, no clock while waiting. `isShut` inputs never start it.
   - Spawning from the level's `SpawnGroup`s (formations: cluster = random u in range at once, line = evenly spaced u
     at once, stagger(s) = one at a time every s seconds). Glooms enter at d = −radius (emerge from the crease).
   - Burn by `Tuning.intensity` at `d` padded by 0.4 × radius toward the band. Pops, chain, sweep, multiplier, splitter
     wisps, hopper rest/hop/skittish hop, fireflies (wavy u, scorch build/decay, deliver/replant), flower eating
     (lane = `min(Int(u × 5), 4)`, fallback nearest standing flower), flowers as lives, sunrise at `duration` (all
     glooms evaporate silently, stars, `+40` per flower), night wins.
   - `snapshot.sun` = time / duration (endless: `min(time / 600, 1)`), `telemetry` filled every step.
   - Endless: waves every 30 s generated from the seed with rising density/speed and the kinds unlocked so far; it never
     wins. Daily: `LevelBook.daily(day:)` + seed from `DailySeed`, scored like a level but `stars` = 0 in `.sunrise`.
   - Sub-step at ≤ 1/120 s. Deterministic for a given seed and input sequence.
   - `.hint` once each per session: `.lightTheShadows` (level 1 only, first emerge), `.followTheBigOnes`,
     `.spareTheFireflies`, `.splitters`, `.hoppers` (first of each).
3. `LevelBook`: 30 handcrafted-by-formula levels (GAME-DESIGN §6). Level 1 trivially winnable; a world-3 level should
   cost a decent player 1–2 flowers. Durations 45–95 s. Titles are short and warm ("First Light", "Dew", "Ladder of
   Wisps"…).
4. `PilotBrain`: picks the most urgent target (highest `d + remainingHP × speed`, weighted by kind), moves the band
   toward it with skill-scaled reaction delay (0.35 s at skill 0 → 0.08 s at 1) and speed cap (0.9 → 1.6 d/s),
   tracks a lit gloom until it pops, flicks across fireflies fast, sometimes hesitates at low skill.
5. Tests: tuning maths, intensity, every rule above, determinism, a 30-level smoke run with a strong pilot (all won),
   and `BalanceTests` printing `GLINT-BAL level=<n> skill=<s> won=<k>/<seeds> flowers=<avg> score=<avg>` for skills
   0.3 / 0.6 / 0.9 using `ProcessInfo.processInfo.environment["GLINT_BAL_SEEDS"]` (default 3). Balance tests only
   assert loose sanity (level 1 won by skill 0.3; level 30 lost by skill 0.3 most of the time).

## Feel engineer (`Glint/Input/`, `Glint/Feedback/`, `GlintTests/FeelTests.swift`)
1. Input per ARCHITECTURE. Copy and trim from Hush (`C:\Users\59527\Lid\Hush\Input\` — `HingeReader.swift`,
   `FeelFilters.swift` for `OneEuroSmoother`, `HingePredictor`, `FeelMath`; rename prefixes HUSH → GLINT). Mapping via
   `Tuning.band(angle:)` / `creaseGlow(angle:)` from Core. `bandSpeed` from the filtered band over ~0.1 s.
   `isShut`: filtered θ ≤ `Tuning.shutAngle` held `Tuning.shutDwell`. `DragMirrorSource`: relative drag along
   `layout.dDirection`, `Δband = Δpoints / layout.gardenDepth × 1.2`, target clamped `Tuning.bandMin…1`, the band
   eases toward the target with speed cap `Tuning.dragSpeedCap`. `hasMoved` once any drag moved it.
2. Feedback per GAME-DESIGN §9. Copy the synth/engine/haptics machinery from Hush (`Feedback/FeelSynth.swift`,
   `FeelAudioEngine.swift`, `FeelHaptics.swift`) and rebuild the sound book for Glint: sizzle layer (continuous, burn
   rate), pentatonic pop ladder (chain step = next note, C major pentatonic from C5, wrap up an octave, cap at 2
   octaves; bigger kinds lower and fuller), sweep chord, firefly fizzle / deliver bell, flower crunch + thud, band air
   (very quiet), sunrise chord + chirps, night-wins minor fall, dawn pad (brightens with `snapshot.sun`), UI cues.
   AVAudioSession `.playback` with `.mixWithOthers`; never crash without audio hardware (simulator). Core Haptics with
   a continuous sizzle player whose intensity follows burn rate; transients for pops; graceful no-op without haptics.
   `musicOn` = the dawn pad; `soundOn` = everything else.
3. Tests: mapping, filters, drag maths, shut dwell, the note ladder, events → cue mapping (pure functions).

## Scene engineer (`Glint/Scene/`, `GlintTests/SceneTests.swift`)
1. `GardenScene` per ARCHITECTURE. Draw everything inside the canvas from `GardenLayout` (convert with
   `layout.scenePoint`). It must work for all four layouts (fold vertical/horizontal × gardenAfter true/false) and any
   size; re-layout on `apply(layout:)` without losing glooms' FX.
2. Art direction (GAME-DESIGN §10), all procedural (CGContext → `SKTexture`, cached):
   - Garden: top-down dewy grass, blue-teal at night → warm gold at sunrise (`snapshot.sun`), soft noise, dew
     sparkles that glint inside the band. Dark gradient near the crease (shadows live there). Five flowers along the
     flower edge (distinct colours; eaten = a sad stalk; replanted = bloom animation).
   - Band: full-width warm stripe, soft edges matching `Tuning.intensity`, additive, slow shimmer, dust motes. Crease
     glow by `creaseGlow` when the band is still hidden.
   - Glooms: wobbly inky blobs (purple-black, rim light), big white eyes that squint when lit and blink; kind shapes:
     murk round, wisp small with a tail, brute big with heavy brows, splitter twin-lobed, hopper with ears (crouch by
     `tension`). Lit: shrink with hp/maxHP, steam particles. Pop: gold sparks + petals burst, a ring.
   - Fireflies: glowing green-gold dots with a trail; flicker red as `scorch` rises; fizzle FX; deliver = sparkle trail
     into the flower.
   - Mirror half: brass frame, dawn sky gradient, the sun rising with `snapshot.sun` (low at 0, high and bright at 1),
     drifting clouds, a lens glint, and a light shaft toward the crease. The reflection shifts a little with the band.
   - Phone fallback (`showsLever`): a brass lever on the mirror half that follows the band.
   - Events: popped (burst), swept ("Sweep!" floating text + ring), split, hopped (dust puff), firefly events, flower
     eaten (chomp + petals), sunrise (all glooms evaporate upward, golden flood), night wins (darkness rolls in),
     chain ≥ 3 shows "×n" near the pop.
   - 120 fps budget: pooled nodes, no per-frame texture creation, ≤ 300 nodes typical.
   - `attract`: softer, no floating text. `reduceMotion`: no shimmer/shake.
3. Touches → `driver?.dragBegan/Moved/Ended` with SwiftUI-space points (`layout.scenePoint` inverse).
4. Debug: a public `func renderIcon(size: CGFloat) -> UIImage?` is NOT needed (the App draws the icon).
5. Tests: layout mapping round trips for all four layouts, texture cache sizes, node pooling, event FX counts.

## App engineer (`Glint/App/`, `Glint/UI/`, `Glint/Persistence/`, `GlintTests/AppTests.swift`)
1. `GlintApp` (@main), `GameController` (GardenDriver, ObservableObject), routes Home / Levels / Play / Results /
   Settings / About, `CoverView`, `ProgressStore` (stars per level, bests, daily best, settings), `SettingsStore`
   (sound, music, haptics, swap halves, reduce motion), `GameCenterManager` (leaderboards `glint.endless`,
   `glint.daily`, `glint.stars`; optional, never gating; copy from `C:\Users\59527\Lid\Hush\App\GameCenterManager.swift`),
   `PilotSource` (MirrorSource over `PilotBrain`).
2. Hinge: `HingeReader` on the root view feeds `HingeMirrorSource`. `isDuo` = a hinge seen (persist the flag) or the
   screen looks like a Duo inner display (short/long > 0.62 and short ≥ 600). Cover display: the window's long side
   < 760 on a Duo → `CoverView` (title, "Open the phone to play" / paused score). Layout: `GardenLayout.make(size:,
   isDuo:, swapHalves:)`, rebuilt on every size change.
3. Level flow (GAME-DESIGN §7–§8): on Play, a Duo whose phone is open shows "Close the phone to start" (session not
   created until shut seen); once shut seen → session `.waiting` → "Open the phone to let the light in" until
   `.started`. Phones: "Drag down to let the light in" (direction per layout). Pause on shut (θ ≤ 15° for 0.25 s),
   inactive or pause button; resume when `canResume` with 0.6 s grace (pass dt = 0). Hints from `.hint` events, one
   line, fade after 3 s or when done. Results: stars animate, score, best, Next / Retry / Levels. Endless & daily
   results: score, best, Game Center submit.
4. UI quality bar: warm dawn palette (deep indigo → peach → gold), SF Rounded heavy for titles, big pill buttons with
   real depth, cards with illustrated headers drawn in SwiftUI (sun, mirror, flowers), the live garden (attract mode
   with `PilotSource`) behind Home. Level map: 3 world tabs, 10 sun medallions per world on a winding path, stars,
   locks with "x more ★". All overlays respect `layout`: HUD text sits on the garden half's flower edge corner;
   menus centre on the whole canvas.
5. `DemoMode` (DEBUG only, `-glintDemo "k=v;k=v"`): keys `screen` (home, levels, play, results, settings, about,
   cover, icon), `progress` (fresh, mid, done), `level`, `mode` (level, endless, daily), `t` (fast-forward the
   session with a pilot to t s at fixed 1/120 s steps, then freeze), `skill` (pilot skill, default 0.8), `band` (pin
   the band at the freeze), `fold` (1 = Duo split layout on any device), `swap` (1), `results` (won, lost),
   `hint` (a HintID). Print `GLINT-T screen <name>` when a screen appears, `GLINT-T canvas <W>x<H> fold=<0|1>` on
   layout, `GLINT-T freeze <tag>` when frozen. `screen=icon`: render `UI/AppIconArt.swift` (a SwiftUI view: deep
   dawn-blue tile, a tilted brass mirror top-left throwing a gold band diagonally, one cheeky shadow blob with white
   eyes squinting in the light) to a 1024 × 1024 opaque PNG in Documents and print `GLINT-ICON <path>`.
6. Tests: pure rules (routing, pause/resume decision, cover detection, unlocks, stars, demo parsing, progress codec).
