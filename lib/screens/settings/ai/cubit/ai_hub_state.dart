part of 'ai_hub_cubit.dart';

@immutable
sealed class AiHubState {
  const AiHubState();
}

class AiHubLoaded extends AiHubState {
  const AiHubLoaded({
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.language,
    required this.mode,
    required this.streaming,
  });

  final String provider;
  final String apiKey;
  final String baseUrl;
  final String model;
  final String language;
  final String mode;
  final bool streaming;
}
