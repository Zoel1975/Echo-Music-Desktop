// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a it locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'it';

  static String m0(count) => "In coda (${count})";

  static String m1(count) =>
      "${Intl.plural(count, zero: 'Nessun brano', one: '1 brano', other: '${count} brani')}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "About": MessageLookupByLibrary.simpleMessage("Informazioni"),
    "Add_To_Favourites": MessageLookupByLibrary.simpleMessage(
      "Aggiungi ai preferiti",
    ),
    "Add_To_Library": MessageLookupByLibrary.simpleMessage(
      "Aggiungi alla libreria",
    ),
    "Add_To_Playlist": MessageLookupByLibrary.simpleMessage(
      "Aggiungi alla playlist",
    ),
    "Add_To_Queue": MessageLookupByLibrary.simpleMessage("Aggiungi alla coda"),
    "Album": MessageLookupByLibrary.simpleMessage("Album"),
    "Albums": MessageLookupByLibrary.simpleMessage("Album"),
    "App_Folder": MessageLookupByLibrary.simpleMessage("Cartella App"),
    "Appearence": MessageLookupByLibrary.simpleMessage("Aspetto"),
    "Artists": MessageLookupByLibrary.simpleMessage("Artisti"),
    "Audio_And_Playback": MessageLookupByLibrary.simpleMessage(
      "Audio e riproduzione",
    ),
    "Autofetch_Songs": MessageLookupByLibrary.simpleMessage(
      "Riproduci automaticamente brani simili",
    ),
    "Backup": MessageLookupByLibrary.simpleMessage("Backup"),
    "Backup_And_Restore": MessageLookupByLibrary.simpleMessage(
      "Backup e ripristino",
    ),
    "Backup_Failed": MessageLookupByLibrary.simpleMessage(
      "Salvataggio dati non riuscito",
    ),
    "Backup_Success": MessageLookupByLibrary.simpleMessage(
      "Salvataggio dati riuscito al percorso",
    ),
    "Battery_Optimisation_message": MessageLookupByLibrary.simpleMessage(
      "Clicca qui per disattivare l’ottimizzazione della batteria e permettere a Echo di funzionare correttamente",
    ),
    "Battery_Optimisation_title": MessageLookupByLibrary.simpleMessage(
      "Ottimizzazione batteria rilevata",
    ),
    "Bug_Report": MessageLookupByLibrary.simpleMessage("Segnala un bug"),
    "Buy_Me_A_Coffee": MessageLookupByLibrary.simpleMessage("Offrimi un caffè"),
    "Cancel": MessageLookupByLibrary.simpleMessage("Annulla"),
    "Check_For_Update": MessageLookupByLibrary.simpleMessage(
      "Verifica aggiornamenti",
    ),
    "Confirm": MessageLookupByLibrary.simpleMessage("Conferma"),
    "Confirm_Delete_All_Message": MessageLookupByLibrary.simpleMessage(
      "Sei sicuro di volerli eliminare?",
    ),
    "Content": MessageLookupByLibrary.simpleMessage("Contenuti"),
    "Contributors": MessageLookupByLibrary.simpleMessage("Collaboratori"),
    "Copied_To_Clipboard": MessageLookupByLibrary.simpleMessage(
      "Copiato negli appunti",
    ),
    "Country": MessageLookupByLibrary.simpleMessage("Paese"),
    "Create": MessageLookupByLibrary.simpleMessage("Crea"),
    "Create_Playlist": MessageLookupByLibrary.simpleMessage("Crea playlist"),
    "DOwnload_Quality": MessageLookupByLibrary.simpleMessage(
      "Qualità download",
    ),
    "Delete_All_Songs": MessageLookupByLibrary.simpleMessage(
      "Elimina tutti i brani",
    ),
    "Delete_Item_Message": MessageLookupByLibrary.simpleMessage(
      "Sei sicuro di voler eliminare questo elemento?",
    ),
    "Delete_Playback_History": MessageLookupByLibrary.simpleMessage(
      "Elimina cronologia di riproduzione",
    ),
    "Delete_Playback_History_Confirm_Message":
        MessageLookupByLibrary.simpleMessage(
          "Sei sicuro di voler eliminare la cronologia di riproduzione?",
        ),
    "Delete_Search_History": MessageLookupByLibrary.simpleMessage(
      "Elimina cronologia di ricerca",
    ),
    "Delete_Search_History_Confirm_Message":
        MessageLookupByLibrary.simpleMessage(
          "Sei sicuro di voler eliminare la cronologia di ricerca?",
        ),
    "Deleting_Songs": MessageLookupByLibrary.simpleMessage(
      "Eliminazione brani...",
    ),
    "Developer": MessageLookupByLibrary.simpleMessage("Sviluppatore"),
    "Donate": MessageLookupByLibrary.simpleMessage("Dona"),
    "Donate_Message": MessageLookupByLibrary.simpleMessage(
      "Supporta lo sviluppo di Echo",
    ),
    "Done": MessageLookupByLibrary.simpleMessage("Fatto"),
    "Download": MessageLookupByLibrary.simpleMessage("Download"),
    "Download_Started": MessageLookupByLibrary.simpleMessage(
      "Download avviato...",
    ),
    "Downloading": MessageLookupByLibrary.simpleMessage("In download"),
    "Downloads": MessageLookupByLibrary.simpleMessage("Download"),
    "Dynamic_Colors": MessageLookupByLibrary.simpleMessage("Colori dinamici"),
    "Enable_Equalizer": MessageLookupByLibrary.simpleMessage(
      "Abilita equalizzatore",
    ),
    "Enable_Playback_History": MessageLookupByLibrary.simpleMessage(
      "Abilita cronologia di riproduzione",
    ),
    "Enable_Search_History": MessageLookupByLibrary.simpleMessage(
      "Abilita cronologia di ricerca",
    ),
    "Enter_Visitor_Id": MessageLookupByLibrary.simpleMessage(
      "Inserisci Visitor ID",
    ),
    "Equalizer": MessageLookupByLibrary.simpleMessage("Equalizzatore"),
    "Favourites": MessageLookupByLibrary.simpleMessage("Preferiti"),
    "Feature_Request": MessageLookupByLibrary.simpleMessage(
      "Richiesta funzionalità",
    ),
    "FileNotFound": MessageLookupByLibrary.simpleMessage("File non trovato"),
    "Go_To_Downloads": MessageLookupByLibrary.simpleMessage("Vai a Download"),
    "Google_Account": MessageLookupByLibrary.simpleMessage("Account Google"),
    "Echo": MessageLookupByLibrary.simpleMessage("Echo"),
    "High": MessageLookupByLibrary.simpleMessage("Alta"),
    "History": MessageLookupByLibrary.simpleMessage("Cronologia"),
    "Home": MessageLookupByLibrary.simpleMessage("Home"),
    "Import": MessageLookupByLibrary.simpleMessage("Importa"),
    "Import_Playlist": MessageLookupByLibrary.simpleMessage("Importa playlist"),
    "In_Progress": MessageLookupByLibrary.simpleMessage("In corso"),
    "Jhelum_Corp": MessageLookupByLibrary.simpleMessage("Jhelum Corp"),
    "Language": MessageLookupByLibrary.simpleMessage("Lingua"),
    "Loudness_And_Equalizer": MessageLookupByLibrary.simpleMessage(
      "Volume ed equalizzatore",
    ),
    "Loudness_Enhancer": MessageLookupByLibrary.simpleMessage(
      "Amplificatore volume",
    ),
    "Low": MessageLookupByLibrary.simpleMessage("Bassa"),
    "Made_In_Kashmir": MessageLookupByLibrary.simpleMessage(
      "Realizzato in Kashmir",
    ),
    "Name": MessageLookupByLibrary.simpleMessage("Nome"),
    "Next_Up": MessageLookupByLibrary.simpleMessage("Prossimo"),
    "No": MessageLookupByLibrary.simpleMessage("No"),
    "No_Internet_Connection": MessageLookupByLibrary.simpleMessage(
      "Nessuna Connessione Internet",
    ),
    "Organisation": MessageLookupByLibrary.simpleMessage("Organizzazione"),
    "Pay_With_UPI": MessageLookupByLibrary.simpleMessage("Paga con UPI"),
    "Payment_Methods": MessageLookupByLibrary.simpleMessage(
      "Metodi di pagamento",
    ),
    "Personalised_Content": MessageLookupByLibrary.simpleMessage(
      "Contenuti personalizzati",
    ),
    "Play_Next": MessageLookupByLibrary.simpleMessage("Riproduci dopo"),
    "Playback_History_Deleted": MessageLookupByLibrary.simpleMessage(
      "Cronologia di riproduzione eliminata",
    ),
    "Playlist_Name": MessageLookupByLibrary.simpleMessage("Nome playlist"),
    "Playlist_Not_Available": MessageLookupByLibrary.simpleMessage(
      "Playlist non disponibile",
    ),
    "Playlists": MessageLookupByLibrary.simpleMessage("Playlist"),
    "Progress": MessageLookupByLibrary.simpleMessage("Avanzamento"),
    "Queued": MessageLookupByLibrary.simpleMessage("In coda"),
    "QueuedCount": m0,
    "Remove": MessageLookupByLibrary.simpleMessage("Rimuovi"),
    "Remove_All_History_Message": MessageLookupByLibrary.simpleMessage(
      "Sei sicuro di voler cancellare tutta la cronologia?",
    ),
    "Remove_From_Favourites": MessageLookupByLibrary.simpleMessage(
      "Rimuovi dai preferiti",
    ),
    "Remove_From_Library": MessageLookupByLibrary.simpleMessage(
      "Rimuovi dalla libreria",
    ),
    "Remove_From_YTMusic_Message": MessageLookupByLibrary.simpleMessage(
      "Sei sicuro di volerlo rimuovere da YTMusic?",
    ),
    "Remove_Message": MessageLookupByLibrary.simpleMessage(
      "Sei sicuro di volerlo rimuovere?",
    ),
    "Rename": MessageLookupByLibrary.simpleMessage("Rinomina"),
    "Rename_Playlist": MessageLookupByLibrary.simpleMessage(
      "Rinomina playlist",
    ),
    "Reset_Visitor_Id": MessageLookupByLibrary.simpleMessage(
      "Reimposta Visitor ID",
    ),
    "Restore": MessageLookupByLibrary.simpleMessage("Ripristina"),
    "Restore_Failed": MessageLookupByLibrary.simpleMessage(
      "Ripristino dati non riuscito",
    ),
    "Restore_Missing_Songs": MessageLookupByLibrary.simpleMessage(
      "Ripristina brani mancanti",
    ),
    "Restore_Success": MessageLookupByLibrary.simpleMessage(
      "Ripristino dati riuscito",
    ),
    "Restoring_Missing_Songs": MessageLookupByLibrary.simpleMessage(
      "Ripristino brani mancanti...",
    ),
    "Retry": MessageLookupByLibrary.simpleMessage("Riprova"),
    "Save": MessageLookupByLibrary.simpleMessage("Salva"),
    "Saved": MessageLookupByLibrary.simpleMessage("Salvati"),
    "Search_Echo": MessageLookupByLibrary.simpleMessage("Cerca in Echo"),
    "Search_History_Deleted": MessageLookupByLibrary.simpleMessage(
      "Cronologia di ricerca eliminata",
    ),
    "Search_Settings": MessageLookupByLibrary.simpleMessage(
      "Impostazioni di ricerca",
    ),
    "Select_Backup": MessageLookupByLibrary.simpleMessage("Seleziona backup"),
    "Settings": MessageLookupByLibrary.simpleMessage("Impostazioni"),
    "Share": MessageLookupByLibrary.simpleMessage("Condividi"),
    "Sheikh_Haziq": MessageLookupByLibrary.simpleMessage("Sheikh Haziq"),
    "Show_Less": MessageLookupByLibrary.simpleMessage("Mostra meno"),
    "Show_More": MessageLookupByLibrary.simpleMessage("Mostra di più"),
    "Shuffle": MessageLookupByLibrary.simpleMessage("Casuale"),
    "Skip_Silence": MessageLookupByLibrary.simpleMessage("Salta silenzi"),
    "Sleep_Timer": MessageLookupByLibrary.simpleMessage("Timer di spegnimento"),
    "Songs": MessageLookupByLibrary.simpleMessage("Brani"),
    "Songs_Will_Start_Playing_Soon": MessageLookupByLibrary.simpleMessage(
      "La riproduzione dei brani inizierà a breve.",
    ),
    "Source_Code": MessageLookupByLibrary.simpleMessage("Codice sorgente"),
    "Start_Radio": MessageLookupByLibrary.simpleMessage("Avvia radio"),
    "Streaming_Quality": MessageLookupByLibrary.simpleMessage(
      "Qualità streaming",
    ),
    "Subscriptions": MessageLookupByLibrary.simpleMessage("Iscrizioni"),
    "Support_Me_On_Kofi": MessageLookupByLibrary.simpleMessage(
      "Supportami su Ko-fi",
    ),
    "Telegram": MessageLookupByLibrary.simpleMessage("Telegram"),
    "Theme_Mode": MessageLookupByLibrary.simpleMessage("Tema"),
    "Translate_Lyrics": MessageLookupByLibrary.simpleMessage("Traduci testi"),
    "Version": MessageLookupByLibrary.simpleMessage("Versione"),
    "Visitor_Id": MessageLookupByLibrary.simpleMessage("Visitor ID"),
    "Window_Effect": MessageLookupByLibrary.simpleMessage("Effetto finestra"),
    "YTMusic": MessageLookupByLibrary.simpleMessage("YTMusic"),
    "Yes": MessageLookupByLibrary.simpleMessage("Sì"),
    "nSongs": m1,
    "M10BandeApplicateAlFiltroAudio": MessageLookupByLibrary.simpleMessage("10 bande applicate al filtro audio"),
    "AILyricsTranslation": MessageLookupByLibrary.simpleMessage("Testi e traduzione AI"),
    "AIPoweredLyricsAndTranslations": MessageLookupByLibrary.simpleMessage("Testi e traduzioni con AI"),
    "APICredentials": MessageLookupByLibrary.simpleMessage("Credenziali API"),
    "APIKey": MessageLookupByLibrary.simpleMessage("Chiave API"),
    "AXIONAutoEqEngine": MessageLookupByLibrary.simpleMessage("Motore AXION / AutoEq"),
    "AXIONAutoEqEqualizer": MessageLookupByLibrary.simpleMessage("Equalizzatore AXION / AutoEq"),
    "AccentColor": MessageLookupByLibrary.simpleMessage("Colore accento"),
    "Account": MessageLookupByLibrary.simpleMessage("Account"),
    "Add5ExtraSecondsOnEachSeek": MessageLookupByLibrary.simpleMessage("Aggiungi 5 secondi extra a ogni salto"),
    "AddSimilarSongsAtTheEndOfTheQueue": MessageLookupByLibrary.simpleMessage("Aggiungi brani simili alla fine della coda"),
    "AddSongsWhenTheQueueRunsLow": MessageLookupByLibrary.simpleMessage("Aggiungi brani quando la coda è quasi vuota"),
    "AdvancedPlayback": MessageLookupByLibrary.simpleMessage("Riproduzione avanzata"),
    "AmoledBlack": MessageLookupByLibrary.simpleMessage("Nero AMOLED"),
    "Annulla": MessageLookupByLibrary.simpleMessage("Annulla"),
    "AppInfoAndLicenses": MessageLookupByLibrary.simpleMessage("Info app e licenze"),
    "AppearanceExtras": MessageLookupByLibrary.simpleMessage("Extra aspetto"),
    "ApriCartellaExport": MessageLookupByLibrary.simpleMessage("Apri cartella export"),
    "AudioNormalization": MessageLookupByLibrary.simpleMessage("Normalizzazione audio"),
    "AudioOutput": MessageLookupByLibrary.simpleMessage("Uscita audio"),
    "AudioProcessing": MessageLookupByLibrary.simpleMessage("Elaborazione audio"),
    "AudioQualityCeilingOverWiFiNetwork": MessageLookupByLibrary.simpleMessage("Qualità audio massima su Wi-Fi / rete"),
    "AutoDownloadOnLike": MessageLookupByLibrary.simpleMessage("Scarica automaticamente con Mi piace"),
    "AutoLoadMoreSongs": MessageLookupByLibrary.simpleMessage("Carica altri brani automaticamente"),
    "AutoPlaylists": MessageLookupByLibrary.simpleMessage("Playlist automatiche"),
    "AutoScrollLyrics": MessageLookupByLibrary.simpleMessage("Scorrimento automatico testi"),
    "AutoSkipToNextSongOnError": MessageLookupByLibrary.simpleMessage("Salta al brano successivo in caso di errore"),
    "AutomixAllineaAlBeat": MessageLookupByLibrary.simpleMessage("Automix · allinea al beat"),
    "AutomixMixingArmonico": MessageLookupByLibrary.simpleMessage("Automix · mixing armonico"),
    "BackgroundExportTaskQueue": MessageLookupByLibrary.simpleMessage("Coda di esportazione in background"),
    "BaseURL": MessageLookupByLibrary.simpleMessage("URL di base"),
    "BitPerfectUSBDACOutput": MessageLookupByLibrary.simpleMessage("Uscita USB DAC bit-perfect"),
    "BlendTheEndOfASongIntoTheNext": MessageLookupByLibrary.simpleMessage("Fonde la fine di un brano nel successivo"),
    "BlockedArtists": MessageLookupByLibrary.simpleMessage("Artisti bloccati"),
    "CacheAndDownloads": MessageLookupByLibrary.simpleMessage("Cache e download"),
    "CacheTheNextSongForGaplessPlayback": MessageLookupByLibrary.simpleMessage("Memorizza il brano successivo per riproduzione senza pause"),
    "CanvasAmbientMode": MessageLookupByLibrary.simpleMessage("Modalità Canvas e Ambient"),
    "CastRemoteControl": MessageLookupByLibrary.simpleMessage("Cast e controllo remoto"),
    "ClearAll": MessageLookupByLibrary.simpleMessage("Cancella tutto"),
    "ClearImageCache": MessageLookupByLibrary.simpleMessage("Cancella cache immagini"),
    "ClearSongCache": MessageLookupByLibrary.simpleMessage("Cancella cache brani"),
    "ComingInAFutureUpdate": MessageLookupByLibrary.simpleMessage("Disponibile in un futuro aggiornamento"),
    "Configure": MessageLookupByLibrary.simpleMessage("Configura"),
    "Crossfade": MessageLookupByLibrary.simpleMessage("Crossfade"),
    "DataSaver": MessageLookupByLibrary.simpleMessage("Risparmio dati"),
    "DefaultContentCountry": MessageLookupByLibrary.simpleMessage("Paese contenuti predefinito"),
    "DefaultContentLanguage": MessageLookupByLibrary.simpleMessage("Lingua contenuti predefinita"),
    "DefaultOpenTab": MessageLookupByLibrary.simpleMessage("Scheda predefinita all'apertura"),
    "DiagnosticaAutomix": MessageLookupByLibrary.simpleMessage("Diagnostica Automix"),
    "DiscordRichPresence": MessageLookupByLibrary.simpleMessage("Discord Rich Presence"),
    "DislikedSongs": MessageLookupByLibrary.simpleMessage("Brani non piaciuti"),
    "EchoWrapped": MessageLookupByLibrary.simpleMessage("Echo Wrapped"),
    "EchoBrainPlaylists": MessageLookupByLibrary.simpleMessage("Playlist EchoBrain"),
    "EnableCastDeviceDiscovery": MessageLookupByLibrary.simpleMessage("Abilita rilevamento dispositivi Cast"),
    "EnableSimilarContent": MessageLookupByLibrary.simpleMessage("Abilita contenuti simili"),
    "ExportAndImportData": MessageLookupByLibrary.simpleMessage("Esporta e importa dati"),
    "ExportAsMP3": MessageLookupByLibrary.simpleMessage("Esporta come MP3"),
    "ExtensionsHighQualityServers": MessageLookupByLibrary.simpleMessage("Estensioni e server di alta qualità"),
    "FetchSongBackground": MessageLookupByLibrary.simpleMessage("Recupera sfondo del brano"),
    "FineGrainedOptions": MessageLookupByLibrary.simpleMessage("Opzioni dettagliate"),
    "ForceLowBitrateAndDisablePreloading": MessageLookupByLibrary.simpleMessage("Forza basso bitrate e disabilita precaricamento"),
    "General": MessageLookupByLibrary.simpleMessage("Generale"),
    "GlassEffect": MessageLookupByLibrary.simpleMessage("Effetto vetro"),
    "GlassPlayerLyricsMiscCustomization": MessageLookupByLibrary.simpleMessage("Vetro, player, testi e varie personalizzazioni"),
    "GoogleCast": MessageLookupByLibrary.simpleMessage("Google Cast"),
    "HidePlayerThumbnail": MessageLookupByLibrary.simpleMessage("Nascondi miniatura player"),
    "HideYouTubeShorts": MessageLookupByLibrary.simpleMessage("Nascondi YouTube Shorts"),
    "HideExplicitContent": MessageLookupByLibrary.simpleMessage("Nascondi contenuti espliciti"),
    "HideVideoSongs": MessageLookupByLibrary.simpleMessage("Nascondi brani video"),
    "HistoryAndTracking": MessageLookupByLibrary.simpleMessage("Cronologia e tracciamento"),
    "IlBlendFinisceSuUnBeatDellaTraccia": MessageLookupByLibrary.simpleMessage("Il blend finisce su un beat della traccia"),
    "ImageCache": MessageLookupByLibrary.simpleMessage("Cache immagini"),
    "ImportAPlaylistByURL": MessageLookupByLibrary.simpleMessage("Importa una playlist da URL"),
    "ImportFromSpotify": MessageLookupByLibrary.simpleMessage("Importa da Spotify"),
    "IncollaProfiloAutoEqAvanzato": MessageLookupByLibrary.simpleMessage("Incolla profilo AutoEq (avanzato)"),
    "JellyfinNavidrome": MessageLookupByLibrary.simpleMessage("Jellyfin / Navidrome"),
    "LanguageRegionAndProviders": MessageLookupByLibrary.simpleMessage("Lingua, regione e provider"),
    "LastFmListenBrainz": MessageLookupByLibrary.simpleMessage("Last.fm / ListenBrainz"),
    "LeaveEmptyForTheProviderDefault": MessageLookupByLibrary.simpleMessage("Lascia vuoto per il valore predefinito del provider"),
    "ListenTogether": MessageLookupByLibrary.simpleMessage("Ascolta insieme"),
    "ListeningSummary": MessageLookupByLibrary.simpleMessage("Riepilogo ascolti"),
    "LogEventi": MessageLookupByLibrary.simpleMessage("Log eventi"),
    "LookUpATrackOnGeniusWikipedia": MessageLookupByLibrary.simpleMessage("Cerca un brano su Genius / Wikipedia"),
    "LoudnessPreset": MessageLookupByLibrary.simpleMessage("Preset di loudness"),
    "Lyrics": MessageLookupByLibrary.simpleMessage("Testi"),
    "LyricsRomanization": MessageLookupByLibrary.simpleMessage("Romanizzazione testi"),
    "LyricsTextPosition": MessageLookupByLibrary.simpleMessage("Posizione testo lyrics"),
    "ManageHiddenArtists": MessageLookupByLibrary.simpleMessage("Gestisci artisti nascosti"),
    "ManageSongsYouDislike": MessageLookupByLibrary.simpleMessage("Gestisci i brani non piaciuti"),
    "MiniPlayer": MessageLookupByLibrary.simpleMessage("Mini-player"),
    "MiniPlayerBackgroundStyle": MessageLookupByLibrary.simpleMessage("Stile sfondo mini-player"),
    "Misc": MessageLookupByLibrary.simpleMessage("Varie"),
    "Model": MessageLookupByLibrary.simpleMessage("Modello"),
    "MostraOverlayNelPlayer": MessageLookupByLibrary.simpleMessage("Mostra overlay nel player"),
    "MusicFlow": MessageLookupByLibrary.simpleMessage("Music Flow"),
    "MusicFlowFull": MessageLookupByLibrary.simpleMessage("Music Flow (completo)"),
    "Network": MessageLookupByLibrary.simpleMessage("Rete"),
    "NetworkQuality": MessageLookupByLibrary.simpleMessage("Rete e qualità"),
    "OutputDevice": MessageLookupByLibrary.simpleMessage("Dispositivo di uscita"),
    "PersistentQueue": MessageLookupByLibrary.simpleMessage("Coda persistente"),
    "PlaybackCutoffGuard": MessageLookupByLibrary.simpleMessage("Protezione da interruzione riproduzione"),
    "PlaybackQualityAndEqualizer": MessageLookupByLibrary.simpleMessage("Riproduzione, qualità ed equalizzatore"),
    "Player": MessageLookupByLibrary.simpleMessage("Player"),
    "PlayerAndAudio": MessageLookupByLibrary.simpleMessage("Player e audio"),
    "PlayerBackgroundStyle": MessageLookupByLibrary.simpleMessage("Stile sfondo player"),
    "PlayerLook": MessageLookupByLibrary.simpleMessage("Aspetto player"),
    "PreArmAdattivoAttivo2035S": MessageLookupByLibrary.simpleMessage("Pre-arm adattivo attivo (20-35 s)"),
    "PreloadNextSong": MessageLookupByLibrary.simpleMessage("Precarica il brano successivo"),
    "PreventDuplicateTracksInQueue": MessageLookupByLibrary.simpleMessage("Evita brani duplicati nella coda"),
    "Privacy": MessageLookupByLibrary.simpleMessage("Privacy"),
    "ProgressiveSeek": MessageLookupByLibrary.simpleMessage("Ricerca progressiva"),
    "Provider": MessageLookupByLibrary.simpleMessage("Provider"),
    "PulisciCompletate": MessageLookupByLibrary.simpleMessage("Pulisci completate"),
    "PulisciLog": MessageLookupByLibrary.simpleMessage("Pulisci log"),
    "Queue": MessageLookupByLibrary.simpleMessage("Coda"),
    "RefreshDevices": MessageLookupByLibrary.simpleMessage("Aggiorna dispositivi"),
    "Region": MessageLookupByLibrary.simpleMessage("Regione"),
    "RememberShuffleAndRepeat": MessageLookupByLibrary.simpleMessage("Ricorda shuffle e repeat"),
    "RemoteControlLAN": MessageLookupByLibrary.simpleMessage("Controllo remoto (LAN)"),
    "ReplayGainLoudnessNormalizationViaPlaybackGain": MessageLookupByLibrary.simpleMessage("Normalizzazione loudness ReplayGain (via guadagno riproduzione)"),
    "RessoStyleVerticalSwipeDiscovery": MessageLookupByLibrary.simpleMessage("Scoperta con swipe verticale stile Resso"),
    "RestoreTheLastQueueOnAppStart": MessageLookupByLibrary.simpleMessage("Ripristina l'ultima coda all'avvio"),
    "Riprova": MessageLookupByLibrary.simpleMessage("Riprova"),
    "SceglieIlBranoSuccessivoInTonalitCompatibileCame": MessageLookupByLibrary.simpleMessage("Sceglie il brano successivo in tonalità compatibile (Camelot)"),
    "ShowBottomPlaylist": MessageLookupByLibrary.simpleMessage("Mostra playlist \"Bottom\""),
    "ShowCachedPlaylist": MessageLookupByLibrary.simpleMessage("Mostra playlist \"Cached\""),
    "ShowDownloadedPlaylist": MessageLookupByLibrary.simpleMessage("Mostra playlist \"Downloaded\""),
    "ShowLikedPlaylist": MessageLookupByLibrary.simpleMessage("Mostra playlist \"Liked\""),
    "ShowTopPlaylist": MessageLookupByLibrary.simpleMessage("Mostra playlist \"Top\""),
    "Show10SecondSeekButtons": MessageLookupByLibrary.simpleMessage("Mostra pulsanti salto di 10 secondi"),
    "ShowRomanizedLyricsAsMain": MessageLookupByLibrary.simpleMessage("Mostra testi romanizzati come principali"),
    "SkipSilence": MessageLookupByLibrary.simpleMessage("Salta il silenzio"),
    "SkipSponsoredSegmentsInVideos": MessageLookupByLibrary.simpleMessage("Salta i segmenti sponsorizzati nei video"),
    "SongCache": MessageLookupByLibrary.simpleMessage("Cache brani"),
    "SongDNA": MessageLookupByLibrary.simpleMessage("Song DNA"),
    "SongRecognitionEchoFind": MessageLookupByLibrary.simpleMessage("Riconoscimento brani (Echo Find)"),
    "SponsorBlockAutoSkip": MessageLookupByLibrary.simpleMessage("SponsorBlock (salto automatico)"),
    "StatoAutomixInSovrimpressione": MessageLookupByLibrary.simpleMessage("Stato Automix in sovrimpressione"),
    "StatoAnalisiBeatMixPointELogEventi": MessageLookupByLibrary.simpleMessage("Stato, analisi beat, mix point e log eventi"),
    "StreamingResponses": MessageLookupByLibrary.simpleMessage("Risposte streaming"),
    "StreamingServiceConfiguration": MessageLookupByLibrary.simpleMessage("Configurazione servizio streaming"),
    "SupportedLinks": MessageLookupByLibrary.simpleMessage("Link supportati"),
    "SystemUpdate": MessageLookupByLibrary.simpleMessage("Aggiornamento di sistema"),
    "TargetLanguage": MessageLookupByLibrary.simpleMessage("Lingua di destinazione"),
    "TestConnection": MessageLookupByLibrary.simpleMessage("Prova connessione"),
    "Theme": MessageLookupByLibrary.simpleMessage("Tema"),
    "ThemesColorsAndUILayout": MessageLookupByLibrary.simpleMessage("Temi, colori e layout UI"),
    "Translation": MessageLookupByLibrary.simpleMessage("Traduzione"),
    "TranslationMode": MessageLookupByLibrary.simpleMessage("Modalità traduzione"),
    "TrimSilentPartsMpvSilenceremoveOnDesktop": MessageLookupByLibrary.simpleMessage("Rimuovi parti silenziose (mpv silenceremove su desktop)"),
    "UseSSEForFasterLyricsTranslation": MessageLookupByLibrary.simpleMessage("Usa SSE per traduzione più rapida dei testi"),
    "VerifyTheEnteredServerCredentials": MessageLookupByLibrary.simpleMessage("Verifica le credenziali server inserite"),
    "ViewYourMusicListeningStatistics": MessageLookupByLibrary.simpleMessage("Visualizza le statistiche di ascolto"),
    "YourYearInSoundPersonalMusicRecap": MessageLookupByLibrary.simpleMessage("Il tuo anno in musica e riepilogo personale"),
  };
}
