import 'package:flutter/material.dart';
import 'package:Echo/generated/l10n.dart';
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
        title: Text(S.of(context).Content)),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              GroupTitle(title: S.of(context).Privacy),
              SettingTile(
                title: S.of(context).BlockedArtists,
                subtitle: S.of(context).ManageHiddenArtists,
                leading: const Icon(Icons.person_off),
                isFirst: true,
                onTap: () => context.go('/settings/content/blocked_artists'),
              ),
              SettingTile(
                title: S.of(context).DislikedSongs,
                subtitle: S.of(context).ManageSongsYouDislike,
                leading: const Icon(Icons.heart_broken),
                isLast: true,
                onTap: () => context.go('/settings/content/disliked_songs'),
              ),
              GroupTitle(title: S.of(context).General),
              SettingSwitchTile(
                title: S.of(context).HideExplicitContent,
                leading: const Icon(Icons.explicit),
                isFirst: true,
                value: s.hideExplicit,
                onChanged: (v) => s.hideExplicit = v,
              ),
              SettingSwitchTile(
                title: S.of(context).HideVideoSongs,
                leading: const Icon(Icons.music_video),
                value: s.hideVideoSongs,
                onChanged: (v) => s.hideVideoSongs = v,
              ),
              SettingSwitchTile(
                title: S.of(context).HideYouTubeShorts,
                leading: const Icon(Icons.smart_display),
                value: s.hideYouTubeShorts,
                onChanged: (v) => s.hideYouTubeShorts = v,
              ),
              SettingSwitchTile(
                title: S.of(context).SponsorBlockAutoSkip,
                subtitle: S.of(context).SkipSponsoredSegmentsInVideos,
                leading: const Icon(Icons.block),
                isLast: true,
                value: s.sponsorBlock,
                onChanged: (v) => s.sponsorBlock = v,
              ),

              GroupTitle(title: S.of(context).Region),
              SettingTile(
                title: S.of(context).DefaultContentLanguage,
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
                title: S.of(context).DefaultContentCountry,
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

              GroupTitle(title: S.of(context).Lyrics),
              SettingSwitchTile(
                title: S.of(context).LyricsRomanization,
                leading: const Icon(Icons.translate),
                isFirst: true,
                value: s.lyricsRomanization,
                onChanged: (v) => s.lyricsRomanization = v,
              ),
              SettingSwitchTile(
                title: S.of(context).ShowRomanizedLyricsAsMain,
                leading: const Icon(Icons.text_fields),
                isLast: true,
                value: s.romanizeAsMain,
                onChanged: (v) => s.romanizeAsMain = v,
              ),

              GroupTitle(title: S.of(context).Network),
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
      subtitle: S.of(context).ComingInAFutureUpdate,
      leading: const Icon(Icons.schedule),
      isLast: isLast,
      trailing: const Icon(Icons.schedule, size: 18),
      onTap: () => Navigator.of(context).pop(),
    );
  }
}
