# Code review — settings (2026-11-24)

Scope: `lib/screens/settings/**`, `lib/services/settings_manager.dart`, and the consumers in `media_player.dart`, `player_page.dart`, `lyrics_box.dart`, and the `main.dart` bootstrap. Method: structured code review (Critical / Warning / Info) verifying the UI → state → Hive → observable effect path.

## Fixes applied

| Severity | Problem | Fix |
|---|---|---|
| Critical | Equalizer stuck on an infinite spinner: `GetIt.I<AndroidEqualizer>()` does not exist on Windows and `FutureBuilder` did not handle `hasError` | `equalizer_page.dart`: desktop fallback to 10 real bands (`eqFrequencies` + persisted gains), error state, cubit created once |
| Critical | Dragging an EQ band: `RangeError` on an empty profile | `settings_manager.dart`: `setEqualizerBandsGain` pads the list with zeros before writing |
| Critical | AXION / AutoEq equalizer disappeared on every restart | `eq_settings.dart` as the single source of truth; `main.dart`, `player_settings_cubit.dart`, `axion_eq_page.dart` always apply gain + `enabled` together |
| Warning | Skip-silence reset the EQ | `setSkipSilence` uses `EqSettings.apply` |
| Warning | Loudness slider had two ranges (-1..1 vs -10..10) | unified to -10..10 with clamping |
| Warning | Output device was not restored | `main.dart` calls `AudioDeviceService.selectDevice(id)` at startup |
| Warning | Account subtitle stayed stale after sign-out | `ValueListenableBuilder(accountEpoch)` in `settings_page.dart` |
| Warning | `persistentQueue` was not respected | restore and `saveState()` gated on the setting |
| Warning | "Translate lyrics" was saved but never read | the player button is gated on `SettingsManager.translateLyrics` |
| Warning | `/export_queue` crashed (ProviderNotFound) | `ExportTaskQueue` added to `MultiProvider` in `main.dart` |
| Warning | Malformed backup values could break `SettingsManager` | clamped indexes and `orElse` for language/country |
| Info | Settings search ignored switches | `_filter` includes `SettingSwitchTile` |
| Info | Player could open with no song → null dereference | "Nothing playing" screen |
| Info | Pages had different widths/indentation | shared `SettingsList` (maxWidth 1000) across 7 pages |

## Settings wiring audit

A later audit found 57 persisted options with no consumer. All feasible ones are now wired with real Flutter hooks — theme accent/AMOLED, queue deduplication, shuffle/repeat persistence, history trimming, crossfade gapless, preload, auto-download on like, content filters, lyrics options, default tab, mini-player style, appearance gestures, Last.fm likes, Song DNA, cloud sync, Listen Together, extension settings, and more. See `test/settings_wiring_test.dart`.

Eight options remain explicitly disabled with a Windows-specific reason in `settings_capabilities.dart`: wallpaper-based Dynamic Colors, haptics, three `RenderEffect` effects, and three automatic playlists with no desktop equivalent. They are rendered as informational tiles, not silent toggles.

Options with real effects include: theme, YT Music language/country, streaming/download quality, Data Saver, high quality, crossfade, loudness, skip silence, SponsorBlock, autofetch, personalized content, history/privacy, seek buttons, Cast/remote, lyrics size/spacing, codec label, AI API keys, Discord/Last.fm/ListenBrainz, storage/backup/update/export.

## Tests

`test/settings_fixes_test.dart`, `test/settings_wiring_test.dart`, `test/crossfade_engine_test.dart`, `test/mp3_export_test.dart`, `test/audio_source_info_test.dart`. `flutter analyze`: 0 errors. `flutter test`: 363 passing, 6 skipped.
