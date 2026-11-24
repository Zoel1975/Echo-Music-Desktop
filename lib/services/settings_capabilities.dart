/// Settings that still cannot work in the Windows build.
///
/// Only eight options remain: the Android platform services they need do not
/// exist on Windows (wallpaper palette, vibration motor, RenderEffect) or the
/// desktop library has no equivalent auto-playlist. Every other Android option
/// is wired to a real Flutter widget or service; these are shown disabled in
/// the UI with the explicit reason below, never as silent no-ops.
const Map<String, String> unavailableSettings = {
  'hapticIntensity':
      'Feedback aptico non disponibile: Windows non espone un motore di vibrazione.',
  'lensRefraction':
      'Rifrazione RenderEffect non disponibile con il renderer Impeller di Windows.',
  'chromaticAberration':
      'Aberrazione cromatica RenderEffect non disponibile su Windows.',
  'depthEffect':
      'Effetto profondità RenderEffect non disponibile su Windows.',
  'DYNAMIC_COLORS':
      'Material You richiede WallpaperColors di Android; Windows non fornisce '
      'la palette del wallpaper di sistema.',
  'showTopPlaylist':
      'Playlist automatica "Top" non presente nella libreria desktop.',
  'showBottomPlaylist':
      'Playlist automatica "Bottom" non presente nella libreria desktop.',
  'showCachedPlaylist':
      'Playlist automatica "Cached" non presente nella libreria desktop.',
};

/// True when the key has a working implementation in the Windows build.
bool isSettingAvailable(String key) => !unavailableSettings.containsKey(key);

/// Human-readable reason why a setting is disabled, or null when available.
String? unavailableReason(String key) => unavailableSettings[key];
