// TC-32-07 (show balances in the main currency, Convert all) and the widget side of TC-17-04
// (simplify on the converted nets): the Balances tab with a real in-memory database.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
import 'package:splitify/features/currency/presentation/converted_balances_view.dart';
import 'package:splitify/ui/components/components.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../currency_harness.dart';

const _gid = 'g1';

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BalancesTab(groupId: _gid),
      ),
    ),
  );
}

Future<AppDatabase> _pump(
  WidgetTester t, {
  List<LocalExpense> expenses = const [],
  List<LocalPayment> payments = const [],
  bool simplify = false,
  bool cache = true,
  double scale = 1,
}) async {
  final db = await seededDb();
  if (simplify) await db.seed(groups: [seedGroup(simplify: true)]);
  await db.seed(expenses: expenses, payments: payments);
  if (cache) await cacheRates(db);
  await pumpApp(
    t,
    db: db,
    overrides: dbOverrides(db, offlineRemote()),
    scale: scale,
    home: const _Host(),
  );
  await settle(t, 12);
  return db;
}

/// ₹300.00 paid by Mohit, split three ways: Asha and Ravi owe him ₹100.00 each.
LocalExpense _dinner() => seedExpense(
  'eINR',
  description: 'Dinner',
  total: 30000,
  payers: {'m1': 30000},
  shares: {'m1': 10000, 'm2': 10000, 'm3': 10000},
);

/// $100.00 paid by Asha on 20 Nov (USD to INR 75 that day), split Mohit / Asha; [converted] saves it.
LocalExpense _hotel({bool converted = false, String id = 'eUSD', String date = '2026-11-20'}) {
  final e = seedExpense(
    id,
    description: 'Hotel',
    currency: 'USD',
    date: date,
    total: 10000,
    payers: {'m2': 10000},
    shares: {'m1': 5000, 'm2': 5000},
  );
  if (!converted) return e;
  return e.copyWith(
    fxRate: const Value('75.0000000000'),
    fxRateDate: const Value('2026-11-20'),
    fxSource: const Value('frankfurter'),
    fxCurrency: const Value('INR'),
    fxTotal: const Value(750000),
    fxPayers: Value(jsonEncode({'m2': 750000})),
    fxShares: Value(jsonEncode({'m1': 375000, 'm2': 375000})),
  );
}

/// A 3-person cycle in INR after conversion: Asha owes Mohit ₹1,000.00, Ravi owes Asha ₹750.00
/// ($10.00 at 75), Mohit owes Ravi ₹750.00. Simplified: Asha pays Mohit ₹250.00.
List<LocalExpense> _cycle() => [
  seedExpense('cA', total: 100000, payers: {'m1': 100000}, shares: {'m2': 100000}),
  seedExpense(
    'cB',
    currency: 'USD',
    total: 1000,
    payers: {'m2': 1000},
    shares: {'m3': 1000},
  ).copyWith(
    fxRate: const Value('75'),
    fxRateDate: const Value('2026-11-20'),
    fxSource: const Value('manual'),
    fxCurrency: const Value('INR'),
    fxTotal: const Value(75000),
    fxPayers: Value(jsonEncode({'m2': 75000})),
    fxShares: Value(jsonEncode({'m3': 75000})),
  ),
  seedExpense('cC', total: 75000, payers: {'m3': 75000}, shares: {'m1': 75000}),
];

Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first);
  await settle(t);
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await settleReal(t);
}

AmountRow _net(WidgetTester t, String id) =>
    t.widget<AmountRow>(find.byKey(Key('converted-net-$id')));

AmountRow _rowOf(WidgetTester t, String key) => t.widget<AmountRow>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(AmountRow)),
);

AmountRow _transfer(WidgetTester t, String from, String to) =>
    _rowOf(t, 'converted-transfer-$from-$to');

Finder _transfers() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('converted-transfer-'),
);

void main() {
  group('the toggle', () {
    // TC-32-07
    testWidgets('is hidden while every record is in the group currency', (t) async {
      await _pump(t, expenses: [_dinner()]);
      expect(find.byKey(const Key('balances-tab')), findsOneWidget);
      expect(find.byKey(const Key('balances-view-toggle')), findsNothing);
    });

    // TC-32-07
    testWidgets('shows with a record in another currency, by currency first', (t) async {
      await _pump(t, expenses: [_dinner(), _hotel()]);
      expect(find.byKey(const Key('balances-view-toggle')), findsOneWidget);
      expect(find.text('By currency'), findsOneWidget);
      expect(find.text('In INR'), findsOneWidget);
      expect(find.text('INR balances'), findsOneWidget);
      expect(find.text('USD balances'), findsOneWidget);
      expect(find.byKey(const Key('converted-balances')), findsNothing);
      expect(find.byKey(const Key('converted-missing')), findsNothing);
    });

    // TC-32-07
    testWidgets('switching back to By currency restores the sections', (t) async {
      await _pump(t, expenses: [_dinner(), _hotel(converted: true)]);
      await _tapText(t, 'In INR');
      expect(find.byKey(const Key('converted-balances')), findsOneWidget);
      expect(find.text('USD balances'), findsNothing);
      await _tapText(t, 'By currency');
      expect(find.byKey(const Key('converted-balances')), findsNothing);
      expect(find.text('USD balances'), findsOneWidget);
    });
  });

  group('Convert all', () {
    // TC-32-07
    testWidgets('an unconverted record shows the missing card and its row', (t) async {
      await _pump(t, expenses: [_dinner(), _hotel()]);
      await _tapText(t, 'In INR');
      expect(find.byKey(const Key('converted-missing')), findsOneWidget);
      expect(find.text('1 record needs a rate'), findsOneWidget);
      expect(
        find.text('Balances in INR use the rate saved with each record. Convert these first.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('convert-all')), findsOneWidget);
      expect(find.text('Convert all at their dates\' rates'), findsOneWidget);
      final row = _rowOf(t, 'missing-eUSD');
      expect(row.title, 'Hotel');
      expect(row.amountText, r'$100');
      expect(row.amountCaption, 'USD');
      expect(find.byKey(const Key('converted-balances')), findsNothing);
    });

    // TC-32-07
    testWidgets('a missing row opens the conversion sheet', (t) async {
      await _pump(t, expenses: [_dinner(), _hotel()]);
      await _tapText(t, 'In INR');
      await _tapKey(t, 'missing-eUSD');
      await settle(t);
      expect(find.text('Convert to INR'), findsWidgets);
    });

    // TC-32-07
    testWidgets('Convert all converts at the cached rate and shows the converted balances', (
      t,
    ) async {
      final db = await _pump(t, expenses: [_dinner(), _hotel()]);
      await _tapText(t, 'In INR');
      await _tapKey(t, 'convert-all');
      await settle(t);

      expect(find.text('1 converted'), findsOneWidget);
      final row = await (db.select(db.expenses)..where((e) => e.id.equals('eUSD'))).getSingle();
      expect(row.fxTotal, 750000); // $100.00 at 75
      expect(row.fxCurrency, 'INR');
      expect(row.fxSource, 'frankfurter');

      expect(find.byKey(const Key('converted-missing')), findsNothing);
      expect(find.byKey(const Key('converted-balances')), findsOneWidget);
      expect(find.text('Everything in INR'), findsOneWidget);
      expect(find.text('Every record counted at the rate saved with it.'), findsOneWidget);

      // Oracle (paise): dinner m2 -10000, m3 -10000, m1 +20000; hotel m1 -375000, m2 +375000.
      final me = _net(t, 'm1');
      expect((me.title, me.amountText, me.amountCaption), ('You', '₹3,550', 'owe'));
      final asha = _net(t, 'm2');
      expect((asha.title, asha.amountText, asha.amountCaption), ('Asha', '₹3,650', 'gets back'));
      final ravi = _net(t, 'm3');
      expect((ravi.amountText, ravi.amountCaption), ('₹100', 'owes'));

      // Original debts: I owe Asha 3,650 (375,000 - 10,000); Ravi owes me 100.
      expect(_transfers(), findsNWidgets(2));
      expect(_transfer(t, 'm1', 'm2').amountText, '₹3,650');
      expect(_transfer(t, 'm3', 'm1').amountText, '₹100');
    });

    // TC-32-07
    testWidgets('a record with no rate stays listed and is counted', (t) async {
      final db = await _pump(
        t,
        // 1 Nov is before every cached day
        expenses: [
          _dinner(),
          _hotel(),
          _hotel(id: 'eOld', date: '2026-11-01'),
        ],
      );
      await _tapText(t, 'In INR');
      expect(find.text('2 records need a rate'), findsOneWidget);
      await _tapKey(t, 'convert-all');
      await settle(t);

      expect(find.text('1 converted · 1 needs a rate you type'), findsOneWidget);
      expect(find.text('1 record needs a rate'), findsOneWidget);
      expect(find.byKey(const Key('missing-eOld')), findsOneWidget);
      expect(find.byKey(const Key('missing-eUSD')), findsNothing);
      expect(find.byKey(const Key('converted-balances')), findsNothing);
      final old = await (db.select(db.expenses)..where((e) => e.id.equals('eOld'))).getSingle();
      expect(old.fxTotal, isNull);
    });

    // TC-32-07
    testWidgets('a payment in another currency is listed with who paid whom', (t) async {
      await _pump(
        t,
        expenses: [_dinner()],
        payments: [
          seedPayment(
            'p1',
            from: 'm2',
            to: 'm1',
            amount: 1000,
            currency: 'USD',
            date: '2026-11-20',
          ),
        ],
      );
      await _tapText(t, 'In INR');
      final row = _rowOf(t, 'missing-p1');
      expect(row.title, contains('Asha'));
      expect(row.amountText, r'$10');
      await _tapKey(t, 'convert-all');
      await settle(t);
      expect(find.text('1 converted'), findsOneWidget);
      // Asha owed me 100 on the dinner and paid 750: she is owed 650; Mohit 200 - 750 = -550; Ravi -100.
      expect(_net(t, 'm2').amountText, '₹650');
      expect(_net(t, 'm2').amountCaption, 'gets back');
      expect(_net(t, 'm1').amountText, '₹550');
      expect(_net(t, 'm1').amountCaption, 'owe');
    });
  });

  group('simplify on the converted nets', () {
    // TC-17-04
    testWidgets('the link toggles between the original debts and the simplified transfers', (
      t,
    ) async {
      await _pump(t, expenses: _cycle());
      await _tapText(t, 'In INR');
      expect(find.text('WHO OWES WHOM'), findsOneWidget);
      expect(find.text('Simplify in INR'), findsOneWidget);
      // the cycle: three transfers
      expect(_transfers(), findsNWidgets(3));
      expect(_transfer(t, 'm2', 'm1').amountText, '₹1,000');
      expect(_transfer(t, 'm3', 'm2').amountText, '₹750');
      expect(_transfer(t, 'm1', 'm3').amountText, '₹750');

      await _tapKey(t, 'converted-simplify-toggle');
      expect(find.text('SUGGESTED PAYMENTS'), findsOneWidget);
      expect(find.text('Show original debts'), findsOneWidget);
      expect(_transfers(), findsOneWidget);
      expect(_transfer(t, 'm2', 'm1').amountText, '₹250');
      // nets do not change: Mohit +250, Asha -250, Ravi settled
      expect((_net(t, 'm1').amountText, _net(t, 'm1').amountCaption), ('₹250', 'get back'));
      expect((_net(t, 'm2').amountText, _net(t, 'm2').amountCaption), ('₹250', 'owes'));
      expect((_net(t, 'm3').amountText, _net(t, 'm3').amountCaption), ('', 'settled up'));

      await _tapKey(t, 'converted-simplify-toggle');
      expect(find.text('WHO OWES WHOM'), findsOneWidget);
      expect(_transfers(), findsNWidgets(3));
    });

    // TC-17-04
    testWidgets('a group with simplify on starts simplified', (t) async {
      await _pump(t, expenses: _cycle(), simplify: true);
      await _tapText(t, 'In INR');
      expect(find.text('SUGGESTED PAYMENTS'), findsOneWidget);
      expect(find.text('Show original debts'), findsOneWidget);
      expect(_transfers(), findsOneWidget);
      await _tapKey(t, 'converted-simplify-toggle');
      expect(_transfers(), findsNWidgets(3));
      expect(find.text('Simplify in INR'), findsOneWidget);
    });
  });

  group('settled', () {
    // TC-32-07
    testWidgets('everyone settled up in the main currency', (t) async {
      await _pump(
        t,
        expenses: [
          seedExpense(
            'eUSD',
            currency: 'USD',
            total: 1000,
            payers: {'m1': 1000},
            shares: {'m2': 1000},
          ).copyWith(
            fxRate: const Value('75'),
            fxRateDate: const Value('2026-11-20'),
            fxSource: const Value('manual'),
            fxCurrency: const Value('INR'),
            fxTotal: const Value(75000),
            fxPayers: Value(jsonEncode({'m1': 75000})),
            fxShares: Value(jsonEncode({'m2': 75000})),
          ),
        ],
        payments: [seedPayment('p1', from: 'm2', to: 'm1', amount: 75000)],
      );
      await _tapText(t, 'In INR');
      expect(find.byKey(const Key('converted-balances')), findsOneWidget);
      expect(find.text('Everyone is settled up'), findsOneWidget);
      expect(_transfers(), findsNothing);
      for (final id in ['m1', 'm2', 'm3']) {
        expect((_net(t, id).amountText, _net(t, id).amountCaption), ('', 'settled up'), reason: id);
      }
    });
  });

  group('layout', () {
    // TC-32-07
    testWidgets('the missing card and the converted view fit at text scale 2.0', (t) async {
      await _pump(t, expenses: [_dinner(), _hotel()], scale: 2);
      await _tapText(t, 'In INR');
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('converted-missing')), findsOneWidget);
      await _tapKey(t, 'convert-all');
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('converted-balances')), findsOneWidget);
    });
  });

  group('ConvertedBalancesView', () {
    // TC-32-07
    testWidgets('a group that is not on this phone renders nothing', (t) async {
      final db = await seededDb();
      await pumpApp(
        t,
        db: db,
        overrides: dbOverrides(db, offlineRemote()),
        home: const Scaffold(body: ConvertedBalancesView(groupId: 'nope')),
      );
      await settle(t, 6);
      expect(find.byKey(const Key('converted-balances')), findsNothing);
      expect(find.byKey(const Key('converted-missing')), findsNothing);
    });
  });
}
