import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../support/contrast.dart';

void main() {
  test('contrastRatio helper: black on white is 21:1', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.001));
  });

  // TC-B3-03 (a11y): every token pair meets its WCAG AA minimum.
  for (final entry in {'light': AppColors.light, 'dark': AppColors.dark}.entries) {
    group('${entry.key} token contrast', () {
      for (final (label, fg, bg, min) in entry.value.contrastPairs) {
        test(label, () => expectContrast(fg, bg, min, reason: '${entry.key} $label'));
      }
    });
  }
}
