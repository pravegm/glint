# Round 2 (founder brief, 28 Oct night)

R1 compiled and passed 158 tests first time (CI 40782324566). Frames: `artifacts/r1/shots/` (not committed; ask the
founder-agent for paths). What the frames and balance table say:

1. **The garden is empty and the game is too easy.** Camping the band at the crease pops every murk the moment it
   emerges (L27 at 40 s shows one gloom on screen). Skill 0.3 wins every level 1–16 with 5 flowers.
2. **The sun's glint** is a huge white 4-point star pasted over the sun: it reads as a bug.
3. **HUD plates cover flowers 0 and 4** (score bottom-left, pause bottom-right).
4. **Level map world tabs truncate** ("2…", "6/…", "20…").
5. ASC tool needs `Glint/App/GameCenterManager.swift` achievement IDs and `screen=badges` (docs/appstore/achievements.md).

## Decisions
- **Crease shade (new rule).** The mirror shades the strip next to the crease: light does nothing for
  `d < Tuning.creaseShade` (0.12). Glooms there are safe and drawn "submerged" (half sunk in a dark seam, eyes peeking).
  You meet shadows in the open garden. The band mapping is unchanged (the band can sit in the shade; it's just dim
  there).
- **HUD moves to the mirror half's far corners** (away from the crease): score + chain at the far-left corner, pause at
  the far-right corner (in a book layout, the two far corners of the mirror). Score isn't time-critical, so the mirror
  blur rule is fine. Nothing drawn by SwiftUI may overlap `GardenScene.flowerRects`.
- **Balance targets** (BalanceTests, pilot with human-like hinge noise at low skill):
  - L1–3: skill 0.3 wins 100 %, 5 flowers. L4–10: 0.3 wins 100 %, loses 0–1 flower on average by L8–10.
  - World 2 (L11–20): 0.3 wins 60–90 %, ~1–2 flowers lost by L15–20; 0.6 wins ~100 %, loses ≤ 1.
  - World 3 (L21–30): 0.3 wins ≤ 30 %; 0.6 wins 70–100 % losing 1–3; 0.9 wins 100 %, 3★ mostly.
  - At any moment mid-level from L6 on there are 4–10 glooms on the field (more pressure, more cascades).

## Core engineer
- `Tuning.creaseShade = 0.12` (intensity 0 below it); expose `Tuning.isShaded(d:)`. `GloomState.d < creaseShade` =
  submerged (Scene draws it).
- Pilot: a human-hinge model scaled by (1 − skill): jitter ±0.05, a 0.1–0.35 s lag, occasional overshoot. Document.
- Retune LevelBook to the targets above (denser waves, mixed fronts, formations that create cascade chances: lines and
  clusters arriving together). Endless and daily retuned to match world 2–3 pressure.
- `Glint/Core/Achievements.swift`: `struct AchievementDef { let key: String; let id: String /* glint.ach.<key> */;
  let title: String; let blurb: String; let points: Int }` and `enum Achievements { static let all: [AchievementDef];
  static func earned(stats: DawnStats, mode: PlayMode, outcome: SessionPhase, progressStars: Int,
  levelsWon: Set<Int>) -> [String] }` with the 10 keys in docs/appstore/achievements.md, written as `def("<key>", …)`
  entries (the ASC tool greps that). Read achievements.md for exact keys, titles and conditions.
- Keep every test green; update numbers that change. Notes → `design/notes/core-R2.md` with the new balance table from
  your Node sim (update the sim too).

## Scene engineer
- Crease shade art: a dark soft seam across the garden's first 12 % with a cool rim where light stops; glooms with
  `d < Tuning.creaseShade` drawn sunk (lower half hidden, eyes peeking and blinking), a little ripple when they emerge.
- Replace the sun's star with a small, tasteful lens glint (a soft cross flare a fraction of the sun's size, slowly
  twinkling) plus a subtle hot spot on the glass where the band leaves the mirror.
- Juice pass: pops slightly bigger and brighter (a short white flash + ring + 10–16 sparks + 3–5 petals), chain ×n text
  with a scale bounce, a brief light swell along the band on a Sweep, 1–2 frames of hit-stop feel (scale squash) on
  brute pops. Glooms 15 % bigger on phones. Gloom eyes track the band (look towards it).
- Expose `func hudSafeRects(layout:) -> [CGRect]` = flower rects (SwiftUI coords) for the App's overlap test.
- Notes → `design/notes/scene-R2.md`.

## App engineer
- Move the HUD per Decisions; check with `GardenScene.flowerRects`/`hudSafeRects` in a test that no HUD rect overlaps a
  flower in all four layouts on the Duo size (951 × 669 / 669 × 951) and a phone (402 × 874).
- Fix the level tabs: no truncation at 402 pt (two-line or shorter labels: "Meadow", "★ 24/30").
- Game Center: `GameCenterManager` gains `static let achievementIDs: [String]` (= `Achievements.all.map(\.id)`) and an
  `enum Leaderboard { static let endless = "glint.endless"; static let daily = "glint.daily"; static let stars =
  "glint.stars" }` (exact literals: the ASC tool greps them). Report earned achievements at Results (banners held until
  the Results card), submit total stars to `glint.stars`.
- `screen=badges` demo: render 10 achievement badges (SwiftUI views: a medallion per achievement with its own
  illustration, dawn palette) to `Documents/badges/glint.ach.<key>.png` (1024², opaque) and print
  `GLINT-T badges done 10`. Add a `badges` scenario line to `ci/scenarios.txt` (`20-badges|screen=badges|8|…|GLINT-T
  badges done`) and copy `Documents/badges/` into `ci-screens/badges/` — tell the founder-agent which CI step to add.
- Reduce motion defaults to the iOS setting. Notes → `design/notes/app-R2.md`.

## R2 addendum (after design/REVIEW-1.md, the critic panel: 5 / 4 / 5 / 4)
- **Cloud shadows (Core + Scene), from L11.** `DawnSnapshot.shades: [ShadeState]` (Contracts, founder-edited): clouds
  drifting across the mirror's sky cast shade stripes on the band. Light × (1 − strength) inside, soft 0.03 edge in u.
  1–2 at a time, half-width 0.08–0.16, drifting 0.04–0.10 u/s, telegraphed (they slide in from an edge). World 3 more
  and wider. Glooms under a shade are safe: choose who and when. Include it in the retune.
- **Flower edge at 135°** (was 145°): `Tuning.edgeAngle = 135`, band = (θ−80)/55. The danger zone must sit where the
  hinge still holds. Drag cap `Tuning.dragSpeedCap` 2.4 → 1.4 d/s (phones mustn't be easier).
- **The light is a pool, not a slab (Scene).** Additive, soft, the grass visible through it; a faint light cone from
  the mirror's crease edge to the band; a warm fading trail where the band just was. Fireflies lime and distinct; no
  white sprinkles in the grass (they read as fireflies).
- **Lever = band (Scene + App).** The phone lever's knob maps 1:1 to the band (track ends = bandMin…1), and the band
  gets a small grip handle at its edge on phones. No lever when `fold=1` (demo) or on a Duo.
- **No control within ±28 pt of the crease (App)**: Home's Play sat across the crease in the Duo split frame. A test
  checks every menu's buttons against the crease band on Duo sizes.
- **Icon (App):** the CI-rendered icon is solid black (SKView offscreen, "no drawables"). Render `AppIconArt` with
  SwiftUI `ImageRenderer` (no SpriteKit) and have the demo log `GLINT-T icon dark` if the mean luminance is < 0.08.
- **Teaching (App):** hint lines sit on the garden with a small arrow at the thing (not on the sun). A lost level shows
  one tip from what ate the flowers (brutes: "Follow the big ones as they walk"; wisps: "Sweep the flocks fast";
  hoppers: "Catch hoppers after they land"; clouds: "Wait for the cloud to pass"). Today's Dawn shows a day streak
  (Home card + cover display).
- **Fold demos (App):** with `fold=1` on a phone sim the pilot must drive the band (it read `angle -1`, band stuck near
  the crease).
