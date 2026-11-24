# Age-restricted tracks

## Current status: solved

Age-restricted YouTube Music tracks play **directly in the app**, without opening a browser. The fix is the complete port of the workaround used by Echo Android / InnerTubeX v0.7.0.

### Root cause of the previous failure

The player request used a fabricated `signatureTimestamp` (`days since epoch - 1`, about 20400). YouTube encodes `signatureCipher.s` according to the received `signatureTimestamp`: with a wrong value, the player JS deciphered the URL with a different algorithm and **every media URL returned HTTP 403**. The final fallback (`capturePoToken`) opened a visible Chrome window — the behavior you saw.

### Implemented fix

`lib/services/stream_resolver.dart`:

1. **Real `signatureTimestamp`** — read from `https://www.youtube.com/` (`"STS":20775`), cached for 6 hours with the YouTube Music watch page as fallback. This matches `YtConfigParserImpl.fetchConfig()` in InnerTubeX.
2. **Mobile body fields** — `context.request` (`internalExperimentFlags`, `useSsl`), `context.user` with `onBehalfOfUser`, `videoCheckOk: true`, `html5Preference: "HTML5_PREF_WANTS"`.
3. **Immediate deciphering** — when the player returns only `signatureCipher` formats (typical for age-gated tracks), `_resolveWithCipher()` deciphers them with the Node-backed player JS **before** any browser fallback. It applies `pot=` and `cpn=` and the WEB_REMIX identity to the resulting URL.
4. **Correct User-Agent** — the ranged validation GET uses the User-Agent of the client that generated the URL, not a hardcoded one.
5. **No visible browser** in the normal path.

### Live verification

On the test track `esHBHhbDQh4`:

| Check | Result |
|---|---|
| `/player-raw` | 16 formats, all with `signatureCipher`, no direct URL |
| STS read | `20775` from `https://www.youtube.com/` |
| `/resolve` | `client = CIPHER`, `audio/webm` Opus 160 kbps |
| Playback | `playing=true`, position advances, `error=null` |
| Chrome processes after play | **0** |
| `error.log` | absent |

## BotGuard / PoToken

In addition to the STS, the app mints the PoToken locally, as Android does:

- `lib/services/po_token_minter.dart` ports `PoTokenWebView.kt` and `JavaScriptUtil.kt`: `Create` → descramble (+97 per byte) → execution of `assets/po/po_token.html` in the CDP-connected Chrome page → `GenerateIT` → mint per session, with 3 attempts;
- the token is stored per `videoId` in Hive (`POTOKENS`, 12 h TTL);
- it is sent as `serviceIntegrityDimensions.poToken` in the player body and as `pot=` on the googlevideo URL, together with `cpn` (16 random characters).

Headers and context follow mobile: `?prettyPrint=false` without an API key, numeric `X-YouTube-Client-Name`, `X-Goog-Visitor-Id` on every client, `WEB_CREATOR` on `studio.youtube.com` with a SAPISIDHASH bound to that origin.

## Real limitation

The client-side fix works for tracks where YouTube accepts the authenticated session. If an account is **not verified as an adult**, YouTube may answer `LOGIN_REQUIRED / "Sign in to confirm your age"` for all clients: in that case age verification must be completed on the Google account — it cannot be bypassed by the client or by the PoToken.

## Diagnostics

With `ECHO_DIAG=1`:

- `GET /player-raw?id=VIDEO_ID` — shows status, format count, and whether formats are ciphered;
- `GET /cipher/diag?id=VIDEO_ID` — shows STS, player JS, cipher formats, and URL probe responses;
- `GET /cipher/test?id=VIDEO_ID` — tries deciphering and returns the stream;
- `GET /player/debug-exact?id=VIDEO_ID` — field/header removal matrix to isolate the block.

Tests: `test/age_gate_mobile_fix_test.dart` covers the mobile body, the real STS, and the cipher path.
