import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_manager.dart';
import '../../../services/cloud_service.dart';
import '../../../services/song_dna_service.dart';
import '../widgets/setting_item.dart';
import '../widgets/settings_list.dart';
import 'integration_catalog.dart';
import '../../../../core/widgets/back_button.dart';

/// Data-driven settings screen for a mobile integration. Every field is
/// persisted through `SettingsManager.extra<T>` (Hive) — credentials entered
/// in-app are stored locally, exactly like the Android settings screens.
class IntegrationPage extends StatelessWidget {
  const IntegrationPage({super.key, required this.screen});
  final IntegrationScreen screen;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsManager>();
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: Text(screen.title)),
      body: SettingsList(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(screen.icon, size: 36, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${screen.title} configuration is stored locally on this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (screen.route == 'jellyfin') _cloudTest(context, settings),
          if (screen.route == 'song_dna') _dnaTest(context, settings),
          ...screen.fields.map((f) => _field(context, settings, f)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _cloudTest(BuildContext context, SettingsManager s) {
    return SettingTile(
      title: 'Test connection',
      subtitle: 'Verify the entered server credentials',
      leading: const Icon(Icons.cloud_sync),
      trailing: FilledButton(
        onPressed: () async {
          final cloud = GetIt.I<CloudService>();
          final type = s.extra<String>('cloudType', 'Jellyfin');
          final url = type == 'Jellyfin'
              ? s.extra<String>('jellyfinUrl', '')
              : s.extra<String>('navidromeUrl', '');
          final ok = type == 'Jellyfin'
              ? await cloud.checkJellyfin(
                  url: url,
                  user: s.extra<String>('jellyfinUser', ''),
                  password: s.extra<String>('jellyfinPass', ''),
                )
              : await cloud.checkNavidrome(
                  url: url,
                  user: s.extra<String>('jellyfinUser', ''),
                  password: s.extra<String>('jellyfinPass', ''),
                );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Connection successful' : 'Connection failed'),
            ));
          }
        },
        child: const Text('Test'),
      ),
    );
  }

  Widget _dnaTest(BuildContext context, SettingsManager s) {
    return SettingTile(
      title: 'Fetch song background',
      subtitle: 'Look up a track on Genius / Wikipedia',
      leading: const Icon(Icons.biotech),
      trailing: FilledButton(
        onPressed: () async {
          final dna = GetIt.I<SongDnaService>();
          final title = await dna.fetchGeniusTitle(
            token: s.extra<String>('geniusToken', ''),
            query: 'Echo Music',
          );
          final wiki = await dna.fetchWikipedia(
            lang: s.extra<String>('wikipediaLang', 'en'),
            title: title ?? 'Echo Music',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  wiki ?? title ?? 'No metadata found (check token/network)'),
            ));
          }
        },
        child: const Text('Fetch'),
      ),
    );
  }

  Widget _field(BuildContext context, SettingsManager s, IntegrationField f) {
    switch (f.type) {
      case IntegrationFieldType.toggle:
        return SettingSwitchTile(
          title: f.label,
          leading: Icon(screen.icon),
          value: s.extra<bool>(f.key, f.toggleFallback),
          onChanged: (v) => s.setExtra<bool>(f.key, v),
        );
      case IntegrationFieldType.text:
        return SettingTile(
          title: f.label,
          subtitle: f.help,
          leading: Icon(f.obscure ? Icons.key : Icons.text_fields),
          trailing: SizedBox(
            width: 220,
            child: TextField(
              controller: TextEditingController(
                  text: s.extra<String>(f.key, f.fallback)),
              obscureText: f.obscure,
              onSubmitted: (v) => s.setExtra<String>(f.key, v),
              decoration: const InputDecoration(isDense: true),
            ),
          ),
        );
      case IntegrationFieldType.choice:
        final value = s.extra<String>(f.key, f.fallback);
        return SettingTile(
          title: f.label,
          subtitle: value,
          leading: Icon(screen.icon),
          trailing: DropdownButton<String>(
            value: (f.options ?? const []).contains(value) ? value : f.fallback,
            underline: const SizedBox(),
            items: (f.options ?? const [])
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) {
              if (v != null) s.setExtra<String>(f.key, v);
            },
          ),
        );
    }
  }
}
