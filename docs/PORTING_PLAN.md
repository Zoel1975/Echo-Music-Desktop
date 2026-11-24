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
echo-music-desktop/            ? this repo (Flutter app)
echo-music-reference/Echo-Music/   ? Android reference (read-only, never built here)
```

> **Licence:** both projects are GPL-3.0. The desktop port is a derivative work:
> it must stay GPL-3.0, ship the licence text, and keep attribution to both
> upstreams. No assets copied from the Play Store / YouTube Music.

---

## 1. Ground rules for the port

1. **Behaviour comes from the Kotlin source, not from guesses.** When a screen or
   service is ported, the Android file that defines it is named in the commit
   message (`port: queue reorder ? playback/Queue.kt`).
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
| B1 | `youtube_explode_dart` points at `github.com/iad1tya/youtube_explode_dart`, which **no longer exists (404)** | `flutter pub get` cannot resolve; app cannot build at all | Replace with a supported resolution path (see —5) |
| B2 | `just_audio_background` is Android/iOS-only | Dead weight on desktop, init call is a no-op that can throw | Gate behind `Platform.isAndroid/isIOS` |
| B3 | Package name is `Echo` (uppercase) | Dart lints, poor convention | Deferred: a global rename churns every import and makes upstream merges harder. Do it once, in Phase 2, together with the `lib/` restructure. |
| B4 | Single flat `lib/screens|services` tree | Doesn't scale to ~150 screens | Feature-first layout (—4) |
| B5 | No tests beyond a widget smoke test | Regressions invisible while porting | Golden/widget tests per ported screen |

---

## 3. Parity matrix

Legend — **DONE** exists on desktop — **PART** partial — **TODO** missing —
**N/A** Android-only, replaced by a desktop equivalent.

### 3.1 Shell, navigation, design

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `FloatingTabBar`, `FloatingNavBar` | `floating_nav.dart` single floating glass bar (per user choice) + `shell_chrome_test.dart` | DONE | 2 |
| `GlassEffect.kt` + `backdrop/*` (36 files) | — | N/A ? `BackdropFilter` + `flutter_acrylic` | 2 |
| `DESIGN.md` tokens (30% surfaces, 24dp, flat) | `core/theme/tokens.dart` + `tokens_test.dart` | DONE | 2 |
| Dynamic seed `0xFFED5564` ? `materialKolor` | `ColorScheme.fromSeed` in `core/theme` | DONE | 2 |
| `PlayerMenu`, `MiniPlayer`, `FloatingMiniPlayer` | `shell/widgets/bottom_player.dart` (docked mini player) + player menu | DONE | 2 |
| `Player.kt` (full player, 3 layouts) | `player_page.dart` + `player_layout.dart` (compact/narrow/wide) | DONE | 2 |
| `BigSeekBar`, `WavySlider`, `SquigglySlider` | `audio_video_progress_bar` in `player_page.dart` + Wavy/Squiggly in `appearance_details_page.dart` | DONE | 2 |
| `AppNavigation` / `NavigationBuilder` | `router.dart` (go_router shell branches) + `appshell_navbar_integration_test.dart` | DONE | 2 |

### 3.2 Discovery

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `HomeScreen` + `HomeViewModel` | `home_page.dart` | DONE | 3 |
| `ExploreScreen`, `NewReleaseScreen` | `explore_page.dart` + `/new_releases` (`FEmusic_new_releases_albums`) | DONE | 3 |
| `ChartsScreen` | `chart/chart_details_page.dart` | DONE | 3 |
| `MoodAndGenresScreen` | `chip/chip_page.dart` | DONE | 3 |
| `BrowseScreen`, `YouTubeBrowseScreen` | `browse/browse_page.dart` | DONE | 3 |
| `PodcastHome`, `podcast/*` | real `ChipPage` `/podcasts` via `FEmusic_podcasts` browse endpoint | DONE | 7 |
| `musicflow/*` (9 files, Resso-style flow) | real `music_flow_feed_page.dart` vertical-swipe `/music_flow_full` + ranking services | DONE | 6 |

### 3.3 Search

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `OnlineSearchScreen` + suggestions (`suggestions/*`) | `search_page.dart` + `ytmusic/mixins/search.dart` | DONE | 3 |
| `LocalSearchScreen` | `local_search_page.dart` (`/search/local`) | DONE | 5 |
| `SearchBar`, `search/history` | inline + Hive `SEARCH_HISTORY` (`search_cubit.dart`, `privacy_cubit.dart`) | DONE | 3 |

### 3.4 Detail screens

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `AlbumScreen` + `AlbumViewModel` | `album_page.dart` (`/album`) | DONE | 3 |
| `ArtistScreen`, `ArtistSongs`, `ArtistAlbums`, `ArtistItems` | `artist_page.dart` (`/artist`) | DONE | 3 |
| `OnlinePlaylistScreen`, `BottomPlaylistScreen`, `TopPlaylistScreen` | `playlist_page.dart` (`/playlist`) + `playlist_details_page.dart` + ranked auto-playlists (Top/Bottom) | DONE | 3 |
| `LocalPlaylistScreen`, `AutoPlaylistScreen`, `CachePlaylistScreen` | `playlist_details_page.dart` | DONE | 4 |
| `CanvasAlbum`, `AmbientModeScreen` | real `ambient_page.dart` `/canvas_ambient` (animated bg + art + lyrics) | DONE | 8 |

### 3.5 Library

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `LibraryScreen` + songs/albums/artists/playlists/mix/podcasts | `library_page.dart` + `ytm_library_page.dart` (real signed-in YT library: playlists/songs/albums/artists via `LibraryMixin`, `/ytm_library`, refreshes on account epoch) + Podcasts | DONE | 4 |
| `LibrarySongsScreen`, `LibraryAlbumsScreen`, `LibraryArtistsScreen` | `library_collections_page.dart` (`/saved/library_songs` tabs 0/1/2) | DONE | 4 |
| `HistoryScreen`, `DetailedListeningHistoryScreen` | `history_page.dart` + `/saved/history_detail` | DONE | 4 |
| `LocalSongScreen` + `LocalSongScanner` | `local_songs_page.dart` (`/saved/local_songs`) | DONE | 6 |
| `StatsScreen`, `ListeningSummaryScreen`, `wrapped/*` | `listening_summary_page.dart` + `wrapped_page.dart` | DONE | 8 |
| `BlockedArtistsScreen`, `DislikedSongsScreen` | `content_filter_page.dart` (`/settings/content/*`) | DONE | 5 |

### 3.6 Playback engine

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `MusicService` (Media3) + `PlayerConnection` | `media_player.dart` (just_audio + media_kit) | DONE | 1 |
| `Queue`, `YouTubeQueue`, `RadioQueuePageFilter`, `QueueExt` | `queue_list.dart` (reorder/remove + search/dedupe filter) + `queue_filter.dart` + full queue persistence | DONE | 1 |
| `SleepTimer` | `sleep_timer.dart` (timed + end-of-track) | DONE | 1 |
| Crossfade / `StandbyCrossfadeScheduler`, `EqualPowerCurve` | `CrossfadeEngine` + `QueueCrossfadeController` (2-player equal-power, track switch + near-end pre-arm) | DONE | 6 |
| `PlaybackCutoffGuard`, `AdaptivePreArmManager` | `playback_cutoff.dart` adaptive pre-arm wired into MediaPlayer position stream | DONE | 6 |
| `SponsorBlockRepository` | `sponsor_block_service.dart` (API + auto-skip in position stream) | DONE | 6 |
| `usbaudio/*` bit-perfect, `dsp-core`, `audio-dsp` | `DesktopDsp` + mpv silenceremove; placeholder 'Bit-perfect USB DAC' | N/A/PART | 9 |
| `EqualizerScreen` + `AXION`/AutoEq | `equalizer_page.dart` + real `axion_eq_page.dart` (10-band sliders, presets, AutoEq import) + `axion_eq_service.dart`, gains applied to mpv lavfi EQ | DONE | 6 |
| `AudioExportService`, `ExportTaskQueue` | real `export_task_queue.dart` + `export_queue_page.dart` `/export_queue` | DONE | 4 |

### 3.7 Lyrics

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `LyricsHelper`, `LyricsUtils`, `LyricsProviderRegistry` | `lyrics.dart` + `lyrics_registry.dart` + tests | DONE | 5 |
| `LrcLibLyricsProvider` | `lrcnet_api.dart` | DONE | 5 |
| `KuGou`, `BetterLyrics`, `SimpMusic`, `YouLyPlus`, `PaxSenix`, `Unison`, `YouTube*` providers | `lyrics_providers.dart` + `lyrics_providers_youtube.dart` (all 9 ported) | DONE | 5 |
| Word-by-word sync, `LyricsV2`, `EchoMusicLyrics` animations | `lyrics_box.dart` (TTML/word sync + animation styles) | DONE | 5 |
| `LyricsTranslationHelper` + DeepL/Mistral/OpenRouter/ApiRoute | `lyrics_translation.dart` + `translation_dialog.dart` | DONE | 5 |
| `SunoLyrics`, Genius/Wikipedia "Song DNA" | `song_dna_service.dart` (real Genius/Wikipedia fetch) + `/song_dna` with in-app Fetch button | DONE | 8 |

### 3.8 Account, sync, integrations

| Android | Desktop | Status | Phase |
|---|---|---|---|
| `LoginScreen` + WebView cookie auth | `google_login_service.dart` (Chrome/Edge + CDP: consent cookies via `Network.setCookie` before navigating, browser-level `Storage.getCookies`, YouTube-jar-only filtering, `window.yt.config_` read for `VISITOR_DATA`/`DATASYNC_ID`) + `login_page.dart` (auto-detect + manual fallback) + `session_service.dart` (`forgetAccount` port) | DONE | 4 |
| `AccountScreen`, `AccountSettingsScreen` + device link | `account_page.dart` (`/account`) + **Google Cast pick** (`services/cast/`: raw mDNS `_googlecast._tcp` discovery, CastV2 protobuf, connect/LAUNCH Default Media Receiver/LOAD, play/pause/seek/volume) surfaced by `screens/connect/cast_page.dart` (`/cast`, reachable from Settings "Linked devices" and the cast icons in the player/mini-player), mirroring Android's `CastButton`/`CastDevicePickerSheet`; audio is streamed from Echo's LAN relay using the receiver's subnet IP. Legacy UDP playback-state announces (`device_link_announcement.dart`, `remote_control_service.dart`) remain for Echo-to-Echo LAN remote control. | DONE | 6 |
| `ListenTogether*` (protocol + server) | `listen_together_service.dart` (real LAN HTTP room publish/join) + `/listen_together` config, wired to playback | DONE | 8 |
| `DiscordPresenceManager` | `discord_rpc_service.dart` (local RPC SET_ACTIVITY) + `/discord` config, wired to playback | DONE | 8 |
| `LastFMSettings`, `ListenBrainzManager` | `scrobble_service.dart` (real now-playing/scrobble HTTP) + `/lastfm`, wired to playback | DONE | 8 |
| `cloud/Jellyfin*`, `cloud/Navidrome*` | `cloud_service.dart` (real connection checks) + `/jellyfin` with in-app Test button | DONE | 8 |
| `spotify/*`, `SpotifyImportScreen` | `spotify.dart`, `import_service.dart` + real `spotify_import_page.dart` (`/settings/services/spotify_import`, URL import + progress) | DONE | 4 |
| `ExtensionManager` (320 kbps / lossless servers) | `IntegrationPage` `/extensions` + `extension_quality.dart` (320 kbps toggle forces highest bitrate) | DONE | 9 |
| `recognition/*` (Shazam-style Echo Find) | EXPLICIT PLACEHOLDER: "Song recognition (Echo Find)" reachable menu entry + native-fingerprinting note | PLACEHOLDER | 9 |
| `EchoBrain`/`ai/*` (AI playlists, recommendations) | real `echo_brain_page.dart` + `echo_brain_service.dart` (OpenRouter playlist generation, play via search) | DONE | 9 |
| `echomusic/updater/*` | `update_service/` (real GitHub update check + dialog) | DONE | 9 |
| Android widgets (`widget/*`, 15 files) | N/A (replaced by tray/MPRIS) | N/A | 9 |
| `Ringtone*`, `quicksettings/*`, `localmedia` | N/A | N/A | - |

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
    repositories/              # home, album, artist, playlist, library, search—
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
- Every cubit gets `bloc_test` coverage; every page gets a golden at 1280x800
  and 420x900.
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
| **0 — Foundations** | Toolchain, `pub get`, dead-dep fix, feature-first skeleton, `docs/PORTING_PLAN.md`, CI script | `flutter analyze` clean, `flutter build windows` ok, app boots with home + player |
| **1 — Playback core** *(done — full queue persistence)* | Queue model, sleep timer, resume state, playback errors, mini-player parity | Sleep timer + full queue persistence + playback errors + InnerTube stream resolver (VISIONOS client fallback chain) done — `MediaPlayer.playbackError` notifier, `saveState`/`restoreLastPlayed` on launch; queue sheet still read-only-ish; full queue persistence done |
| **2 — Shell & design system** *(done — 12f43cf)* | Echo tokens, glass surface, floating tab bar, theme seed, bootable shell | Shell boots, all screens reachable; jank fixes (single PageController, horizontal tab pager, RepaintBoundary, reduced blur, animated tab selection) |
| **3 — Discovery & detail** *(done — 380b84e)* | Album, Artist, Online Playlist pages, ItemList navigation, playable adapter | All Android home/browse tiles lead to a real screen |
| **4 — Library & account** *(done — 8109e93)* | Cookie login via WebView2 (`lib/screens/login/login_page.dart` + `lib/services/cookie_store.dart` + `YTMusic.getAccountInfo()` port of `account/account_menu`); Account screen (`lib/screens/account/account_page.dart`); `YTClient` now merges the Cookie header into every request | WebView2 login flow validated via build + smoke run (actual Google login needs credentials + Edge + WebView2; not exercised) |
| **5 — Lyrics suite** *(done — lyrics providers batch)* | LRCLIB (`lrcnet_api.dart`), Android registry ported to `lib/services/lyrics_registry.dart` + `LrcLibProvider`; tests | All 8 providers ported (lyrics_providers.dart + lyrics_providers_youtube.dart); TTML/word-timing; LyricsService fallback chain; translations (DeepL/Mistral/OpenRouter+ApiRoute + SSE streaming + caching) in lyrics_translation.dart; 50/50 tests; translation UI wired (lyrics_box.dart translate button + TranslationDialog + per-line translated display) |
| **6 — Social & cloud** | PART — menu entries present; Discord/Last.fm/ListenBrainz/Jellyfin/Navidrome/Listen Together/Extensions/EchoBrain show a "Coming in a future update" placeholder (`ComingSoonPage`); no desktop protocol implementation |
| **7 — Podcasts** | PART — placeholder entry in menu; no podcast feed/renderer |
| **8 — Mobile-only leftovers** | PART — Android-only items (Supported Links, Bit-Perfect USB DAC, on-device recognition, Canvas/Ambient, AXION/AutoEq EQ, app icon) show "Coming in a future update" placeholders; feasible items ported |

**Fine-grained appearance options (this session):** Android
`AppearanceSettings.kt` / `GlassEffectSettings.kt` / `HapticsSettings.kt`
individual options ? real `AppearanceDetailsPage` (`/settings/appearance/details`)
with persisted settings (`SettingsManager.extra<T>`) for theme variant, glass
effect (vibrancy/blur/opacity/lens/chromatic/depth, glass player/mini/nav),
player look (Apple-inspired, thumbnail radius, button colors, slider style,
wavy play/pause, rotating thumbnail, show codec, swipe sensitivity), lyrics
(animation style, blur, line spacing, click/swipe, thumbnail play/pause) and
misc (grid cell size, display density, haptic intensity). Android-only/hardware
items (App Icon/Font, status bar) show "Coming in a future update" placeholders.
Runtime effect wired for `gridCellSize` (library grid extent), `showCodec`
(player label) and `lyricsTextSize`/`lyricsLineSpacing` (LyricsBox styles).
Regression guard: `test/appearance_details_parity_test.dart`.

**Windows DSP (this session):** Genuine cross-platform DSP now wired to real
playback behavior:
- `DesktopDsp` computes replay-gain normalization from InnerTube `loudnessDb`
  (exposed via `StreamResolver.loudnessFor`) and applies it through just_audio's
  cross-platform `setVolume` — real effect on Windows (no Android enhancer).
- `QueueEndCrossfade.evaluate` pre-arms at automatic queue advance: the
  position listener overlaps the current and next queued tracks via a
  dedicated outgoing player + equal-power ramp (`QueueCrossfadeController`).
- `autoSkipOnError` now seeks to the next track on playback errors.
- Skip-silence is now genuine on desktop: a local patched
  `packages/just_audio_media_kit` (via `dependency_overrides`) adds a static
  `JustAudioMediaKit.audioFilter`; `SilenceFilter` sets mpv's
  `af=lavfi=[silenceremove=...]` before players are created, and the cubit
  re-applies it + reloads the current source on toggle. Runtime log confirmed
  mpv accepted the filter with no `af` error. `silence_filter_test.dart`.
Pure helpers unit-tested in `desktop_dsp_test.dart` (6 cases).

**Crossfade + discovery + placeholders (this session):** Real two-player
equal-power crossfade at track transitions via `QueueCrossfadeController` +
`CrossfadeDecision` (unit-tested) wired into `MediaPlayer.playSong` — the
outgoing track keeps playing on a dedicated player while the incoming track
fades in. New Releases screen (`/new_releases` ? ChipPage with
`FEmusic_new_releases_albums`) reachable from Explore. All 9 lyrics providers
(BetterLyrics, SimpMusic, YouLyPlus, KuGou, Paxsenix, Unison, LrcLib,
YouTubeSubtitle, YouTubeMusic) are implemented + wired (verified in
`lyrics.dart`/`lyrics_providers.dart`). Placeholders added for Song DNA and
ExportTaskQueue.

**Local audio + SponsorBlock (this session):** Android `LocalSongScreen` +
`LocalSongScanner` ? real `LocalSongsPage` (folder picker + recursive scan +
filename metadata) + `MediaPlayer.playLocalFile` (local-file playback branch).
Android `SponsorBlockRepository` ? real `SponsorBlockService` (public
skipSegments API + cache + `segmentAt`) wired into MediaPlayer's position
stream to auto-skip sponsored parts. Pure helpers unit-tested in
`local_scanner_sponsorblock_test.dart`. PlaybackCutoffGuard /
AdaptivePreArmManager / AXION internals remain explicit "Coming in a future
update" placeholders in Player settings.

**Detailed listening history (this session):** Android
`DetailedListeningHistoryScreen.kt` ? `HistoryDetailPage` (history grouped by
day with total replay counts) + pure `HistoryDetail` helper (unit-tested),
reachable from the History page. Search suggestions already ported
(`ytmusic/mixins/search.dart`: `getSearchSuggestions` + Hive search history).

**Appearance parity (this session):** Android `AppearanceSettings.kt` groups
ported to real persisted toggles/dropdowns in `AppearancePage`: Theme (mode,
accent, AMOLED, dynamic), Mini-player (background style), Player (background
style, hide thumbnail), Lyrics (text position/size, auto-scroll), Misc (default
open tab), Auto playlists (Liked/Downloaded/Top/Bottom/Cached visibility).
Android-only screens (App Icon, Font, Liquid Glass, Haptics, high refresh rate)
show explicit "Coming in a future update" placeholders. Regression guard:
`test/appearance_parity_test.dart`.

**Library collections (this session):** Android `LibrarySongsScreen`/`LibraryAlbumsScreen`/
`LibraryArtistsScreen` ? real `LibraryCollectionsPage` (Songs/Albums/Artists tabs over
FAVOURITES + SONG_HISTORY) + `LibrarySongListPage` detail + pure
`LibraryAggregation` helpers (unit-tested). Reachable from the Library page tiles
`/saved/library_songs` with tab index 0/1/2.

### Settings parity (features ported as REAL, not placeholders)
Mirrors Android `SettingsScreen.kt` 15 top-level entries:
- **Real pages**: Account, AI Hub (`AiSettings.kt` — provider/API key/base URL/model/mode/language/streaming), Appearance (wired — theme/accent/AMOLED/dynamic), Player and audio (full Queue/Misc/DSP groups), Content (`ContentSettings.kt` — filters/region/lyrics + Blocked Artists / Disliked Songs), Privacy, Storage (`StorageSettings.kt` — real cache clearing), Backup and restore, Youtube Music, System update, About.
- **Real data pages**: Listening Summary + Echo Wrapped (aggregated from `SONG_HISTORY`).
- **ComingSoonPage placeholders** (honest "Planned for a future update"): Discord Rich Presence, Last.fm/ListenBrainz, Jellyfin/Navidrome, Listen Together, Supported Links.
- Regression guard: `test/settings_parity_test.dart` asserts every entry renders; `ai_hub_test`, `storage_service_test`, `content_filter_test`, `content_settings_test` cover the new services.

Notes for later phases:
- **Explore / MusicFlow** (Android `ui/screens/musicflow/*`, 9 files): Resso-style
  vertical swipe discovery with ranking from `musicflow/MusicFlowRanking.kt`.
  Not yet started.
- **Search suggestions parity**: desktop `lib/ytmusic/mixins/search.dart` already
  returns `music/get_search_suggestions` results (`getSearchSuggestions`).
  Android adds an `AppleMusicScraper` — to be compared later.
- **Playback error surfacing** (Phase 1 remainder) and **queue persistence** — TODO.
- **Explore in the FloatingNavBar?** Android's tab set is Home/Search/Explore/Library/Account;
  the desktop tab set is Home/Search/Library/Settings. To match, an Explore
  branch must be added first.

(On **downloads**: see "Downloads: out of scope for now" below — this plan
list treats local/download features as non-goals until re-opened.
Phase 4's "cookie login" is done (WebView2 cookie login + account screen, 8109e93) — see
"Phase 4 — Library & account" below.)
| **9 — Explore (MusicFlow)** *(partial — 7a4f0de)* | `/explore` page (`lib/screens/explore/explore_page.dart`): Home feed, sections via `SectionItem` | Android `MusicFlowScreen` (601 lines): vertical swipe discovery, AI mix queues, lyrics, download, takeover block, preferences — not ported |

---

### Downloads: out of scope for now

You said "I don't care about music download", so the download engine
(`playback/DownloadUtil.kt`, `ExoDownloadService`, `MediaDownloadManager`,
`DownloadManager.kt`) is **deliberately dropped**. Local/audio-file playback
(the desktop already has `AudioSource.file` support and the local HTTP relay)
is reused, but nothing new is added in phases 6/9 for offline listening. This
is listed in the risks below as a documented exclusion, not an accident.

---

## 9. Risks

| Risk | Mitigation |
|---|---|
| InnerTube breaking changes / po_token enforcement | Resolver behind an interface; mirror Android client versions; surface `PlaybackError` UI |
| 184k lines of Kotlin to read | Port screen-by-screen, always cite source file; never invent behaviour |
| Glass effects perform badly on Windows | Blur budget: `ImageFilter.blur` = 2 live blurs, fallback to solid tint under 30 fps |
| `media_kit` codec gaps on Windows | Keep m4a/AAC preference from `yt_audio_stream.dart`; test opus fallback |
| No signing / notarisation in CI | Phase 9, out of scope until feature parity |
| Legal | GPL-3.0 both sides; no copyrighted assets; keep both upstreams attributed |

---

## 8. Progress log

### Phase 0 — done (build unblocked)

- Toolchain: Flutter 3.50.0 / Dart 3.14.0 (SDK installed at `C:\Users\zampe\flutter`).
  Windows builds additionally need the VS 2022 **Desktop development with C++**
  workload (`Microsoft.VisualStudio.Workload.NativeDesktop`), CMake and a Windows 10/11 SDK.
  Verified: `flutter build windows --debug` ? `build\windows\x64\runner\Debug\echo.exe`,
  and a 15 s startup smoke test with no exceptions (media_kit registered, local
  audio relay on `127.0.0.1:<port>/audio`, Hive boxes opened).
- **B1 fixed**: `youtube_explode_dart` now resolves from pub.dev `^3.1.0` instead of
  the deleted `iad1tya` fork. `YoutubeApiClient.androidVr` exists there, so the
  call sites are unchanged.
- **B2 fixed**: `JustAudioBackground.init` runs only on Android/iOS (`lib/main.dart`).
- Removed the non-existent `assets/images/` asset entry.
- `.gitignore` added; `tool/verify.ps1` runs pub get ? analyze ? test (? build).
- Analyzer: **0 errors**, 15 warnings left (dead modal helpers, the unused
  Spotify `_scopes` field, experimental `just_audio` streaming API).

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

### Phase 1 — partly done (8109e93) — playback errors + track resume

- `MediaPlayer.playbackError` (ValueNotifier<String?>) now surfaces player
  errors instead of failing silently into "paused".
- `MediaPlayer.saveState` / `restoreLastPlayed`: `MediaPlayer.stop()` persists
  the current track (`videoId`) to the new Hive box `QUEUE` (key `STATE`);
  `main()` opens the box and resumes the track on launch.
- Tests: 18/18 passing (`test/playable_test.dart` = 5 new cases; suite total
  now 18). Full-queue persistence done (QueueSnapshot + full queue restore on launch).

### Phase 2 — done (shell & design system)

- **Theme**: `ColorScheme.fromSeed(EchoTokens.seedColor)` — Android's `0xFFED5564`
  seed replaces the old `Colors.black`/`Colors.red` defaults in `AppTheme`.
- **`lib/core/theme/tokens.dart`**: Echo tokens from `DESIGN.md`/`GlassEffect.kt`
  — radii (16/20/24/28/circle), `surfaceVariant @ 30%` translucent surfaces,
  Apple glass values (0.4 opacity, 0.6 tint, 1.5 vibrancy), 48dp touch targets,
  4dp spacing scale.
- **`lib/core/widgets/echo_surface.dart`**: `EchoSurface` (glass surface: real
  `BackdropFilter` + translucent tint; no `RenderEffect` equivalent on desktop)
  and `EchoButton`.
- **`lib/core/widgets/floating_nav.dart`**: `EchoFloatingNavBar` — the desktop
  counterpart of Android's `FloatingTabBar` (glass capsule, 20dp radius,
  centered, floating above the mini player, explicit `Positioned`).
- **Shell** (`app_shell.dart`): wide layout now uses the floating glass tab bar
  (Home / Search / Library / Settings); narrow layout keeps the `NavigationBar`.
- Tests: `test/tokens_test.dart` (7 invariants); suite total 18 passing.
- Limitations: Apple's refraction/lens edge effects stay platform-gated; the
  tint/vibrancy is approximated by the translucent surface on desktop.
- Verification: `flutter analyze` 0 errors; `flutter test` 18/18; `flutter build
  windows --debug` ? `echo.exe`; 15 s smoke run clean.

### Phase 3 — done (discovery & detail) — 380b84e

- New routes `/album`, `/artist`, `/playlist`:
  - `lib/screens/detail/album_page.dart` — header (art, title, artists,
    year/track count), Play + Add-to-library, songs section.
  - `lib/screens/detail/artist_page.dart` — header, Play, songs + albums
    sections via `SectionItem` (albums tap ? `/album`).
  - `lib/screens/detail/playlist_page.dart` — header, Play/Shuffle, song list.
  - `lib/utils/playable.dart` — adapter YTMusic items ? desktop `MediaPlayer`
    shape (`artists` as `{name}`, `album` map).
- `lib/core/widgets/section_item.dart` — `ItemList` taps on type `ALBUM`/`ARTIST`/
  `PLAYLIST` navigate to the new detail routes instead of generic `/browse`.
- Tests: `test/playable_test.dart` (5 cases). Suite total: 18 passing.
- Verified: `flutter analyze` 0 errors, `flutter test` 18/18,
  `flutter build windows --debug` ? `echo.exe`, 15 s smoke run clean.

**MusicFlowScreen (the 601-line Android screen) is still TODO** — Android's Resso-style vertical swipe
feed from `ui/screens/musicflow/*` (see plan notes above).

### Phase 4 — done (cookie login + account) — 8109e93

- Desktop Library exists (Favourites / Downloads / History / local playlists);
  Android parity: `LibrarySongsScreen` — Favourites (done), plus todo —
  Library albums/artists lists (`LibraryAlbumsScreen`, `LibraryArtistsScreen`),
  and the account layer: cookie login + account settings
  (`LoginScreen`, `AccountScreen`, `AccountViewModel`).
- Cookie login deferred: Android extracts browser cookies into YTMusic via
  `WebView`; the desktop has no CDP/browser-automation infra yet (Chrome is
  installed and could be used, but it needs a new service + UI). See plan
  "Deferred" section.
- Playback resume on launch done (see Phase 1 remainder).

Next: decide whether to pursue Phase 4 remainder (library albums/artists,
cookie login) or move to Phase 5 (lyrics providers).

