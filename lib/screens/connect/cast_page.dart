import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/widgets/back_button.dart';
import '../../services/cast/cast_device.dart';
import '../../services/cast/cast_service.dart';
import '../../services/remote_control_service.dart';

/// Device picker - the desktop equivalent of Android's CastButton +
/// CastDevicePickerSheet. Lists real Google Cast receivers discovered on the
/// LAN (Chromecast, Android TV, Nest Hub, TVs) and lets the user choose which
/// one plays the current YouTube Music queue.
class CastPage extends StatefulWidget {
  const CastPage({super.key});

  @override
  State<CastPage> createState() => _CastPageState();
}

class _CastPageState extends State<CastPage> {
  final _cast = GetIt.I<CastService>();

  @override
  void initState() {
    super.initState();
    _cast.scan();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Riproduci su un dispositivo'),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _cast.scanning,
        builder: (context, scanning, _) => FloatingActionButton(
          onPressed: scanning ? null : _cast.scan,
          tooltip: 'Cerca di nuovo',
          child: scanning
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: _cast.status,
        builder: (context, status, _) => ValueListenableBuilder<CastDevice?>(
          valueListenable: _cast.connected,
          builder: (context, connected, _) =>
              ValueListenableBuilder<List<CastDevice>>(
            valueListenable: _cast.devices,
            builder: (context, devices, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                children: [
                  if (status.isNotEmpty)
                    Card(
                      color: scheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(status),
                      ),
                    ),
                  if (connected != null) ...[
                    Card(
                      color: scheme.primaryContainer,
                      child: ListTile(
                        leading: const Icon(Icons.cast_connected),
                        title: Text('Connesso: ${connected.name}'),
                        subtitle: Text('${connected.kind.label} · ${connected.host}'),
                        trailing: TextButton.icon(
                          onPressed: _cast.disconnect,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnetti'),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: ValueListenableBuilder<bool>(
                        valueListenable: _cast.client.playing,
                        builder: (context, playing, _) => IconButton(
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed: _cast.togglePlayback,
                        ),
                      ),
                      title: const Text('Controllo remoto'),
                      subtitle: const Text('Play/pause sul dispositivo selezionato'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: const Text('Volume del dispositivo'),
                      subtitle: Slider(
                        min: 0,
                        max: 1,
                        onChanged: _cast.setVolume,
                        value: 0.5,
                      ),
                    ),
                    const Divider(),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Dispositivi disponibili',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (devices.isEmpty && !_cast.scanning.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Nessun dispositivo trovato. Assicurati che la TV o '
                        'lo speaker sia acceso e sulla stessa rete di questo PC.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...devices.map(
                    (d) => ListTile(
                      leading: Icon(
                        d.kind == CastDeviceKind.tv
                            ? Icons.tv
                            : d.kind == CastDeviceKind.speaker
                                ? Icons.speaker
                                : Icons.cast,
                      ),
                      title: Text(d.name),
                      subtitle: Text('${d.kind.label} · ${d.host}:${d.port}'),
                      trailing: connected == d
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cast),
                      onTap: () => _cast.connect(d),
                    ),
                  ),
                  const Divider(height: 32),
                  _RemoteCard(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RemoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rc = GetIt.I<RemoteControlService>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Controlla Echo dal telefono',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Con questo PC acceso, apri sul telefono (stessa Wi-Fi) l\'URL '
              'qui sotto per vedere il brano e comandare play/pause, skip e volume.',
            ),
            const SizedBox(height: 10),
            SelectableText(rc.url ?? 'Remote non avviato'),
          ],
        ),
      ),
    );
  }
}
