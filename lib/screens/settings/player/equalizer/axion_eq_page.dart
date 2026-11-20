import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/back_button.dart';
import '../../../../services/axion_eq_service.dart';
import '../../../../services/settings_manager.dart';
import '../../../../services/silence_filter.dart';

/// Real AXION / AutoEq equalizer: headphone presets, 10-band sliders and
/// AutoEq profile import. Gains are persisted via SettingsManager.
class AxionEqPage extends StatefulWidget {
  const AxionEqPage({super.key});

  @override
  State<AxionEqPage> createState() => _AxionEqPageState();
}

class _AxionEqPageState extends State<AxionEqPage> {
  late List<double> _gains;
  String _presetName = 'Custom';

  @override
  void initState() {
    super.initState();
    final s = GetIt.I<SettingsManager>();
    final saved = s.extra<String>('axionEQGains', '');
    if (saved.isNotEmpty) {
      try {
        final p = AxionEqService.decodePreset(saved);
        _gains = List<double>.from(p.gains);
        _presetName = p.name;
      } catch (_) {
        _gains = List<double>.from(AxionEqService.presets.first.gains);
      }
    } else {
      _gains = List<double>.from(AxionEqService.presets.first.gains);
    }
  }

  void _save() {
    final s = GetIt.I<SettingsManager>();
    s.setExtra<String>(
        'axionEQGains', AxionEqService.encodePreset(EqPreset(_presetName, _gains)));
    s.equalizerEnabled = true;
    // Apply the 10-band EQ to the desktop mpv filter chain (combined with
    // skip-silence if enabled).
    SilenceFilter.apply(
      enabled: s.skipSilence,
      eqGains: _gains,
      eqEnabled: true,
    );
  }

  void _applyPreset(EqPreset p) {
    setState(() {
      _gains = List<double>.from(p.gains);
      _presetName = p.name;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AXION / AutoEq equalizer'),
        leading: echoBackButton(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import AutoEq profile',
            onPressed: _importProfile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Presets', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: AxionEqService.presets
                .map((p) => ChoiceChip(
                      label: Text(p.name),
                      selected: _presetName == p.name,
                      onSelected: (_) => _applyPreset(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text('10-band equalizer',
              style: Theme.of(context).textTheme.titleMedium),
          ...List.generate(eqFrequencies.length, (i) {
            return Column(
              children: [
                Slider(
                  value: _gains[i].clamp(-12, 12),
                  min: -12,
                  max: 12,
                  divisions: 24,
                  label: '${_gains[i].toStringAsFixed(1)} dB',
                  onChanged: (v) {
                    setState(() {
                      _gains[i] = v;
                      _presetName = 'Custom';
                    });
                    _save();
                  },
                ),
                Text('${eqFrequencies[i].toInt()} Hz'),
              ],
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _importProfile() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import AutoEq profile'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Paste AutoEq profile (Filter N: ... Gain -x dB)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final gains = AxionEqService.parseAutoEqProfile(controller.text);
              setState(() {
                _gains = gains;
                _presetName = 'Imported';
              });
              _save();
              Navigator.of(ctx).pop();
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
