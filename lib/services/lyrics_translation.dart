/// Desktop port of Android `api/DeepLService.kt`, `MistralService.kt`,
/// `OpenRouterService.kt`, `OpenRouterStreamingService.kt` and
/// `lyrics/LyricsTranslationHelper.kt` (cache + orchestration).
library lyrics_translation;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Android `TranslationStatus`.
sealed class TranslationStatus {
  const TranslationStatus();

  static const idle = TranslationStatusIdle();
  static const success = TranslationStatusSuccess();

  static TranslationStatus translating([List<String> logs = const []]) =>
      TranslationStatusTranslating(logs);

  static TranslationStatus error(String message) =>
      TranslationStatusError(message);
}

class TranslationStatusIdle extends TranslationStatus {
  const TranslationStatusIdle() : super();
}

class TranslationStatusSuccess extends TranslationStatus {
  const TranslationStatusSuccess() : super();
}

class TranslationStatusTranslating extends TranslationStatus {
  const TranslationStatusTranslating(this.logs);
  final List<String> logs;
}

class TranslationStatusError extends TranslationStatus {
  const TranslationStatusError(this.message);
  final String message;
}

/// Language code → name (Android `LanguageCodeToName`, subset with fallback).
const languageCodeToName = <String, String>{
  'en': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'zh': 'Chinese',
  'zh-cn': 'Simplified Chinese',
  'zh-tw': 'Traditional Chinese',
  'hi': 'Hindi',
  'ar': 'Arabic',
  'tr': 'Turkish',
  'nl': 'Dutch',
  'pl': 'Polish',
  'vi': 'Vietnamese',
  'th': 'Thai',
};

String languageName(String code) =>
    languageCodeToName[code.toLowerCase()] ?? code;

/// Android `getCacheKey(lyricsText, mode, language)`.
String translationCacheKey(String lyricsText, String mode, String language) =>
    '${lyricsText.hashCode}_${mode}_$language';

/// In-memory translation cache + status, port of `LyricsTranslationHelper`.
class LyricsTranslationHelper {
  final Map<String, List<String>> _cache = {};

  TranslationStatus status = TranslationStatus.idle;
  bool hasActiveTranslations = false;

  List<String>? getCached(List<String> lines, String mode, String language) =>
      _cache[translationCacheKey(lines.join('\n'), mode, language)];

  void cache(List<String> lines, List<String> translated, String mode, String language) {
    _cache[translationCacheKey(lines.join('\n'), mode, language)] = List.of(translated);
    hasActiveTranslations = true;
  }

  void clearCache() => _cache.clear();

  void clear() {
    _cache.clear();
    hasActiveTranslations = false;
    status = TranslationStatus.idle;
  }
}

/// Parses a model response into exactly [expected] lines.
/// Port of the shared parsing block in Mistral/OpenRouter/Streaming services.
List<String>? parseTranslationContent(String content, int expected) {
  var cleaned = content.trim();
  List<String>? lines;

  List<String> fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is List) {
      return decoded.map((e) => e is String ? e : (e?.toString() ?? '')).toList();
    }
    return <String>[];
  }

  for (final candidate in <String>[
    cleaned,
    cleaned.replaceAll('```json', '').replaceAll('```', '').trim(),
  ]) {
    try {
      lines = fromJson(candidate);
      if (lines.isNotEmpty) break;
    } catch (_) {}
  }
  if (lines == null || lines.isEmpty) {
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start != -1 && end > start) {
      try {
        lines = fromJson(cleaned.substring(start, end + 1));
      } catch (_) {}
    }
    lines ??= cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) {
      var s = l;
      if (s.startsWith('"') && s.endsWith('"')) s = s.substring(1, s.length - 1);
      if (s.startsWith("'") && s.endsWith("'")) s = s.substring(1, s.length - 1);
      return s;
    }).toList();
  }
  if (lines.isEmpty) return null;
  if (lines.length >= expected) return lines.take(expected).toList();
  return [...lines, ...List.filled(expected - lines.length, '')];
}

/// Android `tryParsePartialTranslation` — used for live streaming updates.
List<String> tryParsePartialTranslation(String content, int expected) {
  final start = content.indexOf('[');
  if (start == -1) return const [];
  final result = <String>[];
  final current = StringBuffer();
  var inString = false;
  var escaping = false;
  for (var i = start + 1; i < content.length && result.length < expected; i++) {
    final ch = content[i];
    if (escaping) {
      current.write(ch);
      escaping = false;
    } else if (ch == r'\' && inString) {
      current.write(ch);
      escaping = true;
    } else if (ch == '"') {
      if (inString) {
        result.add(current.toString());
        current.clear();
        inString = false;
      } else {
        inString = true;
      }
    } else if (inString) {
      current.write(ch);
    } else if (ch == ']') {
      break;
    }
  }
  return result;
}

/// System/user prompts shared by Mistral + OpenRouter (+ streaming).
String systemPrompt(int lineCount) =>
    'You are a precise lyrics translation assistant. Your output must ALWAYS be a valid JSON array of strings.\n\n'
    'CRITICAL RULES:\n'
    '1. Output ONLY a JSON array: ["line1", "line2", "line3"]\n'
    '2. NO explanations, NO questions, NO additional text\n'
    '3. Each input line maps to exactly one output line\n'
    '4. Preserve empty lines as empty strings ""\n'
    '5. Return EXACTLY $lineCount items in the array\n'
    '6. If uncertain, provide best approximation but maintain line count';

String userPrompt(String text, int lineCount, String targetLanguage, String mode) {
  if (mode == 'Romanized') {
    return 'Romanize/transliterate the following $lineCount lines into simple Latin script '
        'using ONLY basic English letters (a-z, A-Z). Preserve line-by-line structure exactly.\n\n'
        'Input ($lineCount lines):\n$text\n\n'
        'Output MUST be a JSON array with EXACTLY $lineCount strings.';
  }
  if (mode == 'Transcribed') {
    return 'Transcribe the following $lineCount lines phonetically into $targetLanguage script '
        '(sound, not meaning). Preserve line-by-line structure exactly.\n\n'
        'Input ($lineCount lines):\n$text\n\n'
        'Output MUST be a JSON array with EXACTLY $lineCount strings.';
  }
  return 'Translate the following $lineCount lines to $targetLanguage.\n\n'
      'Provide natural, accurate translation; maintain poetic flow and meaning; '
      'preserve line-by-line structure exactly; prioritize singability.\n\n'
      'Input ($lineCount lines):\n$text\n\n'
      'Output MUST be a JSON array with EXACTLY $lineCount strings.';
}

/// Android `DeepLService.translate`.
Future<List<String>> deeplTranslate({
  required String text,
  required String targetLanguage,
  required String apiKey,
  String formality = 'default',
  void Function(String)? onLog,
}) async {
  final lines = text.split('\n');
  final code = switch (targetLanguage.toLowerCase()) {
    'zh' || 'zh-cn' || 'zh-hans' || 'zh-tw' || 'zh-hant' => 'ZH',
    'en' || 'en-us' => 'EN-US',
    'en-gb' => 'EN-GB',
    'pt' || 'pt-pt' => 'PT-PT',
    'pt-br' => 'PT-BR',
    _ => targetLanguage.toUpperCase().substring(0, 2),
  };
  final base = apiKey.trim().endsWith(':fx')
      ? 'https://api-free.deepl.com/v2/translate'
      : 'https://api.deepl.com/v2/translate';
  onLog?.call('Calling DeepL API...');
  final body = <String, dynamic>{
    'text': lines,
    'target_lang': code,
    'preserve_formatting': true,
    if (formality != 'default') 'formality': formality,
  };
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final r = await http.post(
        Uri.parse(base),
        headers: {
          'Authorization': 'DeepL-Auth-Key ${apiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 45));
      if (r.statusCode >= 500) {
        await Future.delayed(Duration(seconds: attempt + 1));
        continue;
      }
      if (r.statusCode != 200) {
        throw Exception('Translation failed: HTTP ${r.statusCode}');
      }
      final decoded = jsonDecode(r.body) as Map<String, dynamic>;
      final translations = decoded['translations'] as List?;
      if (translations == null || translations.isEmpty) continue;
      final result = translations
          .map((e) => (e as Map)['text']?.toString() ?? '')
          .toList();
      onLog?.call('Successfully parsed ${result.length} lines');
      return parseTranslationContent(result.join('\n'), lines.length)!;
    } catch (_) {
      if (attempt == 2) rethrow;
      await Future.delayed(Duration(seconds: attempt + 1));
    }
  }
  throw Exception('Max retries exceeded');
}

Map<String, dynamic> _openRouterBody(String model, String system, String user, int maxTokens,
    {bool stream = false}) {
  return {
    if (model.isNotEmpty) 'model': model,
    'messages': [
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ],
    'temperature': 0.3,
    'max_tokens': maxTokens,
    if (stream) 'stream': true,
  };
}

String _extractContent(dynamic decoded) {
  if (decoded is! Map) return '';
  final content = decoded['content'];
  if (content is List) {
    return content
        .map((e) => e is Map ? (e['text']?.toString() ?? '') : '')
        .join()
        .trim();
  }
  final choices = decoded['choices'];
  if (choices is List && choices.isNotEmpty) {
    return (choices.first as Map)['message']?['content']?.toString().trim() ?? '';
  }
  return '';
}

/// Android `OpenRouterService.isUrlSafe`.
bool isUrlSafe(String url) {
  if (url.trim().isEmpty) return true;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return false;
  final host = uri.host.toLowerCase();
  return host != '169.254.169.254' &&
      !host.startsWith('169.254.') &&
      host != 'metadata.google.internal' &&
      host != 'instance-data';
}

/// Android `OpenRouterService.translate` (also covers ApiRoute custom URLs).
Future<List<String>> openRouterTranslate({
  required String text,
  required String targetLanguage,
  required String apiKey,
  required String baseUrl,
  required String model,
  required String mode,
  void Function(String)? onLog,
}) async {
  final url = baseUrl.trim().isEmpty
      ? 'https://openrouter.ai/api/v1/chat/completions'
      : baseUrl.trim();
  if (!isUrlSafe(url)) throw Exception('Invalid or restricted endpoint destination');
  final lines = text.split('\n');
  final isAnthropic = url.toLowerCase().contains('api.anthropic.com') && url.toLowerCase().contains('/messages');
  final system = systemPrompt(lines.length);
  final user = userPrompt(text, lines.length, targetLanguage, mode);
  final body = <String, dynamic>{
    if (model.isNotEmpty) 'model': model,
    if (isAnthropic) 'system': system,
    'messages': [
      if (!isAnthropic)
        {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ],
    'temperature': 0.3,
    'max_tokens': lines.length * 100,
  };
  final headers = <String, String>{
    'Content-Type': 'application/json',
    if (apiKey.isNotEmpty)
      if (isAnthropic) 'x-api-key': apiKey.trim() else 'Authorization': 'Bearer ${apiKey.trim()}',
    if (isAnthropic) 'anthropic-version': '2023-06-01',
    if (!isAnthropic) 'HTTP-Referer': 'https://github.com/EchoMusicApp/Echo-Music',
    if (!isAnthropic) 'X-Title': 'echomusic',
  };
  onLog?.call('Calling translation API...');
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final r = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 45));
      if (r.statusCode >= 500) {
        await Future.delayed(Duration(seconds: attempt + 1));
        continue;
      }
      if (r.statusCode != 200) throw Exception('Translation failed: HTTP ${r.statusCode}');
      final content = _extractContent(jsonDecode(r.body));
      final parsed = parseTranslationContent(content, lines.length);
      if (parsed == null) throw Exception('Failed to parse translation');
      onLog?.call('Successfully parsed ${parsed.length} lines');
      return parsed;
    } catch (_) {
      if (attempt == 2) rethrow;
      await Future.delayed(Duration(seconds: attempt + 1));
    }
  }
  throw Exception('Max retries exceeded');
}

/// Android `OpenRouterStreamingService.StreamChunk`.
sealed class StreamChunk {
  const StreamChunk();
}

class StreamContent extends StreamChunk {
  const StreamContent(this.text);
  final String text;
}

class StreamComplete extends StreamChunk {
  const StreamComplete(this.lines);
  final List<String> lines;
}

class StreamError extends StreamChunk {
  const StreamError(this.message);
  final String message;
}

/// Android `OpenRouterStreamingService.streamTranslation` — SSE translation.
Stream<StreamChunk> streamTranslation({
  required String text,
  required String targetLanguage,
  required String apiKey,
  required String baseUrl,
  required String model,
  required String mode,
}) async* {
  final lines = text.split('\n');
  if (text.trim().isEmpty) {
    yield const StreamError('Input text is empty');
    return;
  }
  final url = baseUrl.trim().isEmpty
      ? 'https://openrouter.ai/api/v1/chat/completions'
      : baseUrl.trim();
  if (!isUrlSafe(url)) {
    yield const StreamError('Invalid or restricted endpoint destination');
    return;
  }
  try {
    final request = http.Request('POST', Uri.parse(url))
      ..headers.addAll({
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
        'HTTP-Referer': 'https://github.com/EchoMusicApp/Echo-Music',
        'X-Title': 'echomusic',
      })
      ..body = jsonEncode(_openRouterBody(
        model,
        systemPrompt(lines.length),
        userPrompt(text, lines.length, targetLanguage, mode),
        lines.length * 100,
        stream: true,
      ));
    final response = await http.Client().send(request).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      yield StreamError('Translation failed: HTTP ${response.statusCode}');
      return;
    }
    final content = StringBuffer();
    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final data = line.substring(6);
      if (data == '[DONE]') break;
      try {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        final choices = decoded['choices'] as List?;
        final delta = (choices?.first as Map?)?['delta'] as Map?;
        final chunk = delta?['content'] as String?;
        if (chunk != null) {
          content.write(chunk);
          yield StreamContent(chunk);
        }
      } catch (_) {}
    }
    final parsed = parseTranslationContent(content.toString(), lines.length);
    if (parsed == null) {
      yield const StreamError('Failed to parse translation');
    } else {
      yield StreamComplete(parsed);
    }
  } catch (e) {
    yield StreamError(e.toString());
  }
}

/// Port of `LyricsTranslationHelper.translateLyrics` orchestration.
Future<List<String>> translateLyrics({
  required List<String> lines,
  required String targetLanguage,
  required String mode,
  required String provider,
  required String apiKey,
  String baseUrl = '',
  String model = '',
  String deeplApiKey = '',
  String deeplFormality = 'default',
  bool useStreaming = true,
  LyricsTranslationHelper? helper,
  void Function(String)? onLog,
  void Function(List<String>)? onPartial,
}) async {
  final effectiveKey = provider == 'DeepL' ? deeplApiKey : apiKey;
  if (effectiveKey.trim().isEmpty) throw Exception('API key is required');
  if (lines.isEmpty) throw Exception('No lyrics to translate');
  final effectiveMode =
      (mode == 'Romanized' || mode == 'Transcribed') ? mode : 'Translate';
  final language = languageName(targetLanguage);

  final cached = helper?.getCached(lines, effectiveMode, targetLanguage);
  if (cached != null && cached.length >= lines.length) {
    helper?.status = TranslationStatus.success;
    return cached;
  }
  helper?.status = TranslationStatus.translating(['Starting translation...']);

  late final List<String> result;
  if (provider == 'DeepL') {
    result = await deeplTranslate(
      text: lines.join('\n'),
      targetLanguage: targetLanguage,
      apiKey: effectiveKey,
      formality: deeplFormality,
      onLog: onLog,
    );
  } else if (provider == 'Mistral') {
    result = await openRouterTranslate(
      text: lines.join('\n'),
      targetLanguage: language,
      apiKey: effectiveKey,
      baseUrl: 'https://api.mistral.ai/v1/chat/completions',
      model: model.isEmpty ? 'mistral-small-latest' : model,
      mode: effectiveMode,
      onLog: onLog,
    );
  } else if (useStreaming && provider != 'Custom') {
    final buffer = StringBuffer();
    await for (final chunk in streamTranslation(
      text: lines.join('\n'),
      targetLanguage: language,
      apiKey: effectiveKey,
      baseUrl: baseUrl,
      model: model,
      mode: effectiveMode,
    )) {
      if (chunk is StreamContent) {
        buffer.write(chunk.text);
        final partial = tryParsePartialTranslation(buffer.toString(), lines.length);
        if (partial.isNotEmpty) onPartial?.call(partial);
      } else if (chunk is StreamComplete) {
        result = chunk.lines;
      } else if (chunk is StreamError) {
        throw Exception(chunk.message);
      }
    }
  } else {
    result = await openRouterTranslate(
      text: lines.join('\n'),
      targetLanguage: language,
      apiKey: effectiveKey,
      baseUrl: baseUrl,
      model: model,
      mode: effectiveMode,
      onLog: onLog,
    );
  }
  helper?.cache(lines, result, effectiveMode, targetLanguage);
  helper?.status = TranslationStatus.success;
  return result;
}
