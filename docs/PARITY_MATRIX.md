# Android → Desktop parity matrix (2026-11-23)

Sono esclusi dal denominatore gli elementi non portabili su Windows:
widget Android, notifica Media3/QS tile, haptics, ringtones, USB bit-perfect,
Material You dal wallpaper, RenderEffect con rifrazione reale.

| # | Elemento | Stato | Evidenza |
|---|---|---|---|
| 1 | Home + sezioni personalizzabili | DONE | `screens/home/home_page.dart`, `services/home_sections.dart` |
| 2 | Player 3 layout + controlli | DONE | `player_page.dart`, `player_layout.dart` |
| 3 | Libreria 6 filtri | DONE | `ytm_library_page.dart` |
| 4 | Playlist + coda = playlist | DONE | `playlist_page.dart`, `media_player.dart` |
| 5 | Ricerca online + locale | DONE | `search_page.dart`, `ytmusic/mixins/search.dart` |
| 6 | Cast picker + sessione | DONE | `services/cast/`, `cast_page.dart`, `cast_session_page.dart` |
| 7 | Explore | DONE | `explore_page.dart` |
| 8 | Podcast | DONE | `/podcasts` via `FEmusic_podcasts` |
| 9 | 15 voci impostazioni | DONE | `router.dart`, `SETTINGS_PARITY_AUDIT.md` |
| 10 | Ricerca globale impostazioni | DONE | `settings_page.dart` |
| 11 | Login CDP + cookie | DONE | `google_login_service.dart` |
| 12 | Account/sign-out | DONE | `account_page.dart`, `session_service.dart` |
| 13 | Brani age-gated | DONE | `po_token_minter.dart`, `AGE_GATE.md` (limite account documentato) |
| 14 | Coda persistente | DONE | `queue_snapshot.dart`, `media_player.dart` |
| 15 | Sleep timer | DONE | `sleep_timer.dart` |
| 16 | SponsorBlock | DONE | `sponsor_block_service.dart` |
| 17 | Crossfade + pre-arm adattivo | DONE | `crossfade_engine.dart`, `crossfade_prearm.dart` |
| 18 | Automix analisi beat | DONE | `beat_analysis.dart`, `beat_analyzer_service.dart` |
| 19 | Automix mix-in/out dinamici | DONE | `energyMixIn`, `energyMixOut` |
| 20 | Automix beat-matching | DONE | `beatAlignedStartMs` |
| 21 | Automix DJ blend 16 beat | DONE | `djBlendDurationMs` |
| 22 | Automix ducking | DONE | `silence_filter.dart` (`bass=f=150:g=-8`) |
| 23 | Automix mixing armonico | DONE | `harmonic_mixing.dart` (Camelot) |
| 24 | Diagnostica Automix | DONE | `automix_debug.dart`, `automix_debug_page.dart` |
| 25 | 12 provider lyrics | DONE | `lyrics_registry.dart` |
| 26 | Lyrics word-sync | DONE | `lyrics_box.dart` |
| 27 | Traduzione lyrics | DONE | `lyrics_translation.dart` |
| 28 | Lyrics stabili | DONE | generation guard + geometria costante |
| 29 | Equalizzatore 10 bande | DONE | `equalizer_page.dart` |
| 30 | AutoEq search | DONE | `autoeq_service.dart`, `axion_eq_page.dart` |
| 31 | Export MP3 | DONE | `ffmpeg_audio_encoder.dart` |
| 32 | FLAC Monochrome | DONE | `monochrome_service.dart` |
| 33 | Etichetta sorgente audio | DONE | `audio_source_info.dart` |
| 34 | Mini-player glass + marquee | DONE | `bottom_player.dart`, `echo_surface.dart` |
| 35 | 7 background player | DONE | `player_background.dart` |
| 36 | Font Android | DONE | `assets/fonts/`, `app_fonts.dart` |
| 37 | EchoGlass | DONE | `echo_surface.dart` (blur/tint/rim/shadow/vibrancy) |
| 38 | Wavy/Squiggly slider | DONE | `motion_effects.dart` |
| 39 | HeartBurst | DONE | `motion_effects.dart`, `player_page.dart` |
| 40 | Marquee | DONE | `MarqueeText` in mini-player |
| 41 | Shimmer | DONE | `ShimmerBox` + skeleton home |
| 42 | 7 toggle Music Flow | DONE | `music_flow_feed_page.dart` |
| 43 | Ambient con palette | DONE | `AmbientBackground` |
| 44 | EQ circolare | DONE | `circular_eq_control.dart` |
| 45 | Copertina nei MP3 | DONE | `buildMp3Args(coverUrl:)` |
| 46 | Wrapped 9 slide animate | DONE | `wrapped_stories_page.dart` (9 slide, 8,5 s, temi, radar, EQ, poster) |
| 47 | Commenti YouTube | DONE | `comments_service.dart` (endpoint `next` WEB) + `comment_sheet.dart`, pulsante gated da `showComment` |
| 48 | Riconoscimento brani | DONE | `song_recognition_service.dart` (mic dshow + fingerprint + matching libreria) + `song_recognition_page.dart` |

DONE = 48 / 48 = **100%**. I 2 nuovi elementi sono funzionanti con i limiti dichiarati: i commenti non hanno scrittura (come Android) e il riconoscimento è offline sulla libreria indicizzata (nessuna API a pagamento/chiave).
