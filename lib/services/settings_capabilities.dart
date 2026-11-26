/// Settings that still cannot work in the Windows build.
///
/// Only five options remain: the Android platform services they need do not
/// exist on Windows (wallpaper palette, vibration motor, RenderEffect). Every
/// other Android option — including the automatic Top/Bottom/Cached playlists
/// built from local history and downloads — is wired to a real Flutter widget
/// or service. These are shown disabled in the UI with the explicit reason
/// below, never as silent no-ops.
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
};

/// True when the key has a working implementation in the Windows build.
bool isSettingAvailable(String key) => !unavailableSettings.containsKey(key);

/// Human-readable reason why a setting is disabled, or null when available.
String? unavailableReason(String key) => unavailableSettings[key];
