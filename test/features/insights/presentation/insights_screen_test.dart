// TC-33-02: the Insights screen (donut, legend chips, month bars, Group / Me, group picker, states).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show BalancesSkeleton;
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_charts.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';
import 'package:splitify/l10n/app_localizations_en.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../insights_fixtures.dart';

/// A tall phone so the whole (lazy) list is built and nothing needs scrolling.
const _tall = Size(412, 2600);

Future<void> _pump(
  WidgetTester t, {
  InsightsMode mode = InsightsMode.group,
  String? groupId = goaId,
  List<GroupLedger>? ledgers,
  List<Override>? overrides,
  double scale = 1,
  ThemeMode theme = ThemeMode.light,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = _tall;
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    expenseApp(
      InsightsScreen(mode: mode, groupId: groupId),
      overrides: overrides ?? insightsOverrides(ledgers ?? allInsightLedgers()),
      size: _tall,
      scale: scale,
      mode: theme,
    ),
  );
  await settle(t);
}

Finder _in(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

String _text(String key) => (find.byKey(Key(key)).evaluate().single.widget as Text).data!;

Future<void> _openPicker(WidgetTester t) async {
  await t.tap(find.byKey(const Key('insights-group-picker')));
  await settle(t, 16);
}

Future<void> _pick(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('insights-option-$id')));
  await settle(t, 16);
}

/// A group with one expense of [total] on [date] (INR, shared with a friend).
GroupLedger _single(String date, {int total = 80000}) => GroupLedger(
  group: seedGroup(id: 'g-one', name: 'Solo'),
  members: [
    seedMember('s1', groupId: 'g-one', name: 'Mohit Bindal', userId: 'u1'),
    seedMember('s2', groupId: 'g-one', name: 'Asha', position: 1),
  ],
  expenses: [
    insightExpense(
      's-e1',
      groupId: 'g-one',
      ids: ['s1', 's2'],
      category: 'food.snacks',
      date: date,
      total: total,
    ),
  ],
  payments: const [],
);

void main() {
  group('InsightsScreen', () {
    // TC-33-02
    testWidgets('Group mode on Goa: title, donut, a chip per category, twelve bars', (t) async {
      await _pump(t);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Spending in INR'), findsOneWidget);
      expect(find.byKey(const Key('insights-donut')), findsOneWidget);
      for (final k in ['travel', 'entertainment', 'food', 'shopping', 'groceries', 'other']) {
        expect(find.byKey(Key('insights-chip-$k')), findsOneWidget);
      }
      expect(find.byKey(const Key('insights-chip-rent')), findsNothing);
      expect(_in('insights-donut', 'Total spent'), findsOneWidget);
      expect(_in('insights-donut', '₹57,918'), findsOneWidget);
      expect(_in('insights-donut', '11 expenses'), findsOneWidget);
      expect(_in('insights-chip-travel', '₹31,850'), findsOneWidget);
      expect(_in('insights-chip-travel', '55%'), findsOneWidget);
      expect(find.byKey(const Key('insights-bar-2025-12')), findsOneWidget);
      expect(find.byKey(const Key('insights-bar-2026-11')), findsOneWidget);
      expect(_text('insights-month-title'), 'November 2026');
      expect(_text('insights-month-amount'), '₹5,500');
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Group'), findsWidgets);
      expect(_text('insights-month-hint'), 'Tap a bar to see that month.');
    });

    // TC-33-02
    testWidgets('the expense left out for want of a conversion has a note', (t) async {
      await _pump(t);
      expect(
        _in(
          'insights-unconverted',
          '1 expense in another currency is left out. Convert it to INR on its page to count it.',
        ),
        findsOneWidget,
      );
      // A group whose expenses all convert has no note.
      await _pump(t, groupId: flatId);
      expect(find.byKey(const Key('insights-unconverted')), findsNothing);
    });

    // TC-33-02
    testWidgets('tapping a chip selects it, tapping again clears it', (t) async {
      await _pump(t);
      await t.tap(find.byKey(const Key('insights-chip-travel')));
      await settle(t);
      expect(find.text('55% of the total'), findsOneWidget);
      expect(_in('insights-donut', '₹31,850'), findsOneWidget);
      expect(_in('insights-donut', 'Travel'), findsOneWidget);
      expect(_in('insights-donut', 'Total spent'), findsNothing);

      await t.tap(find.byKey(const Key('insights-chip-travel')));
      await settle(t);
      expect(find.text('55% of the total'), findsNothing);
      expect(_in('insights-donut', 'Total spent'), findsOneWidget);
    });

    // TC-33-02
    testWidgets('picking another chip moves the selection', (t) async {
      await _pump(t);
      await t.tap(find.byKey(const Key('insights-chip-travel')));
      await settle(t);
      await t.tap(find.byKey(const Key('insights-chip-food')));
      await settle(t);
      expect(_in('insights-donut', '₹7,450'), findsOneWidget);
      expect(find.text('13% of the total'), findsOneWidget);
    });

    // TC-33-02
    testWidgets('tapping a month bar changes the month title and amount', (t) async {
      await _pump(t);
      await t.tap(find.byKey(const Key('insights-bar-2026-10')));
      await settle(t);
      expect(_text('insights-month-title'), 'October 2026');
      // Hotel 12,400 + takeaway 2,450.
      expect(_text('insights-month-amount'), '₹14,850');
      await t.tap(find.byKey(const Key('insights-bar-2026-03')));
      await settle(t);
      expect(_text('insights-month-title'), 'March 2026');
      expect(_text('insights-month-amount'), '₹0');
    });

    // TC-33-02
    testWidgets('Group to Me: my share across everything, in INR', (t) async {
      await _pump(t);
      await t.tap(find.text('Me'));
      await settle(t);
      expect(find.text('Your share everywhere'), findsOneWidget);
      expect(find.text('All groups and friends'), findsOneWidget);
      expect(_in('insights-donut', 'Your share'), findsOneWidget);
      expect(_in('insights-donut', '₹57,756.03'), findsOneWidget);
      expect(_in('insights-donut', '17 expenses'), findsOneWidget);
      expect(find.byKey(const Key('insights-chip-rent')), findsOneWidget);
      expect(
        _in(
          'insights-unconverted',
          '3 expenses in other currencies are left out. '
              'Convert them to INR on their pages to count them.',
        ),
        findsOneWidget,
      );
      // And back.
      await t.tap(find.text('Group'));
      await settle(t);
      expect(_in('insights-donut', 'Total spent'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
    });

    // TC-33-02
    testWidgets('group picker: friend groups left out, open before archived, pick Flat 4B', (
      t,
    ) async {
      await _pump(t);
      await _openPicker(t);
      expect(find.text('Choose a group'), findsOneWidget);
      expect(find.byKey(const Key('insights-option-all')), findsNothing);
      expect(find.byKey(const Key('insights-option-$friendId')), findsNothing);
      final order = [flatId, goaId, emptyId, baliId];
      final tops = [
        for (final id in order) t.getTopLeft(find.byKey(Key('insights-option-$id'))).dy,
      ];
      expect(tops, [...tops]..sort());
      expect(find.text('Archived'), findsOneWidget);

      await _pick(t, flatId);
      expect(find.text('Choose a group'), findsNothing);
      expect(find.text('Flat 4B'), findsOneWidget);
      expect(_in('insights-donut', '₹76,000'), findsOneWidget);
      expect(_in('insights-donut', '5 expenses'), findsOneWidget);
      expect(find.byKey(const Key('insights-chip-rent')), findsOneWidget);
      expect(find.byKey(const Key('insights-chip-travel')), findsNothing);
    });

    // TC-33-02
    testWidgets('a picked month and category reset when the group changes', (t) async {
      await _pump(t);
      await t.tap(find.byKey(const Key('insights-bar-2026-10')));
      await t.tap(find.byKey(const Key('insights-chip-travel')));
      await settle(t);
      await _openPicker(t);
      await _pick(t, flatId);
      expect(_text('insights-month-title'), 'November 2026');
      expect(_in('insights-donut', 'Total spent'), findsOneWidget);
    });

    // TC-33-02
    testWidgets('Me picker offers "All groups and friends" first; picking a group narrows Me', (
      t,
    ) async {
      await _pump(t, mode: InsightsMode.me, groupId: null);
      await _openPicker(t);
      final all = find.byKey(const Key('insights-option-all'));
      expect(all, findsOneWidget);
      expect(
        t.getTopLeft(all).dy,
        lessThan(t.getTopLeft(find.byKey(Key('insights-option-$flatId'))).dy),
      );
      await _pick(t, flatId);
      expect(find.text('Your share in'), findsOneWidget);
      expect(find.text('Flat 4B'), findsOneWidget);
      expect(_in('insights-donut', '₹38,000'), findsOneWidget);

      await _openPicker(t);
      await _pick(t, 'all');
      expect(find.text('Your share everywhere'), findsOneWidget);
      expect(_in('insights-donut', '₹57,756.03'), findsOneWidget);
    });

    // TC-33-02
    testWidgets('opening with a group in Me mode narrows Me to it', (t) async {
      await _pump(t, mode: InsightsMode.me, groupId: flatId);
      expect(find.text('Flat 4B'), findsOneWidget);
      expect(_in('insights-donut', '₹38,000'), findsOneWidget);
    });

    // TC-33-02
    testWidgets('empty group, empty Me, only-unconverted and no-groups states', (t) async {
      await _pump(t, ledgers: [emptyLedger()], groupId: emptyId);
      expect(find.byKey(const Key('insights-empty')), findsOneWidget);
      expect(find.text('Nothing spent yet'), findsOneWidget);
      expect(find.text('Expenses in Weekend show up here by category and month.'), findsOneWidget);
      expect(find.byKey(const Key('insights-donut')), findsNothing);

      await _pump(t, ledgers: [emptyLedger()], mode: InsightsMode.me, groupId: null);
      expect(find.byKey(const Key('insights-empty')), findsOneWidget);
      expect(
        find.text('Your share of expenses shows up here by category and month.'),
        findsOneWidget,
      );

      await _pump(t, ledgers: [baliLedger()], groupId: baliId);
      expect(find.byKey(const Key('insights-convert')), findsOneWidget);
      expect(find.text('Convert to see charts'), findsOneWidget);
      expect(
        find.text(
          '2 expenses are in other currencies. Convert them to INR on their pages to see them here.',
        ),
        findsOneWidget,
      );

      await _pump(t, ledgers: [friendLedger()], groupId: null);
      expect(find.byKey(const Key('insights-no-groups')), findsOneWidget);
      expect(find.text('No groups yet'), findsOneWidget);
      expect(find.byKey(const Key('insights-group-picker')), findsNothing);
    });

    // TC-33-02
    testWidgets('loading shows the skeleton, an error says charts could not be loaded', (t) async {
      await _pump(t, overrides: [insightsProvider.overrideWith((ref, q) => const AsyncLoading())]);
      expect(find.byType(BalancesSkeleton), findsOneWidget);
      expect(find.byKey(const Key('insights-donut')), findsNothing);
      expect(find.byKey(const Key('insights-group-picker')), findsNothing);

      await _pump(
        t,
        overrides: [
          insightsProvider.overrideWith((ref, q) => AsyncError(Exception('db'), StackTrace.empty)),
        ],
      );
      expect(find.text('Charts could not be loaded'), findsOneWidget);
      expect(find.byType(BalancesSkeleton), findsNothing);
    });

    // TC-33-02
    testWidgets('a single month and an old-only group have their own hints', (t) async {
      await _pump(t, ledgers: [_single('2026-11-10')], groupId: 'g-one');
      expect(_text('insights-month-hint'), startsWith('Only one month so far.'));
      expect(find.text('12-month total ₹800'), findsOneWidget);

      await _pump(t, ledgers: [_single('2024-02-10')], groupId: 'g-one');
      expect(_text('insights-month-hint'), 'Nothing spent in the last 12 months.');
      expect(_text('insights-month-amount'), '₹0');
      expect(find.byKey(const Key('insights-donut')), findsOneWidget);
    });

    // TC-33-02
    testWidgets('every bar and the donut are labelled for screen readers', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t);
      Finder inMonths(String label) => find.descendant(
        of: find.byKey(const Key('insights-months')),
        matching: find.bySemanticsLabel(label),
      );
      expect(inMonths('November 2026: ₹5,500'), findsOneWidget);
      expect(inMonths('March 2026: ₹0'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Spending by category: Travel ₹31,850, 55%')),
        findsOneWidget,
      );
      handle.dispose();
    });

    // TC-33-02
    testWidgets('large text and dark mode lay out without overflow', (t) async {
      await _pump(t, scale: 2, theme: ThemeMode.dark);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('insights-chip-travel')));
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.text('55% of the total'), findsOneWidget);
    });

    // TC-33-02
    testWidgets('the back arrow is there', (t) async {
      await _pump(t);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(InsightsScreen), findsOneWidget);
    });
  });

  group('InsightsGroupOptions', () {
    // TC-33-02
    testWidgets('marks the current group as selected', (t) async {
      await _pump(t);
      await _openPicker(t);
      final sel = find.descendant(
        of: find.byKey(const Key('insights-option-$goaId')),
        matching: find.byIcon(AppIcons.checkCircle),
      );
      expect(sel, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('insights-option-$flatId')),
          matching: find.byIcon(AppIcons.checkCircle),
        ),
        findsNothing,
      );
    });
  });

  group('helpers', () {
    final l = AppLocalizationsEn();

    // TC-33-02
    test('percentText rounds half up, shows <1% for a sliver and 0% for no total', () {
      expect(percentText(l, 45, 100), '45%');
      expect(percentText(l, 1, 3), '33%');
      expect(percentText(l, 2, 3), '67%');
      expect(percentText(l, 1, 8), '13%');
      expect(percentText(l, 1, 1000), '<1%');
      expect(percentText(l, 1, 300), '<1%');
      expect(percentText(l, 1, 200), '1%');
      expect(percentText(l, 100, 100), '100%');
      expect(percentText(l, 0, 100), '0%');
      expect(percentText(l, 5, 0), '0%');
    });

    // TC-33-02
    test('categoryOfKey finds the top-level category; unknown keys are "other"', () {
      expect(categoryOfKey('travel'), Category.travel);
      expect(categoryOfKey('rent'), Category.rent);
      expect(categoryOfKey('bogus'), Category.other);
      expect(categoryOfKey(''), Category.other);
    });
  });
}
