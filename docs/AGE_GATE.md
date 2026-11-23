# Brani con blocco per età

## Stato attuale: risolto

I brani age-gated di YouTube Music vengono riprodotti **direttamente in app**, senza aprire il browser. Il fix è il port completo del workaround usato da Echo Android / InnerTubeX v0.7.0.

### Causa del problema precedente

Il body della richiesta `/player` usava un `signatureTimestamp` fabbricato (`giorni dall'epoca - 1`, circa 20400). YouTube codifica il campo `signatureCipher.s` in base al `signatureTimestamp` ricevuto: con un valore sbagliato, il player JS scaricato decifrava l'URL con un algoritmo diverso e **ogni URL.media restituiva HTTP 403**. Il fallback finale (`capturePoToken`) apriva Chrome visibile, che è il comportamento che si vedeva.

### Fix implementato

`lib/services/stream_resolver.dart`:

1. **`signatureTimestamp` reale** — letto da `https://www.youtube.com/` (`"STS":20775`), con cache di 6 ore e fallback sulla pagina di YouTube Music. Corrisponde a `YtConfigParserImpl.fetchConfig()` di InnerTubeX.
2. **Campi body mobile** — `context.request` (`internalExperimentFlags`, `useSsl`), `context.user` con `onBehalfOfUser`, `videoCheckOk: true`, `html5Preference: "HTML5_PREF_WANTS"`.
3. **Decifratura immediata** — quando il player restituisce solo formati `signatureCipher` (tipico dei brani age-gated), `_resolveWithCipher()` li decifra con il solver JS/Node **prima** di qualunque fallback browser. Applica `pot=` e `cpn=` e l'identità WEB_REMIX all'URL risultante.
4. **Sondaggio con UA corretto** — la verifica rangedGET usa lo User-Agent del client che ha generato l'URL, non uno hardcoded.
5. **Niente più browser visibile** nel percorso normale.

### Verifica live

Sul brano di test `esHBHhbDQh4`:

| Controllo | Risultato |
|---|---|
| `/player-raw` | 16 formati, tutti con `signatureCipher`, nessun URL diretto |
| STS letto | `20775` da `https://www.youtube.com/` |
| `/resolve` | `client = CIPHER`, `audio/webm` Opus 160 kbps |
| Riproduzione | `playing=true`, posizione avanza, `error=null` |
| Processi Chrome dopo il play | **0** |
| `error.log` | assente |

## PoToken BotGuard

Oltre allo STS, l'app genera localmente il PoToken BotGuard, come fa Android:

- `lib/services/po_token_minter.dart` porta `PoTokenWebView.kt` e `JavaScriptUtil.kt`: `Create` → descramble (+97 per byte) → esecuzione di `assets/po/po_token.html` nella pagina Chrome connessa via CDP → `GenerateIT` → mint per sessione, con 3 tentativi;
- il token viene salvato per `videoId` in Hive (`POTOKENS`, TTL 12 h);
- viene inviato come `serviceIntegrityDimensions.poToken` nel body `/player` e come `pot=` sull'URL googlevideo, insieme a `cpn` (16 caratteri casuali).

Header e contesto seguono mobile: `?prettyPrint=false` senza API key, `X-YouTube-Client-Name` numerico, `X-Goog-Visitor-Id` su ogni client, `WEB_CREATOR` su `studio.youtube.com` con SAPISIDHASH legato all'origine corretta.

## Limite reale

Il fix client funziona per i brani in cui YouTube accetta la sessione autenticata. Se un account **non è verificato come maggiorenne**, YouTube può rispondere `LOGIN_REQUIRED / "Sign in to confirm your age"` per tutti i client: in quel caso la verifica va completata sull'account Google, non è aggirabile dal client o dal PoToken.

## Diagnostica

Con `ECHO_DIAG=1`:

- `GET /player-raw?id=VIDEO_ID` — mostra stato, numero formati e se hanno cipher;
- `GET /cipher/diag?id=VIDEO_ID` — mostra STS, player JS, formati cifrati e risposte dei probe URL;
- `GET /cipher/test?id=VIDEO_ID` — prova la decifratura e restituisce il stream;
- `GET /player/debug-exact?id=VIDEO_ID` — matrice di rimozione di campi/header per isolare il blocco.

Test: `test/age_gate_mobile_fix_test.dart` copre il body mobile, lo STS reale e il percorso cipher.
