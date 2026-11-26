import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'package:Echo/screens/settings/ai/cubit/ai_hub_cubit.dart';
import 'package:Echo/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_ai_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    if (!Hive.isBoxOpen('SETTINGS')) await Hive.openBox('SETTINGS');
    if (!GetIt.I.isRegistered<SettingsManager>()) {
      GetIt.I.registerSingleton<SettingsManager>(SettingsManager());
    }
  });

  test('AI Hub provider list mirrors Android AiSettings.kt', () {
    expect(AiHubCubit.providers, containsAll([
      'OpenRouter',
      'OpenAI',
      'DeepL',
      'Mistral',
      'Gemini',
      'Custom',
    ]));
    expect(AiHubCubit.modes, ['Translate', 'Transcribe']);
  });

  test('AI Hub setters persist through SettingsManager', () async {
    final cubit = AiHubCubit();
    addTearDown(() => cubit.close());

    cubit.setProvider('DeepL');
    cubit.setApiKey('secret');
    cubit.setStreaming(false);
    await Future<void>.delayed(Duration.zero);

    expect(GetIt.I<SettingsManager>().translationProvider, 'DeepL');
    expect(GetIt.I<SettingsManager>().translationApiKey, 'secret');
    expect(GetIt.I<SettingsManager>().translationStreaming, isFalse);
    final state = cubit.state as AiHubLoaded;
    expect(state.provider, 'DeepL');
    expect(state.streaming, isFalse);
  });
}
