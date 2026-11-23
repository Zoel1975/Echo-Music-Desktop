import 'package:flutter/material.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/widgets/back_button.dart';
import '../../services/update_service/update_service.dart';
import '../../services/update_service/models/update_info.dart';
import 'widgets/settings_list.dart';

/// Port of Android `UpdateSettings.kt`: current version, manual check and a
/// clear status line instead of a one-shot dialog with no screen behind it.
class UpdateSettingsPage extends StatefulWidget {
  const UpdateSettingsPage({super.key});

  @override
  State<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends State<UpdateSettingsPage> {
  String _version = '...';
  bool _checking = false;
  String _status = 'Premi "Controlla aggiornamenti" per verificare.';
  UpdateInfo? _update;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = 'Controllo in corso…';
    });
    final update = await UpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _update = update;
      _status = update == null
          ? 'Stai usando la versione più recente ($_version).'
          : 'Aggiornamento disponibile: ${update.version}';
    });
    if (update != null) UpdateService.showUpdateDialog(context, update);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('App updates'),
      ),
      body: SettingsList(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.of(context).SystemUpdate,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Versione installata: $_version'),
                  const SizedBox(height: 12),
                  Text(_status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.update),
            label: Text(_checking ? 'Controllo…' : 'Controlla aggiornamenti'),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
