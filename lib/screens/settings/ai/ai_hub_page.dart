import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/setting_item.dart';
import 'cubit/ai_hub_cubit.dart';
import '../../../../core/widgets/back_button.dart';

/// Real port of Android `AiSettings.kt`: configure the AI provider used for
/// lyrics translation (DeepL / OpenAI-compatible endpoints) and the streaming
/// mode. Backed by the existing [TranslationSettings] Hive surface.
class AiHubPage extends StatelessWidget {
  const AiHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AiHubCubit(),
      child: Scaffold(
        appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('AI Hub')),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: BlocBuilder<AiHubCubit, AiHubState>(
              builder: (context, state) {
                final s = state as AiHubLoaded;
                final cubit = context.read<AiHubCubit>();
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    const GroupTitle(title: 'API Credentials'),
                    SettingTile(
                      title: 'Provider',
                      subtitle: s.provider,
                      leading: const Icon(Icons.auto_awesome),
                      isFirst: true,
                      trailing: DropdownButton<String>(
                        value: s.provider,
                        underline: const SizedBox(),
                        items: AiHubCubit.providers
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) cubit.setProvider(v);
                        },
                      ),
                    ),
                    _textTile(
                      title: 'API Key',
                      value: s.apiKey,
                      icon: Icons.key,
                      obscure: true,
                      onChanged: cubit.setApiKey,
                    ),
                    _textTile(
                      title: 'Base URL',
                      subtitle: 'Leave empty for the provider default',
                      value: s.baseUrl,
                      icon: Icons.link,
                      onChanged: cubit.setBaseUrl,
                    ),
                    _textTile(
                      title: 'Model',
                      value: s.model,
                      icon: Icons.memory,
                      onChanged: cubit.setModel,
                      isLast: true,
                    ),

                    const GroupTitle(title: 'Translation'),
                    SettingTile(
                      title: 'Translation Mode',
                      subtitle: s.mode == 'Translate'
                          ? 'Translate meaning'
                          : 'Convert pronunciation',
                      leading: const Icon(Icons.translate),
                      isFirst: true,
                      trailing: DropdownButton<String>(
                        value: s.mode,
                        underline: const SizedBox(),
                        items: AiHubCubit.modes
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) cubit.setMode(v);
                        },
                      ),
                    ),
                    SettingTile(
                      title: 'Target Language',
                      subtitle: s.language,
                      leading: const Icon(Icons.language),
                      trailing: DropdownButton<String>(
                        value: s.language,
                        underline: const SizedBox(),
                        items: const ['en', 'es', 'it', 'hi', 'tr', 'ur', 'fr', 'de']
                            .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) cubit.setLanguage(v);
                        },
                      ),
                    ),
                    SettingSwitchTile(
                      title: 'Streaming responses',
                      subtitle: 'Use SSE for faster lyrics translation',
                      leading: const Icon(Icons.stream),
                      isLast: true,
                      value: s.streaming,
                      onChanged: cubit.setStreaming,
                    ),
                    const SizedBox(height: 100),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _textTile({
    required String title,
    String? subtitle,
    required String value,
    required IconData icon,
    required ValueChanged<String> onChanged,
    bool obscure = false,
    bool isLast = false,
  }) {
    return SettingTile(
      title: title,
      subtitle: subtitle,
      leading: Icon(icon),
      isLast: isLast,
      trailing: SizedBox(
        width: 220,
        child: TextField(
          controller: TextEditingController(text: value),
          obscureText: obscure,
          onSubmitted: onChanged,
          decoration: const InputDecoration(isDense: true),
        ),
      ),
    );
  }
}
