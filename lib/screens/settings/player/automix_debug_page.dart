import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/widgets/back_button.dart';
import '../../../../services/automix_debug.dart';
import '../../../../services/settings_manager.dart';
import '../widgets/setting_item.dart';
import '../widgets/settings_list.dart';

String _ms(int? value) => value == null ? '—' : '${(value / 1000).toStringAsFixed(2)}s';

/// Port of Android's Automix debug overlay, with a rolling log of the whole
/// transition (analysis -> pre-arm -> handoff -> fade -> done).
class AutomixDebugPage extends StatelessWidget {
  const AutomixDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Diagnostica Automix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Pulisci log',
            onPressed: AutomixDebug.instance.clear,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AutomixDebug.instance,
        builder: (context, _) {
          final d = AutomixDebug.instance;
          final mono = TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          );
          return SettingsList(
            children: [
              AnimatedBuilder(
                animation: GetIt.I<SettingsManager>(),
                builder: (context, _) {
                  final settings = GetIt.I<SettingsManager>();
                  return SettingSwitchTile(
                    title: 'Mostra overlay nel player',
                    subtitle: 'Stato Automix in sovrimpressione',
                    leading: const Icon(Icons.dashboard_customize_outlined),
                    value: settings.extra<bool>('automixOverlay', false),
                    onChanged: (value) =>
                        settings.setExtra<bool>('automixOverlay', value),
                  );
                },
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AUTOMIX  ${d.status}', style: mono),
                      const SizedBox(height: 6),
                      Text(
                        'crossfade=${d.crossfadeEnabled}  automix=${d.automixEnabled}',
                        style: mono,
                      ),
                      Text(
                        'armed=${d.preArmed}  handoff=${d.handoffRunning}  '
                        'fade=${d.fading}',
                        style: mono,
                      ),
                      Text(
                        'lead=${_ms(d.leadMs)}  blend=${_ms(d.blendMs)}  '
                        'trigger=${_ms(d.triggerTimeMs)}',
                        style: mono,
                      ),
                      Text(
                        'vol: main=${d.mainVolume.toStringAsFixed(2)} '
                        'out=${d.outVolume.toStringAsFixed(2)}  '
                        'ratio=${d.tempoRatio?.toStringAsFixed(3) ?? '—'}',
                        style: mono,
                      ),
                      const Divider(),
                      Text(
                        'OUT: ${d.outBeat?.bpm.toStringAsFixed(1) ?? '—'} bpm '
                        '${d.outBeat?.keyLabel ?? ''} '
                        'conf=${d.outBeat?.confidence.toStringAsFixed(2) ?? '—'}',
                        style: mono,
                      ),
                      Text(
                        '     mixOut=${_ms(d.outBeat?.mixOutMs)} '
                        'offset=${_ms(d.outBeat?.firstBeatOffsetMs.toInt())}',
                        style: mono,
                      ),
                      Text(
                        'IN:  ${d.inBeat?.bpm.toStringAsFixed(1) ?? '—'} bpm '
                        '${d.inBeat?.keyLabel ?? ''} '
                        'conf=${d.inBeat?.confidence.toStringAsFixed(2) ?? '—'}',
                        style: mono,
                      ),
                      Text(
                        '     mixIn=${_ms(d.inBeat?.mixInMs)} '
                        'start=${_ms(d.incomingStartMs)}',
                        style: mono,
                      ),
                      if (d.harmonicChoice != null)
                        Text(
                          'ARMONIA: ${d.harmonicChoice} '
                          'score=${d.harmonicScore?.toStringAsFixed(2) ?? '—'}',
                          style: mono.copyWith(color: Colors.tealAccent),
                        ),
                      if (d.lastError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('ERRORE: ${d.lastError}',
                              style: mono.copyWith(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const GroupTitle(title: 'Log eventi'),
              ...d.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    e.formatted,
                    style: mono.copyWith(
                      color: e.level == 'WARN'
                          ? Colors.orangeAccent
                          : e.level == 'ERROR'
                              ? Colors.redAccent
                              : null,
                    ),
                  ),
                ),
              ),
              if (d.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('Nessun evento')),
                ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
