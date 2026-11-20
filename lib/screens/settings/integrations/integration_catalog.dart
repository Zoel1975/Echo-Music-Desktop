import 'package:flutter/material.dart';

/// A single persisted setting field on an integration screen.
class IntegrationField {
  const IntegrationField.text(
    this.key,
    this.label, {
    this.fallback = '',
    this.obscure = false,
    this.help,
  })  : type = IntegrationFieldType.text,
        options = null,
        toggleFallback = false;

  const IntegrationField.toggle(
    this.key,
    this.label, {
    this.toggleFallback = false,
    this.help,
  })  : type = IntegrationFieldType.toggle,
        options = null,
        obscure = false,
        fallback = '';

  const IntegrationField.choice(
    this.key,
    this.label,
    this.options, {
    this.fallback = '',
    this.help,
  })  : type = IntegrationFieldType.choice,
        obscure = false,
        toggleFallback = false;

  final String key;
  final String label;
  final IntegrationFieldType type;
  final String fallback;
  final bool obscure;
  final bool toggleFallback;
  final List<String>? options;
  final String? help;
}

enum IntegrationFieldType { text, toggle, choice }

/// A settings screen for one mobile integration. Port of the Android screens
/// `DiscordSettings.kt`, `LastFMSettingsScreen.kt`, `JellyfinScreens.kt`,
/// `NavidromeScreens.kt`, `ListenTogetherSettings.kt`, `ExtensionSettings.kt`.
class IntegrationScreen {
  const IntegrationScreen(this.route, this.title, this.icon, this.fields);

  final String route;
  final String title;
  final IconData icon;
  final List<IntegrationField> fields;
}

class IntegrationCatalog {
  IntegrationCatalog._();

  static const screens = [
    IntegrationScreen('discord', 'Discord Rich Presence', Icons.discord, [
      IntegrationField.toggle('discordEnabled', 'Enable Discord RPC',
          toggleFallback: false),
      IntegrationField.text('discordToken', 'User token', obscure: true),
      IntegrationField.choice('discordActivityType', 'Activity type',
          ['Listening', 'Playing', 'Streaming', 'Watching'],
          fallback: 'Listening'),
      IntegrationField.text('discordActivityName', 'Activity name',
          fallback: 'Echo Music'),
      IntegrationField.toggle('discordShowPaused', 'Show when paused'),
    ]),
    IntegrationScreen('lastfm', 'Last.fm / ListenBrainz', Icons.audiotrack, [
      IntegrationField.text('lastfmUsername', 'Last.fm username'),
      IntegrationField.text('lastfmApiKey', 'Last.fm API key', obscure: true),
      IntegrationField.toggle('lastfmScrobble', 'Enable scrobbling'),
      IntegrationField.toggle('lastfmNowPlaying', 'Send Now Playing'),
      IntegrationField.toggle('lastfmLikes', 'Send Likes/Unlikes'),
      IntegrationField.text('listenbrainzToken', 'ListenBrainz token',
          obscure: true),
      IntegrationField.toggle('listenbrainzScrobble',
          'ListenBrainz scrobbling'),
    ]),
    IntegrationScreen('jellyfin', 'Jellyfin / Navidrome', Icons.cloud, [
      IntegrationField.choice('cloudType', 'Server type', ['Jellyfin', 'Navidrome'],
          fallback: 'Jellyfin'),
      IntegrationField.text('jellyfinUrl', 'Server URL'),
      IntegrationField.text('jellyfinUser', 'Username'),
      IntegrationField.text('jellyfinPass', 'Password', obscure: true),
      IntegrationField.text('navidromeUrl', 'Navidrome URL'),
      IntegrationField.toggle('cloudSync', 'Sync library on launch'),
    ]),
    IntegrationScreen('listen_together', 'Listen Together', Icons.groups, [
      IntegrationField.text('ltUsername', 'Username', fallback: 'Listener'),
      IntegrationField.toggle('ltAutoApprove', 'Auto-approve join requests'),
      IntegrationField.text('ltServer', 'Sync server URL'),
      IntegrationField.toggle('ltTopBar', 'Show in top bar'),
    ]),
    IntegrationScreen('extensions', 'Extensions & high-quality servers',
        Icons.extension, [
      IntegrationField.toggle('preferExtension', 'Prefer extension audio'),
      IntegrationField.toggle('highQuality', 'High quality (320 kbps)'),
      IntegrationField.text('extensionServer', 'Custom server URL'),
    ]),
    IntegrationScreen('song_dna', 'Song DNA', Icons.biotech, [
      IntegrationField.toggle('songDnaEnabled', 'Show Song DNA in player'),
      IntegrationField.text('geniusToken', 'Genius API token', obscure: true),
      IntegrationField.text('wikipediaLang', 'Wikipedia language',
          fallback: 'en'),
    ]),
  ];

  static IntegrationScreen? byRoute(String route) {
    for (final s in screens) {
      if ('/${s.route}' == route || s.route == route) return s;
    }
    return null;
  }
}
