# Glint: review panel 3 (R3 frames, 29 Oct)
Inputs: GAME-DESIGN.md, ROUND-3.md, REVIEW-2.md, `artifacts/r3/screenshots/` 01–24 + badges + icon, `ci/scenarios.txt`,
GLINT-BAL in `artifacts/r3/logs/build.log`, and `artifacts/duo2/duo-screens/` (real Duo hinge, PREVIOUS build).
Known and not re-reported: light on grass too faint (being fixed); 08 failed to capture.
**Scores: 7 / 5 / 5 / 6** (R2: 6 / 4 / 5 / 5). **Verdict: much closer, still not £1.99.** R3 killed the camping exploit,
and the icon, rail, warm grounds and cloud gaps now look like a paid game. But levels 1–5 still can't be lost, the
lost screen and the hints have never appeared in a frame (third round running), and nobody has played R3 on a Duo.

## What improved since panel 2
- **Camping is dead.** Parked pilot: any fixed band ≤ 0.40 loses all 5 flowers on L6, and every value fails L11 and
  L21. The laptop resting pose (≈ 91°, b ≈ 0.17) now loses. The field from L6 is 4.8–9.4 (target 4–10).
- World 1 has some stakes from L6: skill 0.3 loses 1.0 (L6), 2.5 (L8) and 1.3 (L10) flowers, and wins L8–10 5/6.
- The black slabs are gone. Light on tiles and planks is a warm additive pool (10, 21, 09), and the cloud gap still
  lines up with the cloud over the sun (10: cloud x≈400–525, gap x≈400–520; 21 and 15 too). Still the best idea here.
- **Icon:** a brass hand mirror, a sun, a soft beam and a grumpy gloom. It reads at 60 px. Big step up.
- The rail stops above the flowers with no stub, and the score/pause sit inside the frame. Fireflies are lime with
  wings (11). Rooftops is warm brick. Level names and gloom silhouettes on locked nodes (04b). Badges redrawn.
- Proven by fixtures: "✓ Day 3 streak" (23), cover "Today: 2,140 · streak 3" (18), cover paused with score and
  flowers (24), "Wave 2" (14), "Thu 29 Oct" chip (15), Swap ignored in laptop pose (11), "★★★ 1,400" targets (04).

## 1. Apple Design Award juror: **7/10** (was 6)
- **P0 The fail path is still invisible.** 13 ("lost to brutes") and 22 ("lost to hoppers") both render
  **"Sunrise!"** with 2 stars and "New best!". The CI expect (`GLINT-T result level-13`) passes whether you won or
  lost. Three rounds in, no reviewer has seen "The night won" with real numbers and a matching tip.
- **P1 The Results card overflows.** With 4–5 badge pills (13, 22), Retry, Levels and Home are pushed off-screen and
  Next sunrise is clipped. The flowers are shown three times (hero art, flower row, "5 flowers saved").
- **P1 The Today's Dawn chip collides** with the score pill (15: pill ends x≈365, chip starts x≈350) and sits on the
  sun. On Home on the Duo (03), the tagline runs flush into the left frame (x≈38) and "Glint" sits on the sun again.
- **P1 Ground props look like monsters.** Rooftops' chimney boxes (two black circles, 10/21) read as eyes. Harbour's
  grey puddles (09) are the same capsule shape as a submerged gloom's ripple.
- **P2** The level map's dotted path runs through the labels (Clover, Slate Grey, Skylight). Settings is 40 % empty
  below the buttons. The Results hero is still clip art (R2 fix 14). The cover display is a static logo. The Home sun
  is warm now but muddy, half hidden by cloud.

## 2. Game-feel / UX designer: **5/10** (was 4)
- **P0 Levels 1–5 have zero stakes.** Every skill loses 0.0 flowers on L1–5. L1 scores 320 at 0.3, 0.6 and 0.9 alike:
  every pilot pops every gloom, so there's no skill expression. The field is 0.7 (L1) to 2.7 (L5), and L1–4 give
  skill 0.3 ★★★ on 5–6 of 6 runs, so the score target isn't biting. That's ~5 minutes the founder will call "super easy".
- **P0 The difficulty curve is flat, then a cliff.** Skill 0.3 wins 57/60 runs on L1–10 and 56/60 on L11–20, so
  Rooftops is no harder to win. Then L21 is 1/6 and L29 is 0/6. Skill 0.6 never fails until L29. The 3rd-star target
  misses both ways: 0.6 gets it 3/6 on L5, L9 and L10, while 0.9 gets it only 3/6 on L24 and L27 (target ~95 %).
- **P1 You can't spare fireflies.** Pilots scorch 2–6 per level, even at skill 0.9 (L8: 4.0, L18: 3.0). The band is
  full width, so a firefly at a gloom's depth always burns. "Spare the fireflies" asks for something the controls
  can't do.
- **P1 The first 10 s are still empty.** 05: the card is up over a bare garden. 06 (L1 at 14 s): no gloom on screen at
  all, a score of 20, and some sparkles. "★★★ 300" on the L1 card means nothing before the first pop.
- **P1 Hints are unproven.** 19 shows no hint text, no firefly and no ring, just an empty garden. 07's caption ("brute
  tracked, steam, firefly") isn't met: the band is ~300 px below the brute. 09 shows no eaten flowers.
- **P2** Long Night at 60 s (14) is "Wave 2" with 2 glooms: the pressure from 30 s doesn't show. Juice (Sweep!, ×n
  text, steam, petal bursts) still appears in no frame.

## 3. iPhone Duo specialist: **5/10** (unchanged)
- **P0 R3 has never run on the Duo.** Every R3 frame is a 1206×2622 phone with a simulated split (10/11). The real-hinge
  pass is the previous build, and there `ui-home.png` is a blank green system screen. PAUSE-SHUT is FAIL: L1 reached
  sunrise (log: `event sunrise` at 93.8°) before the tool shut the phone, so shut-to-pause on a hinge is unproven.
- **P1 In book pose, your thumb covers your lives.** The flower column is the outer 9 % of the garden half (duo 01/05:
  x≈1820–1990 of 2000), exactly where the right hand grips a Duo held like a book. The last line of defence is under
  your thumb.
- **P1 Brutes need slow, steady opening:** 0.065 d/s ≈ 4.2°/s for 2.2 s+. Friction hinges stick and slip at that
  rate. The core is now ±4.2° (good), but `jitterDeg` p95 is still unmeasured. Measure it before L5 ships brutes.
- **P1 The submerged read in light:** 10 shows a 4-eyed capsule sitting in full light, unharmed (R2's "is it
  broken?"). In 14, 21 and 09 the crease blob and its eyes overlap the brass frame's bottom edge.
- **P2 Literal optics:** a real mirror past 90° throws light at the ceiling, not further along the floor. Nobody will
  check, and open = further feels right, but don't pitch it as "physics". The mirror half is decoration (sun clock
  and clouds). It could show where the submerged glooms will surface.
- Good: every level starts closed ("Close the phone to start", duo 01), the band maps 1:1 (108° → 0.49,
  135° → 0.96), there are no pose demands, Swap is book-pose only, and the cover now shows real data.

## 4. First-time player (30, casual): **6/10** (was 5)
- 01: "Pretty sunset in a gold frame, and eyes peeking under Play. Cute. Play."
- 05: "Drag down to let the light in… ★★★ 300? 300 what? Drag." 06: "A faint stripe and sparkles. 20 points. For what?"
- 07: "Whoa, an angry purple rock with fangs! And eyes in puddles. My light's down there, he's up here."
- 10: "Bricks look lovely lit. A dark gap. Oh, that cloud's on the sun! Clever. Lots of ink drops." 15: "Chain 8!"
- 09: "Planks and pots. Are those grey capsules monsters too?" 14: "Moon mode. He's squinting at me, ha."
- 13/22: "Sunrise, New best, badges… where's Retry? I have to scroll." Tomorrow? "Maybe, if it gets harder. I couldn't
  lose the first five."

## Merged fix list (P0 first)
### P0
1. **Make the fail path real and proven.** `results=lost` must force `won=false` ("The night won", flowers 0–2,
   real pops and score, tip by cause). Make the expect `result level-13 won=0` / `level-18 won=0` so CI fails on a
   won card. For 19, the fixture spawns a firefly at t−1 s, and the expect is `GLINT-T hint spareTheFireflies shown`.
2. **Stakes from level 2.** L1: field ≥ 2 from 10 s, 45 s long, scores that differ by skill. L2–5: add deep surfacers
   (0.45–0.6) and one brute by L4, so skill 0.3 loses ≥ 0.5 flowers on L3–5. Set starScore so 0.3 gets ★★★ ≤ 50 %
   on L2–5 and 0.6 ~60 % (today 0.3 gets it 6/6 on L1, L2 and L4).
3. **Smooth the curve.** Raise Rooftops so skill 0.3 wins ~80 % by L15 and ~65 % by L18–20. Soften L21–22 to ~40 %
   for 0.3 (today 1/6). Keep L29–30 as walls. Re-fit W3 starScore so 0.9 makes ~95 % (L24 and L27 are 3/6).
4. **Run R3 on the Duo sim before anything else ships.** Capture book-pose play frames (L1, L6, L12), Home (retake the
   blank `ui-home`), and Results. Do the pause test with the shut at t = 20 s of a ≥ 45 s level (the old run's level
   ended first). Log `jitterDeg` p95 at 4°/s opening.
### P1
5. **Results layout:** badges become one row of 44 pt medallions ("+3"), the card has a max height, and the CTAs are
   pinned in the bottom safe area. Drop the flower row (the hero already shows the flowers).
6. **Fireflies must be sparable:** give them their own depth rhythm (0.12 d/s, or spawn only between waves) or a
   lane-tinted band edge. Target: 0.9 scorches ≤ 1 per level, 0.3 ≤ 3 (today 2–6).
7. **Submerged and props:** under the band, submerged eyes at 50 % alpha and half-sunk behind a soil lip. The crease
   blob is clamped so it never draws over the mirror frame. Harbour puddles become flat, irregular reflections, not
   capsules. Rooftop vents get slats, never two dark circles.
8. **First 10 s:** the d = 0.3 murk is visibly surfacing *while* the card shows, so the first drag pops within 2 s.
   Hide the ★★★ target on L1's card (show it from L2).
9. **Book-pose ergonomics:** inset the flower row ≥ 60 pt from the outer edge, or move lives to a strip by the crease.
   Check with a two-thumb hand overlay on the 951×669 canvas. Keep the score pill off the frame corner.
10. **Collisions:** the date chip goes above the sun at the top centre, ≥ 12 pt from the score pill. The Duo Home
    tagline gets a 24 pt inset and "Glint" moves clear of the sun.
11. **Long Night:** at 60 s, a field ≥ 6 and Wave ≥ 4. Prove it in frame 14.
### P2
12. Level map: route the path behind the medallion centres, with a plate under the labels. Fill or trim the empty
    lower 40 % of Settings.
13. Juice proof: a frame 80 ms after a 4-pop sweep (Sweep! text, petals, ×n). Retry 08.
14. Results hero: a live crop of the player's own garden at sunrise. Cover: the mirror at the current sun height with
    the flowers left, not a logo.
15. Make the mirror informative: faint reflected ripples showing where the next glooms will surface.

**Would you pay £1.99? No, not yet.** It finally looks the part and the camping exploit is gone. But the first five
levels can't be lost, failure and hints have never been seen, and R3 hasn't been held in two hands on a Duo.
