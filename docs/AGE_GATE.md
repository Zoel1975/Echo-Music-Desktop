# Brani con blocco per età

## Aggiornamento: port del fix mobile (BotGuard locale)

Il fix usato ora da Echo Android non è più il sniffing della rete di Chrome:
genera un **PoToken BotGuard localmente** in una WebView nascosta e lo manda
nel campo top-level `serviceIntegrityDimensions.poToken` di `/player`.

Desktop ora fa la stessa cosa:

- `lib/services/po_token_minter.dart` porta `PoTokenWebView.kt` +
  `JavaScriptUtil.kt`: `Create` → descramble (+97 per byte) → esecuzione di
  `po_token.html` nella pagina Chrome già usata per il login via CDP →
  `GenerateIT` → creazione del minter → mint per sessione (visitorData /
  dataSyncId), con 3 tentativi e ricreazione in caso di challenge invalida;
- `assets/po/po_token.html` è copiato dal reference Android;
- il body `/player` ora ha `serviceIntegrityDimensions` in alto (non più
  dentro `playbackContext`, dove YouTube lo ignorava), niente `key=` ma
  `prettyPrint=false`, versioni client aggiornate, `WEB_CREATOR` su
  `studio.youtube.com`, header `X-Goog-Api-Format-Version`/`X-Origin`/
  `X-Goog-Visitor-Id` e `pot=` + `cpn` sull'URL googlevideo;
- **rimosso `context.user.onBehalfOfUser` dal player**: con il nostro id
  YouTube rispondeva HTTP 401 (verificato con matrice di probe).

## Limite reale

Con l'account di test, i client web ora rispondono 200 ma
`playabilityStatus = LOGIN_REQUIRED / "Sign in to confirm your age"`: YouTube
richiede che **l'account sia verificato come maggiorenne**, e questo non è
aggirabile né dal client né dal PoToken. Il PoToken locale viene generato
(coverificato: token validi, 128-300 caratteri), ma non basta se l'account
non è age-verified. Come ultima ratio resta il capture dell'URL che Chrome
ottiene dal profilo autenticato (`capturePoToken`), che ha già funzionato
quando il profilo era verificato.

## Approccio storico (fallback)

Non si "bypassa" la verifica dell'età: si usa la **sessione dell'account dell'utente**, esattamente come fa YouTube nel browser e come fa yt-dlp con i cookie importati.

Flusso (port di `yt-dlp` + provider `getpot-wpc`):

1. I client InnerTube vengono provati in ordine; per i brani age-gated è stato aggiunto `WEB_CREATOR` (client id 62, richiede login), oltre a `WEB_REMIX`/`WEB_EMBEDDED_PLAYER` già presenti con `contentCheckOk` e `racyCheckOk`.
2. Se YouTube risponde con un motivo legato all'età ("age", "sign in", "unavailable"), `StreamResolver` apre il profilo Chrome già usato per il login sul video e, tramite CDP, cattura:
   - il `poToken` dal body della richiesta `youtubei/v1/player`;
   - il parametro `pot` dalla richiesta `googlevideo.com/videoplayback`;
   - l'URL stream con i relativi header.
3. I token vengono salvati per **videoId** in Hive (`POTOKENS`, TTL 12 h) perché i PoToken web sono legati al video.
4. L'app riprova i client InnerTube con:
   - `playbackContext.contentPlaybackContext.poToken` nel body player;
   - `pot=<token>` aggiunto all'URL googlevideo.
5. Solo se nulla funziona viene riutilizzato direttamente l'URL stream catturato da Chrome (comportamento precedente).

## Cosa deve fare l'utente (una sola volta)

1. Aprire il brano bloccato nel player: si apre la finestra Chrome con il profilo Echo.
2. **Completare la verifica dell'età / accedere con l'account YouTube** in quella finestra.
3. Tornare all'app: la cattura e il retry sono automatici. Le volte successive il token in cache evita di ripetere la procedura finché non scade.

Nota: se l'account YouTube non è verificato come maggiorenne, YouTube non consentirà la riproduzione: la verifica va fatta sull'account, non aggirabile dal client.

## Verifica tecnica

Sonda diagnostica (solo con `ECHO_DIAG=1`): `POST /potoken/capture?id=VIDEO_ID` stampa quali token sono stati ottenuti. Il flusso CDP usa il websocket della **pagina** (`Page.navigate` dopo `Network.enable`): il websocket di livello browser non riceve gli eventi di rete.

Test: `test/potoken_test.dart` copre il parsing dei token e la catena di fallback.
