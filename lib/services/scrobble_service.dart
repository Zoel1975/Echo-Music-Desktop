import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Port of Android `LastFMSettingsScreen.kt` + `ListenBrainzManager.kt`:
/// sends "now playing" and "scrobble" calls using credentials entered in-app.
class ScrobbleService {
  ScrobbleService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const lastfmEndpoint = 'https://ws.audioscrobbler.com/2.0/';
  static const listenBrainzEndpoint =
      'https://api.listenbrainz.org/1/submit-listens';

  /// Pure builder for the Last.fm api_sig (MD5 of sorted key+value pairs plus
  /// the shared secret). Unit-testable without network.
  static String lastfmSignature(Map<String, String> params, String secret) {
    final keys = params.keys.toList()..sort();
    final raw = keys.map((k) => '$k${params[k]}').join() + secret;
    return md5.convert(utf8.encode(raw)).toString();
  }

  /// Build the Last.fm request body (shared by now-playing and scrobble).
  static Map<String, String> lastfmParams({
    required String method,
    required String apiKey,
    required String sessionKey,
    required String secret,
    required String artist,
    required String track,
    required int timestamp,
    String album = '',
  }) {
    final p = <String, String>{
      'method': method,
      'api_key': apiKey,
      'sk': sessionKey,
      'artist': artist,
      'track': track,
      'timestamp': timestamp.toString(),
      'format': 'json',
    };
    if (album.isNotEmpty) p['album'] = album;
    p['api_sig'] = lastfmSignature(p, secret);
    return p;
  }

  /// Build the ListenBrainz JSON payload (pure).
  static Map<String, dynamic> listenBrainzPayload({
    required String artist,
    required String track,
    required String album,
    required int timestamp,
    required bool singleRelease,
  }) {
    return {
      'listen_type': singleRelease ? 'single' : 'playing_now',
      'payload': [
        {
          if (singleRelease) 'listened_at': timestamp,
          'track_metadata': {
            'artist_name': artist,
            'track_name': track,
            if (album.isNotEmpty) 'release_name': album,
          },
        },
      ],
    };
  }

  Future<bool> _post(Uri uri, {Map<String, String>? body, String? jsonBody, Map<String, String>? headers}) async {
    try {
      final r = body != null
          ? await _client.post(uri, body: body).timeout(const Duration(seconds: 10))
          : await _client
              .post(uri, headers: headers, body: jsonBody)
              .timeout(const Duration(seconds: 10));
      return r.statusCode == 200 || r.statusCode == 204;
    } catch (e) {
      debugPrint('[scrobble] request failed: $e');
      return false;
    }
  }

  Future<bool> sendNowPlaying({
    required String apiKey,
    required String sessionKey,
    required String secret,
    required String artist,
    required String track,
    String album = '',
  }) =>
      _post(
        Uri.parse(lastfmEndpoint),
        body: lastfmParams(
          method: 'user.updateNowPlaying',
          apiKey: apiKey,
          sessionKey: sessionKey,
          secret: secret,
          artist: artist,
          track: track,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          album: album,
        ),
      );

  Future<bool> scrobbleLastfm({
    required String apiKey,
    required String sessionKey,
    required String secret,
    required String artist,
    required String track,
    required int timestamp,
    String album = '',
  }) =>
      _post(
        Uri.parse(lastfmEndpoint),
        body: lastfmParams(
          method: 'track.scrobble',
          apiKey: apiKey,
          sessionKey: sessionKey,
          secret: secret,
          artist: artist,
          track: track,
          timestamp: timestamp,
          album: album,
        ),
      );

  /// Android's "Send Likes/Unlikes to Last.fm" (`track.love` /
  /// `track.unlove`). Uses the same signed request shape as scrobbling.
  static Map<String, String> lastfmLoveParams({
    required String method,
    required String apiKey,
    required String sessionKey,
    required String secret,
    required String artist,
    required String track,
  }) {
    final p = <String, String>{
      'method': method,
      'api_key': apiKey,
      'sk': sessionKey,
      'artist': artist,
      'track': track,
      'format': 'json',
    };
    p['api_sig'] = lastfmSignature(p, secret);
    return p;
  }

  Future<bool> sendLove({
    required String apiKey,
    required String sessionKey,
    required String secret,
    required String artist,
    required String track,
    required bool loved,
  }) =>
      _post(
        Uri.parse(lastfmEndpoint),
        body: lastfmLoveParams(
          method: loved ? 'track.love' : 'track.unlove',
          apiKey: apiKey,
          sessionKey: sessionKey,
          secret: secret,
          artist: artist,
          track: track,
        ),
      );

  Future<bool> submitListenBrainz({
    required String token,
    required String artist,
    required String track,
    required String album,
    required int timestamp,
    required bool singleRelease,
  }) =>
      _post(
        Uri.parse(listenBrainzEndpoint),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        jsonBody: jsonEncode(listenBrainzPayload(
          artist: artist,
          track: track,
          album: album,
          timestamp: timestamp,
          singleRelease: singleRelease,
        )),
      );
}
