# Stems

Stems let you mute or solo parts of a track while it plays. Open the player, tap **...** and choose **Stems**, or use the stem chips docked on the rotating cover.

## Four stems

The offline separator writes a four-channel file with drums, bass, other and vocals. When a file exists for the current track, **Use separated stems** switches playback to four synchronized players — one per stem. The four on/off chips only change a player's volume, so toggling is instant with no render, no source reload and no gap. **Solo** keeps one stem audible and **Enable all** restores the full mix.

**Download all & separate** runs the whole pipeline: it downloads the song when needed, sets up Python, downloads the model once and separates. Two progress bars show the overall job and the model download; while inference runs the sheet shows the current chunk and elapsed time.

## Speed and hardware

- **Separation speed**: Fast uses a 10% chunk overlap; Quality uses 25%. Fast processes fewer chunks, with a small quality trade-off.
- **GPU acceleration**: Auto prefers DirectML/CUDA when ONNX Runtime finds them, otherwise CPU. CPU, DirectML and CUDA can also be forced. The sheet reports the provider actually used.

A CPU-only machine needs roughly 0.5–0.7x the track duration; GPU providers are much faster. The first run also downloads a 166 MB model. Model and stems are cached in `Downloads/Echo/Music/Stems` and reused until the source file changes.

## Requirements and limits

The separator is `tools/stems/separate.py`. It needs Python 3 with `numpy`, `onnxruntime` and `soundfile`; the app finds Python automatically and can install a portable copy when none is present. Playlist pages have a **Separate all tracks** button: missing songs are downloaded, then every track is separated in the background with overall progress. A failed track does not stop the rest.

Downloads, backups and stems all live under the folder chosen in **Settings → Storage → App folder**. Changing it creates the `Music` and `Back Up` subfolders there; stem caches are rebuilt in the new location. Existing files are not moved automatically — copy them if you change the folder after downloading songs.

The model is HT-Demucs (MIT), exported to ONNX by StemSplitio. No audio is uploaded: decoding happens locally with the bundled FFmpeg and inference runs on this machine.

- Stems are produced from local or downloaded files only.
- The separator writes four mono stem WAVs alongside the four-channel cache file.
- Toggling stems only changes volume: no FFmpeg render and no audio-source reload. The four players are re-synced every 15 seconds if they drift.
- The progress bar, seek bar and ±10 s buttons follow the stem players while stem mode is active; the paused original track stays at the same position for a seamless exit.
- Muting all four stems is silent by design; use **Enable all** to reset.
- Stem mode is global: once enabled it follows every separated track automatically. Each player transition is serialized so rapid skips or batch completions cannot leave stale decoders running.
- A track counts as ready only when the four-channel cache **and** all four mono stems exist. Incomplete files are ignored and can be regenerated.

## Keyboard shortcuts

| Key | Action |
|---|---|
| Space | Play / pause |
| ← / → | Previous / next track |
| S | Enable or disable stems |
| 1 / 2 / 3 / 4 | Toggle Drums / Bass / Other / Vocals |
| D / B / I / V (tap) | Toggle Drums / Bass / Other / Vocals |
| D / B / I / V (hold) | Mute that stem while held, then restore it |

Shortcuts are ignored while typing in a text field. Each stem has its own
colour and short label (DRM / BAS / OTH / VOC) on the cover and in the Stems
sheet, so the four channels are easy to tell apart.

## Cleanup

Interrupted separations leave temporary `.part` and `.decode.wav` files. The app removes such files older than 12 hours at startup, and deletes the current run's temporaries immediately after a failure. Files still being written are never touched.
