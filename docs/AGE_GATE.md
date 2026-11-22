# Brani con blocco per età

## Approccio

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
