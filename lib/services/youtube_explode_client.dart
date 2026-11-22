import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'cookie_store.dart';
import 'stream_resolver.dart';

/// youtube_explode_dart normally sends only `CONSENT=YES+cb`. Age-restricted
/// videos need the signed-in YouTube cookie jar and SAPISIDHASH — but ONLY on
/// youtube.com API calls. Sending Authorization to googlevideo.com makes the
/// media HEAD/GET return 403.
class AuthYoutubeHttpClient extends YoutubeHttpClient {
  Map<String, String> _authenticated(Map<String, String>? input) {
    final headers = <String, String>{...?input};
    final cookie = CookieStore.instance.cookieHeader;
    if (cookie != null && cookie.isNotEmpty) headers['cookie'] = cookie;
    final auth = CookieStore.instance
        .authorizationHeaderFor('https://www.youtube.com');
    if (auth != null) {
      headers['Authorization'] = auth;
      headers['X-Goog-AuthUser'] = '0';
    }
    final visitor = StreamResolver.instance.visitorData;
    if (visitor != null && visitor.isNotEmpty) {
      headers['X-Goog-Visitor-Id'] = visitor;
    }
    return headers;
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool validate = false,
  }) {
    final isPlayerApi = url.host.endsWith('youtube.com') &&
        url.path.contains('/youtubei/v1/player');
    return super.post(
      url,
      headers: isPlayerApi ? _authenticated(headers) : headers,
      body: body,
      encoding: encoding,
      validate: validate,
    );
  }

  /// youtube_explode rejects the whole manifest when its HEAD probe returns
  /// 403, even though YouTube often serves the same URL to a ranged GET (the
  /// way media_kit actually fetches it). Let our own [StreamResolver._validate]
  /// make that decision instead.
  @override
  Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
  }) async =>
      http.Response('', 200, request: http.Request('HEAD', url));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await super.send(request);
    if (response.statusCode >= 400) {
      debugPrint('[explode-http] ${response.statusCode} ${request.method} '
          '${request.url.host}${request.url.path}');
    }
    return response;
  }
}
