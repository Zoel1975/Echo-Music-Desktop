import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/core/theme/tokens.dart';

void main() {
  group('EchoTokens', () {
    test('seed is Android Echo\'s 0xFFED5564', () {
      expect(EchoTokens.seedColor, const Color(0xFFED5564));
    });

    test('radii follow DESIGN.md', () {
      expect(EchoTokens.cornerLarge, 24);
      expect(EchoTokens.cornerExtraLarge, 28);
      expect(EchoTokens.cornerSmall, 16);
    });

    test('surfaces are translucent: surfaceVariant @ 30%', () {
      expect(EchoTokens.surfaceAlpha, 0.3);
    });

    test('Apple glass values (GlassEffect.kt)', () {
      expect(EchoTokens.glassOpacity, 0.4);
      expect(EchoTokens.glassVibrancy, 1.5);
      expect(EchoTokens.glassTintLight, const Color(0xFFFAFAFA));
      expect(EchoTokens.glassTintDark, const Color(0xFF121212));
    });

    test('touch targets are at least 48dp (WCAG 2.5.5)', () {
      expect(EchoTokens.touchTarget, 48);
    });

    test('default spacing scale is even (4dp M3 base)', () {
      for (final s in [
        EchoTokens.space1,
        EchoTokens.space2,
        EchoTokens.space3,
        EchoTokens.space4,
        EchoTokens.space5,
        EchoTokens.space6,
        EchoTokens.space7,
        EchoTokens.space8,
        EchoTokens.space9,
      ]) {
        expect(s % 4, 0);
      }
    });
  });
}
