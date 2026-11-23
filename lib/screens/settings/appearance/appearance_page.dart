import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../generated/l10n.dart';
import '../widgets/setting_item.dart';
import '../../../utils/adaptive_widgets/adaptive_widgets.dart';
import '../../../utils/bottom_modals.dart';
import '../../player/widgets/player_background.dart';
import 'cubit/appearance_cubit.dart';
import '../../../../core/widgets/back_button.dart';

/// Real port of Android `AppearanceSettings.kt`: Theme + Mini-player + Player
/// + Lyrics + Misc + Auto playlists groups. Android-only visual/hardware
/// screens (App Icon, Font, Liquid Glass, Haptics, high refresh rate) are
/// explicit "Coming in a future update" placeholders.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppearanceCubit(),
      child: Scaffold(
        appBar: AppBar(
        leading: echoBackButton(context),
        title: Text(S.of(context).Appearence)),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<AppearanceCubit, AppearanceState>(
              builder: (context, state) {
                final s = state as AppearanceLoaded;
                final cubit = context.read<AppearanceCubit>();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    const GroupTitle(title: 'Theme'),
                    SettingTile(
                      title: S.of(context).Theme_Mode,
                      leading: const Icon(Icons.dark_mode),
                      isFirst: true,
                      trailing: AdaptiveDropdownButton<ThemeMode>(
                        value: s.themeMode,
                        items: ThemeMode.values
                            .map((e) => AdaptiveDropdownMenuItem(
                                  value: e,
                                  child: Text(e.name.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) cubit.setThemeMode(v);
                        },
                      ),
                    ),
                    SettingTile(
                      title: 'AccentColor',
                      leading: const Icon(Icons.colorize_rounded),
                      trailing: CircleAvatar(
                        radius: 20,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Row(children: [
                            Container(
                                color: s.accentColor ?? Colors.black, width: 20),
                            Container(
                                color: s.accentColor ?? Colors.white, width: 20),
                          ]),
                        ),
                      ),
                      onTap: () => Modals.showAccentSelector(context),
                    ),
                    SettingSwitchTile(
                      title: 'Amoled Black',
                      leading: const Icon(Icons.mode_night_outlined),
                      value: s.amoledBlack,
                      onChanged: cubit.setAmoledBlack,
                    ),
                    SettingSwitchTile(
                      title: S.of(context).Dynamic_Colors,
                      leading: const Icon(Icons.color_lens_outlined),
                      isLast: true,
                      value: s.dynamicColors,
                      onChanged: cubit.setDynamicColors,
                    ),

                    SettingTile(
                      title: 'Fine-grained options',
                      subtitle: 'Glass, player, lyrics & misc customization',
                      leading: const Icon(Icons.tune),
                      onTap: () => context.go('/settings/appearance/details'),
                    ),

                    // Android-only visual / hardware screens.
                    const GroupTitle(title: 'Appearance extras'),
                    _soon(context, 'App Icon', 'Choose a custom launcher icon'),
                    _soon(context, 'App Font', 'Font selection (Google Sans, Outfit, ...)'),
                    _soon(context, 'Liquid Glass (Beta)', 'Refraction/lens glass effects'),
                    _soon(context, 'Haptics', 'Vibration and tactile feedback'),
                    _soon(context, 'Enable high refresh rate',
                        'Force 120 Hz display (Android-only)', isLast: true),

                    const GroupTitle(title: 'Mini-player'),
                    _dropdown(context,
                        title: 'Mini-player background style',
                        icon: Icons.style,
                        value: s.miniPlayerStyle,
                        items: const ['Glass', 'Solid', 'Gradient'],
                        onChanged: cubit.setMiniPlayerStyle,
                        isFirst: true),

                    const GroupTitle(title: 'Player'),
                    _dropdown(context,
                        title: 'Player background style',
                        icon: Icons.wallpaper,
                        value: PlayerBackgroundStyle.normalize(
                            s.playerBackgroundStyle),
                        items: PlayerBackgroundStyle.all,
                        onChanged: cubit.setPlayerBackgroundStyle,
                        isFirst: true),
                    SettingSwitchTile(
                      title: 'Hide Player Thumbnail',
                      leading: const Icon(Icons.image_not_supported),
                      value: s.hidePlayerThumbnail,
                      onChanged: cubit.setHidePlayerThumbnail,
                      isLast: true,
                    ),

                    const GroupTitle(title: 'Lyrics'),
                    _dropdown(context,
                        title: 'Lyrics text position',
                        icon: Icons.text_fields,
                        value: s.lyricsTextPosition,
                        items: const ['Center', 'Left', 'Right'],
                        onChanged: cubit.setLyricsTextPosition,
                        isFirst: true),
                    SettingEmptyTile(
                      leading: const Icon(Icons.format_size),
                      child: ListTile(
                        title: const Text('Lyrics text size',
                            style: TextStyle(fontSize: 16)),
                        subtitle: Slider(
                          value: s.lyricsTextSize,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          label: '${s.lyricsTextSize.round()}',
                          onChanged: cubit.setLyricsTextSize,
                        ),
                      ),
                    ),
                    SettingSwitchTile(
                      title: 'Auto scroll lyrics',
                      leading: const Icon(Icons.swap_vert),
                      value: s.lyricsAutoScroll,
                      onChanged: cubit.setLyricsAutoScroll,
                      isLast: true,
                    ),

                    const GroupTitle(title: 'Misc'),
                    _dropdown<int>(context,
                        title: 'Default open tab',
                        icon: Icons.tab,
                        value: s.defaultTab,
                        items: const [0, 1, 2, 3],
                        labels: const ['Home', 'Search', 'Library', 'Settings'],
                        onChanged: cubit.setDefaultTab,
                        isFirst: true),

                    const GroupTitle(title: 'Auto playlists'),
                    SettingSwitchTile(
                      title: 'Show "Liked" playlist',
                      leading: const Icon(Icons.favorite),
                      isFirst: true,
                      value: s.showLikedPlaylist,
                      onChanged: cubit.setShowLikedPlaylist,
                    ),
                    SettingSwitchTile(
                      title: 'Show "Downloaded" playlist',
                      leading: const Icon(Icons.download),
                      value: s.showDownloadedPlaylist,
                      onChanged: cubit.setShowDownloadedPlaylist,
                    ),
                    SettingSwitchTile(
                      title: 'Show "Top" playlist',
                      leading: const Icon(Icons.leaderboard),
                      value: s.showTopPlaylist,
                      onChanged: cubit.setShowTopPlaylist,
                    ),
                    SettingSwitchTile(
                      title: 'Show "Bottom" playlist',
                      leading: const Icon(Icons.trending_down),
                      value: s.showBottomPlaylist,
                      onChanged: cubit.setShowBottomPlaylist,
                    ),
                    SettingSwitchTile(
                      title: 'Show "Cached" playlist',
                      leading: const Icon(Icons.cached),
                      isLast: true,
                      value: s.showCachedPlaylist,
                      onChanged: cubit.setShowCachedPlaylist,
                    ),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _soon(BuildContext context, String title, String feature,
      {bool isLast = false}) {
    return SettingTile(
      title: title,
      subtitle: 'Coming in a future update',
      leading: const Icon(Icons.schedule),
      isLast: isLast,
      trailing: const Icon(Icons.schedule, size: 18),
      onTap: () => context.go(
        '/settings/coming_soon',
        extra: {'title': title, 'feature': feature},
      ),
    );
  }

  Widget _dropdown<T>(BuildContext context,
      {required String title,
      required IconData icon,
      required T value,
      required List<T> items,
      List<String>? labels,
      required ValueChanged<T> onChanged,
      bool isFirst = false}) {
    return SettingTile(
      title: title,
      leading: Icon(icon),
      isFirst: isFirst,
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        items: [
          for (var i = 0; i < items.length; i++)
            DropdownMenuItem<T>(
                value: items[i],
                child: Text(labels != null ? labels[i] : items[i].toString())),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
