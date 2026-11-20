import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup cannot be aborted by a busy WASAPI endpoint', () {
    final main = File('lib/main.dart').readAsStringSync();
    final prepare = main.indexOf('await prepareAudioFallback()');
    final audioInit = main.indexOf('JustAudioMediaKit.ensureInitialized()');
    expect(prepare, greaterThanOrEqualTo(0));
    expect(audioInit, greaterThan(prepare),
        reason: 'safe mode must be chosen before any mpv player is created');

    final fallback = File('lib/services/audio_fallback.dart').readAsStringSync();
    expect(fallback, contains("Platform.environment['ECHO_NO_AUDIO'] == '1'"));
    expect(fallback, contains('audio_init_pending'));
    expect(fallback, contains('JustAudioMediaKit.silentFallback = true'));

    final kit = File(
      'packages/just_audio_media_kit/lib/just_audio_media_kit.dart',
    ).readAsStringSync();
    expect(kit, contains('static bool silentFallback = false;'));
    expect(kit, contains('if (silentFallback) NativePlayer.test = true;'),
        reason: 'mpv built-in ao=null/vo=null mode is the only safe fallback');
  });

  test('runtime probe is loopback-only and opt-in', () {
    final src = File('lib/services/runtime_probe_service.dart').readAsStringSync();
    expect(src, contains('HttpServer.bind(InternetAddress.loopbackIPv4, 0)'));
    expect(src, contains('InternetAddress.loopbackIPv4'));
    expect(src, contains('SessionService().signOut()'),
        reason: 'probe must exercise the same code as the UI button');
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("Platform.environment['ECHO_DIAG'] == '1'"));
  });
}
