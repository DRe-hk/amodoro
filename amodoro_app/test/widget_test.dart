import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amodoro_app/theme/amodoro_theme.dart';

void main() {
  test('AmodoroTheme contrast and Neo-Pastel Coral pill constants', () {
    expect(AmodoroTheme.coralPillLight, const Color(0xFFF27166));
    expect(AmodoroTheme.coralPillDark, const Color(0xFFE06358));

    final pastelCoral = AmodoroTheme.parseHexColor('#FFDAD6');
    expect(
      AmodoroTheme.getContrastingInk(pastelCoral),
      const Color(0xFF473A3A),
    );
  });
}
