import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/core/theme/motion_tokens.dart';

void main() {
  test('detail pages belong to the matching shell branch', () {
    final src = File('lib/utils/router.dart').readAsStringSync();

    // These pages used to be their own StatefulShellBranch, which made the
    // floating nav highlight "Settings" (index clamped to 3) on every detail.
    final standalone = RegExp(
      r"StatefulShellBranch\([\s\S]{0,400}?path: '/(album|artist|playlist|account|cast|device_link)'",
    ).allMatches(src);
    expect(standalone, isEmpty,
        reason: 'detail routes must stay inside one of the four main branches');

    final settingsStart = src.indexOf("path: '/settings'");
    final account = src.indexOf("path: '/account'");
    final cast = src.indexOf("path: '/cast'");
    expect(settingsStart, greaterThan(0));
    expect(account, greaterThan(settingsStart));
    expect(cast, greaterThan(settingsStart));

    final savedStart = src.indexOf("path: '/saved'");
    final playlist = src.indexOf("path: '/playlist'");
    expect(savedStart, greaterThan(0));
    expect(playlist, greaterThan(savedStart));
    expect(playlist, lessThan(settingsStart));

    final homeStart = src.indexOf("path: '/',");
    final album = src.indexOf("path: '/album'");
    expect(album, greaterThan(homeStart));
    expect(album, lessThan(savedStart));
  });

  test('page transitions use the shared motion tokens', () {
    final trans = File('lib/utils/page_transitions.dart').readAsStringSync();
    expect(trans, contains('MotionTokens.page'));
    expect(trans, contains('FadeTransition'));
    expect(trans, contains('SlideTransition'));
    expect(trans, contains('CurvedAnimation'));

    final nav = File('lib/core/widgets/floating_nav.dart').readAsStringSync();
    expect(nav, contains('MotionTokens.micro'));
    expect(nav, contains('AnimatedSwitcher'));
    expect(nav, contains('d.selectedIcon'),
        reason: 'selected icon must actually be used');

    final home = File('lib/screens/home/home_page.dart').readAsStringSync();
    expect(home, contains('_HomeSkeleton'));
    expect(home, contains('TweenAnimationBuilder'));
    expect(home, contains('MotionTokens.section'));

    final shell =
        File('lib/screens/shell/echo_shell_chrome.dart').readAsStringSync();
    expect(shell, contains('AnimatedSize'));

    expect(MotionTokens.page.inMilliseconds,
        greaterThan(MotionTokens.micro.inMilliseconds));
    expect(MotionTokens.section, greaterThan(MotionTokens.page));
    expect(MotionTokens.standard, isA<Curve>());

    final audio = File('lib/services/audio_fallback.dart').readAsStringSync();
    expect(audio, contains('restartWithAudio'));
    expect(audio, contains("remove('ECHO_NO_AUDIO')"));
    final appShell =
        File('lib/screens/shell/app_shell.dart').readAsStringSync();
    expect(appShell, contains('Riavvia con audio'));

    final remote =
        File('lib/services/remote_control_service.dart').readAsStringSync();
    expect(remote, contains('Future<String> _lanIp() => lanIp()'));

    final settings =
        File('lib/screens/settings/settings_page.dart').readAsStringSync();
    expect(settings, contains('onTap: () => context.push(route)'),
        reason: 'Settings tiles must keep the previous route for Back');
    expect(settings, isNot(contains("title: 'Podcasts'")),
        reason: 'Podcasts removed from More from mobile');

    final flow = File(
      'lib/screens/explore/music_flow_feed_page.dart',
    ).readAsStringSync();
    expect(flow, contains('context.pop()'));
    expect(flow, contains('AnimatedContainer'));
    expect(flow, contains('TweenAnimationBuilder'));

    final browsing = File('lib/ytmusic/mixins/browsing.dart').readAsStringSync();
    expect(browsing, contains("containers['sectionListContinuation']"),
        reason: 'real playlist continuations arrive as sectionListContinuation');
    expect(browsing, contains('getContinuationString(rawNext)'),
        reason: 'bare tokens are ignored by YouTube');
    expect(browsing, contains('_playlistCache'),
        reason: 'big playlists must be cached between opens');
    expect(browsing, contains('onBatch'),
        reason: 'first batch must render before all continuations finish');
    expect(browsing, contains('_newSongs'),
        reason: 'continuation pages repeat songs and must be deduplicated');
    expect(browsing, contains('declaredSongCount'),
        reason: 'must stop at the song count declared by YouTube');
    expect(browsing, contains('removeRange(declared, result.length)'),
        reason: 'the last continuation page can overshoot the declared count');
    expect(browsing, contains("sendRequest('browse', {'continuation': token})"),
        reason: 'Android sends the continuation in the POST body, not the URL');
    expect(browsing, contains('appendContinuationItemsAction'),
        reason: 'playlist shelf continuations use onResponseReceivedActions');
    expect(browsing, contains('belongsToPlaylist'),
        reason: 'foreign recommended videos must be rejected before parsing');

    final page =
        File('lib/screens/detail/playlist_page.dart').readAsStringSync();
    expect(page, contains('playAll(songs, index: index)'),
        reason: 'tapping a track must queue the whole playlist');
    expect(page, isNot(contains('mediaPlayer.playSong')),
        reason: 'playlist rows must not create a one-song queue');

    final mp = File('lib/services/media_player.dart').readAsStringSync();
    expect(mp, contains('Monotonic generation for every user-initiated play'));
    expect(mp, contains('await _player.play();'),
        reason: 'playAll must await play before touching the queue');
    expect(mp, contains('generation != _playGeneration'),
        reason: 'stale play requests must be discarded');
    expect(mp, contains('setAudioSources(sources, initialIndex: start)'),
        reason: 'the whole playlist must become the queue at the tapped index');
    expect(mp, contains('await _player.clearAudioSources()'),
        reason: 'old queue must be removed before starting a playlist');
    final resolver =
        File('lib/services/stream_resolver.dart').readAsStringSync();
    expect(resolver, contains('for (var attempt = 0; attempt < 2; attempt++)'),
        reason: 'transient resolution failures must be retried');

    final mainSrc = File('lib/main.dart').readAsStringSync();
    expect(mainSrc, contains('_installErrorHandlers'));
    expect(mainSrc, contains('ErrorWidget.builder'));
    expect(mainSrc, contains('PlatformDispatcher.instance.onError'));

    final audit = File('docs/UI_PARITY_AUDIT.md').readAsStringSync();
    for (final area in [
      'HomeScreen.kt',
      'PlayerScreen.kt',
      'LibraryScreen.kt',
      'OnlinePlaylistScreen.kt',
      'SearchScreen.kt',
      'CastButton.kt',
    ]) {
      expect(audit, contains(area), reason: 'UI audit missing $area');
    }
    expect(
        File('docs/ui_parity_contact_sheet.png').existsSync(),
        isTrue,
        reason: 'runtime screenshots for the audited interfaces are required');
    final settingsSrc =
        File('lib/screens/settings/settings_page.dart').readAsStringSync();
    expect(settingsSrc, contains("title: 'AI lyrics & translation'"));
    final player =
        File('lib/screens/player/player_page.dart').readAsStringSync();
    expect(player, contains('TextScrollMode.bouncing'));
    expect(player, contains('height: 38'),
        reason: 'marquee must not overlap artwork/lyrics');

    final thumb = File('lib/utils/song_thumbnail.dart').readAsStringSync();
    expect(thumb, contains("thumbnails.first['url']"),
        reason: 'artwork is still used when present');
    expect(thumb, contains('baseUrl.isEmpty'));
  });
}
