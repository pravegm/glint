# Glint: App Store screenshot plan (v1.0)

*Written Wed 28 Oct 2026 by the launch lead; pipeline ported the same day. Owner: CI captures and captions, the launch lead writes captions, the founder approves. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-glintDemo "…"` (keys: `Glint/App/DemoMode.swift`, `design/notes/app-R1.md`) on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. The pipeline is ported from Snapjaw: `.github/workflows/store.yml` (**manual only**), `ci/store-capture.sh`, `ci/duo-store.sh` (new: the Duo pass; `ci/duo.sh` stays the hinge-check rig), `ci/store-set.sh`, `ci/store-frame.swift`, `ci/store-placements.sh`, `ci/store-banner.swift`, with the scenario files `ci/store-scenarios.txt` (iPhone sets) and `ci/duo-store-scenarios.txt` (Duo set). **The scenario files are the source of truth**: change a caption there and here together (`tools/appstore/build-metadata.js` checks the frame names and every iPhone sub-line against this page).*

## Sets, sizes and slots (Apple's *Screenshot specifications*, as read for the sister games, Oct 2026)

On other iPhones Glint plays in **portrait** (mirror on top, garden below: GAME-DESIGN §3), so the iPhone sets are portrait. The Duo set is the inner display in **book pose** (landscape, the fold top to bottom, mirror on the left, garden on the right): the Duo simulator boots in book pose and CI can't turn it to a laptop (there is no rotate command, and `simctl io … screenConfig` crash-loops SpringBoard on the Duo). The game plays in laptop pose too; the copy says so, the frames don't show it.

| Upload order | App Store Connect slot | Pixels | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **1320 × 2868** portrait | P01–P10 | `store-69` | Upload it: Apple scales it for 6.5" |
| 2 | **iPhone 6.3"** (Dynamic Island, medium display) | **1206 × 2622** portrait (1179 × 2556 also accepted) | P01–P10 | `store-63` | Required class in the tool (`APP_IPHONE_61`); scaled for 6.1" and smaller |
| 3 | **iPhone Duo, inner display** | **2853 × 2007** landscape (book pose) | D01–D10 | `store-duo` | Swoop found the slot live on 27 Oct. Duo screenshots show the "optimized for iPhone Duo" badge; Apple requires them from April 2027 |
| – | iPhone Duo, outer (cover) display | 2034 × 1398 | none | – | Not made: Glint isn't played on the cover (it only shows "Paused" and the score) |

Rules: PNG, **no alpha channel**, 1–10 per size (**we use all 10**). In search results a portrait set shows **its first three frames**, so frames 1–3 have to sell the game together: **the mirror, the pop, the aim.**

## Frame 1 is the Duo open like a book: one page the mirror, the other the garden

The hero is the whole pitch: **an iPhone Duo standing open like a book, the left page a brass-framed mirror with the sun rising in it, the right page the garden with a band of gold light across it, shadows popping.** `store-frame --book` takes D01, a **real Duo inner-display capture** (2853 × 2007, `fold=1`), splits it at the fold and maps each half by a true perspective transform onto one page of a stylised Duo, with a graphite bezel, the hinge spine and a soft ground shadow. **No hands.**
- **Truthful, including the angle:** every screen pixel is the app's, only warped. In store frames a pilot drives the light (`t=` / `skill=`), not the simulator's hinge, so the composite is drawn at **the angle at which the app puts the light where D01 shows it**: θ = 80 + 55 × band (design/ROUND-2.md R2 addendum: the flower edge at 135°), read from the capture's last `GLINT-T band` line by `ci/store-set.sh`, kept to 100–135°. If the band needs an angle more than 8° outside that range the frame is FLAGGED. The pictured phone and the pictured light always agree.
- **Used in every set** as frame 1, including the portrait iPhone sets (the book sits under the caption, full width); the iPhone caption's sub-line says other iPhones play too. It never shows a non-folding iPhone folded.
- **Fallback, automatic:** if D01's capture is missing or isn't 2853 × 2007 with `GLINT-T canvas <W>x<H> fold=1`, P01 is made flat from the iPhone capture and **FLAGGED**. Don't upload a flat P01 without telling the founder.

## Caption style

Snapjaw's compositor, recoloured for dawn (`ci/store-frame.swift`):
- **Layout:** portrait (iPhone): the caption band across the top (3.5–19.5 % of the height, up to 3 lines sized from the width), the capture under it. Landscape (Duo): the band across the top, the capture under it.
- **Background:** a diagonal sweep from deep night indigo `#141A3A` to dusk violet `#3A3470`, a soft sun-gold `#F7C948` glow behind the capture (leaning to the garden's side), a faint dawn-peach `#F4A97A` ember in the far corner, a darker band along the bottom.
- **Type:** SF Pro Rounded Heavy, cream `#FFF7E8`. **One** highlighted word per headline (`*word*` in the scenario file), drawn as ink `#1B1530` letters on a sun-gold `#F7C948` marker swash. Sub-line after ` / ` in SF Pro Rounded Semibold, pale peach `#FFDCC2`.
- **Headline ≤ 30 characters** (counted without the asterisks) and ≤ 7 words. `store-frame.swift` REJECTS kill, die, dead, burn, zap, smash, squish, splat, slam, "Fold to …", "lid" and competitor names; `store-set.sh` FLAGS flat, shut, quick, fast, free, prices and "#1".

## A. iPhone 6.9" (1320 × 2868) and 6.3" (1206 × 2622): 10 frames, portrait

Same frames and captions at both sizes. On these phones there is no hinge, so the brass lever shows on the mirror and the hints say "Drag…" where they speak about the control; no Duo-only words appear inside a capture. Demo args are copied from `ci/store-scenarios.txt` (which wins).

| # (file) | Story beat (in-game moment) | Headline (count) / sub-line | Demo args (`ci/store-scenarios.txt`) |
|---|---|---|---|
| **P01** `P01-hero` | **The mirror.** Book composite of D01: the sun in the mirror page, the band across the garden page, a pop in gold sparks | **Your phone is a *mirror*** (22) / Best on iPhone Duo. Plays on other iPhones too. | frame `book:D01-hero` (fallback capture `screen=play;level=6;t=18;skill=0.8;progress=mid`) |
| **P02** `P02-sweep` | **The pop cascade.** A wisp flock caught mid-Sweep: pops bursting, "Sweep!" floating, the chain | **Sweep the light. *Pop!*** (21) / Every pop climbs a rising scale. | `screen=play;level=3;skill=0.9;freezeOn=sweep;progress=mid` (freezes 0.3 s after the Sweep) |
| **P03** `P03-reach` | **The aim.** The band out in the garden; the brass lever on the mirror tilted to match | **Aim the *sunlight*** (16) / Drag anywhere. The lever follows. | `screen=play;level=2;t=20;skill=0.8;progress=mid` |
| **P04** `P04-fireflies` | **Spare them.** Fireflies drifting near the band, the hint line "Spare the fireflies" | **Spare the *fireflies*** (19) / They replant lost flowers. | `screen=play;level=4;t=12;skill=0.6;hint=spareTheFireflies;progress=mid` |
| **P05** `P05-brute` | **Tracking.** A brute steaming and shrinking inside the band, wisps behind | **Follow the *big ones*** (19) / Keep the light on a brute as it creeps. | `screen=play;level=6;t=25;skill=0.8;progress=mid` |
| **P06** `P06-worlds` | **Progress.** The level map, Meadow tab: sun medallions on a winding path, most starred, the next glowing | **30 *sunrises*, 3 worlds** (21) / Meadow, Rooftops and Harbour. | `screen=levels;progress=mid` |
| **P07** `P07-rooftops` | **New tricks.** Rooftops: splitter wisps flung outwards, a hopper crouching | **Shadows that *split* and hop** (26) / New tricks on the Rooftops. | `screen=play;level=15;t=30;skill=0.8;progress=mid` |
| **P08** `P08-harbour` | **It gets hard.** Harbour: a dense wave, one flower lost (a drooping stalk), the sun high in the mirror | **Hard by the *Harbour*** (19) / World 3 will cost you petals. | `screen=play;level=27;t=40;skill=0.7;progress=mid` |
| **P09** `P09-long-night` | **Endless.** Long Night at 60 s: the wave banner, the score, the chain | **Then the *Long Night*** (19) / Endless waves. One best score. | `screen=play;mode=endless;t=60;skill=0.8;progress=mid` |
| **P10** `P10-todays-dawn` | **Daily.** Today's Dawn: the date chip, the score | **A new *dawn* every day** (20) / Today's Dawn: one sunrise for everyone. | `screen=play;mode=daily;t=20;skill=0.8;progress=mid` |

**Why this order:** 1–3 are the pitch (the mirror, the satisfying pop, the aim); 4–5 are the two skills (spare, follow); 6–10 are the reasons to come back (the worlds, new shadow tricks, real difficulty, endless, daily).

**Caption notes (truth; eyeball each on the first store run):**
- **No `band=` pins:** the light in every frame is the light the pilot made, so lit shadows and the band agree.
- **P02:** a Sweep is 3+ pops within 0.35 s (GAME-DESIGN §5) and the pops really do climb a pentatonic ladder (§9).
- **P03:** "The lever follows" is the phone fallback's brass lever; the Duo has no lever, so D03 has its own caption.
- **P04:** "They replant lost flowers" needs a firefly in view; if the seed shows none, retime `t=` or change the sub-line to "Keep the light off them."
- **P08:** "will cost you petals" needs at least one eaten flower on screen at t=40; if not, retime.
- **One progress state:** every frame uses `progress=mid`, so the set reads as one player.

## B. iPhone Duo, inner display (2853 × 2007, book pose): 10 frames

The same beats as A, captured on the Duo simulator by `ci/duo-store.sh` with the hinge held open at **125°** (the 7th column of `ci/duo-store-scenarios.txt`) so the inner display is up and the layout folded, and the pilot driving the light. Mirror on the left page, garden on the right (the default; reserve R1 shows Swap halves). No lever on the Duo.

| # (file) | Headline (count) / sub-line where it differs from A |
|---|---|
| **D01** `D01-hero` | **Your phone is a *mirror*** (22) / Open it to catch the sun. (frame `book`: the composite of its own capture) |
| **D02** `D02-sweep` | as P02 |
| **D03** `D03-reach` | **Open wider, light goes *further*** (30) / The phone's angle is the aim. |
| **D04–D09** `D04-fireflies`, `D05-brute`, `D06-worlds`, `D07-rooftops`, `D08-harbour`, `D09-long-night` | as P04–P09 (D06: the Duo's level map on the split, nothing important on the crease) |
| **D10** `D10-todays-dawn` | as P10 |

Every Duo frame must log the folded inner canvas (`GLINT-T canvas <W>x<H> fold=1`) and be 2853 × 2007, so a cover-display capture is FLAGGED, never uploaded.

Reserves (not uploaded unless a frame above fails): Duo `R1-swap` **Any way *round*** (13) / Swap the halves in Settings. (garden on the left, so the light comes from the left); phone `R2-results` **Save every *flower*** (17) / Five flowers kept, three stars. A laptop-pose set (mirror on top) needs a way to turn the Duo simulator; not in 1.0.

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture (frame 1: only warped onto the device); captions sit outside it. No composited shadows, pops, light or flowers.
- [ ] **Frame 1's device is a real iPhone Duo pose** (book, open in the play range), drawn at the angle that matches its light (MANIFEST note "book from … at N° (from the band)"), never a non-folding iPhone drawn folded, never shut or flat.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build** (tick against the code, `metadata.md` §10): a Sweep is 3+ pops; the chain goes to ×4; 30 levels in 3 worlds named Meadow, Rooftops, Harbour; fireflies replant; brutes need tracking; splitters split; hoppers hop; Long Night is endless; Today's Dawn is the same for everyone. If any of these change, change the caption.
- [ ] **No "kill", "burn", "lid" or "Fold to …" anywhere,** in captions or in any in-game text visible in a frame.
- [ ] **Shadows pop, never splat** (`metadata.md` §11 ask 1): gold sparks and petals, no gore (P02 especially).
- [ ] **Seeded states are reachable states:** `mid` progress, a score a real player gets. Never seed all 90 stars or an impossible score.
- [ ] **The iPhone frames have no Duo-only line inside the capture** ("Close the phone…"); the Duo frames have no lever.
- [ ] **Nothing important in the crease band** on the Duo frames, except the crease glow, which is the point.
- [ ] **No prices, "#1", Apple logos or the "Made for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7; Apple adds its own badge).
- [ ] **Exact size, PNG, no alpha** (MANIFEST says `slot yes`, `alpha no`). Captions readable at 25 % zoom.

## Running it, and handing it to the App Store Connect tool

1. **Actions → App Store screenshots → Run workflow** (manual only; about 1.5–2 hours with the Duo). Leave the defaults. To redo only the phones, untick `duo` and put an earlier run's ID in `duo_from_run` (frame 1 needs that run's D01).
2. Open the run's summary: each set prints its MANIFEST. Download `store-69`, `store-63`, `store-duo` and eyeball every frame against the rules above. Anything in `_flagged/` must be fixed (or consciously accepted by the founder) first.
3. When all three MANIFESTs end `summary: ok 10  flagged 0  missing 0` and the frames pass the eyeball, put that run's ID in `DEFAULT_STORE_RUN` in `.github/workflows/asc.yml` (or pass it as `store_run`), then run the tool (`screenshots` step). Do it again after the final store run at code freeze (Mon 7 Dec).
4. Optional header and search art: re-run with `placements_from=<that run>` (minutes, no capture) and pass the new run as `placements_run` to the tool.

The tool uploads, in this order, and refuses a set whose MANIFEST isn't `flagged 0 missing 0`: 6.9" `store-69` P01–P10; 6.3" `store-63`, the same; iPhone Duo `store-duo` D01–D10 (only if the API offers a Duo group; else Claude names the files to upload by hand). **Never upload** anything in `_flagged/`, anything from a `raw-*` artifact, or anything from `ci.yml`'s `screenshots` artifact (test frames).

## Sources
- Apple, App Store Connect Help, *Screenshot specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
- Snapjaw's plan and pipeline (mirrored): `C:\Users\59527\Trap\docs\appstore\screenshots.md`, `C:\Users\59527\Trap\ci\store-*`
