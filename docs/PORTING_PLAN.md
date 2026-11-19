# Echo Music — Desktop Port Plan

Porting **`EchoMusicApp/Echo-Music`** (Android, Kotlin + Jetpack Compose) onto
**`Zoel1975/Echo-Music-Desktop`** (Flutter), keeping Dart/Flutter as the target stack.

| | Android source of truth | Desktop target |
|---|---|---|
| Repo | `EchoMusicApp/Echo-Music` @ `16e2a4c` | `Zoel1975/Echo-Music-Desktop` @ `79e0e76` |
| Language | Kotlin 2.x, Compose, Media3 | Dart 3.10+, Flutter, `flutter_bloc` |
| Size | 873 `.kt` files / ~184k lines, 22 Gradle modules | 121 `.dart` files (excl. generated) / ~20k lines |
| Local `lib/` equivalent | `app/` + 21 modules | single `lib/` tree |
| Licence | GPL-3.0 | GPL-3.0 |

Local checkouts:

```
echo-music-desktop/            ← this repo (Flutter app)
echo-music-reference/Echo-Music/   ← Android reference (read-only, never built here)
```

> **Licence:** both projects are GPL-3.0. The desktop port is a derivative work:
> it must stay GPL-3.0, ship the licence text, and keep attribution to both
> upstreams. No assets copied from the Play Store / YouTube Music.

---

## 1. Ground rules for the port

1. **Behaviour comes from the Kotlin source, not from guesses.** When a screen or
   service is ported, the Android file that defines it is named in the commit
   message (`port: queue reorder ← playback/Queue.kt`).
2. **No Android-only API in shared code.** `just_audio_background`, Media3
   sessions, `RenderEffect` glass, Android widgets, ringtones, USB-DAC bit-perfect
   and SAF folder pickers are platform-gated or dropped with a documented
   desktop equivalent.
3. **UI parity is visual parity, not code parity.** Echo's own `DESIGN.md` is the
   spec: translucent `surfaceVariant @ 30%`, 24/28dp radii, flat elevation,
   grouped iOS-style settings lists, glass chrome, bold expressive headers.
4. **Every phase must end green**: `flutter analyze` clean, `flutter test` passing,
   `flutter build windows` producing a runnable binary.
5. **One vertical slice at a time.** No "big bang" rewrite of `lib/`.

---

## 2. Current desktop baseline (what already works)

Already implemented and worth keeping:

- **InnerTube client** (`lib/ytmusic/`): home, browse, search, charts, library,
  playlists, continuations, `visitorData` handling.
- **Playback** (`lib/services/media_player.dart`, `yt_audio_stream.dart`,
  `custom_audio_stream.dart`, `stream_client.dart`): `just_audio` +
  `media_kit` on desktop, custom `StreamAudioSource` that re-serves YouTube
  ranges through a local HTTP server (`http_server`).
- **Downloads** (`download_manager.dart`), **library** (`library.dart`, Hive),
  **lyrics** (`lyrics.dart`, `lrcnet_api.dart`), **settings** (`settings_manager.dart`),
  **Spotify import** (`spotify.dart`, `import_service.dart`).
- **Screens**: home, browse, mood/genre chip, charts, search, favourites,
  downloads (+ downloading, download playlist), history, local playlists,
  player with lyrics box + queue, settings (appearance, player, equalizer,
  privacy, YT Music service, backup/storage, about).

### Blockers found in the baseline

| # | Problem | Impact | Fix |
|---|---|---|---|
| B1 | `youtube_explode_dart` points at `github.com/iad1tya/youtube_explode_dart`, which **no longer exists (404)** | `flutter pub get` cannot resolve; app cannot build at all | Replace with a supported resolution path (see §5) |
| B2 | `just_audio_background` is Android/iOS-only | Dead weight on desktop, init call is a no-op that can throw | Gate behind `Platform.isAndroid/isIOS` |
| B3 | Package name is `Echo` (uppercase) | Dart lints, poor convention | Deferred: a global rename churns every import and makes upstream merges harder. Do it once, in Phase 2, together with the `lib/` restructure. |
| B4 | Single flat `lib/screens|services` tree | Doesn't scale to ~150 screens | Feature-first layout (§4) |
| B5 | No tests beyond a widget smoke test | Regressions invisible while porting | Golden/widget tests per ported screen |

---

## 3. Parity matrix

Legend — **DONE** exists on desktop · **PART** partial · **TODO** missing ·
**N/A** Android-only, replaced by a desktop equivalent.

### 3.1 Shell, navigation, design

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `FloatingTabBar`, `FloatingNavBar` | `NavigationRail` / `NavigationBar` | PART | 2 |
| `GlassEffect.kt` + `backdrop/*` (36 files) | — | N/A → `BackdropFilter` + `flutter_acrylic` | 2 |
| `DESIGN.md` tokens (30% surfaces, 24dp, flat) | ad-hoc Material 3 | PART | 2 |
| Dynamic seed `0xFFED5564` → `materialKolor` | `ColorScheme.fromSeed` | PART | 2 |
| `PlayerMenu`, `MiniPlayer`, `FloatingMiniPlayer` | `bottom_player.dart` | PART | 2 |
| `Player.kt` (full player, 3 layouts) | `player_page.dart` | PART | 2 |
| `BigSeekBar`, `WavySlider`, `SquigglySlider` | `audio_video_progress_bar` | PART | 2 |
| `AppNavigation` / `NavigationBuilder` | `router.dart` | PART | 2 |

### 3.2 Discovery

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `HomeScreen` + `HomeViewModel` | `home_page.dart` | PART | 3 |
| `ExploreScreen`, `NewReleaseScreen` | — | TODO | 3 |
| `ChartsScreen` | `chart_details_page.dart` | PART | 3 |
| `MoodAndGenresScreen` | `chip_page.dart` | PART | 3 |
| `BrowseScreen`, `YouTubeBrowseScreen` | `browse_page.dart` | PART | 3 |
| `PodcastHome`, `podcast/*` | — | TODO | 7 |
| `musicflow/*` (9 files, Resso-style flow) | — | TODO | 6 |

### 3.3 Search

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `OnlineSearchScreen` + suggestions (`suggestions/*`) | `search_page.dart` | PART | 3 |
| `LocalSearchScreen` | — | TODO | 5 |
| `SearchBar`, `search/history` | inline | PART | 3 |

### 3.4 Detail screens

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `AlbumScreen` + `AlbumViewModel` | — | **TODO** | 3 |
| `ArtistScreen`, `ArtistSongs`, `ArtistAlbums`, `ArtistItems` | — | **TODO** | 3 |
| `OnlinePlaylistScreen`, `BottomPlaylistScreen`, `TopPlaylistScreen` | download-playlist only | PART | 3 |
| `LocalPlaylistScreen`, `AutoPlaylistScreen`, `CachePlaylistScreen` | `playlist_details_page.dart` | PART | 4 |
| `CanvasAlbum`, `AmbientModeScreen` | — | TODO | 8 |

### 3.5 Library

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `LibraryScreen` + songs/albums/artists/playlists/mix/podcasts | `library_page.dart` (favourites, downloads, history) | PART | 4 |
| `LibrarySongsScreen`, `LibraryAlbumsScreen`, `LibraryArtistsScreen` | — | **TODO** | 4 |
| `HistoryScreen`, `DetailedListeningHistoryScreen` | `history_page.dart` | PART | 4 |
| `LocalSongScreen` + `LocalSongScanner` | — | TODO | 6 |
| `StatsScreen`, `ListeningSummaryScreen`, `wrapped/*` | — | TODO | 8 |
| `BlockedArtistsScreen`, `DislikedSongsScreen` | — | TODO | 5 |

### 3.6 Playback engine

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `MusicService` (Media3) + `PlayerConnection` | `media_player.dart` (just_audio) | PART | 1 |
| `Queue`, `YouTubeQueue`, `RadioQueuePageFilter`, `QueueExt` | `queue_list.dart` (read-only) | PART | 1 |
| `SleepTimer` | — | **TODO** | 1 |
| Crossfade / `StandbyCrossfadeScheduler`, `EqualPowerCurve` | — | TODO | 6 |
| `PlaybackCutoffGuard`, `AdaptivePreArmManager` | — | TODO | 6 |
| `SponsorBlockRepository` | — | TODO | 6 |
| `usbaudio/*` bit-perfect, `dsp-core`, `audio-dsp` | — | N/A (no Android audio HAL) | 9 |
| `EqualizerScreen` + `AXION`/AutoEq | `equalizer_page.dart` | PART | 6 |
| `AudioExportService`, `ExportTaskQueue` | `download_manager.dart` | PART | 4 |

### 3.7 Lyrics

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `LyricsHelper`, `LyricsUtils`, `LyricsProviderRegistry` | `lyrics.dart` | PART | 5 |
| `LrcLibLyricsProvider` | `lrcnet_api.dart` | PART | 5 |
| `KuGou`, `BetterLyrics`, `SimpMusic`, `YouLyPlus`, `PaxSenix`, `Unison`, `YouTube*` providers | — | **TODO** | 5 |
| Word-by-word sync, `LyricsV2`, `EchoMusicLyrics` animations | `lyrics_box.dart` | PART | 5 |
| `LyricsTranslationHelper` + DeepL/Mistral/OpenRouter/ApiRoute | — | TODO | 5 |
| `SunoLyrics`, Genius/Wikipedia "Song DNA" | — | TODO | 8 |

### 3.8 Account, sync, integrations

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `LoginScreen` + WebView cookie auth | — | **TODO** | 4 |
| `AccountScreen`, `AccountSettingsScreen` | — | TODO | 4 |
| `ListenTogether*` (protocol + server) | — | TODO | 8 |
| `DiscordPresenceManager` | — | TODO (desktop RPC is easier) | 8 |
| `LastFMSettings`, `ListenBrainzManager` | — | TODO | 8 |
| `cloud/Jellyfin*`, `cloud/Navidrome*` | — | TODO | 8 |
| `spotify/*`, `SpotifyImportScreen` | `spotify.dart`, `import_service.dart` | PART | 4 |
| `ExtensionManager` (320 kbps / lossless servers) | — | TODO | 9 |
| `recognition/*` (Shazam-style Echo Find) | — | TODO | 9 |
| `EchoBrain`/`ai/*` (AI playlists, recommendations) | — | TODO | 9 |
| `echomusic/updater/*` | `update_service/` | PART | 9 |
| Android widgets (`widget/*`, 15 files) | — | N/A (replaced by tray/MPRIS) | 9 |
| `Ringtone*`, `quicksettings/*`, `localmedia` | — | N/A | — |

---

## 4. Target architecture

```
lib/
  main.dart                    # bootstrap only
  app.dart                     # MaterialApp.router, theme, glass shell
  core/
    theme/                     # tokens, light/dark, dynamic seed, typography
    widgets/                   # glass_surface, echo_card, section_header, slivers
    utils/                     # formatters, extensions, platform guards
    router/                    # go_router config, typed routes
  data/
    innertube/                 # client + models (evolved from lib/ytmusic)
    db/                        # Hive boxes, migrations
    repositories/              # home, album, artist, playlist, library, search…
  features/
    <feature>/
      domain/                  # entities + use cases (pure Dart, testable)
      data/                    # repository impl, DTO mapping
      presentation/            # bloc/cubit, page, widgets
  services/                    # audio engine, downloads, lyrics, integrations
```

Rules:

- `core/` and `features/*/domain` must not import `package:flutter/material.dart`
  (except `core/theme`), so they stay testable headless.
- Every cubit gets `bloc_test` coverage; every page gets a golden at 1280×800
  and 420×900.
- Platform-specific code sits behind `core/utils/platform.dart` (`isDesktop`,
  `isMobile`), never inline `Platform.isX` in widgets.

### State & DI

Keep `flutter_bloc` (already a dependency, matches the Android MVVM/StateFlow
shape closely) and `get_it`. One cubit per screen, Android `*ViewModel` is the
direct template.

### Audio

`just_audio` + `just_audio_media_kit` stays. The local HTTP relay
(`custom_audio_stream.dart` + `http_server`) is the desktop equivalent of
Media3's `ChunkedDataSource` and is what makes header injection / range
requests / download acceleration work — keep and harden it.

---

## 5. Streaming resolution: replacing the dead fork (B1)

The fork existed to add `androidVr` client support + throttled-range handling.
Options, in order of preference:

1. **Port the Android resolver.** `innertube/.../InnerTube.kt` (`player` call,
   `streamingData` parsing, `signatureCipher`, `n`-param) run through Android
   `NewPipeExtractor`. This is the most faithful and the only one that matches
   the Android app's behaviour. Cost: high.
2. **`youtube_explode_dart` from pub.dev** (3.x). Drop-in for the current call
   sites, loses the fork's tweaks. Cost: low. **Start here**, keep the resolver
   behind `data/innertube/stream_resolver.dart` so (1) can replace it later.
3. Local fork under `packages/youtube_explode/` if we need to patch clients.

Decision: **2 now, 1 in Phase 6**, behind a single interface.

---

## 6. Phases

Each phase ends with a runnable Windows build and documented parity gain.

| Phase | Scope | Exit criteria |
|---|---|---|
| **0 — Foundations** | Toolchain, `pub get`, dead-dep fix, package rename, feature-first skeleton, `docs/PORTING_PLAN.md`, CI script | `flutter analyze` clean, `flutter build windows` ok, app boots with home + player |
| **1 — Playback core** | Queue model (shuffle/repeat/reorder/skip-to), sleep timer, resume state, playback errors, mini-player parity | Queue ops covered by tests; app survives 30 min playback + restarts |
| **2 — Shell & design system** | Echo tokens, glass chrome, floating tab bar, responsive rail, full player layouts, adaptive widgets | Side-by-side screenshots match Android within tolerance |
| **3 — Discovery & detail** | Explore, new releases, album, artist, online playlist, search suggestions | Every Android home/browse tile leads to a real screen |
| **4 — Library & account** | Library sub-tabs, cookie login, account, playlist CRUD, sync of liked songs | Login persists; liked songs round-trip to YouTube Music |
| **5 — Lyrics suite** | 7 providers + registry ordering, word-by-word, translations (DeepL/Mistral/OpenRouter/ApiRoute) | Provider fallback tested; translation cached |
| **6 — Local & smart playback** | Local file scanning, local playlists, crossfade, SponsorBlock, Equalizer AXION + AutoEq | Local album plays; skip segments honoured |
| **7 — Podcasts** | Podcast home, episode progress, video podcast | Podcast episode resumes across sessions |
| **8 — Social & cloud** | Listen Together, Discord RPC, LastFM/ListenBrainz, Jellyfin/Navidrome, Wrapped/stats | Two desktop clients sync a queue |
| **9 — Mobile-only leftovers** | Extensions (320 kbps/lossless), Echo Find, Echo Brain, updater parity | Documented: feature / dropped / replaced |

---

## 7. Risks

| Risk | Mitigation |
|---|---|
| InnerTube breaking changes / po_token enforcement | Resolver behind an interface; mirror Android client versions; surface `PlaybackError` UI |
| 184k lines of Kotlin to read | Port screen-by-screen, always cite source file; never invent behaviour |
| Glass effects perform badly on Windows | Blur budget: `ImageFilter.blur` ≤ 2 live blurs, fallback to solid tint under 30 fps |
| `media_kit` codec gaps on Windows | Keep m4a/AAC preference from `yt_audio_stream.dart`; test opus fallback |
| No signing / notarisation in CI | Phase 9, out of scope until feature parity |
| Legal | GPL-3.0 both sides; no copyrighted assets; keep both upstreams attributed |

---

## 8. Progress log

### Phase 0 — done (build unblocked)

- Toolchain: Flutter 3.50.0 / Dart 3.14.0 (SDK installed at `C:\Users\zampe\flutter`).
  Windows builds additionally need the VS 2022 **Desktop development with C++**
  workload (`Microsoft.VisualStudio.Workload.NativeDesktop`), CMake and a Windows 10/11 SDK.
- **B1 fixed**: `youtube_explode_dart` now resolves from pub.dev `^3.1.0` instead of
  the deleted `iad1tya` fork. `YoutubeApiClient.androidVr` exists there, so the
  call sites are unchanged.
- **B2 fixed**: `JustAudioBackground.init` runs only on Android/iOS (`lib/main.dart`).
- Removed the non-existent `assets/images/` asset entry.
- `.gitignore` added; `tool/verify.ps1` runs pub get → analyze → test (→ build).
- Analyzer: **0 errors**, 47 warnings (pre-existing unused imports/deprecations).

### Phase 1 — started (playback core)

- **`SleepTimer` ported** (`lib/services/sleep_timer.dart`) from
  `playback/.../SleepTimer.kt`: timed mode with 3 s / 30-step fade-out then pause
  and volume restore, plus "pause at end of track" mode armed on media item
  transitions or playback completion. Injected `SleepTimerTarget` keeps it
  testable without a real player.
- `MediaPlayer` now owns the timer, and the timer sheet (`bottom_modals.dart`)
  exposes the new **End of song** option and shows which mode is active.
- **Queue sheet fixes** (`screens/player/widgets/queue_list.dart`):
  shuffle no longer Android-only, index-scoped keys (duplicate songs no longer
  collide), explicit drag handle instead of fighting swipe-to-remove, no
  double-dispose on removal.
- Tests: `test/sleep_timer_test.dart` (7 cases) — replaces the stale
  counter boilerplate test, which could never have passed.

Next: queue persistence across restarts, richer playback error surfacing, then
Phase 2 (design tokens + glass shell) with screenshot parity.

