import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

import 'cookie_store.dart';
import '../ytmusic/helpers.dart';

class YtComment {
  YtComment({
    required this.id,
    required this.author,
    required this.text,
    this.avatarUrl,
    this.published,
    this.voteCount = '',
    this.replyCount,
    this.repliesToken,
  });

  final String id;
  final String author;
  final String text;
  final String? avatarUrl;
  final String? published;
  final String voteCount;
  final int? replyCount;
  final String? repliesToken;
}

class CommentPage {
  CommentPage({required this.comments, this.nextToken});

  final List<YtComment> comments;
  final String? nextToken;
}

/// Port of Android `YouTube.comments()` / `commentContinuation()`: the `next`
/// endpoint with the WEB client, as used by CommentSheet.kt.
class CommentsService {
  CommentsService._();

  static final CommentsService instance = CommentsService._();

  final http.Client _client = http.Client();

  static const _clientVersion = '2.20260213.00.00';
  static const _endpoint =
      'https://music.youtube.com/youtubei/v1/next?prettyPrint=false';

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9,en;q=0.8',
      'Cache-Control': 'no-cache',
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': '1',
      'X-YouTube-Client-Version': _clientVersion,
      'X-Origin': 'https://music.youtube.com',
      'Origin': 'https://music.youtube.com',
      'Referer': 'https://music.youtube.com/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
    };
    final visitor = _visitor();
    if (visitor != null && visitor.isNotEmpty) {
      h['X-Goog-Visitor-Id'] = visitor;
    }
    return h;
  }

  Map<String, dynamic> _body({String? videoId, String? continuation}) => {
        'context': {
          'client': <String, dynamic>{
            'clientName': 'WEB',
            'clientVersion': _clientVersion,
            'hl': 'en',
            'gl': 'US',
          },
          'request': {
            'internalExperimentFlags': [],
            'useSsl': true,
          },
          'user': {'lockedSafetyMode': false},
        },
        if (videoId != null) 'videoId': videoId,
        if (continuation != null) 'continuation': continuation,
      };

  Future<Map<String, dynamic>> _post({
    String? videoId,
    String? continuation,
  }) async {
    final body = _body(videoId: videoId, continuation: continuation);
    final visitor = _visitor();
    if (visitor != null && visitor.isNotEmpty) {
      (body['context'] as Map)['client'] = <String, dynamic>{
        ...((body['context'] as Map)['client'] as Map),
        'visitorData': visitor,
      };
    }
    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Commenti HTTP ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<CommentPage> fetch(String videoId) async {
    final response = await _post(videoId: videoId);
    String? token;
    final twoColumn = nav(response, [
      'contents',
      'twoColumnWatchNextResults',
      'results',
      'results',
      'contents',
    ]);
    if (twoColumn is List) {
      for (final content in twoColumn) {
        final t = _tokenFrom(content);
        if (t != null) {
          token = t;
          break;
        }
      }
    }
    token ??= _tokenFromEngagement(response);
    if (token == null) return CommentPage(comments: const []);
    return continuation(token);
  }

  String? _tokenFrom(dynamic content) =>
      nav(content, [
        'continuationItemRenderer',
        'continuationEndpoint',
        'continuationCommand',
        'token',
      ])?.toString() ??
      nav(content, [
        'itemSectionRenderer',
        'contents',
        0,
        'continuationItemRenderer',
        'continuationEndpoint',
        'continuationCommand',
        'token',
      ])?.toString();

  String? _tokenFromEngagement(Map<String, dynamic> response) {
    final panels = nav(response, ['engagementPanels']);
    if (panels is! List) return null;
    for (final panel in panels) {
      final id = nav(panel, [
        'engagementPanelSectionListRenderer',
        'panelIdentifier',
      ])?.toString();
      if (id != 'engagement-panel-comments-section') continue;
      final contents = nav(panel, [
        'engagementPanelSectionListRenderer',
        'content',
        'sectionListRenderer',
        'contents',
      ]);
      if (contents is! List) continue;
      for (final c in contents) {
        final t = nav(c, [
          'itemSectionRenderer',
          'contents',
          0,
          'continuationItemRenderer',
          'continuationEndpoint',
          'continuationCommand',
          'token',
        ])?.toString();
        if (t != null) return t;
      }
    }
    return null;
  }

  Future<CommentPage> continuation(String token) async {
    final response = await _post(continuation: token);
    final comments = <YtComment>[];
    String? next;

    final endpoints = nav(response, ['onResponseReceivedEndpoints']);
    if (endpoints is List) {
      for (final endpoint in endpoints) {
        final items = nav(endpoint, [
              'reloadContinuationItemsCommand',
              'continuationItems',
            ]) ??
            nav(endpoint, [
              'appendContinuationItemsAction',
              'continuationItems',
            ]);
        if (items is! List) continue;
        for (final item in items) {
          final renderer = nav(item, ['commentRenderer']);
          if (renderer is Map) {
            final c = _fromRenderer(renderer);
            if (c != null) comments.add(c);
          }
          final thread = nav(item, ['commentThreadRenderer']);
          if (thread is Map) {
            final renderer2 = nav(thread, ['comment', 'commentRenderer']);
            if (renderer2 is Map) {
              final c = _fromRenderer(renderer2);
              if (c != null) comments.add(c);
            }
          }
          final t = nav(item, [
                'continuationItemRenderer',
                'continuationEndpoint',
                'continuationCommand',
                'token',
              ])?.toString();
          if (t != null) next = t;
        }
      }
    }
    // Modern responses put comment text in framework entity payloads instead
    // of commentRenderer (Android merges both).
    final mutations = nav(response, [
      'frameworkUpdates',
      'entityBatchUpdate',
      'mutations',
    ]);
    if (mutations is List) {
      for (final mutation in mutations) {
        final payload = nav(mutation, ['payload', 'commentEntityPayload']);
        if (payload is! Map) continue;
        final props = nav(payload, ['properties']) ?? const {};
        final id = props['commentId']?.toString() ?? '';
        final text = nav(payload, ['properties', 'content', 'content'])
                ?.toString() ??
            '';
        if (id.isEmpty || text.isEmpty) continue;
        if (comments.any((c) => c.id == id)) continue;
        final author = nav(payload, ['author', 'displayName'])?.toString() ??
            nav(props, ['author', 'displayName'])?.toString() ??
            '';
        final likes =
            nav(payload, ['toolbar', 'likeCountNotliked'])?.toString() ?? '';
        comments.add(
          YtComment(
            id: id,
            author: author,
            text: text,
            avatarUrl: nav(payload, ['author', 'avatarThumbnailUrl'])
                ?.toString(),
            published: props['publishedTime']?.toString(),
            voteCount: likes,
          ),
        );
      }
    }
    return CommentPage(comments: comments, nextToken: next);
  }

  YtComment? _fromRenderer(dynamic r) {
    if (r is! Map) return null;
    final id = nav(r, ['commentId'])?.toString() ?? '';
    final text = (nav(r, ['contentText', 'runs']) as List?)
            ?.map((e) => e is Map ? (e['text']?.toString() ?? '') : '')
            .join() ??
        '';
    final author = nav(r, ['authorText', 'runs', 0, 'text'])?.toString() ?? '';
    if (id.isEmpty && text.isEmpty) return null;
    final thumbs = nav(r, ['authorThumbnail', 'thumbnails']);
    final avatar = thumbs is List && thumbs.isNotEmpty
        ? (thumbs.last is Map
            ? (thumbs.last as Map)['url']?.toString()
            : null)
        : null;
    final replyCount = nav(r, ['replyCount']);
    return YtComment(
      id: id,
      author: author,
      text: text,
      avatarUrl: avatar,
      published: nav(r, ['publishedTimeText', 'runs', 0, 'text'])?.toString(),
      voteCount: nav(r, ['voteCount', 'runs', 0, 'text'])?.toString() ?? '',
      replyCount: replyCount is num ? replyCount.toInt() : null,
    );
  }
}

String? _visitor() {
  if (!Hive.isBoxOpen('SETTINGS')) return null;
  return Hive.box('SETTINGS').get('VISITOR_ID')?.toString();
}

