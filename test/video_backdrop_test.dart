import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video backdrop is opt-in and isolated from the audio backend', () {
    final service = File('lib/services/video_backdrop_service.dart')
        .readAsStringSync();
    expect(service, contains('WinVideoPlayerController'));
    expect(service, contains('setVolume(0)'));
    expect(service, contains("extra<bool>('videoBackdropBeta', false)"));
    expect(service, contains('Platform.isWindows'));
    expect(service, contains('yt.close()'));
    expect(service, contains('nonVideoWords'));
    expect(service, contains("filter: 'videos'"));
    expect(service, contains('2500'));
    expect(service, contains('5000'));
    expect(service, isNot(contains('mixer.seekBy(')));
    // Never touches MediaPlayer.play/pause/seek or the stem players.
    expect(service, isNot(contains('.player.play()')));
    expect(service, isNot(contains('.player.pause()')));
    expect(service, isNot(contains('mixer.setPlaying(')));

    final widget = File('lib/screens/player/widgets/video_backdrop.dart')
        .readAsStringSync();
    expect(widget, contains('WinVideoPlayer(controller)'));
    expect(widget, contains('IgnorePointer'));
    expect(widget, contains('Opacity('));

    final page = File('lib/screens/player/player_page.dart').readAsStringSync();
    expect(page, contains('VideoBackdropService.instance.attach()'));
    expect(page, contains('VideoBackdropService.instance.detach()'));
    expect(page, contains('const Positioned.fill(child: VideoBackdrop())'));

    final settings =
        File('lib/screens/settings/player/player_settings_page.dart')
            .readAsStringSync();
    expect(settings, contains("'videoBackdropBeta'"));
    expect(settings, contains('S.of(context).VideoBackdropBetaNote'));

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('video_player_win:'));
  });
}
