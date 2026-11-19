/// Settings surface needed by the lyrics translation dialog. Implemented by
/// `SettingsManager` (Hive-backed) and by fakes in widget tests.
abstract class TranslationSettings {
  String get translationProvider;
  set translationProvider(String value);
  String get translationApiKey;
  set translationApiKey(String value);
  String get translationBaseUrl;
  set translationBaseUrl(String value);
  String get translationModel;
  set translationModel(String value);
  String get translationLanguage;
  set translationLanguage(String value);
  String get translationMode;
  set translationMode(String value);
  bool get translationStreaming;
  set translationStreaming(bool value);
}
