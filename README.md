<div align="center">
  <img src="assets/Echo_github.png" alt="Echo Music Logo" width="140"/>
  <h1>Echo Music Desktop</h1>
  <p>A Windows player for YouTube Music.</p>
  <p>Streaming without ads, offline downloads, Automix, and the controls of the Android app.</p>

  <a href="https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest"><img src="assets/Windows-button.png" alt="Download for Windows" width="170"/></a>
</div>

---

## About

Echo Music Desktop is the Windows port of [Echo Music](https://github.com/EchoMusicApp/Echo-Music). It is a Flutter client, not a browser wrapper. It signs in to YouTube Music, plays audio through media_kit/mpv, and includes features the web player does not have.

The port covers 48 of 48 portable Android features (`docs/PARITY_MATRIX.md`). Some Android surfaces have no Windows equivalent and are excluded: home widgets, the Media3 notification and Quick Settings tile, haptics, ringtones, bit-perfect USB output, Material You wallpaper colours, and `RenderEffect` refraction.

Windows x64 only. macOS and Linux are not supported in this release.

GPL-3.0.

---

## Features

Listening:

- YouTube Music library at the best available quality, without ads
- age-restricted tracks in the app, using the Android PoToken and `signatureTimestamp` workaround; no browser window during playback
- offline downloads, MP3 export with ID3v2.3 tags and cover art, and optional Monochrome FLAC with YouTube fallback
- source and codec always shown in the player

Library and discovery:

- configurable home sections, search across online and local files, and six library filters
- tapping a song in a playlist sets the whole playlist as the queue, starting at that song
- Explore, podcasts, Music Flow, history, and liked songs

Automix:

- adaptive crossfade with a 20–35 s pre-arm and a 220 ms handoff
- beat, phase and key analysis; dynamic mix-in and mix-out
- beat matching, a 16-beat DJ blend, bass ducking, and Camelot harmonic mixing
- a diagnostics page with state, levels, BPM, key, and an event log

Lyrics and audio:

- twelve lyrics providers, word sync, translation and stable rendering
- 10-band equalizer, AutoEq search, Axion presets, DSP and loudness normalization

Other:

- Wrapped from real `FEmusic_history` data, with nine slides
- YouTube comments on the playing track
- offline recognition against songs you indexed locally; no paid API
- CastV2 to Chromecast and smart TVs (mDNS + DIAL)
- seven player backgrounds, bundled Android fonts, wavy sliders, HeartBurst, marquee and shimmer
- sleep timer, SponsorBlock, LAN remote control, device link, and settings with search

Details are in [`docs/FEATURES.md`](docs/FEATURES.md). Start with [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

---

## Installation

From the [Releases page](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest):

1. Download `EchoMusicSetup.exe` and run it. The wizard is in English and Italian.
2. Choose the shortcuts you want and finish the install.
3. Start Echo Music from the Start Menu or the desktop shortcut.

The installer adds an uninstaller under **Apps & features**.

For the portable build, download `EchoMusicPortable.zip`, extract it, and run `echo.exe`. Nothing is written to the registry.

An installer upgrade keeps the account, preferences and history. For the portable build, extract the new archive into a new folder.

---

## First run

Click **Sign in** and complete the Google login in the dedicated Chrome profile. The cookies are stored locally; later launches need no action. The library, history and playlists load after sign-in. Click a song to play it.

Age-restricted playback and song recognition are described in [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

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

Release build and checks:

```bash
flutter build windows --release
flutter analyze
flutter test
tool/verify.ps1
```

The installer is generated from `installer/EchoMusic.iss`.

---

## Documentation

| Document | Contents |
|---|---|
| [`docs/FEATURES.md`](docs/FEATURES.md) | User guide to the 48 features |
| [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md) | Install, sign in, first steps, troubleshooting |
| [`docs/PARITY_MATRIX.md`](docs/PARITY_MATRIX.md) | Android to Desktop parity matrix |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Components and data flow |
| [`docs/AGE_GATE.md`](docs/AGE_GATE.md) | Age-restricted playback |
| [`docs/AUTOMIX.md`](docs/AUTOMIX.md) | Beat analysis, DJ blend, harmonic mixing |
| [`docs/CROSSFADE.md`](docs/CROSSFADE.md) | Pre-arm, handoff, fade curve |
| [`docs/MP3_EXPORT.md`](docs/MP3_EXPORT.md) | MP3 export with cover art |
| [`docs/STEMS.md`](docs/STEMS.md) | Instant vocal mute and four-stem separation |
| [`docs/MONOCHROME_FLAC.md`](docs/MONOCHROME_FLAC.md) | Monochrome FLAC and fallback |
| [`docs/PORTING_PLAN.md`](docs/PORTING_PLAN.md) | Historical porting plan |

---

## Support

Open an issue here for bug reports and feature requests. Security reports should go through [`SECURITY.md`](SECURITY.md). The Android app is [EchoMusicApp/Echo-Music](https://github.com/EchoMusicApp/Echo-Music).

<div align="center">
    Built with Flutter. Licensed under <a href="LICENSE">GPL-3.0</a>.
</div>
