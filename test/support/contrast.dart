import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

/// WCAG relative luminance of [c] (alpha ignored).
double relativeLuminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG contrast ratio between two colours (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Fails unless [fg] on [bg] reaches [min] (4.5 for body text, 3 for large).
void expectContrast(Color fg, Color bg, double min, {String? reason}) {
  final ratio = contrastRatio(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(min),
    reason: '${reason ?? 'contrast'}: ${ratio.toStringAsFixed(2)}:1 < $min:1',
  );
}
