# Glint launch runbook (for the founder)

*Written Wed 28 Oct 2026 by the launch lead, adapted from Snapjaw's runbook (`C:\Users\59527\Trap\docs\LAUNCH-RUNBOOK.md`). This is the only document you need to follow. It lists **only the steps that need your own GitHub or Apple login, or your Duo**; Claude does everything else, including putting the whole store listing into App Store Connect with the App Store Connect tool. Each step says exactly where to click and what to type. Everything Apple sees lives in `docs/appstore/`. Whenever a step says "tell Claude", a one-line message in chat is enough.*

**Launch: Tuesday 15 December 2026, about 08:00 UK time, released by you (manual release).** Brim launches Tue 17 Nov, Hush Tue 1 Dec and Snapjaw Tue 8 Dec, so Glint takes the next free week and no two games share one.

A few words used below:
- **Repo** (repository): Glint's project page on GitHub, `github.com/pravegm/glint`. It holds the code and these documents.
- **Actions**: GitHub's build robot. It turns the code into an app on Apple's newest Xcode, because your Mac can't.
- **Workflow**: one of the robot's jobs (for example "TestFlight"). You start one from the **Actions** tab with the grey **Run workflow** button.
- **Secret**: a password-like value stored in the repo's settings, which only the build robot can read.
- **TestFlight**: Apple's app for installing test builds on your own phone before launch.

---

## Timeline

| When | What you do | Section |
|---|---|---|
| ~~Wed 28 Oct~~ | ~~Make the repo public~~ **Done by you on 28 Oct.** Nothing to do | — |
| **Today or tomorrow (Wed 28 – Thu 29 Oct)** | Turn on the website and check Issues are on (5 minutes) | §0 |
| Wed 28 – Fri 30 Oct | The trademark check, then register Glint with Apple and create the app record (30 minutes) | §1 |
| Wed 28 – Fri 30 Oct | Add the 4 GitHub secrets (10 minutes) | §2 |
| When Claude says "first green build" (early November) | Turn on Game Center, then run the App Store Connect tool twice (plan, then push). This also sends the featuring nomination (due by **Mon 23 Nov**) | §3 |
| When Claude says the game is ready to try (November) | Run the TestFlight build (2 clicks) and install it | §4 |
| The same day or weekend | The 15-step Duo test (about 20 minutes), then send Claude your notes | §5 |
| Until about Fri 4 Dec | Claude tunes from your notes; you repeat §4–§5 on each new build | §5 |
| **Tue 17 Nov** | **Brim's launch day.** No Glint work today | — |
| **Tue 1 Dec** | **Hush's launch day.** No Glint work today | — |
| **Sat 5 – Sun 6 Dec** | The four clicks only you can do, and a check of what the robot filled in (one evening) | §6a–b |
| Mon 7 Dec | Claude: code freeze, the final build and the screenshots | — |
| **Tue 8 Dec** | **Snapjaw's launch day.** No Glint work today | — |
| **Wed 9 Dec** | The last robot run, pick the final build, **submit for review** with manual release (last safe day: Fri 11 Dec) | §6c–e |
| ~Thu 10 – Fri 11 Dec | Apple approves (usually 24–48 hours). Glint then waits for you | §6e |
| Sat 12 – Mon 14 Dec | Promo codes for creators (private emails only: it's Snapjaw's week) | §7 |
| **Tue 15 Dec, ~08:00 UK** | Press **Release This Version**. Launch-day steps | §7 |

**If Glint isn't submitted by Fri 11 Dec,** or if Hush slips to Tue 15 Dec (Snapjaw's kit names 15 Dec as Hush's fallback): move the launch to **Tue 19 Jan 2027** (Tue 12 Jan is Snapjaw's fallback, and the Christmas weeks are out). Tell Claude: the nomination's date changes too.

---

## §0. Turn on the website, and check Issues (today; 5 minutes)

The repo is already public (you did it on 28 Oct), so the build robot can run. Apple needs a working support page and privacy page before it accepts the app. They're already written; this puts them online for free.

### 0a. Turn on GitHub Pages

1. Go to **github.com/pravegm/glint** and sign in.
2. Click **Settings** (the gear tab along the top of the repo, on the right).
3. In the left list, under "Code and automation", click **Pages**.
4. Under **Build and deployment**, **Source**: choose **Deploy from a branch**.
5. **Branch**: choose **main**, then in the folder box next to it choose **/docs**. Click **Save**.
6. Wait 1–2 minutes, then open these on your phone. All three must load:
   - Home: **https://pravegm.github.io/glint/**
   - Support: **https://pravegm.github.io/glint/support.html**
   - Privacy: **https://pravegm.github.io/glint/privacy.html**

   (Each one forwards to the real page under `/site/`, which is fine.)

*If you see "404"*, wait 5 more minutes and reload. If it's still missing, tell Claude.

### 0b. Check Issues are on

Support is through **GitHub issues** (`github.com/pravegm/glint/issues`), the same as the sister games, so there's no email address to set up.
1. github.com/pravegm/glint → **Settings** → **General** (top of the left list).
2. Scroll to **Features**. **Issues** must be ticked. If it isn't, tick it (it saves by itself).
3. *Check:* the repo's top tabs now include **Issues**.

**Tell Claude "the site is up".**

---

## §1. Trademark check first, then the app record (about 30 minutes, once)

### 1a. Trademark check for the name "Glint" (10 minutes, before anything else)

The research (`research/01-market.md` §4) found no live game called Glint, but nobody has checked trademarks. It's a quick search, not legal advice.

**Good to know before you search:** there is a well-known UK company called **Glint** (Glint Pay Services Ltd, "Glint | Buy Gold Instantly", an FCA-regulated gold and payments app). It is very likely to own GLINT marks, but for **financial services**, which are a different trade-mark **class** (class **36**, and possibly class 9 *for finance software*). A mark only blocks you in the classes and goods it covers, so a fintech's GLINT is not a problem for a game **unless** it is registered for games or entertainment. That is exactly what this check looks for. Microsoft's "Viva Glint" (HR software) is the same story.

1. **UK:** go to **https://trademarks.ipo.gov.uk/ipo-tmtext** (UK IPO, "Search for a trade mark"). Search for the word `GLINT`. Under "Classes", tick **9** (software and downloadable games), **28** (games and toys) and **41** (entertainment and online games). Search.
2. **US:** go to **https://tmsearch.uspto.gov** (USPTO Trademark Search). Search `GLINT`. Use the filters to show **Live** marks only, and look at classes **009**, **028** and **041**.
3. For each result, look at three things: is it **live / registered**? Does its list of goods mention **games, game software or entertainment**? Who owns it? (A class 9 mark that only says "software for buying gold" or "financial software" is fine.)
4. Tell Claude what you found, in one line per live match (for example "UK: GLINT, class 9 and 36, Glint Pay, financial software, registered"), or "nothing live for games".

What happens next:
- **Nothing live for games in 9, 28 or 41** (finance and HR marks don't count): carry on with "Glint: Sun Mirror".
- **A live GLINT mark for games or entertainment:** stop before 1c. Claude switches to the research's runner-up, **"Dawnlight: Sun Mirror"** (home-screen name "Dawnlight"), and updates every page.

### 1b. Register the bundle ID (Glint's unique name inside Apple), with Game Center

Go to **developer.apple.com** → **Account** → **Certificates, IDs & Profiles** → **Identifiers** → the blue **+**.
1. Choose **App IDs** → **Continue** → **App** → **Continue**.
2. Description: `Glint`
3. Bundle ID: choose **Explicit** and type `com.pravegm.glint`
4. In the **Capabilities** list, tick **Game Center** (nothing else).
5. **Continue** → **Register**.

### 1c. Create the app record

Go to **appstoreconnect.apple.com** → **Apps** → the blue **+** (top left) → **New App**.

| Field | Type or pick |
|---|---|
| Platforms | **iOS** |
| Name | `Glint: Sun Mirror` (if it says the name is taken, try `Glint: Sunlight Mirror`, then `Glint: Catch the Sun`, and tell Claude which one worked) |
| Primary Language | **English (U.K.)** |
| Bundle ID | pick `com.pravegm.glint` from the list (if it's missing, wait 5 minutes and reload) |
| SKU | `glint-2026` |
| User Access | **Full Access** |

Click **Create**.

### 1d. Tell Claude the Apple ID

In the new app, open **App Information** (left list) and copy the **Apple ID** number (10 digits). Send it to Claude: it becomes the App Store link `https://apps.apple.com/app/id<that number>` in the press kit, the website and the posts.

---

## §2. Connect GitHub to Apple: the 4 secrets (10 minutes, once)

GitHub builds Glint for you on Apple's newest Xcode, and fills in the App Store listing for you. It needs four secrets: **the same four names and values you put into the sister repos** (`pravegm/snapjaw`, Swoop, Squish, Brim and Hush). One Apple key works for all your apps.

You don't need to make any certificate or profile. The build uses **Apple's cloud-managed distribution certificate** through the API key, as the sister games do.

**2a. Gather the four values.** GitHub never shows a saved secret again, so you can't copy them out of Snapjaw's settings. Get them from the source:

| Secret name | Where to find the value |
|---|---|
| `ASC_KEY_ID` | App Store Connect → **Users and Access** → **Integrations** → App Store Connect API → **Team Keys**: the "Key ID" column of the key you used for the other games |
| `ASC_ISSUER_ID` | Same page, the **Issuer ID** shown above the table |
| `ASC_PRIVATE_KEY` | The `.p8` file you downloaded when you made that key. Open it in TextEdit (or Notepad) and copy **all** of it, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `APPLE_TEAM_ID` | developer.apple.com → Account → **Membership details** → Team ID (10 characters) |

*Can't find the `.p8` file?* Apple only lets you download it once. Make a new key on the same Team Keys page: **+**, name `Studio CI`, Access **Admin**, **Generate**, **Download** the file straight away, and use the new Key ID. Don't revoke the old key: the other games keep using it.

**2b. Add them to Glint's repo.** github.com/pravegm/glint → **Settings** → **Secrets and variables** (left list) → **Actions** → **New repository secret**. For each of the four: type the name exactly as above (capitals and underscores), paste the value, click **Add secret**. When you're done the list shows four names.

**Tell Claude "secrets in".**

---

## §3. Game Center on, then the App Store Connect tool (when Claude says "first green build")

The App Store Connect tool is already in this repo (`tools/appstore/`, run by the **App Store Connect tool** workflow). Claude tells you when to run it: once the first build is green and the app draws the 10 achievement pictures, because the tool uploads them with the achievements.

*If it stops with a red cross at **Check the secrets exist** ("App Store Connect is not set up") or at **check** ("No App Store Connect app record"):* it is telling you a one-time step is missing. The run's summary page says which: the app record for bundle ID `com.pravegm.glint` (§1b–§1c) or the 4 secrets (§2). Do that step, then run it again. Nothing was changed.

**3a. Turn on Game Center.** appstoreconnect.apple.com → Apps → Glint: Sun Mirror → **Services** (in some layouts **Features**) → **Game Center** → turn it on.

**3b. Dry run.** github.com/pravegm/glint → **Actions** → **App Store Connect tool** (left list) → **Run workflow** → tick **Contact App Store Connect** → mode **plan** → leave the other boxes as they are → **Run workflow**. It changes nothing. When it shows a green tick (about 10 minutes), **tell Claude "plan done"**. Claude reads what it would change and tells you whether to go ahead.

**3c. The real run.** Same steps with mode **push** → **Run workflow**. Green tick = done. A red cross: send Claude the link; running it again is safe (it only changes what's different).

This one run fills in: the name, subtitle, description, keywords, promotional text and web addresses (English (U.K.) and (U.S.)); the categories (Games: Arcade + Casual); the age rating answers (**4+**); the price (**£1.99**, base country United Kingdom) and the countries (everywhere except China mainland and Vietnam); **manual release**; the App Review notes (they open with "NO LOGIN") and your contact details (copied from Squish's record, never written into the public repo); **Game Center: the 3 leaderboards and 10 achievements with their pictures** (so TestFlight can show them); and the **featuring nomination**, which it submits for the 15 Dec launch. The screenshots come later (§6c).

*Check the nomination:* App Store Connect → the app → **Featuring** → **Nominations**: one nomination, status **Submitted**. It must be in by **Mon 23 Nov** (Apple wants 3 weeks' notice). If the robot couldn't do it, make it by hand: **Create Nomination**, copy every field from `docs/appstore/featuring-nomination.md`, press **Submit** (a saved draft doesn't count).

---

## §4. Run TestFlight (when Claude says the game is ready to try)

**4a. Run a build.** github.com/pravegm/glint → **Actions** (tab along the top) → **TestFlight** (left list) → **Run workflow** (grey button on the right) → keep branch `main` → in "What to test" type anything (e.g. `first Duo test`) → leave any other box as it is → **Run workflow**.
- About 20–30 minutes later the run shows a green tick. A red cross with "Missing repository secrets" means a name in §2b is misspelt; anything else, send Claude the link to the run.
- 10–30 minutes after the green tick, the build appears in App Store Connect → the app → **TestFlight**, first as "Processing". You won't be asked about encryption: that answer is already built in.
- **Always use Run workflow, never "Re-run" on an old run**: a re-run reuses the old build number, and Apple rejects the upload as a duplicate.

**4b. Install it (set up once).** App Store Connect → the app → **TestFlight** → **Internal Testing** → **+** → group name `Studio` → add yourself (your Apple Account email) → add the build. On the Duo, open Apple's **TestFlight** app (you have it from the other games) and tap **Install** next to Glint. Later builds appear there automatically. If you have a regular iPhone too, install it there as well for step 14.

---

## §5. The Duo test: 15 steps, about 20 minutes

**Why:** the light following the phone *is* the product, and only your Duo can tell us whether it follows your hand exactly, whether closing feels like a real pause, whether level 1 explains itself, and whether a Sweep feels as good as it should. Do this on the first TestFlight build and again on each new one.

**Before you start:** ringer **on**, volume about half, sitting at a table. If an older Glint is on the Duo, delete it first so you get the first-launch hints. **Screen recording** for steps 3, 6 and 9: swipe down from the top-right corner to open Control Centre and tap the round record button, **with the microphone on** (press and hold the button to turn it on). Tap the red time at the top to stop; the video goes to Photos. A phone video of the Duo from the side while you play helps even more (it shows the hinge and the screen together). If something goes wrong, carry on with the next step and write it down.

| Step | Do this | What should happen (note anything different) |
|---|---|---|
| 1 | Open Glint with the Duo **standing like a laptop** on the table. Look at Home for 10 seconds | A warm, illustrated Home with the live garden playing behind it, a big **Play** button. Does it look like a game you paid for? |
| 2 | Tap **Play** (Level 1) without closing the phone | It says **"Close the phone to start"**. The outer screen, once shut, says **"Open the phone"** |
| 3 | **Start recording.** Close the phone fully, then open it **very slowly** all the way to wide open (take about 10 seconds), then back down to about a right angle | Shut: dark. Opening: light pools in the crease, then the band lifts out and moves steadily towards the flowers, reaching the far edge just before wide open. **Does the light follow the phone exactly, with no lag, no jumps and no shaking?** Going back down, does it come back the same way? |
| 4 | Hold the phone **perfectly still** in the middle for 5 seconds | The band stays put: no drifting, no wobble |
| 5 | Play Level 1 to the end without reading anything except what's on screen | **Was it obvious what to do?** Did "Open the phone to let the light in" and "Light the shadows" appear when you needed them and go away once you'd done it? Did you win? How many stars? |
| 6 | **Start recording.** Play Level 3 (wisps come in flocks). Sweep the light through a group in one smooth move | A burst of pops with **rising notes**, "Sweep!" and a chord, gold sparks and petals, a crisp tick in your hands for each pop. **Does it feel great?** Score 1–5 for sound, haptics and sparks |
| 7 | Mid-level, **close the phone fully** and wait 3 seconds. Look at the outer screen. Then open it again | It **pauses** at once; the outer screen shows **"Paused · open the phone to carry on"** and your score. Opening resumes after a short moment, with nothing lost. Did closing ever cost you a flower? |
| 8 | Mid-level, move the phone around a **right angle (about 90°)** for 10 seconds, back and forth | **No pause, no warning, no card** near 90°. Just the light moving |
| 9 | **Start recording.** Level 5 or 6 (brutes). Follow a brute across the garden by opening the phone at its pace | Can you keep the light on it smoothly? Does it steam and shrink? Is it satisfying when it finally pops? Did your wrist get tired? |
| 10 | Level 4 (fireflies). Let one firefly drift through the light quickly, then try to keep the light **off** another until it reaches the flowers | A quick pass is safe. Holding the light on one makes it flicker, then fizzle (a sad blip). One that makes it home **replants** a lost flower or blooms for points. Was it clear which dots are fireflies? |
| 11 | Turn the Duo sideways and hold it **like a book**; play a few seconds. Then Settings → **Swap halves**, and play again | Both poses play; the mirror and garden swap sides. Did one half of the screen blur for a moment when you started folding from flat? Which half, for how long? |
| 12 | Open the phone **completely flat** during a level | Nothing bad: the light just stays at the far edge. No warning |
| 13 | Flip the **silent switch on**, play a few seconds, then open **Settings** and try **Sound**, **Music**, **Haptics** and **Reduce motion** | Sound plays on silent (that's the plan). Do the switches work? With Reduce motion on, is the shimmer and shake gone? |
| 14 | **On a regular iPhone** (or lend yours to someone): play Level 1 and Level 6 by **dragging** | "Drag down to let the light in". Dragging anywhere moves the light like a trackpad and a **brass lever** on the mirror follows. Is it as fun as on the Duo? Anything that only makes sense on a Duo? |
| 15 | Play **5 levels in a row**, any you like | Then note: is the Duo **warm**? Hands or wrists tired? Did you want "one more"? Was world 1 too easy? |

**Send Claude this (copy, fill in, paste in chat), plus the recordings and any screenshots:**
```
Glint build NUMBER FROM TESTFLIGHT, iPhone Duo, iOS VERSION
1  Home looks premium 1-5:
2  "Close the phone to start" shown: yes/no   Outer screen said "Open the phone": yes/no
3  Light follows the phone exactly 1-5:    Lag: none / a little / too much    Jumps or shaking: never / sometimes / often
4  Still phone = still light: yes/no
5  Level 1 obvious without help: yes/no (where not)   Won: yes/no, stars
6  Sweep feels great 1-5:   Sound 1-5:   Haptics 1-5:   Sparks 1-5:
7  Closing paused at once: yes/no   Outer screen showed:    Resumed cleanly: yes/no   Ever lost a flower to closing: yes/no
8  Anything happened near 90 degrees: no / yes (what)
9  Following a brute felt smooth 1-5:   Wrist tired: no / a little / yes
10 Fireflies clear: yes/no   Quick pass safe: yes/no   Replant seen: yes/no
11 Book pose works: yes/no   Swap halves works: yes/no   Blur: left / right / none, for about N s
12 Flat was fine: yes/no
13 Sound on silent: yes/no   Switches work: yes/no   Reduce motion calmer: yes/no
14 Regular iPhone drag fun 1-5:   Lever follows: yes/no   Anything Duo-only on the phone:
15 Warm after 5 levels: no / a little / hot   Want one more 1-5:   World 1 too easy: yes/no
Best moment:
Worst moment:
Bugs (what you did, what happened):
Anything confusing:
```
In TestFlight you can also take a screenshot in Glint and tap **Share Beta Feedback**.

The release build is the one where every "should" above happens, step 3 scores 4 or 5, step 7 never costs anything, step 8 shows nothing, and comfort is fine.

---

## §6. Fill in the rest and submit (Sat 5 – Wed 9 Dec)

### 6a. The four clicks only you can do (Sat 5 or Sun 6 Dec; no robot can)

In App Store Connect → the app:
1. **App Privacy** (left list): **Privacy Policy URL** `https://pravegm.github.io/glint/privacy.html` → Save (the tool usually fills it). Then **Get Started** → "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app** → **Save** → **Publish**. The page now says **Data Not Collected**. (Why it's true: `docs/appstore/privacy.md`.)
2. **Family Sharing:** **App Information** (in some layouts Pricing and Availability) → Family Sharing → **Turn On** → confirm (it can't be turned off later, which is fine).
3. **Mac and Vision Pro:** **Pricing and Availability** → "iPhone and iPad Apps on Apple Silicon Macs": untick **Make this app available**; then "Apple Vision Pro": untick it too. **Save**.
4. **EU Digital Services Act:** **App Information** → **App Store Regulations and Permits** → **Digital Services Act** → if it asks, give the same trader answer as for your other games → **Save**.

### 6b. Check what the robot did (5 minutes)

- **Pricing and Availability:** **£1.99** with base country **United Kingdom**; the US shows **$1.99**. Every country **except China mainland and Vietnam**. Pre-order: off.
- **App Information → Age Rating:** the result says **4+**. If it says anything else, tell Claude before submitting.
- **App Information → Category:** Games, with **Arcade** and **Casual** (or **Action** and Casual, if Apple has dropped Arcade: that's expected).
- **The 1.0 page → App Review Information:** "Sign-in required" unticked, your contact details filled in, and **Notes** starts "NO LOGIN - this game has no accounts".
- **The 1.0 page → Version Release:** **Manually release this version** is chosen.
- **Services → Game Center:** 3 leaderboards (Long Night, Today's Dawn, Total Stars) and 10 achievements, each with a picture (for example **First Light** and **Firefly Gardener**).

### 6c. The last robot run (Wed 9 Dec, after Claude names the release build)

Claude makes the final screenshots on Mon 7 Dec (the **App Store screenshots** workflow), puts that run's number into the tool for you, and tells you the release build number. Then: **Actions** → **App Store Connect tool** → **Run workflow** → tick **Contact App Store Connect** → mode **push** → in **"Release build number"** type the number Claude gave you → if Claude also gave you a "header and search art" run number, type it in the box that starts **"ID of a store.yml run with a store-placements artifact"** → **Run workflow**. This uploads the screenshots (6.9", 6.3" and iPhone Duo, 10 each, the first one the Duo open like a book: one page the mirror catching the sun, the other the garden) and puts the build on the 1.0 page with Game Center attached. It refuses any set with a flagged or missing frame, so a green tick means every frame passed its checks. Green tick = done.

### 6d. Check the build and screenshots (Wed 9 Dec)

On the 1.0 page: **Build** shows the number Claude named (if it's empty: **+** → pick it → **Done** → **Save**). **Previews and Screenshots**: 10 in each size, the first one showing the Duo open like a book, the mirror on one page. In the **Game Center** section, all three leaderboards and all ten achievements are listed.

### 6e. Submit (Wed 9 Dec; last safe day Fri 11 Dec)

1. Click **Add for Review** (top right). If App Store Connect lists anything missing, send Claude a screenshot.
2. Click **Submit to App Review**.
3. Apple usually answers within 24–48 hours, by email.
   - **Approved:** the status becomes **Pending Developer Release**. Do nothing until launch morning (§7).
   - **Rejected:** don't worry, it's common for a first version. Copy Apple's whole message (App Store Connect → the app → **App Review**, or the email) and send it to Claude the same day. Claude writes the reply (ready-made answers are in `docs/appstore/review-notes.md`, "If rejected under…", including the 2.1 "demo account" one that caught Swoop) and tells you exactly what to paste and where.

---

## §7. Launch: Sat 12 – Tue 15 Dec

**Sat 12 – Mon 14 Dec:** App Store Connect → the app → **Promo Codes** → generate codes for the creators in `docs/appstore/social-launch.md` §4, and email them (`press-kit.md` email #5): they post from Tue 15 Dec. Keep a list of who got which. No public posts yet: it's Snapjaw's week.

**Tue 15 Dec, about 08:00 UK:**
1. App Store Connect → the app → the 1.0 page → **Release This Version** → confirm. It can take a few hours to appear in every country.
2. Open Glint's App Store page on your phone and check: price £1.99, **4+**, "Data Not Collected", the screenshots, Game Center.
3. **Accessibility labels:** App Store Connect → the app → **App Accessibility** → **Get Started** → **iPhone**. Tick only the labels `docs/appstore/accessibility.md` marks as passed (planned: **Differentiate Without Color Alone**, **Sufficient Contrast**, **Reduced Motion**; Claude confirms which). **Never tick Larger Text or VoiceOver.** Leave the rest unticked → **Publish**.
4. Post the launch posts from `social-launch.md` §2 once the page shows **Get** with the price, and send the Day 0 emails from `press-kit.md` (`social-launch.md` §4 says which).
5. Tell Claude **"Glint is live"**: Claude swaps "Coming soon" on the website for the real link.
6. Play Today's Dawn yourself and check your score appears on the Today's Dawn leaderboard.
7. For the next few days: App Store Connect → the app → **Ratings and Reviews**, and TestFlight's crash reports. Forward anything odd to Claude for 1.0.1.

---

## Reference: what the tool sets (no action needed)

Claude runs the App Store Connect tool (GitHub → Actions → **App Store Connect tool**; `tools/appstore/README.md`). It reads `docs/appstore/asc-metadata.json`, which is built from the docs (`node tools/appstore/build-metadata.js`), and changes only what differs. It never submits for review and never releases. The screenshots and the optional header and search art come from the **App Store screenshots** workflow (`store.yml`, manual only).

| What | Value | Source |
|---|---|---|
| Name, subtitle, privacy URL (en-GB and en-US) | `Glint: Sun Mirror`, `Catch the sun, pop the shadows` | `metadata.md` §1–2 |
| Categories | Games: Arcade + Casual (Action if Apple's list has no Arcade); secondary Entertainment | `metadata.md` §7 |
| Age rating | Every answer None / No: 4+ | `metadata.md` §8 |
| Version 1.0 | Copyright `© 2026 pravegm`; release **Manually release this version** | `metadata.md` §9 |
| Description, keywords, promotional text, support and marketing URLs (en-GB and en-US) | | `metadata.md` §3–5, §9 |
| App Review notes ("NO LOGIN" first), "no sign-in", the contact (copied from Squish's record, never in the repo) | | `review-notes.md` |
| Game Center | On; the 3 leaderboards and 10 achievements below, each achievement with its badge | `achievements.md` |
| Screenshots | 6.9" and 6.3" sets (portrait) and the iPhone Duo set (book pose), 10 each | `screenshots.md` |
| Price and availability | £1.99 (UK base; Apple sets $1.99 and the rest); every country except China mainland and Vietnam | `metadata.md` §9 |
| Featuring nomination | App Launch, publish date Tue 15 Dec 2026, **submitted** (by Mon 23 Nov) | `featuring-nomination.md` |

### Game Center items (created by the tool)

IDs can never be changed once created. These are the exact values (the same as `docs/appstore/achievements.md`).

**Leaderboards:**

| Leaderboard ID | Type | Reference name | Display name | Score format | Suffix | Sort | Submission |
|---|---|---|---|---|---|---|---|
| `glint.endless` | **Classic** | Long Night | Long Night | Integer | ` point` / ` points` | High to Low | Best score |
| `glint.daily` | **Recurring**: start **Mon 9 Nov 2026 at 00:00 UTC**, lasts **1 day**, repeats every **1 day** | Today's Dawn | Today's Dawn | Integer | ` point` / ` points` | High to Low | Best score |
| `glint.stars` | **Classic** (range 0–90) | Total stars | Total Stars | Integer | ` star` / ` stars` | High to Low | Best score |

**Achievements** (none hidden, none can be earned more than once, each with its 1024 × 1024 badge drawn by the app):

| Achievement ID | Title | Description before earning | Description after earning | Points |
|---|---|---|---|---|
| `glint.ach.firstlight` | First Light | Win your first sunrise. | The sun is up. The garden is yours. | 10 |
| `glint.ach.sweep` | Clean Sweep | Pop 3 shadows or more in one Sweep. | Three pops, one swish of light. | 10 |
| `glint.ach.brute` | The Bigger They Come | Pop a brute. | Big, slow, grumpy, and gone. | 25 |
| `glint.ach.firefly` | Firefly Gardener | Let a firefly replant a lost flower. | A little light brought a flower back. | 25 |
| `glint.ach.chain4` | Four Times Bright | Reach a x4 chain: pop 13 shadows in a row. | The chain hit x4. Dazzling. | 50 |
| `glint.ach.rooftops` | Over the Rooftops | Win all 10 Rooftops sunrises. | Every roof in the city, lit. | 50 |
| `glint.ach.harbour` | Harbour Lights | Win all 10 Harbour sunrises. | The whole harbour, lit at last. | 100 |
| `glint.ach.allstars` | Ninety Suns | Earn all 90 stars. | Every sunrise, every flower. | 100 |
| `glint.ach.daily` | Early Riser | Finish a Today's Dawn. | Up with the sun, with everyone else. | 15 |
| `glint.ach.longnight` | Night Watch | Score 20,000 in one Long Night. | Twenty thousand points before dawn. | 50 |
| | | | **Total** | **435** (of 1,000 allowed) |

English (U.S.) is identical.

### If you ever have to do it by hand

If the robot can't do something (it says so in its output, and Claude will tell you): paste the code blocks from `docs/appstore/metadata.md` §1–5 into App Information and the 1.0 page (English (U.K.), then switch the language menu to English (U.S.) and paste the U.S. description); answer the age rating exactly as the table in §8; set the price and availability as in §6b; paste `review-notes.md`'s block into Notes; add the Game Center items from the tables above (type the IDs exactly: they can never be changed once saved).
