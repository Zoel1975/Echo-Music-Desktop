# Automix — fase 3 (DJ blend + ducking)

Port dell'Automix di Echo Android. Questa build contiene la fase 3.

## Cosa c'è

- `lib/services/beat_analysis.dart`: port di `BeatAnalyzer` (FFT radix-2,
  spectral flux, autocorrelazione BPM 60-180 con folding 70-140, comb-filter
  per la fase del beat). Tutto puro e testabile.
- `lib/services/beat_analyzer_service.dart`: decodifica una finestra di 30 s a
  22050 Hz mono con FFmpeg Kit (già presente per l'export MP3), esegue
  l'analisi e cache il risultato per videoId in Hive (`BEAT_ANALYSIS`).
- `automixTriggerMs()`: sposta l'inizio del crossfade in modo che la fine del
  blend cada su un beat della traccia in uscita, vicino al suo **mix-out**
  dinamico (energy scan della coda, decode con `-sseof`);
- **fase 2**: viene analizzata anche la traccia **in entrata** durante il
  pre-arm; `beatAlignedStartMs()` calcola l'offset di ingresso in modo che
  un suo beat cada esattamente alla fine del fade (phase matching), partendo
  dal **mix-in** dinamico (energy scan dell'intro);
- Impostazione **Automix · allinea al beat** (Player, attiva di default quando
  il crossfade è acceso);
- Sonda diagnostica `POST /beat/analyze` (con `ECHO_DIAG=1`) che genera un
  click track a 120 BPM e verifica decoding + analisi end-to-end.

- **fase 3**: DJ blend di **16 beat** (`djBlendDurationMs`, clamp 4-15 s) al
  posto della durata fissa; **ducking low-shelf** sulla traccia in uscita
  (`bass=f=150:g=-8`) applicato solo al momento della creazione del player
  di standby, poiché la catena `af` di mpv è uno snapshot per player;
  rilevamento chiave (Krumhansl-Schmuckler) come `keyLabel`;
- **mixing armonico** (`harmonic_mixing.dart`): la chiave viene convertita in
  Camelot (1A-12A / 1B-12B) e usata per scegliere il brano successivo tra i
  primi 3 della coda. Punteggio: stessa chiave 1.0, relativa maggiore/minore
  0.85, quinta giusta (adescente sul wheel) 0.7, altrimenti 0. Il candidato
  migliore viene spostato subito dopo il brano corrente con
  `moveAudioSource`. Setting **Automix · mixing armonico** in Player (default
  on) e risultato visibile nella diagnostica. L'analisi dei candidati è
  limitata a 3 s ciascuno per non consumare il lead del pre-arm.

## Diagnostica (port del debug overlay Android)

- **Impostazioni → Riproduttore → Diagnostica Automix** mostra stato (IDLE,
  MONITOR, ARMED, HANDOFF, FADING), crossfade/automix attivi, lead/blend/trigger,
  volumi, BPM/chiave/mix point di uscita e ingresso, tempo ratio e il log degli
  eventi (ultimi 150).
- Il log viene scritto anche in `%LOCALAPPDATA%\com.echo\Echo Music\automix.log`.
- Switch **Mostra overlay nel player** riproduce l'overlay monospace di Android
  (stato, BPM in/out, chiave, prossimo mix).
- Con `ECHO_DIAG=1`: `GET /automix/state` restituisce tutto lo stato in JSON,
  `POST /settings/crossfade?enabled=1&seconds=5` abilita il crossfade,
  `POST /beat/analyze-song?id=VIDEO_ID` analizza un brano senza coda (verifica
  IN/OUT) e `POST /queue/crossfade-test` simula un passaggio automatico.

L'analisi non partiva perché `StreamResolver` è un singleton statico e il
service controllava `GetIt.I.isRegistered<StreamResolver>()`, sempre falso.
Ora usa direttamente `StreamResolver.instance`; il decode FFmpeg include lo
User-Agent di YouTube e registra exit code/log in caso di fallimento.

Il pre-arm usa un guard contro le chiamate concorrenti del position stream e,
se media_kit non espone `bufferedPosition`, procede comunque riprovando `play()`
al trigger: prima di questa correzione ogni pre-arm veniva annullato e il
crossfade automatico non partiva mai.

## Transizioni senza scatti

Le transizioni Automix usano lo stesso motore di crossfade del cambio brano manuale:

- l'handoff tra player principale e standby dura **220 ms** con curva equal-power;
- i volumi dei due player vengono aggiornati in parallelo a ogni tick e il progresso
  viene ricalcolato dal cronometro, quindi un tick saltato non crea un gradino;
- i volumi finali vengono scritti esplicitamente a fine rampa (e forzati se un
  callback piattaforma va perso), così il seek al brano successivo avviene sempre
  a volume zero del player principale.

Vedi [`CROSSFADE.md`](CROSSFADE.md) per i dettagli.

## Limiti della fase 3

- il ducking di Android è per-sample con rampa (nessun "zipper noise"): qui è
  un filtro statico sul player di uscita, mascherato dalla fade-in della nuova
  traccia. Non è un IIR per-sample, ma evita il mud dei due bassi;
- il confronto armonico considera solo i 3 brani successivi della coda, non
  l'intera libreria o le raccomandazioni radio.

## Test

`test/beat_analysis_test.dart` copre FFT, rilevamento BPM su traccia sintetica,
silenzio, allineamento del trigger e round-trip della cache.
