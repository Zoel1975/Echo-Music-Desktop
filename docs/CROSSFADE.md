# Crossfade (port da Echo Android)

## Pre-arm adattivo

Il port segue `AdaptivePreArmManager.kt` / `StandbyCrossfadeSchedulerImpl.kt`:

- lead iniziale **20 s** (max **35 s**), non più la sola durata del crossfade;
- il tempo di preparazione dello standby viene misurato e registrato:
  - se supera 8 s il lead cresce di `1.5 × (prep − 8 s)`, fino a 35 s;
  - se le preparazioni sono veloci il lead decade di 2 s alla volta fino a 20 s;
- lo standby viene preparato quando `remaining <= lead` e **non** quando
  `remaining <= crossfade`: quest'ultimo è il momento del trigger;
- prima del trigger si attende che lo standby sia davvero pronto
  (`playing == true` e `bufferedPosition >= position + 150 ms`), equivalente
  di `STATE_READY`. Se non è pronto entro 2,5 s il crossfade non parte, così
  non si sente il "blocca e riparte" dovuto al buffering a metà fade.

## Handoff e curva

- durante l'handoff il player udibile scende con `cos(t·π/2)` mentre lo standby
  sale con `sin(t·π/2)` in **220 ms**: nessun salto di volume;
- il crossfade vero usa la stessa curva equal-power per la durata impostata;
- i tick asincroni sovrapposti e quelli di una fade annullata vengono ignorati
  (`CrossfadeEngine` con generation guard);
- **i due volumi vengono applicati in parallelo** (`Future.wait`) in ogni tick:
  awaitarli in sequenza raddoppiava la finestra in cui un tick poteva essere
  saltato, lasciando gradini di volume percettibili ("scattino");
- **un tick saltato non perde progresso**: `t` viene ricalcolato dal cronometro
  a ogni tick, quindi la curva resta continua;
- a fine fade i volumi finali (`0` e `peak`) vengono scritti esplicitamente:
  un callback piattaforma perso non può lasciare un volume intermedio proprio
  mentre il player principale fa il seek al brano successivo;
- se l'handoff non completa entro 700 ms, i volumi finali vengono forzati;
- il volume finale viene ripristinato dal valore catturato all'inizio, non
  ricalcolato da un player muto (che lo portava al 100%).

Nota: Android separa i due ruoli scambiando i player a fine fade. Qui il
player principale resta stabile per non dover riagganciare tutti gli stream
dell'interfaccia; la preparazione anticipata e la verifica del buffering
rimuovono pero' la causa dello stall.

## Automix

L'Automix Android e' stato portato nelle fasi 1-3: `BeatAnalyzer` (STFT,
spectral flux, autocorrelazione per BPM/beat-grid/chiave), mix-in/mix-out
dinamici, beat-matching, DJ blend di 16 beat, ducking low-shelf, mixing
armonico con Camelot wheel e diagnostica. Vedi `docs/AUTOMIX.md` per dettagli
e limiti (il ducking e' un filtro statico sul player di uscita, non un IIR
per-sample come su Android).
