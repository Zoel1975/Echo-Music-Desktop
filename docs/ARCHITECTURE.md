# Technical architecture

An overview of the components of Echo Music Desktop and how they connect. For the user-facing features see [`FEATURES.md`](FEATURES.md).

## Stack

- **Flutter** (Dart) with a Windows x64 backend;
- **media_kit / mpv** for audio playback and the DSP chain;
- **ffmpeg_kit_flutter_new_audio** for decoding, analysis, and MP3 export;
- **Hive** for preferences, token caches, history, and indexes;
- **http** + **cookie_store** for InnerTube requests;
- **Inno Setup** for the Windows installer.

## Folder structure

```
lib/
  main.dart                  startup, DI, session, fallback UI
  core/                      theme, shared widgets, animations
  screens/                   pages (home, player, library, settings, ...)
  services/                  business logic
    stream_resolver.dart     audio URL resolution via InnerTube
    po_token_minter.dart     local BotGuard PoToken minting
    media_player.dart        queue, crossfade, automix, DSP
    crossfade_engine.dart    constant-power two-player ramp
    crossfade_prearm.dart    AdaptivePreArmManager
    beat_analysis.dart       FFT, BPM, phase, key, mix-in/out
    beat_analyzer_service.dart  FFmpeg decoding + Hive cache
    comments_service.dart    `next` endpoint for comments
    song_recognition_service.dart  microphone + fingerprint + matching
    cast/                    CastV2, mDNS, DIAL
    ...
  ytmusic/                   InnerTube client and mixins (browse, search, library, ...)
  utils/                     router, bottom sheets, history, modals
assets/
  po/po_token.html           BotGuard page for the PoToken
  fonts/                     bundled Android fonts
installer/EchoMusic.iss      Inno Setup source
test/                        unit and integration tests
```

## Playback flow

1. **Song selection** — `MediaPlayer.playSong()` receives a song (with `videoId`).
2. **Stream resolution** — `StreamResolver.resolve(videoId)`:
   - obtains `visitorData` and the real `signatureTimestamp`;
   - tries InnerTube clients in order (VISIONOS, WEB_REMIX, WEB_CREATOR, ...);
   - deciphers `signatureCipher` formats with the player JS via Node when that is all the response contains;
   - appends `pot=` and `cpn=` to the media URL;
   - validates the URL with a ranged GET before returning it.
3. **Audio source** — `_getAudioSource()` creates a `StreamAudioSource` with headers and URL.
4. **Playback** — the main player plays; the DSP applies EQ and normalization.

## Crossfade and Automix

- the position stream calls `_maybePreArmQueueCrossfade()` on every tick;
- when the adaptive lead time remains, `_prepareStandby()` creates a second player with the current track and starts it muted;
- when the blend duration remains, `_triggerQueueCrossfade()`:
  1. performs the 220 ms handoff between the main and standby players;
  2. moves the main player to the next track at the offset computed by `beatAlignedStartMs()`;
  3. starts the constant-power crossfade for the blend duration;
- `_applyHarmonicMix()` reorders the queue according to the Camelot wheel before the trigger.

Details in [`CROSSFADE.md`](CROSSFADE.md) and [`AUTOMIX.md`](AUTOMIX.md).

## BotGuard / PoToken

`PoTokenMinter` executes the bundled JavaScript (`assets/po/po_token.html`) in a Chrome page connected over CDP to the sign-in profile. The token is stored per session in Hive and reused until it expires. It is sent as `serviceIntegrityDimensions.poToken` in the player body and as `pot=` on the media URL. See [`AGE_GATE.md`](AGE_GATE.md).

## Comments

`CommentsService` uses the `youtubei/v1/next` endpoint with the **WEB** client (not WEB_REMIX), discovers the continuation token in `twoColumnWatchNextResults` or `engagementPanels`, and merges legacy and framework payloads. `comment_sheet.dart` draws the modal sheet.

## Song recognition

`SongRecognitionService` records the microphone with FFmpeg `dshow` at 16 kHz mono, extracts a set of spectral landmarks with the in-repo FFT, builds a Hive index of decoded local songs, and matches with Jaccard similarity. No external service is used.

## Persistence

| Hive box | Contents |
|---|---|
| `SETTINGS` | preferences, visitor id, account epoch |
| `POTOKENS` | PoTokens per video id |
| `BEAT_ANALYSIS` | cached beat analysis |
| `RECOGNITION_INDEX` | fingerprints of local songs |
| `RECOGNITION_HISTORY` | recognition results |
| `QUEUE_SNAPSHOT` | playback queue |

## Tests and verification

```bash
flutter analyze      # 0 errors
flutter test         # 363 tests, 6 skipped
tool/verify.ps1      # full verification
```

Parity is verified by tests that check the existence of screens and services (`test/parity_90_test.dart`, `test/full_parity_evidence_test.dart`). Settings wiring is verified by `test/settings_wiring_test.dart`.
