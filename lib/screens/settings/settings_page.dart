import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/services/cookie_store.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../generated/l10n.dart';
import '../../themes/text_styles.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import 'widgets/color_icon.dart';
import 'widgets/setting_item.dart';
import 'cubit/settings_system_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Android SearchableSettings: matches top-level entries and common
  /// sub-settings, navigating straight to the right screen.
  static const _searchableSubs = <(String, String, String)>[
    ('Tema', 'Aspetto', '/settings/appearance'),
    ('Colori', 'Aspetto', '/settings/appearance'),
    ('Lingua', 'Contenuti', '/settings/content'),
    ('Paese', 'Contenuti', '/settings/content'),
    ('SponsorBlock', 'Contenuti', '/settings/content'),
    ('Brani bloccati', 'Contenuti', '/settings/content/blocked_artists'),
    ('Brani non graditi', 'Contenuti', '/settings/content/disliked_songs'),
    ('Qualità streaming', 'Riproduttore', '/settings/player'),
    ('Loudness', 'Riproduttore', '/settings/player'),
    ('Crossfade', 'Riproduttore', '/settings/player'),
    ('Equalizzatore', 'Riproduttore', '/settings/player/equalizer'),
    ('AutoEq', 'Riproduttore', '/settings/player/axion'),
    ('Sincronizzazione testi', 'AI', '/settings/ai'),
    ('Traduzione', 'AI', '/settings/ai'),
    ('Cache', 'Archiviazione', '/settings/storage'),
    ('Backup', 'Backup', '/settings/backup_storage'),
  ];

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Cerca nelle impostazioni',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  List<Widget> _filter(List<Widget> children) {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return [_searchField(), ...children];
    final result = <Widget>[_searchField()];
    GroupTitle? pendingGroup;
    for (final widget in children) {
      if (widget is GroupTitle) {
        pendingGroup = widget;
        continue;
      }
      if (widget is SettingTile &&
          (widget.title.toLowerCase().contains(q) ||
              (widget.subtitle ?? '').toLowerCase().contains(q))) {
        if (pendingGroup != null) {
          result.add(pendingGroup);
          pendingGroup = null;
        }
        result.add(widget);
      }
    }
    for (final sub in _searchableSubs) {
      if (sub.$1.toLowerCase().contains(q) ||
          sub.$2.toLowerCase().contains(q)) {
        result.add(SettingTile(
          title: sub.$1,
          subtitle: sub.$2,
          leading: const Icon(Icons.subdirectory_arrow_right),
          onTap: () => context.go(sub.$3),
        ));
      }
    }
    if (result.length == 1) {
      result.add(const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Nessuna impostazione trovata.')),
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsSystemCubit()..load(),
      child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(
          title: Text(
            S.of(context).Settings,
            style: appBarTitleStyle(),
          ),
          automaticallyImplyLeading: false,
        ),
        body: BlocBuilder<SettingsSystemCubit, SettingsSystemState>(
          builder: (context, state) {
            final bool? batteryDisabled = state is SettingsSystemLoaded
                ? state.isBatteryOptimizationDisabled
                : null;

            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: _filter([
                    if (Platform.isAndroid && batteryDisabled != true)
                      _BatteryWarningTile(),

                    // Mirrors Android SettingsScreen.kt (15 entries). Real
                    // routes where a desktop implementation exists; explicit
                    // "coming in a future update" placeholders otherwise.
                    GroupTitle(title: "Account"),
                    SettingTile(
                      title: 'Account',
                      subtitle: () {
                        final account = CookieStore.instance.account;
                        final name = account['name']?.toString();
                        final signedIn = name != null &&
                            name.isNotEmpty &&
                            CookieStore.instance.cookieHeader != null;
                        return signedIn ? name : 'Manage login and integrations';
                      }(),
                      leading: const Icon(Icons.account_circle_outlined),
                      isFirst: true,
                      isLast: true,
                      onTap: () => context.go('/account'),
                    ),

                    GroupTitle(title: "Smart features"),
                    SettingTile(
                      title: 'AI lyrics & translation',
                      subtitle: 'AI-powered lyrics and translations',
                      leading: const Icon(Icons.auto_awesome),
                      isFirst: true,
                      onTap: () => context.go('/settings/ai'),
                    ),
                    SettingTile(
                      title: 'Listening Summary',
                      subtitle: 'View your music listening statistics',
                      leading: const Icon(Icons.bar_chart),
                      isLast: true,
                      onTap: () => context.go('/settings/listening_summary'),
                    ),
                    SettingTile(
                      title: 'Echo Wrapped',
                      subtitle: 'Your year in sound & personal music recap',
                      leading: const Icon(Icons.auto_stories),
                      isLast: true,
                      onTap: () => context.go('/settings/wrapped'),
                    ),

                    GroupTitle(title: "Appearance & player"),
                    SettingTile(
                      title: S.of(context).Appearence,
                      subtitle: 'Themes, colors, and UI layout',
                      leading: const Icon(Icons.palette_outlined),
                      isFirst: true,
                      onTap: () => context.go('/settings/appearance'),
                    ),
                    SettingTile(
                      title: 'Player and audio',
                      subtitle: 'Playback, quality, and equalizer',
                      leading: const Icon(Icons.play_arrow_rounded),
                      onTap: () => context.go('/settings/player'),
                    ),
                    SettingTile(
                      title: 'Music Flow',
                      subtitle: 'Resso-style vertical swipe discovery',
                      leading: const Icon(Icons.auto_awesome_mosaic),
                      onTap: () => context.go('/settings/music_flow'),
                    ),
                    SettingTile(
                      title: 'Content',
                      subtitle: 'Language, region, and providers',
                      leading: const Icon(Icons.language),
                      isLast: true,
                      onTap: () => context.go('/settings/content'),
                    ),

                    GroupTitle(title: "Social & privacy"),
                    _integrationTile(
                      context,
                      title: 'Listen Together',
                      icon: Icons.groups_outlined,
                      route: '/listen_together',
                    ),
                    SettingTile(
                      title: "Privacy",
                      subtitle: 'History and tracking',
                      leading: const Icon(Icons.privacy_tip),
                      isLast: true,
                      onTap: () => context.go('/settings/privacy'),
                    ),

                    GroupTitle(title: "Storage & services"),
                    SettingTile(
                      title: "Storage",
                      subtitle: 'Cache and downloads',
                      leading: const Icon(Icons.storage_rounded),
                      isFirst: true,
                      onTap: () => context.go('/settings/storage'),
                    ),
                    SettingTile(
                      title: "Backup and restore",
                      subtitle: 'Export and import data',
                      leading: const Icon(Icons.cloud_upload_rounded),
                      onTap: () => context.go('/settings/backup_storage'),
                    ),
                    SettingTile(
                      title: "Youtube Music",
                      subtitle: 'Streaming service configuration',
                      leading: const Icon(Icons.play_circle_fill),
                      onTap: () => context.go('/settings/services/ytmusic'),
                    ),
                    SettingTile(
                      title: 'Import from Spotify',
                      subtitle: 'Import a playlist by URL',
                      leading: const Icon(Icons.library_music),
                      isLast: true,
                      onTap: () =>
                          context.go('/settings/services/spotify_import'),
                    ),

                    GroupTitle(title: "Integrations"),
                    _integrationTile(
                      context,
                      title: 'Discord Rich Presence',
                      icon: Icons.discord,
                      route: '/discord',
                    ),
                    _integrationTile(
                      context,
                      title: 'Last.fm / ListenBrainz',
                      icon: Icons.audiotrack,
                      route: '/lastfm',
                    ),
                    _integrationTile(
                      context,
                      title: 'Jellyfin / Navidrome',
                      icon: Icons.cloud_outlined,
                      route: '/jellyfin',
                      isLast: true,
                    ),

                    GroupTitle(title: "More from mobile"),
                    _integrationTile(
                      context,
                      title: 'Music Flow (full)',
                      icon: Icons.swipe,
                      route: '/music_flow_full',
                    ),
                    _integrationTile(
                      context,
                      title: 'Canvas & Ambient mode',
                      icon: Icons.animation,
                      route: '/canvas_ambient',
                    ),
                    _integrationTile(
                      context,
                      title: 'Extensions & high-quality servers',
                      icon: Icons.extension,
                      route: '/extensions',
                    ),
                    _integrationTile(
                      context,
                      title: 'EchoBrain playlists',
                      icon: Icons.auto_awesome,
                      route: '/settings/ai/brain',
                    ),
                    _integrationTile(
                      context,
                      title: 'AXION / AutoEq equalizer',
                      icon: Icons.equalizer,
                      route: '/settings/player/axion',
                    ),
                    _comingSoonTile(
                      context,
                      title: 'Song recognition (Echo Find)',
                      icon: Icons.graphic_eq,
                      feature: 'On-device audio fingerprinting needs native '
                          'DSP / microphone capture, planned for a future update.',
                      isLast: true,
                    ),
                    _integrationTile(
                      context,
                      title: 'Song DNA',
                      icon: Icons.biotech,
                      route: '/song_dna',
                    ),
                    SettingTile(
                      title: 'Export as MP3',
                      subtitle: 'Background export task queue',
                      leading: const Icon(Icons.file_download_outlined),
                      isLast: true,
                      onTap: () => context.go('/export_queue'),
                    ),

                    GroupTitle(title: "Updates & About"),
                    SettingTile(
                      title: S.of(context).About,
                      subtitle: 'App info and licenses',
                      leading: const Icon(Icons.info_rounded),
                      isFirst: true,
                      onTap: () => context.go('/settings/about'),
                    ),
                    SettingTile(
                      title: 'System update',
                      subtitle: S.of(context).Check_For_Update,
                      leading: const Icon(Icons.update_rounded),
                      onTap: () => context.go('/settings/update'),
                    ),
                    _comingSoonTile(
                      context,
                      title: 'Supported Links',
                      icon: Icons.link,
                      feature: 'Android app-link settings (not applicable on '
                          'desktop).',
                    ),
                    SettingTile(
                      title: "Support",
                      leading: const Icon(Icons.favorite_rounded),
                      isLast: true,
                      onTap: () async {
                        final uri = Uri.parse('https://support.iad1tya.cyou/');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    const SizedBox(height: 100), // Extra padding for miniplayer
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

extension _SettingsPageHelpers on _SettingsPageState {
  Widget _integrationTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return SettingTile(
      title: title,
      subtitle: 'Configure',
      leading: Icon(icon),
      isFirst: isFirst,
      isLast: isLast,
      trailing: const Icon(Icons.chevron_right, size: 18),
      // push keeps Settings underneath so Back returns here instead of
      // leaving a black screen (go() replaces the whole stack).
      onTap: () => context.push(route),
    );
  }

  Widget _comingSoonTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String feature,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return SettingTile(
      title: title,
      subtitle: 'Coming in a future update',
      leading: Icon(icon),
      isFirst: isFirst,
      isLast: isLast,
      trailing: const Icon(Icons.schedule, size: 18),
      onTap: () => context.go(
        '/settings/coming_soon',
        extra: {'title': title, 'feature': feature},
      ),
    );
  }
}

class _BatteryWarningTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.errorContainer.withAlpha(200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      leading: const ColorIcon(
        icon: Icons.battery_alert,
        color: Colors.red,
      ),
      title: Text(
        S.of(context).Battery_Optimisation_title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      subtitle: Text(
        S.of(context).Battery_Optimisation_message,
        style: tinyTextStyle(context).copyWith(
          color: Theme.of(context)
              .colorScheme
              .onErrorContainer
              .withValues(alpha: 0.7),
        ),
      ),
      onTap: () {
        context.read<SettingsSystemCubit>().requestBatteryOptimizationIgnore();
      },
    );
  }
}
