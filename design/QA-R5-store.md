# QA R5: App Store pre-submission audit (Glint: Sun Mirror 1.0)

*29 Oct 2026, store specialist. Read against the R4 code (`d5ca248` + tf-status), `artifacts/r4/screenshots/` and the
generated `docs/appstore/asc-metadata.json`. Report only: no Swift, workflow or doc edits (no plain typos found).*

## Blockers (rejection or a failed submit)

| # | Blocker | Evidence | Fix |
|---|---|---|---|
| B1 | **No App Store screenshots exist.** ASC won't submit without the 6.9" (or 6.5") iPhone set | `store.yml` has never run; `DEFAULT_STORE_RUN: ""` in `asc.yml`; `artifacts/r4` holds only CI test frames (RGBA, 1206 x 2622, never to upload) | Run `store.yml` (Duo ticked), eyeball all 3 MANIFESTs (`ok 10 flagged 0 missing 0`), set `DEFAULT_STORE_RUN`, run `asc.yml` `push --only screenshots` |
| B2 | **Support and Privacy Policy URLs return 404** (Guidelines 1.5 and 5.1.1(i): both must load at review time) | GitHub Pages is not on; every URL in metadata §9 is `pravegm.github.io/glint/...`; `docs/*.html` forward to `docs/site/` | Founder: Settings > Pages > Deploy from `main` `/docs` (runbook §0a), then open all 3 URLs on a phone before Submit |

**Blocker count: 2.** Neither is in code. Everything else below is a fix, not a block.

## Fixes before `push` (truth of the listing, Guideline 2.3.1 and founder rule 7)

Each needs `metadata.md` / `review-notes.md` edited, then `node tools/appstore/build-metadata.js` re-run (the JSON is generated).

| # | Claim (where) | What the build does | Suggested replacement |
|---|---|---|---|
| F1 | "close a little to catch the next one **at the crease**" (description, both locales; press-kit l.49 and l.134; social-launch l.92) | R2 crease shade: no light for d < 0.12 (`Tuning.creaseShade`). Glooms travel underground and surface at 0.15–0.60. The app's own loss tip says "the light can't reach the crease" | "close a little to meet the next one as it surfaces" |
| F2 | "Keep all five flowers for three stars" (description; press-kit l.54; site index l.265; support l.65) | From L4, 3 stars = 5 flowers **and** the level's score target (`DawnSession.stars(flowersLeft:score:starScore:)`; L4 2,150 up to L30 9,050). L1–3 are flowers only | "Keep all five flowers, and beat the level's score, for three stars." |
| F3 | "a brass lever **on the mirror** follows your finger" (description; review notes §1; site index l.229; support l.50; press-kit l.57) | R3: a brass rail along the garden's edge with a grip that rides the band (frame 07). It is not on the mirror | "a brass grip at the garden's edge follows the light" |
| F4 | **"Made for iPhone Duo"** heading in About (`UI/AboutView.swift` l.35), shown on every iPhone | "Made for iPhone" is Apple's MFi badge wording (trade-mark risk, 5.2.5). It also breaks metadata §4's rule that the app shows no Duo line on other iPhones | Swift (next build): "Best on iPhone Duo", or show it only when `isDuo` |
| F5 | **First Light badge is blank.** `artifacts/r4/screenshots/badges/glint.ach.firstlight.png` is solid #1B2349 (5 KB; the other 9 are 650–770 KB). The on-screen gallery (frame 20) draws it fine | `BadgeExport.renderAll` renders it first; the first `ImageRenderer` pass came out empty. `asc` would upload a blank Game Center image | Swift: render a throwaway badge first (or render twice). `badges.swift` should refuse a single-colour image. Re-check the CI badges before `push --only gamecenter` |
| F6 | Review notes §2a: "Any pose works ... Settings > Swap halves flips the halves" | The Swap halves row only shows on a Duo in book pose (`AppRules.swapAllowed`). A reviewer in laptop pose won't find it | "In book pose, Settings > Swap halves flips them." (notes are at **3,987 / 4,000 bytes**: cut a word elsewhere) |
| F7 | "about a minute long" (description; press-kit; site); notes "about 60 s" | L1–2 last 60 s; the rest run 65–95 s (most 75–95). L1 = 60 s is true | "a minute or so (60–95 s)"; keep L1's "about 60 s" |
| F8 | Fireflies: "Light held on one too long makes it fizzle" | R4: only the band's full core scorches (0.6 s), and a firefly darts towards the flowers when first lit. The claim is still true | Optional: add "They dart ahead of the light." |
| F9 | Cloud shadows (Rooftops and Harbour) block the light: not in any copy | `LevelBook` clouds from L11; the loss tip is "Wait for the cloud to pass" | Optional: add to "THE LIGHT IS YOUR AIM" ("Clouds over the Rooftops shade the light"). It's a selling point |
| F10 | 4+ condition (metadata §8 / §11 ask 1: "no fangs") | The brute has two small white fangs (frame 07) | Still 4+ in my reading (cute, no harm shown). Note it in §8, or round the teeth. If review re-rates, answer Infrequent/Mild (9+) |
| F11 | Stale headers: "The build doesn't exist yet" (metadata.md, review-notes.md); every claims table unticked; GAME-DESIGN.md still says 145°, ±0.050 band, 0.35 s scorch, drag cap 2.4, stars = flowers only | Code says 135°, ±0.065/0.10, 0.6 s core-only, cap 1.4, star targets | Tick §10 and the review-notes table against R4. Refresh GAME-DESIGN §3–§6 so the next copy pass doesn't re-import old rules |

Checked and **true**: 30 levels, 3 worlds (Meadow/Rooftops/Harbour), Long Night (opens at L5 or +24 h), Today's Dawn
(90 s, UTC seed, opens at L3), 5 flowers, 5 kinds, chain to x4 (13 pops), Sweep at 3+ in 0.35 s, band edge **135°**,
crease 80°, shut 15° / 0.25 s, resume 25° / 0.6 s, the 10 achievements (ids, titles, blurbs, **435** points) and the 3
leaderboards (`glint.endless/daily/stars`) match code, every quoted hint and label is exact ("Close the phone to
start", "The night won", "Paused · open the phone to carry on", the Settings labels), Reduce motion follows iOS, and
"plays on other iPhone models too" (not "every iPhone") is used in the description.
Still wrong outside the listing: press-kit l.57 and HANDOVER l.20 say "Every iPhone" (iOS 18+ only).

## Guideline and compliance checks

- **2.1 demo account:** the notes open "NO LOGIN - this game has no accounts" and `demoAccountRequired: false`. OK.
  Notes explain the L3/L5 unlocks.
- **2.3 metadata:** name 17/30, subtitle 30/30, keywords 97/100 bytes (no Apple marks, no competitors), promo
  157/170, description 3,264/4,000, notes 3,987/4,000 ASCII. Fix F1–F3 and F6–F7 first.
- **2.3.7 / trade marks:** no Apple mark in the name, subtitle or keywords. "iPhone" is spelled right in the heading
  ("PLAYS ON OTHER iPhone MODELS TOO"). "iPhone Duo" is only used referentially (promo, description). See F4 for the
  in-app MFi wording. No other platforms are named anywhere (grep: no Android, Galaxy, Pixel).
- **5.1 privacy manifest** (`Glint/PrivacyInfo.xcprivacy`): tracking false, no domains, no collected data. UserDefaults
  CA92.1 (ProgressStore, SettingsStore, the GameCenterManager queues) and SystemBootTime 35F9.1
  (`ProcessInfo.systemUptime` in `AppTrace`). `CACurrentMediaTime` isn't a listed API, so 35F9.1 covers what is used.
  No file-timestamp, disk-space or keyboard APIs. No URLSession, ATT, IDFV, notifications or review prompt.
  `testflight.yml` lints the manifest in the bundle. OK.
- **Game Center:** optional, the access point is off, nothing is gated, scores are queued while signed out.
  `GKGameCenterBadgingDisabled` is set. The tool attaches all 13 items to the draft submission.
  **`glint.daily` recurrence starts Mon 9 Nov 00:00 UTC**: create it before then (`push --only gamecenter`), or move
  the date in `build-metadata.js` and `achievements.md`.
- **Age rating:** every answer None/No, giving 4+. See F10.
- **Export compliance:** `ITSAppUsesNonExemptEncryption: false` in `project.yml`. OK.
- **Content rights:** no third-party content (all art and sound in code, system fonts). OK.

## Assets

| Asset | State |
|---|---|
| 1024 icon `AppIcon-1024.png` | 1024 x 1024, 8-bit, **colour type 2 (RGB, no alpha)**, no tRNS. OK |
| 6.9" set `store-69` P01–P10 (1320 x 2868) | **Not produced yet** (B1). Required; ASC scales it to 6.5" |
| 6.3" set `store-63` P01–P10 (1206 x 2622) | Not produced. Optional (6.9" scales down), but the tool pushes it |
| Duo inner `store-duo` D01–D10 (2853 x 2007) | Not produced. Optional until Apr 2027; by hand if the API has no group |
| Game Center badges (10, 1024², opaque) | 10 RGB, no alpha; **First Light blank** (F5) |
| Header 3840 x 1646 / search art 3840 x 2560 (iOS 27 placements) | Optional. `store.yml placements_from=<clean run>`, then `asc placements_run` |
| App Preview video | None (optional; the tool can't upload one) |
| Caption truth to eyeball on the first store run | P04 needs a firefly in view at L4 t=12; P08 needs an eaten flower at L27 t=40; P01 book angle within 100–135° |

## Info.plist / project.yml

Display name `Glint`. Version `1.0`, build = the CI run number (checked in `testflight.yml`). iPhone only
(`TARGETED_DEVICE_FAMILY 1`). All 4 orientations with `UIRequiresFullScreen` (fine: the layout follows the canvas).
Launch screen is the `LaunchBackground` colour. Status bar hidden. Dark style. No `UIRequiredDeviceCapabilities`
(none needed). Game Center entitlement. Deployment target **iOS 18**: the only post-18 API is `onHingeChange`, inside
`if #available(iOS 27.1, *)` (`HingeReader`). Nothing else used is past iOS 17 (`contentTransition`, two-argument
`onChange`, `persistentSystemOverlays`, `defersSystemGestures`, `ImageRenderer`). OK.

## Submission checklist (founder clicks, in order)

1. GitHub > pravegm/glint > Settings > **Pages** > Deploy from branch `main` `/docs`. Open the home, support and
   privacy URLs on the phone (B2).
2. Claude: fix F1–F3 and F5–F7 in the docs and the Swift, regenerate `asc-metadata.json`, push, wait for green CI
   (badges) and a new TestFlight build.
3. Actions > **App Store screenshots** > Run (about 2 h). Eyeball the frames. Claude sets `DEFAULT_STORE_RUN` (B1).
4. Actions > **App Store Connect tool**: `check`, then `plan` (read `plan.txt`), then `push`, **before Mon 9 Nov**
   (daily board), with `build=<run number>`.
5. ASC > App Privacy > Get Started > "No, we do not collect data" > **Publish**.
6. ASC > Pricing and Availability > untick Apple Silicon Mac and Vision Pro. Turn **Family Sharing** on.
7. ASC > App Information > **EU DSA trader status** (without it, the app is not on EU storefronts).
8. If the API offered no Duo group, upload the Duo D01–D10 by hand.
9. Open the 1.0 page: check the screenshots, the badges (First Light not blank), the 3 leaderboards and 10 achievements
   in the submission, age rating 4+, and the price (£1.99 / $1.99).
10. **Add for Review > Submit to App Review** (target Wed 9 Dec). Release stays manual (Tue 15 Dec 08:00 UK).
