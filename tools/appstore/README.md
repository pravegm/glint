# App Store Connect from GitHub Actions

`asc.swift` puts the whole Glint 1.0 listing (`com.pravegm.glint`, "Glint: Sun Mirror") into App Store Connect from `docs/appstore/asc-metadata.json`. It's a port of Snapjaw's tool (`C:\Users\59527\Trap\tools\appstore\`), itself a port of the sister tools that set up and filed their 1.0s on the same Apple account. The metadata schema is unchanged, so the same JSON shape drives it. It is idempotent: it changes only what differs, and `push` resumes after a failure. It never submits anything for review and never releases the version.

Nobody pastes anything: the workflow pushes the listing. The few clicks with no API are in `docs/LAUNCH-RUNBOOK.md`.

## The metadata file

`docs/appstore/asc-metadata.json` is **generated**: `node tools/appstore/build-metadata.js` builds it from `docs/appstore/metadata.md`, `review-notes.md`, `achievements.md` and `featuring-nomination.md`, prints every count against Apple's limits, cross-checks the runbook's achievement table and `screenshots.md`, and exits 1 on any problem (an over-long field, non-ASCII review notes, notes that don't open with "NO LOGIN", a banned word, an en-US description that drifts from en-GB). Change the docs, run it, commit both.

## Before the first run (the founder, once)

1. **The app record.** Apple's API can't create apps. App Store Connect → Apps → **+** → New App → iOS, name `Glint: Sun Mirror`, English (U.K.), bundle ID **`com.pravegm.glint`** (registered first with Game Center), SKU `glint-2026` (runbook §1b–§1c).
2. **The 4 repository secrets**: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (the tool's) and `APPLE_TEAM_ID` (TestFlight's): the same Admin team key the sister apps use (runbook §2).

Without them, a ticked run **fails on purpose with a plain message** saying which is missing:
- no secrets → the step "Check the secrets exist" fails: *App Store Connect is not set up* (which secrets, how to make the app record, where to add the secrets);
- secrets but no app record → the `check` step fails: *No App Store Connect app record* for `com.pravegm.glint` (or the key can't see it).

Both also write the same instructions to the run's summary page.

## Run it

GitHub → **Actions** → **App Store Connect tool** → **Run workflow**:

| Input | Meaning |
|---|---|
| `asc` | Tick to contact App Store Connect. Unticked, the run only typechecks and validates |
| `mode` | `check`: read-only status, including an AUDIT that reads the whole 1.0 page back (build, copyright, review details, every localization's fields, screenshot sets and library placements, review submissions). `plan`: check plus a dry run, still read-only. `push`: check, plan, then write |
| `only` | Optional step list, e.g. `nomination` or `gamecenter,attach` |
| `store_run` | A clean **App Store screenshots** run (`store.yml`, manual only). Empty = `DEFAULT_STORE_RUN` in the workflow |
| `ci_run` | A green **CI** run whose `screenshots` artifact holds `badges/`. Empty = the latest green run on `main` (none yet = a warning, not an error) |
| `placements_run` | A `store.yml` run with a `store-placements` artifact (product page header and search art). Empty = the placements step changes nothing |
| `inherit_from` | Default `com.pravegm.squish`. See "Personal data" |
| `build` | The release build number to attach to 1.0 (the `build` step). Empty = leave it |

Every run uploads `asc-output` (check.txt, plan.txt, push.txt). Read `plan.txt` before running `push`.

```bash
gh workflow run asc.yml -R pravegm/glint -f asc=true -f mode=check
gh workflow run asc.yml -R pravegm/glint -f asc=true -f mode=plan
gh workflow run asc.yml -R pravegm/glint -f asc=true -f mode=push -f only=nomination
```

The key is written to a temp file (mode 600) for the job and deleted at the end; it is never echoed.

**`DEFAULT_STORE_RUN` is empty** until the first clean `store.yml` run (all three MANIFESTs `ok 10 flagged 0 missing 0`). Until then the screenshots are a gap (validate and plan say so), not an error. Put the run's ID in `.github/workflows/asc.yml`, and again after the final store run at code freeze (Mon 7 Dec), or pass `store_run`.

## Personal data (the repo is public)

The metadata file has no name, phone or email: `review.contact` is `null`. With `--inherit-from com.pravegm.squish` (or `ASC_INHERIT_FROM`), the tool reads Squish's newest version at run time, its `appStoreReviewDetail` contact, and uses it in memory for Glint. Every value is masked in all output (`‹hidden›`, plus GitHub's `::add-mask::`), and `asc-output` gets only masked lines. Never put these values in a file.

The copyright is `© 2026 pravegm` (the public GitHub handle, `metadata.md` §9), so it is in the metadata and pushed as is. If the founder wants a legal name instead, set `copyrightHolder` to `null`: the copyright is then inherited from Squish and masked like the contact.

## What `push` does, in order

| Step | What |
|---|---|
| `appinfo` | Name `Glint: Sun Mirror`, subtitle `Catch the sun, pop the shadows` and privacy URL for en-GB and en-US. Primary language en-GB. Content Rights: no third-party content |
| `categories` | Games: Arcade and Casual, then Entertainment (`metadata.md` §7). The subcategories are checked against Apple's live list first (on 26 Oct it had dropped Arcade); a subcategory that isn't live is replaced by the first live entry of `categories.fallbackSubcategories`: **Action**. `check` and `plan` print what would be pushed |
| `agerating` | The questionnaire from `metadata.md` §8: every item None or No, including Contests. Result 4+ |
| `version` | 1.0: copyright `© 2026 pravegm`, release **manual** (`metadata.md` §9: the founder presses Release This Version on Tue 15 Dec) |
| `build` | Only with `build`: attaches that processed build to 1.0. Never submits |
| `localizations` | Description, keywords, promotional text, support and marketing URLs (en-GB and en-US) |
| `review` | Review notes (they open with "NO LOGIN"; validate fails over 4,000 bytes), "no sign-in", and the contact (inherited) |
| `gamecenter` | Enables Game Center for the app and version 1.0. Creates the 10 achievements (`glint.ach.*`, 435 points, none hidden, none repeatable) with en-GB and en-US text and a badge each. Creates 3 leaderboards: `glint.endless` (classic, "Long Night"), `glint.daily` (recurring daily from Tue 15 Dec 2026 00:00 UTC, launch day, "Today's Dawn") and `glint.stars` (classic, "Total Stars", range 0–90, suffix " star" / " stars"); the first two are Integer, High to Low, best score, range 0–10,000,000, suffix " point" / " points". All from `achievements.md` via the metadata |
| `attach` | Adds every achievement and leaderboard version to the draft iOS review submission. It never adds the build and never submits |
| `screenshots` | 6.9" (1320 × 2868, `store-69`): P01–P10. 6.3" (1206 × 2622, `store-63`), which goes in Apple's required "Dynamic Island, medium" class, the tool's `APP_IPHONE_61` key: P01–P10. iPhone Duo inner (2853 × 2007, `store-duo`, book pose): D01–D10, only if the API offers a Duo placement group (`check` says). The iPhone sets are **portrait**; the names are the ones `asc-metadata.json` lists. A set whose MANIFEST isn't `flagged 0 missing 0` is refused. Library images can take minutes each to process: the tool waits up to 20 minutes per image, then says to re-run (it resumes) |
| `placements` | Only with `placements_run`: the product page header (`header-3840x1646.png`) and the search results art (`search-3840x2560.png`) from that run's `store-placements` artifact, placed on the en-GB and en-US 1.0 localizations. It refuses an artifact whose `MANIFEST.txt` reports problems. Without `placements_run` it changes nothing (a gap) |
| `price` | £1.99, base territory United Kingdom; Apple equalises the rest ($1.99). Available everywhere except China mainland and Vietnam (`metadata.md` §9: both need a local game licence) |
| `accessibility` | Nothing for 1.0: labels go on by hand on launch day |
| `nomination` | The App Launch featuring nomination from `featuring-nomination.md`, publish date Tue 15 Dec 2026. It's **submitted** (`"submit": true`), not left as a draft. Due by Mon 23 Nov |

Network: Apple's endpoints sometimes hang for minutes. A request that fails with an `NSURLErrorDomain` error (matched by domain, because it arrives as an `NSError`, not a `URLError`) is retried: reads up to 8 times with a growing pause, writes 3 times (no duplicate creates). The `asc` job's timeout is 180 minutes for the same reason.

## What the app (and CI) must provide before the tool can do everything

The tool is complete; these are inputs it reads from the app's repo. Until each exists, validate and plan report a **gap** (a warning), never a failure:

| Input | Who | What exactly | Without it |
|---|---|---|---|
| **10 achievement badges** | App engineer + CI | Demo key `screen=badges` renders `Documents/badges/glint.ach.<key>.png` (1024 × 1024, opaque) and logs `GLINT-T badges done 10`; add a `badges` line to `ci/scenarios.txt` (`ci/screenshots.sh` already copies the folder into the `screenshots` artifact). Art brief: `docs/appstore/achievements.md` "Images" | The `gamecenter` step can't save the achievements (Apple needs an image each) |
| **`Glint/Core/Achievements.swift`** | Core | `static let all: [AchievementDef] = [...]`, each `static let x = def("<key>", …)` → `glint.ach.<key>`, exactly `achievements.md`'s 10 | The tool and `badges.swift` can't cross-check the IDs against the code (they use `achievements.md`'s list and warn) |
| **`Glint/App/GameCenterManager.swift`** | App | `enum Leaderboard { static let endless = "glint.endless"; static let daily = "glint.daily"; static let stars = "glint.stars" }` | Leaderboard IDs aren't cross-checked (a warning) |
| **Store screenshots** | Founder / Claude | **Ported** (`store.yml`, manual only; `docs/appstore/screenshots.md` "Running it"). Run it, eyeball, then put a clean run's ID in `DEFAULT_STORE_RUN` | The `screenshots` step is a gap; nothing uploads |
| **Header and search art** (optional) | Founder / Claude | `store.yml` with `placements_from=<clean run>` (`ci/store-placements.sh`, `ci/store-banner.swift`), then `placements_run` | The `placements` step changes nothing |

**Glint-specific things the tool doesn't do** (by design or by API): it can't create the app record or the bundle ID; it can't upload an App Preview video; it can't publish Accessibility Nutrition Labels before the version is live; it doesn't know a level's star count (the `glint.stars` board is fed by the app at run time, not by the tool); and a recurring leaderboard's start date in the past may be refused on create (move `recurrence.startDate` in `build-metadata.js` and `achievements.md` to the next day, then regenerate).

## Still by hand (no public API, or the founder's call)

- **Create the app record** (above): the API can't create apps. Use the name fallbacks in `metadata.md` §1 if the name is taken, then update the metadata.
- **App Privacy**: Get Started → "Data Not Collected" → Publish.
- **Mac and Vision Pro**: Pricing and Availability → untick "iPhone and iPad Apps on Apple Silicon Macs" and "… on Apple Vision Pro" (runbook §6a).
- **Family Sharing**: on (permanent once on).
- **EU DSA trader status**: App Information → App Store Regulations and Permits. Check it per app.
- **The build**: pick it on the 1.0 page (or use `build`), **Add for Review** (it joins the draft that holds the Game Center items), then **Submit to App Review**.
- **Release**: manual: the founder presses **Release This Version** on Tue 15 Dec (runbook §7).
- **Accessibility Nutrition Labels**: on launch day, only the labels `accessibility.md` marks as passed.
- **iPhone Duo screenshots**: upload by hand if the API offers no Duo group and App Store Connect shows the slot.
- **Promo codes** and the optional App Review screen recording.

## Notes

- **The daily leaderboard start** (Tue 15 Dec 2026 00:00 UTC, launch day, so it is never before the Game Center push; QA R5). Create it with `push --only gamecenter` any time before then; testers see the board empty until launch. Whether App Store Connect accepts a start date already in the past is unconfirmed; once that date passes `validate` warns, and the fix is to move `recurrence.startDate` to the next day.

## Files

- `asc.swift`: the tool (Foundation and CryptoKit only). Commands: `validate`, `check`, `plan`, `push`, `upload-screenshots [dir]`, `upload-placements [dir]`. Run `xcrun swift tools/appstore/asc.swift help`. `upload-screenshots <dir>` takes a folder of downloaded `store-*` artifacts and uploads every clean frame. It refuses a set whose MANIFEST isn't `flagged 0 missing 0`.
- `badges.swift`: checks the achievement IDs (code, `achievements.md`, the metadata) and collects and flattens the app-rendered badges onto dawn blue `#141A3A`.
- `build-metadata.js`: builds `docs/appstore/asc-metadata.json` from the docs and checks every limit (Node, no packages).
- `fixtures/asc-metadata.sample.json`: the validator's CI fixture (a placeholder URL, a partial en-US, missing images, no screenshots), made from `docs/appstore/asc-metadata.json`.
- `badges/`: written by CI (the `badges` artifact); not committed (`.gitignore`).
