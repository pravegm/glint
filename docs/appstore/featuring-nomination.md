# Glint: Featuring nomination (App Launch)

*Written Wed 28 Oct 2026 by the launch lead. **The App Store Connect tool creates and submits it** (`asc.yml`, step `nomination`, `"submit": true`, from `docs/appstore/asc-metadata.json`); nobody pastes it. Change the text here, regenerate the JSON (`node tools/appstore/build-metadata.js`), and push the `nomination` step again. It needs only the app record and the GitHub secrets (runbook §1–§2), not a build.*

## Timing

**Launch: as soon as App Review approves (automatic release, founder 30 Oct 2026).** The nomination date is Tue 24 Nov 2026: the earliest with Apple’s 3 weeks’ notice, after Brim’s launch week (17–23 Nov). The nomination itself was submitted on 29 Oct (by mistake, before founder review); the tool updates it in place and never submits.

Apple asks for nominations as early as possible, ideally **at least 3 weeks before** the date: **submit by Mon 23 Nov** (3 weeks and a day). Sooner is better: the tool submits it in runbook §3, as soon as the app record and secrets exist (about 6 weeks' notice).

Where to see it: App Store Connect → Apps → Glint: Sun Mirror → **Featuring** → **Nominations**. A saved draft is not a nomination, which is why the tool submits it.

If the launch moves (the fallback is Tue 19 Jan 2027), tell Claude: the Publish Date changes in the JSON and the tool pushes it (or edit it by hand on the same page).

## Fields

| Field | Value | Count / limit |
|---|---|---|
| Nomination Name | `Glint: Sun Mirror - App Launch - iPhone Duo light game` | printed by `build-metadata.js` / 60 |
| Nomination Type | **App Launch** | — |
| Description | the block below | printed / 1,000 |
| Publish Date | **Specific day: 2026-11-24** | — |
| Related Apps | Glint only (auto-filled). Don't add Squish, Brim, Swoop, Hush or Snapjaw: they have their own nominations | up to 10 |
| Platforms | iOS | — |
| Countries or Regions | leave the auto-selection (every territory the app is in) | — |
| Localizations | leave the auto-selection (English (U.K.), English (U.S.)) | — |
| In-App Events | none | — |
| Supplemental Materials | 1. `https://pravegm.github.io/glint/` 2. the teaser clip (`social-launch.md` §3A) once it exists, added by editing the nomination 3. the TestFlight public link (only if you open external testing) | up to 5 URLs |
| Helpful Details | the block below | printed / 500 |

### Description
```
Glint turns the top half of iPhone Duo into a mirror. Open the phone and it catches the sunrise, throwing a band of light across the garden on the other half. The phone's angle is the aim: the wider you open it, the further the light reaches, smoothly and both ways, and shut means dark.

Shadow critters seep out of the crease towards five flowers. Light pops them in gold sparks and petals, and a sweep through a crowd climbs a rising scale of notes. Fireflies must be spared: they replant lost flowers. Five kinds of shadow each want a different move, from flocks of wisps to brutes that have to be followed.

30 handmade sunrises in three worlds, with stars to earn, then an endless Long Night and a daily Today's Dawn for everyone. Every level starts with the phone shut; shutting it pauses. Other iPhones aim the light by dragging. Every sound is synthesized in the app. No ads, no in-app purchases, no data collected.
```

### Helpful Details
```
Optimized for iPhone Duo: one half is a mirror, the other the play field, in laptop or book pose. Public iOS 27.1 hinge API: the angle maps continuously to where the light lands, from 80 to 135 degrees, so play is gentle and never flat, with no pause near 90 degrees. Closing is a real pause; the outer display shows it. A new hinge verb for us: reach, aimed by angle. Also from us: Squish, Brim, Swoop, Hush and Snapjaw.
```

**Why this copy:**
- **New hardware first:** the opening line, and "Optimized for iPhone Duo" in Helpful Details (Apple's Duo guidance asks for exactly that phrase).
- **The fantasy in one image:** the phone's own half is the mirror; shut is dark. It is literal, which is the studio's rule.
- **A new hinge verb:** reach. Editors have seen press, pour, wings, a slow opening and a bite from us; this is aim by angle, continuous and both ways.
- **Built for the real device:** play kept in the hinge's holding range, never flat, no pause near 90°, a real pause on close with a cover-display card.
- **Craft:** synthesized sound, a rising pop ladder, 30 handmade levels.
- **Reach:** drag to aim on other iPhones (iOS 18 or later). No VoiceOver claim, because that label isn't earned (`accessibility.md`).
- **No ads:** the last line.

## Later nominations (optional)
- **New Content**, for the first update with real new content (a fourth world, new shadows). Description: what's new, one line restating no ads and a free update. Submit 3 weeks ahead.
- An **In-App Event** (a "Midsummer Dawn" Today's Dawn, for example) needs a build that implements it first; don't create one for 1.0.

## Sources
- App Store Connect Help, *Nominations template* (name ≤ 60, description ≤ 1,000, helpful details ≤ 500, up to 5 URLs, types): https://developer.apple.com/help/app-store-connect/reference/nominations/nominations-template
- App Store Connect Help, *Nominate your app for featuring* (minimum 3 weeks' lead time): https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring
- Snapjaw's nomination (format mirrored): `C:\Users\59527\Trap\docs\appstore\featuring-nomination.md`
