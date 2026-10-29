# Round 3 (founder brief, Thu 29 Oct morning)

R2 is green (CI 40789455196, 183 tests; frames in `artifacts/r2/screenshots/`). The critic panel (design/REVIEW-2.md)
scored 6 / 4 / 5 / 5. Its merged fix list (numbered 1–17 there) is this round's scope. Owners below. Read REVIEW-2 in
full first.

**Contracts (founder, done):** `GloomState.submerged` + `surfaceD` (defaults false / 0) and a new event
`GameEvent.surfaced(id:kind:u:d:)`. Every exhaustive `switch` over `GameEvent` must handle it (Scene, Feedback, App).

## Core — fixes 1, 4, 11 (pressure), 12 (band core)
- Glooms travel submerged from the crease to a per-spawn `surfaceD` (LevelBook-authored, 0.15–0.60; L1–3 0.15–0.35,
  spread from L4; wisp flocks surface together in a line), immune and invisible to light while submerged, then raise
  `.surfaced`. Submerged speed = their normal speed × 1.6 (they hurry underground). The crease shade stays.
- A `ParkedPilot` in BalanceTests: any fixed band (try 0.15, 0.25, 0.4, 0.6, 0.8) must lose ≥ 2 flowers on L6 and L11
  and fail L21 for every value. Field 4–10 glooms on average from L6.
- World 1 stakes: skill 0.3 loses 1–2 flowers by L7–10 and wins L9–10 ≤ 80 %. Keep L1–3 gentle.
- 3rd star = 5 flowers AND `LevelSpec.starScore` (set so skill 0.6 makes it ~60 % of the time, 0.9 ~95 %). Add
  `static func stars(flowersLeft:score:starScore:) -> Int` (keep the old one for compatibility, documented).
- Long Night: world 2–3 pressure from 30 s.
- `Tuning.bandCoreHalfWidth` 0.050 → 0.065 (edge 0.085 → 0.10) until device jitter is measured.

## Scene — fixes 2, 3, 5 (rail), 9, 13 (Home sun art), 15 (medallion 13 colour is App), 17
- Light inside the crease shade drawn at 15 % with a cool tint; a brighter rim at the 0.12 line.
- Submerged glooms: eyes + a moving ripple under the ground (feathered alpha mask, never a box), visible for the whole
  underground trip so the player can read where they'll surface; a burst of soil/dust + a small "pop up" on
  `.surfaced`.
- Grass and Long Night light = the additive pool the tiles already get (core #FFF4D6 ~55 %, 0.03 d feather, no hard
  edge), the 18 % cone from the mirror's crease edge to the band, a 0.4 s warm trail. Add a test that renders the
  scene offscreen (or samples the textures) and checks the grass under the band is < 1.8 × the grass outside.
- Phone rail: track from d = 0 to the top of the flower row (never over a flower, no stub in the mirror).
- No blue on the grounds: Rooftops' slate patches warm (charcoal/brown), Harbour puddles warm-grey and highlighted
  (never blob-shaped). Cool blue is cloud shade only.
- Fireflies: bigger lime body #C8FF6A, wing flicker, a 6-dot trail.
- The attract/menu mirror shows a warm rising sun (never the cratered moon), except in Long Night.

## App — fixes 5 (HUD inset), 6, 7, 8 (AppIconArt), 10, 11, 12 (swap only in book pose), 13, 14, 15, 16
- See REVIEW-2 for each. Icon: the founder-agent redraws the committed `AppIcon-1024.png` with tools/make-icon.js;
  then make `AppIconArt` match it (read the PNG).
- Fixtures: lost results with real numbers and per-cause tips (brutes for L22, hoppers for L18), daily streak 3,
  cover-paused frame, Today's Dawn date chip, Long Night wave line always visible.
- The 3rd-star score target shown on the medallion and the start card ("★★★ 1,400"): use Core's `starScore`.
- First 10 s: one line, finger animates, grip pulses; Core spawns L1's first murk surfacing at d = 0.3 at once.

## Feel — `.surfaced` cue (a soft "bloop" pop-up with a tiny haptic), handle the new event, keep tests green.
