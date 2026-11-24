# Feature guide

This guide describes **what Echo Music Desktop does** and **how to use it**. For implementation details see [`ARCHITECTURE.md`](ARCHITECTURE.md).

Contents:
1. [Account and session](#1-account-and-session)
2. [Library, playlists, and search](#2-library-playlists-and-search)
3. [Playback and player](#3-playback-and-player)
4. [Automix and crossfade](#4-automix-and-crossfade)
5. [Lyrics, EQ, and DSP](#5-lyrics-eq-and-dsp)
6. [Downloads, export, and formats](#6-downloads-export-and-formats)
7. [Discovery and social features](#7-discovery-and-social-features)
8. [Wrapped](#8-wrapped)
9. [Cast, remote control, and devices](#9-cast-remote-control-and-devices)
10. [Settings and diagnostics](#10-settings-and-diagnostics)
11. [Non-portable features](#11-non-portable-features)

---

## 1. Account and session

**Sign in with Google / YouTube Music.** On first launch click **Sign in**: the app opens a dedicated Chrome profile, completes the login, and stores the cookies in a local jar. Subsequent launches require no action.

**What is stored:** authentication cookies, visitor id, preferences, listening history, playlists you created, and cached PoTokens (12 hours). Everything stays on your computer.

**Sign out.** Use **Settings → Account**. Local data (downloads, preferences) remains, but the online library is unavailable until you sign in again.

**Age-restricted tracks.** The app plays them directly in-app:

1. the real `signatureTimestamp` is read from YouTube;
2. the `/player` request is sent with the authenticated YouTube Music context and mobile flags (`videoCheckOk`, `html5Preference`);
3. the response contains only `signatureCipher` formats, deciphered with the player JS via Node.js;
4. `pot=` and `cpn=` are appended to the media URL and playback starts.

No browser window opens. See [`AGE_GATE.md`](AGE_GATE.md).

---

## 2. Library, playlists, and search

**Library.** Six filters: songs, albums, artists, playlists, podcasts, downloads. The view matches the Android app, with cover art, sorting, and in-view search.

**Playlists.** Open a playlist and tap a song: **the whole playlist becomes the playback queue**, starting at that song. You can reorder, remove, and save changes.

**Search.** Searches the online library and local files at the same time, with results grouped by type (songs, albums, artists, playlists, users).

**Smart playlists.** EchoBrain generates automatic playlists; Music Flow offers 7 toggles to customize the feed.

**Persistent queue.** The queue is saved, so closing and reopening the app resumes where you left off.

---

## 3. Playback and player

**Audio engine.** The player uses media_kit/mpv with a dedicated DSP chain. It supports MP3, M4A, FLAC, OGG, OPUS, and local files.

**Three layouts.** The player adapts to the window size: compact, normal, and extended, with scaled controls and artwork.

**Controls.** Play/pause, next/previous, shuffle, repeat, volume, favorites, queue, lyrics, comments, and options. The mini-player at the bottom shows cover art, a scrolling title (marquee), and essential glass-styled controls.

**7 backgrounds.** The player can use seven animated backgrounds with a palette extracted from the cover art.

**Micro-interactions.** Wavy sliders, HeartBurst on like, shimmer while loading, circular EQ, and smooth transitions.

**Source label.** A label always shows the source and codec (for example `WEB_REMIX · Opus 160 kbps`, `FLAC monochrome`, `Local file`).

---

## 4. Automix and crossfade

Automix is the system that makes track transitions seamless, inspired by Echo Android.

**Crossfade.** When the current song is about to end, the app starts fading into the next one. The duration is configurable; in Automix mode a 16-beat DJ blend is used (4–15 s).

**Adaptive pre-arm.** The standby player is prepared **20 seconds early** (up to 35 s if preparation is slow), not inside the fade window. This removes the mid-transition freeze.

**220 ms handoff.** Before the actual crossfade, audio moves from the main player to the standby player with a constant-power 220 ms ramp. No volume jumps.

**Beat analysis.** BPM, beat phase, and musical key are computed for every track with FFT and spectral flux. Results are cached.

**Dynamic mix-in / mix-out.** The intro and outro are analyzed for energy to find the ideal entry and exit points instead of using fixed values.

**Beat matching.** The entry offset of the next track is chosen so one of its beats lands exactly at the end of the fade.

**Ducking.** The outgoing track is attenuated in the low frequencies so the two bass lines do not build up.

**Harmonic mixing.** The key is converted to the Camelot wheel (1A–12A / 1B–12B) and used to pick the next song from the first three in the queue.

**Diagnostics.** **Settings → Player → Automix diagnostics** shows state, lead, trigger, levels, BPM in/out, key, and the event log. An overlay can also be shown inside the player.

See [`AUTOMIX.md`](AUTOMIX.md) and [`CROSSFADE.md`](CROSSFADE.md).

---

## 5. Lyrics, EQ, and DSP

**Lyrics.** Twelve providers, word-by-word sync, translation, and reflow-free rendering.

**Equalizer.** 10 bands with presets, AutoEq search, and the Axion page.

**DSP.** Filter chain with gain, loudness-based volume normalization, and Mono/Stereo options.

**Sleep timer.** Stop playback after a chosen time or at the end of the current track.

---

## 6. Downloads, export, and formats

**Offline downloads.** Download songs and playlists for listening without a connection.

**MP3 export.** Converts local or downloaded files to MP3 with ID3v2.3 tags and embedded cover art. The write is safe: a `.part` file is renamed only on success. You can cancel and retry.

**Monochrome FLAC.** An option for monochrome FLAC sources, with automatic YouTube fallback and Data Saver priority.

**Limitation.** Export works on local and already-downloaded files; it does not convert a stream directly while playing.

---

## 7. Discovery and social features

**Explore.** Discover sections, new releases, charts, and mixes.

**Podcast.** Access YouTube Music podcasts.

**Comments.** Open the comments of a playing track from the player: author, avatar, text, likes, and replies, exactly like the Android app. Writing comments is not implemented in the reference either.

**Song recognition ("Echo Find").** Records 8 seconds from the microphone, computes a spectral fingerprint, and compares it against your indexed local library. Works offline with no paid API. You must first index your local songs with **Index library**; the result shows title, artist, and a match percentage, with a **Play** button.

---

## 8. Wrapped

**YouTube Music Wrapped** uses your real history (`FEmusic_history`), not local Echo data.

Nine animated slides in the Android style:

1. Cover art and introduction;
2. Total minutes listened (estimated from track durations);
3. Top artists;
4. Top songs;
5. Dominant genres;
6. Listening radars;
7. Animated EQ bars;
8. Colorful recap poster (5 selectable colors);
9. Closing and sharing.

Each slide stays for 8.5 seconds with a progress bar. An explicit empty state is shown when the account has no history.

---

## 9. Cast, remote control, and devices

**Cast.** Discovers Chromecast and smart TVs over mDNS and DIAL, opens the picker, and starts playback directly on the device using CastV2.

**Remote control.** A local control server lets you manage playback from another device on the same network.

**Device link.** Connect two instances to synchronize actions and state.

---

## 10. Settings and diagnostics

Fifteen settings entries, the same as the Android app, with **global search** at the top. Options that do not apply on Windows are shown as explicit placeholders, never hidden.

The main sections are: Account, Appearance, Player, Content, Music Flow, Network, Updates, Info.

**Automix diagnostics** and **diagnostic mode** (`ECHO_DIAG=1`) let you inspect the app's internal state through a local server.

---

## 11. Non-portable features

Some Android features have no Windows equivalent and are declared non-portable in the parity matrix:

- home screen widgets;
- Android media notification and Quick Settings tile;
- haptic feedback;
- ringtones;
- bit-perfect USB output;
- Material You palette derived from the system wallpaper;
- real `RenderEffect` refraction.

Everything else — **48 features out of 48** — is implemented. See [`PARITY_MATRIX.md`](PARITY_MATRIX.md).
