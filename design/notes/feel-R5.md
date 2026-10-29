# Feel engineer, Round 5 (QA-R5 fixes)

Not compiled. Not committed. Each item cites QA-R5-scene-feel unless noted.

- **P2-6 Engines wake off the frame loop.**
  - `FeedbackDirector.prepare()` (new) wakes both engines on its own main-actor task. `ui(.levelStart)` calls it at
    session start, which is before first light. The App may also call it on the "Close the phone" card (NEEDS.md).
  - Play-screen frames now count as activity: waiting for first light, held, or paused for under 20 s
    (`pauseHold`). So first light and resume never find the engines idle.
  - Haptics start asynchronously (`CHHapticEngine.start(completionHandler:)`). The looping players are built in the
    completion handler, and a cue asked for during the start plays when the engine is up, if it is under 0.2 s old.
  - A napping audio engine wakes on its own turn (`wakeSoon`). Sounds asked for meanwhile wait in the synth's queue.
  - `heal()` runs on its own task.
  - `AVAudioEngine.start()` itself is still synchronous on the main actor, but it never runs inside a frame now.
- **P2-10 Interruptions.**
  - A `.began` with reason `.appWasSuspended` is ignored. Apple deprecated that reason in iOS 16, so this mostly
    covers old behaviour.
  - An interruption with no `.ended` is repaired in `heal()` once the app has been active for 1.5 s.
  - A render watchdog checks the synth's render-callback count. If the engine says it is running but the count has
    stopped (for about 2 s), it restarts the engine.
  - Activation (`resume`) clears the interruption, refreshes the route and the other-audio state, and restarts the
    engine.
- **P2-11 Other audio.** `FeelAudioEngine.otherAudioPlaying` follows `secondaryAudioShouldBeSilencedHint` and its
  notification. `FeedbackDirector.padAllowed` is `musicOn && !otherAudioPlaying`. It gates the dawn pad in play,
  pause and menus; game sounds are unchanged.
- **P2-12 Bluetooth.** `hapticDelay` is the output latency plus the IO buffer, capped at 0.25 s, on A2DP, LE and HFP
  outputs only. It is refreshed at start, on route changes and on activation. Every haptic cue is shifted by it
  (`FeelHapticBook.delayed`). The continuous sizzle texture isn't delayed; it's a texture, not a hit.
- **P1-2 (Input part)** `DragMirrorSource.layout` forgets the finger's last point on a real layout change. A rotation
  mid-drag continues from the next move with no jump. The App's `refreshLayout` no longer needs `dragEnded()`. P1-3
  (multi-touch) is the Scene's.
- **Tests added:**
  - `aLayoutChangeMidDragNeverJumpsTheBand`
  - `hapticsWaitForBluetoothAudio`
  - `aSuspensionIsNotAnInterruption`
  - `playScreenFramesKeepTheEnginesAwake`

## Compile risks
- `engine.start(completionHandler: { (error: Error?) in … })` on CHHapticEngine.
- `AVAudioSessionInterruptionReasonKey` and `.appWasSuspended` (deprecated: a warning only).
- `AVAudioSession.silenceSecondaryAudioHintNotification`.
- `nonisolated static` helpers: `FeedbackDirector.keepsAwake`, `pauseHold`, `FeelAudioEngine.hapticDelay`,
  `isBluetooth`, `honoursBegan`, `maxHapticDelay`.
- The tests now import AVFoundation, for `AVAudioSession.Port` and `InterruptionReason`.
