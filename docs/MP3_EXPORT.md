# MP3 export

## Backend

Export uses `ffmpeg_kit_flutter_new_audio` 3.0.0, an audio-only LGPL-3.0 FFmpeg build with LAME/MP3 and no GPL codecs. On Windows the DLLs are downloaded at build time and the plugin installs license notices in `licenses/ffmpeg_kit_flutter_new_audio/` next to `echo.exe`. The installer copies that directory from `build/windows/x64/runner/Release`.

Flacora is not used. It is a Rust GUI orchestrator with no CLI or library, and it only outputs FLAC.

## Sources

- Local files picked in **Settings → Export MP3**.
- Downloaded songs, via **Add downloaded songs** in the same screen or **Export as MP3** in a song menu.

Live streams are not exported. The audio must already be on disk.

## Feedback

The export screen lists each task with its stage, bitrate, percentage, and a cancel or retry button. It shows the destination folder above the list. Clicking a finished row opens the file in Explorer.

The song-menu action shows a progress bar with **Cancel**, followed by the saved file name and **Open folder**. Failures show the error text. Earlier versions flashed one toast after the conversion finished, and on Windows that toast had transparent text because it reused `scaffoldBackgroundColor`.

## Pipeline

1. `ExportTaskQueue.enqueue()` (or `enqueueSong()`) creates a task named `Artist - Title.mp3`, removes invalid Windows characters and adds `(1)` on collision. `onTask` fires as soon as the task exists, before transcoding, so the UI can attach progress.
2. Bitrate comes from `SettingsManager.exportBitrateKbps` (192 by default; 128/192/256/320 in the screen).
3. `FfmpegAudioEncoder` runs `-stats_period 0.2 -nostdin -y -i <input> -vn -map 0:a:0 -c:a libmp3lame -b:a <n>k -map_metadata 0 -id3v2_version 3 [-metadata ...] -f mp3 <target>.part`.
4. Output goes to `.part` and is renamed only on success. `-f mp3` is required: FFmpeg cannot infer the container from the `.part` extension and fails with `Unable to choose an output format` without it.
5. Progress comes from FFmpeg statistics every 0.2 s. For files of unknown duration, `FFprobeKit.getMediaInformation()` supplies it.
6. `FFmpegKit.cancel(sessionId)` stops a task; **Retry** requeues it.

Files are saved in `Downloads/Echo/Music`, the same folder as downloaded songs.

## Tests

`test/mp3_export_test.dart` checks FFmpeg arguments, wiring, docs, the `-f mp3` regression, readable toasts and English strings. `test/feasible_ports_test.dart` checks the queue with a fake encoder: transcode, naming, failure, cancel/retry and `.part` atomicity.

Gates: `flutter analyze`, `flutter test`, `flutter build windows --release`.
