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

    final mainSrc = File('lib/main.dart').readAsStringSync();
    expect(mainSrc, contains('_installErrorHandlers'));
    expect(mainSrc, contains('ErrorWidget.builder'));
    expect(mainSrc, contains('PlatformDispatcher.instance.onError'));

    final thumb = File('lib/utils/song_thumbnail.dart').readAsStringSync();
    expect(thumb, contains("thumbnails.first['url']"),
        reason: 'artwork is still used when present');
    expect(thumb, contains('baseUrl.isEmpty'));
  });
}
