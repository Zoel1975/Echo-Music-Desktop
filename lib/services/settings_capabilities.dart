/// Settings still not functional in the Windows build.
///
/// Only options that genuinely cannot work on Windows (no wallpaper palette
/// service, no vibration motor, no RenderEffect) or that need a service that
/// does not exist yet (cloud library sync, Song DNA panel) stay here. Every
/// other Android option has been wired to a real Flutter widget. The UI shows
/// these as disabled with the explicit reason below, never as silent no-ops.
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

  // --- Navigation / layout with no desktop equivalent -------------------
  'navBarStyle':
      'Su Windows la barra di navigazione è sempre flottante; gli stili Android '
      'non sono applicabili.',
  'listenTogetherTop':
      'Ascolto condiviso non integrato nella barra superiore del desktop.',
  'appleInspired': 'Variante estetica di Android non disponibile sul desktop.',

  // --- Auto-playlists with no desktop equivalent ------------------------
  'showTopPlaylist':
      'Playlist automatiche "Top/Bottom/Cached" non presenti nella libreria desktop.',
  'showBottomPlaylist':
      'Playlist automatiche "Top/Bottom/Cached" non presenti nella libreria desktop.',
  'showCachedPlaylist':
      'Playlist automatiche "Top/Bottom/Cached" non presenti nella libreria desktop.',

  // --- Integrations that need a service not yet ported ------------------
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
