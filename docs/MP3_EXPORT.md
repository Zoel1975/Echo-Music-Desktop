# MP3 export

## Backend

Audio export uses `ffmpeg_kit_flutter_new_audio` 3.0.0: an **audio-only LGPL-3.0** FFmpeg build (includes LAME/MP3, no GPL codecs). On Windows the DLLs are downloaded at build time and the plugin installs license notices in `licenses/ffmpeg_kit_flutter_new_audio/` next to `echo.exe`: the directory is included in the Inno Setup installer through the recursive copy of `build/windows/x64/runner/Release`.

**Flacora was not used**: it is a Rust GUI orchestrator that downloads FLAC from Tidal/Qobuz/Amazon/Deezer through external extensions, has no CLI/API/library, and only accepts `.flac` as output. It cannot encode MP3.

## What can be exported

- Local audio files selected with the file picker in **Settings → Export MP3**.
- Already-downloaded songs: the "Add downloaded songs" button in the same screen, or **Export as MP3** in the song menu (right-click / long press).

Streaming songs are not exported: export works offline on files already on disk.

## Pipeline

1. `ExportTaskQueue.enqueue()` (or `enqueueSong()`) creates a task named `Artist - Title.mp3`, with invalid Windows characters removed and a `(1)` suffix on collision.
2. The bitrate comes from `SettingsManager.exportBitrateKbps` (192 kbps by default, selectable 128/192/256/320 in the Export screen).
3. `FfmpegAudioEncoder` runs:
   `-stats_period 0.2 -nostdin -y -i <input> -vn -map 0:a:0 -c:a libmp3lame -b:a <n>k -map_metadata 0 -id3v2_version 3 [-metadata ...] -f mp3 <target>.part`
4. Output is written to a temporary `.part` file and only renamed to the final `.mp3` on success: an error or cancellation never leaves a fake MP3. **`-f mp3` is mandatory**: FFmpeg cannot infer the container from the `.part` extension, and without this flag export always failed with exit 1 (`Unable to choose an output format`).
5. Progress comes from FFmpeg statistics (`statistics.getTime() / duration`) with updates every 0.2 s. When the duration is unknown (files added with the file picker), it is read with `FFprobeKit.getMediaInformation()`: the bar therefore shows a real percentage instead of an indeterminate animation. The screen also shows `stage · bitrate · percentage`.
6. Cancellation: `FFmpegKit.cancel(sessionId)`; the task moves to the "Cancelled" state. **Retry** puts the task back in the queue.

Files are saved in `Downloads/Echo/Music` (the same folder as downloaded songs). The folder button opens the destination.

## Tests

- `test/mp3_export_test.dart`: FFmpeg arguments, named wiring, docs/license presence, and the explicit `-f mp3` regression check.
- `test/feasible_ports_test.dart`: queue with a fake encoder (transcode, naming, failure, cancel/retry, `.part` atomicity).
- Gates: `flutter analyze` 0 errors, `flutter test` all green, `flutter build windows --release`.
