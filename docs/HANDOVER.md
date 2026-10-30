# Glint: handover for the founder

*Last updated Fri 30 Oct 2026 (release on approval; round 5, TestFlight build 3).*

> **Read first: Apple 4.3 (spam) risk, 30 Oct 2026.** On 29 Oct Apple rejected **Swoop** and **Snapjaw** under
> guideline 4.3 ("spam": one account shipping many similar apps). Guideline 4.3(b) says repeated cases "may lead to
> removal from the Apple Developer Program", which would take down every app on the account (Squish, Brim, Hush
> included). **Recommendation: do not submit Glint until Swoop’s and Snapjaw’s 4.3 replies are answered and at least
> one clears.** Everything is ready, so submitting later costs nothing. If you submit anyway, answer any 4.3 honestly
> (shared code, AI-assisted development) with a phone video of the hinge play; never resubmit unchanged.


## What it is
**Glint: Sun Mirror ("Catch the sun, pop the shadows").** Your sixth Duo game. £1.99, no ads, no in-app purchases,
no data collected, rated 4+.
- **The top half of the phone is a mirror.** Open the phone and it catches the sunrise, throwing a band of light across
  the bottom half (the garden). Open wider and the light reaches further. Close a little and it comes back. Shut means
  dark, and the game pauses.
- **Shadows** tunnel out of the crease, surface in the garden and creep towards your five flowers (your lives). Light
  pops them. Pops in a row climb a musical scale. Three at once is a **Sweep**.
- **Five kinds:**
  - murk: the basic one
  - wisp: quick, comes in flocks
  - brute: big, so follow it as it walks
  - splitter: pops into two wisps
  - hopper: hops when the light touches it
- **Fireflies are friends.** A quick pass of light is safe, but lingering burns them. If one reaches the flowers it
  replants a lost flower.
- **Clouds** (from Rooftops) drift across the sun and cut gaps in your light.
- **Levels and modes:**
  - **30 levels** in three worlds (Meadow lawn, Rooftops tiles, Harbour boardwalk), each one a sunrise of 35–95 s.
  - Stars: all five flowers, plus a score target for the third star from level 4.
  - **Long Night:** endless and moonlit.
  - **Today's Dawn:** daily, with a streak.
  - Game Center: 3 leaderboards and 10 achievements, with drawn badges.
- **Other iPhones (iOS 18+):** you drag to aim the light. A gold grip on a brass rail shows where it is. Phones stay
  portrait. VoiceOver can move the light by swiping up or down.

## Where it stands
- **Rounds 1–5 built and green on GitHub's Mac:** 285 automated tests, including:
  - a test that no level has more than 3 s with nothing happening;
  - a test that parking the light at one angle loses;
  - balance tables from pilot players at three skill levels.
- **Your device feedback on build 2** ("slow in the beginning", "a little easy") is in build 3:
  - every level starts within a second;
  - levels 1–5 are 35–50 s;
  - difficulty ramps about 3 levels earlier.
- **Difficulty, by pilot skill** (win rate in Meadow / Rooftops / Harbour):
  - casual: 90 / 68 / 7 %;
  - good: 100 / 100 / 90 %;
  - strong: 100 % everywhere, ★★★ 88–100 %.
- **iPhone Duo simulator with a real hinge: 7 of 7 checks pass:**
  - a level waits for a shut phone;
  - the cover display shows;
  - the light follows the hinge both ways (108° = half way, 135° = the flowers);
  - shutting pauses and opening resumes.
- **QA sweep:** four reviewers covered app flow, scene and sound, the store and a first-time player
  (`design/QA-R5-*.md`). About 60 findings are fixed, including:
  - wins now save the moment the sun rises;
  - a Duo whose hinge doesn't report still pauses when shut;
  - Mac and iPad behave as a phone;
  - audio repairs itself after calls.
- **Critic panels:** R1 5·4·5·4 → R2 6·4·5·5 → R3 7·5·5·6. Everything they flagged since is in builds 2–3.
- **TestFlight:** build 2 (your test) and **build 3** are both VALID.

## What only you can do
See `docs/SUBMISSION.md` for every click. **Already in App Store Connect (pushed by Claude):** the listing
(both English locales), keywords, categories, age rating 4+, review notes, the 6.9-inch, 6.3-inch and Duo screenshot
sets, the header and search art, Game Center (10 achievements with badges, 3 leaderboards) and build 3. The featuring
nomination was submitted by the tool on 29 Oct by mistake; on 30 Oct its date moved to Tue 24 Nov (release on approval): check it under
Featuring → Nominations.
1. **TestFlight:** App Store Connect → TestFlight → your group → **+** → add **build 3**. To skip this next time, turn
   on the group's automatic distribution.
2. **Website:** turn on GitHub Pages (Settings → Pages → main → /docs). Apple needs the support and privacy pages.
3. **App Privacy** ("no data"), **Pricing** (£1.99, untick Mac and Vision Pro), **EU trader status**.
4. **Submit for Review.** Release is automatic on approval (your choice, 30 Oct). Read the 4.3 note at the top first.

## Feedback
One line per thing in chat is enough. Settings › About › hold the version for 2 s copies a diagnostics log (the hinge
trace included) that you can paste.
