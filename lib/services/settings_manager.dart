import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../ytmusic/ytmusic.dart';
import 'translation_settings.dart';

Box _box = Hive.box('SETTINGS');

class SettingsManager extends ChangeNotifier implements TranslationSettings {
  ThemeMode _themeMode = ThemeMode.system;
  final List<ThemeMode> _themeModes = [
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark
  ];
  late Map<String, String> _location;
  late Map<String, String> _language;
  bool _autofetchSongs = true;
  final List<AudioQuality> _audioQualities = [
    AudioQuality.high,
    AudioQuality.low,
    // Monochrome lossless FLAC (https://monochrome.st/).
    AudioQuality.flac,
  ];

  AudioQuality _streamingQuality = AudioQuality.high;
  AudioQuality _downloadQuality = AudioQuality.high;
  bool _skipSilence = false;
  Color? _accentColor;
  bool _amoledBlack = true;
  bool _dynamicColors = false;
  bool _equalizerEnabled = false;
  List<double> _equalizerBandsGain = [];
  bool _loudnessEnabled = false;
  double _loudnessTargetGain = 0.0;

  // Desktop player / "wireless" features (persisted in the SETTINGS box).
  bool _showSeekButtons = false;
  bool _crossfadeEnabled = false;
  bool _automixBeatAlign = true;
  bool _automixHarmonicMix = true;
  double _crossfadeDuration = 5.0;
  int _exportBitrateKbps = 192;
  bool _dataSaver = false;
  String _audioDeviceId = '';
  bool _castEnabled = true;
  bool _remoteControlEnabled = false;

  // Android PlayerSettings.kt — Queue group (port of PreferenceKeys).
  bool _persistentQueue = true;
  bool _autoLoadMore = true;
  bool _similarContent = true;
  bool _autoSkipOnError = false;
  bool _rememberShuffleRepeat = true;
  bool _preventDuplicates = false;
  bool _autoDownloadOnLike = false;
  // Android PlayerSettings.kt — Player/Misc DSP settings.
  bool _progressiveSeek = false;
  bool _crossfadeGapless = true;
  double _historyDuration = 1.0;
  String _loudnessPreset = 'Normal';
  bool _preloadNext = true;
  double _preloadLimit = 10.0;

  // Android ContentSettings.kt — General group.
  bool _hideExplicit = false;
  bool _hideVideoSongs = false;
  bool _hideYouTubeShorts = false;
  bool _sponsorBlock = false;
  bool _lyricsRomanization = false;
  bool _romanizeAsMain = false;
  String _contentLanguage = 'en';
  String _contentCountry = 'US';

  // Android AppearanceSettings.kt — feasible desktop equivalents.
  String _miniPlayerStyle = 'Glass';
  String _playerBackgroundStyle = 'Gradient';
  String _lyricsTextPosition = 'Center';
  double _lyricsTextSize = 18.0;
  bool _lyricsAutoScroll = true;
  bool _hidePlayerThumbnail = false;
  int _defaultTab = 0;
  bool _showLikedPlaylist = true;
  bool _showDownloadedPlaylist = true;
  bool _showTopPlaylist = true;
  bool _showBottomPlaylist = false;
  bool _showCachedPlaylist = false;
  String _localMusicFolder = '';

  ThemeMode get themeMode => _themeMode;
  List<ThemeMode> get themeModes => _themeModes;
  Map<String, String> get location => _location;
  List<Map<String, String>> get locations => _countries;
  Map<String, String> get language => _language;
  bool get autofetchSongs => _autofetchSongs;
  List<Map<String, String>> get languages => _languages;
  List<AudioQuality> get audioQualities => _audioQualities;
  AudioQuality get streamingQuality => _streamingQuality;
  AudioQuality get downloadQuality => _downloadQuality;
  bool get skipSilence => _skipSilence;

  /// YT Music > "Translate lyrics": gates the player's translate button.
  bool get translateLyrics =>
      _box.get('TRANSLATE_LYRICS', defaultValue: false) == true;

  Color? get accentColor => _accentColor;
  bool get amoledBlack => _amoledBlack;
  bool get dynamicColors => _dynamicColors;
  bool get equalizerEnabled => _equalizerEnabled;
  List<double> get equalizerBandsGain => _equalizerBandsGain;
  bool get loudnessEnabled => _loudnessEnabled;
  double get loudnessTargetGain => _loudnessTargetGain;

  bool get showSeekButtons => _showSeekButtons;
  bool get crossfadeEnabled => _crossfadeEnabled;
  bool get automixBeatAlign => _automixBeatAlign;
  bool get automixHarmonicMix => _automixHarmonicMix;
  double get crossfadeDuration => _crossfadeDuration;
  int get exportBitrateKbps => _exportBitrateKbps;
  bool get dataSaver => _dataSaver;
  String get audioDeviceId => _audioDeviceId;
  bool get castEnabled => _castEnabled;
  bool get remoteControlEnabled => _remoteControlEnabled;

  bool get persistentQueue => _persistentQueue;
  bool get autoLoadMore => _autoLoadMore;
  bool get similarContent => _similarContent;
  bool get autoSkipOnError => _autoSkipOnError;
  bool get rememberShuffleRepeat => _rememberShuffleRepeat;
  bool get preventDuplicates => _preventDuplicates;
  bool get autoDownloadOnLike => _autoDownloadOnLike;
  bool get progressiveSeek => _progressiveSeek;
  bool get crossfadeGapless => _crossfadeGapless;
  double get historyDuration => _historyDuration;
  String get loudnessPreset => _loudnessPreset;
  bool get preloadNext => _preloadNext;
  double get preloadLimit => _preloadLimit;

  bool get hideExplicit => _hideExplicit;
  bool get hideVideoSongs => _hideVideoSongs;
  bool get hideYouTubeShorts => _hideYouTubeShorts;
  bool get sponsorBlock => _sponsorBlock;
  bool get lyricsRomanization => _lyricsRomanization;
  bool get romanizeAsMain => _romanizeAsMain;
  String get contentLanguage => _contentLanguage;
  String get contentCountry => _contentCountry;

  String get miniPlayerStyle => _miniPlayerStyle;
  String get playerBackgroundStyle => _playerBackgroundStyle;
  String get lyricsTextPosition => _lyricsTextPosition;
  double get lyricsTextSize => _lyricsTextSize;
  bool get lyricsAutoScroll => _lyricsAutoScroll;
  bool get hidePlayerThumbnail => _hidePlayerThumbnail;
  int get defaultTab => _defaultTab;
  bool get showLikedPlaylist => _showLikedPlaylist;
  bool get showDownloadedPlaylist => _showDownloadedPlaylist;
  bool get showTopPlaylist => _showTopPlaylist;
  bool get showBottomPlaylist => _showBottomPlaylist;
  bool get showCachedPlaylist => _showCachedPlaylist;
  String get localMusicFolder => _localMusicFolder;

  /// Generic persisted accessor for fine-grained appearance/player options
  /// that follow the same boolean/enum/number pattern as Android preferences.
  T extra<T>(String key, T fallback) {
    final v = _box.get('EXTRA_$key');
    return v is T ? v : fallback;
  }

  void setExtra<T>(String key, T value) {
    _box.put('EXTRA_$key', value);
    notifyListeners();
  }

  Map get settings => _box.toMap();
  SettingsManager() {
    _init();
  }
  _init() {
    _themeMode = _themeModes[
        (_box.get('THEME_MODE', defaultValue: 0) as num).toInt().clamp(
            0, _themeModes.length - 1)];
    _language = _languages.firstWhere(
        (language) =>
            language['value'] == _box.get('LANGUAGE', defaultValue: 'en'),
        orElse: () => _languages.firstWhere(
      (language) => language['value'] == 'en',
      orElse: () => _languages.first,
    ));
    _autofetchSongs = _box.get('AUTOFETCH_SONGS', defaultValue: true);
    _accentColor = _box.get('ACCENT_COLOR') != null
        ? Color(_box.get('ACCENT_COLOR'))
        : null;
    _amoledBlack = _box.get('AMOLED_BLACK', defaultValue: true);
    _dynamicColors = _box.get('DYNAMIC_COLORS', defaultValue: false);

    _location = _countries.firstWhere(
        (country) => country['value'] == _box.get('LOCATION', defaultValue: 'IN'),
        orElse: () => _countries.first);

    _streamingQuality = _audioQualities[
        (_box.get('STREAMING_QUALITY', defaultValue: 0) as num).toInt().clamp(
            0, _audioQualities.length - 1)];
    _downloadQuality = _audioQualities[
        (_box.get('DOWNLOAD_QUALITY', defaultValue: 0) as num).toInt().clamp(
            0, _audioQualities.length - 1)];
    _skipSilence = _box.get('SKIP_SILENCE', defaultValue: false);
    _equalizerEnabled = _box.get('EQUALIZER_ENABLED', defaultValue: false);
    _loudnessEnabled = _box.get('LOUDNESS_ENABLED', defaultValue: false);
    _loudnessTargetGain = _box.get('LOUDNESS_TARGET_GAIN', defaultValue: 0.0);
    _equalizerBandsGain =
        _box.get('EQUALIZER_BANDS_GAIN', defaultValue: []).cast<double>();

    _showSeekButtons = _box.get('SHOW_SEEK_BUTTONS', defaultValue: false);
    _crossfadeEnabled = _box.get('CROSSFADE_ENABLED', defaultValue: false);
    _automixBeatAlign = _box.get('AUTOMIX_BEAT_ALIGN', defaultValue: true);
    _automixHarmonicMix =
        _box.get('AUTOMIX_HARMONIC_MIX', defaultValue: true);
    _crossfadeDuration =
        (_box.get('CROSSFADE_DURATION', defaultValue: 5.0) as num).toDouble();
    _exportBitrateKbps =
        (_box.get('EXPORT_BITRATE_KBPS', defaultValue: 192) as num).toInt();
    _dataSaver = _box.get('DATA_SAVER', defaultValue: false);
    _audioDeviceId = _box.get('AUDIO_DEVICE_ID', defaultValue: '');
    _castEnabled = _box.get('CAST_ENABLED', defaultValue: true);
    _remoteControlEnabled =
        _box.get('REMOTE_CONTROL_ENABLED', defaultValue: false);

    _persistentQueue = _box.get('PERSISTENT_QUEUE', defaultValue: true);
    _autoLoadMore = _box.get('AUTO_LOAD_MORE', defaultValue: true);
    _similarContent = _box.get('SIMILAR_CONTENT', defaultValue: true);
    _autoSkipOnError = _box.get('AUTO_SKIP_ON_ERROR', defaultValue: false);
    _rememberShuffleRepeat =
        _box.get('REMEMBER_SHUFFLE_REPEAT', defaultValue: true);
    _preventDuplicates = _box.get('PREVENT_DUPLICATES', defaultValue: false);
    _autoDownloadOnLike =
        _box.get('AUTO_DOWNLOAD_ON_LIKE', defaultValue: false);
    _progressiveSeek = _box.get('PROGRESSIVE_SEEK', defaultValue: false);
    _crossfadeGapless = _box.get('CROSSFADE_GAPLESS', defaultValue: true);
    _historyDuration =
        (_box.get('HISTORY_DURATION', defaultValue: 1.0) as num).toDouble();
    _loudnessPreset = _box.get('LOUDNESS_PRESET', defaultValue: 'Normal');
    _preloadNext = _box.get('PRELOAD_NEXT', defaultValue: true);
    _preloadLimit =
        (_box.get('PRELOAD_LIMIT', defaultValue: 10.0) as num).toDouble();

    _hideExplicit = _box.get('HIDE_EXPLICIT', defaultValue: false);
    _hideVideoSongs = _box.get('HIDE_VIDEO_SONGS', defaultValue: false);
    _hideYouTubeShorts = _box.get('HIDE_YT_SHORTS', defaultValue: false);
    _sponsorBlock = _box.get('SPONSOR_BLOCK', defaultValue: false);
    _lyricsRomanization = _box.get('LYRICS_ROMANIZATION', defaultValue: false);
    _romanizeAsMain = _box.get('ROMANIZE_AS_MAIN', defaultValue: false);
    _contentLanguage = _box.get('CONTENT_LANGUAGE', defaultValue: 'en');
    _contentCountry = _box.get('CONTENT_COUNTRY', defaultValue: 'US');

    _miniPlayerStyle = _box.get('MINI_PLAYER_STYLE', defaultValue: 'Glass');
    _playerBackgroundStyle =
        _box.get('PLAYER_BG_STYLE', defaultValue: 'Gradient');
    _lyricsTextPosition =
        _box.get('LYRICS_TEXT_POSITION', defaultValue: 'Center');
    _lyricsTextSize =
        (_box.get('LYRICS_TEXT_SIZE', defaultValue: 18.0) as num).toDouble();
    _lyricsAutoScroll = _box.get('LYRICS_AUTO_SCROLL', defaultValue: true);
    _hidePlayerThumbnail =
        _box.get('HIDE_PLAYER_THUMBNAIL', defaultValue: false);
    _defaultTab = _box.get('DEFAULT_TAB', defaultValue: 0);
    _showLikedPlaylist = _box.get('SHOW_LIKED_PLAYLIST', defaultValue: true);
    _showDownloadedPlaylist =
        _box.get('SHOW_DOWNLOADED_PLAYLIST', defaultValue: true);
    _showTopPlaylist = _box.get('SHOW_TOP_PLAYLIST', defaultValue: true);
    _showBottomPlaylist = _box.get('SHOW_BOTTOM_PLAYLIST', defaultValue: false);
    _showCachedPlaylist = _box.get('SHOW_CACHED_PLAYLIST', defaultValue: false);
    _localMusicFolder = _box.get('LOCAL_MUSIC_FOLDER', defaultValue: '');
  }

  // -------------------------------------------------- lyrics translation --
  String get translationProvider =>
      _box.get('TRANSLATION_PROVIDER', defaultValue: 'OpenRouter');
  set translationProvider(String value) {
    _box.put('TRANSLATION_PROVIDER', value);
    notifyListeners();
  }

  String get translationApiKey =>
      _box.get('TRANSLATION_API_KEY', defaultValue: '');
  set translationApiKey(String value) {
    _box.put('TRANSLATION_API_KEY', value);
    notifyListeners();
  }

  String get translationBaseUrl =>
      _box.get('TRANSLATION_BASE_URL', defaultValue: '');
  set translationBaseUrl(String value) {
    _box.put('TRANSLATION_BASE_URL', value);
    notifyListeners();
  }

  String get translationModel =>
      _box.get('TRANSLATION_MODEL', defaultValue: '');
  set translationModel(String value) {
    _box.put('TRANSLATION_MODEL', value);
    notifyListeners();
  }

  String get translationLanguage =>
      _box.get('TRANSLATION_LANGUAGE', defaultValue: 'en');
  set translationLanguage(String value) {
    _box.put('TRANSLATION_LANGUAGE', value);
    notifyListeners();
  }

  String get translationMode =>
      _box.get('TRANSLATION_MODE', defaultValue: 'Translate');
  set translationMode(String value) {
    _box.put('TRANSLATION_MODE', value);
    notifyListeners();
  }

  bool get translationStreaming =>
      _box.get('TRANSLATION_STREAMING', defaultValue: true);
  set translationStreaming(bool value) {
    _box.put('TRANSLATION_STREAMING', value);
    notifyListeners();
  }

  setThemeMode(ThemeMode mode) async {
    _box.put('THEME_MODE', _themeModes.indexOf(mode));
    _themeMode = mode;

    notifyListeners();
  }

  set location(Map<String, String> value) {
    _box.put('LOCATION', value['value']);
    _location = value;
    GetIt.I<YTMusic>().refreshContext();
    notifyListeners();
  }

  set language(Map<String, String> value) {
    _box.put('LANGUAGE', value['value']);
    _language = value;
    GetIt.I<YTMusic>().refreshContext();
    notifyListeners();
  }

  set autofetchSongs(bool value) {
    _box.put('AUTOFETCH_SONGS', value);
    _autofetchSongs = value;
    notifyListeners();
  }

  set streamingQuality(AudioQuality value) {
    _box.put('STREAMING_QUALITY', _audioQualities.indexOf(value));
    _streamingQuality = value;
    notifyListeners();
  }

  set downloadQuality(AudioQuality value) {
    _box.put('DOWNLOAD_QUALITY', _audioQualities.indexOf(value));
    _downloadQuality = value;
    notifyListeners();
  }

  set skipSilence(bool value) {
    _box.put('SKIP_SILENCE', value);
    _skipSilence = value;
    notifyListeners();
  }

  set accentColor(Color? color) {
    int? c = color?.value;
    _box.put('ACCENT_COLOR', c);
    _accentColor = color;
    notifyListeners();
  }

  set amoledBlack(bool val) {
    _box.put('AMOLED_BLACK', val);
    _amoledBlack = val;
    notifyListeners();
  }

  set dynamicColors(bool isMaterial) {
    _box.put('DYNAMIC_COLORS', isMaterial);
    _dynamicColors = isMaterial;
    notifyListeners();
  }

  set equalizerEnabled(bool enabled) {
    _box.put('EQUALIZER_ENABLED', enabled);
    _equalizerEnabled = enabled;
    notifyListeners();
  }

  set equalizerBandsGain(List<double>? value) {
    if (value != null) {
      _box.put('EQUALIZER_BANDS_GAIN', value);
      _equalizerBandsGain = value;
      notifyListeners();
    }
  }

  Future<void> setEqualizerBandsGain(int index, double value) async {
    if (index < 0) return;
    // A fresh profile has an empty band list; writing to it used to throw a
    // RangeError before the value could ever be persisted.
    if (_equalizerBandsGain.length <= index) {
      _equalizerBandsGain = List<double>.filled(index + 1, 0.0);
    }
    _equalizerBandsGain[index] = value;
    await _box.put('EQUALIZER_BANDS_GAIN', equalizerBandsGain);
    notifyListeners();
  }

  set loudnessEnabled(enabled) {
    _box.put('LOUDNESS_ENABLED', enabled);
    _loudnessEnabled = enabled;
    notifyListeners();
  }

  set loudnessTargetGain(double value) {
    _box.put('LOUDNESS_TARGET_GAIN', value);
    _loudnessTargetGain = value;
    notifyListeners();
  }

  set showSeekButtons(bool value) {
    _box.put('SHOW_SEEK_BUTTONS', value);
    _showSeekButtons = value;
    notifyListeners();
  }

  set crossfadeEnabled(bool value) {
    _box.put('CROSSFADE_ENABLED', value);
    _crossfadeEnabled = value;
    notifyListeners();
  }

  set automixBeatAlign(bool value) {
    _box.put('AUTOMIX_BEAT_ALIGN', value);
    _automixBeatAlign = value;
    notifyListeners();
  }

  set automixHarmonicMix(bool value) {
    _box.put('AUTOMIX_HARMONIC_MIX', value);
    _automixHarmonicMix = value;
    notifyListeners();
  }

  set crossfadeDuration(double value) {
    _box.put('CROSSFADE_DURATION', value);
    _crossfadeDuration = value;
    notifyListeners();
  }

  set exportBitrateKbps(int value) {
    final bitrate = value.clamp(64, 320);
    _box.put('EXPORT_BITRATE_KBPS', bitrate);
    _exportBitrateKbps = bitrate;
    notifyListeners();
  }

  set dataSaver(bool value) {
    _box.put('DATA_SAVER', value);
    _dataSaver = value;
    notifyListeners();
  }

  set audioDeviceId(String value) {
    _box.put('AUDIO_DEVICE_ID', value);
    _audioDeviceId = value;
    notifyListeners();
  }

  set castEnabled(bool value) {
    _box.put('CAST_ENABLED', value);
    _castEnabled = value;
    notifyListeners();
  }

  set remoteControlEnabled(bool value) {
    _box.put('REMOTE_CONTROL_ENABLED', value);
    _remoteControlEnabled = value;
    notifyListeners();
  }

  set persistentQueue(bool v) {
    _box.put('PERSISTENT_QUEUE', v);
    _persistentQueue = v;
    notifyListeners();
  }

  set autoLoadMore(bool v) {
    _box.put('AUTO_LOAD_MORE', v);
    _autoLoadMore = v;
    notifyListeners();
  }

  set similarContent(bool v) {
    _box.put('SIMILAR_CONTENT', v);
    _similarContent = v;
    notifyListeners();
  }

  set autoSkipOnError(bool v) {
    _box.put('AUTO_SKIP_ON_ERROR', v);
    _autoSkipOnError = v;
    notifyListeners();
  }

  set rememberShuffleRepeat(bool v) {
    _box.put('REMEMBER_SHUFFLE_REPEAT', v);
    _rememberShuffleRepeat = v;
    notifyListeners();
  }

  set preventDuplicates(bool v) {
    _box.put('PREVENT_DUPLICATES', v);
    _preventDuplicates = v;
    notifyListeners();
  }

  set autoDownloadOnLike(bool v) {
    _box.put('AUTO_DOWNLOAD_ON_LIKE', v);
    _autoDownloadOnLike = v;
    notifyListeners();
  }

  set progressiveSeek(bool v) {
    _box.put('PROGRESSIVE_SEEK', v);
    _progressiveSeek = v;
    notifyListeners();
  }

  set crossfadeGapless(bool v) {
    _box.put('CROSSFADE_GAPLESS', v);
    _crossfadeGapless = v;
    notifyListeners();
  }

  set historyDuration(double v) {
    _box.put('HISTORY_DURATION', v);
    _historyDuration = v;
    notifyListeners();
  }

  set loudnessPreset(String v) {
    _box.put('LOUDNESS_PRESET', v);
    _loudnessPreset = v;
    notifyListeners();
  }

  set preloadNext(bool v) {
    _box.put('PRELOAD_NEXT', v);
    _preloadNext = v;
    notifyListeners();
  }

  set preloadLimit(double v) {
    _box.put('PRELOAD_LIMIT', v);
    _preloadLimit = v;
    notifyListeners();
  }

  set hideExplicit(bool v) {
    _box.put('HIDE_EXPLICIT', v);
    _hideExplicit = v;
    notifyListeners();
  }

  set hideVideoSongs(bool v) {
    _box.put('HIDE_VIDEO_SONGS', v);
    _hideVideoSongs = v;
    notifyListeners();
  }

  set hideYouTubeShorts(bool v) {
    _box.put('HIDE_YT_SHORTS', v);
    _hideYouTubeShorts = v;
    notifyListeners();
  }

  set sponsorBlock(bool v) {
    _box.put('SPONSOR_BLOCK', v);
    _sponsorBlock = v;
    notifyListeners();
  }

  set lyricsRomanization(bool v) {
    _box.put('LYRICS_ROMANIZATION', v);
    _lyricsRomanization = v;
    notifyListeners();
  }

  set romanizeAsMain(bool v) {
    _box.put('ROMANIZE_AS_MAIN', v);
    _romanizeAsMain = v;
    notifyListeners();
  }

  set contentLanguage(String v) {
    _box.put('CONTENT_LANGUAGE', v);
    _contentLanguage = v;
    notifyListeners();
  }

  set contentCountry(String v) {
    _box.put('CONTENT_COUNTRY', v);
    _contentCountry = v;
    notifyListeners();
  }

  set miniPlayerStyle(String v) {
    _box.put('MINI_PLAYER_STYLE', v);
    _miniPlayerStyle = v;
    notifyListeners();
  }

  set playerBackgroundStyle(String v) {
    _box.put('PLAYER_BG_STYLE', v);
    _playerBackgroundStyle = v;
    notifyListeners();
  }

  set lyricsTextPosition(String v) {
    _box.put('LYRICS_TEXT_POSITION', v);
    _lyricsTextPosition = v;
    notifyListeners();
  }

  set lyricsTextSize(double v) {
    _box.put('LYRICS_TEXT_SIZE', v);
    _lyricsTextSize = v;
    notifyListeners();
  }

  set lyricsAutoScroll(bool v) {
    _box.put('LYRICS_AUTO_SCROLL', v);
    _lyricsAutoScroll = v;
    notifyListeners();
  }

  set hidePlayerThumbnail(bool v) {
    _box.put('HIDE_PLAYER_THUMBNAIL', v);
    _hidePlayerThumbnail = v;
    notifyListeners();
  }

  set defaultTab(int v) {
    _box.put('DEFAULT_TAB', v);
    _defaultTab = v;
    notifyListeners();
  }

  set showLikedPlaylist(bool v) {
    _box.put('SHOW_LIKED_PLAYLIST', v);
    _showLikedPlaylist = v;
    notifyListeners();
  }

  set showDownloadedPlaylist(bool v) {
    _box.put('SHOW_DOWNLOADED_PLAYLIST', v);
    _showDownloadedPlaylist = v;
    notifyListeners();
  }

  set showTopPlaylist(bool v) {
    _box.put('SHOW_TOP_PLAYLIST', v);
    _showTopPlaylist = v;
    notifyListeners();
  }

  set showBottomPlaylist(bool v) {
    _box.put('SHOW_BOTTOM_PLAYLIST', v);
    _showBottomPlaylist = v;
    notifyListeners();
  }

  set showCachedPlaylist(bool v) {
    _box.put('SHOW_CACHED_PLAYLIST', v);
    _showCachedPlaylist = v;
    notifyListeners();
  }

  set localMusicFolder(String v) {
    _box.put('LOCAL_MUSIC_FOLDER', v);
    _localMusicFolder = v;
    notifyListeners();
  }

  Future<void> setSettings(Map value) async {
    await Future.forEach(value.entries, (entry) async {
      await _box.put(entry.key, entry.value);
    });
    notifyListeners();
    _init();
  }
}

bool getDarkness(int themeMode) {
  if (themeMode == 0) {
    return MediaQueryData.fromView(
                    WidgetsBinding.instance.platformDispatcher.views.first)
                .platformBrightness ==
            Brightness.dark
        ? true
        : false;
  } else if (themeMode == 2) {
    return true;
  }
  return false;
}

/// `flac` resolves through the Monochrome public API (lossless, no account).
enum AudioQuality { high, low, flac }

List<Map<String, String>> _countries = [
  {"name": "Algeria", "value": "DZ"},
  {"name": "Argentina", "value": "AR"},
  {"name": "Australia", "value": "AU"},
  {"name": "Austria", "value": "AT"},
  {"name": "Azerbaijan", "value": "AZ"},
  {"name": "Bahrain", "value": "BH"},
  {"name": "Bangladesh", "value": "BD"},
  {"name": "Belarus", "value": "BY"},
  {"name": "Belgium", "value": "BE"},
  {"name": "Bolivia", "value": "BO"},
  {"name": "Bosnia and Herzegovina", "value": "BA"},
  {"name": "Brazil", "value": "BR"},
  {"name": "Bulgaria", "value": "BG"},
  {"name": "Cambodia", "value": "KH"},
  {"name": "Canada", "value": "CA"},
  {"name": "Chile", "value": "CL"},
  {"name": "Colombia", "value": "CO"},
  {"name": "Costa Rica", "value": "CR"},
  {"name": "Croatia", "value": "HR"},
  {"name": "Cyprus", "value": "CY"},
  {"name": "Czechia", "value": "CZ"},
  {"name": "Denmark", "value": "DK"},
  {"name": "Dominican Republic", "value": "DO"},
  {"name": "Ecuador", "value": "EC"},
  {"name": "Egypt", "value": "EG"},
  {"name": "El Salvador", "value": "SV"},
  {"name": "Estonia", "value": "EE"},
  {"name": "Finland", "value": "FI"},
  {"name": "France", "value": "FR"},
  {"name": "Georgia", "value": "GE"},
  {"name": "Germany", "value": "DE"},
  {"name": "Ghana", "value": "GH"},
  {"name": "Greece", "value": "GR"},
  {"name": "Guatemala", "value": "GT"},
  {"name": "Honduras", "value": "HN"},
  {"name": "Hong Kong", "value": "HK"},
  {"name": "Hungary", "value": "HU"},
  {"name": "Iceland", "value": "IS"},
  {"name": "India", "value": "IN"},
  {"name": "Indonesia", "value": "ID"},
  {"name": "Iraq", "value": "IQ"},
  {"name": "Ireland", "value": "IE"},
  {"name": "Israel", "value": "IL"},
  {"name": "Italy", "value": "IT"},
  {"name": "Jamaica", "value": "JM"},
  {"name": "Japan", "value": "JP"},
  {"name": "Jordan", "value": "JO"},
  {"name": "Kazakhstan", "value": "KZ"},
  {"name": "Kenya", "value": "KE"},
  {"name": "Kuwait", "value": "KW"},
  {"name": "Laos", "value": "LA"},
  {"name": "Latvia", "value": "LV"},
  {"name": "Lebanon", "value": "LB"},
  {"name": "Libya", "value": "LY"},
  {"name": "Liechtenstein", "value": "LI"},
  {"name": "Lithuania", "value": "LT"},
  {"name": "Luxembourg", "value": "LU"},
  {"name": "Malaysia", "value": "MY"},
  {"name": "Malta", "value": "MT"},
  {"name": "Mexico", "value": "MX"},
  {"name": "Moldova", "value": "MD"},
  {"name": "Montenegro", "value": "ME"},
  {"name": "Morocco", "value": "MA"},
  {"name": "Nepal", "value": "NP"},
  {"name": "Netherlands", "value": "NL"},
  {"name": "New Zealand", "value": "NZ"},
  {"name": "Nicaragua", "value": "NI"},
  {"name": "Nigeria", "value": "NG"},
  {"name": "North Macedonia", "value": "MK"},
  {"name": "Norway", "value": "NO"},
  {"name": "Oman", "value": "OM"},
  {"name": "Pakistan", "value": "PK"},
  {"name": "Panama", "value": "PA"},
  {"name": "Papua New Guinea", "value": "PG"},
  {"name": "Paraguay", "value": "PY"},
  {"name": "Peru", "value": "PE"},
  {"name": "Philippines", "value": "PH"},
  {"name": "Poland", "value": "PL"},
  {"name": "Portugal", "value": "PT"},
  {"name": "Puerto Rico", "value": "PR"},
  {"name": "Qatar", "value": "QA"},
  {"name": "Romania", "value": "RO"},
  {"name": "Russia", "value": "RU"},
  {"name": "Saudi Arabia", "value": "SA"},
  {"name": "Senegal", "value": "SN"},
  {"name": "Serbia", "value": "RS"},
  {"name": "Singapore", "value": "SG"},
  {"name": "Slovakia", "value": "SK"},
  {"name": "Slovenia", "value": "SI"},
  {"name": "South Africa", "value": "ZA"},
  {"name": "South Korea", "value": "KR"},
  {"name": "Spain", "value": "ES"},
  {"name": "Sri Lanka", "value": "LK"},
  {"name": "Sweden", "value": "SE"},
  {"name": "Switzerland", "value": "CH"},
  {"name": "Taiwan", "value": "TW"},
  {"name": "Tanzania", "value": "TZ"},
  {"name": "Thailand", "value": "TH"},
  {"name": "Tunisia", "value": "TN"},
  {"name": "Turkey", "value": "TR"},
  {"name": "Uganda", "value": "UG"},
  {"name": "Ukraine", "value": "UA"},
  {"name": "United Arab Emirates", "value": "AE"},
  {"name": "United Kingdom", "value": "GB"},
  {"name": "United States", "value": "US"},
  {"name": "Uruguay", "value": "UY"},
  {"name": "Venezuela", "value": "VE"},
  {"name": "Vietnam", "value": "VN"},
  {"name": "Yemen", "value": "YE"},
  {"name": "Zimbabwe", "value": "ZW"}
];

List<Map<String, String>> _languages = [
  {"name": "Afrikaans", "value": "af"},
  {"name": "Azərbaycan", "value": "az"},
  {"name": "Bahasa Indonesia", "value": "id"},
  {"name": "Bahasa Malaysia", "value": "ms"},
  {"name": "Bosanski", "value": "bs"},
  {"name": "Català", "value": "ca"},
  {"name": "Čeština", "value": "cs"},
  {"name": "Dansk", "value": "da"},
  {"name": "Deutsch", "value": "de"},
  {"name": "Eesti", "value": "et"},
  {"name": "English (India)", "value": "en-IN"},
  {"name": "English (UK)", "value": "en-GB"},
  {"name": "English (US)", "value": "en"},
  {"name": "Español (España)", "value": "es"},
  {"name": "Español (Latinoamérica)", "value": "es-419"},
  {"name": "Español (US)", "value": "es-US"},
  {"name": "Euskara", "value": "eu"},
  {"name": "Filipino", "value": "fil"},
  {"name": "Français", "value": "fr"},
  {"name": "Français (Canada)", "value": "fr-CA"},
  {"name": "Galego", "value": "gl"},
  {"name": "Hrvatski", "value": "hr"},
  {"name": "IsiZulu", "value": "zu"},
  {"name": "Íslenska", "value": "is"},
  {"name": "Italiano", "value": "it"},
  {"name": "Kiswahili", "value": "sw"},
  {"name": "Latviešu valoda", "value": "lv"},
  {"name": "Lietuvių", "value": "lt"},
  {"name": "Magyar", "value": "hu"},
  {"name": "Nederlands", "value": "nl"},
  {"name": "Norsk", "value": "no"},
  {"name": "O‘zbek", "value": "uz"},
  {"name": "Polski", "value": "pl"},
  {"name": "Português", "value": "pt-PT"},
  {"name": "Português (Brasil)", "value": "pt"},
  {"name": "Română", "value": "ro"},
  {"name": "Shqip", "value": "sq"},
  {"name": "Slovenčina", "value": "sk"},
  {"name": "Slovenščina", "value": "sl"},
  {"name": "Srpski", "value": "sr-Latn"},
  {"name": "Suomi", "value": "fi"},
  {"name": "Svenska", "value": "sv"},
  {"name": "Tiếng Việt", "value": "vi"},
  {"name": "Türkçe", "value": "tr"},
  {"name": "Беларуская", "value": "be"},
  {"name": "Български", "value": "bg"},
  {"name": "Кыргызча", "value": "ky"},
  {"name": "Қазақ Тілі", "value": "kk"},
  {"name": "Македонски", "value": "mk"},
  {"name": "Монгол", "value": "mn"},
  {"name": "Русский", "value": "ru"},
  {"name": "Српски", "value": "sr"},
  {"name": "Українська", "value": "uk"},
  {"name": "Ελληνικά", "value": "el"},
  {"name": "Հայերեն", "value": "hy"},
  {"name": "עברית", "value": "iw"},
  {"name": "اردو", "value": "ur"},
  {"name": "العربية", "value": "ar"},
  {"name": "فارسی", "value": "fa"},
  {"name": "नेपाली", "value": "ne"},
  {"name": "मराठी", "value": "mr"},
  {"name": "हिन्दी", "value": "hi"},
  {"name": "অসমীয়া", "value": "as"},
  {"name": "বাংলা", "value": "bn"},
  {"name": "ਪੰਜਾਬੀ", "value": "pa"},
  {"name": "ગુજરાતી", "value": "gu"},
  {"name": "ଓଡ଼ିଆ", "value": "or"},
  {"name": "தமிழ்", "value": "ta"},
  {"name": "తెలుగు", "value": "te"},
  {"name": "ಕನ್ನಡ", "value": "kn"},
  {"name": "മലയാളം", "value": "ml"},
  {"name": "සිංහල", "value": "si"},
  {"name": "ภาษาไทย", "value": "th"},
  {"name": "ລາວ", "value": "lo"},
  {"name": "ဗမာ", "value": "my"},
  {"name": "ქართული", "value": "ka"},
  {"name": "አማርኛ", "value": "am"},
  {"name": "ខ្មែរ", "value": "km"},
  {"name": "中文 (简体)", "value": "zh-CN"},
  {"name": "中文 (繁體)", "value": "zh-TW"},
  {"name": "中文 (香港)", "value": "zh-HK"},
  {"name": "日本語", "value": "ja"},
  {"name": "한국어", "value": "ko"}
];
