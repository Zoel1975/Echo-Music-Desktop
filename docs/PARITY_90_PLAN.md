# Parity plan — 90% and beyond

## Goal

Reach at least 90% feature parity with the Android app, excluding surfaces that have no Windows equivalent (see the exclusions in [`PARITY_MATRIX.md`](PARITY_MATRIX.md)).

## Phases

- [x] **Phase 1 — core playback**: queue, persisted queue, crossfade, sleep timer, SponsorBlock.
- [x] **Phase 2 — discovery**: home sections, search, library filters, playlists, Explore, podcasts, Music Flow.
- [x] **Phase 3 — Automix**: beat analysis, dynamic mix-in/out, beat matching, 16-beat DJ blend, ducking, Camelot harmonic mixing, diagnostics.
- [x] **Phase 4 — audio**: 10-band EQ, AutoEq, loudness normalization, Monochrome FLAC, MP3 export with cover art.
- [x] **Phase 5 — presentation**: Android fonts, 7 player backgrounds, EchoGlass, wavy sliders, HeartBurst, marquee, shimmer, circular EQ, ambient palette.
- [x] **Phase 6 — account and social**: CDP sign-in, account/sign-out, age-gated playback, YouTube comments, song recognition.
- [x] **Phase 7 — Wrapped**: 9 animated slides from real `FEmusic_history` data with YouTube Music branding.
- [x] **Phase 8 — settings**: all 15 Android entries, global search, and a wiring audit of every persisted option. Feasible options are implemented; non-portable ones are disabled with an explicit reason.

## Result

`docs/PARITY_MATRIX.md`: **48/48 = 100%** of portable features.

## Verification gates

Every change must pass:

```bash
flutter analyze     # 0 errors
flutter test        # all green
flutter build windows --release
```

Then commit, push, rebuild the installer, upload the assets to release v1.0.0, reinstall locally, and check that no `error.log` is produced.
