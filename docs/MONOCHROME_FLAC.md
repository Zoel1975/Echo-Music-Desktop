# Monochrome FLAC — lossless quality option

Echo Desktop can use [Monochrome](https://monochrome.st/) as a lossless audio
source. It is exposed in **Settings → Player → Streaming Quality**
as `FLAC (Monochrome)`, alongside `HIGH` and `LOW`.

## How it works

1. `MonochromeService.findBySong(song)` searches the public API
   (`GET https://tracks.monochrome.st/search?q=<artist> <title>`, ISRC first
   when available). Results are cached in memory for the session.
2. `MonochromeAudioSource` streams `GET /track/<id>` with HTTP Range requests,
   so seeking works exactly like the YouTube source. Monochrome serves raw
   FLAC bytes (`fLaC` magic, `Accept-Ranges: bytes`).
3. If Monochrome has no match, is rate-limited (HTTP 429) or unreachable, the
   source automatically falls back to the normal YouTube stream for that
   track — playback never breaks.

Browser-like `User-Agent` and `Referer` headers are sent because the CDN
rejects generic client User-Agents.

## Precedence

`ExtensionQuality.resolve` applies, in order:

- **Data Saver ON** → `low` (explicit bandwidth preference always wins)
- **Quality = FLAC** → Monochrome
- **Android "high quality (320 kbps)" extension ON** → `high`
- otherwise → the configured quality

## Diagnostic probes

With `ECHO_DIAG=1` the runtime probe exposes:

- `GET /monochrome/search?q=<query>` — parsed API results
- `GET /monochrome/stream?id=<id>` — status, `content-range` and first 4 bytes

## Tests

`test/monochrome_test.dart` covers parsing, quality precedence and the
player/settings wiring. `flutter analyze` reports 0 errors; the full suite
passes.
