import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('docs avoid generated-guide boilerplate', () {
    for (final path in [
      'README.md',
      'docs/FEATURES.md',
      'docs/GETTING_STARTED.md',
      'docs/ARCHITECTURE.md',
      'docs/MP3_EXPORT.md',
      'docs/AGE_GATE.md',
    ]) {
      final text = File(path).readAsStringSync();
      for (final phrase in [
        'This guide',
        'This document',
        'This file',
        'crafted down to the last detail',
        'seamless',
      ]) {
        expect(text, isNot(contains(phrase)),
            reason: '$path contains "$phrase"');
      }
    }
  });

  test('docs contain no Italian leftovers', () {
    final buffer = StringBuffer();
    for (final file in Directory('docs').listSync().whereType<File>()) {
      if (file.path.endsWith('.md')) buffer.write(file.readAsStringSync());
    }
    buffer.write(File('README.md').readAsStringSync());
    final text = buffer.toString().toLowerCase();
    for (final word in [
      'tramite',
      'versione installata',
      'stai usando',
      'controlla aggiornamenti',
      'perché',
      'della ',
    ]) {
      expect(text, isNot(contains(word)), reason: 'Italian leftover: $word');
    }
  });
}
