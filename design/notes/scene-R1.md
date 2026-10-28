# Scene R1: hand-off (Scene engineer)

## What I built (`Glint/Scene/`, 8 files, ~3,400 lines)
| File | What |
|---|---|
| `GardenScene.swift` | `GardenDriver` (exact ARCHITECTURE signature), `GardenFrame` (floor ↔ scene transform from `GardenLayout`), `GardenScene` (`init(layout:)`, `driver`, `apply(layout:)`, `showsLever`, `attract`, `reduceMotion`, plus `reset()`, `render(_:events:dt:)` for tests, read-outs, `flowerRects(layout:count:)` for the App's HUD) |
| `GardenArt.swift` | `GardenInk` (colour), `GardenPalette`, `GardenRNG` (cosmetic xorshift), `GardenMath` (band profile copy, world/dawn mapping, flower geometry), `GardenPainter` (CG helpers), `GardenArt` (the texture cache + soft shapes, the band, crease, lawn) |
| `CreatureArt.swift` | `GloomLook` (per-kind feature layout), gloom layers (body, lit rim, eyes, pupils, "> <" squeeze, grin, "ouch", brute brows), firefly, 5 flowers (petals, leaves, eaten stalk) |
| `MirrorArt.swift` | sky gradients (night / dawn / day), sun disc, 3 clouds, tileable horizons per world (meadow hills + windmill, rooftops + chimneys, harbour + lighthouse + boats), brass moulding + corner boss, glass sheen, light shaft, lever slot and knob |
| `GardenMirror.swift` | the mirror node: cropped glass, reflected sky (shifts with the band), sun rising with the level, rays, glint, lens flares, shaft to the crease, drifting tinted clouds, twinkling stars, lighthouse lamp, shine sweep, night veil, frame, lever |
| `GloomNode.swift` | `GloomNode` (pooled puppet + contact shadow; blink, breathe, squint → squeeze, mouth, hp shrink, emerge pop-in, hopper crouch + hop arc, wisp fling stretch, lit shiver; deaths: evaporate / dive into flower / fade), `GardenFirefly`, `GardenFlower` |
| `FXPool.swift` | `GardenFXPool` (fixed sprite pools), `GardenRingPool`, `GardenLabels` (floating words), `GardenFX` (pop, steam, ember, ink, dust, fizzle, trail, twinkle, motes, petals, confetti, evaporate) |

Tests: `GlintTests/SceneTests.swift` (21 tests): the frame transform and the garden node in all four layouts, SwiftUI
round trips, flower rects, the band profile, world/dawn mapping, gloom looks, **a warm frame loop builds zero
textures** (every event, 120 frames, sunrise), gloom and firefly pooling, pop/sweep/chain words (none in attract),
squeeze in light, sunrise evaporation + flood, night roll, eaten flower + shake (none with Reduce Motion), replant,
new-session reset, the lever, the sun rising in every layout, live re-layout through all four, the driver loop, the
node budget (≤ 300 drawn in a busy frame).

## The look
- **Lawn** (seen from above): a big per-size texture (cached; night and dawn painted from one seed so they crossfade
  exactly): dark ink at the crease warming to teal, soft mowing stripes, blotches, clover, ~1,800 grass tufts, tiny
  wildflowers, ~500 dew drops, ink stains reaching out of the crease, and a soil flower bed with pebbles along the
  flower edge. Night = deep blue-teal; dawn = golden green; `snapshot.sun` crossfades. A night veil lifts as the phone
  opens. Breathing ink tendrils sit along the crease.
- **Band**: Core's exact profile (1 within ±0.05, smoothstep to 0 at ±0.085) as a warm amber alpha wash + an
  additive cream-gold core with faint crisp lips at ±core (the burn zone reads), a faint wide bloom, shimmering
  light streaks, drifting dust motes, 22 dew glints that sparkle only where the band crosses them. In the crease
  phase a gold glow pools at the seam (`creaseGlow`) and fades as the band lifts out.
- **Glooms**: inky purple-black mochi blobs with a faint violet aura (readable on the dark lawn), a lilac rim light,
  a teal bounce, gloss and starry specks; big white eyes with highlights that look towards the flowers and blink;
  a cheeky one-fang grin. Lit: a gold rim (hotter/whiter as HP falls), they wince, squint, then squeeze "> <" with
  an "ouch" mouth, shiver, shrink with HP and steam and crackle embers. Murk round; wisp a small flame with a tail;
  brute big and lumpy with heavy brows and tusks; splitter twin lobes with four eyes and two mouths; hopper with
  long ears, crouching by `tension`, arcing on hops. Pop: flash, shock ring, gold sparks, flower petals, ink flecks.
- **Fireflies**: a top-down bug (wings flutter, heading follows its path) with a glowing tail, pulsing halo and a
  glow trail; it flickers and goes red as it scorches; fizzle = red sparks + smoke; delivered = a sparkle stream
  into the flower, a ring, petals (and "+50" when nothing to replant).
- **Flowers**: rose, marigold, violet pansy, sky-blue star, peach daisy; leaves rosette; half-closed at night,
  opening with the dawn; they glow when the band reaches the edge and tremble when a gloom is closing in. Eaten:
  a chomp shrink, petals burst, a wilted stalk with fallen petals; replanted: a spinning bloom with overshoot.
- **Mirror**: brass moulding with citrine corner bosses around a cropped glass; three sky gradients (night indigo,
  rose-peach dawn, blue day) crossfaded by the level's progress; the sun rises from half-hidden on the horizon to
  high and white, with rays, a glint and two lens flares; a shaft of light falls from the sun to the crease; clouds
  drift (tinted by the hour); stars fade; the world's horizon (meadow / rooftops / harbour); the reflection shifts a
  few points with the band. Night wins dims it.
- **Moments**: "Sweep!" (re-worded "Sweep ×4!" as it grows) + a big ring; "×n" for chains ≥ 3; "!" on skittish hops;
  "Wave n"; sunrise = every gloom steams away upwards, a warm flood with turning rays, petal and glitter confetti;
  night wins = darkness rolls out of the crease over the garden; an eaten flower shakes the canvas.
- `attract`: 60 % particles, no words, no shake. `reduceMotion`: half the particles, no shake, no shimmer, no ray
  drift or shine sweep, gentler idle motion.

## Assumptions
- Band constants are copied (`GardenMath.bandCore/bandEdge/bandMin` = 0.05 / 0.085 / −0.2, checked against
  `Core/Tuning.swift`), so the Scene compiles without depending on Core names.
- World per mode: levels 1–10/11–20/21–30 → 1/2/3; Long Night → harbour; Today's Dawn → meadow. Long Night's `sun`
  is the night's depth, so its art dawn = 0.3 × (1 − sun) (a low sun sinking).
- A new session is detected when the mode changes, the clock runs back > 0.25 s, or a finished phase returns to
  waiting/playing; it clears FX silently. `reset()` forces it.
- Glooms that vanish without `.popped`: evaporate on `.sunrise`/won, dive into the flower on `.flowerEaten` (if their
  last d > 0.75), else fade. Fireflies vanish instantly on scorched/delivered, else fade.
- Cosmetic animation runs on wall-clock dt even while the session is paused (the garden breathes behind the pause
  card).
- The HUD/flower corner conflict is answered in `design/NEEDS.md` (Scene → App).

## Performance
Pools: 12 gloom nodes + 3 fireflies pre-made (grown only if more are alive at once; released nodes leave the tree),
84 additive + 64 alpha particles, 10 rings, 8 labels. Every texture is built in `init` (`warmGlooms`,
`warmFlowers`, `MirrorArt.warm`); only a new canvas size builds two lawn textures (≤ 1800 px; the last two sizes per
orientation are kept). A busy frame (12 glooms, 3 fireflies, a pop) draws ~240 nodes (~430 exist, the rest hidden
pool sprites). No `SKShapeNode`, no `SKEffectNode`, one `SKCropNode` (the glass).

## Compile risks (no compiler here)
- `GardenScene.init` assigns `mirror`/`fx`/`labels` before `super.init`; nodes are inline `SKNode()` /
  `SKSpriteNode()` defaults with textures set in `init`/`setUp` (Hush's pattern). Helper classes are `@MainActor
  final class` with inline node defaults.
- `GardenArt.make` captures its non-escaping `draw` inside `UIGraphicsImageRenderer.image { }` (as Hush does).
- `nonisolated static func flowerRects` on the `@MainActor` scene uses only nonisolated types.
- Patterns on `GameEvent` omit labels (`case .popped(let id, let kind, let u, let d, let chain, _)`); the switch is
  exhaustive with no `default`.
- `CGMutablePath.addPath(_:transform:)`, `addEllipse(in:transform:)`, `CGContext.setShadow(offset:blur:color:)`,
  `.setBlendMode(.destinationIn / .clear)` are used in texture drawing only.
- Swift Testing: `Issue.record("…")` in one test; all tests in a `@MainActor struct`.
- Visual risk (not compile): SpriteKit's node transform is assumed to be translate · rotate · scale (the garden node
  uses `yScale = −1` for two layouts); `gardenNodeConvertsFloorPointsInEveryLayout` will catch it on CI.
