import 'dart:async';

import 'package:flutter/material.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/widgets/back_button.dart';
import '../../../../services/import_service.dart';

/// Real port of Android `SpotifyImportScreen.kt`: import a Spotify (or
/// YouTube Music) playlist by URL using the existing ImportService, with
/// live progress. Uses the app's bundled Spotify client credentials.
class SpotifyImportPage extends StatefulWidget {
  const SpotifyImportPage({super.key});

  @override
  State<SpotifyImportPage> createState() => _SpotifyImportPageState();
}

class _SpotifyImportPageState extends State<SpotifyImportPage> {
  final _url = TextEditingController();
  final _secret = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (Hive.isBoxOpen('SETTINGS')) {
      _secret.text = Hive.box('SETTINGS')
              .get('SPOTIFY_CLIENT_SECRET', defaultValue: '')
              ?.toString() ??
          '';
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _import() {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    // Stored locally, never compiled into the distributed binary.
    if (Hive.isBoxOpen('SETTINGS')) {
      unawaited(
          Hive.box('SETTINGS').put('SPOTIFY_CLIENT_SECRET', _secret.text.trim()));
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgress(stream: ImportService().import(url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).ImportFromSpotify),
        leading: echoBackButton(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste a Spotify or YouTube Music playlist URL. Echo will find '
              'each track on YouTube Music and add it to your library.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Playlist URL',
                hintText: 'https://open.spotify.com/playlist/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _secret,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Spotify client secret',
                hintText: 'Your own app credentials',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stored locally on this device only. It is not bundled in the '
              'installer; without it Spotify playlist import is unavailable.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.download),
              label: const Text('Import playlist'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportProgress extends StatelessWidget {
  const _ImportProgress({required this.stream});
  final Stream<ImportState> stream;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importing…'),
      content: StreamBuilder<ImportState>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator()));
          }
          final s = snapshot.data!;
          final progress = s.total > 0 ? s.current / s.total : 0.0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.message),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: s.isDone ? 1.0 : progress),
              if (s.total > 0) Text('${s.current}/${s.total}'),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
