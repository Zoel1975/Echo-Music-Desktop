import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../services/audio_encoder.dart';
import '../../services/download_manager.dart';
import '../../services/export_task_queue.dart';
import '../../services/settings_manager.dart';
import '../../../core/widgets/back_button.dart';
import 'widgets/settings_list.dart';

/// Real MP3 export screen: local audio files and downloaded songs are
/// transcoded by FFmpeg (LGPL audio build) into the Echo Music folder.
class ExportQueuePage extends StatelessWidget {
  const ExportQueuePage({super.key});

  Future<void> _pickFiles(ExportTaskQueue queue) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.audio,
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path != null) await queue.enqueue(f.path!);
    }
  }

  Future<void> _addDownloaded(BuildContext context, ExportTaskQueue queue) async {
    try {
      final downloaded = GetIt.I<DownloadManager>();
      final songs = downloaded.downloads.value
          .whereType<Map>()
          .where((s) => s['status']?.toString() == 'DOWNLOADED')
          .toList();
      if (songs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun brano scaricato')),
        );
        return;
      }
      for (final song in songs) {
        try {
          await queue.enqueueSong(Map<String, dynamic>.from(song));
        } on EncodeException {
          // Missing file: skip it and keep exporting the other downloads.
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gestore download non disponibile')),
      );
    }
  }

  Future<void> _openFolder(ExportTaskQueue queue) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [queue.exportDir.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [queue.exportDir.path]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<ExportTaskQueue>();
    final settings = context.watch<SettingsManager>();
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Esporta MP3'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Apri cartella export',
            onPressed: () => _openFolder(queue),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Pulisci completate',
            onPressed: queue.clearCompleted,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: settingsMaxWidth),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _pickFiles(queue),
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi file audio'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addDownloaded(context, queue),
                      icon: const Icon(Icons.download),
                      label: const Text('Aggiungi brani scaricati'),
                    ),
                    DropdownButton<int>(
                      value: settings.exportBitrateKbps,
                      underline: const SizedBox(),
                      items: const [128, 192, 256, 320]
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text('$b kbps'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) settings.exportBitrateKbps = v;
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: queue.tasks.isEmpty
                    ? const Center(child: Text('Nessuna esportazione'))
                    : ListView.separated(
                        itemCount: queue.tasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final t = queue.tasks[i];
                          return ListTile(
                            leading: Icon(
                              switch (t.status) {
                                ExportStatus.done => Icons.check_circle,
                                ExportStatus.failed => Icons.error,
                                ExportStatus.cancelled => Icons.block,
                                ExportStatus.running => Icons.hourglass_top,
                                ExportStatus.queued => Icons.schedule,
                              },
                              color: t.status == ExportStatus.failed
                                  ? Colors.red
                                  : null,
                            ),
                            title: Text(t.targetPath.split(RegExp(r'[/\\]')).last),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${t.stage} · ${t.bitrateKbps} kbps'
                                  '${t.progress != null ? ' · ${(t.progress! * 100).round()}%' : ''}',
                                ),
                                if (t.error != null)
                                  Text(t.error!,
                                      style: const TextStyle(color: Colors.red)),
                                LinearProgressIndicator(value: t.progress),
                              ],
                            ),
                            trailing: t.status == ExportStatus.running
                                ? IconButton(
                                    icon: const Icon(Icons.cancel),
                                    tooltip: 'Annulla',
                                    onPressed: () => queue.cancel(t.id),
                                  )
                                : (t.status == ExportStatus.failed ||
                                        t.status == ExportStatus.cancelled)
                                    ? IconButton(
                                        icon: const Icon(Icons.replay),
                                        tooltip: 'Riprova',
                                        onPressed: () => queue.retry(t.id),
                                      )
                                    : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
