import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/screens/player/widgets/translation_dialog.dart';
import 'package:Echo/services/lyrics.dart';
import 'package:Echo/services/settings_manager.dart';
import 'package:Echo/services/translation_settings.dart';

class FakeSettings implements TranslationSettings {
  String provider = 'OpenRouter';
  String key = '';
  String baseUrl = '';
  String model = '';
  String language = 'es';
  String mode = 'Translate';
  bool streaming = false;

  @override
  String get translationProvider => provider;
  @override
  set translationProvider(String value) => provider = value;
  @override
  String get translationApiKey => key;
  @override
  set translationApiKey(String value) => key = value;
  @override
  String get translationBaseUrl => baseUrl;
  @override
  set translationBaseUrl(String value) => baseUrl = value;
  @override
  String get translationModel => model;
  @override
  set translationModel(String value) => model = value;
  @override
  String get translationLanguage => language;
  @override
  set translationLanguage(String value) => language = value;
  @override
  String get translationMode => mode;
  @override
  set translationMode(String value) => mode = value;
  @override
  bool get translationStreaming => streaming;
  @override
  set translationStreaming(bool value) => streaming = value;
}

class FakeLyricsService extends LyricsService {
  FakeLyricsService({this.result = const ['hola', 'mundo'], this.fail = false});

  final List<String> result;
  final bool fail;
  List<String>? receivedLines;

  @override
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
    void Function(List<String>)? onPartial,
  }) async {
    receivedLines = lines;
    if (fail) throw Exception('Translation failed');
    return result;
  }
}

void main() {
  testWidgets('translation dialog shows provider and saves settings on submit',
      (tester) async {
    final service = FakeLyricsService();
    final settings = FakeSettings();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TranslationDialog(
          lines: const ['hello', 'world'],
          service: service,
          settings: settings,
        ),
      ),
    ));

    expect(find.text('Translate lyrics'), findsOneWidget);
    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));

    await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
    await tester.pumpAndSettle();

    expect(service.receivedLines, ['hello', 'world']);
    expect(settings.language, 'es');
    expect(find.textContaining('hola'), findsOneWidget);
  });

  testWidgets('translation dialog surfaces errors', (tester) async {
    final service = FakeLyricsService(fail: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TranslationDialog(
          lines: const ['hello'],
          service: service,
          settings: FakeSettings(),
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Translation failed'), findsOneWidget);
  });
}
