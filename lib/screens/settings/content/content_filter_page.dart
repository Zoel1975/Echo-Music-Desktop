import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../services/content_filter_service.dart';
import '../widgets/setting_item.dart';

/// Real port of Android `BlockedArtistsScreen.kt` / `DislikedSongsScreen.kt`.
class ContentFilterPage extends StatefulWidget {
  const ContentFilterPage({super.key, required this.mode});
  final String mode; // 'artists' or 'songs'

  @override
  State<ContentFilterPage> createState() => _ContentFilterPageState();
}

class _ContentFilterPageState extends State<ContentFilterPage> {
  final service = GetIt.I<ContentFilterService>();
  final _controller = TextEditingController();

  bool get _isArtists => widget.mode == 'artists';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      if (_isArtists) {
        service.blockArtist(value);
      } else {
        service.dislikeSong(value, value);
      }
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _isArtists ? service.blockedArtists : service.dislikedSongs;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isArtists ? 'Blocked Artists' : 'Disliked Songs'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all',
              onPressed: () => setState(() {
                if (_isArtists) {
                  service.clearBlockedArtists();
                } else {
                  service.clearDislikedSongs();
                }
              }),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: _isArtists ? 'Artist name' : 'Song id / title',
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        _isArtists
                            ? 'No blocked artists'
                            : 'No disliked songs',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(150),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        return ListTile(
                          leading: Icon(
                            _isArtists ? Icons.person_off : Icons.heart_broken,
                          ),
                          title: Text(entry),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(() {
                              if (_isArtists) {
                                service.unblockArtist(entry);
                              } else {
                                service.likeSong(entry);
                              }
                            }),
                          ),
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
