import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Port of Android `EchoBrain` / `ai/*`: generates themed playlists and
/// recommendations from the user's listening taste using the configured
/// OpenRouter-compatible endpoint (AI Hub credentials already in-app).
class EchoBrainService {
  EchoBrainService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const defaultBaseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const defaultModel = 'openrouter/free';

  /// Pure builder for the chat request (unit-testable).
  static Map<String, dynamic> buildRequest({
    required String systemPrompt,
    required String userPrompt,
    required String model,
  }) {
    return {
      if (model.isNotEmpty) 'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.7,
      'max_tokens': 512,
    };
  }

  /// Pure parser: extract the assistant message text from a chat response.
  static String parseContent(dynamic decoded) {
    if (decoded is! Map) return '';
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is! Map) return '';
    return (message['content']?.toString() ?? '').trim();
  }

  /// Pure parser: extract "Artist - Title" lines from an AI response.
  static List<Map<String, String>> parseTracks(String text) {
    final tracks = <Map<String, String>>[];
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final cleaned = line.trim().replaceFirst(RegExp(r'^\s*\d+[\.\)]\s*'), '');
      final dash = cleaned.indexOf(' - ');
      if (dash > 0) {
        tracks.add({
          'artist': cleaned.substring(0, dash).trim(),
          'title': cleaned.substring(dash + 3).trim(),
        });
      }
    }
    return tracks;
  }

  Future<String> generate({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final url = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
    final resolvedModel = model.trim().isEmpty ? defaultModel : model.trim();
    try {
      final r = await _client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(buildRequest(
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              model: resolvedModel,
            )),
          )
          .timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) {
        debugPrint('[echobrain] HTTP ${r.statusCode}');
        return '';
      }
      return parseContent(jsonDecode(r.body));
    } catch (e) {
      debugPrint('[echobrain] request failed: $e');
      return '';
    }
  }

  Future<List<Map<String, String>>> generatePlaylist({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String theme,
    required List<String> taste,
  }) async {
    final system =
        'You are a music curator. Reply with only a list of songs, one per '
        'line, in the format "Artist - Title". No commentary.';
    final user = 'Suggest a playlist themed "$theme". '
        'The listener likes: ${taste.join(", ")}.';
    final text = await generate(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      systemPrompt: system,
      userPrompt: user,
    );
    return parseTracks(text);
  }
}
