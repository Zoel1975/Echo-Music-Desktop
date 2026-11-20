import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/settings_manager.dart';
import '../widgets/setting_item.dart';
import 'integration_catalog.dart';

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
      appBar: AppBar(title: Text(screen.title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          ...screen.fields.map((f) => _field(context, settings, f)),
          const SizedBox(height: 100),
        ],
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
