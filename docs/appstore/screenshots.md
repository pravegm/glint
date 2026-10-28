# Glint: App Store screenshot plan (v1.0)

*Written Wed 28 Oct 2026 by the launch lead. Owner: CI captures and captions, the launch lead writes captions, the founder approves. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-glintDemo "…"` (the keys in `design/ROUND-1.md`, App engineer 5: `screen`, `progress`, `level`, `mode`, `t`, `skill`, `band`, `fold`, `swap`, `results`, `hint`) on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. The pipeline is Snapjaw's (`C:\Users\59527\Trap\.github\workflows\store.yml`, `ci/store-capture.sh`, `ci/store-set.sh`, `ci/store-frame.swift`), **to be ported by the CI engineer** with two scenario files, `ci/store-scenarios.txt` (iPhone sets) and `ci/duo-store-scenarios.txt` (Duo set). Once they exist, **the scenario files are the source of truth**: change a caption there, not only here (`tools/appstore/build-metadata.js` checks the frame names and sub-lines against this page).*

## Sets, sizes and slots (Apple's *Screenshot specifications*, as read for the sister games, Oct 2026)

Glint is **portrait everywhere** in its store sets: on other iPhones it plays in portrait (mirror on top, garden below: GAME-DESIGN §3), and the Duo set is the **laptop pose** (the inner display upright, fold across the middle, mirror on top): the pose that makes "the top half is a mirror" literal. The game also plays in book pose; that's said in the copy, not shown.

| Upload order | App Store Connect slot | Pixels (portrait) | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **1320 × 2868** | P01–P10 | `store-69` | Upload it: Apple scales it for 6.5" |
| 2 | **iPhone 6.3"** (Dynamic Island, medium display) | **1206 × 2622** | P01–P10 | `store-63` | **Required** (Apple's only required iPhone size); scaled for 6.1" and smaller |
| 3 | **iPhone Duo, inner display** | **2007 × 2853** | D01–D10 | `store-duo` | Swoop found the slot live on 27 Oct. Duo screenshots show the "optimized for iPhone Duo" badge; Apple requires them from April 2027 |
| – | iPhone Duo, outer (cover) display | 1398 × 2034 | none | – | Not made: Glint isn't played on the cover (it only shows "Paused" and the score) |

Rules: PNG, **no alpha channel**, 1–10 per size (**we use all 10**). In search results a portrait set shows **its first three frames**, so frames 1–3 have to sell the game together: **the mirror, the pop, the reach.**

## Frame 1 is the Duo standing like a laptop, the mirror catching the sunrise

The hero is the whole pitch: **an iPhone Duo standing open like a small laptop at about 115°, the top screen a brass-framed mirror with the sun rising in it, a band of gold light falling from the crease across the garden on the bottom screen, shadows popping in sparks.** Snapjaw's compositor (`store-frame --book`) maps a real Duo capture onto a drawn Duo; **ask (CI): add `--laptop`**, which takes D01, a **real Duo inner-display capture** (2007 × 2853, `fold=1`), splits it at the fold and maps the top half onto the upright screen and the bottom half onto the base by a true perspective transform, with a graphite bezel, the hinge and a soft ground shadow. **No hands.**
- **Truthful:** every screen pixel is the app's, only warped and clipped to the display's corners. The pose is a real way Glint is played (open in the play range, never flat, never shut). The composite's angle is the one the capture logged (`ciHinge`): keep it between 105° and 130° so the light is mid-garden, exactly as the app would show at that angle.
- **Used in every set** as frame 1, including the iPhone sets (from the same Duo capture); the iPhone caption's sub-line says other iPhones play too. It never shows a non-folding iPhone folded.
- **Fallback, automatic:** if D01's capture is missing or isn't the folded inner canvas (`GLINT-T canvas 2007x2853 fold=1`, in points as the app logs them), P01 is made flat from the iPhone capture and **FLAGGED**. Don't upload a flat P01 without telling the founder.

## Caption style

Snapjaw's compositor, recoloured for dawn:
- **Layout:** the caption band across the top, the capture under it (on the hero, the device on a soft dawn floor).
- **Background:** a vertical sweep from deep night indigo `#141A3A` at the top to dawn peach `#F4A97A` and gold `#F7C948` at the bottom, a soft warm glow behind the capture.
- **Type:** SF Pro Rounded Heavy, cream `#FFF7E8`. **One** highlighted word per headline (`*word*` in the scenario file), drawn as ink `#1B1530` letters on a sun-gold `#F7C948` marker swash. Sub-line after ` / ` in SF Pro Rounded Semibold, pale peach `#FFDCC2`.
- **Headline ≤ 30 characters** (counted without the asterisks) and ≤ 7 words; never "kill", "burn", "zap", "lid", "flat", "fast", "Fold to …", or a competitor name. The ported `store-set.sh` lints all of these.

## A. iPhone 6.9" (1320 × 2868) and 6.3" (1206 × 2622): 10 frames

Same frames and captions at both sizes. On these phones there is no hinge, so the brass lever shows on the mirror and the hints say "Drag…" where they speak about the control; no Duo-only words appear inside a capture.

| # (file) | Story beat (in-game moment) | Headline (count) / sub-line | Demo args (`ci/store-scenarios.txt`) |
|---|---|---|---|
| **P01** `P01-hero` | **The mirror.** Laptop composite of D01: the sun rising in the mirror, the band mid-garden, a murk popping in gold sparks, flowers along the edge | **Your phone is a *mirror*** (22) / Best on iPhone Duo. Plays on other iPhones too. | frame `laptop:D01-hero` (fallback capture `screen=play;level=6;t=18;skill=0.8`) |
| **P02** `P02-sweep` | **The pop cascade.** A wisp flock caught mid-Sweep: three pops bursting, "Sweep!" and "×3" floating, the chain chip | **Sweep the light. *Pop!*** (21) / Every pop climbs a rising scale. | `screen=play;level=3;t=22;skill=0.9` (freeze on a `.swept` event: ask App for `freezeOn=sweep`) |
| **P03** `P03-reach` | **The aim.** The band far out near the flowers, chasing a murk; the brass lever on the mirror tilted to match | **Aim the *sunlight*** (16) / Drag anywhere. The lever follows. | `screen=play;level=2;t=20;skill=0.8;band=0.8` |
| **P04** `P04-fireflies` | **Spare them.** Two fireflies drifting just outside the band, one flower replanted with its sparkle | **Spare the *fireflies*** (19) / They replant lost flowers. | `screen=play;level=4;t=12;skill=0.6;hint=spareTheFireflies` |
| **P05** `P05-brute` | **Tracking.** A brute steaming and shrinking inside the band, wisps behind | **Follow the *big ones*** (19) / Keep the light on a brute as it creeps. | `screen=play;level=6;t=25;skill=0.8` |
| **P06** `P06-worlds` | **Progress.** The level map, Meadow tab: ten sun medallions on a winding path, most starred, the next glowing, Rooftops showing "x more ★" | **30 *sunrises*, 3 worlds** (21) / Meadow, Rooftops and Harbour. | `screen=levels;progress=mid` |
| **P07** `P07-rooftops` | **New tricks.** Rooftops: splitter wisps flung outwards, a hopper crouching, "×3" near a pop | **Shadows that *split* and hop** (26) / New tricks on the Rooftops. | `screen=play;level=15;t=30;skill=0.8;progress=mid` |
| **P08** `P08-harbour` | **It gets hard.** Harbour: a dense wave, one flower lost (a drooping stalk), the sun high in the mirror | **Hard by the *Harbour*** (19) / World 3 will cost you petals. | `screen=play;level=27;t=40;skill=0.7;progress=mid` |
| **P09** `P09-long-night` | **Endless.** Long Night at 60 s: the wave banner, the score, the chain | **Then the *Long Night*** (19) / Endless waves. One best score. | `screen=play;mode=endless;t=60;skill=0.8;progress=mid` |
| **P10** `P10-todays-dawn` | **Daily.** Today's Dawn: the date chip, the score | **A new *dawn* every day** (20) / Today's Dawn: one sunrise for everyone. | `screen=play;mode=daily;t=20;skill=0.8;progress=mid` |

**Why this order:** 1–3 are the pitch (the mirror, the satisfying pop, the aim); 4–5 are the two skills (spare, follow); 6–10 are the reasons to come back (the worlds, new shadow tricks, real difficulty, endless, daily).

**Caption notes (truth):**
- **P02:** a Sweep is 3+ pops within 0.35 s (GAME-DESIGN §5) and the pops really do climb a pentatonic ladder (§9). The freeze must land after "Sweep!" appears, not before.
- **P03:** "The lever follows" is the phone fallback's brass lever (GAME-DESIGN §3); the Duo has no lever, so D03 has its own sub-line.
- **P04:** "They replant lost flowers": the frame needs a replant in view or a firefly clearly heading for a gap; if the seed doesn't give one, change the sub-line to "Keep the light off them."
- **P08:** "will cost you petals": the frame must show at least one eaten flower, and the balance table must agree (world 3 costs a decent player 1–2 flowers: ROUND-1 Core 3).
- **One progress state:** every frame that shows progress uses `progress=mid`, so the set reads as one player.

**Asks to the CI / App engineers for these frames** (none changes the game): the `--laptop` composite (above); `freezeOn=sweep` (freeze 0.15 s after a `.swept` event); `screen=levels;progress=mid` with Rooftops' "x more ★" visible.

## B. iPhone Duo, inner display (2007 × 2853, laptop pose): 10 frames

The same beats as A, captured on the Duo simulator in the laptop layout (`fold=1`, mirror on top), with the hinge held at **115°** (`ciHinge=115`) for the hero and driven by the pilot for play. No lever on the Duo (the hinge is the control).

| # (file) | Headline (count) / sub-line where it differs from A |
|---|---|
| **D01** `D01-hero` | **Your phone is a *mirror*** (22) / Open it to catch the sun. (frame `laptop`) |
| **D02** `D02-sweep` | as P02 |
| **D03** `D03-reach` | **Open wider, light goes *further*** (30) / The phone's angle is the aim. |
| **D04–D09** `D04-fireflies`, `D05-brute`, `D06-worlds`, `D07-rooftops`, `D08-harbour`, `D09-long-night` | as P04–P09 (D06: the Duo's level map on the split, nothing important on the crease) |
| **D10** `D10-todays-dawn` | as P10 |

Every Duo frame must log the folded inner canvas (`GLINT-T canvas <W>x<H> fold=1`), so a cover-display capture is FLAGGED, never uploaded.

Reserves (not uploaded unless a frame above fails): `R1-swap` (Settings › Swap halves: garden on top, mirror below) **Any way *round*** (13) / Swap the halves in Settings.; `R2-results` (three stars landing) **Save every *flower*** (17) / Five flowers kept, three stars.; `R3-book` (the Duo in book pose, the mirror on the left) **Or hold it like a *book*** (22) / One half mirror, one half garden.

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture (frame 1: only warped onto the device); captions sit outside it. No composited shadows, pops, light or flowers.
- [ ] **Frame 1's device is a real iPhone Duo pose** (laptop, about 115°: the hinge angle D01 was shot at), never a non-folding iPhone drawn folded, never shut or flat. The band's position on screen must be what the app shows at that angle.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build** (tick against the code, `metadata.md` §10): a Sweep is 3+ pops; the chain goes to ×4; 30 levels in 3 worlds named Meadow, Rooftops, Harbour; fireflies replant; brutes need tracking; splitters split; hoppers hop; Long Night is endless; Today's Dawn is the same for everyone. If any of these change, change the caption.
- [ ] **No "kill", "burn", "lid" or "Fold to …" anywhere,** in captions or in any in-game text visible in a frame.
- [ ] **Shadows pop, never splat** (`metadata.md` §11 ask 1): gold sparks and petals, no gore (P02 especially).
- [ ] **Seeded states are reachable states:** a chain of 2–6, `mid` progress, a score a real player gets. Never seed all 90 stars or an impossible score.
- [ ] **The iPhone frames have no Duo-only line inside the capture** ("Close the phone…"); the Duo frames have no lever.
- [ ] **Nothing important in the crease band** on the Duo frames, except the crease glow, which is the point.
- [ ] **No prices, "#1", Apple logos or the "Made for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7; Apple adds its own badge).
- [ ] **Exact size, PNG, no alpha** (MANIFEST says `slot yes`, `alpha no`). Captions readable at 25 % zoom.

## Upload order and checks (the App Store Connect tool, `screenshots` step)

The tool uploads the sets from the store run named by `DEFAULT_STORE_RUN` in `.github/workflows/asc.yml` (or its `store_run` input), in this order, and refuses a set whose MANIFEST isn't `flagged 0 missing 0`. The founder uploads nothing unless App Store Connect shows a slot the API doesn't offer: then Claude says so and names the files.

1. 6.9" slot: `store-69` P01–P10. 2. 6.3" slot: `store-63`, the same. 3. iPhone Duo slot: `store-duo` D01–D10, then check them in App Store Connect's preview.

**Never upload** anything in `_flagged/`, anything from a `raw-*` artifact, or anything from `ci.yml`'s `screenshots` artifact (test frames).

## Sources
- Apple, App Store Connect Help, *Screenshot specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
- Snapjaw's plan and pipeline (mirrored): `C:\Users\59527\Trap\docs\appstore\screenshots.md`, `C:\Users\59527\Trap\ci\store-*`
