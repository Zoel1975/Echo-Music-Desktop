import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/echo_brain_service.dart';
import 'package:Echo/services/axion_eq_service.dart';

void main() {
  group('EchoBrainService (AI playlists)', () {
    test('builds a chat request with model and messages', () {
      final r = EchoBrainService.buildRequest(
        systemPrompt: 'curate', userPrompt: 'focus playlist', model: 'm');
      expect(r['model'], 'm');
      final messages = r['messages'] as List;
      expect(messages.length, 2);
      expect(messages.first['role'], 'system');
      expect(messages.last['content'], contains('focus'));
    });

    test('parses assistant content from choices', () {
      final content = EchoBrainService.parseContent({
        'choices': [
          {'message': {'content': '  Artist - Title  '}},
        ],
      });
      expect(content, 'Artist - Title');
      expect(EchoBrainService.parseContent({}), '');
    });

    test('parses Artist - Title lines, ignoring commentary', () {
      final tracks = EchoBrainService.parseTracks(
        '1. Daft Punk - Harder Better Faster\n'
        'Some commentary here\n'
        '2. Tame Impala - The Less I Know\n',
      );
      expect(tracks.length, 2);
      expect(tracks.first['artist'], 'Daft Punk');
      expect(tracks.first['title'], 'Harder Better Faster');
      expect(tracks.last['artist'], 'Tame Impala');
    });
  });

  group('AxionEqService (AutoEq)', () {
    test('presets are 10-band and within range', () {
      for (final p in AxionEqService.presets) {
        expect(p.gains.length, 10);
        expect(p.gains.every((g) => g >= -12 && g <= 12), isTrue);
      }
    });

    test('parses AutoEq profile text into 10 bands', () {
      final profile = 'Preamp: -6 dB\n'
          'Filter 1: ON PK Fc 60 Hz Gain -4.5 dB Q 1.0\n'
          'Filter 2: ON PK Fc 3000 Hz Gain 3.0 dB Q 1.0\n';
      final gains = AxionEqService.parseAutoEqProfile(profile);
      expect(gains.length, 10);
      expect(gains[1], closeTo(-4.5, 1e-9)); // 60Hz -> 62Hz band (index 1)
      expect(gains[6], closeTo(3.0, 1e-9)); // 3000Hz -> 2000 band
    });

    test('preset serializes and round-trips', () {
      final p = AxionEqService.presets.first;
      final decoded = AxionEqService.decodePreset(AxionEqService.encodePreset(p));
      expect(decoded.name, p.name);
      expect(decoded.gains, p.gains);
    });

    test('exports AutoEq-style text', () {
      final text = AxionEqService.toAutoEqText(AxionEqService.presets.first);
      expect(text, contains('Preamp:'));
      expect(text, contains('Fc 31 Hz'));
      expect(text.split('\n').length, greaterThanOrEqualTo(11));
    });
  });
}
