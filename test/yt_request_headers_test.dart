import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/ytmusic/client.dart';
import 'package:Echo/ytmusic/modals/yt_config.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Captures the exact request the app sends to InnerTube and asserts it matches
/// Android's `InnerTube.ytClient` (`lib/ytmusic/client.dart` +
/// `lib/ytmusic/helpers.dart`).
///
/// No TestWidgetsFlutterBinding on purpose: that binding fakes HTTP, while here
/// we need a real loopback socket to inspect the wire headers.
void main() {
  late HttpServer server;
  late String base;
  Map<String, String> capturedHeaders = {};
  Map<String, dynamic> capturedBody = {};

  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_header_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!Hive.isBoxOpen('COOKIES')) await Hive.openBox('COOKIES');
    if (!Hive.isBoxOpen('ACCOUNT')) await Hive.openBox('ACCOUNT');

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      capturedHeaders = {};
      request.headers.forEach((name, values) {
        capturedHeaders[name.toLowerCase()] = values.join(',');
      });
      final raw = await utf8.decoder.bind(request).join();
      capturedBody = jsonDecode(raw) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"contents":{}}');
      await request.response.close();
    });
  });

  tearDownAll(() async {
    YTClient.baseUrl = YTClient.httpsYtmDomain;
    await server.close(force: true);
  });

  test('signed-in request carries Android InnerTube headers + context', () async {
    await Hive.box('COOKIES').clear();
    await Hive.box('COOKIES').put('SAPISID', 'test-sapisid');
    await Hive.box('COOKIES').put('SID', 'test-sid');
    await Hive.box('SETTINGS').put('VISITOR_ID', 'VISITOR');
    await Hive.box('SETTINGS').put('DATASYNC_ID', 'DSYNC');

    YTClient.baseUrl = base;
    final yt = YTMusic(
      config: YTConfig(visitorData: 'VISITOR', language: 'en', location: 'IT'),
    );
    await yt.refreshHeaders();
    await yt.sendRequest('browse', {'browseId': 'FEmusic_home'});

    expect(capturedHeaders['cookie'], contains('SAPISID=test-sapisid'));
    expect(capturedHeaders['authorization'], startsWith('SAPISIDHASH '));
    expect(capturedHeaders['x-goog-visitor-id'], 'VISITOR');
    expect(capturedHeaders['x-youtube-client-name'], '67');
    expect(capturedHeaders['x-youtube-client-version'], startsWith('1.'));
    expect(capturedHeaders['x-origin'], 'https://music.youtube.com');
    expect(capturedHeaders['referer'], 'https://music.youtube.com/');
    expect(capturedHeaders['x-goog-api-format-version'], '1');
    expect(capturedHeaders.containsKey('content-encoding'), isFalse);

    final context = capturedBody['context'] as Map<String, dynamic>;
    expect((context['client'] as Map)['clientName'], 'WEB_REMIX');
    expect((context['client'] as Map)['visitorData'], 'VISITOR');
    expect((context['user'] as Map)['onBehalfOfUser'], 'DSYNC');
  });

  test('signed-out request sends no Cookie and no Authorization', () async {
    await Hive.box('COOKIES').clear();
    await CookieStore.instance.saveDataSyncId(null);
    YTClient.baseUrl = base;

    final yt = YTMusic(
      config: YTConfig(visitorData: 'VISITOR2', language: 'en', location: 'IT'),
    );
    await yt.refreshHeaders();
    await yt.sendRequest('browse', {'browseId': 'FEmusic_home'});

    expect(capturedHeaders.containsKey('cookie'), isFalse);
    expect(capturedHeaders.containsKey('authorization'), isFalse);
    expect(capturedHeaders['x-goog-visitor-id'], 'VISITOR2');
    final context = capturedBody['context'] as Map<String, dynamic>;
    expect((context['user'] as Map).containsKey('onBehalfOfUser'), isFalse);
  });
}
