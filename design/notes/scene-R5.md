# Scene R5: hand-off (QA-R5 sweep)

Not committed (the founder pushes). Sources: design/QA-R5-scene-feel.md (Scene P1s + every Scene P2) and
design/QA-R5-player.md (Scene items).

| QA item | Fix |
|---|---|
| P1-1 FX pools | Pools are now glow 192, soft 160, rings 48 and labels 12. When full, each replaces the item **nearest its end**. A lit flock shares the steam budget (each gloom's rate ÷ √litCount, ≈ 4 live puffs per gloom in a flock of 7). |
| P1-2 (scene side) | `apply(layout:)` ends a live drag, so no jump from old coordinates. The portrait lock is the App's. |
| P1-3 Multi-touch | `didMove(to:)` sets `isMultipleTouchEnabled`. The newest finger takes over (`dragEnded` + `dragBegan`; the drag is relative, so nothing jumps). If the dragging finger lifts while another is down, the next one to move picks the drag up. |
| P2-1 | `attract` flipping calls `reset()`, so play → menus starts a fresh scene even Long Night → Long Night. |
| P2-2 Clouds | Light layers grow to fit any number of pieces. There are 6 shade tints and 6 mirror clouds (Core caps live clouds at 4). |
| P2-3 Clipped words | The label pool clamps every word inside the garden by its **measured** size at its biggest scale, over its whole rise (and again when re-worded). |
| P2-4 | Label handles carry a generation, so a stale sweep handle can't re-word another label. |
| P2-5 Grounds | All four grounds (night + dawn) are prewarmed **in the background** for each canvas size seen (pure CoreGraphics `GroundRender`, so no UIKit off the main thread). They stay cached until a memory warning (the purge keeps the on-screen pair); there's no LRU. Grounds are capped at 1.25× / 1600 px. A ground not yet ready is drawn synchronously by the same renderer. |
| P2-7 Allocations | Scratch arrays for light pieces and shade clouds; no array literals in `drawLever` or the mirror's lever. Petal textures are cached. Gloom, firefly and mirror colours are set only when they visibly change. |
| P2-8 Overdraw | Fully covered or invisible layers are hidden: the night sky under the dawn/day sky, the dawn sky at 0 or under the day sky, the mirror veil and night veil at 0, the night lawn under an opaque dawn lawn. |
| P2-9 Reduce Motion | The firefly scorch flicker is a smooth 4 Hz pulse (no random strobe), wings are steady, and floating words fade in with no spring. |
| Player #8 | The floating word is the **multiplier** (`multiplierText`: "×1.5" … "×4"); sweeps say "Sweep of N!". |
| Player #9 | Submerged: the body is 10 % and greyed, the eyes are 32 % opacity and 30 % open (sleepy slits) behind the soil lip. It never reads as "the light is failing". |
| Player #11 | The rail sits on the garden's outer margin (13 pt in). The 44 × 20 grip lies along it and starts 30 pt below the crease, clear of the frame's corner bolt. |

Tests: 8 new (the multiplier text, least-life eviction, newest-touch handover and the drag ending on layout change,
menus reset, six clouds lighting the whole band, no clipped words on two phone sizes, no spring with Reduce Motion,
dim submerged eyes). Updated: the ×-text expectations, the sweep wording, the rail start, and the node budget (≤ 1000
total, ≤ 300 drawn).

Compile risks: `GardenArt.drawGround` is now `nonisolated`, called from the background renderer. The prewarm uses
`DispatchQueue.global().async` then `Task { @MainActor in … }`; under Swift 5 mode, a CGImage capture warns at most.
`@objc memoryWarning` is registered with `#selector`.
