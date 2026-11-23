import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/po_token_minter.dart';
import 'package:Echo/services/stream_resolver.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  group('BotGuard PoToken (mobile port)', () {
    test('descramble adds 97 to each decoded byte', () {
      final original = utf8.encode('{"hello":"world"}');
      final scrambled = base64Encode(original.map((b) => (b - 97) & 0xff).toList());
      expect(utf8.decode(PoTokenMinter.descramble(scrambled)),
          '{"hello":"world"}');
    });

    test('YouTube base64 accepts dot padding and URL-safe alphabet', () {
      final encoded = base64Encode([1, 2, 3, 4])
          .replaceAll('+', '-')
          .replaceAll('/', '_')
          .replaceAll('=', '.');
      expect(PoTokenMinter.youTubeBase64(encoded), [1, 2, 3, 4]);
    });

    test('PoToken base64 is URL-safe', () {
      final token = PoTokenMinter.poTokenToBase64([255, 254, 253]);
      expect(token, isNot(contains('+')));
      expect(token, isNot(contains('/')));
    });

    test('challenge parser builds the BotGuard JS shape', () {
      final inner = jsonEncode([
        'msg',
        ['interpreter-js'],
        ['trusted-url'],
        'hash',
        'program',
        'bgGlobal',
        'x',
        'blob',
      ]);
      final scrambled =
          base64Encode(utf8.encode(inner).map((b) => (b - 97) & 0xff).toList());
      final parsed = PoTokenMinter.parseChallenge(
        jsonEncode(['envelope', scrambled]),
      );
      expect(parsed['globalName'], 'bgGlobal');
      expect(parsed['program'], 'program');
      expect(parsed['interpreterJavascript']
              ['privateDoNotAccessOrElseSafeScriptWrappedValue'],
          'interpreter-js');
    });
  });

  group('InnerTube player request matches mobile', () {
    final resolver = StreamResolver.instance;

    test('PoToken is top-level serviceIntegrityDimensions', () {
      resolver.savePoToken('age-test', player: 'TOKEN', gvs: 'TOKEN');
      final body = resolver.buildBody(YtPlayerClient.webRemix, 'age-test');
      expect(body['serviceIntegrityDimensions'], {'poToken': 'TOKEN'});
      final context = body['playbackContext'] as Map<String, dynamic>;
      final pcc = context['contentPlaybackContext'] as Map<String, dynamic>;
      expect(pcc.containsKey('poToken'), isFalse);
      expect(body['contentCheckOk'], true);
      expect(body['racyCheckOk'], true);
    });

    test('WEB_CREATOR uses studio origin and mobile headers', () {
      final headers = resolver.buildHeaders(YtPlayerClient.webCreator);
      expect(headers['Origin'], 'https://studio.youtube.com');
      expect(headers['Referer'], 'https://studio.youtube.com/');
      expect(headers['X-Goog-Api-Format-Version'], '1');
      expect(headers['X-Origin'], headers['Origin']);
      expect(headers['Accept-Language'], isNotEmpty);
      expect(src('lib/services/stream_resolver.dart'),
          contains("headers['X-Goog-Visitor-Id'] = visitor"));
    });

    test('client versions and URL include the mobile fields', () {
      expect(YtPlayerClient.webRemix.version, '1.20260707.12.00');
      expect(YtPlayerClient.webCreator.version, '1.20260708.06.00');
      expect(YtPlayerClient.webEmbedded.version, '2.20260708.00.00');
      final source = src('lib/services/stream_resolver.dart');
      expect(source, contains('_studioPlayerUrl'));
      expect(source, contains("params['cpn']"));
    });
  });
}
