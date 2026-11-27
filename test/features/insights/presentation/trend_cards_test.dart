// TC-D34D-03 (D-034 WP-D, P-6): the "Category over time" and "Who paid" cards on Insights: the picks,
// the shared month, Me mode without "Who paid", labels for screen readers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';
import 'package:splitify/ui/components/components.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../insights_fixtures.dart';

const _tall = Size(412, 3600);

/// Goa with three people who take turns paying.
GroupLedger _goa() {
  final members = [
    seedMember('m1', groupId: goaId, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('m2', groupId: goaId, name: 'Asha Rao', userId: 'u2', position: 1),
    seedMember('m3', groupId: goaId, name: 'Rahul', position: 2),
  ];
  final ids = ['m1', 'm2', 'm3'];
  return GroupLedger(
    group: seedGroup(id: goaId),
    members: members,
    expenses: [
      insightExpense(
        'e1',
        groupId: goaId,
        ids: ids,
        category: 'travel.hotel',
        date: '2026-10-03',
        total: 900000,
      ),
      insightExpense(
        'e2',
        groupId: goaId,
        ids: ['m2', 'm1', 'm3'],
        category: 'food.dining_out',
        date: '2026-11-18',
        total: 300000,
      ),
      insightExpense(
        'e3',
        groupId: goaId,
        ids: ['m3', 'm1'],
        category: 'food.snacks',
        date: '2026-10-21',
        total: 60000,
      ),
    ],
    payments: const [],
  );
}

Future<void> _pump(
  WidgetTester t, {
  InsightsMode mode = InsightsMode.group,
  double scale = 1,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = _tall;
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    expenseApp(
      InsightsScreen(mode: mode, groupId: goaId),
      overrides: insightsOverrides([_goa()]),
      size: _tall,
      scale: scale,
    ),
  );
  await settle(t);
}

String _text(WidgetTester t, String key) => t.widget<Text>(find.byKey(Key(key))).data!;

String _amount(WidgetTester t, String key) => t
    .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
    .last
    .data!;

(String, String) _who(WidgetTester t) =>
    (_amount(t, 'trend-who-paid'), _amount(t, 'trend-who-share'));

bool _selected(WidgetTester t, String key) => t.widget<IconChip>(find.byKey(Key(key))).selected;

void main() {
  // TC-D34D-03
  testWidgets('Category over time starts on the biggest category and follows a pick', (t) async {
    await _pump(t);
    expect(find.byKey(const Key('insights-category-trend')), findsOneWidget);
    expect(find.text('CATEGORY OVER TIME'), findsOneWidget);
    expect(_selected(t, 'trend-category-travel'), isTrue);
    expect(_text(t, 'trend-category-total'), '₹9,000 on Travel in the last 12 months');
    // This month: nothing on travel.
    expect(_text(t, 'trend-category-amount'), '₹0');

    await t.tap(find.byKey(const Key('trend-category-food')));
    await settle(t);
    expect(_selected(t, 'trend-category-food'), isTrue);
    expect(_text(t, 'trend-category-total'), '₹3,600 on Food in the last 12 months');
    expect(_text(t, 'trend-category-amount'), '₹3,000');

    // A bar picks the month for every card.
    await t.tap(find.byKey(const Key('trend-bar-2026-10')));
    await settle(t);
    expect(_text(t, 'trend-category-amount'), '₹600');
    expect(_text(t, 'insights-month-title'), 'October 2026');
    expect(find.text('₹9,600'), findsOneWidget, reason: 'the By month card shows October');
  });

  // TC-D34D-03
  testWidgets('a pick in the donut legend moves Category over time too', (t) async {
    await _pump(t);
    await t.tap(find.byKey(const Key('insights-chip-food')));
    await settle(t);
    expect(_selected(t, 'trend-category-food'), isTrue);
  });

  // TC-D34D-03
  testWidgets('Who paid starts on me and shows paid against share per month', (t) async {
    await _pump(t);
    expect(find.byKey(const Key('insights-who-paid')), findsOneWidget);
    expect(_selected(t, 'trend-person-m1'), isTrue);
    expect(
      find.descendant(of: find.byKey(const Key('trend-person-m1')), matching: find.text('You')),
      findsOneWidget,
    );
    // November: Asha paid the dinner; my share ₹1,000.
    expect(_who(t), ('₹0', '₹1,000'));
    expect(_text(t, 'trend-who-total'), 'Last 12 months: paid ₹9,000 · share ₹4,300');

    await t.tap(find.byKey(const Key('trend-person-m2')));
    await settle(t);
    expect(_who(t), ('₹3,000', '₹1,000'));
    await t.tap(find.byKey(const Key('trend-who-bar-2026-10')));
    await settle(t);
    expect(_who(t), ('₹0', '₹3,000'));
    expect(_text(t, 'insights-month-title'), 'October 2026');
    expect(_text(t, 'trend-who-total'), 'Last 12 months: paid ₹3,000 · share ₹4,000');
  });

  // TC-D34D-03
  testWidgets('Me mode: Category over time of my shares, no Who paid', (t) async {
    await _pump(t, mode: InsightsMode.me);
    expect(find.byKey(const Key('insights-category-trend')), findsOneWidget);
    expect(find.byKey(const Key('insights-who-paid')), findsNothing);
    expect(_text(t, 'trend-category-total'), '₹3,000 on Travel in the last 12 months');
  });

  // TC-D34D-03
  testWidgets('bars are read out with the month, paid and share', (t) async {
    final handle = t.ensureSemantics();
    await _pump(t);
    expect(find.bySemanticsLabel('November 2026: paid ₹0, share ₹1,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Category'), findsOneWidget);
    expect(find.bySemanticsLabel('Person'), findsOneWidget);
    handle.dispose();
  });

  // TC-D34D-03
  testWidgets('large text lays out without overflow', (t) async {
    await _pump(t, scale: 2);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.byKey(const Key('trend-person-m3')));
    await settle(t);
    await t.tap(find.byKey(const Key('trend-person-m3')));
    await settle(t);
    expect(t.takeException(), isNull);
  });
}
