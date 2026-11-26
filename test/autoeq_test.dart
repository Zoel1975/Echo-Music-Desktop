import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/autoeq_service.dart';
import 'package:Echo/services/axion_eq_service.dart';

void main() {
  test('AutoEq index parser handles names and paths with parentheses', () {
    final index = '''
# Index
This is a list of all equalization profiles.

- [1MORE Aero (ANC Off)](./HypetheSonics/GRAS%20RA0045%20in-ear/1MORE%20Aero%20(ANC%20Off)) by HypetheSonics on GRAS RA0045
- [Sennheiser HD 600](./oratory1990/harman_over-ear_2018/Sennheiser%20HD%20600) by oratory1990
- [Sony WH-1000XM5](./Rtings/HMS%20II.3%20over-ear/Sony%20WH-1000XM5) by Rtings
''';
    final profiles = AutoEqService.parseIndex(index);
    expect(profiles, hasLength(3));
    expect(profiles.first.name, '1MORE Aero (ANC Off)');
    expect(profiles.first.author, 'HypetheSonics');
    expect(profiles.first.target, 'GRAS RA0045');
    expect(profiles[1].source, 'oratory1990');
    expect(profiles.last.rawUrl, contains('Sony%20WH-1000XM5/ParametricEQ.txt'));

    // Search is fed by the same in-memory list the UI uses.
    AutoEqService.search(''); // no crash before load
    expect(AutoEqProfile.fromMarkdown('not a profile').name, isEmpty);
  });

  test('ParametricEQ text maps to the app 10 bands', () {
    final gains = AxionEqService.parseAutoEqProfile('''
Preamp: -5.0 dB
Filter 1: ON PK Fc 31 Hz Gain 4.5 dB Q 1.0
Filter 2: ON PK Fc 10000 Hz Gain -3.0 dB Q 0.7
''');
    expect(gains, hasLength(10));
    expect(gains.first, 4.5);
    expect(gains[8], -3.0, reason: '10 kHz maps to the nearest 8 kHz band');
    expect(gains[5], 0.0);
  });
}
