import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String path) => File(path).readAsStringSync();

void main() {
  test('Automix debug mirrors Android fields and keeps a rolling log', () {
    final debug = src('lib/services/automix_debug.dart');
    for (final field in [
      'status',
      'outBeat',
      'inBeat',
      'triggerTimeMs',
      'incomingStartMs',
      'tempoRatio',
    ]) {
      expect(debug, contains(field));
    }
    expect(debug, contains('automix.log'));
    expect(debug, contains('_entries.length > 150'));
  });

  test('crossfade flow is instrumented end to end', () {
    final player = src('lib/services/media_player.dart');
    for (final marker in [
      'pre-arm idx=',
      'pre-arm FALLITO',
      'standby non pronto',
      'CROSSFADE AVVIATO',
      'crossfade completato',
      'analisi OUT:',
      'analisi IN:',
      'handoff start',
      'crossfade utente:',
    ]) {
      expect(player, contains(marker), reason: 'missing log: $marker');
    }
  });

  test('debug screen is reachable from Player settings and the probe', () {
    final router = src('lib/utils/router.dart');
    expect(router, contains("path: 'automix_debug'"));
    expect(router, contains('AutomixDebugPage'));

    final page = src('lib/screens/settings/player/player_settings_page.dart');
    expect(page, contains("'Diagnostica Automix'"));
    expect(page, contains('/settings/player/automix_debug'));

    final search = src('lib/screens/settings/settings_page.dart');
    expect(search, contains("('Automix', 'Riproduttore'"));

    final probe = src('lib/services/runtime_probe_service.dart');
    expect(probe, contains("path == '/automix/state'"));
    expect(probe, contains('AutomixDebug.instance.toJson()'));

    final debugPage = src(
        'lib/screens/settings/player/automix_debug_page.dart');
    expect(debugPage, contains('automixOverlay'));

    final playerPage = src('lib/screens/player/player_page.dart');
    expect(playerPage, contains("'AUTOMIX "));

    final engine = src('lib/services/media_player.dart');
    expect(engine, contains('bool _xfadePreparing = false;'));

  });
}
