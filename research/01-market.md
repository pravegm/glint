# Glint: market, collision and name research (01)

Researched 28 Oct 2026. Builds on the earlier studio research in `Lid/research/01-market.md`, `Trap/research/01-market.md` and `Wing/research/01-market.md`.

New sources checked:
- foldhunt.com: the full /iphone-duo/ index (~130 entries) and its games list
- duodiscover.com: the games category
- iThinkDiff, Notebookcheck, TechCrunch and Axios Duo coverage
- App Store listings
- web searches by name

Limits:
- PhoneArena's roundup returned a 403 error and Tom's Guide's top-15 page came back truncated.
- No indexed r/iPhoneDuo thread was found.
- Items marked [unverified] come from search snippets only.

## TL;DR
- **Glint is open on Duo.** No Duo app uses the hinge to aim light, a mirror or a beam.
  - The two "light" Duo games are tile and light-path puzzles. In both, the fold only changes the layout or view.
  - Off-Duo, "reflect sunlight onto monsters" exists only as small iPad/PC puzzlers (Epinaelo, Gleam: Last Light). None uses a hinge.
- **Drawbridge (C) is also open on Duo.** Its only precedents are two small touch games (2010 and 2020).
- **Puppet (B) is crowded for us.** ChompDuo, Fold Smasher and our own Snapjaw already own "phone = mouth", and accordion apps own "fold to the beat".
- **Name: "Glint"**, store name **"Glint: Sun Mirror"**, subtitle **"Tilt the sun. Pop the shadows."** (30 chars).
  - Fallback: **Dawnlight**.
  - Avoid: Sunbeam, Daybreak, Lumo, Beam and Shine.
- **Side finding for Hush:** a new Duo chest game, **Questionable Loot**, has a lid that follows the hinge. Details are in section 2.

## 1. Light, mirror, beam and searchlight prior art

### On iPhone Duo (none aims light with the hinge)
| App | What the hinge does | Date / price | Overlap |
|---|---|---|---|
| **Porta Nubi: Immersive Puzzles** (Michael Temper) [apps.apple.com/us/app/id6503628155](https://apps.apple.com/us/app/porta-nubi-immersive-puzzles/id6503628155) | Light-path puzzle with mirrors, portals and prisms. Closing the phone enters a cloud, opening it exits, and half-folded shows virtual sticks. The hinge is a view switch. | Listed 15 Oct; v4.0.2 on 22 Oct; price not seen | Low: same theme, no aiming |
| **Lightfold Puzzle** (Mohammed Ridha) [id6821920462](https://apps.apple.com/us/app/lightfold-puzzle/id6821920462) | Tap tiles to route light to a ring. When open, the board sits on one half. The hinge sets layout only. | 16 Oct 2026; price not seen | Low; its name is close to "Glint/light" |
| **Foldlight: Cosmic Courier** (foldhunt) | "Fold and turn to choose a route" | Oct 2026 [unverified detail] | Low |
| **Fold Match** | Mirror-the-shape puzzle | Oct 2026 | None (a symmetry puzzle, not light) |
| **Saura** (Bitrig hackathon prototype) | One half acts as a beauty mirror (a camera feed) | Prototype, not released | None |
| **SolarWatch**, **Red Light For Your Eyes**, **Light Noise** | Utilities: a sundial whose tiles move off the crease, red-light therapy that starts on unfold, a reading light in tent pose | Utilities | None |

Sources: [foldhunt index](https://foldhunt.com/iphone-duo/), [Porta Nubi page](https://foldhunt.com/games/porta-nubi/), [Lightfold page](https://foldhunt.com/games/lightfold-puzzle/), [Notebookcheck](https://www.notebookcheck.net/Made-for-iPhone-Duo-These-apps-show-what-Apple-s-foldable-can-do.1416967.0.html)

### Off-Duo (no hinge): closest to "sunlight pops shadows"
- **Epinaelo** (iPad game, [id6444372362](https://apps.apple.com/us/app/epinaelo/id6444372362)): bounce sunlight through mirrors onto vampires. This is the closest fantasy match. The US page returned 404 on 28 Oct, so it may be delisted [unverified].
- **Gleam: Last Light** (Hiker Games, [id1124381015](https://apps.apple.com/us/app/-/id1124381015)): angle reflective gems to bring sunlight to the last plant. Free with IAP, July 2016, 3 ratings, abandoned.
- **Towaga: Among Shadows** (Sunny Peak, 2020): shoot a light beam to burn shadow hordes around a tower. $14.99 on console/PC; it was earlier on iOS.
- **Light My Fear** (iOS): spin a torch to beat dark enemies.
- **Wildwood: Graveyard Defense** (iOS): a flashlight makes ghosts vanish.
- **Night in the Garden** (itch.io, PC): shine a flashlight on garden monsters.
- **Mirror and laser puzzlers**: God of Light, Beams, Hex Beam, Beam Riddle, Lyxo, Light Stream. These are routing puzzles, not action.
- **MacBook lid-angle hacks** (Sam Henri Gold's LidAngleSensor, 2025): creaky door, theremin, and a Dino-runner controller. None uses light.

**Read:** the light-versus-shadow theme is familiar and readable, but the mechanic is new: the phone's own lid is the mirror, and the opening angle sets how far the light reaches.

### Duo games that use the hinge angle as a continuous aim or position control
- **Uphill**: the lane slope follows the hinge.
- **Obtuse** and **Duometry** ($2.99): match a target angle.
- **Valley Run** ($0.99, "Fold to Fly"): folding pumps a marble swing.
- **FoldFling**: bend the phone to charge a catapult.
- **Exactly Half**: line up the cut, then close the phone to chop.
- **Foldfish** (free + IAP): unfolding sets the cast.
- **Fold: Gravity Puzzle**: the play area widens as the phone opens.
- **Questionable Loot**: the lid follows the hinge.
- **Paper-folding apps**: kami, PureOrigami, Duo Cut, Hingami.
- **Accordions**: Fold Accordion ($2.99), Foldissimo, Accorduon, Foldeon, DuoBox, Bellowsby.

**None of these maps the angle to the reach of an effect against moving enemies.** Glint's verb (open wider = light reaches further) is unclaimed.

Design note: the Duo hinge holds friction between **15° and 145°** ([iThinkDiff](https://www.ithinkdiff.com/apples-hardware-chief-says-the-iphone-duos-hinge-was-the-hardest-problem-to-solve/)). The light band should therefore map onto roughly 15–145°. That matches the "closed = no light" rule, and the player never needs to go flat (which also avoids the known fold-from-flat blur).

### Lip-sync puppet and drawbridge
- **Puppet:**
  - No lip-sync puppet hinge app was found on any platform.
  - Adjacent apps:
    - **ChompDuo** (free, $0.99 IAP, 19 Oct): the jaws track the hinge, as a toy.
    - **Fold Smasher** (free + IAP, about 23 Oct).
    - **FoldAhhh**: fold to squeal.
    - Our own **Snapjaw**.
  - Rhythm via the hinge already exists in **Fold Accordion**'s Learn mode, and **AngleBeat** sets tempo from the opening angle.
  - Touch-only lip-sync apps: MouthOff and Sock Puppets (old).
- **Drawbridge:**
  - Nothing exists on Duo or on Android foldables.
  - **Raise That Bridge** (jrs0ul, Dec 2010): raise and lower a castle drawbridge to let friendly soldiers in and crush enemies ([TouchArcade thread](https://toucharcade.com/community/threads/raise-that-bridge-coming-this-december.74191/)).
  - **BUDE'S TOWER** (Hideki Kubo, $0.99, May 2020): "lower the drawbridge to get only your friend Piyon into the tower" ([id1514709132](https://apps.apple.com/us/app/id1514709132)).
  - The "Draw Bridge" titles are line-drawing puzzles.

## 2. Duo hinge games, Oct 2026 (what to avoid duplicating)
| Game | Hinge mechanic | Price |
|---|---|---|
| Fold Smasher | Snap shut on bugs moving across both halves | Free + IAP |
| Foldfish | Unfold to cast, hold to reel | Free + IAP |
| ChompDuo | Inner screen is a mouth; folding bites (toy) | Free + $0.99 |
| **Questionable Loot** (Abiem LLC, NEW) | Treasure chest; the lid follows a slow unfold so you can peek; key every 8 h. **Not on the App Store when checked on 28 Oct**; no mimic mentioned. | Free, no ads/IAP |
| Keep It Shut | Horror; crack the "door" open to peek | ? |
| Toastie / WaffleKing / Exactly Half | Close to toast / bake / chop | ? |
| Duometry / Obtuse | Match an angle by feel | $2.99 / ? |
| Valley Run | Fold timing pumps a marble swing ("Fold to Fly") | $0.99 |
| Uphill / Marbles Unhinged / Fold: Gravity Puzzle | The hinge tilts the slope or floor | ? |
| FoldFling | Bend to charge, open to launch | ? |
| NEOFOLD | Fold switches mode (brick breaker, pinball, duel) | ? |
| Porta Nubi / Lightfold / Foldlight | Light puzzles; the fold changes view or route | ? |
| Fold Party | 16 party games (Safe Cracker = hinge as a dial) | ? |
| Paper & Grain, Orisuji ($4.99), Hingami, kami, Duo Cut, PureOrigami, Foldink | Paper folds with the phone | mixed |
| Tensei Mahō Shōjo | Close to block, open to cast | ? |
| Foldtales | Pop-up book | ? |
| Penalty Area: Face2Face | Fold to about 90° for keeper perspective | ? |
| PianoFold | Rhythm tiles in laptop pose | ? |
| Fold Accordion ($2.99), Foldissimo, Accorduon, Foldeon, DuoBox, Bellowsby | The hinge is the bellows | mixed |
| Two Fold, Foldplay, Battlefleet/FleetFold/Peekaboard/Torpedo | Pose or split-screen, not a hinge control | mixed |

No new hinge game is dated 24–28 Oct on foldhunt; its latest checks there were utilities.
Our own games: Squish, Brim, Swoop, Hush and Snapjaw.

## 3. Verdicts
| Concept | Verdict | Why |
|---|---|---|
| **Glint** (lid = mirror, opening throws light) | **UNIQUE** | No hinge-aimed light anywhere. The theme has light precedent (Epinaelo, Towaga), but none uses a fold. The risk is pose overlap with Hush (tabletop, opening slowly); see the note below. |
| B: lip-sync puppet | **CROWDED (for us)** | The mouth-on-hinge is ChompDuo, Snapjaw and Fold Smasher. Fold-to-the-beat is Fold Accordion, Foldissimo and AngleBeat. It would read as "Snapjaw with music". |
| C: drawbridge traffic | **UNIQUE on Duo** | Only Raise That Bridge (2010) and Bude's Tower (2020) exist, both touch-only. It is a clean second choice. |

**Glint positioning (one line):** *"Your phone is a mirror: open it to catch the sun and sweep light across the garden, popping shadow critters crawling from the crease, but don't wake the owls."*

Lead with **reach**, not stealth, to separate it from Hush. Glint is about how far you open (the angle is the aim). Hush is about how slowly you open.

## 4. Name check
| Name | Exact-name App Store app? | Prominence | Verdict |
|---|---|---|---|
| **Glint** | "Glint" game (Ensomniac, 2014, join-the-dots), probably delisted. **"Glint \| Buy Gold Instantly"** is a UK FCA fintech (Glint Pay Services Ltd). Also Glintfall and Glintstorm (games) and Microsoft's Viva Glint (HR). | Fintech: medium in the UK, Finance category | **Best fit.** A glint is literally light flashed off a mirror. TM risk is low to medium (different class and category). Use a compound store name. |
| Gleam | **Gleam: Last Light** (2016, *reflect sunlight to a plant*), Gleam of Fire ($3.99), Gleam.io, the Gleam programming language | Low each, but the theme clashes | Avoid: near-identical theme |
| Sunbeam | **Sunbeam: UV Index** (about 1.6K ratings); **Sunbeam** is a major appliance trademark (Newell) | High | **Avoid (TM)** |
| Dawnlight | Only "DawnLight - Sunrise Alarm" (productivity). Dawnfolk (2026, a light-versus-shadows city builder) is adjacent. | Low | **Cleanest for games**; longer and softer |
| Lumo | **Lumo by Proton** (AI, prominent), Kumo Lumo, Lumo's Cat, Lumo Stars, and the 2016 console game LUMO | High | **Avoid (TM / crowded)** |
| Shine | **SHINE - Journey Of Light** ($3.99, a *light and shadow* game), The Shine, Shine (Blueshift) | Medium | Avoid: same theme, crowded |
| Glimmer | Glimmer: Interactive Fanfics (about 1.2K ratings), Glimmer Studios, Glimmer: Baby Sensory, Glimmer (Switch) | Medium | Avoid: crowded |
| Beam | No exact game, but Beams, Hex Beam, Beam Riddle and Beam Hero are all light puzzles; Beam Suntory TM | Medium | Avoid: generic, can't be searched |
| Daybreak | **Order Daybreak** (Neocraft ARPG); **Daybreak Game Company** (EverQuest) holds a games trademark | High | **Avoid (TM)** |
| Brighten | No game; photo apps (Brighten Me, Brighten A Dark Photo) | Low | Clean but bland, and reads like a photo tool |

**Recommendation:** brand **Glint**, App Store name **"Glint: Sun Mirror"**.
- A compound name sidesteps the exact-name clash with "Glint" and avoids looking like Glint Pay.
- Subtitle: **"Tilt the sun. Pop the shadows."** (30 characters).
- Alternative subtitle: **"Catch the sun. Spare the owls."** (30 characters).
- Fallback name: **Dawnlight**, as "Dawnlight: Sun Mirror".
- Neither subtitle uses "Fold to …" or "Open to …".
- Reserve the name in App Store Connect early. Name uniqueness there is the only authoritative test, and a quick UK IPO search for "GLINT" in class 9/41 is worth doing.
