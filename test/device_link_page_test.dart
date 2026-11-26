import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'package:Echo/screens/account/device_link_page.dart';
import 'package:Echo/services/device_link_announcement.dart';
import 'package:Echo/services/remote_control_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Hive.init(Directory.systemTemp.path + '\\echo_hive_device_link_test');
    await Hive.openBox('COOKIES');
  });

  void _replaceRCS() {
    if (GetIt.I.isRegistered<RemoteControlService>()) {
      GetIt.I.unregister<RemoteControlService>();
    }
    final rcs = GetIt.I.registerSingleton<RemoteControlService>(RemoteControlService());
    rcs.addLinkedAnnounce(DeviceLinkAnnounce(
      id: 'a1', name: 'Pixel 8', account: 'deadbeef', playing: true,
      songId: 's1', title: 'A Song', updatedAt: 2,
    ));
    rcs.addLinkedAnnounce(DeviceLinkAnnounce(
      id: 'a2', name: 'Echo Laptop', account: 'cafebabe', playing: false, updatedAt: 1,
    ));
  }

  setUp(() => _replaceRCS());

  testWidgets('lists linked peers with name, account, playing state',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeviceLinkPage()));
    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.text('Echo Laptop'), findsOneWidget);
    expect(find.textContaining('deadbeef'), findsAny);
    expect(find.textContaining('cafebabe'), findsAny);
    expect(find.textContaining('Riproduzione'), findsAny);
  });

  testWidgets('empty state when no announces yet', (tester) async {
    if (GetIt.I.isRegistered<RemoteControlService>()) {
      GetIt.I.unregister<RemoteControlService>();
    }
    GetIt.I.registerSingleton<RemoteControlService>(RemoteControlService());
    await tester.pumpWidget(const MaterialApp(home: DeviceLinkPage()));
    expect(find.textContaining('Nessun dispositivo'), findsOneWidget);
  });
}
