// R3-A screen-size matrix (S-441): every main screen and sheet (r3_screens.dart) on seven frames — small
// phone 320 × 568, 360 × 640, 393 × 852, 412 × 915, large phone 480 × 1000, small tablet / open foldable
// 600 × 960 and tablet 840 × 1200 (portrait) — each at text 0.85, 1.0, 1.3 and 2.0 side by side in one
// picture (light), plus dark at 393 × 852 at 1.0 and 2.0. Any overflow fails the test; every picture runs the
// a11y guidelines (48 dp targets, labels, tap actions) through pumpFixedFrames.
// Review with real fonts: $env:PLATFORM_GOLDENS='1'; flutter test --update-goldens test/goldens/r3_sizes_golden_test.dart
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/text_contrast.dart';
import 'golden_support.dart';
import 'r3_screens.dart';

/// The frames (logical px, portrait).
const r3Sizes = <(String, Size)>[
  ('320x568', Size(320, 568)),
  ('360x640', Size(360, 640)),
  ('393x852', Size(393, 852)),
  ('412x915', Size(412, 915)),
  ('480x1000', Size(480, 1000)),
  ('600x960', Size(600, 960)),
  ('840x1200', Size(840, 1200)),
];

/// Text scales, smallest to largest.
const r3Scales = <double>[0.85, 1.0, 1.3, 2.0];

String _label(double s) => 'text ${s.toStringAsFixed(2)}';

GoldenTestGroup _group(
  R3Screen screen,
  SharedPreferences prefs,
  Size size,
  ThemeMode mode,
  List<double> scales,
) => GoldenTestGroup(
  // Tablets two per row, phones all in one row.
  columns: size.width >= 600 ? 2 : scales.length,
  children: [
    for (final s in scales)
      GoldenTestScenario(
        name: _label(s),
        constraints: BoxConstraints.tight(size),
        child: screen.build(prefs, size, mode, s),
      ),
  ],
);

/// The usual fixed frames and a11y guidelines, plus text contrast against the real backgrounds and
/// tabular figures on every standalone amount (S-443, S-445).
Future<void> _pump(WidgetTester t) async {
  await pumpFixedFrames(t);
  // R3_REPORT=1 (visual review runs): print the findings and still write the picture.
  if (Platform.environment['R3_REPORT'] == '1') {
    for (final g in [textOnSolidContrastGuideline, tabularAmountsGuideline]) {
      final e = await g.evaluate(t);
      if (!e.passed) debugPrint('R3-GUIDE ${t.testDescription}: ${e.reason}');
    }
    return;
  }
  await expectLater(t, meetsGuideline(textOnSolidContrastGuideline));
  await expectLater(t, meetsGuideline(tabularAmountsGuideline));
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  for (final screen in r3Screens()) {
    for (final (label, size) in r3Sizes) {
      goldenTest(
        'R3-A ${screen.name} $label',
        fileName: 'r3_${screen.name}_$label',
        pumpBeforeTest: _pump,
        builder: () => _group(screen, prefs, size, ThemeMode.light, r3Scales),
      );
    }
    goldenTest(
      'R3-A ${screen.name} 393x852 dark',
      fileName: 'r3_${screen.name}_393x852_dark',
      pumpBeforeTest: _pump,
      builder: () => _group(screen, prefs, const Size(393, 852), ThemeMode.dark, const [1.0, 2.0]),
    );
  }
}
