import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/crossfade_prearm.dart';

void main() {
  test('starts with the Android 20 second base lead', () {
    final manager = AdaptivePreArmManager();
    expect(manager.currentLeadTime, const Duration(seconds: 20));
  });

  test('expands the lead when preparation is slow', () {
    final manager = AdaptivePreArmManager();
    manager.recordPreparationDuration(const Duration(seconds: 10));
    expect(manager.currentLeadTime, greaterThan(const Duration(seconds: 20)));
    expect(manager.currentLeadTime,
        lessThanOrEqualTo(const Duration(seconds: 35)));
  });

  test('never exceeds the 35 second cap', () {
    final manager = AdaptivePreArmManager();
    for (var i = 0; i < 10; i++) {
      manager.recordPreparationDuration(const Duration(seconds: 60));
    }
    expect(manager.currentLeadTime, const Duration(seconds: 35));
  });

  test('decays back toward the base after fast preparations', () {
    final manager = AdaptivePreArmManager();
    manager.recordPreparationDuration(const Duration(seconds: 20));
    final expanded = manager.currentLeadTime;
    for (var i = 0; i < 10; i++) {
      manager.recordPreparationDuration(const Duration(seconds: 2));
    }
    expect(manager.currentLeadTime, lessThan(expanded));
    expect(manager.currentLeadTime,
        greaterThanOrEqualTo(const Duration(seconds: 20)));
  });

  test('reset restores the base lead', () {
    final manager = AdaptivePreArmManager();
    manager.recordPreparationDuration(const Duration(seconds: 30));
    manager.reset();
    expect(manager.currentLeadTime, const Duration(seconds: 20));
  });
}
