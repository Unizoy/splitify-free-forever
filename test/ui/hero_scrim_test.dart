// D-033: once a hero page scrolls, a status-bar-high band in the hero colour sits under the clock and
// icons (light icons in both themes), so text and buttons never run under them — on every hero screen,
// also when the rows are slivers after the hero and the hero itself has scrolled away.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/expenses/expense_fixtures.dart' show gid, sampleExpense, sampleView;
import '../support/group_fakes.dart';
import '../support/group_harness.dart';

const _bar = 24.0;

Widget _page(Widget body, {Brightness brightness = Brightness.light}) => MediaQuery(
  data: const MediaQueryData(
    size: Size(400, 800),
    padding: EdgeInsets.only(top: _bar),
  ),
  child: MaterialApp(
    theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
    home: Scaffold(body: body),
  ),
);

/// The status-bar style the system would read at the clock.
SystemUiOverlayStyle? _barStyle(WidgetTester tester) => tester.binding.renderViews.first.debugLayer!
    .find<SystemUiOverlayStyle>(const Offset(200, _bar / 2));

double _scrim(WidgetTester tester) =>
    tester.widget<Opacity>(find.byKey(const Key('hero-status-scrim'))).opacity;

Future<void> _scrollBy(WidgetTester tester, Finder scrollable, double dy) async {
  await tester.drag(scrollable, Offset(0, -dy), touchSlopY: 0);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Paints the hero-coloured status-bar band at [band] (the column's own coordinates).
PaintPattern _band(Color color, [Rect? band]) => paints
  ..something(
    (method, args) =>
        method == #drawRect &&
        (band == null || args[0] == band) &&
        (args[1] as Paint).color.toARGB32() == color.toARGB32(),
  );

Widget _hero() => OverlapColumn(
  top: const HeroHeader(title: 'split it.\nsettle it.'),
  bottom: const OverlapSheet(child: SizedBox(height: 1600)),
);

void main() {
  group('OverlapColumn (single scroll view pages)', () {
    for (final brightness in Brightness.values) {
      testWidgets('no band at the top; a hero-coloured band with light icons once scrolled '
          '(${brightness.name})', (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _page(SingleChildScrollView(child: _hero()), brightness: brightness),
        );
        final hero = (brightness == Brightness.light ? AppTheme.light() : AppTheme.dark())
            .extension<AppColors>()!
            .heroTop;
        final column = find.byType(OverlapColumn);
        expect(column, isNot(_band(hero, const Rect.fromLTWH(0, 0, 400, _bar))));
        expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);

        await _scrollBy(tester, find.byType(SingleChildScrollView), 300);
        expect(column, _band(hero, const Rect.fromLTWH(0, 300, 400, _bar)));
        expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);

        // Further down the sheet is under the clock: still the hero band, still light icons.
        await _scrollBy(tester, find.byType(SingleChildScrollView), 700);
        expect(column, _band(hero, const Rect.fromLTWH(0, 1000, 400, _bar)));
        expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);
      });
    }

    testWidgets('the band fades in over the first 8 px', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_page(SingleChildScrollView(child: _hero())));
      final hero = AppTheme.light().extension<AppColors>()!.heroTop;
      await _scrollBy(tester, find.byType(SingleChildScrollView), 4);
      expect(
        find.byType(OverlapColumn),
        _band(hero.withValues(alpha: hero.a * 0.5), const Rect.fromLTWH(0, 4, 400, _bar)),
      );
    });
  });

  group('HeroScrim (rows as slivers after the hero)', () {
    testWidgets('stays under the clock after the hero scrolled away; gone back at the top', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _page(
          HeroScrim(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _hero()),
                SliverList.builder(
                  itemCount: 200,
                  itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
                ),
              ],
            ),
          ),
        ),
      );
      // The hero column joins the page's scrim after its first frame.
      await tester.pump();
      expect(_scrim(tester), 0);
      expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);
      await _scrollBy(tester, find.byType(CustomScrollView), 4);
      expect(_scrim(tester), closeTo(0.5, 0.01));
      // The column inside leaves the band to the scrim.
      final hero = AppTheme.light().extension<AppColors>()!.heroTop;
      expect(find.byType(OverlapColumn), isNot(_band(hero)));
      await _scrollBy(tester, find.byType(CustomScrollView), 3000);
      expect(_scrim(tester), 1);
      expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 6000), 4000);
      await tester.pumpAndSettle();
      expect(_scrim(tester), 0);
    });
  });

  testWidgets('a page without a hero gets no band and keeps its own status-bar style', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(
        HeroScrim(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: ListView(children: [for (var i = 0; i < 80; i++) Text('row $i')]),
          ),
        ),
      ),
    );
    await tester.pump();
    await _scrollBy(tester, find.byType(ListView), 400);
    expect(find.byKey(const Key('hero-status-scrim')), findsNothing);
    expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.dark);
  });

  group('every hero screen', () {
    const top = EdgeInsets.only(top: _bar);

    testWidgets('Groups home (the page scrim; the column leaves the band to it)', (tester) async {
      await pumpGroups(
        tester,
        '/groups',
        padding: top,
        overrides: fixedGroupData(
          groups: [for (var i = 0; i < 8; i++) sampleGroup(id: 'g$i', name: 'Trip $i')],
        ),
      );
      final heroTop = AppTheme.light().extension<AppColors>()!.heroTop;
      expect(_scrim(tester), 0);
      await _scrollBy(tester, find.byType(SingleChildScrollView).first, 200);
      expect(_scrim(tester), 1);
      expect(find.byType(OverlapColumn), isNot(_band(heroTop)));
      expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('group page', (tester) async {
      await pumpGroups(
        tester,
        '/groups/$gid',
        padding: top,
        overrides: fixedGroupData(
          groups: [sampleGroup(id: gid, name: 'Goa trip')],
          expenses: {
            gid: [for (var i = 0; i < 30; i++) sampleView(sampleExpense(id: 'e$i'))],
          },
        ),
      );
      expect(_scrim(tester), 0);
      await _scrollBy(tester, find.byType(CustomScrollView), 60);
      expect(_scrim(tester), 1);
      await _scrollBy(tester, find.byType(CustomScrollView), 2000);
      expect(_scrim(tester), 1);
      expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('Activity', (tester) async {
      final items = [
        for (var i = 0; i < 40; i++)
          ActivityItem(
            id: 'a$i',
            type: 'expense_added',
            groupId: gid,
            groupName: 'Goa trip',
            at: DateTime(2026, 11, 22, 9).subtract(Duration(hours: i)),
            actor: (name: 'Asha', seed: 'm2', isMe: false),
            description: 'Dinner $i',
            amount: 120000,
            currency: 'INR',
          ),
      ];
      await pumpGroups(
        tester,
        '/activity',
        padding: top,
        overrides: fixedGroupData(
          groups: [sampleGroup(id: gid, name: 'Goa trip')],
          activity: items,
        ),
      );
      expect(_scrim(tester), 0);
      // The rows are pressable: move the list itself (what a drag does) and check the band.
      tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere((s) => s.position.axis == Axis.vertical)
          .position
          .jumpTo(1500);
      await tester.pump();
      expect(_scrim(tester), 1);
      expect(_barStyle(tester)?.statusBarIconBrightness, Brightness.light);
    });
  });
}
