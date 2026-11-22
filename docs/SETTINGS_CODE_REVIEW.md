# Code review — impostazioni (2026-11-22)

Scope: `lib/screens/settings/**`, `lib/services/settings_manager.dart` e i consumatori in `media_player.dart`, `player_page.dart`, `lyrics_box.dart`, bootstrap `main.dart`. Metodo: code review strutturato (Critical / Warning / Info) con verifica del percorso UI → stato → Hive → effetto osservabile.

## Correzioni applicate

| Severity | Problema | Fix |
|---|---|---|
| Critical | Equalizzatore bloccato su spinner infinito: `GetIt.I<AndroidEqualizer>()` non esiste su Windows e `FutureBuilder` non gestiva `hasError` | `equalizer_page.dart`: fallback desktop a 10 bande reali (`eqFrequencies` + gain persistiti), stato errore, cubit creato una sola volta |
| Critical | Drag di una banda EQ: `RangeError` su profilo vuoto | `settings_manager.dart`: `setEqualizerBandsGain` allunga la lista con zeri prima della scrittura |
| Critical | Equalizer AXION/AutoEq spariva a ogni riavvio | `eq_settings.dart` come single source of truth; `main.dart`, `player_settings_cubit.dart`, `axion_eq_page.dart` applicano sempre gain + `enabled` insieme |
| Warning | Skip-silence azzerava l'EQ | `setSkipSilence` usa `EqSettings.apply` |
| Warning | Slider loudness con due range diversi (-1..1 vs -10..10) | unificato a -10..10 con clamp |
| Warning | Dispositivo di output non ripristinato | `main.dart` chiama `AudioDeviceService.selectDevice(id)` all'avvio |
| Warning | Sottotitolo Account rimaneva vecchio dopo logout | `ValueListenableBuilder(accountEpoch)` in `settings_page.dart` |
| Warning | `persistentQueue` non veniva rispettato | restore e `saveState()` gated sul setting |
| Warning | "Traduci testi" salvato ma mai letto | il pulsante nel player è gated su `SettingsManager.translateLyrics` |
| Warning | `/export_queue` crashava (ProviderNotFound) | `ExportTaskQueue` aggiunto al `MultiProvider` in `main.dart` |
| Warning | Valori di backup malformati potevano bloccare `SettingsManager` | clamp indici e `orElse` per lingua/paese |
| Info | Ricerca impostazioni ignorava gli switch | `_filter` include `SettingSwitchTile` |
| Info | Player apribile senza brano → deref null | schermata "Nessun brano in riproduzione" |
| Info | Pagine con larghezze/indentazione diverse | `SettingsList` condivisa (maxWidth 1000) per 7 pagine |

## Opzioni ancora placeholder (dichiarate esplicitamente)

Le seguenti opzioni sono state portate dall'Android per parità ma **non hanno ancora un consumer desktop**. Non devono essere considerate funzionanti:

- Aspetto: Theme variant, AccentColor, AMOLED, Dynamic Colors, stili mini-player/player, nascondi thumbnail, posizione testi lyrics, auto-scroll lyrics, tab predefinita, toggle "Show * playlist".
- Contenuti: filtri explicit/video/shorts, romanizzazione testi, lingua/paese contenuti.
- Player: auto load more, contenuti simili, remember shuffle/repeat, prevenzione duplicati, auto-download on like, durata storico, preload next/limit, gapless crossfade.
- Music Flow: tutti e sette i toggle.
- Integrazioni: sync library all'avvio, prefer extension audio, Song DNA, LT auto-approve/server.
- AI Hub: provider/mode non compatibili con la dialog di traduzione (OpenAI, Perplexity, Claude, Gemini, XAi, Transcribe).

Un banner `SettingNoticeTile` è visibile nelle pagine principali interessate. Le opzioni con effetto reale sono: tema, lingua/paese YT Music, qualità streaming/download, Data Saver (solo bitrate), high quality, crossfade, loudness, skip silence, sponsorblock, autofetch, personalised content, history/privacy, seek buttons, cast/remote, lyrics size/spacing, show codec, API keys AI, Discord/Last.fm/ListenBrainz, storage/backup/update/export.

## Test

`test/settings_fixes_test.dart` (6 test), `test/crossfade_engine_test.dart`, `test/mp3_export_test.dart`, `test/audio_source_info_test.dart`. `flutter analyze`: 0 errori. `flutter test`: 298 passati, 6 skip.
