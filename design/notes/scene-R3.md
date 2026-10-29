# Scene R3: hand-off (Scene engineer)

Brief: ROUND-3 "Scene" + REVIEW-2 fixes 2, 3, 5 (rail), 9, 13 (mirror side), 17. Contracts R3: `GloomState.submerged` /
`surfaceD`, `GameEvent.surfaced`. Not committed (the founder pushes).

## What changed
| Fix | What |
|---|---|
| 2 Shade | The crease-shade strip now dims to 15 % (alpha 0.85, a solid strip with a short soft lip under the rim, not a long fade into the garden). The light that falls in the shade shows as a faint cool wash (`shadeLight`, 15 % of the pool + core strength, by how much of the band reaches the strip). The 0.12 rim is brighter (0.3 → 0.9 as the band touches it). |
| 1/2 Submerged | Driven by Core's `submerged`, not by d. Underground a gloom is a faint flattened ghost (body 20 %), its round eyes peeking (pupils still track the band), with a **feathered soft mound** (the shadow ellipse) under it: no box anywhere. The R2 "seam pool" (the black slabs in 08/10/21) is gone. A soft flat ripple ring trails it every ~0.3 s for its whole trip, so you can read where it's heading. On `.surfaced`: a dust puff, clods of soil thrown up, a ripple, and a springy pop up (0.32 s overshoot and lift). |
| 3 Light | No hard edge anywhere: the pool and core profiles are Core's widths (now read from `Tuning.bandCoreHalfWidth/EdgeHalfWidth`, so ±0.065/0.10 flows in) softened by a 0.03 d feather each side, and the R2 lips are gone. `LightAlphas.of(style, …)` sets the strengths per ground. Grass (meadow) and Long Night are gentle; tiles and planks keep R2's strength, which the founder liked. The 18 % cone runs from the shade's edge to the band's near edge, so it never stacks under the band. The warm trail settles in ~0.4 s. |
| 3 Test | `grassUnderTheBandIsAPoolNotASlab` samples the real lawn textures (meadow and moonlit, night and dawn), applies the night veil, and adds the layers at their real profiles and strengths. The ratio under the band must be < 1.8 × unlit and > 1.15 (the light must still show). This models SpriteKit's additive blend. It is not an offscreen render, because R1 showed SKView offscreen captures come out black on CI. |
| 5 Rail | The rail runs from d = 0 to 6 pt above the flower row's rects: no stub in the mirror, never over a flower. The grip is at d = band on the rail and parks at its ends outside it. |
| 9 Grounds | Rooftops' slate patches are warm charcoal-brown, and the gutter and ledge are warmed. The harbour planks are warm greys and browns at night. Puddles are smooth stadium-shaped wet sheens along the planks, warm grey with a bright streak, not blobs and not blue. Glints sit inside them. `roofsAndBoardwalkHaveNoBlue` checks < 2 % blue pixels. |
| 13 Sun | Behind the menus (`attract`), Long Night's attract garden is drawn as the sunlit meadow with a warm half-risen sun. The moon only shows when you actually play Long Night (`GardenScene.style(for:attract:)`). The Home title art itself is the App's. |
| 17 Fireflies | The body is 1.7 × bigger with a big lime (#C8FF6A) lantern. Separate wings flutter (size and opacity). The halo is softer, saturated lime, so they no longer read as white dots. A real 6-dot trail along the path replaces the stream of motes. |
| Misc | The ripple rings are warm-pale (cool blue is cloud shade only). The ring pool is 24 (from 10). `.surfaced` is handled in the exhaustive switch. |

Tests: 6 new (submerged / surfacing, faint light in the shade, the grass luminance ratio, no blue on roofs and boardwalk, the 6-dot trail, menus show the sun). Updated: the band profile now reads Tuning, the rail test (range, flowers, no mirror stub), and the node budget (≤ 700 total; still ≤ 300 drawn).

## Watch on CI
- The luminance ratio test is calibrated from palette maths (night meadow ≈ 1.65, moonlit ≈ 1.66, dawn ≈ 1.25). If it fails, lower `LightAlphas.of(.meadow/.moonlit)` pool/core; don't loosen the test.
- `SKTexture.cgImage()` is used in tests to read the ground textures.
- `GardenMath.bandCore/bandEdge/bandMin` are now computed from `Tuning`.
