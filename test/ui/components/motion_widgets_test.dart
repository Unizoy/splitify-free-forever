import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/components/motion_widgets.dart';
import 'package:splitify/ui/theme/theme.dart';

final ThemeData _theme = AppTheme.light();

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: _theme,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => n++), child: Text('count $n'));
}

void main() {
  group('MotionSwitcher', () {
    Widget switcher(String key, {bool grow = false, VoidCallback? onTap}) => MotionSwitcher(
      grow: grow,
      child: SizedBox(
        key: ValueKey(key),
        height: 40,
        child: TextButton(onPressed: onTap, child: Text('child $key')),
      ),
    );

    testWidgets('first build shows the child without a transition', (tester) async {
      await tester.pumpWidget(_app(switcher('a')));
      expect(find.text('child a'), findsOneWidget);
      final scale = tester.widget<ScaleTransition>(
        find.descendant(of: find.byType(MotionSwitcher), matching: find.byType(ScaleTransition)),
      );
      expect(scale.scale.value, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('both children are present mid-way, only the new one at 180 ms', (tester) async {
      await tester.pumpWidget(_app(switcher('a')));
      await tester.pumpWidget(_app(switcher('b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text('child a'), findsOneWidget);
      expect(find.text('child b'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pump();
      expect(find.text('child a'), findsNothing);
      expect(find.text('child b'), findsOneWidget);
    });

    testWidgets('the old child ignores pointers and the new one takes taps mid-transition', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(_app(switcher('a')));
      await tester.pumpWidget(_app(switcher('b', onTap: () => taps++)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        find.ancestor(of: find.text('child a'), matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      await tester.tap(find.text('child b'));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('grow uses SizeTransition', (tester) async {
      await tester.pumpWidget(_app(switcher('a', grow: true)));
      await tester.pumpWidget(_app(switcher('b', grow: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        find.descendant(of: find.byType(MotionSwitcher), matching: find.byType(SizeTransition)),
        findsWidgets,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('grow false uses no SizeTransition', (tester) async {
      await tester.pumpWidget(_app(switcher('a')));
      await tester.pumpWidget(_app(switcher('b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        find.descendant(of: find.byType(MotionSwitcher), matching: find.byType(SizeTransition)),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion removes the old child after one pump', (tester) async {
      await tester.pumpWidget(_app(switcher('a'), reduced: true));
      await tester.pumpWidget(_app(switcher('b'), reduced: true));
      await tester.pump();
      expect(find.text('child a'), findsNothing);
      expect(find.text('child b'), findsOneWidget);
    });
  });

  group('AppExpand', () {
    Widget expand({required bool open, Widget? child}) => AppExpand(
      open: open,
      child: child ?? const SizedBox(key: Key('body'), height: 100, width: 100),
    );

    testWidgets('closed builds nothing', (tester) async {
      await tester.pumpWidget(_app(expand(open: false)));
      expect(find.byKey(const Key('body')), findsNothing);
    });

    testWidgets('open at first build shows the child in full', (tester) async {
      await tester.pumpWidget(_app(expand(open: true)));
      expect(tester.getSize(find.byKey(const Key('body'))).height, 100);
      expect(tester.getSize(find.byType(AppExpand)).height, 100);
    });

    testWidgets('opening grows the height and is full after 220 ms', (tester) async {
      await tester.pumpWidget(_app(expand(open: false)));
      await tester.pumpWidget(_app(expand(open: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getSize(find.byType(AppExpand)).height;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(100));
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();
      expect(tester.getSize(find.byType(AppExpand)).height, 100);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('closing collapses and removes the child after 220 ms', (tester) async {
      await tester.pumpWidget(_app(expand(open: true)));
      await tester.pumpWidget(_app(expand(open: false)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const Key('body')), findsOneWidget);
      expect(tester.getSize(find.byType(AppExpand)).height, lessThan(100));
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();
      expect(find.byKey(const Key('body')), findsNothing);
    });

    testWidgets('a button inside is tappable mid-open', (tester) async {
      var taps = 0;
      Widget tree({required bool open}) => _app(
        expand(
          open: open,
          child: TextButton(onPressed: () => taps++, child: const Text('go')),
        ),
      );
      await tester.pumpWidget(tree(open: false));
      await tester.pumpWidget(tree(open: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('go'));
      expect(taps, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion opens and closes at once', (tester) async {
      await tester.pumpWidget(_app(expand(open: false), reduced: true));
      await tester.pumpWidget(_app(expand(open: true), reduced: true));
      expect(tester.getSize(find.byType(AppExpand)).height, 100);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_app(expand(open: false), reduced: true));
      expect(find.byKey(const Key('body')), findsNothing);
    });

    testWidgets('the child keeps its state when the open animation ends', (tester) async {
      Widget tree({required bool open}) => _app(expand(open: open, child: const _Counter()));
      await tester.pumpWidget(tree(open: false));
      await tester.pumpWidget(tree(open: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.textContaining('count'));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);
    });
  });

  group('SelectionMotion', () {
    Widget selection({required bool selected, required List<double> seen}) => SelectionMotion(
      selected: selected,
      builder: (context, t, child) {
        seen.add(t);
        return Text('t=${t.toStringAsFixed(3)}');
      },
    );

    testWidgets('first build is at the selected value without motion', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(_app(selection(selected: true, seen: seen)));
      expect(seen.last, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('first build unselected starts at 0', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(_app(selection(selected: false, seen: seen)));
      expect(seen.last, 0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('t goes from 0 to 1 over 150 ms', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(_app(selection(selected: false, seen: seen)));
      await tester.pumpWidget(_app(selection(selected: true, seen: seen)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(seen.last, allOf(greaterThan(0), lessThan(1)));
      await tester.pump(const Duration(milliseconds: 75));
      expect(seen.last, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion jumps straight to the new value', (tester) async {
      final seen = <double>[];
      await tester.pumpWidget(_app(selection(selected: false, seen: seen), reduced: true));
      await tester.pumpWidget(_app(selection(selected: true, seen: seen), reduced: true));
      await tester.pump();
      expect(seen.last, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
