import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/back_button.dart';
import '../../services/cast/cast_device.dart';
import '../../services/cast/cast_service.dart';

/// Android `CastDevicePickerSheet` equivalent: discover receivers and connect.
/// Once connected the app opens [CastSessionPage], like Android's
/// `CastSessionSheet`.
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

  Future<void> _connect(CastDevice device) async {
    await _cast.connect(device);
    if (!mounted) return;
    if (_cast.isCasting) context.push('/cast/session');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Trasmetti su un dispositivo'),
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
        builder: (context, status, _) =>
            ValueListenableBuilder<List<CastDevice>>(
          valueListenable: _cast.devices,
          builder: (context, devices, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              if (status.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(status),
                  ),
                ),
              const SizedBox(height: 12),
              Text('Dispositivi disponibili',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (devices.isEmpty && !_cast.scanning.value)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nessun dispositivo trovato. Assicurati che la TV o lo '
                    'speaker sia acceso e sulla stessa rete di questo PC.',
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
                  trailing: const Icon(Icons.cast),
                  onTap: () => _connect(d),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
