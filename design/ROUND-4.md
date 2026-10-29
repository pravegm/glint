# Round 4 (founder brief, Thu 29 Oct midday)

R3 green (CI 40859397563, 236 tests). Panel R3 (design/REVIEW-3.md): 7 / 5 / 5 / 6, "not yet". Already fixed in R3b
(uncommitted until the Duo run ends): results overflow, built lost fixtures, map path, grass light retune.

## Core
1. **Curve:** L1–3 stay gentle (first session), but ★★★ there needs a real score (0.3 skill ★★★ ≤ 50 %). L4–5: a
   deep surfacer group and a first brute by L4, so skill 0.3 loses ~0.5–1 flower. Rooftops harder (0.3 wins 60–80 %,
   loses 1.5–2.5), L21–22 softer (0.3 wins ~30 %), so there's no cliff: 0.3's win rate should fall smoothly
   ~100 % → ~60 % → ~15 % across the worlds. Refit World 3 `starScore` so 0.9 gets ★★★ ≥ 70 % on every level.
2. **Fireflies must be spareable.** Pilots burn 2–6 per level even at 0.9. Changes: fireflies fly at their own depth
   rhythm (they appear between waves, in gaps), scorch only in the band's full core (not the soft edge), tolerance
   0.6 s cumulative (decay 0.8/s), and when first lit they dart outward (+0.08 in 0.3 s) — so a sweep past one is safe
   and lingering isn't. Target: 0.6 burns ≤ 1 per level, 0.9 ≤ 0.3. The pilot learns to skip them.
3. L1's first murk surfaces at d ≈ 0.3 within 1.5 s of the first light (the start card time counts as waiting).
4. BalanceTests: print a per-world summary line `GLINT-BAL world=<w> skill=<s> winrate=<x> flowers=<y> three=<z>
   scorched=<q>`.

## Scene
5. **Submerged reads as underground:** no light highlight or rim on submerged glooms even under the band (they're
   dim, desaturated, partly hidden by soil), a distinct ripple, and never drawn over the mirror frame or the crease line.
6. **Nothing else looks like a gloom:** Harbour puddles become long thin streaks along plank lines (never capsules);
   Rooftops chimney pots lose the two dark round holes (use a single rectangular flue with a cap).
7. **Book pose thumb room:** the flower row sits ≥ 60 pt in from the garden's outer edge on Duo book layouts (the
   right thumb rests there); the garden's d = 1 line moves in accordingly (layout-driven, not a magic number per
   device) — coordinate with App if `GardenLayout` needs an inset (founder will add `flowerInset` to Contracts if
   asked; prefer handling it inside the Scene's own mapping and telling App via `hudSafeRects`).

## App
8. CI proves the fail path: the `results=lost` fixtures print `GLINT-T result … won=0`; `ci/scenarios.txt` expects it.
   Frame 19 (fireflies hint) spawns a firefly before the hint (a demo key `spawn=firefly` handled by GameController via
   Core's API — ask Core if a hook is needed; else pick a level/time where one is on screen).
9. Duo book pose: the flower column under the right thumb → follow Scene's inset; keep pause/score clear.
