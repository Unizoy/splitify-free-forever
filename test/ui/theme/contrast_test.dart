import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../support/contrast.dart';

void main() {
  test('contrastRatio helper: black on white is 21:1', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.001));
  });

  // R3-A (S-445): avatar initials (12–21 sp) are small text: 4.5:1 on their tint, light and dark.
  for (final entry in {'light': AppPalette.avatarLight, 'dark': AppPalette.avatarDark}.entries) {
    for (final (i, tint) in entry.value.indexed) {
      test(
        '${entry.key} avatar tint $i',
        () => expectContrast(tint.fg, tint.bg, 4.5, reason: '${entry.key} avatar $i'),
      );
    }
  }

  // TC-B3-03 (a11y): every token pair meets its WCAG AA minimum.
  for (final entry in {'light': AppColors.light, 'dark': AppColors.dark}.entries) {
    group('${entry.key} token contrast', () {
      for (final (label, fg, bg, min) in entry.value.contrastPairs) {
        test(label, () => expectContrast(fg, bg, min, reason: '${entry.key} $label'));
      }
    });
  }
}
