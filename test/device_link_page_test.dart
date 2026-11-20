import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:Echo/screens/account/device_link_page.dart';
import 'package:Echo/services/device_link_service.dart';

class _FakeDeviceLink extends DeviceLinkService {
  @override
  Future<String> start() async => '123456';

  @override
  bool get isListening => true;
}

void main() {
  setUp(() {
    final gi = GetIt.I;
    if (!gi.isRegistered<DeviceLinkService>()) {
      gi.registerSingleton<DeviceLinkService>(_FakeDeviceLink());
    }
  });

  testWidgets('device link page shows pairing code and network address',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DeviceLinkPage()));
    // _start() awaits NetworkInterface.list for the LAN address.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Collega dispositivo mobile'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Copia codice'), findsOneWidget);
    expect(find.text('Indirizzo di rete locale'), findsOneWidget);
    expect(GetIt.I<DeviceLinkService>().isListening, isTrue);
  });
}
