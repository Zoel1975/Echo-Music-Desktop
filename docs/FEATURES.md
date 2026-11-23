# Guida alle funzioni

Questa guida descrive **cosa fa** Echo Music Desktop e **come si usa**. Per i dettagli di implementazione vedi [`ARCHITECTURE.md`](ARCHITECTURE.md).

Indice:
1. [Account e sessione](#1-account-e-sessione)
2. [Libreria, playlist e ricerca](#2-libreria-playlist-e-ricerca)
3. [Riproduzione e player](#3-riproduzione-e-player)
4. [Automix e crossfade](#4-automix-e-crossfade)
5. [Testi, EQ e DSP](#5-testi-eq-e-dsp)
6. [Download, export e formati](#6-download-export-e-formati)
7. [Scoperta e funzioni sociali](#7-scoperta-e-funzioni-sociali)
8. [Wrapped](#8-wrapped)
9. [Cast, remote e dispositivi](#9-cast-remote-e-dispositivi)
10. [Impostazioni e diagnostica](#10-impostazioni-e-diagnostica)
11. [Funzioni non portabili](#11-funzioni-non-portabili)

---

## 1. Account e sessione

**Accesso con Google/YouTube Music.** Al primo avvio clicchi **Accedi**: l'app apre un profilo Chrome dedicato, completa il login e salva i cookie in un jar locale. Le sessioni successive non richiedono alcuna azione.

**Cosa viene salvato:** cookie di autenticazione, visitor id, preferenze, cronologia di ascolto, playlist create, token PoToken in cache (12 ore). Tutto resta sul tuo computer.

**Sign-out.** Da **Impostazioni → Account** puoi disconnetterti. I dati locali (download, preferenze) restano, ma la libreria online non è più accessibile finché non accedi di nuovo.

**Brani con limite d'età.** Se un brano è age-restricted, l'app:

1. legge il `signatureTimestamp` reale dal sito YouTube;
2. manda la richiesta `/player` con il contesto YouTube Music autenticato e i flag mobile (`videoCheckOk`, `html5Preference`);
3. riceve i formati cifrati (`signatureCipher`) e li decifra con il player JS, usando Node.js;
4. applica `pot=` e `cpn=` all'URL del media e avvia la riproduzione **direttamente in app**.

Nessuna finestra del browser si apre. Vedi [`AGE_GATE.md`](AGE_GATE.md).

---

## 2. Libreria, playlist e ricerca

**Libreria.** Sei filtri: brani, album, artisti, playlist, podcast, download. La vista è la stessa dell'app Android, con copertine, ordinamenti e ricerca interna.

**Playlist.** Apri una playlist e tocca un brano: **l'intera playlist diventa la coda di riproduzione**, partendo dal brano toccato. Puoi riordinare, rimuovere e salvare modifiche.

**Ricerca.** Cerca simultaneamente nella libreria online e nei file locali. I risultati sono divisi per tipo (brani, album, artisti, playlist, utenti).

**Playlist intelligenti.** EchoBrain genera playlist automatiche; Music Flow offre 7 toggle per personalizzare il feed.

**Coda persistente.** La coda viene salvata: se chiudi e riapri l'app, riprendi da dove eri.

---

## 3. Riproduzione e player

**Motore audio.** Il player usa media_kit/mpv con una catena DSP dedicata. Supporta MP3, M4A, FLAC, OGG, OPUS e file locali.

**Tre layout.** Il player si adatta alla dimensione della finestra: compatto, normale e esteso, con controlli e copertine ridimensionati.

**Controlli.** Play/pausa, avanti/indietro, shuffle, repeat, volume, preferiti, coda, testi, commenti, opzioni. Il mini-player in basso mostra copertina, titolo scorrevole (marquee) e controlli essenziali con effetto vetro.

**7 background.** Il player può usare sette diversi sfondi animati, con palette colori estratta dalla copertina.

**Micro-effetti.** Slider ondulati,HeartBurst quando metti un like, shimmer nei caricamenti, EQ circolare e transizioni fluide.

**Sorgente audio.** Un'etichetta mostra sempre sorgente e codec (es. `WEB_REMIX · Opus 160 kbps`, `FLAC monochrome`, `File locale`).

---

## 4. Automix e crossfade

L'Automix è il sistema che rende fluido il passaggio tra brani, ispirato a Echo Android.

**Crossfade.** Quando il brano corrente sta per finire, l'app inizia il fade con il successivo. La durata è configurabile; in modalità Automix viene usato un DJ blend di 16 beat (tra 4 e 15 secondi).

**Pre-arm adattivo.** Il player di standby viene preparato **20 secondi prima** (fino a 35 se la preparazione è lenta), non dentro la finestra di fade. Questo elimina il blocco a metà transizione.

**Handoff a 220 ms.** Prima del crossfade vero, l'audio passa dal player principale a quello di standby con una rampa a potenza costante di 220 ms. Nessuno scatto di volume.

**Analisi beat.** Per ogni brano vengono calcolati BPM, fase del beat e chiave musicale tramite FFT e spectral flux. L'analisi viene cachesata.

**Mix-in / mix-out dinamici.** L'intro e la coda del brano vengono analizzati energeticamente per trovare il punto ideale di ingresso e uscita, invece di usare valori fissi.

**Beat-matching.** L'offset di ingresso del brano successivo viene scelto in modo che un suo beat cada esattamente alla fine del fade.

**Ducking.** La traccia in uscita viene attenuata sulle basse frequenze per evitare che i due bassi si sovrappongano.

**Mixing armonico.** La chiave viene convertita nella ruota Camelot (1A–12A / 1B–12B) e usata per scegliere il brano successivo tra i primi tre della coda.

**Diagnostica.** In **Impostazioni → Riproduttore → Diagnostica Automix** vedi stato, lead, trigger, volumi, BPM in/out, chiave e il log degli eventi. Puoi anche mostrare un overlay direttamente nel player.

Vedi [`AUTOMIX.md`](AUTOMIX.md) e [`CROSSFADE.md`](CROSSFADE.md).

---

## 5. Testi, EQ e DSP

**Lyrics.** Dodici provider diversi, sincronizzazione parola per parola, traduzione e visualizzazione stabile senza sfarfallii durante il resize.

**Equalizzatore.** 10 bande con preset, ricerca AutoEq e pagina Axion.

**DSP.** Catena di filtri con guadagno, normalizzazione del volume in base alla loudness del brano e opzioni Mono/Stereo.

**Sleep timer.** Interrompi la riproduzione dopo un tempo impostato o alla fine del brano.

---

## 6. Download, export e formati

**Download offline.** Scarica brani e playlist per ascoltarli senza connessione.

**Export MP3.** Converte i file locali o scaricati in MP3 con tag ID3v2.3 e copertina incorporata. L'operazione è sicura: scrive prima un file `.part` e lo rinomina solo a fine riuscita. Puoi annullare e riprovare.

**FLAC Monochrome.** Opzione per sorgenti FLAC in bianco e nero, con fallback automatico a YouTube e priorità Data Saver.

**Limite.** L'export supporta file locali e già scaricati; non converte direttamente uno stream in riproduzione.

---

## 7. Scoperta e funzioni sociali

**Explore.** Sezioni scopribili, nuove uscite, classifiche e mix.

**Podcast.** Accesso ai podcast di YouTube Music.

**Commenti.** Apri i commenti di un brano dal player: autore, avatar, testo, like e risposte, esattamente come sull'app Android. La scrittura di commenti non è prevista nemmeno nel reference.

**Riconoscimento brani ("Echo Find").** Registra 8 secondi dal microfono, calcola un'impronta spettrale e la confronta con la tua libreria indicizzata. Funziona offline, senza API a pagamento. Devi prima indicizzare i brani locali dal pulsante **Indicizza la libreria**; il risultato mostra titolo, artista e percentuale di match, con pulsante **Riproduci**.

---

## 8. Wrapped

**Wrapped di YouTube Music** usa la tua cronologia reale (`FEmusic_history`), non dati locali.

Nove slide animate in stile Android:

1. Copertina e introduzione;
2. Minuti totali ascoltati (stimati dalle durate dei brani);
3. Artisti più ascoltati;
4. Brani più ascoltati;
5. Generi predominanti;
6. Radari di ascolto;
7. Barre EQ animate;
8. Poster recap colorato (5 colori selezionabili);
9. Chiusura e condivisione.

Ogni slide resta 8,5 secondi con barra di avanzamento. Se l'account non ha cronologia, viene mostrato uno stato vuoto esplicito.

---

## 9. Cast, remote e dispositivi

**Cast.** Scopre Chromecast e smart TV via mDNS e DIAL, apre il selettore e avvia la riproduzione direttamente sul dispositivo con il protocollo CastV2.

**Controllo remoto.** Un server di controllo in locale permette di gestire la riproduzione da un altro dispositivo della stessa rete.

**Device link.** Collega due istanze per sincronizzare azioni e stato.

---

## 10. Impostazioni e diagnostica

Quindici voci di impostazioni, uguali all'app Android, con **ricerca globale** nel campo in alto. Le opzioni non applicabili su Windows sono mostrate come segnaposto espliciti, non nascoste.

Le sezioni principali sono: Account, Aspetto, Riproduttore, Contenuti, Music Flow, Rete, Aggiornamenti, Info.

**Diagnostica Automix** e **modalità diagnostica** (`ECHO_DIAG=1`) permettono di ispezionare lo stato interno dell'app tramite un server locale.

---

## 11. Funzioni non portabili

Alcune funzioni dell'app Android non hanno un equivalente Windows e sono dichiarate come non portabili nella matrice di parità:

- widget della home screen;
- notifica media e riquadro Quick Settings di Android;
- feedback aptico;
- suonerie;
- output USB bit-perfect;
- palette Material You derivata dal wallpaper di sistema;
- rifrazione reale `RenderEffect`.

Tutto il resto — **48 funzioni su 48** — è implementato. Vedi [`PARITY_MATRIX.md`](PARITY_MATRIX.md).
