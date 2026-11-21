import 'dart:async';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'stream_resolver.dart';

/// StreamAudioSource backed by the new InnerTube [StreamResolver].
///
/// Replaces the old `youtube_explode_dart`/androidVr path, which produced
/// throttled URLs with a ~1 MiB byte cap and failed entirely on YouTube Music
/// tracks ("Sign in to confirm you're not a bot").
class YouTubeAudioSource extends StreamAudioSource {
  YouTubeAudioSource({
    required this.videoId,
    required this.quality,
    super.tag,
  });

  final String videoId;
  final String quality; // 'high' or 'low'
  ResolvedStream? _resolved;

  Future<ResolvedStream> _resolve() async {
    final cached = _resolved;
    if (cached != null) return cached;
    final resolved =
        await StreamResolver.instance.resolve(videoId, quality: quality);
    _resolved = resolved;
    return resolved;
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      final stream = await _resolve();
      final total = stream.contentLength > 0 ? stream.contentLength : 10379935;
      start ??= 0;
      end ??= total - 1;
      if (end >= total) end = total - 1;
      if (start > end) start = end;

      final request = http.Request('GET', Uri.parse(stream.url))
        ..headers.addAll({
          ...stream.headers,
          'Range': 'bytes=$start-$end',
          'User-Agent': YtPlayerClient.visionOs.userAgent,
        });
      final response = await http.Client().send(request);
      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.stream.drain<void>();
        throw StreamResolutionException(
          'Media request returned HTTP ${response.statusCode}',
        );
      }
      return StreamAudioResponse(
        sourceLength: total,
        contentLength: end - start + 1,
        offset: start,
        stream: response.stream,
        contentType: stream.mimeType,
      );
    } catch (e) {
      throw Exception('Failed to load audio: $e');
    }
  }
}

/// Local HTTP relay used by media_kit on Windows/Linux: the player requests
/// `http://127.0.0.1:<port>/audio?id=...&quality=...` with Range headers and
/// this handler proxies the resolved googlevideo stream.
Future<String> createAudioStreamServer() async {
  // Bind all interfaces so a Cast receiver (TV/speaker) can fetch the audio
  // too. The returned URL stays loopback for local playback; castCurrentSong()
  // rewrites the host to the LAN address.
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
  server.listen(handleAudioRequest);
  final url = 'http://127.0.0.1:${server.port}/audio';
  print('Generic streaming server started on $url. Use ?id=...&quality=... to stream.');
  return url;
}

/// IPv4 address of this machine that can actually reach [peerHost].
///
/// A desktop can have WSL/Hyper-V/Tailscale adapters with their own IPs. The
/// first non-loopback address is often one of those virtual networks, which a
/// Cast device cannot route to - pick the address in the peer's subnet first.
Future<String> lanIp({String? peerHost}) async {
  final candidates = <String>[];
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final nic in interfaces) {
      for (final address in nic.addresses) {
        if (!address.isLoopback) candidates.add(address.address);
      }
    }
  } catch (_) {}
  if (candidates.isEmpty) return '127.0.0.1';

  return pickLanAddress(candidates, peerHost);
}

/// Pure: prefer the address in the receiver's subnet, then a real LAN address.
String pickLanAddress(List<String> candidates, String? peerHost) {
  bool sameSubnet(String a, String b) {
    final x = a.split('.');
    final y = b.split('.');
    return x.length == 4 && y.length == 4 && x[0] == y[0] && x[1] == y[1];
  }

  if (peerHost != null) {
    for (final ip in candidates) {
      if (sameSubnet(ip, peerHost)) return ip;
    }
  }
  for (final ip in candidates) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) return ip;
  }
  return candidates.first;
}

/// Pure: rewrite the relay URL so another device on the LAN can reach it.
String audioUrlForHost(
  String baseUrl,
  String host,
  String videoId, {
  String quality = 'high',
}) {
  final uri = Uri.parse(baseUrl);
  return uri
      .replace(host: host, queryParameters: {'id': videoId, 'quality': quality})
      .toString();
}

/// URL a Cast receiver can use to play [videoId] through Echo's relay.
Future<String> lanAudioUrl(String videoId,
    {String quality = 'high', String? peerHost}) async {
  final base = GetIt.I<String>(instanceName: 'audioStreamUrl');
  return audioUrlForHost(base, await lanIp(peerHost: peerHost), videoId,
      quality: quality);
}

Future<void> handleAudioRequest(HttpRequest request) async {
  final response = request.response;
  if (request.uri.path != '/audio') {
    response.statusCode = HttpStatus.notFound;
    await response.close();
    return;
  }
  final videoId = request.uri.queryParameters['id'];
  final quality = request.uri.queryParameters['quality'] ?? 'high';
  if (videoId == null || videoId.isEmpty) {
    response.statusCode = HttpStatus.badRequest;
    await response.close();
    return;
  }

  try {
    final stream = await StreamResolver.instance.resolve(videoId, quality: quality);
    final total = stream.contentLength > 0 ? stream.contentLength : 10379935;

    int start = 0;
    int end = total - 1;
    bool isPartial = false;
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final parts = rangeHeader.substring(6).split('-');
      if (parts.length == 2) {
        final s = int.tryParse(parts[0]) ?? 0;
        final e = parts[1].isEmpty ? total - 1 : int.tryParse(parts[1]);
        if (e != null && s <= e && s < total) {
          start = s;
          end = e >= total ? total - 1 : e;
          isPartial = true;
        }
      }
    }

    final mediaRequest = http.Request('GET', Uri.parse(stream.url))
      ..headers.addAll({
        ...stream.headers,
        'Range': 'bytes=$start-$end',
        'User-Agent': YtPlayerClient.visionOs.userAgent,
      });
    final media = await http.Client().send(mediaRequest);
    if (media.statusCode != 200 && media.statusCode != 206) {
      response.statusCode = HttpStatus.badGateway;
      await media.stream.drain<void>();
      await response.close();
      return;
    }

    response.statusCode = isPartial ? HttpStatus.partialContent : HttpStatus.ok;
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.contentType = ContentType.parse(stream.mimeType);
    response.headers.contentLength = end - start + 1;
    if (isPartial) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$total',
      );
    }
    response.bufferOutput = false;
    await response.addStream(media.stream);
    await response.close();
  } catch (e) {
    print('Error serving audio for $videoId: $e');
    try {
      response.statusCode = HttpStatus.internalServerError;
      await response.close();
    } catch (_) {}
  }
}

/// Direct-URL path (macOS/iOS): uses the same resolver with the stream's
/// required headers attached.
Future<AudioSource> getDirectUrlAudioSource(
  String videoId,
  String quality,
  dynamic tag,
) async {
  final stream = await StreamResolver.instance.resolve(videoId, quality: quality);
  return AudioSource.uri(
    Uri.parse(stream.url),
    headers: {
      ...stream.headers,
      'User-Agent': YtPlayerClient.visionOs.userAgent,
    },
    tag: tag,
  );
}
