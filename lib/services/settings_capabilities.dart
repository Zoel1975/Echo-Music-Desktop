/// Settings that are persisted but not functional in the Windows build.
///
/// Android-only effects (RenderEffect refraction, wallpaper palette, haptics)
/// have no Windows equivalent. For everything else, the option is disabled in
/// the UI with this explicit explanation instead of silently doing nothing.
const Map<String, String> unavailableSettings = {
  // --- Platform features with no Windows API -----------------------------
  'hapticIntensity':
      'Feedback aptico non disponibile: Windows non espone un motore di vibrazione.',
  'lensRefraction':
      'Rifrazione RenderEffect non disponibile con il renderer Impeller di Windows.',
  'chromaticAberration':
      'Aberrazione cromatica RenderEffect non disponibile su Windows.',
  'depthEffect':
      'Effetto profondità RenderEffect non disponibile su Windows.',

  // --- Dynamic colors is a real SettingsManager key ---------------------
  'DYNAMIC_COLORS':
      'Material You richiede WallpaperColors di Android; Windows non fornisce '
      'la palette del wallpaper di sistema.',

  // --- Navigation / layout ----------------------------------------------
  'navBarStyle':
      'Su Windows la barra di navigazione è sempre flottante; gli stili Android '
      'non sono applicabili.',
  'displayDensity':
      'Densità di visualizzazione Android non applicabile alla finestra Windows.',
  'listenTogetherTop':
      'Ascolto condiviso non integrato nella barra superiore del desktop.',

  // --- Glass sub-options -------------------------------------------------
  'surfaceOpacity':
      'Opacità superficiale gestita dal tema centralizzato EchoGlass.',
  'glassPlayer':
      'Vetro del player gestito da EchoGlass; non disattivabile per singola superficie.',
  'glassMiniPlayer':
      'Vetro del mini-player gestito dallo stile Mini-player.',
  'glassNavBar':
      'La barra flottante usa sempre EchoGlass su Windows.',

  // --- Player micro-interactions not ported -----------------------------
  'appleInspired': 'Variante estetica di Android non disponibile sul desktop.',
  'wavyPlayPause':
      'Pulsante play/pause ondulato non applicabile al controllo desktop.',
  'swipeChangeSong':
      'Gesti di swipe non disponibili nel player desktop (usare i pulsanti).',
  'swipeSensitivity': 'Sensibilità swipe non applicabile senza gesti di swipe.',
  'rotatingThumb': 'Copertina rotante non disponibile nel player desktop.',
  'rotatingThumbnail': 'Copertina rotante non disponibile nel player desktop.',
  'preloadLimit':
      'Limite di precaricamento non esposto: mpv gestisce automaticamente il buffer.',
  'cropArt': 'Ritaglio copertina gestito dal layout del player desktop.',
  'buttonColors':
      'Colori pulsanti Android non mappati sulla palette del tema desktop.',
  'hideVolumeSlider':
      'Slider volume sempre visibile nel player desktop.',

  // --- Lyrics extras ----------------------------------------------------
  'lyricsAnimation': 'Animazione parola per parola non disponibile nel testo desktop.',
  'appleLyricsBlur': 'Sfocatura lyrics stile Apple non disponibile con Impeller.',
  'standardLyricsBlur': 'Sfocatura lyrics non disponibile con Impeller.',
  'lyricsClickChange':
      'Cambio traccia cliccando il testo non disponibile; usare i controlli.',
  'lyricsSwipe': 'Swipe sui testi non disponibile nel player desktop.',
  'lyricsThumbPlayPause':
      'Play/pause sulla copertina dei testi non disponibile sul desktop.',
  'defaultLibChip': 'Scheda libreria predefinita gestita da "Apri scheda".',

  // --- Queue gestures ---------------------------------------------------
  'swipeQueue': 'Gesto di swipe sulla coda non disponibile sul desktop.',
  'swipeRemove': 'Rimozione con swipe non disponibile nella coda desktop.',

  // --- Auto-playlists with no desktop equivalent ------------------------
  'showTopPlaylist':
      'Playlist automatiche "Top/Bottom/Cached" non presenti nella libreria desktop.',
  'showBottomPlaylist':
      'Playlist automatiche "Top/Bottom/Cached" non presenti nella libreria desktop.',
  'showCachedPlaylist':
      'Playlist automatiche "Top/Bottom/Cached" non presenti nella libreria desktop.',

  // --- Integrations -----------------------------------------------------
  'lastfmUsername':
      'Nome utente Last.fm usato solo per i suggerimenti Android, non disponibili.',
  'lastfmLikes':
      'Invio dei like a Last.fm non collegato al pulsante preferiti desktop.',
  'cloudSync':
      'Sincronizzazione libreria Jellyfin/Navidrome non ancora implementata.',
  'ltAutoApprove':
      'Approvazione automatica richieste Listen Together non disponibile.',
  'ltServer': 'Server Listen Together personalizzato non disponibile.',
  'preferExtension':
      'Preferenza sorgente estensione non collegata al resolver desktop.',
  'extensionServer': 'Server estensioni personalizzato non disponibile.',
  'songDnaEnabled':
      'Song DNA non ancora esposto nel menu del player desktop.',
};

/// True when the key has a working implementation in the Windows build.
bool isSettingAvailable(String key) => !unavailableSettings.containsKey(key);

/// Human-readable reason why a setting is disabled, or null when available.
String? unavailableReason(String key) => unavailableSettings[key];
