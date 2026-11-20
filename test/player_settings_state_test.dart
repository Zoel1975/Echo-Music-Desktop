import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/screens/settings/player/cubit/player_settings_cubit.dart';
import 'package:Echo/services/audio_device_service.dart';

void main() {
  group('PlayerSettingsLoaded (desktop Player settings)', () {
    PlayerSettingsLoaded build() => const PlayerSettingsLoaded(
          skipSilence: false,
          showSeekButtons: false,
          crossfadeEnabled: false,
          crossfadeDuration: 5,
          dataSaver: false,
          streamingQuality: null,
          audioNormalization: true,
          loudnessGain: 0,
          castEnabled: true,
          remoteControlEnabled: false,
          audioDeviceId: 'auto',
          audioDevices: [
            AudioDeviceEntry(id: 'auto', name: 'System default'),
            AudioDeviceEntry(id: '{1}', name: 'Speakers'),
          ],
        );

    test('carries every wireless/DSP setting (page is not empty)', () {
      final s = build();
      expect(s.showSeekButtons, isFalse);
      expect(s.crossfadeDuration, 5);
      expect(s.dataSaver, isFalse);
      expect(s.audioNormalization, isTrue);
      expect(s.castEnabled, isTrue);
      expect(s.audioDevices.length, 2);
    });

    test('copyWith updates each field independently', () {
      final s = build();
      expect(s.copyWith(dataSaver: true).dataSaver, isTrue);
      expect(s.copyWith(crossfadeEnabled: true).crossfadeEnabled, isTrue);
      expect(s.copyWith(remoteControlEnabled: true).remoteControlEnabled, isTrue);
      expect(s.copyWith(audioDeviceId: '{1}').audioDeviceId, '{1}');
      expect(s.copyWith(audioDevices: const []).audioDevices, isEmpty);
    });
  });
}
