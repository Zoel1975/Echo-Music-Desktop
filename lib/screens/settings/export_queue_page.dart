import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../services/export_task_queue.dart';

/// Real screen for Android `ExportTaskQueue`: pick local audio files, enqueue
/// them for export, and watch per-task progress.
class ExportQueuePage extends StatelessWidget {
  const ExportQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<ExportTaskQueue>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export as MP3'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear completed',
            onPressed: queue.clearCompleted,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () async {
                final result = await FilePicker.pickFiles(
                  allowMultiple: true,
                  type: FileType.audio,
                );
                if (result == null) return;
                for (final f in result.files) {
                  if (f.path != null) await queue.enqueue(f.path!);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add audio files to export'),
            ),
          ),
          Expanded(
            child: queue.tasks.isEmpty
                ? const Center(child: Text('No export tasks'))
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
                            Text(t.status.name.toUpperCase()),
                            if (t.error != null)
                              Text(t.error!,
                                  style: const TextStyle(color: Colors.red)),
                            LinearProgressIndicator(value: t.progress),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
