# Architettura tecnica

Panoramica dei componenti di Echo Music Desktop e del modo in cui si collegano. Per le funzioni dal punto di vista dell'utente vedi [`FEATURES.md`](FEATURES.md).

## Stack

- **Flutter** (Dart) con backend Windows x64;
- **media_kit / mpv** per la riproduzione audio e la catena DSP;
- **ffmpeg_kit_flutter_new_audio** per decodifica, analisi ed export MP3;
- **Hive** per preferenze, cache dei token, cronologia e indici;
- **http** + **cookie_store** per le richieste InnerTube;
- **Inno Setup** per l'installer Windows.

## Struttura delle cartelle

```
lib/
  main.dart                  avvio, DI, sessione, fallback UI
  core/                      tema, widget condivisi, animazioni
  screens/                   schermate (home, player, library, settings, ...)
  services/                  logica di business
    stream_resolver.dart     risoluzione URL audio via InnerTube
    po_token_minter.dart     mint locale del PoToken BotGuard
    media_player.dart        coda, crossfade, automix, DSP
    crossfade_engine.dart    rampa equal-power a due player
    crossfade_prearm.dart    AdaptivePreArmManager
    beat_analysis.dart       FFT, BPM, fase, chiave, mix-in/out
    beat_analyzer_service.dart  decoding FFmpeg + cache Hive
    comments_service.dart    endpoint `next` per i commenti
    song_recognition_service.dart  microfono + fingerprint + matching
    cast/                    CastV2, mDNS, DIAL
    ...
  ytmusic/                   client InnerTube e mixin (browse, search, library, ...)
  utils/                     router, bottom sheets, history, modali
assets/
  po/po_token.html           pagina BotGuard per il PoToken
  fonts/                     font Android
installer/EchoMusic.iss      sorgente Inno Setup
test/                        test unitari e di integrazione
```

## Flusso di riproduzione

1. **Selezione brano** — `MediaPlayer.playSong()` riceve una song (con `videoId`).
2. **Risoluzione streaming** — `StreamResolver.resolve(videoId)`:
   - ottiene `visitorData` e il vero `signatureTimestamp`;
   - prova i client InnerTube in ordine (VISIONOS, WEB_REMIX, WEB_CREATOR, ...);
   - se la risposta contiene solo `signatureCipher`, la decifra con il player JS tramite Node;
   - applica `pot=` e `cpn=` all'URL;
   - valida l'URL con una richiesta rangedGET prima di restituirlo.
3. **Sorgente audio** — `_getAudioSource()` crea uno `StreamAudioSource` con header e URL.
4. **Riproduzione** — il player principale riproduce; il DSP applica EQ e normalizzazione.

## Crossfade e Automix

- il position stream chiama `_maybePreArmQueueCrossfade()` a ogni tick;
- quando manca il lead adattativo, `_prepareStandby()` crea un secondo player con la traccia corrente e lo fa partire in silenzio;
- quando manca la durata del blend, `_triggerQueueCrossfade()`:
  1. esegue l'handoff a 220 ms tra player principale e standby;
  2. sposta il player principale sul brano successivo, all'offset calcolato da `beatAlignedStartMs()`;
  3. avvia il crossfade equal-power per la durata del blend;
- `_applyHarmonicMix()` riordina la coda secondo la ruota Camelot prima del trigger.

Dettagli in [`CROSSFADE.md`](CROSSFADE.md) e [`AUTOMIX.md`](AUTOMIX.md).

## BotGuard / PoToken

`PoTokenMinter` esegue il JavaScript Bundled (`assets/po/po_token.html`) in una pagina Chrome connessa via CDP al profilo di login. Il token viene salvato per sessione in Hive e riutilizzato finché non scade. Viene aggiunto come `serviceIntegrityDimensions.poToken` alla richiesta player e come `pot=` all'URL media. Vedi [`AGE_GATE.md`](AGE_GATE.md).

## Commenti

`CommentsService` usa l'endpoint `youtubei/v1/next` con client **WEB** (non WEB_REMIX), scopre il token di continuazione in `twoColumnWatchNextResults` o negli `engagementPanels`, e unisce i payload legacy e framework. `comment_sheet.dart` disegna il foglio modale.

## Riconoscimento brani

`SongRecognitionService` usa FFmpeg `dshow` per registrare il microfono a 16 kHz mono, estrae un set di landmark spettrali con la FFT già presente, costruisce un indice Hive dei brani locali decodificati e fa matching Jaccard. Nessun servizio esterno.

## Persistenza

| Box Hive | Contenuto |
|---|---|
| `SETTINGS` | preferenze, visitor id, account epoch |
| `POTOKENS` | token PoToken per videoId |
| `BEAT_ANALYSIS` | analisi beat in cache |
| `RECOGNITION_INDEX` | impronte dei brani locali |
| `RECOGNITION_HISTORY` | risultati del riconoscimento |
| `QUEUE_SNAPSHOT` | coda di riproduzione |

## Test e verifica

```bash
flutter analyze      # 0 errori
flutter test         # 352 test, 6 skip
tool/verify.ps1      # verifica completa
```

La matrice di parità è verificata da test che controllano l'esistenza delle schermate e dei servizi (`test/parity_90_test.dart`, `test/full_parity_evidence_test.dart`).
