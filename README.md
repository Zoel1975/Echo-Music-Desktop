<div align="center">
  <img src="assets/Echo_github.png" alt="Echo Music Logo" width="140"/>
  <h1>Echo Music Desktop</h1>
  <p><strong>Your complete music player on Windows.</strong></p>
  <p>Ad-free streaming from YouTube Music, offline listening, intelligent Automix, and an interface crafted down to the last detail.</p>

  <a href="https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest"><img src="assets/Windows-button.png" alt="Download for Windows" width="170"/></a>
</div>

---

## What it is

Echo Music Desktop is the native Windows port of [Echo Music](https://github.com/EchoMusicApp/Echo-Music), the Android app for YouTube Music. It is not a browser wrapper: it is a Flutter client that signs in to your YouTube Music account, plays audio through a dedicated engine, and adds features the web player does not have.

**Status:** full parity with the Android app (more like 95% for functions, still working on stability and design) — **48/48 features** (`docs/PARITY_MATRIX.md`).

**Platforms:** Windows x64. macOS and Linux are not supported in this release.

**License:** GPL-3.0.

---

## Features at a glance

### Listening
- **Ad-free streaming** from your YouTube Music library at the best available quality.
- **Age-restricted tracks** play thanks to the ported Android workaround (BotGuard PoToken + real `signatureTimestamp` + `signatureCipher` deciphering). No browser window opens during playback.
- **Offline downloads** and real MP3 export (ID3v2.3, cover art included), plus a Monochrome FLAC option with YouTube fallback and Data Saver priority.
- **Source and codec always visible**, so you know what you are listening to.

### Discovery and organization
- **Customizable home** with configurable sections.
- **Search** across your online library and local files, with filters.
- **Playlists and queue**: tapping a song sets the whole playlist as the playback queue, starting at that song.
- **Explore**, **podcasts**, **Music Flow** with 7 toggles, **history**, and **liked songs**.

### Automix and crossfade
- **Adaptive crossfade** with a 20–35 s pre-arm and a 220 ms handoff with no clicks.
- **Beat analysis** (BPM, phase, key) plus dynamic mix-in/mix-out computed from the audio energy.
- **Beat matching** and a 16-beat DJ blend with outgoing-track ducking.
- **Harmonic mixing** with the Camelot wheel: the next track is chosen from the first three in the queue by key compatibility.
- **Automix diagnostics** with state, levels, BPM, and an event log.

### Lyrics and sound
- **12 lyrics providers**, word-by-word sync, translation, and reflow-free rendering.
- **10-band equalizer**, AutoEq search, Axion presets, and **DSP** with gain control.
- **Volume normalization** based on track loudness.

### Experience
- **YouTube Music Wrapped** driven by your real listening history (`FEmusic_history`), with 9 animated slides, themes, radar, EQ bars, and selectable poster colors.
- **YouTube comments** on the playing track, with author, avatar, likes, and replies.
- **Offline song recognition**: records the microphone, computes a spectral fingerprint, and matches it against your indexed local library. No paid API.
- **Direct CastV2** to Chromecast and smart TVs (mDNS + DIAL).
- **7 player backgrounds**, bundled Android fonts, EchoGlass, wavy sliders, HeartBurst, marquee, shimmer, circular EQ, and ambient palette.
- **Sleep timer**, **SponsorBlock**, **remote control**, **device link**, and settings with global search.

The complete guide is in [`docs/FEATURES.md`](docs/FEATURES.md); to get started see [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

---

## Installation

### Windows installer (recommended)
1. Download `EchoMusicSetup.exe` from the [Releases page](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest).
2. Run it. The wizard is available in English and Italian.
3. Choose whether to create Desktop and Start Menu shortcuts, then finish.
4. Launch **Echo Music** from the Start Menu or the desktop shortcut.

The installer also creates an uninstaller, available in **Apps & features**.

### Portable build
1. Download `EchoMusicPortable.zip` from the [Releases page](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest).
2. Extract it to a folder of your choice.
3. Run `echo.exe`. Nothing is written to the registry.

### Upgrading
Download the new installer and run it: it overwrites the previous version while keeping your data (account, preferences, history). Extract the portable archive into a new folder.

---

## First run

1. Click **Sign in** and complete the login with your Google / YouTube Music account. A dedicated Chrome profile is used and cookies are stored locally.
2. Your library, history, and playlists load after sign-in.
3. Click a song to start listening. Open the player for full controls, lyrics, and Automix.

For details — including age-restricted tracks and song recognition — see [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

---

## Building from source

Flutter with Windows desktop support is required.

```bash
git clone https://github.com/ItsZale0/Echo-Music-Desktop.git
cd Echo-Music-Desktop
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

Release build:

```bash
flutter build windows --release
```

The Inno Setup installer is generated from `installer/EchoMusic.iss`. Full verification:

```bash
flutter analyze
flutter test
tool/verify.ps1
```

---

## Documentation

| Document | Contents |
|---|---|
| [`docs/FEATURES.md`](docs/FEATURES.md) | Complete user-facing guide to all 48 features |
| [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md) | Installation, sign-in, first steps, Automix, troubleshooting |
| [`docs/PARITY_MATRIX.md`](docs/PARITY_MATRIX.md) | Android → Desktop parity matrix (48/48) |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Technical architecture and components |
| [`docs/AGE_GATE.md`](docs/AGE_GATE.md) | How age-restricted playback works |
| [`docs/AUTOMIX.md`](docs/AUTOMIX.md) | Beat analysis, DJ blend, harmonic mixing |
| [`docs/CROSSFADE.md`](docs/CROSSFADE.md) | Adaptive pre-arm, handoff, fade curve |
| [`docs/MP3_EXPORT.md`](docs/MP3_EXPORT.md) | MP3 export with cover art |
| [`docs/MONOCHROME_FLAC.md`](docs/MONOCHROME_FLAC.md) | Monochrome FLAC and fallback |
| [`docs/PORTING_PLAN.md`](docs/PORTING_PLAN.md) | Historical porting plan and implementation details |

---

## Community and support

Open an issue in this repository for bug reports and feature requests. The original Android app is [EchoMusicApp/Echo-Music](https://github.com/EchoMusicApp/Echo-Music).

<div align="center">
    Built with Flutter. Licensed under <a href="LICENSE">GPL-3.0</a>.
</div>
