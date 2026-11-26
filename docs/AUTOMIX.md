# Automix

Port of Echo Android's Automix. All three phases are implemented: beat analysis, beat and key matching, and the DJ blend with ducking.

## Analysis

`lib/services/beat_analysis.dart` ports `BeatAnalyzer`: radix-2 FFT, spectral flux, autocorrelation for BPM 60–180 with 70–140 folding, and a comb filter for beat phase. It is pure Dart and covered by unit tests.

`lib/services/beat_analyzer_service.dart` decodes a 30 s window at 22 050 Hz mono with FFmpeg Kit, runs the analysis and caches it per video id in Hive (`BEAT_ANALYSIS`).

`automixTriggerMs()` moves the fade start so the end of the blend lands on a beat of the outgoing track, near its dynamic mix-out (energy scan of the tail with `-sseof`). During pre-arm the incoming track is analysed too; `beatAlignedStartMs()` picks an entry offset so one of its beats lands at the end of the fade, starting from the dynamic mix-in.

Key detection uses Krumhansl–Schmuckler and is exposed as `keyLabel`.

## Settings

- **Automix · beat align** — on by default when crossfade is enabled
- **Automix · harmonic mixing** — on by default

Harmonic mixing (`harmonic_mixing.dart`) maps the key to the Camelot wheel (1A–12A / 1B–12B) and chooses the next track from the first three in the queue. Same key scores 1.0, relative major/minor 0.85, perfect fifth (descending on the wheel) 0.7, otherwise 0. The best candidate is moved after the current track with `moveAudioSource`. Candidate analysis is limited to 3 s so it does not eat the pre-arm lead. The result appears in diagnostics.

Phase 3 adds a 16-beat DJ blend (`djBlendDurationMs`, clamped to 4–15 s) and low-shelf ducking on the outgoing track (`bass=f=150:g=-8`). The filter is applied only when the standby player is created, because mpv's `af` chain is a per-player snapshot.

## Glitch-free transitions

Automix uses the same crossfade engine as manual changes:

- 220 ms constant-power handoff between main and standby players
- both volumes applied in parallel on every tick, with progress recomputed from the stopwatch so a skipped tick cannot leave a volume step
- final volumes written explicitly, and forced on timeout, so the main player is silent when it seeks to the next track
- standby re-synchronised to the exact main position at the trigger, avoiding phasing
- incoming stream awaited until it is playing and buffered; the outgoing standby stays audible at full volume during the wait

See [`CROSSFADE.md`](CROSSFADE.md).

## Diagnostics

**Settings → Player → Automix diagnostics** shows state (IDLE, MONITOR, ARMED, HANDOFF, FADING), crossfade/automix active, lead, blend, trigger, levels, BPM/key/mix points for both tracks, tempo ratio, and the last 150 log entries. The log is also written to `%LOCALAPPDATA%\com.echo\Echo Music\automix.log`. **Show overlay in player** reproduces the Android monospace overlay.

With `ECHO_DIAG=1`:

- `GET /automix/state` — full state as JSON
- `POST /settings/crossfade?enabled=1&seconds=5` — enable crossfade
- `POST /beat/analyze-song?id=VIDEO_ID` — analyse a song without a queue
- `POST /queue/crossfade-test` — simulate an automatic transition

`POST /beat/analyze` generates a 120 BPM click track and checks decoding and analysis end to end.

Two bugs found during integration are fixed: analysis now uses `StreamResolver.instance` instead of a failing GetIt lookup, and pre-arm no longer cancels on a missing `bufferedPosition` but retries `play()` at the trigger. FFmpeg decoding sends the YouTube User-Agent and records exit code and logs on failure.

## Limits

Android ducking is per-sample with a ramp. Here it is a static filter on the outgoing player, masked by the incoming fade-in. Harmonic comparison considers only the next three queued tracks, not the whole library or radio recommendations.

## Tests

`test/beat_analysis_test.dart` covers FFT, BPM on a synthetic track, silence, trigger alignment and cache round-trips. `test/automix_integration_test.dart` covers settings-to-transition wiring, the incoming-ready wait and standby re-sync.
