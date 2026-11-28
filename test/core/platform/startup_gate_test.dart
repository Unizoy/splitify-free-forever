import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/platform/startup_gate.dart';

/// Only [waitUntilFirstFrameRasterized] is read by [StartupGate.arm].
class _FakeBinding extends Fake implements WidgetsBinding {
  final firstFrame = Completer<void>();

  @override
  Future<void> get waitUntilFirstFrameRasterized => firstFrame.future;
}

void main() {
  setUp(StartupGate.debugReset);
  tearDown(StartupGate.debugReset);

  Future<bool> opened(WidgetTester tester) async {
    var done = false;
    unawaited(StartupGate.afterFirstFrame.then((_) => done = true));
    await tester.pump();
    return done;
  }

  group('StartupGate', () {
    testWidgets('not armed: afterFirstFrame completes at once and run executes at once', (
      tester,
    ) async {
      expect(StartupGate.armed, isFalse);
      expect(await opened(tester), isTrue);
      var ran = false;
      StartupGate.run(() async => ran = true);
      await tester.pump();
      expect(ran, isTrue);
    });

    testWidgets('armed: closed before the first frame', (tester) async {
      final binding = _FakeBinding();
      StartupGate.arm(binding: binding);
      expect(StartupGate.armed, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(await opened(tester), isFalse);
      expect(StartupGate.armed, isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('armed: opens 600 ms after the first frame, not before', (tester) async {
      final binding = _FakeBinding();
      StartupGate.arm(binding: binding);
      binding.firstFrame.complete();
      await tester.pump();
      expect(await opened(tester), isFalse, reason: 'first frame alone is not enough');

      await tester.pump(const Duration(milliseconds: 590));
      expect(await opened(tester), isFalse);
      expect(StartupGate.armed, isTrue);

      await tester.pump(const Duration(milliseconds: 20));
      expect(await opened(tester), isTrue);
      expect(StartupGate.armed, isFalse);
      // The fallback timer was cancelled by the first frame: nothing left pending.
    });

    testWidgets('armed: opens after the 4 s fallback when no frame ever comes', (tester) async {
      StartupGate.arm(binding: _FakeBinding());
      await tester.pump(const Duration(milliseconds: 3900));
      expect(await opened(tester), isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(await opened(tester), isTrue);
      expect(StartupGate.armed, isFalse);
    });

    testWidgets('the fallback still opens the gate only once when the frame arrives later', (
      tester,
    ) async {
      final binding = _FakeBinding();
      StartupGate.arm(binding: binding);
      await tester.pump(const Duration(seconds: 5));
      expect(await opened(tester), isTrue);
      binding.firstFrame.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(await opened(tester), isTrue);
    });

    testWidgets('arm twice keeps the first gate', (tester) async {
      final first = _FakeBinding();
      final second = _FakeBinding();
      StartupGate.arm(binding: first);
      StartupGate.arm(binding: second);
      second.firstFrame.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(await opened(tester), isFalse, reason: 'only the first binding counts');
      first.firstFrame.complete();
      await tester.pump(const Duration(milliseconds: 700));
      expect(await opened(tester), isTrue);
    });

    testWidgets('run waits for the gate and then executes the work once', (tester) async {
      final binding = _FakeBinding();
      StartupGate.arm(binding: binding);
      var runs = 0;
      StartupGate.run(() async => runs++);
      await tester.pump(const Duration(seconds: 1));
      expect(runs, 0);
      binding.firstFrame.complete();
      await tester.pump(const Duration(milliseconds: 700));
      expect(runs, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(runs, 1);
    });

    testWidgets('debugReset makes a new arm possible', (tester) async {
      StartupGate.arm(binding: _FakeBinding());
      StartupGate.debugReset();
      expect(StartupGate.armed, isFalse);
      expect(await opened(tester), isTrue);
      final binding = _FakeBinding();
      StartupGate.arm(binding: binding);
      expect(StartupGate.armed, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('arm without a binding argument opens by itself (first frame or fallback)', (
      tester,
    ) async {
      StartupGate.arm();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(await opened(tester), isTrue);
    });
  });
}
