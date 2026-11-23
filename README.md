<div align="center">
  <img src="assets/Echo_github.png" alt="Echo Music Logo" width="140"/>
  <h1>Echo Music Desktop</h1>
  <p><strong>Il tuo music player completo su Windows.</strong></p>
  <p>Streaming da YouTube Music senza pubblicità, ascolto offline, Automix intelligente e un'interfaccia curata in ogni dettaglio.</p>

  <a href="https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest"><img src="assets/Windows-button.png" alt="Scarica per Windows" width="170"/></a>
</div>

---

## Cos'è

Echo Music Desktop è il port nativo per Windows di [Echo Music](https://github.com/EchoMusicApp/Echo-Music), l'app Android per YouTube Music. Non è un wrapper del browser: è un client Flutter che si collega al tuo account YouTube Music, riproduce l'audio attraverso un motore dedicato e offre funzioni che l'app web non ha.

**Stato:** parità completa con l'app Android — **48/48 funzioni** (`docs/PARITY_MATRIX.md`).

**Piattaforme:** Windows x64. macOS e Linux non sono supportati in questa release.

**Licenza:** GPL-3.0.

---

## Funzioni in evidenza

### Ascolto
- **Streaming senza pubblicità** dalla tua libreria YouTube Music, con la qualità migliore disponibile.
- **Brani con limite d'età** riproducibili grazie al port del workaround Android (PoToken BotGuard + `signatureTimestamp` reale + decifratura `signatureCipher`). Nessuna finestra del browser si apre durante la riproduzione.
- **Download e ascolto offline**, con export MP3 reale (ID3v2.3, copertina inclusa) e opzione FLAC Monochrome con fallback YouTube e priorità Data Saver.
- **Sorgente e codec sempre visibili**, così sai cosa stai ascoltando.

### Scoperta e organizzazione
- **Home personalizzabile** con sezioni configurabili.
- **Ricerca** online e nella libreria locale, con filtri.
- **Playlist e code**: toccare un brano imposta l'intera playlist come coda, partendo dal brano scelto.
- **Explore**, **podcast**, **Music Flow** con 7 toggle, **cronologia** e **brani piaciuti**.

### Automix e crossfade
- **Crossfade adattivo** con pre-arm da 20 a 35 secondi e handoff a 220 ms senza scatti.
- **Analisi beat** (BPM, fase, chiave) e **mix-in/mix-out** dinamici calcolati sull'energia dell'audio.
- **Beat-matching** e **DJ blend di 16 beat** con ducking della traccia in uscita.
- **Mixing armonico** con ruota Camelot: sceglie il brano successivo tra i primi 3 della coda in base alla compatibilità della chiave.
- **Diagnostica Automix** integrata, con stato, volumi, BPM e log degli eventi.

### Testi e suono
- **12 provider di lyrics**, sincronizzazione parola per parola e traduzione.
- **Equalizzatore a 10 bande**, AutoEq, preset Axion e **DSP** con controllo del guadagno.
- **Normalizzazione del volume** basata sulla loudness del brano.

### Esperienza
- **Wrapped in stile YouTube Music**: 9 slide animate con i tuoi dati reali di ascolto (`FEmusic_history`), temi, radar, EQ e poster colorati.
- **Commenti YouTube** sui brani, con autore, avatar, like e risposte.
- **Riconoscimento brani offline**: registra dal microfono, calcola un'impronta spettrale e la confronta con la tua libreria indicizzata. Nessuna API a pagamento.
- **Cast DirectV2** verso Chromecast e smart TV (mDNS + DIAL).
- **7 background del player**, font Android, vetro EchoGlass, slider ondulati, HeartBurst, marquee, shimmer, EQ circolare e palette ambient.
- **Sleep timer**, **SponsorBlock**, **comandi remote**, **device link** e impostazioni con ricerca globale.

La guida completa è in [`docs/FEATURES.md`](docs/FEATURES.md); per iniziare vedi [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

---

## Installazione

### Windows (consigliato)
1. Scarica `EchoMusicSetup.exe` dalla [pagina Releases](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest).
2. Esegui l'installer: è una procedura guidata reale in italiano e inglese, con licensing GPL-3.0, scorciatoia sul Desktop, voce nel Menu Start e disinstallatore.
3. Avvia Echo Music dal Menu Start o dalla scorciatoia.

### Portabile (senza installazione)
1. Scarica `EchoMusicPortable.zip` dalla [pagina Releases](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest).
2. Estrai l'archivio in una cartella a tua scelta.
3. Avvia `echo.exe`. Nessuna installazione, nessuna scrittura nel registro.

### Aggiornamento
Scarica il nuovo installer ed eseguilo: sovrascrive la versione precedente mantenendo i dati (account, preferenze, cronologia). L'archivio portatile va estratto in una nuova cartella.

---

## Primo avvio

1. Clicca **Accedi** e completa il login con il tuo account Google/YouTube Music. Viene usato un profilo Chrome dedicato e i cookie vengono salvati in modo sicuro.
2. Dopo il login la libreria, la cronologia e le playlist vengono caricate.
3. Premi un brano per iniziare l'ascolto. Tocca l'icona del player per aprire i controlli completi, i testi e l'Automix.

Per i dettagli, inclusi i brani con limite d'età e il riconoscimento brani, leggi [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md).

---

## Compilare da sorgente

Serve Flutter con il supporto Windows abilitato.

```bash
git clone https://github.com/ItsZale0/Echo-Music-Desktop.git
cd Echo-Music-Desktop
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

Build di produzione:

```bash
flutter build windows --release
```

L'installer Inno Setup si genera con lo script in `installer/EchoMusic.iss`. La verifica completa è:

```bash
flutter analyze
flutter test
tool/verify.ps1
```

---

## Documentazione

| Documento | Contenuto |
|---|---|
| [`docs/FEATURES.md`](docs/FEATURES.md) | Tutte le funzioni dell'app, spiegate per uso |
| [`docs/GETTING_STARTED.md`](docs/GETTING_STARTED.md) | Installazione, login e primi passi |
| [`docs/PARITY_MATRIX.md`](docs/PARITY_MATRIX.md) | Matrice di parità Android → Desktop (48/48) |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Architettura tecnica e componenti |
| [`docs/AGE_GATE.md`](docs/AGE_GATE.md) | Come funziona la riproduzione dei brani age-gated |
| [`docs/AUTOMIX.md`](docs/AUTOMIX.md) | Beat analysis, DJ blend e mixing armonico |
| [`docs/CROSSFADE.md`](docs/CROSSFADE.md) | Pre-arm adattivo, handoff e curva di fade |
| [`docs/MP3_EXPORT.md`](docs/MP3_EXPORT.md) | Export MP3 con copertina |
| [`docs/MONOCHROME_FLAC.md`](docs/MONOCHROME_FLAC.md) | FLAC monochrome e fallback |
| [`docs/PORTING_PLAN.md`](docs/PORTING_PLAN.md) | Piano di port storico e dettagli di implementazione |

---

## Community e supporto

Per segnalazioni e richieste apri una issue nel repository. Il progetto originale Android è [EchoMusicApp/Echo-Music](https://github.com/EchoMusicApp/Echo-Music).

<div align="center">
    Realizzato con Flutter. Licenziato sotto <a href="LICENSE">GPL-3.0</a>.
</div>
