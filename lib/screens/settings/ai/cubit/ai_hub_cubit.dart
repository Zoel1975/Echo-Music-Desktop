import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'package:Echo/services/settings_manager.dart';

part 'ai_hub_state.dart';

/// Drives the AI Hub settings screen. All values are persisted by
/// [SettingsManager] (Hive) — a direct port of Android `AiSettings.kt`.
class AiHubCubit extends Cubit<AiHubState> {
  AiHubCubit()
      : super(
          AiHubLoaded(
            provider: GetIt.I<SettingsManager>().translationProvider,
            apiKey: GetIt.I<SettingsManager>().translationApiKey,
            baseUrl: GetIt.I<SettingsManager>().translationBaseUrl,
            model: GetIt.I<SettingsManager>().translationModel,
            language: GetIt.I<SettingsManager>().translationLanguage,
            mode: GetIt.I<SettingsManager>().translationMode,
            streaming: GetIt.I<SettingsManager>().translationStreaming,
          ),
        ) {
    _listener = () {
      if (!isClosed) _emit();
    };
    _settings.addListener(_listener);
  }

  final SettingsManager _settings = GetIt.I<SettingsManager>();
  late final VoidCallback _listener;

  static const providers = [
    'OpenRouter',
    'OpenAI',
    'API Route',
    'Perplexity',
    'Claude',
    'Gemini',
    'XAi',
    'Mistral',
    'DeepL',
    'Custom',
  ];
  static const modes = ['Translate', 'Transcribe'];

  void _emit() {
    if (isClosed) return;
    emit(
      AiHubLoaded(
        provider: _settings.translationProvider,
        apiKey: _settings.translationApiKey,
        baseUrl: _settings.translationBaseUrl,
        model: _settings.translationModel,
        language: _settings.translationLanguage,
        mode: _settings.translationMode,
        streaming: _settings.translationStreaming,
      ),
    );
  }

  void setProvider(String v) => _settings.translationProvider = v;
  void setApiKey(String v) => _settings.translationApiKey = v;
  void setBaseUrl(String v) => _settings.translationBaseUrl = v;
  void setModel(String v) => _settings.translationModel = v;
  void setLanguage(String v) => _settings.translationLanguage = v;
  void setMode(String v) => _settings.translationMode = v;
  void setStreaming(bool v) => _settings.translationStreaming = v;

  @override
  Future<void> close() {
    _settings.removeListener(_listener);
    return super.close();
  }
}
