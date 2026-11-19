import 'package:Echo/services/lyrics_translation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseTranslationContent', () {
    test('parses a plain JSON array', () {
      final result = parseTranslationContent('["uno","dos"]', 2);
      expect(result, ['uno', 'dos']);
    });

    test('parses a fenced JSON array and truncates extras', () {
      final result = parseTranslationContent('```json\n["a","b","c"]\n```', 2);
      expect(result, ['a', 'b']);
    });

    test('pads short translations with empty lines', () {
      final result = parseTranslationContent('["a"]', 3);
      expect(result, ['a', '', '']);
    });

    test('falls back to line-by-line text', () {
      final result = parseTranslationContent('hello\nworld', 2);
      expect(result, ['hello', 'world']);
    });

    test('returns null for empty content', () {
      expect(parseTranslationContent('', 2), isNull);
    });
  });

  group('tryParsePartialTranslation', () {
    test('extracts completed strings from a partial streaming JSON array', () {
      expect(
        tryParsePartialTranslation('["one","two","th', 3),
        ['one', 'two'],
      );
    });
  });

  group('translation cache', () {
    test('keys include text, mode and language', () {
      final key = translationCacheKey('hello', 'Translate', 'es');
      expect(key, contains('_Translate_es'));
      expect(translationCacheKey('bye', 'Translate', 'es'), isNot(key));
    });

    test('cache hit restores translations for the same song/mode/language', () {
      final helper = LyricsTranslationHelper();
      const lines = ['hello', 'world'];
      expect(helper.getCached(lines, 'Translate', 'es'), isNull);
      helper.cache(lines, const ['hola', 'mundo'], 'Translate', 'es');
      expect(helper.getCached(lines, 'Translate', 'es'), ['hola', 'mundo']);
      expect(helper.getCached(lines, 'Romanized', 'es'), isNull);
      expect(helper.hasActiveTranslations, isTrue);
      helper.clearCache();
      expect(helper.getCached(lines, 'Translate', 'es'), isNull);
    });
  });

  group('languageName', () {
    test('maps known codes and falls back to the code', () {
      expect(languageName('es'), 'Spanish');
      expect(languageName('zh-CN'), 'Simplified Chinese');
      expect(languageName('xx'), 'xx');
    });
  });

  group('isUrlSafe', () {
    test('accepts HTTPS endpoints and empty defaults', () {
      expect(isUrlSafe(''), isTrue);
      expect(isUrlSafe('https://api.example.com/v1'), isTrue);
    });

    test('blocks cloud metadata and non-http schemes', () {
      expect(isUrlSafe('http://169.254.169.254/latest/meta-data'), isFalse);
      expect(isUrlSafe('http://metadata.google.internal'), isFalse);
      expect(isUrlSafe('file:///etc/passwd'), isFalse);
    });
  });
}
