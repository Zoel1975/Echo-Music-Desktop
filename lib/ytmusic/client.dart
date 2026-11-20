import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/ytmusic/helpers.dart';
import 'package:Echo/ytmusic/modals/yt_config.dart';
import 'package:http/http.dart';

class YTClient {
  YTClient({required this.config, this.onIdUpdate}) {
    init();
  }
  Map<String, String> headers = {};
  Map<String, dynamic> context = {};
  int? signatureTimestamp;
  YTConfig? config;
  void Function(String visitorId)? onIdUpdate;

  static const ytmDomain = 'music.youtube.com';
  static const httpsYtmDomain = 'https://music.youtube.com';
  static const baseApiEndpoint = '/youtubei/v1/';
  static const String ytmParams =
      '?alt=json&key=AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:88.0) Gecko/20100101 Firefox/88.0';

  static final ValueNotifier<int> lastConnectionErrorTime =
      ValueNotifier<int>(0);
  ValueNotifier<int> get lastConnectionError => lastConnectionErrorTime;

  Future<void> init() async {
    headers = initializeHeaders();
    context = initializeContext();

    if (config?.visitorData != null) {
      headers['X-Goog-Visitor-Id'] = config!.visitorData;
    }
  }

  void refreshContext() {
    context = initializeContext();
  }

  Future<void> refreshHeaders() async {
    headers = initializeHeaders();
    final cookieHeader = CookieStore.instance.cookieHeader;
    if (cookieHeader != null) headers['cookie'] = cookieHeader;
    if (config?.visitorData != null) {
      headers['X-Goog-Visitor-Id'] = config!.visitorData;
    }
  }

  Future<void> resetVisitorId() async {
    Map<String, String> newHeaders = Map.from(headers);
    newHeaders.remove('X-Goog-Visitor-Id');
    final response = await sendGetRequest(httpsYtmDomain, newHeaders);
    final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
    RegExpMatch? matches = reg.firstMatch(response.body);
    String? visitorId;
    if (matches != null) {
      final ytcfg = json.decode(matches.group(1).toString());
      visitorId = ytcfg['VISITOR_DATA']?.toString();
      config ??= YTConfig(visitorData: '', language: 'en', location: 'IN');
      config = config!.copyWith(visitorData: visitorId);
      if (onIdUpdate != null && visitorId != null) {
        onIdUpdate!(visitorId);
      }
    }
    refreshHeaders();
  }

  static Future<String?> getVisitorid() async {
    Map<String, String> newHeaders = initializeHeaders();
    newHeaders.remove('X-Goog-Visitor-Id');
    final response = await _sendGetRequest(httpsYtmDomain, newHeaders);
    final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
    RegExpMatch? matches = reg.firstMatch(response.body);
    String? visitorId;
    if (matches != null) {
      final ytcfg = json.decode(matches.group(1).toString());
      visitorId = ytcfg['VISITOR_DATA']?.toString();
      return visitorId;
    }
    return null;
  }

  Future<Response> sendGetRequest(
    String url,
    Map<String, String>? headers,
  ) async {
    try {
      final effectiveHeaders = {...?headers};
      final cookieHeader = CookieStore.instance.cookieHeader;
      if (cookieHeader != null) {
        effectiveHeaders['cookie'] = cookieHeader;
      } else {
        effectiveHeaders.remove('cookie');
        effectiveHeaders.remove('Cookie');
      }
      final Uri uri = Uri.parse(url);
      final Response response = await get(uri, headers: effectiveHeaders);
      return response;
    } catch (e) {
      debugPrint("Exception in YTClient::sendGetReques: $e");
      lastConnectionErrorTime.value = DateTime.now().millisecondsSinceEpoch;
      return Response.bytes([], 503);
    }
  }

  static Future<Response> _sendGetRequest(
    String url,
    Map<String, String>? headers,
  ) async {
    try {
      final Uri uri = Uri.parse(url);
      final Response response = await get(uri, headers: headers);
      return response;
    } catch (e) {
      debugPrint("Exception in YTClient::_sendGetRequest: $e");
      lastConnectionErrorTime.value = DateTime.now().millisecondsSinceEpoch;
      return Response.bytes([], 503);
    }
  }

  Future<Response> addPlayingStats(String videoId, Duration time) async {
    try {
      final Uri uri = Uri.parse(
          'https://music.youtube.com/api/stats/watchtime?ns=yt&ver=2&c=WEB_REMIX&cmt=${(time.inMilliseconds / 1000)}&docid=$videoId');
      final Response response = await get(uri, headers: headers);
      return response;
    } catch (e) {
      debugPrint("Exception in YTClient::addPlayingStats: $e");
      lastConnectionErrorTime.value = DateTime.now().millisecondsSinceEpoch;
      return Response.bytes([], 503);
    }
  }

  Future<Map> sendRequest(String endpoint, Map<String, dynamic> body,
      {Map<String, String>? headers, String additionalParams = ''}) async {
    //
    try {
      body = {...body, ...context};

      this.headers.addAll(headers ?? {});

      // Mirror Android's reactive `YouTube.cookie = ...`: update the header
      // on every request, and REMOVE it after logout so no stale auth is sent.
      final cookieHeader = CookieStore.instance.cookieHeader;
      if (cookieHeader != null) {
        this.headers['cookie'] = cookieHeader;
      } else {
        this.headers.remove('cookie');
        this.headers.remove('Cookie');
      }

      if (config?.visitorData == null || config!.visitorData.isEmpty) {
        await resetVisitorId();
      }
      if (this.headers['X-Goog-Visitor-Id'] == null &&
          config?.visitorData != null) {
        this.headers['X-Goog-Visitor-Id'] = config!.visitorData;
      }
      final Uri uri = Uri.parse(httpsYtmDomain +
          baseApiEndpoint +
          endpoint +
          ytmParams +
          additionalParams);
      final response =
          await post(uri, headers: this.headers, body: jsonEncode(body));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map;
      } else {
        return {};
      }
    } catch (e) {
      debugPrint("Exception in YTClient::sendRequest: $e");
      lastConnectionErrorTime.value = DateTime.now().millisecondsSinceEpoch;
      return {};
    }
  }

  /// Desktop port of `YouTube.accountInfo` (`innertube/YouTube.kt`):
  /// reads the active account from `account/account_menu`.
  Future<Map<String, dynamic>?> getAccountInfo() async {
    final response = await sendRequest('account/account_menu', {});
    final actions = response['actions'] as List?;
    if (actions == null || actions.isEmpty) return null;
    final header = nav(
      actions[0],
      [
        'openPopupAction',
        'popup',
        'multiPageMenuRenderer',
        'header',
        'activeAccountHeaderRenderer',
      ],
    );
    if (header == null) return null;
    final info = <String, dynamic>{
      'name': nav(header, ['name', 'runs', 0, 'text']),
      'email': nav(header, ['email', 'runs', 0, 'text']),
      'channelHandle': nav(header, ['channelHandle', 'runs', 0, 'text']),
      'avatarUrl': nav(header, ['accountPhoto', 'thumbnails', 0, 'url']),
    };
    info.removeWhere((k, v) => v == null || (v is List && v.isEmpty));
    return info;
  }

  /// Port of `YouTube.lyrics()` / `YouTube.transcript()`: find the endpoint in
  /// the `next` response and query `get_lyrics` / `get_transcript`.
  Future<String?> getLyricsForVideo(String videoId, {bool transcript = false}) async {
    final next = await sendRequest('next', {'videoId': videoId});

    Object? findEndpoint(dynamic node) {
      if (node is! Map) return null;
      for (final entry in node.entries) {
        final key = '${entry.key}';
        if ((transcript && key.toLowerCase().contains('transcript')) ||
            (!transcript && key.contains('lyricsEndpoint'))) {
          return entry.value;
        }
        final found = findEndpoint(entry.value);
        if (found != null) return found;
      }
      return null;
    }

    String? collectText(dynamic node) {
      if (node is String) return node.trim().isEmpty ? null : node;
      if (node is Map) {
        for (final v in node.values) {
          final t = collectText(v);
          if (t != null) return t;
        }
      } else if (node is List) {
        for (final v in node) {
          final t = collectText(v);
          if (t != null) return t;
        }
      }
      return null;
    }

    final endpoint = findEndpoint(next);
    if (endpoint == null) return null;
    final params = endpoint is Map ? endpoint['params'] : null;
    if (params == null) return null;
    final response = await sendRequest(
      transcript ? 'get_transcript' : 'get_lyrics',
      {'params': params},
    );
    return collectText(response['contents'] ?? response);
  }
}
