import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/back_button.dart';
import '../../services/cast/cast_device.dart';
import '../../services/cast/cast_service.dart';

/// Android `CastSessionSheet` equivalent: controls for the connected receiver.
class CastSessionPage extends StatelessWidget {
  const CastSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cast = GetIt.I<CastService>();
    final device = cast.connected.value;
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Riproduzione su dispositivo'),
      ),
      body: device == null
          ? const Center(child: Text('Nessun dispositivo collegato.'))
          : ValueListenableBuilder<bool>(
              valueListenable: cast.client.playing,
              builder: (context, playing, _) => ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.cast_connected, size: 48),
                          const SizedBox(height: 12),
                          Text(device.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          Text('${device.kind.label} · ${device.host}'),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled),
                                iconSize: 56,
                                onPressed: cast.togglePlayback,
                              ),
                              IconButton(
                                icon: const Icon(Icons.stop_circle, size: 44),
                                onPressed: cast.stop,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Volume del dispositivo',
                      style: Theme.of(context).textTheme.titleMedium),
                  Slider(
                    min: 0,
                    max: 1,
                    value: 0.5,
                    onChanged: cast.setVolume,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      cast.disconnect();
                      context.pop();
                    },
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnetti'),
                  ),
                ],
              ),
            ),
    );
  }
}
