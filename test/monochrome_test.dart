import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/extension_quality.dart';
import 'package:Echo/services/monochrome_service.dart';
import 'package:Echo/services/settings_manager.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  const sample = '''
{
  "tracks": [
    {
      "id": 221078857590341632,
      "title": "Harpsichord Suite No. 7 in G minor: Passacaglia",
      "artistNames": ["Handel"],
      "duration": 332693,
      "isrc": "DEF057303286"
    },
    {
      "title": "No id must be skipped",
      "artistNames": []
    }
  ]
}
''';

  test('Monochrome search parser returns usable FLAC track URLs', () {
    final tracks = MonochromeService.parseSearch(sample);
    expect(tracks, hasLength(1));
    final t = tracks.first;
    expect(t.id, '221078857590341632');
    expect(t.artist, 'Handel');
    expect(t.durationMs, 332693);
    expect(t.isrc, 'DEF057303286');
    expect(t.streamUrl,
        'https://tracks.monochrome.st/track/221078857590341632');
  });

  test('FLAC is a selectable audio quality in settings and wins over 320kbps',
      () {
    expect(AudioQuality.values, contains(AudioQuality.flac));
    expect(
      ExtensionQuality.resolve(
        dataSaver: false,
        highQuality: false,
        configured: 'flac',
      ),
      'flac',
      reason: 'an explicit FLAC choice must reach the Monochrome resolver',
    );
    expect(
      ExtensionQuality.resolve(
        dataSaver: true,
        highQuality: true,
        configured: 'flac',
      ),
      'low',
      reason: 'Data Saver always wins, including over FLAC',
    );
    expect(
      ExtensionQuality.resolve(
        dataSaver: false,
        highQuality: false,
        configured: 'high',
      ),
      'high',
    );
  });

  test('player resolves songs through Monochrome with a YouTube fallback', () {
    final player = _read('lib/services/media_player.dart');
    expect(player, contains("quality == 'flac'"));
    expect(player, contains('MonochromeService.findBySong(song)'));
    expect(player, contains('MonochromeAudioSource('));

    final settingsUi =
        _read('lib/screens/settings/player/player_settings_page.dart');
    expect(settingsUi, contains('FLAC (Monochrome)'));

    final source = _read('lib/services/monochrome_audio_source.dart');
    expect(source, contains("'Range': 'bytes="));
    expect(source, contains("contentType: 'audio/flac'"));
    expect(source, contains('YouTubeAudioSource('),
        reason: 'an unavailable FLAC must fall back to YouTube');
  });
}
