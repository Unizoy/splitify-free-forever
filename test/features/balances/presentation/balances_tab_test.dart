// TC-15-03 (balances tab states), TC-14-02 (multi-currency balance sections): the group's
// Balances tab, driven by fixed GroupBalances.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
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
        child: BalancesTab(groupId: gid),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester t, AsyncValue<GroupBalances?> v, {double scale = 1}) async {
  usePhone(t);
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(const SizedBox());
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Host()),
      stubRoute('/settle'),
    ],
  );
  await t.pumpWidget(
    routerApp(router, overrides: [groupBalancesProvider(gid).overrideWithValue(v)]),
  );
  await settle(t);
}

AmountRow _net(WidgetTester t, String currency, String member) =>
    t.widget<AmountRow>(find.byKey(Key('net-$currency-$member')));

Finder _inRow(String key, Finder what) => find.descendant(of: find.byKey(Key(key)), matching: what);

String _bannerText(WidgetTester t) {
  final b = t.widget<OverlapBanner>(find.byKey(const Key('balances-banner')));
  return '${b.line1}|${b.line2}';
}

void main() {
  group('BalancesTab states', () {
    // TC-15-03
    testWidgets('loading shows the skeleton', (t) async {
      await _pump(t, const AsyncLoading());
      expect(find.byType(BalancesSkeleton), findsOneWidget);
      expect(find.byKey(const Key('balances-tab')), findsNothing);
    });

    // TC-15-03
    testWidgets('a failed load says so', (t) async {
      await _pump(t, AsyncError(Exception('db'), StackTrace.empty));
      expect(find.text('Balances could not be loaded'), findsOneWidget);
    });

    // TC-15-03
    testWidgets('a group that is not on this phone says so', (t) async {
      await _pump(t, const AsyncData(null));
      expect(find.text('This group is not on this phone.'), findsOneWidget);
    });

    // TC-15-03
    testWidgets('no expenses or payments yet shows the empty state', (t) async {
      await _pump(t, AsyncData(goaEmpty()));
      expect(find.text('Balances show up here'), findsOneWidget);
      expect(find.text("Once the group has expenses, you'll see who owes whom."), findsOneWidget);
      expect(find.byKey(const Key('balances-banner')), findsNothing);
    });

    // TC-15-03
    testWidgets('everyone paid back: settled banner, a note, and settled rows', (t) async {
      await _pump(t, AsyncData(goaSettled()));
      expect(_bannerText(t), "In this group|You're all settled");
      expect(find.text('Everyone is settled up'), findsOneWidget);
      expect(find.byType(TransferRow), findsNothing);
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        final row = _net(t, 'INR', id);
        expect(row.amountText, '');
        expect(row.amountCaption, 'settled up');
      }
    });
  });

  group('BalancesTab content', () {
    // TC-15-03
    testWidgets('owed banner, who owes whom, and everyone\'s net', (t) async {
      await _pump(t, AsyncData(goaOwed()));
      expect(_bannerText(t), 'You are owed here|₹900');
      expect(find.text('WHO OWES WHOM'), findsOneWidget);
      expect(find.text('EVERYONE'), findsOneWidget);
      // No section header with a single currency.
      expect(find.text('INR balances'), findsNothing);

      expect(find.byType(TransferRow), findsNWidgets(2));
      expect(_inRow('transfer-INR-m2-m1', find.text('Asha Rao owes you')), findsOneWidget);
      expect(_inRow('transfer-INR-m2-m1', find.text('₹1,200')), findsOneWidget);
      // I owe Rahul (the wording of "You owe" is checked loosely: see the report).
      expect(
        _inRow('transfer-INR-m1-m3', find.textContaining(RegExp(r'^You owes? Rahul Mehta$'))),
        findsOneWidget,
      );
      expect(_inRow('transfer-INR-m1-m3', find.text('₹300')), findsOneWidget);
      expect(find.text('Settle'), findsNWidgets(2));

      final me = _net(t, 'INR', 'm1');
      expect((me.title, me.amountText, me.amountCaption), ('You', '₹900', 'get back'));
      final asha = _net(t, 'INR', 'm2');
      expect((asha.title, asha.amountText, asha.amountCaption), ('Asha Rao', '₹1,200', 'owes'));
      final rahul = _net(t, 'INR', 'm3');
      expect((rahul.amountText, rahul.amountCaption), ('₹300', 'gets back'));
      final priya = _net(t, 'INR', 'm4');
      expect(
        (priya.title, priya.amountText, priya.amountCaption),
        ('Priya Nair', '', 'settled up'),
      );
    });

    // TC-15-03
    testWidgets('owe banner when I only owe', (t) async {
      await _pump(t, AsyncData(goaOwe()));
      expect(_bannerText(t), 'You owe here|₹300');
      expect(find.byType(TransferRow), findsOneWidget);
      expect(_net(t, 'INR', 'm1').amountCaption, 'owe'); // "You … owe" (S-252)
      // Members with no net and still active stay listed as settled.
      expect(_net(t, 'INR', 'm4').amountCaption, 'settled up');
    });

    // TC-15-03, TC-14-02
    testWidgets('owed in one currency and owing in another gives a mixed banner', (t) async {
      await _pump(t, AsyncData(goaMixed()));
      final banner = _bannerText(t);
      expect(banner, startsWith('You are owed and you owe here|'));
      expect(banner, allOf(contains('₹900'), contains('\$20')));
    });

    // TC-15-03
    testWidgets('a viewer who is not a member sees the settled banner', (t) async {
      final b = GroupBalances(
        groupId: gid,
        groupName: 'Goa trip',
        mainCurrency: 'INR',
        members: goaMembers(),
        byCurrency: const {'INR': goaInr},
        hasRecords: true,
      );
      await _pump(t, AsyncData(b));
      expect(_bannerText(t), "In this group|You're all settled");
      expect(find.byType(TransferRow), findsNWidgets(2));
      // Names read in third person: nobody is "you".
      expect(find.text('Asha Rao owes Mohit Bindal'), findsOneWidget);
      expect(_net(t, 'INR', 'm1').title, 'Mohit Bindal');
    });

    // TC-15-03
    testWidgets('Settle opens Settle up prefilled with the pair', (t) async {
      await _pump(t, AsyncData(goaOwed()));
      await tapKey(t, 'settle-m2-m1');
      expect(find.text('at /settle?group=g-goa&from=m2&to=m1&currency=INR'), findsOneWidget);
    });

    // TC-15-03
    testWidgets('tapping the row itself also opens Settle up', (t) async {
      await _pump(t, AsyncData(goaOwed()));
      await t.tap(find.text('₹300'));
      await settle(t);
      expect(find.text('at /settle?group=g-goa&from=m1&to=m3&currency=INR'), findsOneWidget);
    });
  });

  group('BalancesTab simplify', () {
    // TC-15-03
    testWidgets('simplify off: original pairs and no toggle', (t) async {
      await _pump(t, AsyncData(goaOwed()));
      expect(find.byKey(const Key('balances-toggle-INR')), findsNothing);
      expect(find.text('SUGGESTED PAYMENTS'), findsNothing);
    });

    // TC-15-03
    testWidgets('simplify on: suggested payments, with a link to the original debts', (t) async {
      await _pump(t, AsyncData(goaOwed(simplify: true)));
      expect(find.text('SUGGESTED PAYMENTS'), findsOneWidget);
      expect(find.text('Show original debts'), findsOneWidget);
      expect(find.byType(TransferRow), findsNWidgets(2));
      // Asha pays me 900 and Rahul 300 instead of the original pairs.
      expect(_inRow('transfer-INR-m2-m1', find.text('₹900')), findsOneWidget);
      expect(find.byKey(const Key('transfer-INR-m2-m3')), findsOneWidget);
      expect(find.byKey(const Key('transfer-INR-m1-m3')), findsNothing);
    });

    // TC-15-03
    testWidgets('the link flips between suggested payments and original debts', (t) async {
      await _pump(t, AsyncData(goaOwed(simplify: true)));
      await tapKey(t, 'balances-toggle-INR');
      expect(find.text('WHO OWES WHOM'), findsOneWidget);
      expect(find.text('Show suggested payments'), findsOneWidget);
      expect(find.byKey(const Key('transfer-INR-m1-m3')), findsOneWidget);
      expect(_inRow('transfer-INR-m2-m1', find.text('₹1,200')), findsOneWidget);

      await tapKey(t, 'balances-toggle-INR');
      expect(find.text('SUGGESTED PAYMENTS'), findsOneWidget);
      expect(find.byKey(const Key('transfer-INR-m2-m3')), findsOneWidget);
    });

    // TC-15-03
    testWidgets('the nets stay the same either way (simplify never changes who is owed)', (
      t,
    ) async {
      await _pump(t, AsyncData(goaOwed(simplify: true)));
      final before = [
        for (final m in ['m1', 'm2', 'm3']) _net(t, 'INR', m).amountText,
      ];
      await tapKey(t, 'balances-toggle-INR');
      final after = [
        for (final m in ['m1', 'm2', 'm3']) _net(t, 'INR', m).amountText,
      ];
      expect(after, before);
    });
  });

  group('BalancesTab currencies', () {
    // TC-14-02
    testWidgets('two currencies: a section each, main currency first, never added', (t) async {
      await _pump(t, AsyncData(goaMixed()));
      expect(find.text('INR balances'), findsOneWidget);
      expect(find.text('USD balances'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('INR balances')).dy,
        lessThan(t.getTopLeft(find.text('USD balances')).dy),
      );
      // Each section has its own pairs and nets.
      expect(find.byType(TransferRow), findsNWidgets(3));
      expect(_inRow('transfer-USD-m1-m3', find.text('\$20')), findsOneWidget);
      expect(_net(t, 'INR', 'm1').amountText, '₹900');
      expect(_net(t, 'USD', 'm1').amountText, '\$20');
      expect(_net(t, 'USD', 'm1').amountCaption, 'owe');
      expect(find.text('WHO OWES WHOM'), findsNWidgets(2));
    });

    // TC-14-02
    testWidgets('owing in both currencies lists both amounts in the banner', (t) async {
      await _pump(t, AsyncData(goaOweTwoCurrencies()));
      final banner = _bannerText(t);
      expect(banner, startsWith('You owe here|'));
      expect(banner, allOf(contains('₹300'), contains('\$20'), contains('\u00A0· ')));
    });

    // TC-14-02
    testWidgets('simplify toggle is per currency section but flips them together', (t) async {
      await _pump(t, AsyncData(goaMixed(simplify: true)));
      expect(find.byKey(const Key('balances-toggle-INR')), findsOneWidget);
      expect(find.byKey(const Key('balances-toggle-USD')), findsOneWidget);
      await tapKey(t, 'balances-toggle-USD');
      expect(find.text('Show suggested payments'), findsNWidgets(2));
    });
  });

  group('BalancesTab large text', () {
    // TC-15-03
    testWidgets('normal text: Settle sits beside the words', (t) async {
      await _pump(t, AsyncData(goaOwed()));
      final title = t.getTopLeft(find.text('Asha Rao owes you'));
      final settle = t.getTopLeft(find.byKey(const Key('settle-m2-m1')));
      expect(settle.dx, greaterThan(title.dx + 100));
    });

    // TC-15-03
    testWidgets('large text: Settle moves under the words and nothing overflows', (t) async {
      await _pump(t, AsyncData(goaMixed()), scale: 2);
      final amount = t.getBottomLeft(_inRow('transfer-INR-m2-m1', find.text('₹1,200')));
      final settle = t.getTopLeft(find.byKey(const Key('settle-m2-m1')));
      expect(settle.dy, greaterThanOrEqualTo(amount.dy));
      expect(t.takeException(), isNull);
    });
  });
}
