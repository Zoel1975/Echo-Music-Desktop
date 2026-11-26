import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/google_login_service.dart';
import 'package:Echo/services/stream_resolver.dart';

void main() {
  test('parses poToken from a CDP player request body', () {
    const body =
        '{"videoId":"esHBHhbDQh4","playbackContext":{"contentPlaybackContext":{"poToken":"ABC123"}}}';
    expect(GoogleLoginService.poTokenFromPlayerRequest(body), 'ABC123');
    expect(
      GoogleLoginService.poTokenFromPlayerRequest('{"videoId":"x"}'),
      isNull,
    );
    expect(GoogleLoginService.poTokenFromPlayerRequest('not json'), isNull);
  });

  test('parses the GVS pot query parameter from a googlevideo URL', () {
    expect(
      GoogleLoginService.gvsTokenFromUrl(
          'https://rr1---sn.googlevideo.com/videoplayback?itag=251&pot=XYZ%3D'),
      'XYZ=',
    );
    expect(
      GoogleLoginService.gvsTokenFromUrl(
          'https://rr1---sn.googlevideo.com/videoplayback?itag=251'),
      isNull,
    );
  });

  test('GVS token is appended to the stream URL without losing metadata', () {
    const stream = ResolvedStream(
      url: 'https://rr1---sn.googlevideo.com/videoplayback?itag=251',
      mimeType: 'audio/webm; codecs=opus',
      contentLength: 1234,
      bitrate: 160000,
      client: 'WEB_CREATOR',
      loudnessDb: -12.5,
    );
    final withPot = StreamResolver.withGvsPot(stream, 'TOKEN=');
    expect(Uri.parse(withPot.url).queryParameters['pot'], 'TOKEN=');
    expect(Uri.parse(withPot.url).queryParameters['itag'], '251');
    expect(withPot.mimeType, stream.mimeType);
    expect(withPot.bitrate, stream.bitrate);
    expect(withPot.loudnessDb, stream.loudnessDb);
    expect(StreamResolver.withGvsPot(stream, null), same(stream));
  });

  test('WEB_CREATOR client is in the age-gate fallback chain', () {
    expect(YtPlayerClient.webCreator.id, '62');
    expect(YtPlayerClient.webCreator.name, 'WEB_CREATOR');
    expect(YtPlayerClient.fallbackOrder, contains(YtPlayerClient.webCreator));
  });

  test('age gate captures PoTokens and retries InnerTube clients', () {
    final resolver =
        File('lib/services/stream_resolver.dart').readAsStringSync();
    expect(resolver, contains('capturePoToken(videoId)'));
    expect(resolver, contains('savePoToken('));
    expect(resolver, contains('allowPoTokenCapture: false'));
    expect(resolver, contains("'pot'"));
    expect(resolver, contains('withGvsPot('));

    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("Hive.openBox('POTOKENS')"));
    expect(main, contains('StreamResolver.instance.loadPoTokens()'));
  });
}
