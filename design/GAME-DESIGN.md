# Glint: game design v1

*Owner: founder (Claude). Every number lives in `Glint/Core/Tuning.swift`. This doc gives the intent and the starting
values. Working title "Glint". The product name is read from `CFBundleDisplayName` via `AppBrand.name`.*

## 1. The pitch (5 seconds)
**The top half of your iPhone Duo is a mirror.**
- Open the phone and it catches the sunrise, throwing a band of light across the bottom half.
- The wider you open, the further the light reaches.
- Shadows seep out of the phone's crease and creep towards your flowers. Light them and they pop.
- Spare the fireflies: they bring lost flowers back.

Store line: **"Catch the sun. Pop the shadows."**

## 2. Why it works
- **Duo-native and literal.** The top half *is* the mirror. Shut phone = shut mirror = dark. As the phone opens, light
  pools in the crease, then the band lifts out and sweeps across the garden. The phone's angle is the light's position,
  continuously, both ways.
- **New for the hinge.** The angle is a precise aim, used in both directions all the time: open to chase a shadow
  outwards, close a little to catch the next one at the crease. No sister game does this (Squish = press, Brim =
  pour rate, Swoop = wings, Hush = lid speed, Snapjaw = shut).
- **Clear.** Light = pop. Shadows come from the crease. Flowers are your lives. Fireflies are friends.
- **Addictive.** Sweeps through a crowd pop a cascade of rising notes. Levels last about a minute (one sunrise), with
  stars to earn. Endless ("Long Night") and Today's Dawn chase a score.
- **Satisfying.** Warm light, sizzle that swells with what's burning, pops with petals and golden sparks, a sunrise
  chord when you win. Haptic sizzle under your fingers, a crisp tick per pop.
- **Gentle on the hinge.** Play lives between about 80° and 145°. Never flat, never shut, small smooth moves.

## 3. The phone and the light
**Poses.** Any pose plays: held like a book (landscape, fold vertical) or stood like a laptop (portrait, fold
horizontal). The layout follows the screen: whichever way iOS gives us the canvas, one half is the **mirror** and the
other is the **garden** (the floor). Nothing asks for a pose.

**Which half is which.** iOS blurs one fixed physical half for 1–2 s when a fold starts from flat (founder, Brim and
Hush logs). In book pose that's the left half. Default: garden on the **right** half in landscape, the **bottom** half in
portrait (a laptop's "keyboard"). Settings › "Swap halves" flips it. Play never needs flat, so the blur rarely fires. Even
so, nothing time-critical is drawn only on the mirror.

**Hinge angle θ** (180° = flat), `Tuning`:
| θ | What you see |
|---|---|
| ≤ 15° | **Shut.** No light. The cover display takes over. A level can't start open: "Close the phone to start". |
| 15°…80° | **Dawn in the crease.** Light pools in the crease, brighter as you open (`creaseGlow = (θ−15)/65`). Cosmetic. |
| 80°…145° | **The band.** Its centre runs from the crease (d = 0) to the flower edge (d = 1): `b = (θ−80)/65`. |
| > 145° | The band stays at the flower edge. Flat is fine. (The Duo hinge only holds its position from about 15° to 145°: research/01-market.md.) |

The light reads the filtered angle: predictor + One-Euro, as in Hush. It is continuous between hinge reports (25–30 Hz,
±5°), so the band never steps.

**Floor space** (Core): `u` 0…1 across the garden (left → right as the player sees it), `d` 0…1 from the crease (0) to
the flower edge (1). The scene maps (u, d) to the screen for the current layout.

**The band** (`Tuning.band*`): full width (the mirror is as wide as the phone). Its intensity at distance `d` is 1 within
±0.050 of `b`, falling smoothly to 0 at ±0.085. A gloom burns at `intensity × 1 HP/s` (seconds of full light). It is
measured at the gloom's centre, padded by 40 % of its radius.

**Non-Duo fallback (first class).** Same layout, portrait. **Drag anywhere** (relative, like a trackpad): one garden
height of drag = the full sweep, with a soft speed cap of 2.4 d/s, so it plays like the hinge. The mirror shows a brass
lever that follows. Copy says "Drag to aim the light". Levels start with the band in the crease ("Drag down to let the
light in").

## 4. Shadows, fireflies, flowers
Glooms emerge from the crease at a random `u` and creep towards the flowers (`d` grows). They never stop in the light:
shadows don't stand still. So parking the band in one place gives each gloom only a short dose (≈ band width ÷ speed),
and **tracking** a big one (opening at its pace) is the skill.

| Kind | Look | HP (s of light) | Speed (d/s) | Special |
|---|---|---|---|---|
| **Murk** | inky blob, two eyes | 0.55 | 0.10 | basic |
| **Wisp** | small, quick, comes in flocks | 0.12 | 0.21 | one sweep pops a flock |
| **Brute** | big, slow, grumpy | 2.2 | 0.065 | must be tracked; parked light can't finish it |
| **Splitter** | twin-lobed | 0.7 | 0.09 | pops into 2 wisps flung 0.07 further out, fast (0.30) for 0.6 s |
| **Hopper** | ears, crouches | 0.8 | hops | rests 0.9 s, then hops +0.14 in 0.22 s. **The first touch of light makes it hop at once** (skittish) |

**Fireflies** drift out of the crease too (0.075 d/s, wavy in `u`). Light scorches them: 0.35 s of cumulative light
(it fades at 0.6 s/s when unlit) and a firefly fizzles, breaking your chain. A firefly that reaches the flowers
**replants** one lost flower, or blooms for +50 if none are lost. A quick sweep across a firefly is safe.

**Flowers.** Five across the flower edge (lanes of `u`). A gloom reaching d = 1 eats the flower in its lane. If that one
is gone, it eats the nearest one left. All five gone: the night wins (level failed / endless over).

## 5. Score and chain
- Pop values: murk 10, wisp 5, brute 40, splitter 15, hopper 20.
- **Chain:** each pop within 1.6 s of the last adds 1. Multiplier `1 + 0.25 × (chain − 1)`, capped at ×4. A
  fizzled firefly or an eaten flower resets the chain.
- **Sweep:** 3 or more pops within 0.35 s = "Sweep!" +30 × the number popped.
- Level end: +40 per flower left.

## 6. A level = one sunrise
- A level lasts `duration` (45–95 s). The sun rises on the mirror half as the clock runs. At sunrise every shadow left
  evaporates (a satisfying mass pop, no score), the sunrise chord plays, and stars are counted.
- **Stars:** 5 flowers = ★★★, 3–4 = ★★, 1–2 = ★. Stars unlock levels (each world opens at 2/3 of the previous
  world's stars; levels inside a world unlock one at a time).
- **Waves** are scripted per level from `LevelBook` (seeded, deterministic): a list of spawn groups `(time, kind,
  count, u-spread, formation)`. The density ramps in each level and per world.
- **30 levels, 3 worlds:**
  1. **Meadow** (1–10): murks, wisps (from 3), brutes (from 5), fireflies (from 4).
  2. **Rooftops** (11–20): splitters (from 11), hoppers (from 14), mixed flocks.
  3. **Harbour** (21–30): everything, faster, denser, fewer fireflies.
- **Long Night** (endless, from level 5 or the first launch +1 day, whichever comes first): waves escalate forever;
  score = points. Best score on the leaderboard.
- **Today's Dawn** (daily, from level 3): one seeded 90 s sunrise for everyone that day. The score is the points; best
  of the day kept.

## 7. First session (no forced tutorial)
- Home → Play goes straight to level 1. One line at a time, each shown only until it's done:
  1. Phone open: "Close the phone to start." (Duo only; skipped if already shut. The cover display says "Open the phone".)
  2. Shut: "Open the phone to let the light in."
  3. First murk: "Light the shadows." (gone after the first pop)
  4. Level 2, first brute: "Follow the big ones." Level 4, first firefly: "Spare the fireflies."
- Level 1 is gentle (12 murks, 60 s, nothing fast) and should be won by anyone who moves the phone at all.

## 8. Pause, close, resume
- θ ≤ 15° for 0.25 s mid-level, app inactive, or the pause button: **paused** (glooms freeze). The cover display
  shows "Paused · open the phone to carry on" and the score.
- Resume: θ ≥ 25°, with 0.6 s grace (glooms frozen, then a 0.5 s fade back in). No "hold still" card.
- Never a pause or warning near 90°.

## 9. Feel (sound and haptics)
- **Sizzle:** filtered noise and a crackle. Loudness = total burn rate this frame, pitch rises as HP falls.
  Haptic: a continuous soft texture whose intensity follows the sizzle.
- **Pop:** a bright pluck on a pentatonic ladder: each chain step goes up a note, with a sparkle tail. Bigger glooms
  give a lower, fuller pop. Haptic: a sharp transient, intensity by size.
- **Sweep:** a chord stab plus a whoosh. **Firefly fizzle:** a sad falling blip. **Firefly delivered:** a bell and a
  flower bloom. **Flower eaten:** crunch plus a low thud, heavy haptic.
- **Band motion:** a soft air tone whose level follows band speed (very quiet).
- **Sunrise:** a rising major chord with birdsong chirps. **Night wins:** a low minor fall.
- Ambient: a dawn pad that brightens with the sun.
- Ring/silent switch: the app plays sound (`.playback`) unless Settings › Sound is off (Squish lesson).

## 10. Look
- **Garden** (seen from above): dewy grass in deep blue-teal that warms to gold as the sun rises. Dark at the crease
  (where shadows live), flowers at the edge. The band is warm gold with soft edges, dust motes and a slight shimmer, and
  glints where it crosses dew.
- **Glooms:** wobbly inky blobs (purple-black, with a faint rim light), big white eyes that squint in the light and
  blink. Lit: they steam and shrink. Pop: they burst into gold sparks and petals.
- **Mirror:** a brass-framed mirror showing the dawn sky: the sun rising (level progress), clouds, a glint at the
  sun. The reflected sky shifts slightly with the angle.
- **HUD (garden half):** score and chain at the flower edge's corner, pause button. The flowers *are* the lives.
- Menus: warm, illustrated, live scene behind (attract mode), SF Rounded, big friendly buttons, real art on every
  card. Never plain system lists.

## 11. Out of scope for 1.0
IAP, ads, accounts, analytics, iPad. Leaderboards via Game Center only (optional, never gating).
