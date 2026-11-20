import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:Echo/core/widgets/floating_nav.dart';
import 'package:Echo/generated/l10n.dart';
import 'package:Echo/screens/shell/app_shell.dart';
import 'package:Echo/services/audio_device_service.dart';
import 'package:Echo/services/media_player.dart';
import 'package:Echo/services/remote_control_service.dart';
import 'package:Echo/services/settings_manager.dart';
import 'package:Echo/services/stream_resolver.dart';
import 'package:Echo/utils/router.dart';
import 'package:Echo/ytmusic/ytmusic.dart';

/// Stubs every HTTP call so the real router/home branch can build offline.
class _StubHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HttpOverrides.global = _StubHttp();
    final hiveDir = Directory('${Directory.systemTemp.path}/echo_navbar_test');
    if (!hiveDir.existsSync()) hiveDir.createSync(recursive: true);
    Hive.init(hiveDir.path);
    for (final name in [
      'SETTINGS',
      'QUEUE',
      'FAVOURITES',
      'HISTORY',
      'DOWNLOADS',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
    final gi = GetIt.I;
    if (!gi.isRegistered<SettingsManager>()) {
      gi.registerSingleton<SettingsManager>(_FakeSettings());
    }
    if (!gi.isRegistered<AudioDeviceService>()) {
      gi.registerSingleton<AudioDeviceService>(AudioDeviceService());
    }
    if (!gi.isRegistered<RemoteControlService>()) {
      gi.registerSingleton<RemoteControlService>(RemoteControlService());
    }
    if (!gi.isRegistered<String>(instanceName: 'audioStreamUrl')) {
      gi.registerSingleton<String>('http://127.0.0.1:1/audio',
          instanceName: 'audioStreamUrl');
    }
    if (!gi.isRegistered<YTMusic>()) {
      gi.registerSingleton<YTMusic>(YTMusic());
    }
    if (!gi.isRegistered<MediaPlayer>()) {
      gi.registerSingleton<MediaPlayer>(_FakePlayer());
    }
    StreamResolver.instance.cookieHeaderProvider = () => null;
  });

  testWidgets('real AppShell tree renders exactly one in-viewport options bar',
      (tester) async {
    const size = Size(1000, 700);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // The real shell (AppShell) is in the widget tree.
    expect(find.byType(AppShell), findsOneWidget);

    // Exactly one options bar, from the real AppShell.build().
    final bars = find.byType(EchoFloatingNavBar);
    expect(bars, findsOneWidget);

    // No competing navigation surface anywhere in the real tree.
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);

    // The bar is actually laid out inside the viewport.
    final rect = tester.getRect(bars);
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    expect(rect.bottom, lessThan(size.height));
    expect(rect.top, greaterThan(0));
  });
}

class _FakeSettings extends SettingsManager {
  @override
  ThemeMode get themeMode => ThemeMode.dark;
}

class _FakePlayer extends MediaPlayer {
  _FakePlayer() : super();
}
