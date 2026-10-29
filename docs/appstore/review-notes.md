# Glint: App Review notes (v1.0)

*Written Wed 28 Oct 2026 by the launch lead from the design (`design/GAME-DESIGN.md` §3–§9, `design/ROUND-1.md`); the build doesn't exist yet. The block between the markers is what App Review reads. Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes, no degree sign, no multiplication sign), so bytes = characters. `tools/appstore/build-metadata.js` prints the count and fails over 4,000 or on any non-ASCII character. Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

**Why it opens with "NO LOGIN".** Apple auto-rejected Swoop under Guideline 2.1 for a "missing demo account" although Swoop has no accounts at all. The reviewer's checklist asks for sign-in details first, so the very first line answers that question before anything else: no accounts, nothing to sign in to, press Play.

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**. **The App Store Connect tool sets all of it** (`asc.yml`, step `review`, from `docs/appstore/asc-metadata.json`): nobody pastes anything.
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email, read at run time from Squish's App Store Connect record and masked in every log (`tools/appstore/README.md`, "Personal data"). Never in the repo.
- **Notes:** the block below.
- **Attachment (optional):** a 20–30 s phone video of the Duo standing like a laptop: shut, then opening slowly so the light lifts out of the crease and sweeps across the garden, a few pops, then shut again to show the pause. The notes don't depend on it; the tool doesn't upload one.

<!-- REVIEW-NOTES:BEGIN -->
```
NO LOGIN - this game has no accounts. There is nothing to sign in to and no demo account to give: open the app and tap Play.

Thanks for reviewing Glint: Sun Mirror, a paid game with no ads, no in-app purchases, no data collection and no network requests of its own.

1. TESTING ON A REGULAR iPHONE (start here)
You don't need an iPhone Duo. The whole game plays on any iPhone (iOS 18 or later) and in the Simulator. Portrait is best.
- The top of the screen is a brass-framed mirror; the bottom is the garden. The line between them is the crease.
- Control: drag anywhere, up or down, like a trackpad. A band of gold light moves across the garden; a gold grip on a rail at its edge follows. Drag down to send the light further out, up to bring it back.
- Quickest look (about a minute): Home > Play starts Level 1. The hint says "Drag down to let the light in". Shadows (inky blobs with eyes) creep out of the crease towards five flowers at the far edge. Keep the light on a shadow and it sizzles and pops. At sunrise (35 s on Level 1) the level ends with 1 to 3 stars.
- Fireflies (small glowing dots) drift out too: light held on one too long makes it fizzle; one that reaches the flowers replants a lost flower.
- A shadow that reaches the edge eats a flower. All five gone: "The night won" and Retry.

2. HOW THE HINGE IS USED (iPhone Duo)
Glint reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. No private API. The angle is used only while playing; it is never stored or sent.
a) One half of the inner display is the mirror, the other the garden; the fold is the crease. Any pose works, laptop (mirror on top) or book. In book pose, Settings > Swap halves flips them.
b) The opening angle is the aim. Shut is dark. As the phone opens, light pools in the crease; from about 80 degrees the band lifts out and moves across the garden, reaching the far edge at about 135 degrees. Opening further changes nothing, so the phone never needs to lie flat.
c) Every level starts with the phone shut: if it is open, the game says "Close the phone to start", then "Open the phone to let the light in".
d) Closing the phone (below about 15 degrees for a quarter of a second) pauses the level, and the outer display shows "Paused" with the score. Opening it again resumes after a short grace.
e) There is no pause, warning or penalty anywhere near 90 degrees.

3. KIND TO THE DEVICE (Guidelines 2.4.2 and 1.4.5)
- Play is small, smooth movements between about 80 and 135 degrees, inside the range where the hinge holds its position. Glint never asks the user to lay the phone flat, slam it or move it fast.
- The only full close is the one at the start of a level (and to pause), at the player's own pace.
- No score, achievement or leaderboard rewards hinge speed or the number of folds.

4. MODES AND PROGRESS (nothing hidden, nothing to buy)
- Levels: 30 sunrises in 3 worlds (Meadow, Rooftops, Harbour). Stars (by flowers kept) open the next levels and worlds.
- Today's Dawn: one seeded 90 s sunrise a day, the same for everyone; best of the day kept. Opens after level 3.
- Long Night: endless waves and one best score. Opens after level 5, or a day after the first launch.
- Level 1 is gentle and is won by anyone who moves the light at all.

5. CONTENT
Cartoon shadow critters made of ink, with big eyes. In the light they shrink and pop into gold sparks and petals. No blood, no injury, no death: an eaten flower becomes a drooping stalk and a firefly can replant it.

6. PRIVACY
No third-party SDKs, analytics, ads, accounts or tracking. Progress and settings stay on the device. App Privacy: Data Not Collected.

7. GAME CENTER
Optional, never required. 3 leaderboards (Long Night, Today's Dawn, Total Stars) and 10 achievements (435 points), none hidden.

8. OTHER
- No notifications. Debug and demo modes are disabled in Release builds.
- Sound plays with the silent switch on; Settings > Sound turns it off.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

**Code: not written yet** (28 Oct). Tick "Code" when Round 1 compiles, and **RC** on the build that is submitted.

| Claim in the block | Source in the code (expected) | Code | RC |
|---|---|---|---|
| No sign-in anywhere; Home has a **Play** button that starts Level 1 | `UI/HomeView.swift` | [ ] exact label | [ ] |
| Drag anywhere (relative) moves the band; a gold grip on a brass rail at the garden's edge follows; "Drag down to let the light in" on a new level | `Input/DragMirrorSource.swift`, the rail and grip in `GardenScene`, App hint line | [ ] exact wording | [ ] |
| Level 1 is 35 s, gentle, won by anyone who moves the light; 1–3 stars | `LevelBook` level 1 (35 s; L2–5 38/42/45/50 s), `BalanceTests` (skill 0.3 wins) | [ ] | [ ] |
| Fireflies fizzle when held in light; delivered ones replant | `DawnSession` firefly rules | [ ] | [ ] |
| "The night won" and Retry | `UI/ResultsView.swift` | [ ] exact wording | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; the angle is never stored or sent | `Input/HingeReader.swift`; `Persistence/` has no angle (grep) | [ ] grep | [ ] |
| Band lifts out at about 80°, reaches the edge at about 135°; nothing changes beyond | `Tuning.band(angle:)` | [ ] update if tuning moves them | [ ] |
| "Close the phone to start" / "Open the phone to let the light in" | `GameController` level flow | [ ] exact wording | [ ] |
| Pause below 15° for 0.25 s; cover display shows "Paused" and the score; resume with grace | `Tuning.shutAngle` / `shutDwell`, `CoverView` | [ ] | [ ] |
| No pause or warning near 90° | GAME-DESIGN §8 | [ ] | [ ] |
| Never uses `status == .closed` in play (it turns on at about 85° on hardware) | grep `Glint/` | [ ] | [ ] |
| Settings **"Swap halves"** (book pose only: `AppRules.swapAllowed`), **"Sound"** | `UI/SettingsView.swift` | [ ] exact labels | [ ] |
| Today's Dawn opens after level 3; Long Night after level 5 or a day after first launch | unlock rules (GAME-DESIGN §6) | [ ] | [ ] |
| Today's Dawn is 90 s, seeded by the UTC day, best of the day kept | `LevelBook.daily(day:)`, `DailySeed` | [ ] | [ ] |
| Pops are sparks and petals; no blood or injury | `Scene/` FX (`metadata.md` §11 ask 1) | [ ] | [ ] |
| 3 leaderboards, 10 achievements, 435 points, none hidden | `achievements.md`, `App/GameCenterManager.swift` | [ ] | [ ] |
| No notifications, no rating prompt | no `UNUserNotificationCenter` / `requestReview` / `SKStoreReview` in `Glint/` | [ ] (if a rating prompt is added, add: "A one-time rating prompt may appear on a results card, never mid-level.") | [ ] |
| Debug and demo modes disabled in Release (`-glintDemo` keys and `GLINT-T` logs are DEBUG only) | `App/DemoMode.swift` (`#if DEBUG`), `testflight.yml`'s release check (already there) | [ ] | [ ] |

## If rejected under 2.1 (missing demo account / couldn't sign in)

Reply in the Resolution Center:
> "Glint has no accounts, no sign-in screen and no server, so there is no demo account to give. Open the app and tap Play; the whole game is playable at once. The first line of the review notes says so. On any iPhone, drag up or down anywhere on the screen to move the light."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game plays without a Duo, by dragging. Offer the phone video attachment.

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

> "Glint never asks users to lay the phone flat, slam it or move it fast. The light follows the phone's opening angle smoothly between about 80 and 135 degrees, inside the range where the iPhone Duo's hinge holds its position, so play is small, slow movements, like adjusting a laptop screen. Opening beyond 135 degrees changes nothing. The only full close is at the start of a level and to pause, at the player's own pace. No score, achievement or leaderboard rewards hinge speed or the number of folds. Any iPhone without a hinge plays the full game by dragging on the screen."

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to §4 and the achievements: 30 handmade levels in 3 worlds with stars and unlocks, five shadow kinds with their own behaviour, fireflies to spare, an endless mode and a daily mode with leaderboards. The store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Snapjaw's notes (structure mirrored): `C:\Users\59527\Trap\docs\appstore\review-notes.md`
