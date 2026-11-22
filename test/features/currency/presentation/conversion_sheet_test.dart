// TC-32-04: the conversion sheet (automatic Frankfurter rate or a typed one, save, remove) for
// expenses and payments, with a real in-memory database and a fake rate server.
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/currency/application/conversion_controller.dart';
import 'package:splitify/features/currency/presentation/conversion_sheet.dart';

import 'package:splitify/ui/components/components.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../currency_harness.dart';

const _auto = '75.0000000000'; // 20 Nov: 90 / 1.2
const _earlier = '72.0000000000'; // 17 Nov: 90 / 1.25
const _members = ['m1', 'm2', 'm3'];

LocalExpense _expense({
  String id = 'e1',
  String currency = 'USD',
  String date = '2026-11-20',
  int total = 10001,
}) => seedExpense(
  id,
  currency: currency,
  date: date,
  total: total,
  payers: {'m1': total},
  shares: {'m1': total - total ~/ 2, 'm2': total ~/ 2},
);

Map<String, int> _ints(String? json) => {
  for (final e in (jsonDecode(json!) as Map<String, Object?>).entries) e.key: e.value! as int,
};

String _money(int minor, String code) => MoneyFormatter.detail.format(minor, code);

String _text(WidgetTester t, String key) => t.widget<Text>(find.byKey(Key(key))).data!;

String _field(WidgetTester t) => t.widget<TextField>(fieldIn('conversion-rate')).controller!.text;

bool _canSave(WidgetTester t) => buttonEnabled(t, 'conversion-save');

class _Env {
  _Env(this.db, this.remote);

  final AppDatabase db;
  final FakeFxRemote remote;

  Future<LocalExpense> expense([String id = 'e1']) =>
      (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingle();

  Future<LocalPayment> payment([String id = 'p1']) =>
      (db.select(db.payments)..where((p) => p.id.equals(id))).getSingle();

  Future<List<Map<String, Object?>>> outbox(String entity, String id) async => [
    for (final o in await db.select(db.outbox).get())
      if (o.entity == entity && o.recordId == id) jsonDecode(o.payload) as Map<String, Object?>,
  ];
}

/// Opens the sheet on [recordId] of a group with the given rows.
Future<_Env> _open(
  WidgetTester t, {
  List<LocalExpense>? expenses,
  List<LocalPayment> payments = const [],
  bool cache = true,
  bool only20 = false,
  bool only17 = false,
  FakeFxRemote? remote,
  String recordId = 'e1',
  bool payment = false,
  double scale = 1,
}) async {
  final db = await seededDb();
  await db.seed(expenses: expenses ?? [_expense()], payments: payments);
  if (cache) await cacheRates(db, only20: only20, only17: only17);
  final server = remote ?? offlineRemote();
  await pumpOpener(
    t,
    db: db,
    overrides: dbOverrides(db, server),
    scale: scale,
    onOpen: (context, ref) =>
        showConversionSheet(context, recordId: recordId, payment: payment, to: 'INR'),
  );
  final args = (recordId: recordId, payment: payment);
  await warm(t, conversionProvider(args), (c) => c.read(conversionProvider(args).future));
  await openSheet(t);
  return _Env(db, server);
}

void main() {
  group('rate from the cache', () {
    // TC-32-04
    testWidgets('the cached rate of the record date fills the field with its source', (t) async {
      await _open(t);
      expect(find.byKey(const Key('conversion-sheet')), findsOneWidget);
      expect(find.text('Convert to INR'), findsOneWidget);
      expect(_field(t), '75');
      expect(_text(t, 'conversion-source'), 'Frankfurter\u00A0· 20\u00A0Nov\u00A02026');
      final converted = convert(10001, 'USD', 'INR', _auto);
      expect(converted, 750075);
      expect(_text(t, 'conversion-original'), _money(10001, 'USD'));
      expect(_text(t, 'conversion-result'), '≈ ${_money(converted, 'INR')}');
      expect(_text(t, 'conversion-result'), '≈ ₹7,500.75');
      expect(find.byKey(const Key('conversion-use-auto')), findsNothing);
      expect(find.byKey(const Key('conversion-remove')), findsNothing);
      expect(find.text('Save conversion'), findsOneWidget);
      expect(
        find.text('Reference rates from central banks, not your bank\'s rate.'),
        findsOneWidget,
      );
      expect(_canSave(t), isTrue);
    });

    // TC-32-04
    testWidgets('only an earlier day cached: the latest rate before is used and said so', (
      t,
    ) async {
      await _open(t, only17: true);
      expect(_field(t), '72');
      expect(
        _text(t, 'conversion-source'),
        'Frankfurter\u00A0· 17\u00A0Nov\u00A02026 (latest before 20\u00A0Nov\u00A02026)',
      );
      expect(
        _text(t, 'conversion-result'),
        '≈ ${_money(convert(10001, 'USD', 'INR', _earlier), 'INR')}',
      );
      expect(_canSave(t), isTrue);
    });

    // TC-32-04
    testWidgets('a later cached day is not used for an earlier record', (t) async {
      await _open(
        t,
        expenses: [_expense(date: '2026-11-18')],
        only20: true,
        remote: offlineRemote(),
      );
      // nothing on or before 18 Nov: ask for a typed rate
      expect(_field(t), '');
      expect(find.textContaining('No saved rate for 18\u00A0Nov\u00A02026'), findsOneWidget);
    });
  });

  group('typing a rate', () {
    // TC-32-04
    testWidgets('a different rate becomes "Rate you typed"; "Use Frankfurter rate" restores', (
      t,
    ) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('conversion-rate')), '80');
      await settle(t, 2);
      expect(_text(t, 'conversion-source'), 'Rate you typed\u00A0· 20\u00A0Nov\u00A02026');
      expect(
        _text(t, 'conversion-result'),
        '≈ ${_money(convert(10001, 'USD', 'INR', '80'), 'INR')}',
      );
      expect(find.byKey(const Key('conversion-use-auto')), findsOneWidget);
      expect(find.text('Use Frankfurter rate'), findsOneWidget);

      await t.tap(find.byKey(const Key('conversion-use-auto')));
      await settle(t, 2);
      expect(_field(t), '75');
      expect(_text(t, 'conversion-source'), 'Frankfurter\u00A0· 20\u00A0Nov\u00A02026');
      expect(
        _text(t, 'conversion-result'),
        '≈ ${_money(convert(10001, 'USD', 'INR', _auto), 'INR')}',
      );
      expect(find.byKey(const Key('conversion-use-auto')), findsNothing);
    });

    // TC-32-04
    testWidgets('typing exactly the Frankfurter rate keeps it automatic', (t) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('conversion-rate')), '75.00');
      await settle(t, 2);
      expect(_text(t, 'conversion-source'), 'Frankfurter\u00A0· 20\u00A0Nov\u00A02026');
      expect(find.byKey(const Key('conversion-use-auto')), findsNothing);
    });

    // TC-32-04
    testWidgets('an invalid rate shows the error and Save is disabled', (t) async {
      await _open(t);
      for (final bad in ['0', '1.12345678901', '1.2.3', '.']) {
        await t.enterText(find.byKey(const Key('conversion-rate')), bad);
        await settle(t, 2);
        expect(find.text('Enter a rate above 0 with up to 10 decimals'), findsWidgets, reason: bad);
        expect(_canSave(t), isFalse, reason: bad);
        expect(_text(t, 'conversion-result'), 'Rate needed');
      }
    }, skip: false);

    // TC-32-04
    testWidgets('clearing the field disables Save; the error shows in the source line only', (
      t,
    ) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('conversion-rate')), '');
      await settle(t, 2);
      expect(t.widget<UnderlineField>(find.byKey(const Key('conversion-rate'))).errorText, isNull);
      expect(_text(t, 'conversion-source'), 'Enter a rate above 0 with up to 10 decimals');
      expect(_canSave(t), isFalse);
    });

    // TC-32-04
    testWidgets('a converted amount that does not fit says it is too large', (t) async {
      await _open(t);
      await t.enterText(find.byKey(const Key('conversion-rate')), '1000000000000000');
      await settle(t, 2);
      expect(find.text('The converted amount is too large'), findsOneWidget);
      expect(_canSave(t), isFalse);
    });
  });

  group('no automatic rate', () {
    // TC-32-04
    testWidgets('empty cache and offline: asks for a rate; a typed one can be saved', (t) async {
      final env = await _open(t, cache: false);
      expect(_field(t), '');
      expect(
        _text(t, 'conversion-source'),
        'No saved rate for 20\u00A0Nov\u00A02026 on this phone. Type the rate, or connect to the internet.',
      );
      expect(_canSave(t), isFalse);
      // the sheet tried the server for the missing days
      expect(env.remote.betweenCalls, hasLength(1));
      expect(env.remote.betweenCalls.single.$1, {'USD', 'INR'});
      expect(env.remote.betweenCalls.single.$3, '2026-11-20');

      await t.enterText(find.byKey(const Key('conversion-rate')), '80');
      await settle(t, 2);
      expect(_text(t, 'conversion-source'), 'Rate you typed\u00A0· 20\u00A0Nov\u00A02026');
      expect(_canSave(t), isTrue);
      await t.tap(find.byKey(const Key('conversion-save')));
      await settleReal(t);

      final row = await env.expense();
      expect(row.fxSource, 'manual');
      expect(row.fxRateDate, '2026-11-20');
      expect(row.fxRate, '80');
      expect(row.fxCurrency, 'INR');
      expect(row.fxTotal, convert(10001, 'USD', 'INR', '80'));
      expect(find.text('Conversion saved'), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a currency Frankfurter does not publish (VED) says so, no server call', (t) async {
      final env = await _open(t, expenses: [_expense(currency: 'VED')]);
      expect(_text(t, 'conversion-source'), 'VED has no published rate. Type the rate.');
      expect(_canSave(t), isFalse);
      expect(env.remote.betweenCalls, isEmpty);
      await t.enterText(find.byKey(const Key('conversion-rate')), '2.5');
      await settle(t, 2);
      expect(_canSave(t), isTrue);
      expect(
        _text(t, 'conversion-result'),
        '≈ ${_money(convert(10001, 'VED', 'INR', '2.5'), 'INR')}',
      );
    });
  });

  group('server rates', () {
    final rows = [
      (date: '2026-11-20', currency: 'INR', rate: '90', fetchedAt: '2026-11-21T00:00:00Z'),
      (date: '2026-11-20', currency: 'USD', rate: '1.2', fetchedAt: '2026-11-21T00:00:00Z'),
    ];

    // TC-32-04
    testWidgets('online, missing days are fetched and fill an untouched sheet', (t) async {
      final remote = FakeFxRemote(rows: rows);
      await _open(t, cache: false, remote: remote);
      expect(remote.betweenCalls, hasLength(1));
      expect(_field(t), '75');
      expect(_text(t, 'conversion-source'), 'Frankfurter\u00A0· 20\u00A0Nov\u00A02026');
      expect(_text(t, 'conversion-result'), '≈ ₹7,500.75');
      expect(_canSave(t), isTrue);
    });

    // TC-32-04
    testWidgets('a rate typed before the server answers is kept, the automatic one is offered', (
      t,
    ) async {
      final remote = FakeFxRemote(rows: rows)..gate = Completer<void>();
      await _open(t, cache: false, remote: remote);
      await t.enterText(find.byKey(const Key('conversion-rate')), '80');
      await settle(t, 2);
      remote.gate!.complete();
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await settle(t);
      expect(_field(t), '80');
      expect(_text(t, 'conversion-source'), 'Rate you typed\u00A0· 20\u00A0Nov\u00A02026');
      expect(find.byKey(const Key('conversion-use-auto')), findsOneWidget);
      await t.tap(find.byKey(const Key('conversion-use-auto')));
      await settle(t, 2);
      expect(_field(t), '75');
    });
  });

  group('save and remove', () {
    // TC-32-04
    testWidgets('Save writes the fx columns to the expense and the outbox, then says so', (
      t,
    ) async {
      final env = await _open(t);
      await t.tap(find.byKey(const Key('conversion-save')));
      await settleReal(t);

      final row = await env.expense();
      final c = convertExpense(
        total: 10001,
        from: 'USD',
        to: 'INR',
        rate: _auto,
        paid: {'m1': 10001},
        shares: {'m1': 5001, 'm2': 5000},
        order: _members,
      );
      expect(row.fxRate, _auto);
      expect(row.fxRateDate, '2026-11-20');
      expect(row.fxSource, 'frankfurter');
      expect(row.fxCurrency, 'INR');
      expect(row.fxTotal, c.total);
      expect(_ints(row.fxPayers), c.paid);
      expect(_ints(row.fxShares), c.shares);
      expect(_ints(row.fxShares).values.fold(0, (a, b) => a + b), row.fxTotal);
      expect(row.total, 10001); // the original is untouched
      expect(row.currency, 'USD');

      final payload = (await env.outbox('expense', 'e1')).single;
      expect(payload.keys, everyElement(startsWith('fx_')));
      expect(payload['fx_total'], c.total);

      expect(find.byKey(const Key('conversion-sheet')), findsNothing);
      expect(find.text('Conversion saved'), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a saved conversion shows Remove, which clears every fx column', (t) async {
      final saved = _expense().copyWith(
        fxRate: const Value(_auto),
        fxRateDate: const Value('2026-11-20'),
        fxSource: const Value('frankfurter'),
        fxCurrency: const Value('INR'),
        fxTotal: const Value(750075),
        fxPayers: Value(jsonEncode({'m1': 750075})),
        fxShares: Value(jsonEncode({'m1': 375038, 'm2': 375037})),
      );
      final env = await _open(t, expenses: [saved]);
      expect(find.byKey(const Key('conversion-remove')), findsOneWidget);
      expect(find.text('Remove conversion'), findsOneWidget);
      expect(_field(t), '75');
      expect(_text(t, 'conversion-source'), 'Frankfurter\u00A0· 20\u00A0Nov\u00A02026');

      await t.tap(find.byKey(const Key('conversion-remove')));
      await settleReal(t);
      final row = await env.expense();
      expect(row.fxRate, isNull);
      expect(row.fxRateDate, isNull);
      expect(row.fxSource, isNull);
      expect(row.fxCurrency, isNull);
      expect(row.fxTotal, isNull);
      expect(row.fxPayers, isNull);
      expect(row.fxShares, isNull);
      expect(find.text('Conversion removed'), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a saved typed rate stays typed and offers the Frankfurter one', (t) async {
      final saved = _expense().copyWith(
        fxRate: const Value('80'),
        fxRateDate: const Value('2026-11-20'),
        fxSource: const Value('manual'),
        fxCurrency: const Value('INR'),
        fxTotal: const Value(800080),
        fxPayers: Value(jsonEncode({'m1': 800080})),
        fxShares: Value(jsonEncode({'m1': 400040, 'm2': 400040})),
      );
      await _open(t, expenses: [saved]);
      expect(_field(t), '80');
      expect(_text(t, 'conversion-source'), 'Rate you typed\u00A0· 20\u00A0Nov\u00A02026');
      expect(find.byKey(const Key('conversion-use-auto')), findsOneWidget);
      expect(find.byKey(const Key('conversion-remove')), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a payment converts its amount (fx_amount)', (t) async {
      final env = await _open(
        t,
        expenses: const [],
        payments: [
          seedPayment(
            'p1',
            from: 'm2',
            to: 'm1',
            amount: 5000,
            currency: 'USD',
            date: '2026-11-20',
          ),
        ],
        recordId: 'p1',
        payment: true,
      );
      expect(_text(t, 'conversion-original'), _money(5000, 'USD'));
      expect(
        _text(t, 'conversion-result'),
        '≈ ${_money(convert(5000, 'USD', 'INR', _auto), 'INR')}',
      );
      await t.tap(find.byKey(const Key('conversion-save')));
      await settleReal(t);
      final row = await env.payment();
      expect(row.fxAmount, convert(5000, 'USD', 'INR', _auto));
      expect(row.fxAmount, 375000);
      expect(row.fxCurrency, 'INR');
      expect(row.fxRate, _auto);
      expect(row.fxSource, 'frankfurter');
      expect(row.fxRateDate, '2026-11-20');
      expect((await env.outbox('payment', 'p1')).single.keys, everyElement(startsWith('fx_')));
      expect(find.text('Conversion saved'), findsOneWidget);
    });
  });

  group('not possible', () {
    // TC-32-04
    testWidgets('a record already in the group currency', (t) async {
      await _open(t, expenses: [_expense(currency: 'INR')]);
      expect(find.text('This record is already in the group\'s currency.'), findsOneWidget);
      expect(find.byKey(const Key('conversion-sheet')), findsNothing);
      expect(find.byKey(const Key('conversion-save')), findsNothing);
    });

    // TC-32-04
    testWidgets('a record that is not on this phone', (t) async {
      await _open(t, recordId: 'nope');
      expect(find.text('This record is already in the group\'s currency.'), findsOneWidget);
    });

    // TC-32-04
    testWidgets('a deleted record', (t) async {
      final gone = seedExpense(
        'e1',
        currency: 'USD',
        total: 100,
        payers: {'m1': 100},
        shares: {'m1': 100},
        deletedAt: '2026-11-21T00:00:00Z',
      );
      await _open(t, expenses: [gone]);
      expect(find.text('This record is already in the group\'s currency.'), findsOneWidget);
    });
  });

  group('layout', () {
    // TC-32-04
    testWidgets('lays out at text scale 2.0 without overflow', (t) async {
      await _open(t, scale: 2);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('conversion-result')), findsOneWidget);
      expect(find.byKey(const Key('conversion-save')), findsOneWidget);
      await t.enterText(find.byKey(const Key('conversion-rate')), '80');
      await settle(t, 2);
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('conversion-use-auto')), findsOneWidget);
    });
  });
}
