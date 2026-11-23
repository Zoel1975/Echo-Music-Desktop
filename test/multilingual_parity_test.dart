import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = ['en', 'it', 'es', 'hi', 'tr', 'ur'];

  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/intl_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> keys(Map<String, dynamic> data) =>
      data.keys.where((k) => !k.startsWith('@')).toSet();

  test('all locales expose the exact same set of messages', () {
    final reference = keys(arb('en'));
    expect(reference.length, greaterThan(280));
    for (final locale in locales) {
      expect(keys(arb(locale)), equals(reference),
          reason: '$locale has missing or extra keys');
    }
  });

  test('generated message bundles contain every message', () {
    final reference = keys(arb('en'));
    for (final locale in locales) {
      final source =
          File('lib/generated/intl/messages_$locale.dart').readAsStringSync();
      final generated = RegExp(r'^    "([A-Za-z0-9_]+)":', multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      expect(generated, equals(reference),
          reason: '$locale generated bundle is out of sync with its ARB');
    }
  });

  test('the previously missing messages are translated in every locale', () {
    const added = [
      'Translate_Lyrics',
      'Autofetch_Songs',
      'Backup_Success',
      'No_Internet_Connection',
      'QueuedCount',
      'FileNotFound',
    ];
    for (final locale in locales) {
      final data = arb(locale);
      for (final key in added) {
        expect(data[key], isA<String>(), reason: '$locale missing $key');
        expect((data[key] as String).trim(), isNotEmpty,
            reason: '$locale has empty $key');
      }
    }
    expect(arb('es')['Retry'], 'Reintentar');
    expect(arb('tr')['Retry'], 'Tekrar dene');
    expect(arb('hi')['QueuedCount'], contains('{count}'));
  });

  test('settings menus have no hardcoded labels left', () {
    final files = Directory('lib/screens/settings')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final offenders = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      final matches = RegExp(
        r"(?:title|label|subtitle|message|tooltip)\s*:\s*(?:const\s+)?'([^']{3,})'",
      ).allMatches(source);
      for (final m in matches) {
        if (!m.group(1)!.contains(r'$')) {
          offenders.add('${file.path}: ${m.group(1)}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'untranslated labels: $offenders');
  });
}
