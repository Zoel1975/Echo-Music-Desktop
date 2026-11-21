import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';

/// True when mpv runs without an audio output because the system endpoint was
/// busy/unavailable (or the previous launch died while opening it).
final ValueNotifier<bool> audioFallback = ValueNotifier<bool>(false);

/// Prepares the audio subsystem so a busy WASAPI endpoint cannot kill startup.
///
/// On Windows, libmpv's `ao/wasapi` fails with `AUDCLNT_E_DEVICE_IN_USE` when
/// another program (e.g. a DAW using exclusive mode) holds the endpoint, and
/// media_kit then crashes natively (0xC0000005). libmpv has a built-in safe
/// mode (`NativePlayer.test`) that sets `ao=null`/`vo=null`; we enable it when:
///
///  * `ECHO_NO_AUDIO=1` is set explicitly, or
///  * the previous launch left the `audio_init_pending` marker, meaning it died
///    before startup completed.
///
/// The marker is removed after 30 seconds of a healthy run, so a normally
/// working installation always starts with real audio again.
Future<bool> prepareAudioFallback() async {
  final support = await getApplicationSupportDirectory();
  final marker = File(
    '${support.path}${Platform.pathSeparator}audio_init_pending',
  );
  final explicitlyRequested = Platform.environment['ECHO_NO_AUDIO'] == '1';
  final previousCrash = marker.existsSync();
  final enabled = explicitlyRequested || previousCrash;

  await marker.writeAsString(DateTime.now().toIso8601String());
  if (enabled) {
    JustAudioMediaKit.silentFallback = true;
    audioFallback.value = true;
  }
  Timer(const Duration(seconds: 30), () {
    try {
      if (marker.existsSync()) marker.deleteSync();
    } catch (_) {
      // A stale marker only costs one silent launch; never crash for it.
    }
  });
  return enabled;
}

/// Leave silent mode for good: restart the app as a detached process without
/// `ECHO_NO_AUDIO`, so a fresh mpv instance opens the real audio endpoint.
/// Used by the home banner action - being stuck muted with no explanation was
/// the worst part of the old fallback.
Future<void> restartWithAudio() async {
  try {
    final environment = Map<String, String>.from(Platform.environment)
      ..remove('ECHO_NO_AUDIO');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      environment: environment,
      mode: ProcessStartMode.detached,
    );
    exit(0);
  } catch (_) {
    // If the OS refuses the restart the user can still close and reopen.
  }
}
