import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/audio_encoder.dart';
import 'package:Echo/services/export_task_queue.dart';
import 'package:Echo/utils/export_feedback.dart';

class _NoopEncoder implements AudioEncoder {
  @override
  Future<void> encode({
    required String inputPath,
    required String outputPath,
    required int bitrateKbps,
    int? durationMs,
    Map<String, String> tags = const {},
    String? coverUrl,
    void Function(double? progress)? onProgress,
    void Function(int sessionId)? onSession,
  }) async {}

  @override
  Future<void> cancel(int sessionId) async {}
}

ExportTask _task() => ExportTask(
      id: '1',
      sourcePath: r'C:\Downloads\Echo\Music\Com e.m4a',
      targetPath: r'C:\Downloads\Echo\Music\Unknown - Com e.mp3',
      bitrateKbps: 192,
      tags: const {},
    );

void main() {
  testWidgets('progress feedback names the track and can be cancelled',
      (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    final queue = ExportTaskQueue(
      exportDir: Directory.systemTemp,
      encoder: _NoopEncoder(),
    );
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: messenger,
      home: const Scaffold(),
    ));

    ExportFeedback.progress(messenger.currentState!, queue, _task(), 'Com è');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Exporting to MP3'), findsOneWidget);
    expect(find.textContaining('Com è'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('completion feedback shows the file and opens the folder',
      (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: messenger,
      home: const Scaffold(),
    ));

    ExportFeedback.done(messenger.currentState!, _task());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MP3 saved to your Music folder'), findsOneWidget);
    expect(find.text('Unknown - Com e.mp3'), findsOneWidget);
    expect(find.text('Open folder'), findsOneWidget);
  });

  testWidgets('failure feedback shows the error instead of a blank toast',
      (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: messenger,
      home: const Scaffold(),
    ));

    ExportFeedback.failed(messenger.currentState!, 'Track is not downloaded');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Export failed'), findsOneWidget);
    expect(find.textContaining('Track is not downloaded'), findsOneWidget);
  });
}
