import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/components/feedback.dart';
import 'package:splitify/ui/components/success_check.dart';
import 'package:splitify/ui/theme/theme.dart';

final ThemeData _theme = AppTheme.light();

Widget _app(Widget body, {bool reduced = false}) => MaterialApp(
  theme: _theme,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: body),
  ),
);

SuccessCheckPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(SuccessCheck), matching: find.byType(CustomPaint)),
  );
  return paint.painter! as SuccessCheckPainter;
}

void main() {
  group('SuccessCheck', () {
    testWidgets('starts empty and finishes after 280 ms', (tester) async {
      await tester.pumpWidget(_app(const Center(child: SuccessCheck())));
      expect(_painter(tester).draw, 0);
      expect(_painter(tester).pop, 0);

      await tester.pump(const Duration(milliseconds: 140));
      final mid = _painter(tester);
      expect(mid.pop, allOf(greaterThan(0), lessThan(1.2)));
      expect(mid.draw, allOf(greaterThan(0), lessThan(1)));

      await tester.pump(const Duration(milliseconds: 150));
      final end = _painter(tester);
      expect(end.draw, 1);
      expect(end.pop, closeTo(1, 0.1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is still running at 260 ms and settled by 300 ms', (tester) async {
      await tester.pumpWidget(_app(const Center(child: SuccessCheck())));
      await tester.pump(const Duration(milliseconds: 260));
      expect(_painter(tester).draw, lessThan(1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();
      expect(_painter(tester).draw, 1);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('plays once: a rebuild does not restart it', (tester) async {
      await tester.pumpWidget(_app(const Center(child: SuccessCheck())));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(const Center(child: SuccessCheck(size: 40))));
      expect(_painter(tester).draw, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion shows the finished mark at once', (tester) async {
      await tester.pumpWidget(_app(const Center(child: SuccessCheck()), reduced: true));
      expect(_painter(tester).draw, 1);
      expect(_painter(tester).pop, closeTo(1, 0.1));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('uses the requested size and colours', (tester) async {
      await tester.pumpWidget(
        _app(
          const Center(
            child: SuccessCheck(size: 20, color: Color(0xFF112233), checkColor: Color(0xFFAABBCC)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(SuccessCheck)), const Size.square(20));
      expect(_painter(tester).circle, const Color(0xFF112233));
      expect(_painter(tester).check, const Color(0xFFAABBCC));
      await tester.pumpAndSettle();
    });
  });

  group('SuccessCheckPainter', () {
    const base = SuccessCheckPainter(
      pop: 0.5,
      draw: 0.5,
      circle: Color(0xFF000000),
      check: Color(0xFFFFFFFF),
    );

    test('shouldRepaint is true for any changed field', () {
      expect(base.shouldRepaint(base), isFalse);
      expect(
        base.shouldRepaint(
          const SuccessCheckPainter(
            pop: 0.5,
            draw: 0.5,
            circle: Color(0xFF000000),
            check: Color(0xFFFFFFFF),
          ),
        ),
        isFalse,
      );
      expect(
        base.shouldRepaint(
          const SuccessCheckPainter(
            pop: 0.6,
            draw: 0.5,
            circle: Color(0xFF000000),
            check: Color(0xFFFFFFFF),
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const SuccessCheckPainter(
            pop: 0.5,
            draw: 0.6,
            circle: Color(0xFF000000),
            check: Color(0xFFFFFFFF),
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const SuccessCheckPainter(
            pop: 0.5,
            draw: 0.5,
            circle: Color(0xFF111111),
            check: Color(0xFFFFFFFF),
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const SuccessCheckPainter(
            pop: 0.5,
            draw: 0.5,
            circle: Color(0xFF000000),
            check: Color(0xFF111111),
          ),
        ),
        isTrue,
      );
    });

    test('paints at every stage without throwing, including overshoot and zero', () {
      for (final (pop, draw) in [(0.0, 0.0), (0.5, 0.2), (1.08, 0.6), (1.0, 1.0), (-0.1, 1.5)]) {
        final recorder = PictureRecorder();
        SuccessCheckPainter(
          pop: pop,
          draw: draw,
          circle: const Color(0xFF000000),
          check: const Color(0xFFFFFFFF),
        ).paint(Canvas(recorder), const Size.square(96));
        recorder.endRecording().dispose();
      }
    });
  });

  group('success feedback', () {
    Widget page({required bool success}) => Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => showAppMessage(context, 'Saved it', success: success),
          child: const Text('show'),
        ),
      ),
    );

    testWidgets('showAppMessage(success: true) shows a snackbar with the check and the text', (
      tester,
    ) async {
      await tester.pumpWidget(_app(page(success: true)));
      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SuccessLine), findsOneWidget);
      expect(find.byKey(const Key('success-check')), findsOneWidget);
      expect(find.text('Saved it'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('showAppMessage(success: false) shows plain text only', (tester) async {
      await tester.pumpWidget(_app(page(success: false)));
      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(SuccessLine), findsNothing);
      expect(find.byKey(const Key('success-check')), findsNothing);
      expect(find.text('Saved it'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('successSnackBar defaults to the check and a 4 s duration', (tester) async {
      final bar = successSnackBar('Paid');
      expect(bar.content, isA<SuccessLine>());
      expect(bar.duration, const Duration(milliseconds: 4000));
      expect(successSnackBar('Paid', success: false).content, isA<Text>());
      expect(
        successSnackBar('Paid', duration: const Duration(seconds: 1)).duration,
        const Duration(seconds: 1),
      );
    });

    testWidgets('inside a bottom sheet the message is the toast, with the check', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (sheet) => Center(
                    child: TextButton(
                      onPressed: () => showAppMessage(sheet, 'Saved it', success: true),
                      child: const Text('in sheet'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('in sheet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('sheet-toast')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('sheet-toast')),
          matching: find.byKey(const Key('success-check')),
        ),
        findsOneWidget,
      );
      expect(find.text('Saved it'), findsOneWidget);
      // The toast removes itself after 3 s.
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('sheet-toast')), findsNothing);
    });

    testWidgets('inside a bottom sheet a plain message has no check', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (sheet) => Center(
                    child: TextButton(
                      onPressed: () => showAppMessage(sheet, 'Plain'),
                      child: const Text('in sheet'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('in sheet'));
      await tester.pump();
      expect(find.byKey(const Key('sheet-toast')), findsOneWidget);
      expect(find.byKey(const Key('success-check')), findsNothing);
      expect(find.text('Plain'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
