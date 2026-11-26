import 'package:flutter/material.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_manager.dart';
import '../../../services/settings_capabilities.dart';
import '../../../../themes/app_fonts.dart';
import '../widgets/setting_item.dart';
import '../widgets/settings_list.dart';
import '../../../../core/widgets/back_button.dart';

/// Fine-grained appearance options from Android `AppearanceSettings.kt`,
/// `GlassEffectSettings.kt`, `FontSelectionScreen.kt` and `HapticsSettings.kt`.
/// Feasible options are real persisted settings; Android-only/hardware ones
/// route to an explicit S.of(context).ComingInAFutureUpdate placeholder.
class AppearanceDetailsPage extends StatelessWidget {
  const AppearanceDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsManager>();
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Appearance details')),
      body: SettingsList(
        children: [
          GroupTitle(title: S.of(context).Theme),
          _dropdown(
            context,
            s,
            'Theme variant',
            'themeVariant',
            ['System', 'Light', 'Dark', 'AMOLED', 'Monochrome', 'Monochrome OLED'],
            'System',
          ),
          _soon(context, 'App Icon', 'Custom launcher icon (Android-only)'),
          _dropdown(
            context,
            s,
            'App Font',
            'appFont',
            AppFonts.choices.keys.toList(),
            'Google Sans Flex',
          ),

          GroupTitle(title: S.of(context).GlassEffect),
          _switch(context, s, 'Enable Liquid Glass', 'liquidGlass', false),
          _dropdown(context, s, 'Navigation bar style', 'navBarStyle',
              ['Material', 'Apple (floating)'], 'Apple (floating)'),
          _slider(context, s, 'Blur radius', 'blurRadius', 0, 40, 12),
          _slider(context, s, 'Surface opacity', 'surfaceOpacity', 0, 100, 30),
          _switch(context, s, 'Vibrancy', 'vibrancy', true),
          _switch(context, s, 'Lens refraction', 'lensRefraction', false),
          _switch(context, s, 'Chromatic aberration', 'chromaticAberration', false),
          _switch(context, s, 'Depth effect', 'depthEffect', false),
          _switch(context, s, 'Glass player', 'glassPlayer', true),
          _switch(context, s, 'Glass mini player', 'glassMiniPlayer', true),
          _switch(context, s, 'Glass navigation bar', 'glassNavBar', true),

          GroupTitle(title: S.of(context).PlayerLook),
          _switch(context, s, 'Apple Music inspired', 'appleInspired', false),
          _switch(context, s, 'Hide volume slider', 'hideVolumeSlider', false),
          _slider(context, s, 'Thumbnail corner radius', 'thumbRadius', 0, 28, 12),
          _switch(context, s, 'Crop album art', 'cropArt', false),
          _dropdown(context, s, 'Player button colors', 'buttonColors',
              ['Accent', 'White', 'Adaptive'], 'Accent'),
          _dropdown(context, s, 'Player slider style', 'sliderStyle',
              ['Default', 'Wavy', 'Squiggly'], 'Default'),
          _switch(context, s, 'Wavy play/pause button', 'wavyPlayPause', false),
          _switch(context, s, 'Enable swipe to change song', 'swipeChangeSong', true),
          _switch(context, s, 'Rotating thumbnail', 'rotatingThumb', false),
          _switch(context, s, 'Show comment button', 'showComment', false),
          _switch(context, s, 'Show codec on player', 'showCodec', true),
          _slider(context, s, 'Mini-player swipe sensitivity', 'swipeSensitivity', 1, 10, 5),

          GroupTitle(title: S.of(context).Lyrics),
          _dropdown(context, s, 'Word-by-word animation', 'lyricsAnimation',
              ['Fade', 'Scale', 'Slide'], 'Fade'),
          _switch(context, s, 'Apple Music lyrics blur', 'appleLyricsBlur', false),
          _switch(context, s, 'Standard lyrics blur', 'standardLyricsBlur', false),
          _slider(context, s, 'Lyrics line spacing', 'lyricsLineSpacing', 0, 20, 8),
          _switch(context, s, 'Change lyrics on click', 'lyricsClickChange', true),
          _switch(context, s, 'Swipe to change song (lyrics)', 'lyricsSwipe', true),
          _switch(context, s, 'Show play/pause on thumbnail', 'lyricsThumbPlayPause', true),

          GroupTitle(title: S.of(context).Misc),
          _dropdown(context, s, 'Default library chip', 'defaultLibChip',
              ['Songs', 'Albums', 'Artists', 'Playlists'], 'Songs'),
          _switch(context, s, 'Swipe song left to queue / right to play next',
              'swipeQueue', true),
          _switch(context, s, 'Swipe song to remove', 'swipeRemove', false),
          _switch(context, s, 'Listen Together in top bar', 'listenTogetherTop', false),
          _dropdown(context, s, 'Grid cell size', 'gridCellSize',
              ['Small', 'Medium', 'Large'], 'Medium'),
          _dropdown(context, s, 'Display density', 'displayDensity',
              ['Native 100%', 'Compact 85%', 'Compact 75%', 'Ultra 65%'], 'Native 100%'),
          _slider(context, s, 'Haptic intensity', 'hapticIntensity', 0, 3, 1),
          _soon(context, 'Hide status bar on fullscreen', 'Android-only system UI'),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _switch(BuildContext context, SettingsManager s, String title,
      String key, bool fallback) {
    final reason = unavailableReason(key);
    if (reason != null) {
      return SettingTile(
        title: title,
        subtitle: 'Non disponibile su Windows — $reason',
        leading: const Icon(Icons.info_outline),
        trailing: const Icon(Icons.block, size: 18),
      );
    }
    return SettingSwitchTile(
      title: title,
      leading: const Icon(Icons.tune),
      value: s.extra<bool>(key, fallback),
      onChanged: (v) => s.setExtra<bool>(key, v),
    );
  }

  Widget _dropdown(BuildContext context, SettingsManager s, String title,
      String key, List<String> items, String fallback) {
    final reason = unavailableReason(key);
    if (reason != null) {
      return SettingTile(
        title: title,
        subtitle: 'Non disponibile su Windows — $reason',
        leading: const Icon(Icons.info_outline),
        trailing: const Icon(Icons.block, size: 18),
      );
    }
    final value = s.extra<String>(key, fallback);
    if (key == 'appFont') AppFonts.initialize(value);
    return SettingTile(
      title: title,
      subtitle: value,
      leading: const Icon(Icons.arrow_drop_down_circle),
      trailing: DropdownButton<String>(
        value: items.contains(value) ? value : fallback,
        underline: const SizedBox(),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          s.setExtra<String>(key, v);
          if (key == 'appFont') AppFonts.initialize(v);
        },
      ),
    );
  }

  Widget _slider(BuildContext context, SettingsManager s, String title,
      String key, double min, double max, double fallback) {
    final reason = unavailableReason(key);
    if (reason != null) {
      return SettingTile(
        title: title,
        subtitle: 'Non disponibile su Windows — $reason',
        leading: const Icon(Icons.info_outline),
        trailing: const Icon(Icons.block, size: 18),
      );
    }
    final value = s.extra<double>(key, fallback);
    return SettingTile(
      title: title,
      subtitle: '${value.round()}',
      leading: const Icon(Icons.linear_scale),
      trailing: SizedBox(
        width: 160,
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: (v) => s.setExtra<double>(key, v),
        ),
      ),
    );
  }

  Widget _soon(BuildContext context, String title, String feature) {
    return SettingTile(
      title: title,
      subtitle: S.of(context).ComingInAFutureUpdate,
      leading: const Icon(Icons.schedule),
      trailing: const Icon(Icons.schedule, size: 18),
      onTap: () => context.go(
        '/settings/coming_soon',
        extra: {'title': title, 'feature': feature},
      ),
    );
  }
}
