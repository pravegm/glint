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

## Thu 29 Oct: the night gap, then R3
- R2 green (CI 40789455196: 183 tests, 22 frames, 10 badges, icon renders). Duo sim R2 (40793416148): 6/7 PASS;
  PAUSE-SHUT ran on a level 1 that was already won (a parked band at 0.25 wins it: the camping problem the panel
  found). First real 951×669 book-pose frames look right; the Duo Home frame was the bare launch colour (re-shoot added).
- Critic panel R2 (design/REVIEW-2.md): 6/5/5/5 → P0: camping at ~91° still wins world 1, black boxes under submerged
  glooms, grass light still a slab, world 1 can't be lost.
- **The session process died ~00:40 and nothing ran until 10:00** (agents died with it). The founder asked why; the
  machine is now kept awake for the session (keep-awake, session_idle) and work stays in flight.
- R3 (design/ROUND-3.md): submerged travel to authored surfacing depths, parked-pilot balance test, world-1 stakes,
  ★3 score target, band core ±0.065, light pool on grass, warm grounds (no blue), icon redrawn as a brass hand mirror
  catching the sun, ASC tool "all" vs "allStars" fix.
- R3 green (CI 40859397563, 236 tests). Parked band loses L6/L11/L21 at every depth on CI. Curve (CI, 6 seeds): 0.3
  loses flowers from L6, wins ~1/6 in Harbour; 0.6 wins all but L29–30 (5/6); 0.9 wins all.
- Duo R3 (40864118921): 6/7 PASS; PAUSE-SHUT ran on a level 8 already LOST (holding still now loses — anti-camping
  works). Script reordered (pause right after the mid band). Duo Home frame now draws (6 MB).
- Panel R3 (design/REVIEW-3.md): 7/5/5/6, "not yet": fail path unproven, L1–5 no stakes, cliff at L21, fireflies
  unspareable, a few look-alikes, book-pose thumb room. → design/ROUND-4.md. R3b (results overflow, built lost
  fixtures, map path, grass light) done, uncommitted until R4 lands.
- R4 green (CI 40868010079): 249 tests, every frame + expect (lost fixtures really lose, won=0). Per-world (CI):
  0.3 wins 100 % / 87 % / 18 %, 0.6 100 / 100 / 97 %, 0.9 100 % everywhere with ★★★ 95–98 %; fireflies scorched
  0.6 ≤ 0.7/level, 0.9 ≤ 0.05. TestFlight release-check (40871729218) green: Release archive builds, no demo strings.
- Founder (midday): "activate TestFlight now". Waiting on the founder's bundle ID + app record + the 4 secrets.
- Founder did the bundle ID, app record and 4 secrets (29 Oct ~13:00). **TestFlight 1.0 (2) uploaded** (run
  40878725064; archive unsigned + ad-hoc entitlements, Game Center entitlement in the App
  Store signature). Apple processing next.
- R5 (founder device feedback: "slow in the beginning", "a little easy"): action within 1 s, empty field ≤ 2.3 s
  (test-enforced), L1–5 35–50 s, ramp ~3 levels earlier. CI per-world: 0.3 wins 90 / 68 / 7 %, 0.6 100 / 100 / 90 %,
  0.9 100 % (★★★ 100 / 98 / 88 %). QA sweep: 4 reviewers (design/QA-R5-*.md), ~60 findings fixed (save on sunrise,
  cover pause without hinge, portrait-only phones, Mac as phone, VoiceOver light control, FX pools, audio interruption
  repair…). 285 tests. iPhone SE fallback captures added to CI.
- R5 regression caught by the Duo sim (40896758284: Duo locked onto drag; the hinge API's early nil) → fixed; Duo sim
  40911325933 **7/7 PASS** for the first time. Store pipeline trial OK (9/10, empty-garden frames → busy freezes).
- TestFlight build 3 (R5) VALID. ASC push (40921737131, 40926210238, 40928662647): listing, categories (Arcade isn't
  on Apple's list → Action + Casual), age rating, review details, Game Center (enabled; 10 achievements with badges,
  3 leaderboards) attached to the draft 1.0 submission, header + search art, price, accessibility. **The featuring
  nomination was submitted by the first push** (metadata had submit: true; I hadn't checked) — told the founder; the
  tool now keeps nominations as drafts. Store frames: stage= moments (5/8 land; daily, Long Night, fireflies retimed).
- Store frames: stage= moments; demo freezes now hold the scene. Store run 40941504707: 6.9" 10/10, 6.3" 10/10,
  Duo 10/10, header + search art OK. **Uploaded to App Store Connect** (asc 40946051208): all three sets for en-GB and
  en-US, header and search art. Build 3 attached. Founder-only steps are in docs/SUBMISSION.md.
