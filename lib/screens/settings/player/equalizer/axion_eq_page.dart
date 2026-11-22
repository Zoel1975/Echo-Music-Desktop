import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/widgets/back_button.dart';
import '../../../../services/autoeq_service.dart';
import '../../../../services/axion_eq_service.dart';
import '../../../../services/settings_manager.dart';
import '../../../../services/silence_filter.dart';

/// AXION / AutoEq equalizer with the full AutoEq database searchable inline:
/// type a headphone name, tap a result, the 10 bands are applied immediately.
class AxionEqPage extends StatefulWidget {
  const AxionEqPage({super.key});

  @override
  State<AxionEqPage> createState() => _AxionEqPageState();
}

class _AxionEqPageState extends State<AxionEqPage> {
  late List<double> _gains;
  String _presetName = 'Custom';
  final _search = TextEditingController();
  List<AutoEqProfile> _results = const [];
  bool _indexLoading = true;
  String? _applying;
  String? _error;

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
    _loadIndex();
  }

  Future<void> _loadIndex() async {
    final profiles = await AutoEqService.loadIndex();
    if (!mounted) return;
    setState(() {
      _indexLoading = false;
      _results = profiles.take(30).toList();
      _error = profiles.isEmpty
          ? 'Indice AutoEq non disponibile (verifica la connessione).'
          : null;
    });
  }

  void _filter(String query) {
    setState(() => _results = AutoEqService.search(query));
  }

  Future<void> _applyProfile(AutoEqProfile profile) async {
    setState(() => _applying = profile.name);
    final gains = await AutoEqService.fetchGains(profile);
    if (!mounted) return;
    setState(() => _applying = null);
    if (gains == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profilo "${profile.name}" non caricato.')),
      );
      return;
    }
    setState(() {
      _gains = gains;
      _presetName = profile.name;
    });
    _save();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AutoEq applicato: ${profile.name}')),
    );
  }

  void _save() {
    final s = GetIt.I<SettingsManager>();
    s.setExtra<String>(
        'axionEQGains', AxionEqService.encodePreset(EqPreset(_presetName, _gains)));
    s.equalizerEnabled = true;
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
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AXION / AutoEq equalizer'),
        leading: echoBackButton(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: 'Incolla profilo AutoEq (avanzato)',
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
          const SizedBox(height: 24),
          Text('Cerca profili AutoEq',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: _filter,
            decoration: InputDecoration(
              hintText: 'Es. Sennheiser HD 600, Sony XM5…',
              prefixIcon: _indexLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.orange)),
          ],
          const SizedBox(height: 8),
          if (_results.isEmpty && !_indexLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Nessun profilo trovato.'),
            ),
          ..._results.map(
            (p) => ListTile(
              title: Text(p.name),
              subtitle: Text('${p.author} · ${p.source}'
                  '${p.target.isEmpty ? '' : ' · ${p.target}'}'),
              trailing: _applying == p.name
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _presetName == p.name
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.tune),
              onTap: () => _applyProfile(p),
            ),
          ),
          const SizedBox(height: 24),
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
        title: const Text('Incolla profilo AutoEq'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Filter N: ... Gain -x dB',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
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
            child: const Text('Importa'),
          ),
        ],
      ),
    );
  }
}
