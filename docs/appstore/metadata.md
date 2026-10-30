# Glint: App Store metadata (v1.0)

*Written Wed 28 Oct 2026 by the launch lead, from `CLAUDE.md`, `design/GAME-DESIGN.md` v1, `design/ARCHITECTURE.md`, `design/ROUND-1.md`, `Glint/Shared/Contracts.swift` and `research/01-market.md`, in the structure and tone of Snapjaw's Apple-tested kit (`C:\Users\59527\Trap\docs\appstore\`). **The build doesn't exist yet** (Round 1 is being written), so every feature claim below is from the design and is listed in §10 with an empty "Code" box: tick each one against the code once it compiles, and again on the release candidate ("RC"). If a line is false, change the copy here, never the build to match the words. Nobody pastes these: `node tools/appstore/build-metadata.js` turns the code blocks into `docs/appstore/asc-metadata.json`, and the App Store Connect tool (`tools/appstore/`, `asc.yml`) pushes it. Change the text here, then regenerate. Counts are Unicode characters (counted with Node), except keywords, which Apple counts in bytes (all ASCII here, so the same).*

**Words the copy uses** (the game's own words, GAME-DESIGN §1–§10): *the mirror* (the top half, or whichever half iOS gives it), *the garden* (the other half), *the crease* (the fold, where shadows come from), *the band* / *the light*, *catch the sun*, *open the phone wider* / *close it a little*, *shadows* (in-game kinds: *murk, wisp, brute, splitter, hopper*), *pop*, *sizzle*, *chain*, *Sweep!*, *spare the fireflies*, *replant*, *flowers* (your lives), *sunrise* (one level), *stars*, *the night won*, *Meadow, Rooftops, Harbour*, *Long Night* (endless), *Today's Dawn* (daily), *phone* (never "lid"). **Never:** "kill", "die", "dead", "burn" (the light *pops* shadows; "burn" is only the code's word), "zap", "blast", "smash", "squish", "lid", "Fold to …" / "Open to …" as a slogan, "flat", "as fast as you can", owls (the research's early draft; the game has fireflies), and no competitor names anywhere.

**The pitch order** (`research/01-market.md` §3, "Glint positioning"): lead with **the mirror** (the phone's own half is a mirror that catches the sun), then **reach** (the wider you open, the further the light goes: that's the aim), then **the pop** (shadows creeping from the crease, popped in a rising cascade), then **sparing the fireflies**. Lead with reach, not stealth, to keep clear of Hush (tabletop, open slowly). The reasons to come back follow: 30 sunrises in 3 worlds with stars, the Long Night, Today's Dawn.

Localisations: **English (U.K.)** is the primary language, plus **English (U.S.)**. Every other storefront shows en-GB. Only the description differs between the two (§4); everything else is identical.

---

## 1. App name (limit 30)

```
Glint: Sun Mirror
```
**17 / 30.** The research's pick (`research/01-market.md` §4): "Glint" is literally light flashed off a mirror, and the compound name sidesteps an old delisted "Glint" game and keeps clear of **Glint Pay** (a UK fintech, "Glint | Buy Gold Instantly", Finance category, a different trade-mark class). "Sun Mirror" also indexes two of the search words we want without spending keyword bytes.

If App Store Connect says the name is taken when you create the record, use the first that works, and tell Claude:

| Order | Fallback | Count |
|---|---|---|
| 1 | `Glint: Sunlight Mirror` | 22 |
| 2 | `Glint: Catch the Sun` | 20 |
| 3 | `Dawnlight: Sun Mirror` | 21 |

The home-screen name under the icon is **Glint** (`CFBundleDisplayName`), whichever store name is used (fallback 3 would also change the home-screen name to Dawnlight, and `AppBrand.name` follows it).

## 2. Subtitle (limit 30)

```
Catch the sun, pop the shadows
```
**30 / 30**, the same in en-GB and en-US. The brief's line was "Catch the sun. Pop the shadows." (GAME-DESIGN §1), but with its two full stops it is **31** characters, one over Apple's limit; the comma version says the same in 30. "Catch the sun" is literal (the phone's mirror half catches it), unlike the research's "Tilt the sun". It indexes "catch", "sun", "pop" and "shadows". No "Fold to …", no price, superlative or Apple mark (Guideline 2.3.7). The two-sentence store line stays in the game's own art, the press kit and the website, where there's no limit.

Alternative for a later version: `Open wider. Light goes further.` is 31, too long; `Light the way. Spare fireflies.` (30) is the backup if review ever objects to "pop".

## 3. Promotional text (limit 170; can change any time without a new version)

```
Your iPhone Duo is a mirror. Open the phone to catch the sunrise: the wider you open it, the further the light reaches. Pop the shadows, spare the fireflies.
```
**157 / 170**, both locales. The mirror and the Duo first, then reach, then the pop and the fireflies. Other iPhones get their own heading in the description.

Rotation ideas for later (count before pasting):
- After launch week: `Today's Dawn is up: one sunrise, the same for everyone, every day. Catch the sun, pop the shadows and beat your friends' best.` (121)
- After a press mention: a real quote with the outlet's name, only once it exists.

## 4. Description (limit 4,000)

Short paragraphs and capitalised section heads, so it scans on a phone: the first three lines (all that shows before "more") are the mirror, the reach and the pop. Then the rules, the five shadows, the worlds, the modes, then the Duo and other iPhones. The counts are printed by `build-metadata.js`.

### en-GB (English U.K.)

```
The top half of your iPhone Duo is a mirror.

Open the phone and the mirror catches the sunrise, throwing a band of warm light across the garden below. The wider you open it, the further the light reaches. Close it a little and the light comes back towards the crease. Shut the phone and it's dark.

Shadows seep out of the crease and creep towards your five flowers. Hold the light on one and it sizzles, shrinks and pops in a burst of gold sparks and petals. Sweep through a crowd and the pops climb a rising scale. Sweep!

Spare the fireflies. They drift out of the crease too, and a firefly that reaches your flowers replants a lost one.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

THE LIGHT IS YOUR AIM
• The phone's angle is where the light lands, smoothly, both ways. Open wider to chase a shadow outwards, close a little to bring the light back and meet the next one as it surfaces
• Shadows never stand still, so a light left in one place only gives each a short dose. Follow the big ones as they creep
• Quick pops build a chain, up to ×4. Three or more in one sweep is a Sweep, with a bonus
• Light held on a firefly too long makes it fizzle and breaks your chain. A quick pass over one is safe
• A shadow that reaches the edge eats a flower. Lose all five and the night wins

FIVE KINDS OF SHADOW
Murks creep. Wisps come in quick little flocks. Brutes are big, slow and grumpy, and have to be followed. Splitters pop into two wisps flung further out. Hoppers crouch and jump, and the first touch of light makes them hop at once.

30 SUNRISES, 3 WORLDS
Every level is one sunrise, from 35 seconds to a minute and a half, with shadows from the first second and the sun climbing in the mirror as the clock runs. At sunrise every shadow left melts away. Keep all five flowers, and from level 4 beat the level's score too, for three stars. Stars open the next world: the Meadow, the Rooftops and the Harbour, where it gets properly hard.

LONG NIGHT
Endless waves that never let up, and one best score to beat.

TODAY'S DAWN
One sunrise a day, the same for everyone. Your best of the day counts.

NO TUTORIAL TO SIT THROUGH
Level 1 teaches as you play, one line at a time: close the phone to start, open it to let the light in, light the shadows.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, hold it however you like, as a laptop or as a book: one half is the mirror, the other is the garden. Play lives between about a right angle and well open, so you never lay the phone flat or rush the hinge. Every sunrise starts with the phone shut, and shutting it mid-level pauses the game. In book pose, Settings can swap the halves. On any other iPhone, drag anywhere to aim the light, and a gold grip on a brass rail at the garden's edge follows it.

SOUND AND FEEL
A sizzle that swells with everything in the light, a bright pluck for every pop that climbs the scale as your chain grows, a chord for every Sweep, birdsong at sunrise. All synthesised live in the app. You feel the sizzle in your hands and a crisp tick for every pop. Sound, music, haptics and Reduce motion each have a setting.

GAME CENTER
Leaderboards for the Long Night, Today's Dawn and your total stars, and 10 achievements. Optional: Glint works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

### en-US (English U.S.)

Identical except one spelling: synthesised → synthesized (generated from the en-GB block by `build-metadata.js` checks, so the two can't drift: the script fails if anything else differs). "Harbour" stays, because it is the world's name in the game. Full text, ready to paste:

```
The top half of your iPhone Duo is a mirror.

Open the phone and the mirror catches the sunrise, throwing a band of warm light across the garden below. The wider you open it, the further the light reaches. Close it a little and the light comes back towards the crease. Shut the phone and it's dark.

Shadows seep out of the crease and creep towards your five flowers. Hold the light on one and it sizzles, shrinks and pops in a burst of gold sparks and petals. Sweep through a crowd and the pops climb a rising scale. Sweep!

Spare the fireflies. They drift out of the crease too, and a firefly that reaches your flowers replants a lost one.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

THE LIGHT IS YOUR AIM
• The phone's angle is where the light lands, smoothly, both ways. Open wider to chase a shadow outwards, close a little to bring the light back and meet the next one as it surfaces
• Shadows never stand still, so a light left in one place only gives each a short dose. Follow the big ones as they creep
• Quick pops build a chain, up to ×4. Three or more in one sweep is a Sweep, with a bonus
• Light held on a firefly too long makes it fizzle and breaks your chain. A quick pass over one is safe
• A shadow that reaches the edge eats a flower. Lose all five and the night wins

FIVE KINDS OF SHADOW
Murks creep. Wisps come in quick little flocks. Brutes are big, slow and grumpy, and have to be followed. Splitters pop into two wisps flung further out. Hoppers crouch and jump, and the first touch of light makes them hop at once.

30 SUNRISES, 3 WORLDS
Every level is one sunrise, from 35 seconds to a minute and a half, with shadows from the first second and the sun climbing in the mirror as the clock runs. At sunrise every shadow left melts away. Keep all five flowers, and from level 4 beat the level's score too, for three stars. Stars open the next world: the Meadow, the Rooftops and the Harbour, where it gets properly hard.

LONG NIGHT
Endless waves that never let up, and one best score to beat.

TODAY'S DAWN
One sunrise a day, the same for everyone. Your best of the day counts.

NO TUTORIAL TO SIT THROUGH
Level 1 teaches as you play, one line at a time: close the phone to start, open it to let the light in, light the shadows.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, hold it however you like, as a laptop or as a book: one half is the mirror, the other is the garden. Play lives between about a right angle and well open, so you never lay the phone flat or rush the hinge. Every sunrise starts with the phone shut, and shutting it mid-level pauses the game. In book pose, Settings can swap the halves. On any other iPhone, drag anywhere to aim the light, and a gold grip on a brass rail at the garden's edge follows it.

SOUND AND FEEL
A sizzle that swells with everything in the light, a bright pluck for every pop that climbs the scale as your chain grows, a chord for every Sweep, birdsong at sunrise. All synthesized live in the app. You feel the sizzle in your hands and a crisp tick for every pop. Sound, music, haptics and Reduce motion each have a setting.

GAME CENTER
Leaderboards for the Long Night, Today's Dawn and your total stars, and 10 achievements. Optional: Glint works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

Copy rules this text keeps:
- **Mirror first, reach second, pop third.** "The wider you open it, the further the light reaches" is in the first two lines: that's the difference from every other Duo game (and from Hush, which is about how *slowly* you open).
- **Duo first, then "plays on other iPhone models too"** (not "every iPhone": the deployment target is iOS 18). The drag control is described plainly in one sentence, after the fold. The store page may talk about the Duo; the *app* never shows a Duo line on a non-Duo iPhone.
- **No pose demand** (founder rule 2): "however you like, as a laptop or as a book". Never "hold it like a book" alone, never "lay it flat", never "catch them at the crease" (the R2 crease shade: the light does nothing right at the crease; shadows surface further out), never "close it fully" except the honest "every sunrise starts with the phone shut", which is the game's own rule 1.
- **Kind to the hinge** (rule 3): "between about a right angle and well open" is GAME-DESIGN §2's 80°–135°; "you never lay the phone flat or rush the hinge". No "fast", "quick snap" or "slam". "Quick" appears about the wisps and the pops, never about moving the phone.
- **Nothing is hurt.** Shadows "pop" into sparks and petals; flowers are "eaten" and come back as a firefly "replants" them; the level is lost with "the night wins". Never kill, die, burn or zap (keeps the 4+ honest, §8).
- **"iPhone Duo" is used only referentially**, never in the name, subtitle or keywords, and "iPhone" keeps its exact form even in a capitalised heading (Apple trademark guidelines).
- **Numbers are the design's, and only the design's** (to be ticked against `Glint/Core/Tuning.swift` and `LevelBook`): 5 flowers, 5 shadow kinds, chain to ×4, a Sweep at 3+, 30 levels in 3 worlds, 35–95 s per sunrise (levels 1–5: 35, 38, 42, 45, 50 s), three stars = five flowers plus the score target from level 4, 10 achievements, 3 leaderboards. If Core moves one, this text moves with it.

## 5. Keywords (limit 100 bytes, comma-separated, no spaces)

```
light,beam,sunrise,dawn,sunlight,reflect,firefly,flower,garden,glow,monster,arcade,foldable,hinge
```
**The byte count is printed by `build-metadata.js`** (must be ≤ 100), both locales.
- Nothing repeats the name or subtitle: glint, sun, mirror, catch, pop and shadows are already indexed from them (Apple matches plurals, so "shadow" is covered).
- "light" + "beam" catch "light beam game"; "sunrise", "dawn" and "sunlight" are the theme's searches; "reflect" catches "reflect light" puzzlers' fans; "firefly", "flower", "garden" and "glow" are what's on screen; "monster" catches "light vs monsters" (the shadows are cute critters, so "monster" is fair and honest).
- "arcade" is the subcategory word; "foldable" + "hinge" are the Duo-owners' searches, used by every sister game.
- Singular forms only. **No competitor names** (Porta Nubi, Lightfold, Epinaelo, Gleam), no Apple marks ("iPhone", "Duo"), no "Beam" as a brand claim.

Alternate set to A/B after 4 weeks of Search data (check the bytes first): `light,beam,sunrise,dawn,sunbeam,reflect,firefly,flower,garden,glow,critter,casual,foldable,hinge`. (Careful: Sunbeam is a trade mark in appliances; as a keyword it's a common word, but drop it if anyone objects.)

## 6. What's New

App Store Connect has no What's New field for an app's first version. Use the 1.0 line for TestFlight's "What to Test", press and social:
```
First light. Open your Duo to catch the sunrise and pop the shadows creeping from the crease. 30 sunrises in 3 worlds, the Long Night and Today's Dawn. Spare the fireflies.
```
Template for 1.0.1 (fill in only what actually shipped):
```
Smoother light on iPhone Duo, one real change here, and small fixes. Thanks for sparing all those fireflies.
```

## 7. Category

| Field | Choice | API value |
|---|---|---|
| Primary | **Games** | `GAMES` |
| Game subcategory 1 | **Arcade** | `GAMES_ARCADE` |
| Game subcategory 2 | **Casual** | `GAMES_CASUAL` |
| Secondary category | **Entertainment** | `ENTERTAINMENT` |

**Why:** Glint is an arcade game underneath: waves of enemies, a score chase with a chain multiplier, a Sweep bonus, stars per level and an endless mode. Casual is where paid one-input games chart, and its paid chart is shallow enough for a launch spike to show. Not Puzzle: nothing is solved, it's aim and timing. Entertainment (optional) catches "look what my phone does" browsers, the same choice as the sister games. **Apple dropped Arcade from its live list on 26 Oct 2026** (Brim run 40340641267; Swoop was filed as Casual + Action on 27 Oct), so the tool reads the live list and uses **Action** instead if Arcade is still missing (`fallbackSubcategories` in `asc-metadata.json`). If that happens the listing becomes Games: Action + Casual, which is also true of Glint.

## 8. Age rating: 4+

Answer the questionnaire exactly like this (App Store Connect → the app → App Information → Age Rating → Edit). **The tool sets it**; this table is for checking.

| Section | Item | Answer |
|---|---|---|
| In-app controls | Parental Controls | **No** |
| | Age Assurance | **No** |
| Capabilities | Unrestricted Web Access | **No** |
| | User-Generated Content | **No** |
| | Messaging and Chat | **No** |
| | Advertising | **No** |
| Mature themes | Profanity or Crude Humor | **None** |
| | Horror/Fear Themes | **None** |
| | Alcohol, Tobacco, or Drug Use or References | **None** |
| | Mature or Suggestive Themes | **None** |
| Medical or wellness | Medical or Treatment Information | **None** |
| | Health or Wellness Topics | **No** |
| Sexuality or nudity | Sexual Content or Nudity | **None** |
| | Graphic Sexual Content and Nudity | **None** |
| Violence | Cartoon or Fantasy Violence | **None** |
| | Realistic Violence | **None** |
| | Prolonged Graphic or Sadistic Realistic Violence | **None** |
| | Guns or Other Weapons | **None** |
| Chance-based activities | Simulated Gambling | **None** |
| | Contests | **None** |
| | Gambling | **No** |
| | Loot Boxes | **No** |
| Kids | Made for Kids | **No** |

**Expected result: 4+.** If the form you see has extra or renamed items, the honest answer to each is None or No.

Why each risky item is None:
- **Cartoon or Fantasy Violence: None, on one condition.** Sunlight making little ink blobs pop into gold sparks and petals is a light show, not a fight: nothing is hit, nothing bleeds, nothing is shown hurt, and the fireflies are only ever "fizzled" (a sad blip, then they're gone, never shown harmed). **The condition (Scene engineer, §11 ask 1):** the pop is sparks, petals and a ring, never a splat; a lit shadow "steams and shrinks" (GAME-DESIGN §10), it is never shown in pain; an eaten flower becomes a drooping stalk with a "chomp", no gore. If the final art reads as hurting a creature, the honest answer becomes **Infrequent/Mild** (9+, as Hush answered for its mimic's bite). Claude re-checks this on the release-candidate frames before the questionnaire is pushed, and tells the founder if it changes.
- **Horror/Fear:** the night garden is deep blue-teal warming to gold, and the shadows are wobbly, big-eyed and cheeky, not scary; nothing jumps out. A lost level is "the night won", gently worded. **Ask (Scene):** keep the glooms cute (big white eyes that squint and blink), no fangs, no screams.
- **Profanity or Crude Humor:** none; level titles are short and warm ("First Light", "Dew"). Claude reads all 30 titles against the build.
- **Simulated gambling / loot boxes:** no chance-based rewards and nothing to buy. Waves are seeded and scripted; Today's Dawn is the same sunrise for everyone.
- **Contests:** Game Center leaderboards are not prize contests.
- **Made for Kids: No.** The Kids category adds parental-gate rules and moves the app out of Games; Glint is for everyone, not built for under-11s specifically.

## 9. Other App Store Connect fields

| Field | Value |
|---|---|
| Price | Base country **United Kingdom, £1.99**; Apple equalises every other storefront (check the US shows **$1.99**). No launch discount |
| Availability | Every country or region **except China mainland and Vietnam** (paid games there need a government game licence) |
| Pre-order | **No** |
| Release | **Automatically release this version** as soon as App Review approves it (founder, 30 Oct 2026; §12) |
| Family Sharing | **On** (permanent once on) |
| Small Business Program | Account-level; already enrolled for Squish (just confirm it shows Active) |
| Copyright | `© 2026 pravegm` |
| Support URL | `https://pravegm.github.io/glint/support.html` |
| Marketing URL | `https://pravegm.github.io/glint/` |
| Privacy Policy URL | `https://pravegm.github.io/glint/privacy.html` |
| App Privacy | **Data Not Collected** (`privacy.md`) |
| Accessibility Nutrition Labels | **Differentiate Without Color Alone**, **Sufficient Contrast**, **Reduced Motion**, each only after its check passes, published on launch day (`accessibility.md`) |
| Content Rights | "Does your app contain, show, or access third-party content?" **No** (all art drawn in code, all sound synthesised, system fonts only) |
| Export compliance | Nothing to answer: `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` (already there) |
| Game Center | On; 3 leaderboards and 10 achievements, 435 points (`achievements.md`) |
| Sign-in required | **No** (there are no accounts; review notes open with "NO LOGIN") |
| SKU | `glint-2026` |
| Version | 1.0 (`MARKETING_VERSION` in `project.yml`) |

**About the three web addresses.** GitHub Pages serves the repo's `docs/` folder at `https://pravegm.github.io/glint/` once Pages is on (runbook §0). The real pages are in `docs/site/`. `docs/index.html`, `docs/support.html` and `docs/privacy.html` are tiny forwarding pages, so the short addresses above work. If a reviewer or tool ever objects to the forward, use the direct addresses: `https://pravegm.github.io/glint/site/`, `…/site/support.html`, `…/site/privacy.html`.

## 10. Claims, and the code that makes each one true

**Code: not written yet** (28 Oct). Tick **Code** when Round 1 compiles and the source says exactly what the copy says; tick **RC** on the build that is submitted. If a line is false, change the copy here, in `review-notes.md`, the site and the press kit, never the build to match the words.

| Claim (where) | Source in the code (expected) | Code | RC |
|---|---|---|---|
| The angle is the light: shut = dark; crease glow from about 15°; the band lifts out at about 80° and reaches the flower edge at about 135°; continuous both ways, no steps (description, promo, review notes, site) | `Tuning.band(angle:)`, `creaseGlow(angle:)`, `shutAngle`; `HingeMirrorSource` (predictor + One-Euro) | [ ] | [ ] |
| "Between about a right angle and well open"; never flat; opening further than ~135° changes nothing | GAME-DESIGN §3 table; `Tuning.band(angle:)` clamps at 1 | [ ] | [ ] |
| Every sunrise starts shut: "Close the phone to start", then "Open the phone to let the light in" (Duo only) | `GameController` level flow (ROUND-1 App 3) | [ ] exact labels | [ ] |
| Shutting mid-level pauses (≤ 15° for 0.25 s); the cover display shows "Paused · open the phone to carry on" and the score; resume at ≥ 25° with 0.6 s grace | `Tuning.shutDwell`, `CoverView`, pause rules (GAME-DESIGN §8) | [ ] | [ ] |
| No pause or warning near 90° | GAME-DESIGN §8; no hint keyed to an angle in 60°–120° | [ ] | [ ] |
| Any pose: laptop or book; Settings "Swap halves" (shown in book pose only) | `GardenLayout.make(size:isDuo:swapHalves:)`, `SettingsStore` | [ ] exact label | [ ] |
| Other iPhones: drag anywhere (relative), a gold grip on a brass rail at the garden's edge follows the light; "Drag down to let the light in" / "Drag to aim the light" | `DragMirrorSource`, the R3 rail and grip (`GardenScene`), hint copy | [ ] exact labels | [ ] |
| Five flowers are the lives; a shadow at the edge eats the flower in its lane (else the nearest); all five gone = "the night wins" | `Tuning.flowerCount` 5, `DawnSession` eating rule, `.nightWins` | [ ] | [ ] |
| Five shadow kinds with the behaviours named (murk creeps; wisps in flocks; brutes big and slow; splitters pop into two wisps flung out; hoppers hop, skittish at first light) | `GloomKind`, `Tuning` kind table (GAME-DESIGN §4) | [ ] | [ ] |
| "Shadows never stand still" (a parked light only gives a short dose) | `DawnSession`: glooms keep moving in light | [ ] | [ ] |
| Chain: pops within 1.6 s; multiplier up to ×4; Sweep at 3+ pops within 0.35 s with a bonus | `Tuning.chainWindow`, `chainCap`, `sweepWindow`; `.swept` | [ ] | [ ] |
| Fireflies: light held too long fizzles one and breaks the chain; a quick pass is safe; one that reaches the flowers replants a lost flower (or blooms for points) | `Tuning.fireflyScorch*`, `.fireflyScorched`, `.fireflyDelivered(replanted:)` | [ ] | [ ] |
| 30 levels in 3 worlds named Meadow, Rooftops, Harbour; "from 35 seconds to a minute and a half" (35–95 s; L1–5 35/38/42/45/50 s), shadows from the first second; the sun rises in the mirror; at sunrise every shadow left melts away | `LevelBook.count` 30, world names, durations; `snapshot.sun`; `.sunrise` | [ ] | [ ] |
| Stars by flowers kept (5 = ★★★, 3–4 = ★★, 1–2 = ★), and from level 4 ★★★ also needs the level's score target; stars open the next world | `DawnSession.stars(flowersLeft:score:starScore:)` (L4 2,150 … L30 9,050), unlock rules (GAME-DESIGN §6) | [ ] | [ ] |
| "Properly hard" by the Harbour | `BalanceTests` `GLINT-BAL`: world-3 levels cost a decent pilot 1–2 flowers (ROUND-1 Core 3) | [ ] | [ ] |
| Long Night: endless, escalating, one best score | `PlayMode.endless`, `DawnSession` endless waves | [ ] | [ ] |
| Today's Dawn: one seeded sunrise a day, the same for everyone, best of the day kept; a new one at 00:00 UTC | `LevelBook.daily(day:)`, `DailySeed.day(for:)` (UTC) | [ ] | [ ] |
| No forced tutorial; Level 1 teaches one line at a time ("Light the shadows") | `HintID`, App hint lines (GAME-DESIGN §7) | [ ] exact labels | [ ] |
| Sound: sizzle, pentatonic pop ladder, Sweep chord, birdsong at sunrise; all synthesised; sizzle haptic + pop ticks | `Feedback/` (no audio files in the bundle) | [ ] | [ ] |
| Settings: Sound, Music, Haptics, Swap halves, Reduce motion; sound plays with the silent switch on | `SettingsStore`, `UI/SettingsView.swift`; `.playback` | [ ] exact labels | [ ] |
| 3 leaderboards + 10 achievements report from the build | `App/GameCenterManager.swift`, `Core/Achievements.swift` = `achievements.md` | [ ] | [ ] |
| No network code, no SDKs, no tracking | `privacy.md` §3 grep | [ ] | [ ] |

## 11. Asks to the build team (so the store copy stays true)

| # | Owner | Ask | Why |
|---|---|---|---|
| 1 | Scene | A pop is gold sparks, petals and a ring, never a splat; lit shadows steam and shrink, never shown in pain; an eaten flower is a drooping stalk. Glooms stay cute (big eyes, no fangs) | Keeps the honest age rating at 4+ (§8) |
| 2 | Core + App | Keep these exact ids: leaderboards `glint.endless`, `glint.daily`, `glint.stars`; achievements exactly as `achievements.md` (`Achievements.all` in `Glint/Core/Achievements.swift`, `def("<key>", …)` → `glint.ach.<key>`) | Game Center ids are permanent once created; the tool cross-checks the code |
| 3 | Core | Today's Dawn runs on the UTC date (`DailySeed.day(for:)` already says "days since 2026-01-01 UTC": keep it) | Game Center's recurring board resets at one UTC moment for everyone |
| 4 | App | Exact labels the copy quotes: "Long Night", "Today's Dawn", "Meadow", "Rooftops", "Harbour", "Close the phone to start", "Open the phone to let the light in", "Light the shadows", "Follow the big ones", "Spare the fireflies", "Drag down to let the light in", "Drag to aim the light", "Sweep!", "The night won", "Paused · open the phone to carry on", "Open the phone to play", Settings "Sound", "Music", "Haptics", "Swap halves", "Reduce motion". If a label changes, tell the launch lead | The review notes, runbook and support page quote them |
| 5 | App | Game Center banners queue until the Results card, never mid-level | A banner over the garden hides shadows |
| 6 | App | The demo key `screen=badges`: render the 10 achievement badges (`achievements.md` "Images") into `Documents/badges/<id>.png`, 1024 × 1024, opaque, and log `GLINT-T badges done 10`; plus a `badges` line in `ci/scenarios.txt` | The App Store Connect tool uploads them; without them Game Center can't be saved |
| 7 | CI | **Done (28 Oct):** the App Store screenshots pipeline is ported (`store.yml`, manual only; portrait iPhone sets, a book-pose Duo set, frame 1 the book composite drawn at the angle matching its light: `screenshots.md`) | The tool's `screenshots` step needs a clean store run |
| 8 | Design (founder) | Reduce motion should default to the iOS setting (`UIAccessibility.isReduceMotionEnabled`) | So the Reduced Motion label is honest without a visit to Settings (`accessibility.md`) |

## 12. Launch date

**Tue 15 Dec 2026, about 08:00 UK, released by the founder (manual release).** Brim launches Tue 17 Nov, Hush Tue 1 Dec and Snapjaw Tue 8 Dec; Glint takes the next free week (Tue 15 – Mon 21 Dec), so every game keeps its own week of news and its own featuring slot. It lands a week before the App Store's Christmas lull, while people are still buying games for new phones. Seven weeks out leaves room for two or three real-Duo tuning rounds (the light's lag and smoothing, level 1's clarity and the pop cascade can only be judged on the Duo) and Apple's 3 weeks' featuring notice (**nomination by Mon 23 Nov**). **Submit Wed 9 Dec** (the day after Snapjaw's launch; last safe day Fri 11 Dec).

**Watch out:** Snapjaw's kit names **Tue 15 Dec as Hush's fallback** date. If Hush slips to 15 Dec, Glint moves; and Snapjaw's own fallback is Tue 12 Jan 2027. **Glint's fallback: Tue 19 Jan 2027** (if 1.0 isn't submitted by Fri 11 Dec, or if Hush takes 15 Dec), never the Christmas weeks. If the founder would rather release on approval, the only rule is that it must not go live in Snapjaw's week (8–14 Dec).

## Sources
- Snapjaw's metadata (structure, copy rules, category fallback, claims table): `C:\Users\59527\Trap\docs\appstore\metadata.md`
- `research/01-market.md` (the name check, Glint Pay, the subtitle, "lead with reach")
- `design/GAME-DESIGN.md` (what the game is, and its words)
- Apple, *Age ratings values and definitions*: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- App Review Guidelines 2.3.7 (metadata): https://developer.apple.com/app-store/review/guidelines/
