import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 19 T3 (reduced motion): every animation in the app follows "Remove animations".
/// Implicit animations take their durations from `context.motion` (zero when reduced), and every
/// hand-driven [AnimationController] checks `context.motion.reduced` before it runs.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  test('there are app sources to scan', () => expect(files, isNotEmpty));

  test('every AnimationController honours reduced motion', () {
    final offenders = [
      for (final f in files)
        if (f.readAsStringSync().contains('AnimationController(') &&
            !f.readAsStringSync().contains('motion.reduced'))
          f.path,
    ];
    expect(offenders, isEmpty, reason: 'controllers must stop when context.motion.reduced');
  });

  test('implicit animations use motion tokens, not fixed durations', () {
    final implicit = RegExp(
      r'Animated(Container|Opacity|Switcher|Size|Align|Positioned|CrossFade|Padding|Scale|Rotation|Slide)\(|TweenAnimationBuilder',
    );
    final fixed = RegExp(r'duration:\s*(const\s+)?Duration\(');
    final offenders = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!implicit.hasMatch(lines[i])) continue;
        // The widget's arguments follow on the next lines.
        final window = lines.skip(i).take(8).join('\n');
        if (fixed.hasMatch(window)) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'use context.motion.fast/base/slow/showcase');
  });
}
