# Features

What the app does and where to find each control. Implementation notes are in [`ARCHITECTURE.md`](ARCHITECTURE.md).

Contents:

1. [Account and session](#1-account-and-session)
2. [Library, playlists, search](#2-library-playlists-search)
3. [Player](#3-player)
4. [Automix and crossfade](#4-automix-and-crossfade)
5. [Lyrics, EQ, DSP](#5-lyrics-eq-dsp)
6. [Downloads and export](#6-downloads-and-export)
7. [Discovery and social](#7-discovery-and-social)
8. [Wrapped](#8-wrapped)
9. [Cast, remote, devices](#9-cast-remote-devices)
10. [Settings and diagnostics](#10-settings-and-diagnostics)
11. [Not portable](#11-not-portable)

---

## 1. Account and session

Sign in on first launch. The app opens a dedicated Chrome profile, completes the login, and keeps the cookies in a local jar. Later launches need no sign-in.

Stored locally: authentication cookies, visitor id, preferences, listening history, playlists you create, and PoTokens (12 hours).

Sign out in **Settings → Account**. Downloads and preferences stay; the online library needs a new sign-in.

Age-restricted tracks play in the app:

1. the real `signatureTimestamp` is read from YouTube;
2. the `/player` request uses the authenticated YouTube Music context and the mobile flags `videoCheckOk` and `html5Preference`;
3. `signatureCipher` formats are deciphered with the player JS through Node;
4. `pot=` and `cpn=` are added to the media URL before playback.

No browser window opens. See [`AGE_GATE.md`](AGE_GATE.md).

---

## 2. Library, playlists, search

The library has six filters: songs, albums, artists, playlists, podcasts, downloads. It supports cover art, sorting and in-view search.

Open a playlist and tap a song. The whole playlist becomes the queue, starting at that song. You can reorder, remove and save changes.

Search covers the online library and local files at the same time. Results are grouped by type.

EchoBrain generates automatic playlists. Music Flow adds seven feed toggles. The queue is saved, so reopening the app resumes where you left off.

---

## 3. Player

Playback uses media_kit/mpv with a DSP chain. It handles MP3, M4A, FLAC, OGG, OPUS and local files.

The layout adapts to the window: compact, normal and extended. Controls include play/pause, next/previous, shuffle, repeat, volume, favourites, queue, lyrics, comments and options.

The mini-player shows cover art, a scrolling title and the main controls. Click it to open the full player.

Seven backgrounds use a palette taken from the cover art. The player also has wavy sliders, HeartBurst on like, shimmer while loading and a circular EQ. A label always shows the source and codec, for example `WEB_REMIX · Opus 160 kbps`, `FLAC monochrome` or `Local file`.

---

## 4. Automix and crossfade

Crossfade starts when the current track is about to end. The duration is configurable; Automix uses a 16-beat DJ blend of 4–15 s.

The standby player is prepared 20 s early, up to 35 s if preparation is slow, so the work happens outside the fade. A 220 ms constant-power handoff moves audio to the standby player before the blend.

BPM, beat phase and key come from FFT and spectral flux, and are cached per track. Energy scans find the mix-in and mix-out points. The entry offset is chosen so a beat of the incoming track lands at the end of the fade. Low frequencies of the outgoing track are ducked to avoid bass build-up.

Keys are mapped to the Camelot wheel (1A–12A / 1B–12B). The next track is picked from the first three in the queue.

**Settings → Player → Automix diagnostics** shows state, lead, trigger, levels, BPM in/out, key and the event log. An overlay can be shown in the player. See [`AUTOMIX.md`](AUTOMIX.md) and [`CROSSFADE.md`](CROSSFADE.md).

---

## 5. Lyrics, EQ, DSP

Twelve lyrics providers support word sync, translation and stable rendering.

The equalizer has 10 bands with presets, AutoEq search and the Axion page. The DSP chain adds gain, loudness-based normalization and Mono/Stereo options.

The sleep timer stops playback after a chosen time or at the end of the track.

---

## 6. Downloads and export

Download songs and playlists from their menus for offline listening.

MP3 export converts local or downloaded files with ID3v2.3 tags and embedded cover art. Output goes to a `.part` file that is renamed only on success; cancel and retry work on that state.

Monochrome FLAC is available as a streaming quality. If it has no match, is rate-limited or is unreachable, playback falls back to YouTube.

Export does not convert a live stream directly; the file must already be on disk.

---

## 7. Discovery and social

Explore has sections, new releases, charts and mixes. Podcasts come from YouTube Music.

Comments open from the player. They show author, avatar, text, likes and replies. Writing comments is not supported in the Android reference either.

Song recognition ("Echo Find") records 8 seconds from the microphone, builds a spectral fingerprint and compares it with your indexed local songs. Index the library first in **Settings → Song recognition**. The result shows title, artist and a match percentage, with a Play button. It works offline and only identifies indexed songs.

---

## 8. Wrapped

Wrapped uses real `FEmusic_history` data, not local Echo data.

Nine slides: cover and introduction, total minutes (estimated from track durations), top artists, top songs, genres, listening radars, animated EQ bars, a recap poster with five colours, and closing/share. Each slide stays 8.5 s with a progress bar. Accounts with no history show an empty state.

---

## 9. Cast, remote, devices

Cast discovers Chromecast and smart TVs over mDNS and DIAL, shows a picker, and starts playback through CastV2 on the device.

The LAN remote control starts only when enabled in settings. It has no authentication, so enable it only on a trusted network.

Device link connects two instances to share playback state. It uses the account fingerprint announced on the LAN; see [`DEVICE_LINK_PROTOCOL.md`](DEVICE_LINK_PROTOCOL.md).

---

## 10. Settings and diagnostics

The 15 Android settings entries are present, with global search at the top. Options that cannot work on Windows appear as disabled tiles with the reason, not as silent toggles.

Main sections: Account, Appearance, Player, Content, Music Flow, Network, Updates, Info.

Automix diagnostics and diagnostic mode (`ECHO_DIAG=1`) expose internal state through a loopback-only HTTP server.

---

## 11. Not portable

These Android features have no Windows equivalent and are excluded from the parity count:

- home screen widgets
- Media3 notification and Quick Settings tile
- haptics
- ringtones
- bit-perfect USB output
- wallpaper-based Material You colours
- real `RenderEffect` refraction

Everything else is implemented: 48 of 48 portable features. See [`PARITY_MATRIX.md`](PARITY_MATRIX.md).
