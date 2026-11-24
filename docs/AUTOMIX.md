# Automix — phase 3 (DJ blend + ducking)

Port of Echo Android's Automix. This build contains phase 3.

## What is included

- `lib/services/beat_analysis.dart`: port of `BeatAnalyzer` (radix-2 FFT, spectral flux, autocorrelation for BPM 60–180 with 70–140 folding, comb filter for beat phase). Pure and testable.
- `lib/services/beat_analyzer_service.dart`: decodes a 30 s window at 22050 Hz mono with FFmpeg Kit (already present for MP3 export), runs the analysis, and caches the result per video id in Hive (`BEAT_ANALYSIS`).
- `automixTriggerMs()`: moves the start of the crossfade so the end of the blend lands on a beat of the outgoing track, near its dynamic **mix-out** (energy scan of the tail with `-sseof`);
- **phase 2**: the incoming track is also analyzed during pre-arm; `beatAlignedStartMs()` computes the entry offset so one of its beats lands exactly at the end of the fade (phase matching), starting from the dynamic **mix-in** (energy scan of the intro);
- **Automix · beat align** setting (Player, enabled by default when crossfade is on);
- diagnostic probe `POST /beat/analyze` (with `ECHO_DIAG=1`) that generates a 120 BPM click track and verifies decoding plus analysis end to end.
- **phase 3**: a **16-beat** DJ blend (`djBlendDurationMs`, clamped 4–15 s) instead of a fixed duration; **low-shelf ducking** on the outgoing track (`bass=f=150:g=-8`) applied only when the standby player is created, because mpv's `af` chain is a per-player snapshot; key detection (Krumhansl–Schmuckler) as `keyLabel`;
- **harmonic mixing** (`harmonic_mixing.dart`): the key is converted to the Camelot wheel (1A–12A / 1B–12B) and used to choose the next track from the first three in the queue. Score: same key 1.0, relative major/minor 0.85, perfect fifth (descending on the wheel) 0.7, otherwise 0. The best candidate is moved right after the current track with `moveAudioSource`. Setting **Automix · harmonic mixing** in Player (on by default) and the result are visible in diagnostics. Candidate analysis is limited to 3 s each so it does not consume the pre-arm lead.

## Glitch-free transitions

Automix transitions use the same crossfade engine as manual track changes:

- the handoff between the main and standby players lasts **220 ms** with a constant-power curve;
- both volumes are applied in parallel on every tick and progress is recomputed from the stopwatch, so a skipped tick cannot leave a coarse volume step;
- final volumes are written explicitly at the end (and forced on timeout), so the main player is always silent when it seeks to the next track;
- the standby is re-synchronized to the exact main-player position at the trigger, so two offset copies of the same song cannot produce a phasing glitch;
- before the fade begins, the incoming stream is awaited until it is playing and buffered — the outgoing standby covers the wait at full volume.

See [`CROSSFADE.md`](CROSSFADE.md) for details.

## Diagnostics (port of the Android debug overlay)

- **Settings → Player → Automix diagnostics** shows state (IDLE, MONITOR, ARMED, HANDOFF, FADING), crossfade/automix active, lead/blend/trigger, levels, BPM/key/mix points for outgoing and incoming, tempo ratio, and the event log (last 150 entries).
- The log is also written to `%LOCALAPPDATA%\com.echo\Echo Music\automix.log`.
- Switch **Show overlay in player** reproduces Android's monospace overlay (state, BPM in/out, key, next mix).
- With `ECHO_DIAG=1`: `GET /automix/state` returns all state as JSON, `POST /settings/crossfade?enabled=1&seconds=5` enables crossfade, `POST /beat/analyze-song?id=VIDEO_ID` analyzes a song without a queue (verifies IN/OUT), and `POST /queue/crossfade-test` simulates an automatic transition.

Analysis did not start because `StreamResolver` is a static singleton and the service checked `GetIt.I.isRegistered<StreamResolver>()`, which was always false. It now uses `StreamResolver.instance` directly; FFmpeg decoding includes the YouTube User-Agent and records exit code/logs on failure.

The pre-arm has a guard against concurrent calls from the position stream and, if media_kit does not expose `bufferedPosition`, proceeds anyway and retries `play()` at the trigger: before this fix every pre-arm was cancelled and automatic crossfade never started.

## Phase 3 limitations

- Android's ducking is per-sample with a ramp (no zipper noise); here it is a static filter on the outgoing player, masked by the incoming fade-in. It is not a per-sample IIR but avoids muddy bass.
- Harmonic comparison only considers the 3 next tracks in the queue, not the whole library or radio recommendations.

## Tests

`test/beat_analysis_test.dart` covers FFT, BPM detection on a synthetic track, silence, trigger alignment, and cache round-trip. `test/automix_integration_test.dart` verifies the wiring from settings to the transition, including the incoming-ready wait and standby re-sync.
