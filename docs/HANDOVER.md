# Glint: handover for the founder

*Living document. Last updated Thu 29 Oct 2026 (round 3 in progress).*

## What it is
**Glint: Sun Mirror ("Catch the sun, pop the shadows").** Your sixth Duo game. £1.99, no ads, no in-app purchases,
no data collected, rated 4+.
- **The top half of the phone is a mirror.** Open the phone and it catches the sunrise, throwing a band of light across
  the bottom half (the garden). The wider you open, the further the light reaches; close a little and it comes back.
  Shut = dark.
- **Shadows** tunnel out of the crease and surface in the garden, then creep towards your five flowers (your lives).
  Light pops them. Pops in a row climb a musical scale; three at once is a **Sweep**.
- **Five kinds:** murk (basic), wisp (quick, in flocks), brute (big: follow it as it walks), splitter (pops into two
  wisps), hopper (hops when the light touches it).
- **Fireflies are friends:** don't burn them, and they replant a lost flower.
- **Clouds** (from Rooftops) drift across the sun and cut gaps in your light: shadows under a cloud are safe.
- **30 levels** in three worlds (Meadow lawn, Rooftops tiles, Harbour boardwalk), each a sunrise. Stars: all five
  flowers plus a score target for the third star. **Long Night** (endless, moonlit) and **Today's Dawn** (daily, with
  a streak). Game Center: 3 leaderboards, 10 achievements with drawn badges.
- **Every iPhone plays.** Without a hinge you drag to aim the light (a brass rail and grip show where it is).

## Why this idea
`research/01-market.md`: no Duo app (or any hinge/lid app) uses the fold to aim light. The hinge angle is a precise,
continuous aim used in both directions, which none of your other five games do. Name check: "Glint" is clear in
games; a UK fintech called Glint is in Finance (different class).

## Where it stands
- **Rounds 1–2 built and green on GitHub's Mac** (183 automated tests). Round 3 is in progress.
- **iPhone Duo simulator with a real hinge** (the `hinge` tool): the level waits for a shut phone, the cover display
  shows, opening lets the light in, the light follows the phone both ways (108° → half way, 135° → the flowers), and
  shutting pauses.
- **Critic panels** (Apple-juror / game-feel / Duo / first-time player): R1 5·4·5·4, R2 6·4·5·5. R3 targets their
  P0s: no "park the phone at one angle and win", world 1 with real stakes, the light as a soft pool on grass, a
  clearer icon, fixtures that prove the loss tips and streak.
- **Store kit ready to fill in:** listing, keywords, review notes, privacy answers, achievements, press kit, website
  (`docs/appstore/`, `docs/site/`), the App Store Connect tool (`asc.yml`) and the screenshot pipeline (`store.yml`).

## What only you can do (when you're ready for TestFlight; `docs/LAUNCH-RUNBOOK.md` has every click)
1. Turn on GitHub Pages (Settings → Pages → main → /docs) and check Issues are on. (§0)
2. Trademark glance for GLINT, register the bundle ID **com.pravegm.glint** with Game Center, create the app record
   **Glint: Sun Mirror** (SKU glint-2026, English (U.K.)). (§1)
3. Add the 4 App Store Connect secrets to pravegm/glint, the same values as your other games. (§2)
4. Tell Claude; Claude runs the listing push, the screenshots and TestFlight, then you do the Duo test (§5).

## How to give feedback
One line per thing in chat is enough: "the light lags", "level 9 too hard", "can't see the shadows", "sound too quiet".
Settings › About › hold the version for 2 s copies a diagnostics log (hinge trace included) you can paste.
