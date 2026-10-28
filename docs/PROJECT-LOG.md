# Glint project log

## Wed 28 Oct 2026 (evening): kick-off
- Founder brief: a sixth Duo-first paid game (~£2), unique vs Squish/Brim/Swoop/Hush/Snapjaw, built unsupervised;
  launch-ready by the morning of 29 Oct. TestFlight is the founder's step in the morning.
- Concept chosen by the founder-agent: **the top half is a mirror**; the hinge angle aims a band of sunlight across the
  garden half (literal mapping, both directions, mid-range angles only). Alternatives considered: lip-sync puppet
  (crowded: ChompDuo/Snapjaw), drawbridge (unique but needs repeated flat ↔ fold, which triggers the iOS blur).
- Market + name research (research/01-market.md): no hinge app aims light; "Glint: Sun Mirror"; the hinge only holds
  position ~15–145°, so the band reaches the flowers at 145°.
- Repo pravegm/glint created private (guard); probe run 40775864907 refused by billing; the founder made it public.
- Round 1 started: Core, Feel, Scene, App engineers in parallel against design/ARCHITECTURE.md; launch lead on the
  store kit; CI (ci.yml, duo.yml + lean ci/duo.sh, testflight.yml, tf-status.yml) ported by the founder-agent.

## Wed 28 Oct, 22:45–23:10: R1 green first time
- CI 40782324566: build + 158 tests green, 19/19 frames. Balance (CI = Node sim): skill 0.3 wins every level 1–16;
  world 3 loses at 0.3. Frames: lovely garden/mirror/menus; issues → design/ROUND-2.md (empty garden from crease
  camping, sun star, HUD over flowers, truncated tabs). ASC tool failed only on the missing achievement IDs (R2).
- Duo sim run 40785108096 started (ci/duo.sh hinge checks). R2 in flight (Core, Scene, App, store pipeline) plus a
  critic panel on the R1 frames (design/REVIEW-1.md).
- Duo sim run 40785108096 (R1, real hinge via the hinge CLI): START-CLOSED, COVER, BAND-MID (112° → 0.474),
  BAND-EDGE, BAND-BACK, PAUSE-SHUT all PASS. OPEN-PROMPT "failed" only because the open prompt already showed while
  shut (script now checks from the shut). No frames: the Duo needs `--display` for screenshots (fixed: probe like
  Snapjaw). Check angles moved to the 135° edge for R2.
- Critic panel R1 (design/REVIEW-1.md): 5/4/5/4. P0s folded into R2 (addendum): cloud shadows (lateral choice), light
  as a soft pool + cone, edge 135°, lever = band, nothing on the crease, black CI icon, hints on the garden, loss tips,
  daily streak. Store pipeline ported (store.yml, ci/store-*, ci/duo-store.sh).
