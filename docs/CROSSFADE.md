# Crossfade (port from Echo Android)

## Adaptive pre-arm

The port follows `AdaptivePreArmManager.kt` / `StandbyCrossfadeSchedulerImpl.kt`:

- initial lead **20 s** (max **35 s**), not just the crossfade duration;
- standby preparation time is measured and recorded:
  - if it exceeds 8 s the lead grows by `1.5 × (prep − 8 s)`, up to 35 s;
  - if preparation is fast the lead decays by 2 s at a time down to 20 s;
- the standby is prepared when `remaining <= lead` and **not** when `remaining <= crossfade`: the latter is the trigger moment;
- before the trigger the app waits until the standby is really ready (`playing == true` and `bufferedPosition >= position + 150 ms`), equivalent to `STATE_READY`. If it is not ready within 2.5 s the crossfade does not start, so the "freeze and restart" caused by mid-fade buffering cannot be heard.

## Handoff and curve

- during the handoff the audible player falls with `cos(t·π/2)` while the standby rises with `sin(t·π/2)` over **220 ms**: no volume jump;
- the actual crossfade uses the same constant-power curve for the configured duration;
- overlapping async ticks and ticks from a cancelled fade are ignored (`CrossfadeEngine` with a generation guard);
- **both volumes are applied in parallel** (`Future.wait`) on each tick. Awaiting them sequentially doubled the window in which a tick could be skipped, leaving audible volume steps ("stutter") right before the main player seeks to the next track;
- **a skipped tick loses no progress**: `t` is recomputed from the stopwatch on every tick, so the curve stays continuous;
- at the end of the fade the final volumes (`0` and `peak`) are written explicitly: a lost platform callback cannot leave an intermediate volume exactly when the main player seeks to the next track;
- if the handoff does not complete within 700 ms, the final volumes are forced;
- the final volume is restored from the value captured at the beginning, not recalculated from a muted player (which used to push it to 100%).

Note: Android swaps the players at the end of the fade. Here the main player stays stable so all UI streams do not need re-attaching; early preparation and buffer verification remove the cause of the stall.

## Incoming readiness

The incoming track is attached only at the trigger with `seek(index: ...)`, so a fresh network stream may still be buffering when the fade starts. `_waitForIncomingReady()` waits for `playing` plus a buffered margin before ramping the incoming volume. The outgoing standby remains audible at full volume during the wait, so the wait itself is inaudible. This is applied to both automatic queue transitions and manual switches.

## Automix

Android Automix is ported in phases 1–3: `BeatAnalyzer` (STFT, spectral flux, autocorrelation for BPM/beat grid/key), dynamic mix-in/mix-out, beat matching, a 16-beat DJ blend, low-shelf ducking, Camelot harmonic mixing, and diagnostics. See [`AUTOMIX.md`](AUTOMIX.md) for details and limitations (the ducking is a static filter on the outgoing player, not a per-sample IIR as on Android).
