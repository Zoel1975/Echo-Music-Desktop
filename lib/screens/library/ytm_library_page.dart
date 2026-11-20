import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../services/account_refresh.dart';
import '../../services/cookie_store.dart';
import '../../services/media_player.dart';
import '../../ytmusic/ytmusic.dart';

/// Real signed-in YouTube Music library (port of Android's LibraryScreen /
/// playlists tabs). Uses LibraryMixin endpoints that were implemented but
/// never surfaced in the UI — this is what actually changes after login.
class YtmLibraryPage extends StatefulWidget {
  const YtmLibraryPage({super.key});

  @override
  State<YtmLibraryPage> createState() => _YtmLibraryPageState();
}

class _YtmLibraryPageState extends State<YtmLibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _yt = GetIt.I<YTMusic>();
  final _cache = <int, List<dynamic>>{};
  final _errors = <int, String>{};
  bool _loading = false;

  static const _labels = ['Playlist', 'Brani', 'Album', 'Artisti'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load(_tabs.index);
    });
    accountEpoch.addListener(_onAccountChanged);
    _load(0);
  }

  void _onAccountChanged() {
    _cache.clear();
    _errors.clear();
    _load(_tabs.index);
  }

  @override
  void dispose() {
    accountEpoch.removeListener(_onAccountChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load(int index) async {
    // Never hit the network while logged out (avoids hangs and empty errors).
    if (CookieStore.instance.cookieHeader == null) return;
    if (_cache.containsKey(index)) return;
    setState(() => _loading = true);
    try {
      final res = switch (index) {
        0 => await _yt.getLibraryPlaylists(),
        1 => await _yt.getLibrarySongs(),
        2 => await _yt.getLibraryAlbums(),
        _ => await _yt.getLibraryArtists(),
      };
      final contents = (res['contents'] as List?) ?? const [];
      if (mounted) setState(() {
        _cache[index] = contents;
        _errors.remove(index);
      });
    } catch (e) {
      if (mounted) setState(() => _errors[index] = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(Map item, int tab) {
    final endpoint = item['endpoint'] as Map?;
    final browseId = endpoint?['browseId']?.toString() ??
        item['browseId']?.toString() ??
        '';
    if (tab == 1) {
      final videoId = item['videoId']?.toString();
      if (videoId != null && videoId.isNotEmpty) {
        GetIt.I<MediaPlayer>().playSong({
          'videoId': videoId,
          'title': item['title'],
          'artists': [{'name': item['subtitle'] ?? ''}],
        });
      }
      return;
    }
    if (browseId.isEmpty) return;
    if (tab == 0) {
      context.go('/playlist', extra: {'playlistId': browseId});
    } else if (tab == 2) {
      context.go('/album', extra: {'browseId': browseId});
    } else {
      context.go('/artist', extra: {'browseId': browseId});
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = CookieStore.instance.cookieHeader != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('La tua libreria YouTube Music'),
        bottom: TabBar(controller: _tabs, tabs: _labels.map((l) => Tab(text: l)).toList()),
      ),
      body: !signedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Effettua il login con Google per vedere la tua '
                    'libreria YouTube Music.', textAlign: TextAlign.center),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: List.generate(_labels.length, (i) => _tabBody(i)),
            ),
    );
  }

  Widget _tabBody(int index) {
    if (_loading && !_cache.containsKey(index)) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _errors[index];
    if (error != null) return Center(child: Text('Errore: $error'));
    final items = _cache[index] ?? const [];
    if (items.isEmpty) {
      return const Center(child: Text('Nessun elemento.'));
    }
    if (index == 1) {
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final item = items[i] as Map;
          return ListTile(
            leading: _thumb(item),
            title: Text(item['title']?.toString() ?? ''),
            subtitle: Text(item['subtitle']?.toString() ?? ''),
            onTap: () => _open(item, index),
          );
        },
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i] as Map;
        return InkWell(
          onTap: () => _open(item, index),
          child: Card(
            child: Column(
              children: [
                Expanded(child: _thumb(item)),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    item['title']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(Map item) {
    final thumbs = item['thumbnails'] as List?;
    final url = thumbs != null && thumbs.isNotEmpty
        ? (thumbs.last as Map)['url']?.toString()
        : null;
    return url != null
        ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
            const Icon(Icons.music_note))
        : const Icon(Icons.music_note);
  }
}
