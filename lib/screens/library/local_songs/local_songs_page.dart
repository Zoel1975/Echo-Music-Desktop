import 'dart:io';

import 'package:easy_folder_picker/FolderPicker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../services/file_storage.dart';
import '../../../services/local_song_scanner.dart';
import '../../../services/media_player.dart';
import '../../../services/settings_manager.dart';

/// Real port of Android `LocalSongScreen` + `LocalSongScanner`: pick a folder,
/// scan it for audio files, and play them locally. The scan root is persisted
/// so it is restored on next launch.
class LocalSongsPage extends StatefulWidget {
  const LocalSongsPage({super.key});

  @override
  State<LocalSongsPage> createState() => _LocalSongsPageState();
}

class _LocalSongsPageState extends State<LocalSongsPage> {
  final scanner = LocalSongScanner();
  List<Map<String, dynamic>> _songs = [];
  String _folder = '';
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _folder = GetIt.I<SettingsManager>().localMusicFolder;
    if (_folder.isNotEmpty) _scan(_folder);
  }

  Future<void> _pickFolder() async {
    final root = _folder.isNotEmpty
        ? Directory(_folder)
        : Directory(Platform.environment['USERPROFILE'] ?? Directory.current.path);
    final picked = await FolderPicker.pick(
      context: context,
      rootDirectory: root.existsSync() ? root : Directory.current,
      allowFolderCreation: true,
      message: 'Select a folder with music files',
    );
    if (picked != null) {
      setState(() => _folder = picked.path);
      GetIt.I<SettingsManager>().localMusicFolder = picked.path;
      await _scan(picked.path);
    }
  }

  Future<void> _scan(String folder) async {
    setState(() => _scanning = true);
    final songs = await scanner.scan(Directory(folder));
    if (mounted) setState(() {
      _songs = songs;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<MediaPlayer>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local songs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Choose folder',
            onPressed: _pickFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _folder.isEmpty ? 'No folder selected' : _folder,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_songs.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => player.playAll(_songs),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play all'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _scanning
                ? const Center(child: CircularProgressIndicator())
                : _songs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _folder.isEmpty
                                ? 'Choose a folder to scan for music files.'
                                : 'No audio files found in this folder.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _songs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final song = _songs[i];
                          return ListTile(
                            leading: const Icon(Icons.audiotrack, size: 40),
                            title: Text(song['title']?.toString() ?? 'Unknown'),
                            subtitle: Text(song['artists']?.first['name'] ?? ''),
                            onTap: () => player.playLocalFile(song),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
