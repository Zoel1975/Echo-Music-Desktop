# Getting started

Install the app, sign in, and start listening.

## Install

From the [Releases page](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest):

1. Download `EchoMusicSetup.exe`.
2. Run it. The wizard is in English and Italian.
3. Choose the Desktop and Start Menu shortcuts, then finish.
4. Start Echo Music from the Start Menu or the desktop shortcut.

The uninstaller is under **Apps & features**.

For the portable build, download `EchoMusicPortable.zip`, extract it (for example to `C:\EchoMusic`) and run `echo.exe`. It does not touch the registry.

## Sign in

On first launch click **Sign in**. A Chrome window opens with a dedicated profile. Sign in with the Google account tied to your YouTube Music library and confirm the permissions. The app detects the session after a few seconds and loads the library, history and playlists.

Cookies are stored locally, so later launches need no sign-in. Two-factor authentication is completed in the Chrome window.

## Listen

- Click a song in Home or Library to play it.
- In a playlist, clicking a song sets the whole playlist as the queue, starting at that song.
- The mini-player at the bottom has play/pause and quick controls. Click the cover art to open the full player.
- The player has lyrics, comments, queue, favourites and options.

## Age-restricted tracks

The app plays them in-app without opening a browser. It reads the real `signatureTimestamp`, sends the `/player` request with the authenticated YouTube Music context, deciphers `signatureCipher` formats with the player JS, and adds `pot=` and `cpn=` to the media URL.

If the Google account is not verified as an adult, YouTube may still refuse playback. Age verification must be done on the Google account. See [`AGE_GATE.md`](AGE_GATE.md).

## Automix and crossfade

In **Settings → Player**:

1. enable Crossfade and set the duration, or let Automix use a 16-beat DJ blend;
2. enable Beat align and Harmonic mixing;
3. play a playlist.

Open **Automix diagnostics** to see state, lead, trigger, BPM, key and the event log.

## Lyrics, EQ, downloads

- Lyrics: click the lyrics icon in the player. The provider and translation are configurable.
- EQ: **Settings → Player → Equalizer**. Adjust ten bands or load an AutoEq preset.
- Downloads: choose **Download** from a song or playlist menu. Files stay available offline.
- MP3 export: **Settings → Tools → Export MP3**. Select local or downloaded files; cover art is included.

## Wrapped

Open Wrapped from Home or the menu. Nine slides use your YouTube Music history. They advance every 8.5 s, or you can move between them with the buttons.

## Comments and recognition

Comments open from the player. Enable **Show comment button** in Settings → Appearance first.

For song recognition, open **Settings → Song recognition**, click **Index library**, and wait for it to finish. The microphone button then records 8 s, builds a fingerprint, and looks for a match among the indexed songs. It cannot identify songs outside that local index.

## Cast

Click the Cast icon in the player. The app searches over mDNS and DIAL. Select a TV or Chromecast to play the audio on that device.

## Troubleshooting

| Symptom | Check |
|---|---|
| A song does not start | Connection and account validity. Log: `%LOCALAPPDATA%\com.echo\Echo Music\error.log` |
| Age-gated song does not play | Google account age verification |
| Automix does not start | Automix diagnostics; crossfade and automix enabled |
| Lyrics do not load | Another provider in the lyrics settings |
| App does not open | Reinstall with the latest installer; local data is kept |

Report bugs on [GitHub](https://github.com/ItsZale0/Echo-Music-Desktop/issues).
