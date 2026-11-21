import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/lyrics.dart';
import 'package:Echo/services/lyrics_providers_more.dart';
import 'package:Echo/services/stream_resolver.dart';

void main() {
  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_media_quality_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    for (final box in ['SETTINGS', 'COOKIES', 'ACCOUNT']) {
      if (!Hive.isBoxOpen(box)) await Hive.openBox(box);
    }
  });

  test('age-gated player requests carry the signed-in identity', () async {
    await Hive.box('COOKIES').put('SAPISID', 'sapisid-value');
    await Hive.box('SETTINGS').put('VISITOR_ID', 'VISITOR-X');
    await CookieStore.instance.saveDataSyncId('DSYNC-X');
    StreamResolver.instance.cookieHeaderProvider =
        () => CookieStore.instance.cookieHeader;

    final headers = StreamResolver.instance.buildHeaders(YtPlayerClient.webEmbedded);
    expect(headers['Cookie'], contains('SAPISID=sapisid-value'));
    expect(headers['Authorization'], startsWith('SAPISIDHASH '));
    expect(headers['X-Goog-Visitor-Id'], 'VISITOR-X');
    expect(headers['X-Goog-AuthUser'], '0');

    final body = StreamResolver.instance.buildBody(
      YtPlayerClient.webEmbedded,
      'video1',
    );
    final context = body['context'] as Map;
    expect((context['client'] as Map)['visitorData'], 'VISITOR-X');
    expect((context['user'] as Map)['onBehalfOfUser'], 'DSYNC-X');
    expect((context['client'] as Map)['thirdParty']['embedUrl'],
        'https://www.youtube.com/');
    expect(YtPlayerClient.fallbackOrder, contains(YtPlayerClient.webEmbedded));
  });

  test('muxed audio formats are considered as well as adaptive ones', () {
    final formats = StreamResolver.audioFormats({
      'streamingData': {
        'formats': [
          {'itag': 18, 'mimeType': 'audio/mpeg', 'url': 'https://a'}
        ],
        'adaptiveFormats': [
          {'itag': 140, 'mimeType': 'audio/mp4', 'url': 'https://b'}
        ],
      }
    });
    expect(formats.map((f) => f['itag']), [140, 18]);
  });

  test('new lyric providers parse their sources', () {
    expect(NeteaseProvider.firstId(NeteaseProvider.songsFrom({
      'result': {'songs': [
        {'id': 42, 'name': 'x'}
      ]}
    })), '42');
    expect(AzLyricsProvider.slug("Il Mio Cuscino!"), 'ilmiocuscino');
    final plain = AzLyricsProvider.extractLyrics(
      '<div class="lyrics">Hello<br>World &amp; you</div>',
    );
    expect(plain, 'Hello\nWorld & you');
    expect(isLrc('[00:12.00]Hello'), isTrue);
    expect(isLrc('Hello'), isFalse);
    expect(LocalLrcProvider.normalize('Il Mio-Cuscino!'), 'il mio cuscino');
    expect(LyricsService.providers.map((p) => p.name),
        containsAll(['Netease', 'AZLyrics', 'LocalLRC']));
  });
}
