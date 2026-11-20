import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../services/device_link_service.dart';

/// Desktop counterpart of YouTube Music's "link a device" flow. Shows a short
/// pairing code and the LAN address the mobile app connects to. When the mobile
/// app posts the code together with its cookies, the session is shared.
class DeviceLinkPage extends StatefulWidget {
  const DeviceLinkPage({super.key});

  @override
  State<DeviceLinkPage> createState() => _DeviceLinkPageState();
}

class _DeviceLinkPageState extends State<DeviceLinkPage> {
  final _service = GetIt.I<DeviceLinkService>();
  String _code = '';
  String _address = '...';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final code = await _service.start();
    if (!mounted) return;
    // Show the pairing code immediately; the LAN address loads separately.
    setState(() {
      _code = code;
      _started = _service.isListening;
    });
    final ip = await _localIp();
    if (mounted) {
      setState(() => _address = 'http://$ip:${DeviceLinkService.port}');
    }
  }

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final i in interfaces) {
        for (final a in i.addresses) {
          if (!a.isLoopback) return a.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiato negli appunti')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collega dispositivo mobile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Collega il telefono a Echo Desktop',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'In Echo mobile apri Impostazioni → Account → Collega dispositivo, '
                'scegli la rete locale e inserisci il codice qui sotto. Le credenziali '
                'verranno condivise in Automatico, come YouTube Music.',
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Codice di accoppiamento',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        _started ? _code : '...',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _started ? () => _copy(_code) : null,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copia codice'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.wifi),
                title: const Text('Indirizzo di rete locale'),
                subtitle: Text(_address),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copy(_address),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _started ? Icons.check_circle : Icons.error,
                    color: _started ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(_started
                      ? 'In ascolto di connessioni sulla rete locale'
                      : 'Server non avviato (porta occupata?)'),
                ],
              ),
              const SizedBox(height: 32),
              if (_service.devices.isNotEmpty) ...[
                const Text('Dispositivi collegati',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._service.devices.map(
                  (d) => ListTile(
                    leading: const Icon(Icons.smartphone),
                    title: Text(d.name),
                    subtitle: Text('ID: ${d.id}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Keep the server alive for the session so pairing can happen later.
    super.dispose();
  }
}
