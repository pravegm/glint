# Glint: submission checklist (for the founder)

*Thu 29 Oct 2026. Claude fills in everything the App Store Connect API allows (listing, keywords, screenshots,
header and search art, Game Center leaderboards, achievements and badges, age rating, review notes, the build). This
page lists only the clicks that need you. Do them in order. Each takes a minute or two.*

## Before you submit (once)

1. **Turn on the website** (the support and privacy pages Apple checks). github.com/pravegm/glint → **Settings** →
   **Pages** → Source **Deploy from a branch** → Branch **main**, folder **/docs** → **Save**. After 2 minutes, open
   each of these on your phone. All three must load:
   - https://pravegm.github.io/glint/
   - https://pravegm.github.io/glint/support.html
   - https://pravegm.github.io/glint/privacy.html
2. **App Privacy.** appstoreconnect.apple.com → Glint: Sun Mirror → **App Privacy** → **Get Started** → "No, we do
   not collect data from this app" → **Save**, then **Publish**.
3. **Pricing and Availability:**
   - Price **£1.99** (Tier 2; it shows $1.99 in the US). Base country United Kingdom.
   - All territories.
   - **Untick** "Make this app available on Mac (Apple silicon)" and "Apple Vision Pro". The game needs a touch
     screen or a hinge.
   - **Family Sharing on.**
4. **EU trader status** (App Information → **Digital Services Act**): pick your status. Without it, Glint isn't on EU
   storefronts.
5. **Game Center** is already on, through the bundle ID. If App Store Connect asks you to "add Game Center to this
   version", tick the 3 leaderboards and 10 achievements Claude created (version page → Game Center → **+**).

## Check, then submit

6. Open the **1.0 Prepare for Submission** page and scroll the whole page once:
   - The screenshots: a 6.9-inch set and a 6.3-inch set. The Duo frame is first in each.
   - The build Claude attached.
   - Age rating **4+**.
   - The review notes start with "NO LOGIN".
   - Support and privacy URLs.
   - Manual release.
7. Press **Add for Review**, then **Submit to App Review**. Pick "**Manually release this version**" if it asks.
8. Apple usually answers in 24–48 hours. If they reject it, paste their message to Claude: the replies are drafted
   in `docs/appstore/review-notes.md`.
9. **Launch day** (the default plan is Tue 15 Dec 08:00 UK, the next free week after your other games; you can
   release earlier): press **Release This Version**. Then tell Claude, who swaps the website's "Coming soon" for the
   App Store link.
