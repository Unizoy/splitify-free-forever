// QA motion (S-260..S-267): the tap primitive, count-up, entrance, tab fade-through, shared-axis routes,
// shimmer, fade-in and the pre-blurred glass card.
import 'dart:async';

import 'package:flutter/gestures.dart' show kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

double _scaleOf(WidgetTester t, Finder of) {
  // storage[0] is the x scale (getMaxScaleOnAxis also counts z, always 1).
  final transforms = t.widgetList<Transform>(
    find.descendant(of: of, matching: find.byType(Transform)),
  );
  return transforms.first.transform.storage[0];
}

String _text(WidgetTester t, Key key) => t.widget<Text>(find.byKey(key)).data!;

class _Counter extends StatefulWidget {
  const _Counter(this.label);

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => n++), child: Text('${widget.label} $n'));
}

void main() {
  group('Pressable', () {
    testWidgets('presses in, springs back and fires on finger up', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _app(
          Pressable(
            key: const Key('p'),
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      );
      final g = await t.startGesture(t.getCenter(find.byKey(const Key('p'))));
      await t.pump(kPressTimeout);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(_scaleOf(t, find.byKey(const Key('p'))), closeTo(AppMotion.pressScale, 0.001));
      expect(taps, 0);
      await g.up();
      await t.pump();
      expect(taps, 1);
      await t.pumpAndSettle();
      expect(_scaleOf(t, find.byKey(const Key('p'))), closeTo(1, 0.001));
    });

    testWidgets('a quick tap still shows the whole press, then rests', (t) async {
      await t.pumpWidget(
        _app(
          Pressable(
            key: const Key('p'),
            onTap: () {},
            child: const SizedBox(width: 80, height: 48),
          ),
        ),
      );
      await t.tap(find.byKey(const Key('p')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(_scaleOf(t, find.byKey(const Key('p'))), lessThan(1));
      await t.pumpAndSettle();
      expect(_scaleOf(t, find.byKey(const Key('p'))), closeTo(1, 0.001));
    });

    testWidgets('long press and keyboard activation work; null callbacks are inert', (t) async {
      var long = 0;
      var taps = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await t.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Pressable(
                key: const Key('a'),
                focusNode: focus,
                onTap: () => taps++,
                onLongPress: () => long++,
                child: const SizedBox(width: 80, height: 48),
              ),
              const Pressable(key: Key('b'), child: SizedBox(width: 80, height: 48)),
            ],
          ),
        ),
      );
      await t.longPress(find.byKey(const Key('a')));
      await t.pumpAndSettle();
      expect(long, 1);
      focus.requestFocus();
      await t.pump();
      Actions.invoke(focus.context!, const ActivateIntent());
      expect(taps, 1);
      await t.tap(find.byKey(const Key('b')), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(_scaleOf(t, find.byKey(const Key('b'))), closeTo(1, 0.001));
    });

    testWidgets('reduced motion: no scale animation runs', (t) async {
      await t.pumpWidget(
        _app(
          Pressable(
            key: const Key('p'),
            onTap: () {},
            child: const SizedBox(width: 80, height: 48),
          ),
          reduced: true,
        ),
      );
      await t.tap(find.byKey(const Key('p')));
      await t.pump();
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('AppIconButton presses in through its states', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _app(
          AppIconButton(
            key: const Key('i'),
            icon: const Icon(AppIcons.add),
            tooltip: 'Add',
            onPressed: () => taps++,
          ),
        ),
      );
      final g = await t.startGesture(t.getCenter(find.byKey(const Key('i'))));
      await t.pump(kPressTimeout);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(_scaleOf(t, find.byKey(const Key('i'))), closeTo(AppIconButton.pressedScale, 0.001));
      await g.up();
      await t.pumpAndSettle();
      expect(taps, 1);
      expect(_scaleOf(t, find.byKey(const Key('i'))), closeTo(1, 0.001));
    });

    testWidgets('PillButton presses in and still fires', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _app(PillButton(key: const Key('b'), label: 'Save', onPressed: () => taps++)),
      );
      final g = await t.startGesture(t.getCenter(find.byKey(const Key('b'))));
      await t.pump(kPressTimeout);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(_scaleOf(t, find.byKey(const Key('b'))), closeTo(AppMotion.pressScale, 0.001));
      await g.up();
      await t.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('AnimatedAmount', () {
    String fmt(int m) => 'Rs $m';

    Widget amount(int minor, {String currency = 'INR'}) =>
        AnimatedAmount(textKey: const Key('amt'), minor: minor, currency: currency, format: fmt);

    testWidgets('shows the first value as is, then counts in integers to a new one', (t) async {
      await t.pumpWidget(_app(amount(100)));
      expect(_text(t, const Key('amt')), 'Rs 100');
      await t.pumpWidget(_app(amount(1100)));
      await t.pump(const Duration(milliseconds: 100));
      final mid = int.parse(_text(t, const Key('amt')).substring(3));
      expect(mid, inExclusiveRange(100, 1100));
      await t.pump(const Duration(milliseconds: 400));
      expect(_text(t, const Key('amt')), 'Rs 1100');
      expect(find.bySemanticsLabel('Rs 1100'), findsOneWidget);
    });

    testWidgets('a currency change jumps; reduced motion jumps', (t) async {
      await t.pumpWidget(_app(amount(100)));
      await t.pumpWidget(_app(amount(900, currency: 'EUR')));
      expect(_text(t, const Key('amt')), 'Rs 900');
      await t.pumpWidget(_app(amount(100), reduced: true));
      await t.pumpWidget(_app(amount(500), reduced: true));
      await t.pump();
      expect(_text(t, const Key('amt')), 'Rs 500');
    });
  });

  group('Entrance', () {
    Finder inEntrance(String label, Type type) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Entrance)),
      matching: find.byType(type),
    );

    Opacity opacityOf(WidgetTester t, String label) =>
        t.widget<Opacity>(inEntrance(label, Opacity).first);

    testWidgets('rows rise in on first show only, staggered, first 8 rows', (t) async {
      await t.pumpWidget(
        _app(
          EntranceScope(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (var i = 0; i < 10; i++) Entrance(index: i, child: Text('row $i'))],
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 60));
      expect(opacityOf(t, 'row 0').opacity, greaterThan(opacityOf(t, 'row 3').opacity));
      expect(inEntrance('row 9', Opacity), findsNothing);
      await t.pumpAndSettle();
      expect(opacityOf(t, 'row 3').opacity, 1);
    });

    testWidgets('without a scope (or reduced motion) rows just appear', (t) async {
      await t.pumpWidget(_app(const Entrance(index: 0, child: Text('solo'))));
      expect(inEntrance('solo', Opacity), findsNothing);
      await t.pumpWidget(
        _app(const EntranceScope(child: Entrance(index: 0, child: Text('calm'))), reduced: true),
      );
      expect(inEntrance('calm', Opacity), findsNothing);
    });

    testWidgets('FadeIn fades its child in once', (t) async {
      await t.pumpWidget(_app(const FadeIn(child: Text('tab'))));
      await t.pump(const Duration(milliseconds: 50));
      final fade = t.widget<FadeTransition>(
        find.ancestor(of: find.text('tab'), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await t.pumpAndSettle();
      expect(fade.opacity.value, 1);
    });
  });

  group('FadeThroughStack', () {
    testWidgets('fades to the new child, keeps every child\'s state', (t) async {
      Widget stack(int i) => _app(
        SizedBox(
          width: 300,
          height: 300,
          child: FadeThroughStack(index: i, children: const [_Counter('a'), _Counter('b')]),
        ),
      );
      await t.pumpWidget(stack(0));
      await t.tap(find.text('a 0'));
      await t.pump();
      expect(find.text('a 1'), findsOneWidget);
      await t.pumpWidget(stack(1));
      await t.pump(const Duration(milliseconds: 40));
      // Mid-way both are on stage; only the new one takes taps.
      expect(find.text('a 1'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('a 1'), findsNothing);
      expect(find.text('b 0'), findsOneWidget);
      await t.pumpWidget(stack(0));
      await t.pumpAndSettle();
      expect(find.text('a 1'), findsOneWidget);
    });
  });

  group('SharedAxisPageTransitionsBuilder', () {
    testWidgets('a push fades and slides the new page in, a pop takes it back out', (t) async {
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: AppTheme.light(),
          home: const Scaffold(body: Text('home')),
        ),
      );
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('next'))),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final opacity = t.widget<Opacity>(
        find.ancestor(of: find.text('next'), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, inExclusiveRange(0, 1));
      await t.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
      nav.currentState!.pop();
      await t.pumpAndSettle();
      expect(find.text('next'), findsNothing);
      expect(const SharedAxisPageTransitionsBuilder().transitionDuration.inMilliseconds, 280);
    });
  });

  group('Shimmer', () {
    testWidgets('sweeps a few times, then rests (tests settle); still when reduced', (t) async {
      await t.pumpWidget(_app(const Shimmer(child: SkeletonBox(width: 100, height: 20))));
      expect(find.byType(ShaderMask), findsOneWidget);
      await t.pumpAndSettle();
      await t.pumpWidget(_app(const Shimmer(child: SkeletonRow()), reduced: true));
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group('GlassCard', () {
    // Off for every other test (flutter_test_config.dart).
    setUp(() => GlassBackdropHost.snapshotsEnabled = true);

    Widget host({double width = 360, double height = 400, Widget? extra}) => _app(
      SizedBox(
        width: width,
        height: height,
        child: GlassBackdropHost(
          background: const ColoredBox(color: AppPalette.black),
          child: Center(
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [const Text('glass'), ?extra],
              ),
            ),
          ),
        ),
      ),
    );
    BackdropFilter filter(WidgetTester t) => t.widget<BackdropFilter>(find.byType(BackdropFilter));
    // The snapshot and the blur are two engine round trips (real time, not the test clock). [off]: the
    // snapshot is expected, so wait on the real clock until it lands (up to 10 s: under full-suite load the
    // round trips took longer than the 600 ms that is enough on a quiet PC, final QA S-408).
    Future<void> engine(WidgetTester t, {bool off = false}) async {
      final end = DateTime.now().add(
        off ? const Duration(seconds: 10) : const Duration(milliseconds: 600),
      );
      while (filter(t).enabled && DateTime.now().isBefore(end)) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await t.pump();
      }
    }

    testWidgets('blurs live when snapshots are off (goldens)', (t) async {
      GlassBackdropHost.snapshotsEnabled = false;
      await t.pumpWidget(host());
      await t.pump(GlassBackdropHost.settle * 2);
      await engine(t);
      expect(filter(t).enabled, isTrue);
    });

    testWidgets('in a hero it paints the pre-blurred snapshot instead of a live blur', (t) async {
      await t.pumpWidget(host());
      await t.pump();
      // Nothing is snapshotted on the first frames (S-279): it would be rasterised before them.
      await engine(t);
      expect(filter(t).enabled, isTrue);
      await t.pump(GlassBackdropHost.settle);
      await engine(t, off: true);
      expect(filter(t).enabled, isFalse);
      expect(find.text('glass'), findsOneWidget);
      // A new size retakes the snapshot once it settles.
      await t.pumpWidget(host(width: 300, height: 420));
      await t.pump();
      expect(filter(t).enabled, isTrue);
      for (var i = 0; i < GlassBackdropHost.maxWaits && filter(t).enabled; i++) {
        await t.pump(GlassBackdropHost.settle);
        await engine(t);
      }
      await engine(t, off: true);
      expect(filter(t).enabled, isFalse);
    });

    testWidgets('a pushed page snapshots its hero once the route and the flight have landed', (
      t,
    ) async {
      final nav = GlobalKey<NavigatorState>();
      const card = SizedBox.square(dimension: 80, child: ColoredBox(color: AppPalette.black));
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Hero(tag: 'cover', child: card),
          ),
        ),
      );
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: GlassBackdropHost(
                background: Hero(
                  tag: 'cover',
                  child: ColoredBox(color: AppPalette.black),
                ),
                child: Center(child: GlassCard(child: Text('glass'))),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      // Mid-flight the page's hero is a placeholder: nothing to snapshot yet.
      await engine(t);
      expect(filter(t).enabled, isTrue);
      await t.pumpAndSettle();
      for (var i = 0; i < GlassBackdropHost.maxWaits && filter(t).enabled; i++) {
        await t.pump(GlassBackdropHost.settle);
        await engine(t);
      }
      await engine(t, off: true);
      expect(filter(t).enabled, isFalse);
    });

    testWidgets('waits while something animates, but not forever', (t) async {
      // An indeterminate spinner ticks every frame, like a looping loader.
      await t.pumpWidget(host(extra: const CircularProgressIndicator()));
      await t.pump(GlassBackdropHost.settle * 3);
      await engine(t);
      expect(filter(t).enabled, isTrue);
      await t.pump(GlassBackdropHost.settle * GlassBackdropHost.maxWaits);
      await engine(t, off: true);
      expect(filter(t).enabled, isFalse);
    });
  });
}
