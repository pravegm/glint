# CLAUDE.md: working on Glint

**Glint: Sun Mirror** ("Catch the sun. Pop the shadows.") is a paid iPhone game (£1.99, no ads, no IAP, no data
collected), built **iPhone Duo first**. The Duo is Apple's foldable (iOS 27.1).
- The top half of the phone is a mirror. Opening the phone throws a band of sunlight across the bottom half (the
  garden). The wider you open, the further the light reaches. Shut = dark.
- Shadows creep out of the crease towards five flowers. Light pops them. Spare the fireflies: they replant flowers.
- Levels are sunrises (30, in 3 worlds), plus Long Night (endless) and Today's Dawn (daily).

The founder (GitHub `pravegm`) is the product owner and is away while this is built. Claude runs the studio as founder,
designer and developer, with parallel subagents per role and a critic loop.

**Sister projects:** Squish (`C:\Users\59527\Squish`), Brim (`Fold`), Swoop (`Wing`), Hush (`Lid`), Snapjaw (`Trap`).
Never modify them. Reuse their lessons and code by copying.

## Identity
- Product name **Glint** (`CFBundleDisplayName`); Swift reads it via `AppBrand.name`, never a literal.
- Xcode target and folder `Glint`, tests `GlintTests`. Bundle id **com.pravegm.glint**.
- Log prefix `GLINT-`; demo launch argument `-glintDemo`; Game Center ids `glint.*`.
- Repo folder `C:\Users\59527\Sun` → GitHub **pravegm/glint**.

## The bar (founder rules carried over from the sister projects)
1. **The phone is the object, literally.** The top half IS the mirror. Shut phone = no light. Every level starts
   with the phone shut ("Close the phone to start"), and the light grows as the phone opens. No on-screen light runs
   ahead of the hinge.
2. **No pose demands.** Book, laptop, any way round: the layout follows the canvas. Never ask for flat or a full close.
   Say "phone" in copy, never "lid".
3. **Gentle on the hinge.** Play lives in 80°–145° (the hinge only holds position from ~15° to ~145°). No pause or
   warning near 90°.
4. **First-class phone fallback.** Every non-Duo iPhone plays the whole game with drag-to-aim. Audit it whenever a
   mechanic, copy or flow changes.
5. **Satisfying and hard enough.** The pop cascade must feel great (sound, haptics, sparks). Levels get genuinely
   hard by world 3; "super easy" bores (Snapjaw lesson).
6. **Menus never cheap.** Illustrated, warm, the live garden behind; no plain system lists.
7. **Truthful store frames.** Nothing appears on a frame that the app doesn't do.

## Working rules
- Push straight to `main` (the founder's standing rule; solo project). No PRs.
- **No Mac on the Claude side. CI is the compiler.** A Swift change is unverified until a GitHub Actions run passes.
- The repo was created private (the permission guard blocks creating public repos); the founder made it **public** on
  28 Oct 2026 so Actions run (private Actions are blocked by this account's billing). Keep it public.
- On this Windows host Bash ignores `cd`. Use absolute paths and `git -C`. No Python; use Node.

## Build
`brew install xcodegen && xcodegen generate && open Glint.xcodeproj`
- Xcode 27.1 with the iOS 27.1 SDK. Deployment target iOS 18. Hinge code behind `#available(iOS 27.1, *)`. Swift 5.
- The `.xcodeproj`, `Info.plist` and entitlements are generated, not committed.

## Docs (read in this order)
1. `design/GAME-DESIGN.md`: the game.
2. `design/ARCHITECTURE.md` and `Glint/Shared/Contracts.swift`: modules, owners, APIs.
3. `design/ROUND-N.md` (briefs), `design/REVIEW-N*.md` (critics), `design/notes/` (engineer hand-offs),
   `docs/PROJECT-LOG.md` (what happened when).
4. `research/`: market and name checks.

## Hinge facts that bite (from the sister projects' real-Duo logs)
- Use the **angle**, never `status == .closed` (it turns on at about 85° on hardware).
- Samples arrive at 25–30 Hz while moving and not at all while still. Re-enable `onHingeChange` on each activation.
- A natural quick fold goes "about halfway" (≈ 90°). Never put a pause or warning near 90° (Swoop).
- Closing moves the app to the outer (cover) display and keeps it running: show a cover view there.
- Full-screen apps are refused upside down, and a Duo lying flat never auto-rotates.

## Swift Testing gotchas (found on CI)
- `#expect(x.mutatingMethod())` doesn't compile: call it first, then `#expect(r)`.
- Compare `CGFloat`/`Double` with a tolerance, never with literal arithmetic.
