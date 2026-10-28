# Glint: review panel 1 (R1 frames, 28 Oct)
Inputs: GAME-DESIGN.md, ROUND-2.md, `artifacts/r1/shots/` 01–19 + icon + logs, `Glint/UI/*.swift`.
**Already in flight (ROUND-2), not re-reported:** empty garden / too easy / crease camping, the pasted sun star, HUD over
flowers 0 and 4, truncated world tabs, achievements/badges.
Ignoring those, the panel still would not pay £1.99 for this build. The menus look nice enough. The game frames
don't yet show the one thing the game is about: sunlight bouncing off a mirror.

## 1. Apple Design Award juror: **5/10**
- **P0 The app icon is solid black** (`app-icon-1024.png`, every pixel #000). The log says `icon ok rgb=1` next to
  `SKView: no drawables available`. The renderer draws an SKView offscreen and writes an empty frame, and the check
  doesn't catch it. If this is the icon that ships, nothing else matters.
- **P0 The light doesn't look like light.** In 06/07/14/15/19 the band is an opaque, flat yellow slab with vertical
  streaks. It hides the grass under it. It reads as a progress bar or a highlighter, not sunlight. Nothing joins it to
  the mirror: no shaft, no spill, no glow on the brass rail.
- **P1 The garden is wallpaper.** Teal noise, tiny "^" marks, white dot sprinkles. It has no focal object and looks the
  same in Meadow, Rooftops and Harbour (06 vs 08 vs 09). Only the mirror's skyline changes.
- **P1 Fireflies are plain glowing dots** (08, 10) and the grass is already sprinkled with white dots. You can't tell
  a friend from the background.
- **P1 The scene behind the menus isn't hidden properly.** The lever track, the mirror rail and the sun show through
  the headers in 04, 12, 16 and 17. It looks like a layering bug, not a "live scene".
- **P1 Cheap moments:** the Results art (12) is the same small clip-art sunset as the Today's Dawn card. The cover
  display (18) is a plain gradient with a clip-art sun and no best score, though the caption promises one.
- **P2** The home tagline is lilac on mauve and sits on the frame rail and lighthouse (01): low contrast. "Glint"
  overlaps the sun. Medallion 13 is red/pink while 11 and 12 are gold, so it reads as "failed".
- What works: the SF Rounded type system, the gold primary button, the brass frame, the flowers, the brute's face (09),
  and the Settings rows.

## 2. Game-feel / UX designer: **4/10**
- **P0 Width doesn't matter.** The band spans the whole garden, so a gloom's lane (`u`) never changes whether it gets
  hit. The whole game is one slider (d). Lanes only decide which flower gets eaten. Adding more glooms (ROUND-2) makes
  it harder, not deeper. Players will call it "just move up and down".
- **P0 There are two controls on phones and they disagree.** The copy says "drag anywhere", but a brass lever on the
  mirror moves as well. Its knob doesn't match the light: in 06 the band sits at 6 % of the garden while the knob is
  about 25 % down its travel. People will try to grab the lever.
- **P1 First 10 seconds (05):** the card shows two lines that say the same thing ("Drag down to let the light in" /
  "Drag anywhere to aim the light."). The garden is empty while it's up, so the first drag lights nothing.
- **P1 Hints sit on the mirror** (19, "Spare the fireflies."), away from where you're looking. They also cover the sun,
  which is the level clock.
- **P1 Results:** a won level (12) has four buttons (Next / Retry / Levels / Home). A first clear shows "Best 1,015"
  with no "New best!". A loss (13) has no tip and no "kind copy". It shows "0 flowers saved · 0 shadows popped", which
  is a bad demo fixture.
- **P1 Not much reason to come back tomorrow:** Today's Dawn has no streak and no "played today" state. Stars only
  count flowers, so a 3★ level never needs replaying for score. Long Night only shows a best.
- **P1 Modes look the same:** Long Night (14) has no wave banner and Today's Dawn (15) has no date chip, though both
  captions expect them. Both are the level screen with a different skyline.
- **P2** The chain readout "×2.25" / "×3.50" needs arithmetic to read. On Home, "Sunrises" doesn't say "levels", and the
  three round icon buttons have no labels. The bottom 35 % of Home is empty (01–03). The level map hides the level names
  ("Hop Along" is only on the Play button).

## 3. iPhone Duo specialist: **5/10**
- Strength: the physics is right. A low sun behind you, a mirror leaning back → the bright spot moves away from the
  crease. "Open wider = light reaches further" is literal and needs no tutorial. "Shut = dark" is perfect.
- **P0 The fold layouts break their own rules.** 10 and 11 still draw the brass lever ("no lever" is the caption).
  On Home (03) the Play button sits across the crease, at y ≈ 845–1010 with the crease at ≈ 975.
  The hinge and the button would literally cut each other.
- **P0 The light never moves in the fold demos.** The 10/11 logs show `band -0.020` on every frame, `angle -1`, for
  20 s. The pilot isn't driving the hinge source when fold=1. Check what a real Duo does when the hinge API returns
  nothing: right now it may be unplayable with no message.
- **P1 The flower edge (the danger zone) sits at 145°**, exactly where the hinge stops holding. Defending the flowers
  means holding the lid at its weakest angle, and in laptop pose the lid flops towards flat.
- **P1 Band core vs hinge noise.** Full light is ±0.05 d, which is ±3.25°. The hinge is ±5° absolute. Relative motion
  is probably smoother, but nobody has measured it. If the jitter after the filter is over 1.5°, brutes "slip" out of
  the light and it feels unfair.
- **P1 Speed parity:** the phone cap is 2.4 d/s, which is 156°/s on the hinge. Nobody can swing a friction hinge that
  fast with one finger. Phone players get an easier game.
- **P1 No book-pose frames** (951 × 669 landscape) and no laptop-pose Duo frames. The pose most people will play in has
  never been looked at.
- **P2 Swap halves in laptop pose** puts the mirror flat on the table and the garden upright, which stops making sense
  (11). The cover display (18) wastes the moment you shut the phone: it could show the paused score and today's dawn.

## 4. First-time player (30, casual): **4/10**
- 01: "Pretty, a sunset in a frame. What's the slider on the right? Can I drag it? Nothing happens. Tap Play."
- 05: "Drag down… I drag, a yellow stripe shows at the top of the grass. Where's the mirror in this? It's a painting."
- 06/07: "There's just a yellow bar and empty grass. The score went up and I didn't see why. Is it loading?"
- 08: "Little glowing balls. Are those coins? I'll drag over them… oh, I wasn't meant to? ×2.25 of what?"
- 09: "OK, an angry rock-thing in the light, that's fun! But it's the only thing I've seen in five levels' worth of frames."
- 10/11: "Same thing but the frame is bigger and five balls fly in a line."
- 12: "Three stars. I didn't feel I did anything to earn them." 13: "The night won… why? What do I do differently?"
- Would I keep it after 10 minutes? Only if things fill the garden. Would I open it tomorrow? Nothing tells me to.
## Merged fix list (de-duplicated, P0 first)

### P0
1. **Icon.** Render `AppIcon-1024` with SwiftUI `ImageRenderer` (or ship a checked-in PNG), not an offscreen SKView.
   The CI icon step should fail if mean luminance < 0.08 or there are fewer than 64 distinct colours. A human looks at
   the icon before every TestFlight build.
2. **Make the light reflected sunlight.** Draw a soft, additive (`.add` blend) light cone from the mirror's crease edge
   to the band, 18 % alpha, wider at the band end. Make the band an additive pool that brightens the grass under it
   instead of covering it: core #FFF4D6 at 70 %, edge #FFC24A, then transparent. Grass in the band gets warm rim
   highlights. The band fades out over the outer 6 % of the screen width. The lit strip between the crease and the band
   stays faintly warm (10 %), so you can see the beam travel. Tie in the hot spot on the mirror glass (already in flight).
3. **Give the width a job: cloud shadows.** The mirror's clouds (already drawn) cast 1–2 shadow gaps that drift across
   the band in `u`. Each gap is 0.15–0.30 of the width, drifts at 0.05–0.12 u/s, and shows as a cool blue gap in the
   band. Light inside a gap does 0 damage. From L6 onwards, waves time glooms to arrive under gaps. Now the player
   chooses who to light and when (hold back, wait for the cloud to pass), and fireflies can be sheltered under a gap.
   The rule is literal: a cloud covers the sun, the mirror catches less light. Show it first in L3 with the hint
   "Clouds block the sun."
4. **One control on phones.** Remove the mirror lever, or map it 1:1 to `b` with the knob at the band's height (it moves
   with the band). Add a small gold grip pill on the band's right end (44 × 20 pt) that pulses while
   `!hasMoved`. The start card says only "Drag down to let the light in", with the finger animating down and the band
   following it.
5. **Fold-layout rules, tested.** Never draw the lever when `fold=1`/hinge. No SwiftUI control may intersect the
   crease ± 28 pt on any fold layout. Move Home's Play button fully onto the garden half, ≥ 32 pt below the crease.
   Add this to the HUD overlap test with the same four layouts plus the 402 × 874 phone.
6. **Fix the hinge path in the fold demo** (band stuck at −0.020). If the hinge reports nothing for 1.5 s mid-level,
   switch to drag and show "Can't read the hinge: drag to aim" once.

### P1
7. **Hints move to the garden**, centred at 40 % of the garden height, with an arrow to their subject: "Light the
   shadows." points at the first murk, "Spare the fireflies." rings the first firefly in green. Never put them on the
   sun.
8. **Fireflies get their own look:** a body with two wing flickers, a lime glow #C8FF6A (not white) and a 6-dot trail.
   Remove the white dot sprinkles from the grass texture. When light starts scorching one, show a red-orange warning
   ring and a falling "eep" blip.
9. **Hinge comfort:** move the flower edge to 135° (`b = (θ−75)/60`) so the danger zone isn't at the hinge's limit.
   Measure the filtered jitter on a real Duo and keep the band core ≥ 2 × that. Lower the phone drag cap from
   2.4 → 1.4 d/s, and author no wave that needs more than 1.0 d/s.
10. **Results:** Won = "Next sunrise" (primary) and "Retry", with Levels/Home as small text links underneath. A first
    clear or a new record shows "New best!" with a burst. Under the stars, show 5 flower icons, eaten ones greyed.
    Lost = one tip based on what killed you, e.g. brute: "Open slowly to follow the big ones."; fireflies: "Sweep past
    fireflies quickly."; wisps: "One quick sweep pops a whole flock." Fix the 13 fixture to something like
    "2 flowers saved · 41 shadows popped".
11. **Come back tomorrow:** the Today's Dawn card shows "Day 3 streak" and a ✓ once played. The cover display (18)
    shows "Today's Dawn is up" or "Today: 2,140 · streak 3", and when paused shows the paused score and flowers left.
    The level's 3rd star needs no flowers lost plus a score target, shown on the level card ("★★★ 1,200").
12. **Give each mode its own look:** Long Night = moonlit (no sun, the mirror shows the moon, the band is silver
    #DDE6FF) plus a "Wave 3" banner. Today's Dawn = a date chip, e.g. "Wed 28 Oct", top centre of the mirror.
13. **Give each world its own ground:** Meadow = grass and clover; Rooftops = slate tiles with chimney shadows;
    Harbour = boardwalk planks with water at the flower edge. Add 2–3 static props per world (stones, a watering can,
    rope coils).
14. **Menus:** cover the scene behind every menu with a 55 % #140F2E scrim plus a blur, and hide the lever there.
    Home: rename "Sunrises" to "Levels"; put 13 pt captions under the round buttons (Settings / Game Center / About);
    move the three cards down so the empty band goes. Level map: show the level name under each medallion (13 pt) and,
    on a locked node, a silhouette of the shadow it introduces. Give 13 the same gold as the other unlocked medallions.
15. **CI frames:** add book-pose 951 × 669 (default and swapped) and laptop-pose Duo captures. Hide "Swap halves" on
    non-Duo phones, and limit it to book pose on a Duo.
### P2
16. Show the chain as a whole count ("Chain 7") with the multiplier in steps of 0.5 (×1, ×1.5 … ×4), up every 2 pops.
17. Home tagline in #FFE7B0 at 90 % with a 2 pt dark shadow, moved 16 pt above the frame rail. Keep "Glint" clear of
    the sun disc.
18. Cover display art: the brass mirror with the sun behind its glass, not the clip-art sun.
