import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/widgets/back_button.dart';

import '../../services/device_link_announcement.dart';
import '../../services/remote_control_service.dart';

/// Device-link page ("tramite YouTube Music nello stato di riproduzione"):
/// lists the devices linked to this desktop — peers that broadcast an
/// announce with the same YouTube/Google account fingerprint. Live, so
/// phones/other desktop instances appear as they connect.
class DeviceLinkPage extends StatefulWidget {
  const DeviceLinkPage({super.key});

  @override
  State<DeviceLinkPage> createState() => _DeviceLinkPageState();
}

class _DeviceLinkPageState extends State<DeviceLinkPage> {
  final _rc = GetIt.I<RemoteControlService>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Announce per account (newest/most-recent wins → live playing state).
  Map<String, DeviceLinkAnnounce> get linked => _rc.linkedByAccount;

  bool isMyAccount(String account) => account == _rc.accountFp;

  @override
  Widget build(BuildContext context) {
    final entries = linked.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivi collegati'),
        leading: echoBackButton(context),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text('Nessun dispositivo collegato.\nIl telefono appare '
                  'se accede con lo stesso account YouTube.', textAlign: TextAlign.center))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = entries[i];
                final mine = isMyAccount(a.account);
                return ListTile(
                  leading: Icon(Icons.link, color: mine ? colorScheme.primary : null),
                  title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${_fp(a.account)} · '
                    '${a.playing ? 'Riproduzione: ${a.title.isEmpty ? 'Track' : a.title}' : 'Inattivo'}'
                    '${mine ? ' — questo desktop' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
    );
  }

  static String _fp(String account) =>
      account.length <= 8 ? account : account.substring(0, 8);
}
