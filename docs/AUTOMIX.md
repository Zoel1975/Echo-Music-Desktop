# Automix — fase 1 (beat-align)

Port parziale dell'Automix di Echo Android. Questa build contiene la fase 1.

## Cosa c'è

- `lib/services/beat_analysis.dart`: port di `BeatAnalyzer` (FFT radix-2,
  spectral flux, autocorrelazione BPM 60-180 con folding 70-140, comb-filter
  per la fase del beat). Tutto puro e testabile.
- `lib/services/beat_analyzer_service.dart`: decodifica una finestra di 30 s a
  22050 Hz mono con FFmpeg Kit (già presente per l'export MP3), esegue
  l'analisi e cache il risultato per videoId in Hive (`BEAT_ANALYSIS`).
- `automixTriggerMs()`: sposta l'inizio del crossfade in modo che la fine del
  blend cada su un beat della traccia in uscita.
- Impostazione **Automix · allinea al beat** (Player, attiva di default quando
  il crossfade è acceso).
- Sonda diagnostica `POST /beat/analyze` (con `ECHO_DIAG=1`) che genera un
  click track a 120 BPM e verifica decoding + analisi end-to-end.

## Cosa non c'è ancora (fasi successive)

- mix-in/mix-out dinamici dell'Android (energy scan di intro/outro);
- blend DJ di 16 beat con allineamento delle due griglie (serve l'analisi di
  entrambe le tracce e la scelta del punto di mix);
- ducking low-shelf per-sample (`AutomixDuckAudioProcessor`) durante
  l'overlap, per evitare il "mud" delle due linee di basso.

## Test

`test/beat_analysis_test.dart` copre FFT, rilevamento BPM su traccia sintetica,
silenzio, allineamento del trigger e round-trip della cache.
