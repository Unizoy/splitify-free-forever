// R3-A responsive behaviour (S-444, S-446): content keeps phone proportions on tablets and open foldables
// (max content width, centred sheets, adaptive group grid), rows stack by width rather than text size alone,
// the pinned action bar stacks on narrow phones, and short phones drop the decorative hero tagline.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// [child] in a themed app on a [size] screen at text [scale].
Future<void> _pump(
  WidgetTester t,
  Widget child, {
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  );
  await t.pump();
}

const _probe = Key('probe');

void main() {
  group('ContentWidth', () {
    testWidgets('fills a phone', (t) async {
      await _pump(
        t,
        const Scaffold(
          body: ContentWidth(child: SizedBox(key: _probe, height: 10)),
        ),
      );
      expect(t.getSize(find.byKey(_probe)).width, 393);
    });

    testWidgets('keeps phone proportions on a tablet, centred', (t) async {
      await _pump(
        t,
        const Scaffold(
          body: ContentWidth(child: SizedBox(key: _probe, height: 10)),
        ),
        size: const Size(840, 1200),
      );
      final r = t.getRect(find.byKey(_probe));
      expect(r.width, AppSpacing.maxContent);
      expect(r.center.dx, closeTo(420, 0.5));
    });

    testWidgets('sliver version pads to the same width', (t) async {
      await _pump(
        t,
        const Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverContentWidth(
                sliver: SliverToBoxAdapter(child: SizedBox(key: _probe, height: 10)),
              ),
            ],
          ),
        ),
        size: const Size(840, 1200),
      );
      expect(t.getSize(find.byKey(_probe)).width, AppSpacing.maxContent);
    });

    testWidgets('page side padding: the margin on phones, centring on tablets', (t) async {
      late double phone;
      late double tablet;
      await _pump(
        t,
        Builder(
          builder: (c) {
            phone = pageSidePadding(c);
            return const SizedBox();
          },
        ),
      );
      await _pump(
        t,
        Builder(
          builder: (c) {
            tablet = pageSidePadding(c);
            return const SizedBox();
          },
        ),
        size: const Size(840, 1200),
      );
      expect(phone, AppSpacing.screen);
      expect(tablet, (840 - AppSpacing.maxContent) / 2);
    });
  });

  testWidgets('a bottom sheet is at most 640 dp wide and centred on a tablet', (t) async {
    await _pump(
      t,
      const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: AppSheet(
            title: 'Settle up',
            child: SizedBox(key: _probe, height: 40),
          ),
        ),
      ),
      size: const Size(840, 1200),
    );
    final sheet = t.getRect(
      find.descendant(of: find.byType(AppSheet), matching: find.byType(DecoratedBox)).first,
    );
    expect(sheet.width, AppSpacing.maxSheet);
    expect(sheet.center.dx, closeTo(420, 0.5));
  });

  group('group grid columns', () {
    Future<int> columns(WidgetTester t, double width, double scale) async {
      late int n;
      await _pump(
        t,
        Builder(
          builder: (c) {
            n = GroupCoverCard.columnsFor(c, width);
            return const SizedBox();
          },
        ),
        scale: scale,
      );
      return n;
    }

    testWidgets('two on phones, three on a tablet, two again at large text', (t) async {
      expect(await columns(t, 280, 1), 2);
      expect(await columns(t, 353, 1), 2);
      expect(await columns(t, 440, 1), 2);
      expect(await columns(t, AppSpacing.maxContent, 1), 3);
      expect(await columns(t, AppSpacing.maxContent, 1.3), 2);
    });
  });

  group('rows stack by width per text size', () {
    Future<bool> stacked(WidgetTester t, Size size, double scale) async {
      late bool s;
      await _pump(
        t,
        Builder(
          builder: (c) {
            s = c.stackRows;
            return const SizedBox();
          },
        ),
        size: size,
        scale: scale,
      );
      return s;
    }

    testWidgets('small phone at 1.3 stacks, big phone at 1.5 does not, tablets keep rows', (
      t,
    ) async {
      expect(await stacked(t, const Size(320, 568), 1), isFalse);
      expect(await stacked(t, const Size(320, 568), 1.3), isTrue);
      expect(await stacked(t, const Size(412, 915), 1.3), isFalse);
      expect(await stacked(t, const Size(412, 915), 1.5), isFalse);
      expect(await stacked(t, const Size(412, 915), 2), isTrue);
      expect(await stacked(t, const Size(840, 1200), 2), isFalse);
    });
  });

  group('pinned action bar', () {
    Widget bar() => Scaffold(
      bottomNavigationBar: StickyActionBar(
        secondary: PillButton(label: 'Settle up', onPressed: () {}),
        primary: PillButton(key: _probe, label: 'Add expense', onPressed: () {}),
      ),
    );

    testWidgets('side by side on a normal phone', (t) async {
      await _pump(t, bar());
      final settle = t.getRect(find.text('Settle up'));
      final add = t.getRect(find.byKey(_probe));
      expect(settle.center.dy, closeTo(add.center.dy, 1));
    });

    testWidgets('stacked on a 320 dp phone, so "Add expense" never breaks', (t) async {
      await _pump(t, bar(), size: const Size(320, 568));
      final settle = t.getRect(find.text('Settle up'));
      final add = t.getRect(find.byKey(_probe));
      expect(add.bottom, lessThanOrEqualTo(settle.top));
      expect(t.takeException(), isNull);
    });

    testWidgets('its buttons line up with the content on a tablet', (t) async {
      await _pump(t, bar(), size: const Size(840, 1200));
      final row = t.getRect(find.byKey(_probe));
      final settle = t.getRect(find.text('Settle up'));
      expect(row.right - settle.left, lessThanOrEqualTo(AppSpacing.maxContent));
    });
  });

  group('hero tagline', () {
    Widget hero() => const Scaffold(
      body: SingleChildScrollView(
        child: HeroHeader(title: 'split it.\nsettle it.', taglineTitle: true),
      ),
    );

    testWidgets('left out on a short phone, still a header for screen readers', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, hero(), size: const Size(360, 640));
      expect(find.text('split it.\nsettle it.'), findsNothing);
      expect(
        t.getSemantics(find.bySemanticsLabel('split it.\nsettle it.')),
        isSemantics(isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('shown on a tall phone', (t) async {
      await _pump(t, hero());
      expect(find.text('split it.\nsettle it.'), findsOneWidget);
    });
  });
}
