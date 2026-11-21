import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/widgets/back_button.dart';
import '../../services/settings_manager.dart';

/// Port of Android `MusicFlowSettings.kt`: the same seven toggles, persisted
/// through SettingsManager (Hive) instead of Android DataStore.
class MusicFlowSettingsPage extends StatefulWidget {
  const MusicFlowSettingsPage({super.key});

  @override
  State<MusicFlowSettingsPage> createState() => _MusicFlowSettingsPageState();
}

class _MusicFlowSettingsPageState extends State<MusicFlowSettingsPage> {
  final _settings = GetIt.I<SettingsManager>();

  static const _general = [
    ('musicFlowEnabled', true, 'Enable Music Flow', 'Vertical swipe discovery'),
    ('musicFlowAutoplay', true, 'Autoplay', 'Start the focused song automatically'),
    ('musicFlowAutoNext', true, 'Auto next', 'Advance when a song ends'),
    ('musicFlowHideRecent', true, 'Hide recent', 'Do not show recently played items'),
  ];
  static const _visuals = [
    ('musicFlowAnimatedBackground', true, 'Animated background', 'Gradient follows the current track'),
    ('musicFlowLyrics', true, 'Lyrics', 'Show synced lyrics in Music Flow'),
    ('musicFlowCellularPrefetch', true, 'Cellular prefetch', 'Preload tracks on metered networks'),
  ];

  bool _value(String key, bool fallback) =>
      _settings.extra<bool>(key, fallback);

  void _set(String key, bool value) {
    setState(() => _settings.setExtra<bool>(key, value));
  }

  Widget _toggle(String key, bool fallback, String title, String subtitle) {
    return SwitchListTile(
      value: _value(key, fallback),
      onChanged: (v) => _set(key, v),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Music Flow'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Music Flow', style: Theme.of(context).textTheme.titleMedium),
          ..._general.map((s) => _toggle(s.$1, s.$2, s.$3, s.$4)),
          const SizedBox(height: 16),
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          ..._visuals.map((s) => _toggle(s.$1, s.$2, s.$3, s.$4)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
