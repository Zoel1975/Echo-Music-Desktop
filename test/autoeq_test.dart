import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/autoeq_service.dart';

void main() {
  const index = '''
# Index
- [AKG K371](./oratory1990/over-ear/AKG%20K371) by oratory1990
- [AKG K371](./crinacle/GRAS%2043AG-7%20over-ear/AKG%20K371) by crinacle
- [7Hz Salnotes Zero](./oratory1990/in-ear/7Hz%20Salnotes%20Zero) by oratory1990
''';

  test('parses the official AutoEq markdown index', () {
    final profiles = AutoEqService.parseIndex(index);
    expect(profiles, hasLength(3));
    expect(profiles.first.name, 'AKG K371');
    expect(profiles.first.source, 'oratory1990');
    expect(profiles.first.path, 'oratory1990/over-ear/AKG%20K371');
  });

  test('search ranks prefix matches above substring matches', () {
    final profiles = AutoEqService.parseIndex(index);
    final result = AutoEqService.search(profiles, 'akg');
    expect(result, hasLength(2));
    expect(result.first.name, 'AKG K371');
    expect(AutoEqService.search(profiles, 'salnotes').single.name,
        '7Hz Salnotes Zero');
    expect(AutoEqService.search(profiles, 'zzz'), isEmpty);
  });

  test('builds the parametric EQ URL with the profile-specific file name', () {
    final profile = AutoEqService.parseIndex(index).first;
    expect(
      AutoEqService.parametricEqUrl(profile),
      'https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/'
      'results/oratory1990/over-ear/AKG%20K371/'
      'AKG%20K371%20ParametricEQ.txt',
    );
  });
}
