import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../services/bottom_message.dart';
import '../../../services/storage_service.dart';
import '../widgets/setting_item.dart';
import '../../../../core/widgets/back_button.dart';

/// Real port of Android `StorageSettings.kt`: cache sizes + clear actions.
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  final StorageService _storage = GetIt.I<StorageService>();
  int _songBytes = 0;
  int _imageBytes = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _songBytes = _storage.songCacheBytes;
      _imageBytes = _storage.imageCacheBytes;
    });
  }

  Future<void> _clear(Future<int> Function() action, String label) async {
    final bytes = await action();
    _refresh();
    if (mounted) {
      BottomMessage.showText(context, '$label cleared (${StorageService.formatBytes(bytes)})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Storage')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              const GroupTitle(title: 'Song Cache'),
              SettingTile(
                title: 'Clear song cache',
                subtitle: StorageService.formatBytes(_songBytes),
                leading: const Icon(Icons.audiotrack),
                isFirst: true,
                isLast: true,
                onTap: () => _clear(_storage.clearSongCache, 'Song cache'),
              ),
              const GroupTitle(title: 'Image Cache'),
              SettingTile(
                title: 'Clear image cache',
                subtitle: StorageService.formatBytes(_imageBytes),
                leading: const Icon(Icons.image),
                isFirst: true,
                isLast: true,
                onTap: () => _clear(_storage.clearImageCache, 'Image cache'),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
