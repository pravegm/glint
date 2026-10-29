# App engineer, round 3

Nothing here has been compiled (CI is the compiler). Nothing is committed: the founder pushes. Every file was re-read
from disk after the overnight restart. I coded against these:
- Core: `LevelSpec.starScore`, `DawnSession.stars(flowersLeft:score:starScore:)`, `DawnSession.wave`;
- Contracts: `GloomState.submerged`, `GameEvent.surfaced`;
- the founder's new `tools/make-icon.js` icon.

## REVIEW-2 fixes (App)
- **5. HUD inset.** `AppRules.hudMargin(layout:)` is the mirror's brass frame thickness plus 12 pt. The thickness is
  copied from `GardenMirror.apply(rect:)`: `clamp(min side × 0.045, 9, 22)`.
  - The score and pause plates (and the new date chip) use it.
  - Test `hudSitsInsideTheBrassFrame`. The R2 overlap tests now use the same margin.
  - Pause stays at the mirror's bottom-left in book pose, as the founder asked.
- **6. First 10 s.**
  - The start card is one line ("Drag down to let the light in"; the R1 second line is gone).
  - The finger drawing slides the way the light grows (`PromptArt`, off under Reduce motion).
  - The level's 3rd-star target sits under it ("★★★ 1,400").
  - The grip pulse is the Scene's; the first murk at d = 0.3 is Core's.
- **7. Hints wait for their subject.**
  - `HintQueue`: a raised hint waits up to 25 s for its subject. Subjects are surfaced glooms only (never submerged
    ones), or a firefly.
  - It is marked seen only when actually shown.
  - The hint shows only while `hintTarget` exists, with the arrow and a breathing ring (lime for a firefly, gold for
    a shadow).
- **8. Icon.**
  - `IconShader` ports `tools/make-icon.js`'s `shade(x, y)` line by line, so `AppIconArt` is the committed PNG's
    design pixel for pixel.
  - It runs on the CPU (2×2 supersampling up to 512 px, 1× at 1024 to keep the Debug CI render to a few seconds).
  - `IconExport` still goes through `ImageRenderer`, with the luminance check and fallback.
  - Tests sample known pixels (the sun disc, the sky, the gloom body).
- **10. Fixtures** (new demo keys):
  - `ignore=<kind>`: the pilot never aims at that kind, so a lost result has real numbers and a known cause. This
    gives `results=lost;level=13;ignore=brute` and `level=18;ignore=hopper`.
  - `streak=<n>`: Today's Dawn finished on the last n days, today's best 2,140.
  - The cover-paused frame reuses `screen=cover` with `t=`.
  - Results stars, score and chips land at once in demo runs (founder note).
- **11. Modes.**
  - The score pill's second line is "Chain 7 · Wave 3": the wave always shows. It comes from `DawnSession.wave`, so
    fast-forwards show it too.
  - Today's Dawn gets a date chip ("Thu 29 Oct", `AppRules.dateChip`, UTC) centred at the mirror's far edge, one row
    in from the score and pause plates.
- **12. Duo.**
  - Swap halves exists only in book pose (`AppRules.swapAllowed`: Duo and a landscape canvas), in both the layout and
    Settings.
  - `JitterMeter` takes the filtered hinge angle while the hinge drives the light. About's diagnostics now say
    `jitterDeg p95 <deg> samples <n>`.
  - The book/laptop CI capture frames are the founder's.
- **13. Home.**
  - On phones the cards sit at the bottom (`SplitMenu(spread:)`, no empty band).
  - On a Duo the title is leading on the mirror half, clear of the sun (drawn 12 % right of centre; NEEDS line for
    Scene).
  - A blur over the lower half removes the light smear behind the cards.
- **14. Results hero.** `ResultGardenArt` draws the player's own five flowers as they ended (eaten = a bare stalk)
  under a sunrise, or under the moon (lost / Long Night). Levels / Home are now proper pill buttons (founder's Duo
  note).
- **15. Level map.**
  - Each medallion shows its name (12 pt) and, until ★★★, the 3rd-star target.
  - Locked medallions show a shadow peeking with a small lock.
  - Every unlocked face is gold (13 is no longer pink); the nodes are a little smaller to fit.
- **16. Badges and Settings.** "rooftops" is a gold-lined roof line with the sun; "brute" is an angry gloom popping (a
  ring and sparks). The warm glow is centred. Settings' title is pinned to the top safe area (`SplitMenu(alignTop:)`).

## Other changes
- `GameEvent.surfaced` is logged as `GLINT-T event surfaced kind=… d=…` (DEBUG). Every App switch over `GameEvent`
  has a `default:`.
- `ci/scenarios.txt`:
  - fixed 04 (it now opens on the Meadow tab via `level=1`);
  - added 04b (Rooftops);
  - 11 shows that Swap is ignored in laptop pose;
  - 13 and 22 are real lost results with their causes' tips;
  - 18 shows the streak;
  - new 23 (home streak) and 24 (cover paused);
  - every caption matches R3.

## Compile risks
- `IconShader` uses labeled-tuple `RGB` typealiases fed unlabeled tuple literals; a hand-built `CGImage` (data
  provider); and `@inline(__always)` statics.
- `SplitRegion`'s `.frame(minHeight: fill ? max(h - 24, 1) : nil)` is a `CGFloat?` ternary.
- `if let session, case .endless = playMode` in `publishHUD`.
- The tests use `GloomState(… submerged: true)` and the new Core `stars(flowersLeft:score:starScore:)`.

## Not done / open
- The "Can't read the hinge" mid-level fallback (R1 review P0-6) is still open.
- Grip pulse, the moon/sun art, grass light and rail are the Scene's; submerged travel and L1's first murk are Core's.

## R3b (founder, after CI 40859397563)
- **Results buttons always on screen.** `AppRules.resultsPlacement` gives the buttons their own rect, never shorter
  than their block (`resultsButtonsHeight`):
  - on phones, pinned to the bottom of the safe area, with the card scrolling above it;
  - on a Duo, the garden half.
  Test `resultsButtonsAlwaysOnScreen`: 402×874, 951×669 book and 669×951 laptop, both garden sides, compact or not.
- **Achievements** show as one row of small medallions: up to 4, or 3 plus "+n" when there are more
  (`AppRules.achievementRow`). Tapping the row opens `AchievementSheet` with their titles and earned lines.
- **`results=lost` is built, not played.**
  - `DemoPresets.lostStats(cause:)` gives 41 popped, 1,120 points and five flowers eaten (four by the cause), with
    cause = `ignore=` or murks.
  - The tip comes from `TipRules`, the same as a real loss, so scenarios 13 and 22 always lose and always show the
    brute / hopper tip.
- **Level map.** Where the path drops a row (at a row's end), it now swings out sideways past the medallion, so it
  never crosses its name or target line (`LevelPath(bulge:)`; test).

## R4 (ROUND-4 "App" 8–9)
- **Fail path in CI.** The built lost fixtures print `GLINT-T result level-13 won=0 …` / `level-18 won=0`, and
  `ci/scenarios.txt` now expects exactly those.
- **Frame 19 shows a real firefly.**
  - The new demo key `spawn=firefly` (with `t=`, on a level) plays the level's own `LevelSpec` plus one scripted
    firefly at t − 1 s (`DemoPresets.withFirefly`, via Core's existing `DawnSession(mode:spec:seed:)`; no Core hook
    needed).
  - A hint logs `GLINT-T hint <id> shown` the first frame it is really on screen (its subject on the field). That is
    frame 19's expect.
- **Book-pose flower inset.** The prompt card and hint plates no longer assume flowers at d ≈ 0.9. They size and
  centre themselves on the strip from d = 0.04 to 0.04 short of the flowers' nearest edge, read from
  `GardenScene.hudSafeRects` (`AppRules.flowersInnerD`, `overlaySpan`), so they follow Scene's 60 pt thumb inset
  whatever it does. The score and pause plates are on the mirror half, so they are unaffected. Tested.
