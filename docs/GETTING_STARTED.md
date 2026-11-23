# Primi passi

Guida pratica per installare, configurare e usare Echo Music Desktop.

## 1. Installazione

### Installer (consigliato)

1. Vai alla [pagina Releases](https://github.com/ItsZale0/Echo-Music-Desktop/releases/latest).
2. Scarica **`EchoMusicSetup.exe`**.
3. Esegui il file. La procedura guidata è in italiano e inglese.
4. Scegli se installare le scorciatoie (Desktop e Menu Start) e completa.
5. Avvia **Echo Music** dal Menu Start.

L'installer crea anche un disinstallatore, accessibile da **Installazione applicazioni**.

### Versione portatile

1. Scarica **`EchoMusicPortable.zip`**.
2. Estrai tutto in una cartella, ad esempio `C:\EchoMusic`.
3. Avvia `echo.exe` dalla cartella.

La versione portatile non modifica il registro e può essere copiata su un'altra macchina.

## 2. Accesso al tuo account

1. All'avvio clicca **Accedi**.
2. Si apre una finestra Chrome con un profilo dedicato. Accedi con il tuo account Google associato a YouTube Music.
3. Se richiesto, conferma i permessi. Dopo qualche secondo l'app rileva la sessione e carica libreria, cronologia e playlist.

I cookie vengono salvati localmente: alle aperture successive non devi rifare il login.

> **Nota:** se usi la verifica in due passaggi, completala normalmente nella finestra Chrome. L'app non la richiede direttamente.

## 3. Ascoltare la tua musica

- Clicca un brano nella **Home** o nella **Libreria**: inizia subito la riproduzione.
- Se apri una **playlist** e tocchi un brano, l'intera playlist diventa la coda, a partire da quel brano.
- Usa il **mini-player** in basso per play/pausa e controlli rapidi; clicca la copertina per aprire il player completo.
- Nel player trovi: testi, commenti, coda, preferiti e opzioni avanzate.

## 4. Brani con limite d'età

Se un brano è age-restricted, l'app lo riproduce automaticamente in-app, senza aprire il browser. Il sistema:

- legge il `signatureTimestamp` reale da YouTube;
- invia una richiesta `/player` con il contesto YouTube Music autenticato;
- decifra i formati `signatureCipher` con il player JS;
- applica i token `pot=` e `cpn=` all'URL audio.

Se il tuo account non è verificato come maggiorenne, YouTube può ancora rifiutare la riproduzione: in quel caso devi completare la verifica dell'età **sull'account Google**, non è aggirabile dal client. Vedi [`AGE_GATE.md`](AGE_GATE.md).

## 5. Automix e crossfade

1. Vai su **Impostazioni → Riproduttore**.
2. Abilita **Crossfade** e scegli la durata, oppure lascia che Automix usi un DJ blend di 16 beat.
3. Attiva **Allinea al beat** e **Mixing armonico** per transizioni musicali coerenti.
4. Avvia una playlist e ascolta: il passaggio tra brani avviene senza interruzioni.

Per vedere cosa succede, apri **Diagnostica Automix**: stato, lead, trigger, BPM, chiave e log degli eventi.

## 6. Testi, EQ e download

- **Testi**: clicca l'icona dei testi nel player. Puoi scegliere il provider e la traduzione.
- **EQ**: **Impostazioni → Riproduttore → Equalizzatore**. Regola le 10 bande o carica un preset AutoEq.
- **Download**: dal menu di un brano o di una playlist scegli **Scarica**. I file restano disponibili offline.
- **Export MP3**: **Impostazioni → Strumenti → Export MP3**. Seleziona i file locali o scaricati; la copertina viene inclusa.

## 7. Wrapped

Apri **Wrapped** dalla Home o dal menu. Vengono mostrate 9 slide con i tuoi dati reali di YouTube Music. Usa i pulsanti per navigare o lascia che avanzino automaticamente ogni 8,5 secondi.

## 8. Commenti e riconoscimento brani

- **Commenti**: clicca l'icona commenti nel player (serve che l'opzione "Mostra pulsante commenti" sia attiva in Impostazioni → Aspetto).
- **Riconoscimento brani**: apri **Impostazioni → Riconoscimento brani**, clicca **Indicizza la libreria** e attendi la fine. Poi clicca il microfono: l'app registra 8 secondi, calcola l'impronta e cerca un match tra i brani indicizzati.

Il riconoscimento funziona **solo offline sulla tua libreria**: non identifica brani qualunque, ma solo quelli che hai indicizzato.

## 9. Cast

Clicca l'icona Cast nel player. L'app cerca dispositivi sulla rete (mDNS + DIAL). Seleziona la TV o il Chromecast: l'audio viene riprodotto direttamente sul dispositivo.

## 10. Risoluzione problemi

| Sintomo | Cosa fare |
|---|---|
| Il brano non parte | Controlla la connessione e che l'account sia ancora valido. Vedi il log in `%LOCALAPPDATA%\com.echo\Echo Music\error.log`. |
| Un brano age-gated non si sente | Verifica che l'account Google sia age-verified. |
| Automix non parte | Apri Diagnostica Automix e controlla che crossfade e automix siano attivi. |
| Lyrics non caricano | Prova un altro provider nelle impostazioni dei testi. |
| L'app non si apre | Reinstalla usando l'ultimo installer; i dati locali vengono mantenuti. |

Per segnalazioni, apri una issue su [GitHub](https://github.com/ItsZale0/Echo-Music-Desktop/issues).
