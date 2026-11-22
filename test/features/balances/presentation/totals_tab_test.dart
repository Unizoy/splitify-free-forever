// TC-21-02: the group's Totals tab (This month / All time, spent card, each person).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show BalancesSkeleton;
import 'package:splitify/features/balances/presentation/totals_tab.dart';
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

Future<void> _pump(WidgetTester t, AsyncValue<GroupTotalsView?> v) async {
  usePhone(t);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    expenseApp(const _Host(), overrides: [groupTotalsProvider(gid).overrideWithValue(v)]),
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
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);

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
      expect(_row(t, 'm1').caption, 'paid ₹3,000 · share ₹1,206.25');
      expect(_row(t, 'm2').title, 'Asha Rao');
      expect(_row(t, 'm2').caption, 'paid ₹1,500 · share ₹1,206.25');
      expect(_row(t, 'm3').caption, 'paid ₹325 · share ₹1,206.25');
      // Priya paid nothing but has a share.
      expect(_row(t, 'm4').caption, 'paid ₹0 · share ₹1,206.25');
    });

    // TC-21-02
    testWidgets('This month shows only this month\'s spending', (t) async {
      await _pump(t, AsyncData(sampleTotals()));
      await t.tap(find.text('This month'));
      await settle(t);
      final pill = t.widget<SegmentedPill<bool>>(find.byKey(const Key('totals-period')));
      expect(pill.value, isTrue);
      expect(_in('totals-card-INR', '₹900'), findsOneWidget);
      expect(_in('totals-card-INR', '2 expenses'), findsOneWidget);
      expect(_in('totals-my-share', '₹225'), findsOneWidget);
      expect(_in('totals-my-paid', '₹600'), findsOneWidget);
      expect(_row(t, 'm3').caption, 'paid ₹0 · share ₹225');

      await t.tap(find.text('All time'));
      await settle(t);
      expect(_in('totals-card-INR', '₹4,825'), findsOneWidget);
    });

    // TC-21-02
    testWidgets('two currencies: a card each with its code, never added together', (t) async {
      await _pump(t, AsyncData(sampleTotals(withUsd: true)));
      expect(_in('totals-card-INR', 'TOTAL SPENT · INR'), findsOneWidget);
      expect(_in('totals-card-USD', 'TOTAL SPENT · USD'), findsOneWidget);
      expect(_in('totals-card-USD', '\$120'), findsOneWidget);
      expect(_in('totals-card-USD', '1 expense'), findsOneWidget);
      expect(_row(t, 'm2', 'USD').caption, 'paid \$120 · share \$60');
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
      await t.tap(find.text('This month'));
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
  });
}
