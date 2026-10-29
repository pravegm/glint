# QA R5: Scene, Input and Feedback (pre-launch sweep)

Scope: `Glint/Scene/*`, `Glint/Input/*`, `Glint/Feedback/*`, plus the App calls into them. I reviewed by reading the
code only (there's no Mac here). Findings are sorted by severity. "Unverified" means it's reasoned from the code but not
seen on a device.

Counts: **P0 0 · P1 3 · P2 12**. I found nothing that crashes or hangs, and audio always recovers (see the last section).

## P1

**P1-1 The FX pools run out during the hero moment, so sparks, petals and steam vanish mid-life.**
- Pool sizes: glow 84, soft 64, rings 24 (`FXPool.swift:403-406`).
- When every slot is busy, `spawn` takes the slot at `cursor` (`FXPool.swift:123`, rings `:204`). In practice that
  deletes one of the oldest live particles, with no fade.
- Steam alone can fill the soft pool. Each lit gloom puffs 14/s and each puff lives 0.55–0.9 s
  (`GardenScene.swift:1135-1141`), so about 10 puffs per gloom are alive. The band spans the full width, so a world-2/3
  flock of 6–7 is lit at once, which needs 60–70 slots.
- Each pop then adds 6–10 petals and flecks, and steam from the glooms still burning keeps writing over them.
- The glow pool also overflows. A 7-pop cascade spawns 7 × 10–16 sparks, plus about 17 motes and about 19 embers.
  That is more than 84, so the first sparks disappear early.
- Sunrise with about 10 glooms left needs 22 confetti + 50 evaporate sparks + motes, which is also more than 84.
- Fix:
  - Raise the pools to glow 192, soft 160, rings 48 and labels 12. Hidden sprites cost almost nothing.
  - Scale steam by `1/max(litCount, 1)` (or cap it at 4 live puffs per gloom).
  - When stealing, take the live particle with the least life left, not the one at `cursor`.

**P1-2 Regular iPhones in landscape get a shallow, half-scale garden** (verified in code; GAME-DESIGN §3 says the
fallback is portrait).
- `project.yml:31-35` allows landscape on every device, and RootView applies no orientation lock (`RootView.swift:4`).
- On a phone, `GardenLayout.make` (`Contracts.swift:254`) never folds vertically. A landscape phone therefore gets the
  laptop split with 58 % of a 375–440 pt height: a 217 pt deep garden on an SE and 255 pt on a Pro Max.
- Every art size scales with that depth. A murk shrinks from 32 to 12–15 pt, flowers to 16–18 pt, fireflies hit the
  11 pt floor, and the brass mirror strip is about 180 pt tall.
- Rotating mid-drag also jumps the band: `DragMirrorSource.lastPoint` is in the old coordinates
  (`DragMirrorSource.swift:62-72`).
- Fix: lock non-Duo phones to portrait. One way: `application(_:supportedInterfaceOrientationsFor:)` returns `.portrait`
  unless `hingeSeen` or the window looks like a Duo. Also call `drag.dragEnded()` in `refreshLayout` when the layout
  changes.

**P1-3 A resting finger blocks the drag fallback** (unverified on device).
- `touchesBegan` keeps the first touch and ignores every later one until that touch ends
  (`GardenScene.swift:1486-1509`).
- SKView's `isMultipleTouchEnabled` is false by default, and nothing sets it. UIKit then delivers no second finger until
  all fingers lift.
- Scenario: the player holds the phone with the left thumb resting on the lower garden (the natural grip for "drag
  anywhere") and drags with the right index finger. Nothing moves.
- Related: a finger that lands while paused stays dead after Resume. `GameController.dragBegan` refuses it (`:668`),
  but the scene still holds `dragTouch`.
- Fix: in `didMove(to:)` set `view.isMultipleTouchEnabled = true`, and make the latest touch win (`dragEnded` then
  `dragBegan(new)`). The drag is relative, so a handover never jumps. In `dragMoved`, adopt a moving touch when
  `dragging` is false.

## P2

1. **Endless → menu skips the scene reset.**
   - `isNewSession` (`GardenScene.swift:842-849`) misses this hand-off: the mode is `.endless` on both sides, and once
     menu time exceeds the run, the attract clock is ahead.
   - Gloom ids restart in each session, so attract glooms take over play nodes and teleport or re-dress. Eaten flowers
     replay the replant ring and petals behind the menu.
   - Fix: call `reset()` in the `attract` didSet (`:122`). The App never calls `scene.reset()`.
2. **Four or more clouds at once cut the band off at high u.**
   - Core puts no cap on live shades (`DawnSession.swift:363-372`). World 3 has 5 clouds over 95 s, each crossing in
     16–21 s, so 3–4 can overlap.
   - Each light layer holds 15 pieces (`GardenLight.swift:126`), and 3 shades already use all 15. A 4th shade drops the
     pieces past u ≈ 0.8, so no light is drawn where Core still burns.
   - Only 3 tints and 3 mirror clouds exist (`GardenScene.swift:415`, `:1415`).
   - Fix: capacity `4 + 4·shades.count` (grow it lazily), or cap Core at 3 live shades.
3. **Floating words clip at the side edges.** `clampLabel` insets only 1.6 × the font size (45 pt)
   (`GardenScene.swift:821-825`). "Sweep ×10!" at 28 pt is about 170 pt wide, so a sweep in an edge lane on an SE (or
   across a book layout's 669 pt) loses about 35 pt off-screen. Fix: clamp by the label's measured half-width.
4. **The sweep label can take over a chain label.** With 8 label slots, a chain storm steals `sweepSlot`. `retext`
   checks only that the slot is alive (`FXPool.swift:348-353`), so "Sweep ×6!" then rewrites a "×9" sitting elsewhere.
   Fix: keep a generation id per slot, and grow the label pool (see P1-1).
5. **Ground textures are drawn on the main thread inside the frame loop.**
   - They're built (`GardenArt.swift:784-806`, two textures of about 714 × 1002 px each) when the style or size changes
     (`GardenScene.swift:646-661`, `:892-898`): world change, Duo book ↔ laptop, and inner ↔ cover display (the scene is
     re-laid out to the cover's size behind CoverView).
   - The LRU keeps 8 keys. Inner + cover × night/dawn × (attract meadow + world style) already fills it, and laptop pose
     evicts entries.
   - Likely cost is 30–60 ms per rebuild (unverified), which can land right as the phone opens to resume.
   - Fix: warm the current world's grounds at level start, keep 16 keys, and skip `apply(layout:)` while the cover is
     shown.
6. **Engines wake on the main thread, in the frame that needs them.**
   - `lastActive` only moves while live, so a waiting stage or pause longer than 3 s idles the engines
     (`FeedbackDirector.swift:407-420`).
   - The wake then does `CHHapticEngine.start()`, builds 2 players (`FeelHaptics.swift:304-314`, `:392-414`) and runs
     `AVAudioEngine.start()` (`FeelAudioEngine.swift:158-163`). With music off it also runs after a nap.
   - That happens synchronously in the `.started` frame (first light) or at resume. The hitch size is unverified.
   - Fix: count waiting and paused-on-a-play-screen as active, or wake both engines when the level screen appears.
7. **Per-frame heap allocations at 120 Hz** (about 40–60 per frame):
   - array literals in `GardenLightMath.pieces` (`GardenLight.swift:87`, `:91`), `placeShadeClouds`
     (`GardenScene.swift:1412-1414`), `drawLever` (`:1430`) and `GardenMirror.update` (`:571`);
   - a new `UIColor` every frame per sprite: mirror `:459-498`, `GloomNode.swift:275` (body, a constant), `:308`, and
     about 10 per firefly (`:521-560`);
   - `"petal-\(k)"` built per particle (`GardenArt.swift:486`).
   - Fix: cache constant `UIColor`s as statics, set a colour only when it changes, and reuse scratch arrays.
8. **Overdraw** (unverified on GPU).
   - Three full-glass sky sprites always draw, and the night sky stays under an opaque day sky (`GardenMirror.swift:82-87`).
   - `veil` draws at alpha 0, never hidden (`:189-191`).
   - `groundNight` draws under an opaque `groundDawn` at sunrise (`GardenScene.swift:1375`).
   - Fix: hide each layer that is fully covered or has alpha < 0.005.
9. **Reduce Motion gaps.**
   - Firefly scorch flicker uses a new random alpha every frame at 120 Hz, a strobe (`GloomNode.swift:515`).
   - The chain "×n" spring overshoots to 1.45× (`FXPool.swift:365-372`).
   - Fix: under Reduce Motion, use a 4 Hz smooth flicker and a plain fade-in.
10. **A late "interruption began" can block `heal()` until the next activation** (unverified).
    - A `.began` with `.appWasSuspended` (or any began with no `.ended`) sets `interrupted = true`. If it arrives after
      `resume()`, `heal()` stays blocked (`FeelAudioEngine.swift:121-122`, `:152-156`, `:293-303`). It also runs
      `stopAll` on sounds that are playing.
    - Fix: ignore begans whose reason is `appWasSuspended`, and clear `interrupted` in `heal()` when the app is active.
11. **The pad plays over the player's own music.** `.playback` + `.mixWithOthers` (`FeelAudioEngine.swift:170`) ignores
    the silent switch; that's the founder's rule and fine. But the dawn pad also mixes over Spotify or Music.
    - Fix: drop `bed.pad` while `AVAudioSession.secondaryAudioShouldBeSilencedHint` is true, and observe
      `silenceSecondaryAudioHintNotification`.
12. **On AirPods, haptics land about 150–250 ms before the pop sounds.** Haptics fire at once, while audio goes through
    the queue plus output latency (`FeedbackDirector.swift:189-195`). Fix: on Bluetooth routes, delay haptic cues by
    `AVAudioSession.outputLatency`, capped at 0.25 s.

## Checked, no bug found
- **Crash surface.**
  - Every array index in the scene is guarded: dew/dewSpots, lanes, `frameEatenLanes[0]`, `wets[i % count]`, light
    pieces and mirror arrays.
  - No force unwraps or `try!`. No SKAction or emitters, so nothing accumulates.
  - `Int(...)` conversions in the synth only take constant specs.
  - Texture sizes are capped at 1800 px, so even a huge Mac window is safe.
- **Hinge.**
  - NaN or infinite samples are dropped (`HingeMirrorSource.swift:98`), and times never run backwards.
  - Jumps over 90° snap. A silence glides onto the last raw reading. The shut gate matures on the clock alone.
  - Before the first sample the band is hidden and the phone isn't shut. `reset()` re-seeds from the last raw reading.
  - Re-subscription toggles `isEnabled` after 30 ms on every activation and every cover change.
- **Drag.**
  - Input is relative, clamped at every step and speed-capped. `maxStep` caps a stale dt.
  - `touchesCancelled` ends the drag. Non-finite points are ignored.
- **Synth.**
  - The SPSC atomic queue never blocks (it drops when full), and the render path is allocation-free.
  - The limiter's instant attack plus tanh mean the output never clips, even with stacked pops.
  - A NaN in the output resets the filters. 160 voices, and all frequencies are relative to the sample rate.
  - Every filter is clamped to 0.45 × the sample rate. A route change resamples in the mixer.
  - Configuration change, route change, media-services reset and repeated start failures all restart or rebuild the
    engine.
- **Haptics.**
  - The reset and stopped handlers hop to the main actor. Heal runs about once a second. Background is skipped.
  - A device without Core Haptics falls back to `UIImpactFeedbackGenerator`. Turning haptics off stops the hardware.
- **Memory.**
  - Gloom and firefly pools grow only to the peak crowd. Dying nodes return to the pool on rotation and on a new session.
  - The ground cache is purged by LRU. Other textures are a fixed set of about 70.
- **Layout.**
  - `GardenFrame` maps all four `GardenLayout` variants correctly (I checked the origin, rotation and u-flip by hand).
  - The thumb inset applies only in book layouts. Swap halves takes the "turned" path (FX cleared).
  - Duo 951×669 / 669×951, SE 375×667 and Pro Max 440×956 portrait all size cleanly. Landscape phones are P1-2.
