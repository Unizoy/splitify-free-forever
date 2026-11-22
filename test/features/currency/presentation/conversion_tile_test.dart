// TC-32-04: the detail-screen row that opens the conversion sheet ("Convert to INR" / "In INR").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/currency/application/conversion_controller.dart';
import 'package:splitify/features/currency/domain/conversion.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';
import 'package:splitify/features/currency/presentation/conversion_tile.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../currency_harness.dart';

SavedFx _saved({
  String currency = 'INR',
  FxSource source = FxSource.frankfurter,
  int total = 750075,
}) => SavedFx(
  rate: '75.0000000000',
  rateDate: DateTime.utc(2026, 11, 20),
  source: source,
  currency: currency,
  total: total,
);

Future<void> _pump(
  WidgetTester t, {
  String currency = 'USD',
  SavedFx? saved,
  String groupId = 'g1',
  bool payment = false,
  double scale = 1,
}) async {
  final db = await seededDb();
  await db.seed(
    expenses: [
      seedExpense(
        'e1',
        currency: 'USD',
        total: 10001,
        payers: {'m1': 10001},
        shares: {'m1': 5001, 'm2': 5000},
      ),
    ],
    payments: [
      seedPayment('p1', from: 'm2', to: 'm1', amount: 5000, currency: 'USD', date: '2026-11-20'),
    ],
  );
  await cacheRates(db);
  await pumpApp(
    t,
    db: db,
    overrides: dbOverrides(db, offlineRemote()),
    scale: scale,
    home: Scaffold(
      body: Center(
        child: ConversionTile(
          recordId: payment ? 'p1' : 'e1',
          groupId: groupId,
          currency: currency,
          saved: saved,
          payment: payment,
        ),
      ),
    ),
  );
  await settle(t, 8);
}

void main() {
  group('ConversionTile', () {
    // TC-32-04
    testWidgets('is hidden for a record in the group currency', (t) async {
      await _pump(t, currency: 'INR');
      expect(find.byKey(const Key('conversion-tile')), findsNothing);
      expect(find.text('Convert to INR'), findsNothing);
    });

    // TC-32-04
    testWidgets('is hidden while the group is not on this phone', (t) async {
      await _pump(t, groupId: 'nope');
      expect(find.byKey(const Key('conversion-tile')), findsNothing);
    });

    // TC-32-04
    testWidgets('without a conversion offers "Convert to INR" and opens the sheet', (t) async {
      await _pump(t);
      expect(find.byKey(const Key('conversion-tile')), findsOneWidget);
      expect(find.text('Convert to INR'), findsOneWidget);
      expect(find.byKey(const Key('conversion-tile-amount')), findsNothing);

      const args = (recordId: 'e1', payment: false);
      await warm(t, conversionProvider(args), (c) => c.read(conversionProvider(args).future));
      await t.tap(find.byKey(const Key('conversion-tile')));
      await settle(t, 12);
      expect(find.byKey(const Key('conversion-sheet')), findsOneWidget);
      expect(find.text('Save conversion'), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a payment tile opens the sheet for the payment', (t) async {
      await _pump(t, payment: true);
      const args = (recordId: 'p1', payment: true);
      await warm(t, conversionProvider(args), (c) => c.read(conversionProvider(args).future));
      await t.tap(find.byKey(const Key('conversion-tile')));
      await settle(t, 12);
      expect(find.byKey(const Key('conversion-sheet')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('conversion-original'))).data,
        MoneyFormatter.detail.format(5000, 'USD'),
      );
    });

    // TC-32-04
    testWidgets('a saved conversion shows "In INR", the amount and the rate with its source', (
      t,
    ) async {
      await _pump(t, saved: _saved());
      expect(find.text('Convert to INR'), findsNothing);
      expect(find.text('In INR'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('conversion-tile-amount'))).data, '₹7,500.75');
      expect(find.text('1 USD = 75 INR · Frankfurter · 20 Nov 2026'), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a typed rate says "Rate you typed"', (t) async {
      await _pump(t, saved: _saved(source: FxSource.manual));
      expect(find.text('1 USD = 75 INR · Rate you typed · 20 Nov 2026'), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a conversion to another currency does not count', (t) async {
      await _pump(t, saved: _saved(currency: 'EUR'));
      expect(find.text('Convert to INR'), findsOneWidget);
      expect(find.byKey(const Key('conversion-tile-amount')), findsNothing);
    });

    // TC-32-04
    testWidgets('lays out at text scale 2.0 with the amount under the caption', (t) async {
      await _pump(t, saved: _saved(), scale: 2);
      expect(t.takeException(), isNull);
      final amount = t.getTopLeft(find.byKey(const Key('conversion-tile-amount')));
      final caption = t.getTopLeft(find.textContaining('Frankfurter'));
      expect(amount.dy > caption.dy, isTrue);
    });

    // TC-32-04
    testWidgets('the saved tile says what it is to a screen reader', (t) async {
      final handle = t.ensureSemantics();
      await _pump(t, saved: _saved());
      expect(
        t.getSemantics(find.byKey(const Key('conversion-tile'))).label,
        'In INR, ₹7,500.75, 1 USD = 75 INR · Frankfurter · 20 Nov 2026',
      );
      handle.dispose();
    });
  });
}
