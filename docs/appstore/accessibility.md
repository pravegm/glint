# Glint: Accessibility Nutrition Labels (v1.0)

*Decided Wed 28 Oct 2026 by the launch lead, from the design (`design/GAME-DESIGN.md` §3–§10, `design/ROUND-1.md` App and Scene briefs); the build doesn't exist yet. The rule, the same as every sister game: **claim a label only when the build earns it across every common task**, and verify on the release build first. Labels are voluntary, per device, and can only be published once a version is live, so this happens on **launch day, Tue 15 Dec** (runbook §7). The App Store Connect tool doesn't set labels: the founder ticks them by hand.*

Common tasks for Glint:
1. the first launch: Home → **Play** → Level 1, following the one-line hints ("Close the phone to start", "Open the phone to let the light in" on a Duo; "Drag down to let the light in" elsewhere; "Light the shadows");
2. pick a level on the **level map** (three world tabs, sun medallions, stars, locks with "x more ★"), or start **Long Night** or **Today's Dawn** from Home;
3. play: aim the light (the hinge on a Duo; a drag elsewhere), see shadows creeping and popping, tell a firefly from a shadow, read the HUD (score, chain "×n", "Sweep!", the hint line) and count the flowers left;
4. pause (the pause button, or shut the phone on a Duo) and resume; the cover display's "Paused" card;
5. read the Results card (stars, score, best; "The night won" on a loss) and choose Next, Retry or Levels;
6. change **Settings** (Sound, Music, Haptics, Swap halves, Reduce motion) and read **About**.

## What the design gives us (to be confirmed on the build)

- **Two ways to aim:** the hinge (Duo) and a relative drag anywhere (any iPhone without a hinge). The drag starts anywhere on the screen and needs no precise target, which helps motor access. On a Duo there is no touch alternative in the design (see the 1.0.1 list).
- **Fireflies don't depend on colour:** they are small, round and glowing with a trail; shadows are big inky blobs with white eyes. Shape and size tell them apart; a scorching firefly also flickers (motion), and there's a sad falling blip when one fizzles (sound).
- **Flowers are lives you can count:** five flowers in a row; an eaten one is a drooping stalk (a shape change), not just a colour change.
- **Words for every outcome:** "Sweep!", "×n" on chains of 3+, the hint line, "The night won", stars as star shapes.
- **Sound and haptics carry the state:** the sizzle swells with how much is in the light (sound and a haptic texture), each pop is a tick and a rising note, a flower lost is a crunch and a heavy thud. A player who can't see the edge of the band well can still hear and feel when it's on something.
- **Reduce motion:** a setting (ROUND-1: `reduceMotion` turns off the band's shimmer and any shake). **Ask (App engineer, `metadata.md` §11 ask 8):** default it to the iOS setting (`UIAccessibility.isReduceMotionEnabled`) and say so in the row.
- **Swap halves:** puts the garden on whichever half the player sees best (and away from the half iOS blurs when a fold starts from flat).
- **Gentle input:** play needs small, slow movements of the hinge or the finger; nothing needs speed or force.

## The answer, at a glance

| Label | 1.0 answer | Status | Why |
|---|---|---|---|
| VoiceOver | **No** | Decided | Menus will be labelled, but play (task 3) depends on seeing where shadows are relative to the light. Apple's bar is all common tasks |
| Voice Control | **No** | Decided | Aiming is continuous; there's no spoken alternative |
| Larger Text | **No** | Decided | No Dynamic Type in the design; the HUD and floating text are fixed-size scene labels. Never tick it unless 1.0 is built with it |
| Dark Interface | **No** | Decided | The garden starts at night and warms to gold as the sun rises; menus are warm and light. Not a dark interface by Apple's definition |
| Differentiate Without Color Alone | **Yes**, if check A passes | **Verify** | Fireflies vs shadows by shape and size; flowers by shape; every score state is a word or a number |
| Sufficient Contrast | **Yes**, if check B passes | **Verify** | HUD text sits over a garden that changes from deep blue to gold; it needs an outline or a backing plate everywhere |
| Reduced Motion | **Yes**, if check C passes | **Verify** | Shimmer, shake and big FX must calm down; the light and the shadows still move (that's the game) |
| Captions | **No** (not applicable) | Decided | No dialogue, video or audio-only content |
| Audio Descriptions | **No** (not applicable) | Decided | No time-based video content |

**Publish for iPhone: Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion**, each only if its check below passes on the release build. Leave every other box unticked. If a check fails, leave that box unticked: an honest "not indicated" beats a false claim.

## Checks (on the release build, on a Duo and on a non-Duo iPhone)

### A. Differentiate Without Color Alone
- [ ] With **Settings > Accessibility > Display & Text Size > Color Filters > Grayscale** on, a tester can tell a firefly from every shadow kind at a glance (size, glow, trail vs blob with eyes), at night and at sunrise.
- [ ] A **scorching** firefly is noticeable without colour (flicker or a size pulse, not only turning red).
- [ ] The **band of light** is visible against the garden in grayscale (brightness, soft edges, dust motes), at every point in the sunrise.
- [ ] An **eaten flower** reads as a drooping stalk, not only a greyed flower.
- [ ] The **chain** shows its multiplier as text ("×3"), not only a colour.
- [ ] Locked levels show a **lock** and "x more ★"; earned stars are filled star shapes vs outlines, not only gold vs grey.
- [ ] Selected options in Settings show a toggle position, not only a tint.

### B. Sufficient Contrast
Apple's bar: about 4.5:1 for text, 3:1 for large text, controls and state indicators.
- [ ] HUD text (score, the chain, the hint line) and floating text ("Sweep!", "×n") keep ≥ 4.5:1 (3:1 for the large ones) against **every** moment of the sunrise (deep blue-teal at night, peach, gold) and against the band itself. Cream text inside the gold band won't pass without an outline or plate.
- [ ] The pause button and the level-map medallions reach 3:1 against what's behind them.
- [ ] Menu, Results and Settings text ≥ 4.5:1 on its panel, the quiet lines included.
- [ ] Check with Increase Contrast and Bold Text on.

Measure with a contrast checker on the release-build frames (the CI store frames) and paste the ratios here (the sister games' table format).

### C. Reduced Motion
- [ ] With Reduce motion on (the in-app setting, and iOS Reduce Motion if the ask above is built): no band shimmer, no screen shake on a lost flower, the reflected sky in the mirror doesn't shift with the angle, the sunrise "golden flood" fades rather than sweeping.
- [ ] Pops keep their sound and haptic but the spark burst is small and short; "Sweep!" fades in rather than springing.
- [ ] Menu transitions become fades or short moves, not springs and slides.
- [ ] The light following the phone, shadows creeping and fireflies drifting still move: that motion is the game itself, which Apple's criteria allow.

## What we can say in copy today

The description says "Sound, music, haptics and Reduce motion each have a setting" and "On any other iPhone, drag anywhere to aim the light". None of this claims a VoiceOver, Voice Control or Larger Text label. If check C fails, keep the sentence (the setting exists) but don't tick the label.

## 1.0.1 list to earn more labels honestly

| Fix | Size | Earns |
|---|---|---|
| Settings → "Aim with touch" on a Duo (drag to aim, hinge ignored) | S | Motor access on the Duo; makes Switch Control usable there |
| A slower "Gentle dawn" option (shadows 30 % slower, longer levels) | S | Helps players with slower reactions (no label by itself) |
| Spoken cues for VoiceOver ("Shadow near the flowers, left", "Firefly in the light") plus audio panning by `u` | M | VoiceOver (maybe), and helps low-vision players |
| HUD, Results, level map and menus scale to AX3 with reflow | M | Larger Text |

Re-check the labels with every update; add one only after the fix is on device and tested.

## Sources
- App Store Connect Help, *Overview of Accessibility Nutrition Labels*: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- App Store Connect Help, *Manage Accessibility Nutrition Labels* (publish only for devices with a live version): https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels
- Snapjaw's label decisions (method mirrored): `C:\Users\59527\Trap\docs\appstore\accessibility.md`
