import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/screens/shell/widgets/bottom_player.dart';

double luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

void main() {
  test('light album art is darkened so white text stays legible', () {
    final background = readableMiniPlayerBackground(Colors.white);
    expect(luminance(background), lessThanOrEqualTo(0.22));
    expect(background.r, lessThan(Colors.white.r));
    expect(
      ThemeData.estimateBrightnessForColor(background),
      Brightness.dark,
    );
  });

  test('already-dark album art is left alone', () {
    final original = Color(0xFF121212);
    expect(readableMiniPlayerBackground(original), original);
  });

  test('source file no longer paints white text on a light palette', () {
    final source = readFileSync('lib/screens/shell/widgets/bottom_player.dart');
    expect(source, contains('readableMiniPlayerBackground'));
    expect(source, contains('palette.darkVibrantColor'));
    expect(source, contains('const foreground = Colors.white'));
    expect(source, isNot(contains('color: Colors.white,')));
  });
}

String readFileSync(String path) => File(path).readAsStringSync();
