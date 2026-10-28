# Cross-module needs

Add a line under your role when you need something from another module. The owner answers by doing it (or saying why
not) and deleting the line.

## Core (R1) → founder (docs only; Core already does the right thing)
- Contracts.swift `MirrorInput` comments say the band hides "θ < 85°" and the crease glow spans "θ 15°…85°";
  GAME-DESIGN §3 and `Tuning` use 80° (band 0 at 80°, glow full at 80°). Please fix the two comments.
- GAME-DESIGN §6 says brutes arrive "from 5", §7 says "Level 2, first brute: Follow the big ones". Core puts one slow
  teaching brute in level 2 (Dew), none in 3–4, and brutes in every level from 5. Confirm or say which.
- GAME-DESIGN §4: brute HP 2.2 contradicts "parked light can't finish it" (a parked band gives a brute ≈ 3.1 s of
  light). `Tuning`/`GloomSpec` use 3.6. Hoppers also got one rule: light hurries a resting hopper's clock ×(1 + 2 ×
  intensity), so it hops on through a parked band (popping there takes ≈ 3 s of luck) while a band that rides on it
  pops it in ≈ 1.3 s. Please update §4.

## App (R1) → Scene (answered by Scene R1)
- `size == layout.size` after `init(layout:)` and every `apply(layout:)`, `.aspectFill`: confirmed (tested).
- Flowers clear of the corners: **can't on a phone.** Five flowers fill the flower edge (lane i at u = (i + 0.5)/5,
  radius min(lane × 0.34, depth × 0.072), centre ≈ 35 pt in from the edge on a 393 pt phone). The 140 × 58 score
  plate at u = 0 covers flower 0 and part of flower 1; the pause button at u = 1 covers most of flower 4. The middle
  between the two plates is ~180 pt, too little for five readable flowers. See the Scene → App line below.

## Scene (R1) → App
- Please move the HUD off the flower row. `GardenScene.flowerRects(layout:count:)` (nonisolated, SwiftUI space) gives
  every flower's rect, so `AppRules` can test for overlaps. Two places the scene keeps free of anything that matters:
  (a) the mirror half's two far corners (sky and the brass frame only; on phones the lever's slot runs down the
  glass's right side but stops ≥ 98 pt short of the far edge, so a 56 pt button fits in that corner; the knob rests
  at the slot's far end when the band is in the crease), or (b) the garden's crease-side corners (glooms emerge
  there, but the plate only hides them for their first ~0.5 s). (a) looks best: an engraved brass plate on the
  frame. Not time-critical, so GAME-DESIGN §3's blur rule is fine with it.
- Set `scene.showsLever = !isDuo` (done), `attract` for menus (done), `reduceMotion` (done). Nothing else is needed;
  `SpriteView` options don't matter (every overlapping node has an explicit z, so `ignoresSiblingOrder` is safe).
