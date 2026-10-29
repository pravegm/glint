# Glint: review panel 2 (R2 frames, 29 Oct)
Inputs: GAME-DESIGN.md, ROUND-2.md (with addendum), `artifacts/r2/screenshots/` 01–22 + badges + icon + logs,
`ci/scenarios.txt`, `Glint/UI/*.swift`, `design/notes/core-R2.md`. Scores were 5 / 4 / 5 / 4 in panel 1.
**Verdict: better, still not £1.99.** The shell is now nearly premium. The round's main goal was to end crease
camping, and it failed: the camping line just moved down to the edge of the shade. Every Meadow log parks the band at
d ≈ 0.18–0.22 (06: 0.216, 07: 0.199, 10: 0.183, 14: 0.210). That's θ ≈ 90°, a normal laptop angle. The garden below
it is empty in 06, 07, 14 and 19.

## What improved since panel 1
- The icon renders (lum 0.326, 345 colours). The Results card has 2 buttons plus links, "New best!", a flower row and
  earned badges (12). The lost card shows a tip (13/22). "Chain 7" replaced "×2.25".
- Rooftops tiles and Harbour planks with plant pots: the worlds finally look different (08/09/21). Long Night is
  moonlit with a silver band (14). The level tabs fit ("Rooftops ★ 6/30").
- Cloud shadows work, and they're literal: the cloud over the sun in the mirror lines up with the gap in the band (08:
  cloud x≈355–495, gap x≈345–500; 09 has a full-height cool column). It's the best new idea in the build.
- On the Duo: no lever when fold=1 (10/11), Play sits clear of the crease (03), the flower edge is at 135°, the knob
  maps 1:1 to the band, and the glooms squint when lit (11). Badges come in bronze and gold tiers with real art.

## 1. Apple Design Award juror: **6/10** (was 5)
- **P0 Black rectangles in the light.** Submerged glooms are masked with hard dark boxes that spill into the band
  (21: two black slabs at y≈1050–1110 under the murk pairs; 08 and 10 under the crease gloom). It reads as a render bug
  in the frame the store will use.
- **P0 On grass the light is still a slab** (06/07/14/19): opaque pale yellow, a hard top edge, grass hidden. The
  addendum asked for a cone from the mirror and a trail, and neither shows in any frame. On tiles (08/21) it's additive
  and looks right, so the grass shader/blend is the problem. Long Night's white slab (14) is the worst one.
- **P1 The brass rail runs over flower 5** in every phone frame (05–09, 14, 15, 19, 21). It also climbs 25 % up into
  the mirror, a stub that leads nowhere (the track starts at bandMin < 0). The score pill and pause straddle the
  mirror's frame edges.
- **P1 The icon reads as a lightsaber or glow stick next to a blob.** There's no sun, the "mirror" is a pill, the beam
  has stepped hard bands, and the background is split by a hard diagonal. At 60 px it's a yellow stick.
- **P1 Home's "sun" is a grey moon with craters** (01–03) under "Catch the sun". On the Duo (03), "Glint" and the
  tagline sit on the disc. On phones the bottom 25 % of Home is still empty, and a smeared light strip runs behind the
  cards (01 y≈980–1110).
- **P1 Rooftops' blue tile patches look like cloud shade** (08/10/21). Harbour's eyeless blue-grey puddles look like
  glooms (09). The ground art fights the new mechanic.
- **P2** The Results hero is still the Today's Dawn clip art (12). The cover display (18) hasn't changed since R1. Badge
  "rooftops" is an unreadable streak over a pink shape, and "brute" is a plain blob. Settings has 25 % empty space above
  the title. Medallion 13 is still red-pink.

## 2. Game-feel / UX designer: **4/10** (unchanged)
- **P0 A dominant strategy still exists.** Glooms rise at d = 0.12, so parking the band core on 0.15–0.25 catches every
  murk and wisp as it surfaces. Nothing gets past, nothing moves, and the field stays empty. The sim admits it: the L6–7
  field is 2.6–3.9 glooms (target 4–10). The shade moved the camping spot, it didn't remove it.
- **P0 World 1 can't be lost.** Skill 0.3 wins all of L1–10, losing ≤ 0.6 flowers (core-R2). Stars still only count
  flowers, so ★★★ is automatic. That's 10 levels (≈10 min) with no tension. The founder has rejected that before
  ("super easy").
- **P1 The first 10 seconds haven't changed** (05). The card still has two lines saying the same thing ("Drag down to
  let the light in" / "Drag anywhere to aim the light."), and the garden is empty, so the first drag lights nothing.
  The grip pill doesn't pulse and the finger doesn't animate.
- **P1 Hints with no subject:** "Spare the fireflies." (19) appears with no firefly on screen and no arrow (the arrow
  only shows when `hintTarget` exists). A hint must wait for its subject.
- **P1 Lost fixture is still "0 flowers · 0 shadows · score 0"** (13 and 22, flagged in R1), and both show the same
  flock tip for different levels. Nobody can check that tips match their cause.
- **P1 Modes:** Long Night's "Wave n" only shows when the chain is < 2 (`PlayHUD` else-if), so you never see it.
  Long Night is 484 points at 60 s against Today's Dawn's 1,033 at 20 s: endless is the sparse mode. Today's Dawn has
  no date chip, and Home shows no streak (02 "New today").
- **P2** The level map still hides level names, and locked nodes show no silhouette. The 04 fixture shows Rooftops,
  but its caption says Meadow. Juice (×n text, sweeps, hit-stop) appears in no frame, so it's unverified.

## 3. iPhone Duo specialist: **5/10** (unchanged)
- **P0 The camping spot is the resting pose.** Band 0.2 → θ = 80 + 0.2 × 55 ≈ 91°. A Duo player can set the phone down
  like a laptop and win Meadow without touching it. That's the opposite of "the angle is a precise aim, used both ways".
- **P1 The core is narrower in degrees:** ±0.05 d × 55° = ±2.75° (it was ±3.25°), against ±5° absolute hinge
  accuracy. The post-filter jitter still hasn't been measured on a device. Brutes will "slip". Widen the core to
  ±0.065 or measure first.
- **P1 Still no real Duo canvas frames.** Every frame is a 402×874 phone with a simulated split. Nobody has looked at
  book pose (951×669), the pose most people will play in (R1 P1, carried over).
- **P1 Swap in laptop pose** (11) still lays the mirror on the table and puts the flowers under the top edge and
  Dynamic Island. Limit Swap to book pose (R1 P1, carried over).
- **P1 The cover display** (18) shows no best, no streak and no "Paused · 1,281". `CoverView` has the code, but the
  demo seeds no data, so it's unproven.
- Good: the score is on the mirror's far corners, safe from the blur. Pause on shut. No pose demands.

## 4. First-time player (30, casual): **5/10** (was 4)
- 01: "Nice frame. Is that the moon? It says catch the sun. Tap the big yellow Play."
- 05: "Drag down… twice, it says. I drag, and a yellow stripe appears near the top. Nothing's there."
- 06: "A glowing bar and empty grass. 20 points? For what?" 07: "Chain 7, but I never saw anything pop. A glowing
  ball — friend or coin?"
- 08: "Bricks! Little ink guys with googly eyes, cute. Why is there a gap in my light? Oh, the cloud in the sky. Cool."
- 15/21: "There's a row of blobs IN my light and they aren't popping? Is it broken?" (submerged reads as immune-while-lit)
- 09: "Planks, pots. Are those blue puddles monsters?" 12: "Sunrise! New best! Badges! That felt good."
- 13: "The night won… 0 points, 0 popped? I was playing." Tomorrow? "The Daily says 'New today'. Maybe."

## Merged fix list (P0 first)
### P0
1. **Kill the camping line: glooms travel submerged and surface at authored depths.** A gloom moves *under* the
   ground (eyes plus a ripple, immune) from the crease to `surfaceD` (LevelBook, 0.15–0.60, per spawn), then rises.
   Murks surface 0.15–0.35 in L1–3, spread to 0.15–0.6 from L4, and wisp flocks surface together in a line. Add a
   BalanceTest: a parked pilot (any fixed b) must lose ≥ 2 flowers on L6 and L11, and fail L21. Target the field from L6
   at 4–10 (today 2.6–3.9).
2. **Don't draw light where it does nothing.** For d < creaseShade the band drops to 15 % with a cool tint, and the
   0.12 rim gets brighter. Submerged glooms get a soft sink mask (a feathered alpha gradient over the lower 50 %), not
   a box. Fixes the black slabs (08/10/21) and the "lit but immune" read (15/21).
3. **The light on grass is a pool.** Use the tile path's additive blend on grass and Long Night: core #FFF4D6 at 55 %,
   no hard top edge (a 0.03 d feather each side). Draw the 18 % cone from the mirror's crease edge to the band and a
   0.4 s warm trail. CI check: the mean luminance of the grass under the band must be < 1.8 × the grass outside it.
4. **World 1 needs stakes:** L4–10 at skill 0.3 should lose 1–2 flowers by L7–10 and fail sometimes (L9–10 ≤ 80 %).
   The 3rd star = all 5 flowers + a score target, shown on the medallion and the start card ("★★★ 1,400").
### P1
5. **Phone rail:** the track ends at the flower edge's top (stop above flower 5), with no stub above the crease
   (clamp the track at bandMin = 0). Inset the score pill and pause ≥ 12 pt inside the brass frame.
6. **First 10 s:** one line only ("Drag down to let the light in"), the finger animating down and the grip pulsing.
   Spawn L1's first murk at t = 0 at d = 0.3, so the first drag pops something within 2 s.
7. **Hints wait for their subject:** show "Spare the fireflies." only while a firefly is on the field, with its arrow
   and a green ring. Same for "Follow the big ones" and brutes.
8. **Icon redraw:** a brass hand mirror (round or arched, readable at 60 px) catching a warm sun disc, a soft beam to
   one cute gloom squinting. No stepped bands, a single gradient background. Check it at 60 px next to Squish/Brim.
9. **Ground vs mechanics:** remove the blue tile patches (Rooftops) and the blue puddles (Harbour), or make them warm.
   Cool blue is reserved for cloud shade only.
10. **Fixtures that prove things:** lost 13 = "2 flowers saved · 41 popped · 1,120", killed by brutes → brute tip; 22
    killed by hoppers → hopper tip. Daily fixture with streak 3 (Home card shows "Day 3 streak", the cover display shows
    "Today: 2,140 · streak 3"). A cover-paused frame ("Paused · 1,281 · 4 flowers"). Fix the 04 caption or the fixture.
11. **Modes:** Long Night always shows "Wave n" (a second line under the chain, or a banner on each new wave), and its
    pressure gets raised to match world 2–3 from 30 s. Today's Dawn gets a date chip ("Thu 29 Oct") top centre on the
    mirror.
12. **Duo capture pass:** CI frames at 951×669 book pose (default + swapped) and 669×951 laptop pose. Swap halves only
    in book pose. Widen the band core to ±0.065 until filtered jitter is measured on a device (log `jitterDeg`
    p95 in the About trace).
13. **Home:** draw a warm sun (not the cratered moon) behind the title, keep "Glint" clear of the disc in the Duo
    layout, move the card stack down to fill the bottom 25 % on phones, and remove the light smear behind the cards.
### P2
14. Results hero art: a small live crop of the player's own garden at sunrise, not the Daily clip art.
15. Level map: the level name under each medallion and a gloom silhouette on locked nodes. Medallion 13 in gold.
16. Badges: redraw "rooftops" (a roof line with a sun) and "brute" (an angry big gloom popping). Centre the warm glow.
    Settings: put the title at the top safe area and remove the empty band.
17. Fireflies: a bigger lime body (#C8FF6A) with wing flicker and a 6-dot trail. They still read as white dots (07/09/15).
