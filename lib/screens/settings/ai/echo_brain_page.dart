import 'package:flutter/material.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:get_it/get_it.dart';

import '../../../core/widgets/back_button.dart';
import '../../../services/echo_brain_service.dart';
import '../../../services/media_player.dart';
import '../../../services/settings_manager.dart';
import '../../../ytmusic/ytmusic.dart';

/// Real EchoBrain: generates a themed playlist via the configured AI provider
/// and plays the suggested tracks through MediaPlayer.
class EchoBrainPage extends StatefulWidget {
  const EchoBrainPage({super.key});

  @override
  State<EchoBrainPage> createState() => _EchoBrainPageState();
}

class _EchoBrainPageState extends State<EchoBrainPage> {
  final _theme = TextEditingController(text: 'Late night focus');
  List<Map<String, String>> _tracks = [];
  bool _loading = false;

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final s = GetIt.I<SettingsManager>();
    final apiKey = s.translationApiKey;
    if (apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Set an API key in AI Hub first')));
      }
      return;
    }
    setState(() => _loading = true);
    final tracks = await GetIt.I<EchoBrainService>().generatePlaylist(
      apiKey: apiKey,
      baseUrl: s.translationBaseUrl,
      model: s.translationModel,
      theme: _theme.text,
      taste: const ['electronic', 'ambient'],
    );
    if (mounted) setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  Future<void> _playSuggested(Map<String, String> track) async {
    final query = '${track['artist']} ${track['title']}';
    try {
      final result = await GetIt.I<YTMusic>().search(query);
      final songs = result['songs'] as List? ?? [];
      if (songs.isNotEmpty && songs.first is Map) {
        await GetIt.I<MediaPlayer>()
            .playSong(Map<String, dynamic>.from(songs.first as Map));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No match found for $query')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).EchoBrainPlaylists),
        leading: echoBackButton(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _theme,
              decoration: const InputDecoration(
                labelText: 'Playlist theme',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Generate playlist'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _tracks.isEmpty
                  ? const Center(
                      child: Text('No suggestions yet. Generate a playlist.'))
                  : ListView.separated(
                      itemCount: _tracks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = _tracks[i];
                        return ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(t['title'] ?? ''),
                          subtitle: Text(t['artist'] ?? ''),
                          onTap: () => _playSuggested(t),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
