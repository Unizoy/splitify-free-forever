// TC-21-02: the group's Totals tab (Month with prev / next, All time, spent card, each person; D-034 F13).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show BalancesSkeleton;
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/balances/presentation/totals_tab.dart';
import 'package:splitify/features/insights/application/totals_months.dart';
import 'package:splitify/ui/components/components.dart';

import '../../expenses/presentation/presentation_harness.dart';
import '../balance_fixtures.dart';

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: TotalsTab(groupId: gid),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester t, AsyncValue<GroupTotalsView?> v, {TotalsMonths? months}) async {
  usePhone(t);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    expenseApp(
      const _Host(),
      overrides: [
        groupTotalsProvider(gid).overrideWithValue(v),
        totalsMonthsProvider(gid).overrideWithValue(AsyncData(months)),
      ],
    ),
  );
  await settle(t);
}

Finder _in(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

AmountRow _row(WidgetTester t, String member, [String currency = 'INR']) =>
    t.widget<AmountRow>(find.byKey(Key('totals-$currency-$member')));

void main() {
  group('TotalsTab', () {
    // TC-21-02
    testWidgets('loading, error and not-found states', (t) async {
      await _pump(t, const AsyncLoading());
      expect(find.byType(BalancesSkeleton), findsOneWidget);
      await _pump(t, AsyncError(Exception('db'), StackTrace.empty));
      expect(find.text('Balances could not be loaded'), findsOneWidget);
      await _pump(t, const AsyncData(null));
      expect(find.text('This group is not on this phone.'), findsOneWidget);
    });

    // TC-21-02
    testWidgets('opens on All time with the spent card and my share and what I paid', (t) async {
      await _pump(t, AsyncData(sampleTotals()));
      final pill = t.widget<SegmentedPill<bool>>(find.byKey(const Key('totals-period')));
      expect(pill.value, isFalse);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);
      expect(find.byKey(const Key('totals-month')), findsNothing);

      expect(_in('totals-card-INR', 'TOTAL SPENT'), findsOneWidget);
      expect(_in('totals-card-INR', '₹4,825'), findsOneWidget);
      expect(_in('totals-card-INR', '7 expenses'), findsOneWidget);
      expect(_in('totals-my-share', '₹1,206.25'), findsOneWidget);
      expect(_in('totals-my-paid', '₹3,000'), findsOneWidget);
      expect(find.text('Your share'), findsOneWidget);
      expect(find.text('You paid'), findsOneWidget);
      expect(find.text('Payments and loans are not counted as spending.'), findsOneWidget);
    });

    // TC-21-02
    testWidgets('each person shows what they paid and their share, me as "You"', (t) async {
      await _pump(t, AsyncData(sampleTotals()));
      expect(find.text('EACH PERSON'), findsOneWidget);
      expect(_row(t, 'm1').title, 'You');
      expect(_row(t, 'm1').caption, 'paid ₹3,000\u00A0· share ₹1,206.25');
      expect(_row(t, 'm2').title, 'Asha Rao');
      expect(_row(t, 'm2').caption, 'paid ₹1,500\u00A0· share ₹1,206.25');
      expect(_row(t, 'm3').caption, 'paid ₹325\u00A0· share ₹1,206.25');
      // Priya paid nothing but has a share.
      expect(_row(t, 'm4').caption, 'paid ₹0\u00A0· share ₹1,206.25');
    });

    // TC-21-02
    testWidgets('Month opens on this month and shows only its spending', (t) async {
      await _pump(t, AsyncData(sampleTotals()));
      await t.tap(find.text('Month'));
      await settle(t);
      final pill = t.widget<SegmentedPill<bool>>(find.byKey(const Key('totals-period')));
      expect(pill.value, isTrue);
      expect(_in('totals-card-INR', '₹900'), findsOneWidget);
      expect(_in('totals-card-INR', '2 expenses'), findsOneWidget);
      expect(_in('totals-my-share', '₹225'), findsOneWidget);
      expect(_in('totals-my-paid', '₹600'), findsOneWidget);
      expect(_row(t, 'm3').caption, 'paid ₹0\u00A0· share ₹225');
      expect(find.text('November 2026'), findsOneWidget);

      await t.tap(find.text('All time'));
      await settle(t);
      expect(_in('totals-card-INR', '₹4,825'), findsOneWidget);
    });

    // TC-21-02
    testWidgets('two currencies: a card each with its code, never added together', (t) async {
      await _pump(t, AsyncData(sampleTotals(withUsd: true)));
      expect(_in('totals-card-INR', 'TOTAL SPENT\u00A0· INR'), findsOneWidget);
      expect(_in('totals-card-USD', 'TOTAL SPENT\u00A0· USD'), findsOneWidget);
      expect(_in('totals-card-USD', '\$120'), findsOneWidget);
      expect(_in('totals-card-USD', '1 expense'), findsOneWidget);
      expect(_row(t, 'm2', 'USD').caption, 'paid \$120\u00A0· share \$60');
      // Main currency first.
      expect(
        t.getTopLeft(find.byKey(const Key('totals-card-INR'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('totals-card-USD'))).dy),
      );
    });

    // TC-21-02
    testWidgets('empty all time and empty month have their own wording', (t) async {
      await _pump(t, AsyncData(emptyTotals()));
      expect(find.text('No spending yet'), findsOneWidget);
      expect(find.text('Add an expense and the totals show up here.'), findsOneWidget);
      expect(find.byKey(const Key('totals-card-INR')), findsNothing);

      final onlyOld = sampleTotals();
      await _pump(
        t,
        AsyncData(
          GroupTotalsView(
            mainCurrency: 'INR',
            members: onlyOld.members,
            meId: 'm1',
            month: const {},
            allTime: onlyOld.allTime,
          ),
        ),
      );
      await t.tap(find.text('Month'));
      await settle(t);
      expect(find.text('Nothing spent this month'), findsOneWidget);
      expect(find.byKey(const Key('totals-card-INR')), findsNothing);
    });

    // TC-21-02
    testWidgets('a viewer who is not a member sees no personal share', (t) async {
      await _pump(t, AsyncData(sampleTotals(meMissing: true)));
      expect(find.byKey(const Key('totals-my-share')), findsNothing);
      expect(_in('totals-card-INR', '₹4,825'), findsOneWidget);
      expect(_row(t, 'm1').title, 'Mohit Bindal');
    });

    // TC-21-02, TC-33-02
    testWidgets('See charts opens Insights on this group', (t) async {
      usePhone(t);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const _Host()),
          stubRoute('/insights'),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        routerApp(
          router,
          overrides: [groupTotalsProvider(gid).overrideWithValue(AsyncData(sampleTotals()))],
        ),
      );
      await settle(t);
      expect(find.text('See charts'), findsOneWidget);
      expect(find.text('Export CSV'), findsOneWidget);
      await tapKey(t, 'totals-charts');
      expect(find.text('Coming soon'), findsNothing);
      expect(
        (find.byKey(const Key('stub')).evaluate().single.widget as Text).data,
        'at /insights?mode=group&group=$gid',
      );
    });

    // TC-D34D-04
    testWidgets('prev / next walk the months with spending; each month has its own numbers', (
      t,
    ) async {
      TotalsExpense e(String date, int total, String payer) => TotalsExpense(
        currency: 'INR',
        total: total,
        date: date,
        paid: {payer: total},
        shares: {'m1': total ~/ 2, 'm2': total - total ~/ 2},
      );
      final months = TotalsMonths([
        e('2026-11-20', 90000, 'm1'),
        e('2026-10-02', 40000, 'm2'),
        e('2026-10-28', 10000, 'm1'),
        e('2026-08-15', 30000, 'm2'),
        const TotalsExpense(currency: 'INR', total: 5000, date: '2026-07-01', kind: 'iou'),
      ]);
      await _pump(t, AsyncData(sampleTotals()), months: months);
      await t.tap(find.text('Month'));
      await settle(t);
      bool enabled(String key) => t.widget<AppIconButton>(find.byKey(Key(key))).onPressed != null;
      expect(find.text('November 2026'), findsOneWidget);
      expect(enabled('totals-next'), isFalse);
      expect(enabled('totals-prev'), isTrue);

      await tapKey(t, 'totals-prev');
      expect(find.text('October 2026'), findsOneWidget);
      expect(_in('totals-card-INR', '₹500'), findsOneWidget);
      expect(_in('totals-card-INR', '2 expenses'), findsOneWidget);
      expect(_in('totals-my-paid', '₹100'), findsOneWidget);
      expect(_in('totals-my-share', '₹250'), findsOneWidget);
      expect(_row(t, 'm2').caption, 'paid ₹400\u00A0· share ₹250');
      expect(enabled('totals-next'), isTrue);

      await tapKey(t, 'totals-prev');
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Nothing spent in September 2026'), findsOneWidget);
      expect(find.byKey(const Key('totals-card-INR')), findsNothing);

      await tapKey(t, 'totals-prev');
      expect(find.text('August 2026'), findsOneWidget);
      expect(_in('totals-card-INR', '₹300'), findsOneWidget);
      // The July loan is not spending, so August is the oldest month.
      expect(enabled('totals-prev'), isFalse);

      // All time and back keeps the month.
      await t.tap(find.text('All time'));
      await settle(t);
      expect(find.byKey(const Key('totals-month')), findsNothing);
      await t.tap(find.text('Month'));
      await settle(t);
      expect(find.text('August 2026'), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tapKey(t, 'totals-next');
      }
      expect(find.text('November 2026'), findsOneWidget);
      expect(_in('totals-card-INR', '₹900'), findsOneWidget);
      expect(enabled('totals-next'), isFalse);
    });

    // TC-D34D-04
    testWidgets('the month arrows have names for TalkBack', (t) async {
      await _pump(t, AsyncData(sampleTotals()));
      await t.tap(find.text('Month'));
      await settle(t);
      expect(find.byTooltip('Previous month'), findsOneWidget);
      expect(find.byTooltip('Next month'), findsOneWidget);
    });
  });
}
