# Feel engineer, Round 3

Not compiled (R2 is green on CI 40789455196). Not committed.

- **`GameEvent.surfaced`** maps to `FeelCue.surface(kind)` in `FeelCueMap`, the only exhaustive `GameEvent` switch in
  Feel. The director's `FeelCue` switch plays it.
- **Bloop**: a soft rising low bubble (wisp ~308 Hz … brute 180 Hz: bigger lower), its octave 35 ms later and a little
  low splash. Peak gain ≤ 0.065, below every pop's loudest voice and under every pop's bubble pitch, so "it's up" never
  reads as "it popped". Haptic: one faint round tick (0.18; a brute 0.26).
- **Flocks**: `FeelSurfaceGate` takes the first surfacing in a 0.25 s window as a bloop and the second as one little
  chord: strummed C4 E4 G4 marimba (a fifth up for 5+) over a deeper bubble, with two soft ticks. The rest are silent.
  A flock of 8 plays 1 bloop and 1 chord.
- Submerged glooms are immune, so they no longer count toward the cloud-shade sizzle muffle.
- Tuning's band widening (core 0.065, edge 0.10) needs no change: Feel and FeelTests only use `Tuning.intensity(d:band:)`
  and never the widths.
- Tests: the mapping test includes `.surfaced`, plus `aFlockSurfacingIsOneBloopAndOneChord`,
  `theBloopIsQuietLowAndUnlikeAPop` and `submergedGloomsNeverMuffleTheSizzle`.
