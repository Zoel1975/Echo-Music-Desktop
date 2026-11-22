import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_manager.dart';
import '../widgets/setting_item.dart';
import '../widgets/settings_list.dart';
import '../../../../core/widgets/back_button.dart';

/// Real port of Android `ContentSettings.kt` (General + Lyrics groups):
/// content filters and lyrics romanization. Proxy / IP version are Android
/// networking features with no desktop equivalent -> coming soon placeholders.
class ContentPage extends StatelessWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsManager>();
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Content')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              const SettingNoticeTile(
                message: 'Filtri contenuto, romanizzazione e lingua sono importati '
                    'dall\'app Android e non filtrano ancora i risultati desktop.',
              ),
              const GroupTitle(title: 'Privacy'),
              SettingTile(
                title: 'Blocked Artists',
                subtitle: 'Manage hidden artists',
                leading: const Icon(Icons.person_off),
                isFirst: true,
                onTap: () => context.go('/settings/content/blocked_artists'),
              ),
              SettingTile(
                title: 'Disliked Songs',
                subtitle: 'Manage songs you dislike',
                leading: const Icon(Icons.heart_broken),
                isLast: true,
                onTap: () => context.go('/settings/content/disliked_songs'),
              ),
              const GroupTitle(title: 'General'),
              SettingSwitchTile(
                title: 'Hide explicit content',
                leading: const Icon(Icons.explicit),
                isFirst: true,
                value: s.hideExplicit,
                onChanged: (v) => s.hideExplicit = v,
              ),
              SettingSwitchTile(
                title: 'Hide video songs',
                leading: const Icon(Icons.music_video),
                value: s.hideVideoSongs,
                onChanged: (v) => s.hideVideoSongs = v,
              ),
              SettingSwitchTile(
                title: 'Hide YouTube Shorts',
                leading: const Icon(Icons.smart_display),
                value: s.hideYouTubeShorts,
                onChanged: (v) => s.hideYouTubeShorts = v,
              ),
              SettingSwitchTile(
                title: 'SponsorBlock (auto-skip)',
                subtitle: 'Skip sponsored segments in videos',
                leading: const Icon(Icons.block),
                isLast: true,
                value: s.sponsorBlock,
                onChanged: (v) => s.sponsorBlock = v,
              ),

              const GroupTitle(title: 'Region'),
              SettingTile(
                title: 'Default content language',
                subtitle: s.contentLanguage,
                leading: const Icon(Icons.language),
                isFirst: true,
                trailing: DropdownButton<String>(
                  value: s.contentLanguage,
                  underline: const SizedBox(),
                  items: const ['en', 'es', 'it', 'hi', 'tr', 'fr', 'de']
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) s.contentLanguage = v;
                  },
                ),
              ),
              SettingTile(
                title: 'Default content country',
                subtitle: s.contentCountry,
                leading: const Icon(Icons.public),
                isLast: true,
                trailing: DropdownButton<String>(
                  value: s.contentCountry,
                  underline: const SizedBox(),
                  items: const ['US', 'IT', 'GB', 'IN', 'DE', 'FR', 'ES']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) s.contentCountry = v;
                  },
                ),
              ),

              const GroupTitle(title: 'Lyrics'),
              SettingSwitchTile(
                title: 'Lyrics romanization',
                leading: const Icon(Icons.translate),
                isFirst: true,
                value: s.lyricsRomanization,
                onChanged: (v) => s.lyricsRomanization = v,
              ),
              SettingSwitchTile(
                title: 'Show romanized lyrics as main',
                leading: const Icon(Icons.text_fields),
                isLast: true,
                value: s.romanizeAsMain,
                onChanged: (v) => s.romanizeAsMain = v,
              ),

              const GroupTitle(title: 'Network'),
              _soon(context, 'Network IP version', 'Force IPv4 / IPv6 on Android'),
              _soon(context, 'Enable proxy', 'Route requests through a proxy server',
                  isLast: true),
              const SizedBox(height: 100),
            ],
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
      onTap: () => Navigator.of(context).pop(),
    );
  }
}
