import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:Echo/services/update_service/update_service.dart';
import 'package:Echo/services/cookie_store.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../generated/l10n.dart';
import '../../themes/text_styles.dart';
import '../../utils/adaptive_widgets/adaptive_widgets.dart';
import 'widgets/color_icon.dart';
import 'widgets/setting_item.dart';
import 'cubit/settings_system_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                  children: [
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
                      title: 'AI Hub',
                      subtitle: 'AI-powered lyrics and translations',
                      leading: const Icon(Icons.auto_awesome),
                      isFirst: true,
                      onTap: () => context.go('/settings/ai'),
                    ),
                    _comingSoonTile(
                      context,
                      title: 'Listening Summary',
                      icon: Icons.bar_chart,
                      feature: 'View your music listening statistics.',
                      isLast: true,
                    ),
                    _comingSoonTile(
                      context,
                      title: 'Echo Wrapped',
                      icon: Icons.auto_stories,
                      feature: 'Your year in sound & personal music recap.',
                      isLast: true,
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
                      onTap: () => context.go('/explore'),
                    ),
                    SettingTile(
                      title: S.of(context).Language,
                      subtitle: 'Language, region, and providers',
                      leading: const Icon(Icons.language),
                      isLast: true,
                      onTap: () => context.go('/settings/services/ytmusic'),
                    ),

                    GroupTitle(title: "Social & privacy"),
                    _comingSoonTile(
                      context,
                      title: 'Listen Together',
                      icon: Icons.groups_outlined,
                      feature: 'Sync playback with friends over the network.',
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
                      isLast: true,
                      onTap: () => context.go('/settings/services/ytmusic'),
                    ),

                    GroupTitle(title: "Integrations"),
                    _comingSoonTile(
                      context,
                      title: 'Discord Rich Presence',
                      icon: Icons.discord,
                      feature: 'Show what you are listening to in Discord.',
                    ),
                    _comingSoonTile(
                      context,
                      title: 'Last.fm / ListenBrainz',
                      icon: Icons.audiotrack,
                      feature: 'Scrobble your listening history.',
                    ),
                    _comingSoonTile(
                      context,
                      title: 'Jellyfin / Navidrome',
                      icon: Icons.cloud_outlined,
                      feature: 'Connect to your self-hosted music server.',
                      isLast: true,
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
                      onTap: () async {
                        await UpdateService.manualCheck(context);
                      },
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

extension _SettingsPageHelpers on SettingsPage {
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
