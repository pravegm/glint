# Scene R2: hand-off (Scene engineer)

Brief: ROUND-2 "Scene engineer" plus the R2 addendum (REVIEW-1). Nothing committed. The founder pushes.

## What changed
| Area | What |
|---|---|
| **Light = reflected sunlight** (REVIEW-1 P0-2) | New `GardenLight.swift`. The R1 slab (alpha wash + core + rays) is gone. Five **additive** layers, the grass visible through them: pool #FFC24A (Core's exact profile), core #FFF4D6 with faint lips at ±core, a wide halo, a **beam** from the crease to the band that brightens towards the band (the light's path stays faintly warm), and a **warm trail** that lags behind the band and fades as it catches up. All of it fades over the outer 6 % of the width. A sweep swells it briefly (`bandSwell`). The mirror's sun shaft and a new **hot spot** on the glass at its crease edge tie it to the mirror. |
| **Cloud shades** (addendum, `snapshot.shades`) | `GardenLightMath` (pure) cuts the light into pieces along u wherever it bends (outer fades, each shade's soft 0.03 edge). Each layer draws a flat + ramp sprite pair per piece, so inside a shade the light is exactly × (1 − strength); tested against the formula at 201 points. A cool blue tint lies over the light's path in each gap. The mirror draws a cloud for each shade at its u, on the sun's path, moving as the shade drifts. |
| **Crease shade** | A dark soft strip over d < `Tuning.creaseShade`, drawn over the light so the band is dim there, with a cool rim at the shade's edge that brightens where the band touches it. Glooms with d < shade are **sunk**: a dark seam with a wavy, cool-rimmed surface covers their lower half, their eyes peek and blink more often, and their contact shadow goes. Coming out of the shade gives a flat cool ripple (2 squashed rings + ink drops); `.emerged` ripples at the crease too. No dew glints or motes in the shade or in cloud gaps. |
| **Sun glint** | The big white 4-point star is replaced by a small soft cross flare (`MirrorArt.crossFlare`, ≈ 1 sun radius, alpha ≤ 0.54, slow twinkle). The lens-flare ring is toned down to 6 %. |
| **Juice** | Pops: a 0.11 s white flash, a warm glow, a brighter ring, 10–16 sparks (more with the chain), 3–5 petals. "×n" springs in (to about 1.4×, settles) and grows a little per step. A sweep swells the light. A brute pop holds a white flattened squash for about 0.05 s over its burst (hit-stop) plus a small shake. A firefly gets a red-orange warning ring the moment it starts to scorch. |
| **Glooms** | 15 % bigger when `gardenFraction > 0.54` (phones; `GardenMath.gloomArtScale`). Eyes look towards the band (+d when the band is further out, towards the crease when it's behind them). |
| **Fireflies / lawn** | Lime #C8FF6A. The lawn's white wildflowers and bright dew dots are removed (they read as fireflies); dew is a faint sheen in the grass's own colour. |
| **Lever = band** (REVIEW-1 P0-4) | The mirror slot is retired. On phones, a brass rail runs along d at u = 1 − 30 pt, from d = bandMin (inside the mirror) to the flower edge. A gold **grip pill** (44 × 20) sits on the band's edge at d = band exactly and pulses until the band first moves. Hidden in attract mode. |
| **API** | `nonisolated static func hudSafeRects(layout:) -> [CGRect]` (= `flowerRects`). I made it static only: an instance overload of the same name would make the call ambiguous. Read-outs for tests: `gloomSubmerged/gloomRadius/gloomLook(id:)`, `lightSpriteCount`, `mirrorShadeClouds`, `shadeRimCenter`, `sunGlintSize`, `sunRadius`, `mirrorHotSpot`, `bandSwell`, `gripPulsing`, `chainTextPeakScale`. |

Tests (SceneTests): 9 new, plus a rewritten lever test (the grip's floor d equals the band at five values; it pulses and hides in attract mode). New: light math vs pieces, shades in the scene (clouds and cut sprites), the rim position in all four layouts, sink and surface ripple, phone scale and band-tracking eyes, juice (brute squash, swell, chain bounce), small glint and hot spot, hudSafeRects. The node budget allows ≤ 640 nodes in total (150 hidden light-piece sprites) and still ≤ 300 drawn.

## Dependencies on Core (in flight in parallel)
- `Tuning.creaseShade: Double` and `Tuning.isShaded(d: Double) -> Bool`, as the brief names them. They are used only through `GardenMath.creaseShade` / `GardenMath.isShaded(d:)`, so a rename is a one-line fix in GardenArt.swift.
- `ShadeState` / `snapshot.shades` from Contracts (already there).

## R2b: a ground per world, Long Night, Today's Dawn (REVIEW-1 P1-12/13)
- `GroundStyle.of(mode)`: levels go through `LevelBook.world(of:)` (1 Meadow, 2 Rooftops, 3 Harbour); Long Night →
  `.moonlit`; Today's Dawn → Meadow. `GardenMath.world(for:)` now uses `LevelBook.world(of:)` too, and Long Night's
  mirror horizon is the meadow.
- **Rooftops** (`GroundWorlds.drawRooftops`): staggered terracotta tiles with slate patches, overlap shadows and lit
  lips, moss (thicker near the crease), 2–3 chimney stacks with pots near the side edges (out of the main play), a
  metal gutter with brackets, then a stone ledge as the flower edge with a wooden **window box** under each flower.
- **Harbour** (`GroundWorlds.drawHarbour`): weathered boardwalk planks along u with staggered joints, grain and
  nails, salt/damp patches, 6–9 **puddles** (`GardenMath.puddles`, seeded; they keep clear of the shade and the flower
  row), a rope coil, a dock beam with rope at the edge, terracotta **pots** under the flowers. The band's 22 glints sit
  on the puddles here.
- Every ground keeps the crease's ink and darkening (the shade strip, the rim and the glooms read the same), the flower
  row and the light. Night and dawn versions share one seed and crossfade with `sun` as before.
- **Long Night**: the moonlit meadow (deep blue; silvered as the "dawn" layer). The mirror shows a big cratered moon
  that climbs with the night's depth (`GardenMath.nightDepth`), a cool halo, faint rays, no flares, the night sky and
  stars. The light is silver-gold moonlight (pool #F2DDA0, core #F6F2E6), still warm enough to read.
- **Today's Dawn**: the meadow at golden hour (art dawn 0.55 → 1). I left out the date flag (the App can show a date
  chip).
- Caching: ground textures are keyed by style and size and built on the first use of each world (at session start,
  when the mode changes), never per frame. The last 8 keys are kept. The moon disc is built up front.
- Tests: mode → ground for all 30 levels plus both modes, the scene switching grounds (and the moon) and reusing them
  with zero builds, harbour glints on puddles, golden hour and night depth. The R1 endless-world expectation is now 1.

## Compile risks
- `GardenArt.LightProfile` is nested in the `@MainActor` enum `GardenArt` and used only from MainActor code.
- `GardenLightMath.pieces(shades:into:)` takes `&lightPieces`, a stored property passed inout inside a method. No overlapping access.
- `CGContext.rotate(by:)`, `.setBlendMode(.destinationIn)` are used in texture drawing only.
- The new `GloomDeath.squash` case is handled in both switches (no `default`).
