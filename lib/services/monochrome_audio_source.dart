import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'monochrome_service.dart';
import 'yt_audio_stream.dart';

/// just_audio source backed by a Monochrome `/track/<id>` FLAC response.
///
/// Monochrome serves raw FLAC bytes with `Accept-Ranges: bytes`, so this is a
/// drop-in replacement for [YouTubeAudioSource]: seeking works through the
/// same `request(start, end)` contract, and a failed/unavailable FLAC falls
/// back to the regular YouTube stream for that video id.
class MonochromeAudioSource extends StreamAudioSource {
  MonochromeAudioSource({
    required this.track,
    required this.fallbackVideoId,
    super.tag,
  });

  final MonochromeTrack track;
  final String fallbackVideoId;
  final http.Client _client = http.Client();
  int? _total;

  // Monochrome's CDN rejects requests with a generic library User-Agent
  // (HTTP 429 "oooooooooooooooooof beep boop"). A normal browser UA + referer
  // is required for the lossless stream to be served.
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Referer': 'https://monochrome.st/',
    'Accept': 'audio/flac,*/*',
  };

  Future<int> _discoverLength() async {
    final cached = _total;
    if (cached != null && cached > 0) return cached;

    try {
      final head = await _client
          .head(Uri.parse(track.streamUrl), headers: _headers)
          .timeout(const Duration(seconds: 15));
      final len = int.tryParse(
            head.headers[HttpHeaders.contentLengthHeader] ?? '',
          ) ??
          0;
      if (head.statusCode == 200 && len > 0) {
        _total = len;
        return len;
      }
      // The CDN rate-limits per IP with 429. Don't waste another request on
      // the 1-byte probe in that case; the estimate keeps the seek bar usable
      // and the real request will fall back to YouTube anyway.
      if (head.statusCode == 429) {
        final estimate = (track.durationMs * 125).clamp(1024, 1 << 35);
        _total = estimate;
        return estimate;
      }
    } catch (_) {}

    // HEAD may be blocked by a proxy: discover the total from a 1-byte range.
    try {
      final probe = http.Request('GET', Uri.parse(track.streamUrl))
        ..headers.addAll(_headers)
        ..headers['Range'] = 'bytes=0-0';
      final res = await _client
          .send(probe)
          .timeout(const Duration(seconds: 15));
      await res.stream.drain<void>();
      final range = res.headers[HttpHeaders.contentRangeHeader];
      if (range != null) {
        final match = RegExp(r'/(\d+)\s*$').firstMatch(range);
        final len = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
        if (len > 0) {
          _total = len;
          return len;
        }
      }
    } catch (_) {}

    // Last resort: FLAC at ~1 Mbit/s ≈ 125 KB/s keeps the seek bar usable.
    final estimate = (track.durationMs * 125).clamp(1024, 1 << 35);
    _total = estimate;
    return estimate;
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final total = await _discoverLength();
    start ??= 0;
    end ??= total - 1;
    if (end >= total) end = total - 1;
    if (start > end) start = end;
    if (start < 0) start = 0;

    try {
      final req = http.Request('GET', Uri.parse(track.streamUrl))
        ..headers.addAll({
          ..._headers,
          'Range': 'bytes=$start-$end',
        });
      final response = await _client
          .send(req)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.stream.drain<void>();
        throw HttpException(
          'Monochrome returned HTTP ${response.statusCode}',
          uri: req.url,
        );
      }

      final range = response.headers[HttpHeaders.contentRangeHeader];
      if (range != null) {
        final match = RegExp(r'/(\d+)\s*$').firstMatch(range);
        final real = match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
        if (real > 0) _total = real;
      }

      return StreamAudioResponse(
        sourceLength: _total ?? total,
        contentLength: end - start + 1,
        offset: start,
        stream: response.stream,
        contentType: 'audio/flac',
      );
    } catch (e) {
      // A matched-but-broken FLAC must not break playback: use YouTube.
      if (fallbackVideoId.isNotEmpty) {
        return YouTubeAudioSource(
          videoId: fallbackVideoId,
          quality: 'high',
        ).request(start, end);
      }
      throw Exception('Failed to load FLAC: $e');
    }
  }
}
