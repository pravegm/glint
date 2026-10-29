# Scene R3b + R4: hand-off (Scene engineer)

Not committed (the founder pushes).

## R3b: grass light (founder, after the R3 frames)
- Grass light now reads as warm sunlight. A gold wash (#D88A2A, alpha-blended, 25 % peak) shifts the teal towards gold.
  A narrow soft cream line (#FFF4D6, additive) runs at the centre, and the additive gold pool grows as the sun climbs.
  The cone fades out inside the band, so it no longer ends in a line (07). Long Night uses the same recipe in
  silver-gold. Tiles and planks are unchanged.
- Test `grassUnderTheBandReadsAsWarmSunlight`: brightness under the band is 1.35–2.0 × unlit, and R − B rises by
  ≥ 40 on the night meadow, ≥ 20 at dawn and ≥ 10 for Long Night (real textures, the night veil included).

## R4: ROUND-4 items 5–7 (REVIEW-3)
| Item | What |
|---|---|
| 5 Submerged | Underground a gloom is dim and desaturated: body 22 %, greyed, no gloss and no lit rim even under the band (`lit × (1 − sink)`). Its eyes show at 50 %, peeking over a **soil lip** (a feathered mound with a lit top edge and crumbs, tinted per ground's soil). The R3 dark mound is gone. It is held just inside the garden (`submergedMinD`: its top ≥ 6 pt below the crease line) and fades in as Core's d passes that line, so it is never drawn over the crease or the mirror's frame. The trail ripple is flatter and slower, with a soil crumb. |
| 6 Props | Harbour wet patches are a few long thin broken streaks lying in a plank seam (`GroundWorlds.wetCenter` snaps them), warm grey with highlights: never a capsule or blob. The band's glints sit on them (`GardenScene.wetSpots`). Rooftop chimneys have one rectangular flue with a cap and slats: no round holes. |
| 7 Thumb room | In book layouts the d = 1 line (and the flower row) sits `GardenMath.flowerInset` = 60 pt (at most 20 % of the depth) in from the garden's outer edge. This is handled in the Scene's own mapping (`GardenFrame`: `depth` = play depth, `fullDepth`, `inset`, `dScale`). The ground is drawn over the whole garden and its flower bed / ledge / boardwalk carries on under the thumb. `hudSafeRects`/`flowerRects` return the moved rects. No Contracts change. |
| App asks | `GardenScene.sunRect(layout:dawn:moonlit:)` and `mirrorFrameThickness(layout:)` (nonisolated) come from the mirror's own geometry (`GardenMirror.sunCircle/glass/frameThickness`, now the single source). Overlays that point into the garden should use `GardenScene.canvasPoint(layout:u:d:)` (see design/NEEDS.md). |

Tests: new `bookLayoutsLeaveThumbRoomOutsideTheFlowers` (951 × 669 both ways round + the test layouts),
`submergedGloomsStayOffTheMirrorFrame` (all four layouts) and `sunRectAndFrameThicknessMatchTheMirror`. The mapping,
round-trip, flower-rect, phone-scale and re-layout tests now go through the inset mapping; the harbour-glint test uses
the seam-snapped streaks.

## Notes / risks
- The drag fallback (`DragMirrorSource`) still scales drags by `layout.gardenDepth`. Book layouts are Duo (hinge)
  only, so this doesn't matter in play.
- `GardenFrame.floor(at:)` is a method named `floor`. Nothing inside `GardenFrame` calls the free `floor()`.
- The `GardenArt.groundKey` format gained an inset field (`-i<n>`).
