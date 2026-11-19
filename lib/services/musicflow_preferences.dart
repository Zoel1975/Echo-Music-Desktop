/// Port of Android `musicflow/MusicFlowPreferences.kt` (DataStore → Hive box
/// `SETTINGS`, prefixed with `MUSIC_FLOW_`).
import 'package:hive_flutter/hive_flutter.dart';

class MusicFlowPreferences {
  MusicFlowPreferences._({
    this.enabled = true,
    this.autoplay = true,
    this.autoNext = true,
    this.animatedBackground = false,
    this.lyrics = true,
    this.cellularPrefetch = true,
    this.hideRecent = true,
    this.dataSaver = false,
  });

  static const key = 'MUSIC_FLOW_PREFS';
  static const enabledKey = 'MUSIC_FLOW_ENABLED';
  static const autoplayKey = 'MUSIC_FLOW_AUTOPLAY';
  static const autoNextKey = 'MUSIC_FLOW_AUTO_NEXT';
  static const animatedBackgroundKey = 'MUSIC_FLOW_ANIMATED_BG';
  static const lyricsKey = 'MUSIC_FLOW_LYRICS';
  static const cellularPrefetchKey = 'MUSIC_FLOW_CELLULAR_PREFETCH';
  static const hideRecentKey = 'MUSIC_FLOW_HIDE_RECENT';
  static const dataSaverKey = 'MUSIC_FLOW_DATA_SAVER';

  final bool enabled;
  final bool autoplay;
  final bool autoNext;
  final bool animatedBackground;
  final bool lyrics;
  final bool cellularPrefetch;
  final bool hideRecent;
  final bool dataSaver;

  static Box get _box => Hive.box('SETTINGS');

  static MusicFlowPreferences from() {
    return MusicFlowPreferences._(
      enabled: _box.get(enabledKey, defaultValue: true) as bool,
      autoplay: _box.get(autoplayKey, defaultValue: true) as bool,
      autoNext: _box.get(autoNextKey, defaultValue: true) as bool,
      animatedBackground: _box.get(animatedBackgroundKey, defaultValue: false) as bool,
      lyrics: _box.get(lyricsKey, defaultValue: true) as bool,
      cellularPrefetch: _box.get(cellularPrefetchKey, defaultValue: true) as bool,
      hideRecent: _box.get(hideRecentKey, defaultValue: true) as bool,
      dataSaver: _box.get(dataSaverKey, defaultValue: false) as bool,
    );
  }
}
