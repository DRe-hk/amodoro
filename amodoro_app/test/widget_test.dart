import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amodoro_app/theme/amodoro_theme.dart';

void main() {
  test('AmodoroTheme contrast and Coral pill constants', () {
    expect(AmodoroTheme.coralPillLight, const Color(0xFFF08076));
    expect(AmodoroTheme.coralPillDark, const Color(0xFFD96B62));

    final pastelCoral = AmodoroTheme.parseHexColor('#FFDAD6');
    expect(
      AmodoroTheme.getContrastingInk(pastelCoral),
      const Color(0xFF1F1B18),
    );
  });
}
