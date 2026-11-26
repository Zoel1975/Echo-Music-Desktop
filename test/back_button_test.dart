import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail/menu screens expose a back button', () {
    final files = [
      'lib/screens/account/account_page.dart',
      'lib/screens/settings/appearance/appearance_details_page.dart',
      'lib/screens/settings/integrations/integration_page.dart',
      'lib/screens/settings/player/equalizer/equalizer_page.dart',
      'lib/screens/library/playlist/playlist_details_page.dart',
      'lib/screens/library/history/history_detail_page.dart',
      'lib/screens/account/device_link_page.dart',
      'lib/screens/settings/services/spotify/spotify_import_page.dart',
      'lib/screens/settings/player/equalizer/axion_eq_page.dart',
      'lib/screens/settings/ai/echo_brain_page.dart',
      'lib/screens/detail/playlist_page.dart',
      'lib/screens/connect/cast_page.dart',
    ];
    for (final f in files) {
      final src = File(f).readAsStringSync();
      expect(src, contains('echoBackButton(context)'),
          reason: '$f has no back button');
    }
  });

  test('back button goes back when possible, home otherwise', () {
    final src =
        File('lib/core/widgets/back_button.dart').readAsStringSync();
    expect(src, contains('context.canPop()'));
    expect(src, contains('context.pop()'));
    expect(src, contains("context.go('/')"));
  });
}
