import 'dart:convert';

import 'package:Echo/services/stream_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formats = [
    {'mimeType': 'audio/webm; codecs="opus"', 'bitrate': 128000, 'url': 'https://example.com/opus', 'contentLength': 1000},
    {'mimeType': 'audio/mp4; codecs="mp4a.40.2"', 'bitrate': 131000, 'url': 'https://example.com/m4a131', 'contentLength': 2000},
    {'mimeType': 'audio/mp4; codecs="mp4a.40.2"', 'bitrate': 50000, 'url': 'https://example.com/m4a50', 'contentLength': 800},
  ];

  group('StreamResolver.pick', () {
    test('prefers m4a formats for desktop playback', () {
      final picked = StreamResolver.pick(formats, 'high', 'VISIONOS');
      expect(picked!.mimeType, contains('audio/mp4'));
      expect(picked.bitrate, 131000);
    });

    test('low quality picks a smaller m4a format', () {
      final picked = StreamResolver.pick(formats, 'low', 'VISIONOS');
      expect(picked!.bitrate, 50000);
    });

    test('ignores cipher-only formats and returns null if none usable', () {
      final cipherOnly = [
        {'mimeType': 'audio/mp4', 'signatureCipher': 's=abc'},
      ];
      expect(StreamResolver.pick(cipherOnly, 'high', 'WEB_REMIX'), isNull);
    });

    test('falls back to any audio format when no m4a exists', () {
      final opusOnly = [
        {'mimeType': 'audio/webm', 'bitrate': 128000, 'url': 'https://example.com/opus'},
      ];
      expect(StreamResolver.pick(opusOnly, 'high', 'VISIONOS')!.mimeType, 'audio/webm');
    });
  });

  group('visitorData (no-login playback)', () {
    test('extracts VISITOR_DATA from a YouTube page', () {
      final html = 'ytcfg.set({"INNERTUBE_API_KEY":"x","VISITOR_DATA":"Cgt123abc"});';
      expect(StreamResolver.extractVisitorData(html), 'Cgt123abc');
    });

    test('decodes escaped visitor tokens', () {
      final html = '"VISITOR_DATA":"Cgt\\u0041bc"';
      expect(StreamResolver.extractVisitorData(html), 'CgtAbc');
    });

    test('returns null when no visitor token present', () {
      expect(StreamResolver.extractVisitorData('<html>nothing</html>'), isNull);
    });

    test('ANDROID client is in the no-login fallback chain', () {
      expect(
        YtPlayerClient.fallbackOrder.map((c) => c.name),
        contains('ANDROID'),
      );
      expect(YtPlayerClient.fallbackOrder.first.name, 'VISIONOS');
    });
  });

  group('StreamResolver.audioFormats', () {
    test('filters out video formats', () {
      final data = {
        'streamingData': {
          'adaptiveFormats': [
            {'mimeType': 'video/mp4', 'url': 'v'},
            {'mimeType': 'audio/mp4', 'url': 'a'},
          ],
        },
      };
      final result = StreamResolver.audioFormats(data);
      expect(result.length, 1);
      expect(result.first['mimeType'], 'audio/mp4');
    });
  });
}
