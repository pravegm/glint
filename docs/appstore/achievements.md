# Glint: Game Center leaderboards and achievements (v1.0)

*Written Wed 28 Oct 2026 by the launch lead from `design/GAME-DESIGN.md` §4–§6, the `GameEvent` and `DawnSnapshot` types in `Glint/Shared/Contracts.swift` and `design/ROUND-1.md` (App engineer 1: leaderboards `glint.endless`, `glint.daily`, `glint.stars`). **IDs are permanent once created in App Store Connect**, so Core and the App engineer must use exactly these strings. **Glint has no `Achievements` type yet**: this file proposes it (below, "For Core"), and every trigger is computable from one finished session's events and snapshot plus `ProgressStore` (stars per level), with no new inputs. Every one works the same with the hinge (Duo) and with drag (other iPhones). Nothing rewards hinge speed or the number of folds (App Review 2.4.2).*

## Apple's limits (from the sister games' sourced notes)
- ≤ 100 points per achievement, ≤ 1,000 points per app, ≤ 100 achievements.
- IDs ≤ 100 characters: letters, digits, `.` and `_`. Permanent.
- Each achievement needs a **1024 × 1024** image (PNG or JPEG, RGB, no transparency, ≥ 72 dpi). Leaderboard images are optional.
- Achievements and leaderboards only go live attached to a version that includes them. The App Store Connect tool creates all of them and attaches them to the 1.0 review submission (`asc.yml` steps `gamecenter` and `attach`); nobody types them in.

## Leaderboards (3)

| | `glint.endless` | `glint.daily` | `glint.stars` |
|---|---|---|---|
| Type | **Classic** (all-time) | **Recurring** | **Classic** (all-time) |
| Reference name | `Long Night` | `Today's Dawn` | `Total stars` |
| Display name (en-GB and en-US) | `Long Night` | `Today's Dawn` | `Total Stars` |
| Score format | Integer | Integer | Integer |
| Format suffix (singular / plural) | ` point` / ` points` | ` point` / ` points` | ` star` / ` stars` |
| Sort order | High to Low | High to Low | High to Low |
| Score submission | Best score | Best score | Best score |
| Score range (optional) | 0 – 10,000,000 | 0 – 10,000,000 | 0 – 90 |
| Recurring settings | — | Start **Mon 9 Nov 2026, 00:00 UTC**; duration **1 day**; repeats every **1 day** | — |
| What the app submits | the score of every finished **Long Night** run (`PlayMode.endless`) | the score of every finished **Today's Dawn** run of the (UTC) day (`PlayMode.daily(day:)`); best of the day is kept by Game Center | the player's **total stars** across all 30 levels (`ProgressStore`), after every level result and on each Game Center sign-in. It only grows, so "best score" is the current total |

**Why the ranges:** Long Night never ends and the chain reaches ×4, so 10 million leaves room; total stars are 30 levels × 3 = **90**. **Never submit** attract-mode (`PilotSource`) or demo scores.

**Why Today's Dawn starts on Mon 9 Nov:** a few days after the tool first creates Game Center (runbook §3), so TestFlight testers (Game Center sandbox) see the board for weeks before launch. If the tool runs after 8 Nov, Claude moves the start date to the next day before pushing (whether App Store Connect accepts a start date in the past is unconfirmed: the sister games' note).

**Today's Dawn runs on the UTC date.** `DailySeed.day(for:)` is "days since 2026-01-01 UTC" (`design/ARCHITECTURE.md`): keep it UTC everywhere, so the board and the seed change at the same moment for everyone (00:00 UTC: midnight in the UK in winter, 4 pm Pacific).

## Achievements (10, 435 points)

**Which sessions count:** a finished level (`.level(n)`, won or lost), a finished Today's Dawn, a finished Long Night. **Never** attract mode, demo mode or CI pilots.

| # | Achievement ID | Title | Pre-earned description | Earned description | Points | Hidden | Trigger (for Core: exact) |
|---|---|---|---|---|---|---|---|
| 1 | `glint.ach.firstlight` | First Light | Win your first sunrise. | The sun is up. The garden is yours. | 10 | No | a `.sunrise` event in any `.level(n)` session |
| 2 | `glint.ach.sweep` | Clean Sweep | Pop 3 shadows or more in one Sweep. | Three pops, one swish of light. | 10 | No | any `.swept(count:bonus:)` event (it first fires at count 3) |
| 3 | `glint.ach.brute` | The Bigger They Come | Pop a brute. | Big, slow, grumpy, and gone. | 25 | No | a `.popped` event with `kind == .brute` |
| 4 | `glint.ach.firefly` | Firefly Gardener | Let a firefly replant a lost flower. | A little light brought a flower back. | 25 | No | a `.fireflyDelivered(replanted: true)` event |
| 5 | `glint.ach.chain4` | Four Times Bright | Reach a x4 chain: pop 13 shadows in a row. | The chain hit x4. Dazzling. | 50 | No | a `.popped` event with `chain >= 13` (multiplier `1 + 0.25 × (chain − 1)` reaches ×4 at chain 13: GAME-DESIGN §5). If `Tuning` moves the step or the cap, change the number in the description and here together |
| 6 | `glint.ach.rooftops` | Over the Rooftops | Win all 10 Rooftops sunrises. | Every roof in the city, lit. | 50 | No | `ProgressStore` has ≥ 1 star on each of levels 11–20 |
| 7 | `glint.ach.harbour` | Harbour Lights | Win all 10 Harbour sunrises. | The whole harbour, lit at last. | 100 | No | `ProgressStore` has ≥ 1 star on each of levels 21–30 |
| 8 | `glint.ach.allstars` | Ninety Suns | Earn all 90 stars. | Every sunrise, every flower. | 100 | No | total stars == 90 (`LevelBook.count` × 3) |
| 9 | `glint.ach.daily` | Early Riser | Finish a Today's Dawn. | Up with the sun, with everyone else. | 15 | No | a finished `.daily(day:)` session (won or lost) |
| 10 | `glint.ach.longnight` | Night Watch | Score 10,000 in one Long Night. | Ten thousand points before dawn. | 50 | No | a `.endless` session whose final `snapshot.score >= 10000` (check with `BalanceTests`, below) |
| | | | | | **435** | | |

Points: 10 + 10 + 25 + 25 + 50 + 50 + 100 + 100 + 15 + 50 = **435**. **565 points stay in reserve** for later updates (a fourth world, new shadows, events), well under the 1,000 cap.

**Titles:** all ≤ 30 characters (longest: "The Bigger They Come", 20). The `x4` in #5 is a plain letter x (ASCII), so it reads the same in every Game Center font.

**Achievable more than once:** No, for all ten. **Hidden:** none; every one tells the player something to try. **Progress:** report only when earned (`percentComplete` 100), and re-send every earned one on each Game Center sign-in (the sister games' 1.0 rule). Partial progress (for the worlds and Ninety Suns) is a nice 1.0.1 addition.

**en-US** is identical to en-GB for all ten ("Harbour" is the world's proper name, so it stays).

## For Core: the shape of `Achievements.all` (new file `Glint/Core/Achievements.swift`)

The App Store Connect tool (`tools/appstore/asc.swift`, `badges.swift`) reads the IDs straight from the source, in Snapjaw's shape, so please write it exactly like this:

```swift
public struct AchievementDef: Equatable, Sendable { public let id: String; public let title: String; public let detail: String }

public enum Achievements {
    static func def(_ key: String, _ title: String, _ detail: String) -> AchievementDef {
        AchievementDef(id: "glint.ach." + key, title: title, detail: detail)
    }
    static let firstLight = def("firstlight", "First Light", "Win your first sunrise.")
    static let sweep = def("sweep", "Clean Sweep", "Pop 3 shadows or more in one Sweep.")
    // … one `static let` per row above, in the table's order …
    static let all: [AchievementDef] = [firstLight, sweep, brute, firefly, chain4, rooftops, harbour, allStars, daily, longNight]
}
```
`id` = the Achievement ID above (the full `glint.ach.<key>` string), `title` = the Title, `detail` = the Pre-earned description, in the table's order. The in-app Results card and any in-app list use the same words. The leaderboard ids live in `GameCenterManager` as `enum Leaderboard { static let endless = "glint.endless"; static let daily = "glint.daily"; static let stars = "glint.stars" }` (the tool reads the `static let` strings inside `enum Leaderboard`).

## The ladder (does it feel right?)

Rough reach from GAME-DESIGN §6 (to be confirmed by `BalanceTests`' `GLINT-BAL` table, skills 0.3 / 0.6 / 0.9):
- **First session:** First Light (level 1 is made to be won), Clean Sweep (wisp flocks from level 3), The Bigger They Come (brutes from level 5), Firefly Gardener (fireflies from level 4, once a flower has been lost).
- **First week:** Early Riser (Today's Dawn opens after level 3), Four Times Bright, Over the Rooftops.
- **The long tail:** Harbour Lights (world 3 is properly hard), Night Watch, Ninety Suns (every level with all five flowers).

**Checks before the tool creates them** (descriptions and triggers can still change then; ids never):
- `Night Watch`: 10,000 in Long Night should be above the 0.6 pilot's median and at or below the 0.9 pilot's. If not, change the number in both descriptions and the trigger together (the title stays).
- `Four Times Bright`: the 0.6 pilot should reach chain 13 in some levels of world 2; if the chain window makes 13 near-impossible, lower it to the ×3 point (chain 9) and retitle "Three Times Bright" before creation.
- `Ninety Suns`: three stars on every Harbour level must be possible for the 0.9 pilot on most seeds; otherwise it's a grind, not a goal.
- Every trigger is reachable with drag only.

If the harness shows a step is far off, change the **description and trigger** before the achievement is created, never after: changing what an earned achievement meant is unfair.

## Copy rules
- Nothing mentions hinge speed, slamming or laying the phone flat.
- No "kill", "die", "burn", "zap" or "destroy". Shadows pop, fireflies are spared, flowers come back.
- No competitor names, no Apple marks.

## Images (needed before you can save each achievement)

Ten 1024 × 1024 PNGs, one per achievement, opaque (no alpha channel), in the app icon's style: a **deep dawn-blue** field (`#141A3A`, the badge background `badges.swift` flattens onto) with a soft gold glow from one corner, a **brass medallion** whose rim shows the tier (**copper** for 10–25 points, **brass with a gold inner ring** for 50, **bright gold with rays** for 100) and one motif in the game's gold light and ink-purple: a sun peeking over a garden edge (First Light), three pops in a curved streak of light (Clean Sweep), a big grumpy gloom squinting (The Bigger They Come), a firefly over a sprouting flower (Firefly Gardener), "x4" in chunky numerals with a glint (Four Times Bright), rooftops with a band of light (Over the Rooftops), a lighthouse-like harbour light over water (Harbour Lights), a ring of small suns (Ninety Suns), a sunrise over a calendar page (Early Riser), a crescent moon and a ring of tiny stars (Night Watch). No words, only short numerals.

**Where they come from:** the app draws them itself, the way the sister games do (`AchievementBadge(id:)` in `Glint/UI/AchievementArt.swift`). **Ask (App engineer):** add the demo key `screen=badges`, which renders all ten into the app's `Documents/badges/` (one file per achievement, named by its id: `glint.ach.firstlight.png`) and prints `GLINT-T badges done 10`; then add a `badges` line to `ci/scenarios.txt` (for example `20-badges|screen=badges|12|the ten Game Center badges|GLINT-T badges done`). `ci/screenshots.sh` already copies `Documents/badges/` into the `screenshots` artifact. `tools/appstore/badges.swift` checks and flattens them, and the App Store Connect tool uploads each one with its achievement (`gamecenter` step). Nothing to upload by hand.

## Implementation checklist (Core and App engineers)
- [ ] `Glint/Core/Achievements.swift`: `Achievements.all` has exactly these 10 ids, titles and details, in this order, in the shape above.
- [ ] `Achievements.earned(after:events:progress:alreadyEarned:)` (or similar) returns only ids not in `alreadyEarned`, never for attract or demo sessions.
- [ ] `GameCenterManager.Leaderboard` has exactly `glint.endless`, `glint.daily`, `glint.stars`.
- [ ] Authenticate once at launch; if the player declines, never show the sign-in sheet again uninvited. Silent when signed out.
- [ ] Banners never appear mid-level: queue them until the Results card.
- [ ] Today's Dawn: submit to `glint.daily`; Long Night to `glint.endless`; total stars to `glint.stars` (levels never submit a points score).
- [ ] Drag play can earn every achievement (no hinge-only trigger).
- [ ] `AppTests` or `CoreTests`: one test per achievement just below and just at each threshold.

## Sources
- App Store Connect Help, *Achievements* (limits, hidden, images): https://developer.apple.com/help/app-store-connect/reference/game-center/achievements
- App Store Connect Help, *Leaderboards* (classic and recurring; start date, duration, restart): https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards
- Snapjaw's Game Center plan (format mirrored): `C:\Users\59527\Trap\docs\appstore\achievements.md`
