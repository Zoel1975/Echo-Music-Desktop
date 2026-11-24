# Android → Desktop parity matrix (2026-11-24)

Items that cannot be ported to Windows are excluded from the denominator: Android widgets, the Media3 notification / Quick Settings tile, haptics, ringtones, bit-perfect USB output, Material You wallpaper colors, and real `RenderEffect` refraction.

| # | Feature | Status | Evidence |
|---|---|---|---|
| 1 | Home + customizable sections | DONE | `screens/home/home_page.dart`, `services/home_sections.dart` |
| 2 | Player 3 layouts + controls | DONE | `player_page.dart`, `player_layout.dart` |
| 3 | Library 6 filters | DONE | `ytm_library_page.dart` |
| 4 | Playlist + queue = playlist | DONE | `playlist_page.dart`, `media_player.dart` |
| 5 | Online + local search | DONE | `search_page.dart`, `ytmusic/mixins/search.dart` |
| 6 | Cast picker + session | DONE | `services/cast/`, `cast_page.dart`, `cast_session_page.dart` |
| 7 | Explore | DONE | `explore_page.dart` |
| 8 | Podcasts | DONE | `/podcasts` via `FEmusic_podcasts` |
| 9 | 15 settings entries | DONE | `router.dart`, `SETTINGS_PARITY_AUDIT.md` |
| 10 | Global settings search | DONE | `settings_page.dart` |
| 11 | CDP login + cookies | DONE | `google_login_service.dart` |
| 12 | Account / sign-out | DONE | `account_page.dart`, `session_service.dart` |
| 13 | Age-restricted tracks | DONE | `stream_resolver.dart` (real STS + `signatureCipher`) + `po_token_minter.dart`, `AGE_GATE.md` (no visible browser) |
| 14 | Persistent queue | DONE | `queue_snapshot.dart`, `media_player.dart` |
| 15 | Sleep timer | DONE | `sleep_timer.dart` |
| 16 | SponsorBlock | DONE | `sponsor_block_service.dart` |
| 17 | Crossfade + adaptive pre-arm | DONE | `crossfade_engine.dart`, `crossfade_prearm.dart` |
| 18 | Automix beat analysis | DONE | `beat_analysis.dart`, `beat_analyzer_service.dart` |
| 19 | Automix dynamic mix-in/out | DONE | `energyMixIn`, `energyMixOut` |
| 20 | Automix beat matching | DONE | `beatAlignedStartMs` |
| 21 | Automix 16-beat DJ blend | DONE | `djBlendDurationMs` |
| 22 | Automix ducking | DONE | `silence_filter.dart` (`bass=f=150:g=-8`) |
| 23 | Automix harmonic mixing | DONE | `harmonic_mixing.dart` (Camelot) |
| 24 | Automix diagnostics | DONE | `automix_debug.dart`, `automix_debug_page.dart` |
| 25 | 12 lyrics providers | DONE | `lyrics_registry.dart` |
| 26 | Lyrics word sync | DONE | `lyrics_box.dart` |
| 27 | Lyrics translation | DONE | `lyrics_translation.dart` |
| 28 | Stable lyrics | DONE | generation guard + constant geometry |
| 29 | 10-band equalizer | DONE | `equalizer_page.dart` |
| 30 | AutoEq search | DONE | `autoeq_service.dart`, `axion_eq_page.dart` |
| 31 | MP3 export | DONE | `ffmpeg_audio_encoder.dart` |
| 32 | Monochrome FLAC | DONE | `monochrome_service.dart` |
| 33 | Audio source label | DONE | `audio_source_info.dart` |
| 34 | Glass mini-player + marquee | DONE | `bottom_player.dart`, `echo_surface.dart` |
| 35 | 7 player backgrounds | DONE | `player_background.dart` |
| 36 | Android fonts | DONE | `assets/fonts/`, `app_fonts.dart` |
| 37 | EchoGlass | DONE | `echo_surface.dart` (blur/tint/rim/shadow/vibrancy) |
| 38 | Wavy / squiggly slider | DONE | `motion_effects.dart` |
| 39 | HeartBurst | DONE | `motion_effects.dart`, `player_page.dart` |
| 40 | Marquee | DONE | `MarqueeText` in the mini-player |
| 41 | Shimmer | DONE | `ShimmerBox` + home skeleton |
| 42 | 7 Music Flow toggles | DONE | `music_flow_feed_page.dart` |
| 43 | Ambient with palette | DONE | `AmbientBackground` |
| 44 | Circular EQ | DONE | `circular_eq_control.dart` |
| 45 | Cover art in MP3 | DONE | `buildMp3Args(coverUrl:)` |
| 46 | Animated 9-slide Wrapped | DONE | `wrapped_stories_page.dart` (9 slides, 8.5 s, themes, radar, EQ, poster) |
| 47 | YouTube comments | DONE | `comments_service.dart` (WEB `next` endpoint) + `comment_sheet.dart`, button gated by `showComment` |
| 48 | Song recognition | DONE | `song_recognition_service.dart` (dshow microphone + fingerprint + library matching) + `song_recognition_page.dart` |

DONE = 48 / 48 = **100%**. The two most recent items are functional with their declared limits: comments have no write support (as in Android), and recognition is offline against the indexed local library (no paid API or key).

## Settings coverage

The settings audit found 57 persisted options with no consumer. All feasible ones are now wired to real Flutter widgets or services; `test/settings_wiring_test.dart` verifies this. Eight options remain explicitly disabled with a Windows-specific reason in `settings_capabilities.dart`: wallpaper-based Dynamic Colors, haptics, three `RenderEffect` effects, and three automatic playlists with no desktop equivalent.
