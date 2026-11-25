# Stems

Stems let you mute or solo parts of a track while it plays. Open the song menu and choose **Stems**.

## Instant vocal mute

**Mute vocals (instant)** applies a center-channel cancellation filter to the live stream. It needs no model and starts immediately. It works best on recordings with the lead vocal panned to the center; bass and other centered instruments are reduced too. This is a quick karaoke control, not a separated stem.

## Four real stems

The offline separator writes a four-channel file with drums, bass, other and vocals. When a file exists for the current track, **Use separated stems** switches playback to it at the same position. The four switches then mute individual stems, and **Solo** keeps one stem audible. mpv mixes the channels with a `pan` filter inside the same player, so the stems stay sample-synchronized and no extra mpv instance is needed.

Select **Separate this track** to queue the current song. A 3-minute track takes roughly 20–90 s on a CPU, depending on the machine; the first run also downloads a 166 MB model. The model and the stem files are cached in `Downloads/Echo/Music/Stems` and reused until the source file changes.

Separation runs in the background with the same queue pattern as MP3 export. Download or import a song first: live streams are not separated directly.

## Requirements

The separator is a Python helper (`tools/stems/separate.py`). It needs Python 3 with `numpy`, `onnxruntime` and `soundfile`. Set the executable in **Settings → Player → Stem separation Python** if `python` is not on your PATH. If the helper or model cannot be loaded, the task shows the exact error in the Stems sheet; playback of the original track is unaffected.

The model is HT-Demucs (MIT), exported to ONNX by StemSplitio. No audio is uploaded: decoding happens locally with the bundled FFmpeg and inference runs on the CPU.

## Limits

- Stems are produced from local or downloaded files only.
- The four channels are mono downmixes of each stereo stem; the `pan` filter duplicates them to stereo.
- Muting all four stems is silent by design; use **Restore full mix** to reset.
