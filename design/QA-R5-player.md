# QA R5: player play-through by reading (Thu 29 Oct)

*Read-only QA of the R4 tree. Sources: `Glint/App`, `Glint/UI`, `Core/DawnSession.swift`, `Core/Tuning.swift`,
`docs/appstore/metadata.md`; frames `artifacts/r4/screenshots` (iPhone 18 Pro sim) and `artifacts/duo3/duo-screens`
(Duo sim, previous build). P0 = stuck / false / broken, P1 = confusing / visible bug, P2 = polish.*

## 1. Walk-through: iPhone Duo, first launch, held open
1. Launch: `looksLikeDuoInner` (AppRules.swift:236) gives the split layout before any hinge report. Home: title on the
   mirror, controls on the garden (frame 03). The attract light follows the real hinge (GameController.swift:744).
2. Play → `play(.level(1))` (GameController.swift:450). The phone is open → stage `.closeFirst`, card "Close the phone
   to start" (AppRules.swift:37, 287). No session, no clock. Good.
3. Shut ≤ 15° for 0.25 s → `beginSession` (GameController.swift:651); the cover says "Open the phone" (AppRules.swift:72).
   After 3 s the cover also offers "Already open? Show the game" on a phone that IS shut (CoverView.swift:60; duo3 02).
4. Open: the inner display shows "Open the phone to let the light in" until the band moves (θ ≈ 70°, Tuning.swift:31,
   DawnSession.swift:263). Light only works from θ ≈ 87° (`creaseShade` 0.12, Tuning.swift:43).
5. Level 1: "Light the shadows." waits for a surfaced murk (AppRules.swift:455), 12 s max. Win → 2.2 s → Results
   (GameController.swift:792). "Next sunrise" → `play(.level(2))` → "Close the phone to start" again (rule 1, OK).
6. L2 (one brute) "Follow the big ones.", L3 wisps (no hint), L4 "Spare the fireflies.", L5 two brutes. Every Retry,
   Next and Restart asks for the shut first.

## 2. Findings
| # | Sev | Where | Scenario | Fix |
|---|---|---|---|---|
| 1 | P0 | metadata.md:78, 128 | Store: "Keep all five flowers for three stars." Since R3, ★★★ also needs the score target (DawnSession.swift:235; L4+ have `starScore`). False claim (rule 7). | "Keep all five flowers and beat the target score for three stars." Also fix §10 row. |
| 2 | P0 | GameController.swift:177, AppRules.swift:244, PauseView.swift:41 | A Duo whose hinge never reports (API nil, iOS < 27.1): isDuo is true from the window shape, so the split layout plays by drag. The pause card says "Closing the phone pauses too", which is false. Shutting doesn't pause (`hingeSeen` is false, so no cover view), and the level keeps running on the outer display while flowers are eaten. | Show the Duo line only when `hingeDriven`. When the window shrinks to cover size mid-level without a hinge, set `pause.inactive` (or menu). |
| 3 | P0 | duo3/checks.txt | PAUSE-SHUT FAIL: level 8 was lost before the shut step (app.txt: nightWins at band 0.25), so shut-pause has never passed on the Duo sim. The store and review notes promise it. | Run the shut step on L1 (or `ignore=` an immortal fixture) before the band steps; gate submission on PASS. |
| 4 | P1 | CoverView.swift:60 | On a genuinely shut phone the cover says "Already open? Show the game" (a prompt that contradicts the phone). Tapping it draws Home / the HUD on the small outer display. | Offer it only when the hinge angle is ≥ 25° or unknown. Else hide it. |
| 5 | P1 | AppRules.swift:73, PauseView.swift:42 | Pause-menu pause, then shut: cover "Paused · open the phone to carry on", and the menu says "Open it to carry on". Opening lands on the pause menu, not play. | Cover for a menu pause: "Paused · tap Resume when you open the phone". Menu line: "Closing the phone pauses too." |
| 6 | P1 | PlayHUD.swift:49, frame 15 | Today's Dawn date chip overlaps the score pill's lower-right corner (~27 pt) and the sun. | Put the chip under the pill's row by its real rect, or centre it between the pill and pause on the same row. |
| 7 | P1 | HomeView.swift:21, frames 03 + duo3 ui-home | Duo Home: the tagline starts at the region edge, over the mirror's brass frame. "Glint" sits on the sun disc and clouds (caption says clear of the sun). | Inset `secondary` by `mirrorFrameThickness + 12`. Centre the title block or move the sun. |
| 8 | P1 | GardenScene.swift:990, Achievements.swift:34 | Floating "×7…×13" shows the chain COUNT. The multiplier caps at ×4 and the store / badge say "x4 chain". The player sees ×13 and then reads "reach ×4". | Float the multiplier ("×2.5") or "Chain 7". Badge: "Reach a ×4 multiplier (13 pops in a row)." |
| 9 | P1 | frames 14, 15, 10 | Submerged glooms under the band still show bright eyes and a full body (rows of eyes in 15). The light does nothing to them, so it reads like a bug. | Dim eyes to slits / 30 % and hide the bodies below soil. |
| 10 | P1 | AboutView.swift:35–39 | On a non-Duo iPhone: "Made for iPhone Duo… Open it to catch the sunrise". The store rule (metadata.md:154) says the app never shows a Duo line on other iPhones. | Phones: "Drag anywhere to aim the light…" (see copy list). |
| 11 | P1 | metadata.md:90, frames 05/06 | Store: "a brass lever on the mirror follows your finger". The lever is a rail on the garden's right edge. Its grip overlaps the mirror frame's corner bolt and lane 5. | Fix the copy ("a brass lever beside the garden") or move the rail onto the mirror. Keep it off the bolt. |
| 12 | P1 | project.yml / ASC | iPhone apps are offered on Apple-silicon Macs by default. A resized Mac window ≥ 600 pt and squarish trips `looksLikeDuoInner`: split layout, no lever, "Closing the phone pauses too", Swap halves shown. | Untick Mac availability in ASC. Require `hingeSeen` or a Duo model id for the Duo copy (#2). |
| 13 | P1 | ci/scenarios.txt | No frames on iPhone SE (375×667), Pro Max, or any landscape phone. Landscape phones: Home's Play falls below the fold (SplitMenu scrolls, Theme.swift:150). The garden is ~250 pt and the prompt card is near its max height. | Add SE, Pro Max and landscape scenarios. In landscape, put Home in two columns. |
| 14 | P2 | AppRules.swift:72 | Cover at a level start: "Open the phone" (bare). | "Open the phone to start". |
| 15 | P2 | Tuning.swift:22, 43 | Resume at 25°, but no light can work until ~87°. After every reopen, glooms walk ~0.5–1 s with nothing the player can do. | Resume grace until the band is out (θ ≥ creaseAngle) or 1.5 s, whichever first. |
| 16 | P2 | GameController.swift:479 | Stage `.checking`: up to 1.5 s with an empty garden and no card (phone within 2 s of launch; Duo relaunch before a report). | Show "Close the phone to start" as soon as `hingeSeen`, or a soft "…" card. |
| 17 | P2 | PlayHUD.swift:64 | Hint plate is an opaque gold capsule at the field's centre (12 s on L1, frame 19). It hides glooms in the busiest strip. | 85 % opacity, and move it to d ≈ 0.7 when a gloom is under it. |
| 18 | P2 | HintRules (AppRules.swift:174), LevelBook L3 | Wisps first appear on L3 with no line. They are the quickest kind. | Add `.wisps`: "Wisps come in flocks. Sweep them in one pass." |
| 19 | P2 | GameController.swift:799 + GardenScene.swift:1066 | "Wave n" is drawn twice at once: the HUD banner on the mirror and the scene label on the garden. | Keep one (the garden label). |
| 20 | P2 | ResultsView.swift:47 | A lost Today's Dawn and every Long Night end show "The night is over", which reads like a win. | Both: "The night won". |
| 21 | P2 | ResultsView, PauseView | Restart / Retry / Try again / Play again / Again for one action. | "Retry" everywhere ("Play again" after the last level). |
| 22 | P2 | HomeView.swift:84, ProgressStore.swift:198 | Long Night card says "Win level 5", but it also opens a day after first launch, with no unlock note when it does. | "Win level 5 or come back tomorrow". Toast "Long Night is open" on first sight. |
| 23 | P2 | AppRules.swift:520, frame 04b | Locked world tab "🔒 ★ 20" doesn't say 20 of what. | "★ 20 in Rooftops" or "Needs ★ 20". |
| 24 | P2 | PauseView.swift | No Settings from pause: you can't mute or turn off haptics mid-level without quitting. | Add sound and haptics toggles to the pause card. |
| 25 | P2 | SettingsView.swift:34, RootView.swift:53 | Duo: toggling Swap halves moves the whole Settings card to the other half under the thumb. | Delay the swap until the player leaves Settings, or animate with a one-line note. |
| 26 | P2 | PlayHUD.swift:231 | "Close the phone" drawing is a laptop hinge even in book pose (duo3 01). | Rotate the art with `layout.foldVertical`. |
| 27 | P2 | frame 06 | L1 at 14 s shows an empty garden (caption promises a sizzling murk). The band is a faint smear in the crease shade. Weak first impression for a store frame. | Pick t where a murk is lit. Raise the band's contrast when d < creaseShade. |
| 28 | P2 | duo3 ui-results (prev. build) | Duo Results card covers the brass frame top and left. Achievement chips are cut at the screen edge. | Re-shoot on R4 Duo. Inset the card by the frame thickness. |
| 29 | P2 | frame 24 | "Paused · open the phone to / carry on" breaks badly. | Two lines: "Paused" / "Open the phone to carry on". |
| 30 | P2 | ResultsView.swift:89, frame duo3 07 | "New best!" pill on "The night won". | On a loss show "Best 2,100" in plain text, no pill. |

## 3. Non-Duo fallback (regular iPhone, drag)
- **First launch:** `isDuo` false (no hinge, phone window), Home spread layout (frame 01). If Play is tapped within 2 s
  of launch, there are up to 1.5 s of silence (`.checking`, #16). Otherwise `beginSession` straight away.
- **Prompts:** only `.drag` ("Drag down to let the light in", AppRules.swift:290). `.closeToStart` and `.openToLight`
  need `hingeDriven`, so a phone never gets them. Hints and tips never mention a phone or a hinge. OK. Only the About
  text breaks the rule (#10).
- **Level start:** the band starts hidden (−0.2), and the clock starts after a 0.02 nudge (DawnSession.swift:263). Drag
  is relative, anywhere, capped at 1.4 d/s. Works the same in all four orientations (`dragDirection`).
- **Pause:** the pause button is always there, top-right of the mirror (frame 05). Backgrounding sets `inactive` and
  returns to the pause menu (AppRules.swift:154). Control Centre and notifications (inactive only) resume after 0.6 s
  grace. Shut pause can't fire (`hingeDriven` false, AppRules.swift:117). OK.
- **Cover paths:** `isCover` needs `hingeSeen` (AppRules.swift:250). `ShutCard` needs `pause.shut`. Neither can fire on
  a phone. OK.
- **Swap halves:** hidden (`swapAllowed` needs isDuo + landscape, frame 16). OK. The lever shows (`showsLever`).
- **Store copy:** "Plays on other iPhone models too… drag anywhere" is true. The lever location is wrong (#11). The
  three-star line is false on every device (#1).
- **SE 375×667:** compact type and a 280 pt mirror. Fits by arithmetic, but no frame (#13). **Pro Max landscape
  932×430:** single column that scrolls. Play is below the fold (#13).
- **iPad (compatibility):** an iPhone-sized window and `TARGETED_DEVICE_FAMILY 1`, so the layout is a phone. No haptics
  (fine). **Mac (Apple silicon):** see #12. Mouse drag works. Untick Mac availability.
- **Duo with no hinge reports:** drag on the split layout with no lever, no cover view and no shut pause, plus a false
  pause line (#2). Make every Duo-only line and behaviour depend on `hinge.hasHinge`, not on the window shape.

## 4. Copy changes (old → new)
- AboutView: "Made for iPhone Duo" → (phones) "Plays best on iPhone Duo"
- AboutView: "The top half of your phone is a mirror. Open it to catch the sunrise… On other iPhones, drag to aim the
  light." → Duo: "One half of your phone is a mirror. Open it to catch the sunrise and pop the shadows creeping out of
  the crease." / Phone: "The mirror catches the sunrise. Drag anywhere to aim the light and pop the shadows creeping out
  of the crease."
- CoverLine.openToStart: "Open the phone" → "Open the phone to start"
- CoverLine.paused (menu pause): "Paused · open the phone to carry on" → "Paused · open the phone, then tap Resume"
- PauseView: "Closing the phone pauses too. Open it to carry on." → "Closing the phone pauses too." (only when hingeDriven)
- CoverView: "Already open? Show the game" → keep, but only when the hinge isn't reading shut
- ResultsView: "The night is over" → "The night won"; "Again" / "Try again" / "Restart" → "Retry"
- Toast: "Win level \(n-1) to open this sunrise" → "Win level \(n-1) to open this level"
- ResultsView: "Next sunrise" → "Next level" (or use "sunrise" everywhere; pick one)
- Home card: "Win level 5" → "Win level 5 or come back tomorrow"
- Levels tab (locked): "★ 20" → "Needs ★ 20"
- Levels lock card: "Rooftops opens at 20 ★ in Meadow" → "Rooftops opens at 20 ★ in the Meadow"
- Settings: "Calmer light, no shimmer. Follows iOS until you change it" → "Calmer light and no shimmer. Matches iOS until you change it."
- Settings: "The dawn pad" → "A soft dawn soundtrack"
- Hint: "Spare the fireflies." → "Spare the fireflies. They replant flowers."
- Hint: "Hoppers jump when the light touches them." → "Hoppers hop when the light touches them."
- New hint: "Wisps come in flocks. Sweep them in one pass."
- Achievement: "Pop 3 shadows or more in one Sweep." → "Pop 3 or more shadows in one Sweep."
- Achievement: "Reach a x4 chain: pop 13 shadows in a row." → "Reach a ×4 multiplier: 13 pops in a row."
- Scene label: "×\(chain)" → "×\(multiplier)" (e.g. "×2.5"), matching the store's "up to ×4"
- Store (metadata.md): "Keep all five flowers for three stars." → "Keep all five flowers and beat the target score for three stars."
- Store: "a brass lever on the mirror follows your finger" → "a brass lever beside the garden follows your finger"
- Store promo: "Your iPhone Duo is a mirror." → "The top half of your iPhone Duo is a mirror."
- No typos and no American spellings in UI strings ("Harbour", "Slate Grey", "carry on" are fine).
