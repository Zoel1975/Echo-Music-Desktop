# Architecture

Components of Echo Music Desktop and how they connect. User-facing behaviour is in [`FEATURES.md`](FEATURES.md).

## Stack

- Flutter (Dart), Windows x64
- media_kit/mpv for playback and the DSP chain
- ffmpeg_kit_flutter_new_audio for decoding, analysis and MP3 export
- Hive for preferences, token caches, history and indexes
- http and cookie_store for InnerTube requests
- Inno Setup for the installer

## Layout

```
lib/
  main.dart                  startup, DI, session, fallback UI
  core/                      theme, shared widgets, animations
  screens/                   pages (home, player, library, settings, ...)
  services/
    stream_resolver.dart     InnerTube audio URL resolution
    po_token_minter.dart     local BotGuard PoToken minting
    media_player.dart        queue, crossfade, automix, DSP
    crossfade_engine.dart    constant-power two-player ramp
    crossfade_prearm.dart    AdaptivePreArmManager
    beat_analysis.dart       FFT, BPM, phase, key, mix-in/out
    beat_analyzer_service.dart  FFmpeg decoding + Hive cache
    comments_service.dart    `next` endpoint for comments
    song_recognition_service.dart  microphone, fingerprint, matching
    cast/                    CastV2, mDNS, DIAL
  ytmusic/                   InnerTube client and browse/search/library mixins
  utils/                     router, bottom sheets, history, modals
assets/
  po/po_token.html           BotGuard page used for the PoToken
  fonts/                     bundled Android fonts
installer/EchoMusic.iss      Inno Setup source
test/                        unit and integration tests
```

## Playback

1. `MediaPlayer.playSong()` receives a song with a `videoId`.
2. `StreamResolver.resolve(videoId)` gets `visitorData` and the real `signatureTimestamp`, tries InnerTube clients in order (VISIONOS, WEB_REMIX, WEB_CREATOR, ...), deciphers `signatureCipher` formats with the player JS through Node when that is all the response contains, adds `pot=` and `cpn=`, and checks the URL with a ranged GET.
3. `_getAudioSource()` creates a `StreamAudioSource` with the URL and headers.
4. The main player plays and the DSP applies EQ and normalization.

## Crossfade and Automix

The position stream calls `_maybePreArmQueueCrossfade()` on every tick. When the adaptive lead remains, `_prepareStandby()` starts a second player with the current track, muted. At the blend point, `_triggerQueueCrossfade()` performs the 220 ms handoff, moves the main player to the next track at the `beatAlignedStartMs()` offset, and runs the constant-power crossfade. `_applyHarmonicMix()` reorders the queue by Camelot key before the trigger.

See [`CROSSFADE.md`](CROSSFADE.md) and [`AUTOMIX.md`](AUTOMIX.md).

## PoToken

`PoTokenMinter` runs the bundled JavaScript in `assets/po/po_token.html` inside a Chrome page connected over CDP to the sign-in profile. The token is cached per session in Hive until it expires and is sent as `serviceIntegrityDimensions.poToken` in the player body and `pot=` on the media URL. See [`AGE_GATE.md`](AGE_GATE.md).

## Comments

`CommentsService` uses `youtubei/v1/next` with the WEB client. It finds the continuation token in `twoColumnWatchNextResults` or `engagementPanels` and merges the legacy and framework payloads. `comment_sheet.dart` renders the sheet.

## Song recognition

`SongRecognitionService` records the microphone with FFmpeg `dshow` at 16 kHz mono, extracts spectral landmarks with the in-repo FFT, builds a Hive index of decoded local songs, and matches with Jaccard similarity. No external service is used.

## Storage

| Hive box | Contents |
|---|---|
| `SETTINGS` | preferences, visitor id, account epoch |
| `POTOKENS` | PoTokens per video id |
| `BEAT_ANALYSIS` | cached beat analysis |
| `RECOGNITION_INDEX` | fingerprints of local songs |
| `RECOGNITION_HISTORY` | recognition results |
| `QUEUE_SNAPSHOT` | playback queue |

## Checks

```bash
flutter analyze      # 0 errors
flutter test         # 391 tests, 6 skipped
tool/verify.ps1      # full verification
```

Screen and service parity is checked in `test/parity_90_test.dart` and `test/full_parity_evidence_test.dart`; settings wiring in `test/settings_wiring_test.dart`.
