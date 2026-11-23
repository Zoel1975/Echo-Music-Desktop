import 'dart:async';
import 'dart:math' as math;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/widgets/back_button.dart';
import '../../services/media_player.dart';
import '../../services/song_recognition_service.dart';
import '../../ytmusic/ytmusic.dart';

enum RecognitionState { ready, listening, processing, success, noMatch, error }

class SongRecognitionPage extends StatefulWidget {
  const SongRecognitionPage({super.key});

  @override
  State<SongRecognitionPage> createState() => _SongRecognitionPageState();
}

class _SongRecognitionPageState extends State<SongRecognitionPage>
    with SingleTickerProviderStateMixin {
  RecognitionState _state = RecognitionState.ready;
  RecognitionHit? _hit;
  String? _error;
  bool _indexing = false;
  int _indexed = 0;
  int _indexTotal = 0;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _indexed = SongRecognitionService.instance.indexedCount;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _recognize() async {
    if (_indexed == 0) {
      setState(() {
        _state = RecognitionState.error;
        _error = 'Indicizza prima la tua libreria musicale';
      });
      return;
    }
    setState(() {
      _state = RecognitionState.listening;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _state = RecognitionState.processing);
    try {
      final hit = await SongRecognitionService.instance.recognize();
      if (!mounted) return;
      if (hit == null) {
        setState(() => _state = RecognitionState.noMatch);
      } else {
        await SongRecognitionService.instance.saveHistory(hit);
        if (!mounted) return;
        setState(() {
          _hit = hit;
          _state = RecognitionState.success;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _state = RecognitionState.error;
      });
    }
  }

  Future<void> _indexLibrary() async {
    setState(() {
      _indexing = true;
      _indexTotal = 0;
    });
    try {
      final count = await SongRecognitionService.instance.indexLibrary(
        onProgress: (done, total) {
          if (mounted) setState(() {
            _indexed = done;
            _indexTotal = total;
          });
        },
      );
      if (mounted) setState(() => _indexed = count);
    } finally {
      if (mounted) setState(() => _indexing = false);
    }
  }

  Future<void> _playInEcho() async {
    if (_hit == null) return;
    try {
      final results = await GetIt.I<YTMusic>()
          .search('${_hit!.title} ${_hit!.artist}', filter: 'songs');
      final songs = (results['songs'] as List?) ?? const [];
      if (songs.isNotEmpty) {
        await GetIt.I<MediaPlayer>().playSong(Map<String, dynamic>.from(songs.first));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: echoBackButton(context),
          title: const Text('Riconoscimento brani'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => _showHistory(context),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stage(),
                const SizedBox(height: 32),
                Text(
                  _indexed == 0
                      ? 'Nessun brano indicizzato'
                      : '$_indexed brani indicizzati',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _indexing ? null : _indexLibrary,
                  icon: const Icon(Icons.library_music),
                  label: Text(_indexing
                      ? 'Indicizzazione $_indexed/$_indexTotal…'
                      : 'Indicizza la libreria'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Il riconoscimento funziona offline e trova solo brani '
                  'presenti nella tua libreria indicizzata.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _stage() => switch (_state) {
        RecognitionState.ready => _micButton(),
        RecognitionState.listening => const _ListeningBars(),
        RecognitionState.processing => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Elaborazione…'),
            ],
          ),
        RecognitionState.success => _success(),
        RecognitionState.noMatch => _message(
            Icons.search_off,
            'Nessuna corrispondenza nella libreria',
            'Prova con un brano indicizzato o registra piu\' a lungo.',
          ),
        RecognitionState.error => _message(
            Icons.error_outline,
            'Errore',
            _error ?? 'Errore sconosciuto',
          ),
      };

  Widget _micButton() => GestureDetector(
        onTap: _recognize,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Transform.scale(
            scale: 0.95 + _pulse.value * 0.1,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Icon(Icons.mic, size: 64, color: Colors.white),
            ),
          ),
        ),
      );

  Widget _success() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(_hit?.title ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          Text(_hit?.artist ?? '',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('Match ${(_hit!.score * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _playInEcho,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Riproduci'),
          ),
          TextButton(
            onPressed: () => setState(() => _state = RecognitionState.ready),
            child: const Text('Riprova'),
          ),
        ],
      );

  Widget _message(IconData icon, String title, String body) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => _state = RecognitionState.ready),
            child: const Text('Riprova'),
          ),
        ],
      );

  void _showHistory(BuildContext context) {
    final box = Hive.isBoxOpen(SongRecognitionService.boxHistory)
        ? Hive.box(SongRecognitionService.boxHistory)
        : null;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: box == null || box.isEmpty
            ? const Center(child: Text('Nessuna cronologia'))
            : ListView.builder(
                itemCount: box.length,
                itemBuilder: (context, i) {
                  final item = box.getAt(i);
                  if (item is! Map) return const SizedBox.shrink();
                  return ListTile(
                    title: Text(item['title']?.toString() ?? ''),
                    subtitle: Text(item['artist']?.toString() ?? ''),
                  );
                },
              ),
      ),
    );
  }
}

class _ListeningBars extends StatefulWidget {
  const _ListeningBars();

  @override
  State<_ListeningBars> createState() => _ListeningBarsState();
}

class _ListeningBarsState extends State<_ListeningBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();
  final _random = math.Random();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) {
                  final h = 20 + _random.nextInt(80).toDouble();
                  return Container(
                    width: 10,
                    height: h,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('In ascolto…'),
        ],
      );
}
