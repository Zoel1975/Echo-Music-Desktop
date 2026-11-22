# Export MP3

## Backend

L'export audio usa `ffmpeg_kit_flutter_new_audio` 3.0.0: build **audio-only LGPL-3.0** di FFmpeg 8.1.3 (include LAME/MP3, nessun codec GPL). Su Windows le DLL vengono scaricate in fase di build e il plugin installa le notifiche di licenza in `licenses/ffmpeg_kit_flutter_new_audio/` accanto a `echo.exe`: la directory viene inclusa nell'installer Inno Setup grazie alla copia ricorsiva di `build/windows/x64/runner/Release`.

**Flacora non è stato usato**: è un orchestratore GUI Rust che scarica FLAC da Tidal/Qobuz/Amazon/Deezer tramite estensioni esterne, non ha CLI/API/libreria e il suo output accetta solo file `.flac`. Non può codificare MP3.

## Cosa può essere esportato

- File audio locali selezionati con il file picker nella schermata **Impostazioni → Esporta MP3**.
- Brani già scaricati: pulsante "Aggiungi brani scaricati" nella stessa schermata oppure **Esporta in MP3** nel menu del brano scaricato (long-press/click destro).

Non vengono esportati brani in streaming: l'export funziona offline sui file già presenti su disco.

## Pipeline

1. `ExportTaskQueue.enqueue()` (o `enqueueSong()`) crea un task con nome `Artista - Titolo.mp3`, caratteri Windows non validi rimossi e suffisso `(1)` in caso di collisione.
2. Il bitrate viene letto da `SettingsManager.exportBitrateKbps` (default 192 kbps, modificabile 128/192/256/320 nella schermata Export).
3. `FfmpegAudioEncoder` esegue:
   `-nostdin -y -i <input> -vn -map 0:a:0 -c:a libmp3lame -b:a <n>k -map_metadata 0 -id3v2_version 3 [-metadata ...] <target>.part`
4. L'output viene scritto in un file temporaneo `.part` e solo al successo rinominato nel `.mp3` finale: un errore o un annullamento non lascia file MP3 fasulli.
5. Progresso: statistiche FFmpeg (`statistics.getTime() / duration`) quando la durata è nota; altrimenti progresso indeterminato.
6. Annullamento: `FFmpegKit.cancel(sessionId)`; il task passa allo stato "Annullata". "Riprova" rimette il task in coda.

I file sono salvati in `Downloads/Echo/Music` (stessa cartella dei brani scaricati). Il pulsante cartella apre la destinazione.

## Test

- `test/mp3_export_test.dart`: argomenti FFmpeg, named wiring, presenza docs/licenza.
- `test/feasible_ports_test.dart`: coda con encoder fake (transcode, naming, failure, cancel/retry, atomicità `.part`).
- Gate: `flutter analyze` 0 errori, `flutter test` tutti verdi, `flutter build windows --release`.
