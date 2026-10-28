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

## Not done (not in my list)
REVIEW-1 P1-12 (Long Night moonlit, a silver band) and P1-13 (a different ground per world). Both are good R3 candidates for the Scene.

## Compile risks
- `GardenArt.LightProfile` is nested in the `@MainActor` enum `GardenArt` and used only from MainActor code.
- `GardenLightMath.pieces(shades:into:)` takes `&lightPieces`, a stored property passed inout inside a method. No overlapping access.
- `CGContext.rotate(by:)`, `.setBlendMode(.destinationIn)` are used in texture drawing only.
- The new `GloomDeath.squash` case is handled in both switches (no `default`).
