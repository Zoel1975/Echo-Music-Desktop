# Age-restricted tracks

Age-restricted YouTube Music tracks play in the app. No browser window opens during normal playback. The code ports the workaround from Echo Android and InnerTubeX v0.7.0.

## Previous failure

The player request used a fabricated `signatureTimestamp` (days since epoch minus one, about 20400). YouTube encodes `signatureCipher.s` against that timestamp, so a wrong value made the player JS decipher the URL incorrectly and every media URL returned HTTP 403. The old fallback opened a visible Chrome window to capture a PoToken.

## Current implementation

`lib/services/stream_resolver.dart`:

1. Read the real `signatureTimestamp` from `https://www.youtube.com/` (`"STS":20775`), cached for 6 hours, with the YouTube Music watch page as fallback.
2. Send the mobile body fields: `context.request` (`internalExperimentFlags`, `useSsl`), `context.user` with `onBehalfOfUser`, `videoCheckOk: true`, `html5Preference: "HTML5_PREF_WANTS"`.
3. When the player returns only `signatureCipher` formats, as it does for age-gated tracks, decipher them with the Node-backed player JS before any browser fallback. Add `pot=` and `cpn=` and the WEB_REMIX identity to the URL.
4. Use the User-Agent of the generating client for the ranged validation GET.

## Verification

On the test track `esHBHhbDQh4`:

| Check | Result |
|---|---|
| `/player-raw` | 16 formats, all ciphered, no direct URL |
| STS | `20775` from `https://www.youtube.com/` |
| `/resolve` | client `CIPHER`, `audio/webm` Opus 160 kbps |
| Playback | playing, position advances, no error |
| Chrome processes after play | 0 |
| `error.log` | absent |

## PoToken

`lib/services/po_token_minter.dart` ports `PoTokenWebView.kt` and `JavaScriptUtil.kt`: create, descramble (+97 per byte), run `assets/po/po_token.html` in the CDP-connected Chrome page, and call `GenerateIT`. It retries three times. The token is stored per `videoId` in Hive (`POTOKENS`, 12 h) and sent as `serviceIntegrityDimensions.poToken` in the player body and `pot=` on the googlevideo URL, with a 16-character `cpn`.

Headers follow the mobile client: `?prettyPrint=false` without an API key, numeric `X-YouTube-Client-Name`, `X-Goog-Visitor-Id` on every client, and `WEB_CREATOR` on `studio.youtube.com` with a SAPISIDHASH bound to that origin.

## Limitation

The client workaround works when YouTube accepts the authenticated session. If the Google account is not verified as an adult, YouTube can answer `LOGIN_REQUIRED / "Sign in to confirm your age"` for every client. Age verification has to be completed on the Google account; neither the client nor the PoToken can bypass it.

## Diagnostics

With `ECHO_DIAG=1`:

- `GET /player-raw?id=VIDEO_ID` — status, format count, cipher state
- `GET /cipher/diag?id=VIDEO_ID` — STS, player JS, cipher formats, URL probes
- `GET /cipher/test?id=VIDEO_ID` — decipher and return the stream
- `GET /player/debug-exact?id=VIDEO_ID` — field/header removal matrix

`test/age_gate_mobile_fix_test.dart` covers the mobile body, the real STS and the cipher path.
