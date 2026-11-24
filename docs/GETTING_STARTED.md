# Getting started

A practical guide to installing, configuring, and using Echo Music Desktop.

## 1. Installation

### Installer (recommended)

1. Go to the [Releases page](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest).
2. Download **`EchoMusicSetup.exe`**.
3. Run it. The wizard is available in English and Italian.
4. Choose whether to install the Desktop and Start Menu shortcuts, then complete the setup.
5. Launch **Echo Music** from the Start Menu or the desktop shortcut.

The installer also creates an uninstaller, available in **Apps & features**.

### Portable build

1. Download **`EchoMusicPortable.zip`**.
2. Extract everything into a folder, for example `C:\EchoMusic`.
3. Run `echo.exe` from that folder.

The portable build does not modify the registry and can be copied to another machine.

## 2. Signing in to your account

1. On first launch click **Sign in**.
2. A Chrome window opens with a dedicated profile. Sign in with your Google account associated with YouTube Music.
3. If requested, confirm the permissions. After a few seconds the app detects the session and loads your library, history, and playlists.

Cookies are stored locally: later launches do not require signing in again.

> **Note:** if you use two-factor authentication, complete it normally in the Chrome window. The app does not request it directly.

## 3. Listening to your music

- Click a song in **Home** or **Library** to start playback.
- If you open a **playlist** and tap a song, the whole playlist becomes the queue, starting at that song.
- Use the **mini-player** at the bottom for play/pause and quick controls; click the cover art to open the full player.
- The player provides lyrics, comments, queue, favorites, and advanced options.

## 4. Age-restricted tracks

If a track is age-restricted, the app plays it directly in-app without opening a browser. It could ask for additional auth, do that and it should work inside the app. It:

- reads the real `signatureTimestamp` from YouTube;
- sends a `/player` request with the authenticated YouTube Music context;
- deciphers the `signatureCipher` formats with the player JS;
- applies the `pot=` and `cpn=` tokens to the audio URL.

If your account is not verified as an adult, YouTube may still refuse playback: age verification must be completed on the Google account and cannot be bypassed by the client. See [`AGE_GATE.md`](AGE_GATE.md).

## 5. Automix and crossfade

1. Go to **Settings → Player**.
2. Enable **Crossfade** and choose the duration, or let Automix use a 16-beat DJ blend.
3. Enable **Beat align** and **Harmonic mixing** for musically coherent transitions.
4. Play a playlist and listen: transitions happen without interruption.

To see what is happening, open **Automix diagnostics**: state, lead, trigger, BPM, key, and event log.

## 6. Lyrics, EQ, and downloads

- **Lyrics**: click the lyrics icon in the player. You can choose the provider and the translation.
- **EQ**: **Settings → Player → Equalizer**. Adjust the 10 bands or load an AutoEq preset.
- **Downloads**: choose **Download** from a song or playlist menu. Files remain available offline.
- **MP3 export**: **Settings → Tools → Export MP3**. Select local or downloaded files; cover art is included.

## 7. Wrapped

Open **Wrapped** from Home or the menu. Nine slides show your real YouTube Music data. Use the buttons to navigate or let them advance automatically every 8.5 seconds.

## 8. Comments and song recognition

- **Comments**: click the comment icon in the player (the "Show comment button" option must be enabled in Settings → Appearance).
- **Song recognition**: open **Settings → Song recognition**, click **Index library**, and wait for it to finish. Then click the microphone: the app records 8 seconds, computes the fingerprint, and looks for a match among the indexed songs.

Recognition works **offline on your library only**: it cannot identify arbitrary songs, only those you indexed.

## 9. Cast

Click the Cast icon in the player. The app searches the network (mDNS + DIAL). Select your TV or Chromecast: audio plays directly on the device.

## 10. Troubleshooting

| Symptom | What to do |
|---|---|
| A song does not start | Check your connection and that the account is still valid. See the log at `%LOCALAPPDATA%\com.echo\Echo Music\error.log`. |
| An age-gated song does not play | Verify that your Google account is age-verified. |
| Automix does not start | Open Automix diagnostics and check that crossfade and automix are enabled. |
| Lyrics do not load | Try another provider in the lyrics settings. |
| The app does not open | Reinstall using the latest installer; local data is preserved. |

For bug reports, open an issue on [GitHub](https://github.com/ItsZale0/Echo-Music-Desktop/issues).
