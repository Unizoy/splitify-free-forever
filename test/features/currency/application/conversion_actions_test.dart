import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/features/currency/application/conversion_actions.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';

import '../../../support/fakes.dart';
import '../../../support/ledger_seed.dart';

/// Server with no rates of its own: [error] makes it behave offline.
class _FakeFxRemote implements FxRatesRemote {
  Exception? error;
  final betweenCalls = <(Set<String>, String, String)>[];

  @override
  Future<List<RemoteFxRate>> changedSince({
    required String? since,
    required String fromDate,
    int offset = 0,
    int limit = 1000,
  }) async {
    if (error != null) throw error!;
    return const [];
  }

  @override
  Future<List<RemoteFxRate>> between(Set<String> currencies, String from, String to) async {
    betweenCalls.add((currencies, from, to));
    if (error != null) throw error!;
    return const [];
  }
}

Map<String, int> _ints(String? json) => {
  for (final e in (jsonDecode(json!) as Map<String, Object?>).entries) e.key: e.value! as int,
};

int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

void main() {
  late AppDatabase db;
  late _FakeFxRemote remote;
  late ProviderContainer container;

  setUp(() async {
    db = testDb();
    remote = _FakeFxRemote();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 12))),
        fxRatesRemoteProvider.overrideWithValue(remote),
      ],
    );
    await db.seed(
      groups: [seedGroup()],
      members: [seedMember('m1'), seedMember('m2', position: 1)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ConversionActions actions() => container.read(conversionActionsProvider);

  /// EUR-based cache: on 20 Nov 1 EUR = 90 INR = 1.2 USD (USD→INR 75); on 17 Nov 1 EUR = 90 INR = 1.25 USD (72).
  Future<void> cacheRates() async {
    for (final r in [
      ('2026-11-20', 'INR', '90'),
      ('2026-11-20', 'USD', '1.2'),
      ('2026-11-17', 'INR', '90'),
      ('2026-11-17', 'USD', '1.25'),
    ]) {
      await db.into(db.fxRates).insert(LocalFxRate(date: r.$1, currency: r.$2, rate: r.$3));
    }
  }

  Future<LocalExpense> expenseRow(String id) =>
      (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingle();
  Future<LocalPayment> paymentRow(String id) =>
      (db.select(db.payments)..where((p) => p.id.equals(id))).getSingle();

  Future<List<Map<String, Object?>>> outboxPayloads(String entity, String recordId) async => [
    for (final o in await db.select(db.outbox).get())
      if (o.entity == entity && o.recordId == recordId)
        jsonDecode(o.payload) as Map<String, Object?>,
  ];

  final manual = FxRate(
    from: 'USD',
    to: 'INR',
    rate: '80',
    effectiveDate: DateTime.utc(2026, 11, 19),
    source: FxSource.manual,
    isFallback: false,
  );

  group('record mapping', () {
    test('fxRecordOfExpense trims codes and dates and reads saved parts', () async {
      final row =
          seedExpense(
            'e1',
            currency: 'USD ',
            date: '2026-11-20T00:00:00Z',
            total: 1000,
            payers: {'m1': 1000},
            shares: {'m1': 400, 'm2': 600},
          ).copyWith(
            fxCurrency: const Value('INR '),
            fxTotal: const Value(75000),
            fxPayers: Value(jsonEncode({'m1': 75000})),
            fxShares: Value(jsonEncode({'m1': 30000, 'm2': 45000})),
          );
      final r = fxRecordOfExpense(row);
      expect(r.id, 'e1');
      expect(r.date, '2026-11-20');
      expect(r.currency, 'USD');
      expect(r.amount, 1000);
      expect(r.description, 'Dinner');
      expect(r.paid, {'m1': 1000});
      expect(r.shares, {'m1': 400, 'm2': 600});
      expect(r.fxCurrency, 'INR');
      expect(r.fxAmount, 75000);
      expect(r.fxPaid, {'m1': 75000});
      expect(r.fxShares, {'m1': 30000, 'm2': 45000});
      expect(r.countsIn('INR'), isTrue);
    });

    test('an expense without a conversion has no fx parts', () {
      final r = fxRecordOfExpense(
        seedExpense('e1', total: 100, payers: {'m1': 100}, shares: {'m1': 100}),
      );
      expect(r.fxCurrency, isNull);
      expect(r.fxPaid, isNull);
      expect(r.fxShares, isNull);
    });

    test('fxRecordOfPayment maps a payment', () {
      final row = seedPayment(
        'p1',
        from: 'm1',
        to: 'm2',
        amount: 500,
        currency: 'USD ',
        date: '2026-11-20T10:00:00Z',
      ).copyWith(fxCurrency: const Value('INR'), fxAmount: const Value(37500));
      final r = fxRecordOfPayment(row);
      expect(r.isPayment, isTrue);
      expect(r.date, '2026-11-20');
      expect(r.currency, 'USD');
      expect((r.from, r.to, r.amount), ('m1', 'm2', 500));
      expect(r.fxCurrency, 'INR');
      expect(r.fxAmount, 37500);
    });

    test('savedFxOf* read the columns, a half-saved row is none', () {
      final e = seedExpense('e1', total: 100, payers: {'m1': 100}, shares: {'m1': 100});
      expect(savedFxOfExpense(e), isNull);
      final full = e.copyWith(
        fxRate: const Value('75'),
        fxRateDate: const Value('2026-11-20'),
        fxSource: const Value('manual'),
        fxCurrency: const Value('INR'),
        fxTotal: const Value(7500),
      );
      final s = savedFxOfExpense(full)!;
      expect((s.rate, s.currency, s.total, s.source), ('75', 'INR', 7500, FxSource.manual));
      expect(savedFxOfExpense(full.copyWith(fxTotal: const Value(null))), isNull);

      final p = seedPayment('p1', from: 'm1', to: 'm2', amount: 100);
      expect(savedFxOfPayment(p), isNull);
      final sp = savedFxOfPayment(
        p.copyWith(
          fxRate: const Value('75'),
          fxRateDate: const Value('2026-11-20'),
          fxSource: const Value('frankfurter'),
          fxCurrency: const Value('INR'),
          fxAmount: const Value(7500),
        ),
      )!;
      expect((sp.total, sp.source), (7500, FxSource.frankfurter));
    });
  });

  group('save and remove', () {
    test('save writes the expense conversion to the row and the outbox (fx keys only)', () async {
      await db.seed(
        expenses: [
          seedExpense(
            'e1',
            currency: 'USD',
            total: 1001,
            payers: {'m1': 1001},
            shares: {'m1': 501, 'm2': 500},
          ),
        ],
      );
      final record = fxRecordOfExpense(await expenseRow('e1'));
      await actions().save('g1', record, manual, ['m1', 'm2']);

      final row = await expenseRow('e1');
      expect(row.fxRate, '80');
      expect(row.fxRateDate, '2026-11-19');
      expect(row.fxSource, 'manual');
      expect(row.fxCurrency, 'INR');
      expect(row.fxTotal, convert(1001, 'USD', 'INR', '80'));
      expect(_sum(_ints(row.fxPayers)), row.fxTotal);
      expect(_sum(_ints(row.fxShares)), row.fxTotal);
      expect(row.total, 1001); // the original amounts are untouched
      expect(savedFxOfExpense(row), isNotNull);

      final payload = (await outboxPayloads('expense', 'e1')).single;
      expect(payload.keys, everyElement(startsWith('fx_')));
      expect(payload['fx_total'], row.fxTotal);
    });

    test('save and remove a payment conversion', () async {
      await db.seed(
        payments: [seedPayment('p1', from: 'm1', to: 'm2', amount: 500, currency: 'USD')],
      );
      final record = fxRecordOfPayment(await paymentRow('p1'));
      await actions().save('g1', record, manual, ['m1', 'm2']);
      var row = await paymentRow('p1');
      expect(row.fxAmount, convert(500, 'USD', 'INR', '80'));
      expect(row.fxCurrency, 'INR');
      expect(row.fxSource, 'manual');
      expect((await outboxPayloads('payment', 'p1')).single.keys, everyElement(startsWith('fx_')));

      await actions().remove('g1', record);
      row = await paymentRow('p1');
      expect(row.fxAmount, isNull);
      expect(row.fxRate, isNull);
      expect(row.fxCurrency, isNull);
      expect(savedFxOfPayment(row), isNull);
    });

    test('remove clears an expense conversion', () async {
      await db.seed(
        expenses: [
          seedExpense(
            'e1',
            currency: 'USD',
            total: 1000,
            payers: {'m1': 1000},
            shares: {'m1': 500, 'm2': 500},
          ),
        ],
      );
      final record = fxRecordOfExpense(await expenseRow('e1'));
      await actions().save('g1', record, manual, ['m1', 'm2']);
      await actions().remove('g1', record);
      final row = await expenseRow('e1');
      expect(row.fxTotal, isNull);
      expect(row.fxPayers, isNull);
      expect(row.fxShares, isNull);
      expect(row.fxRate, isNull);
      expect(savedFxOfExpense(row), isNull);
    });
  });

  group('convertAll', () {
    Future<void> seedMixed() => db.seed(
      expenses: [
        // dated on a cached day
        seedExpense(
          'e1',
          currency: 'USD',
          total: 1001,
          payers: {'m1': 1001},
          shares: {'m1': 501, 'm2': 500},
        ),
        // 18 Nov has no rates: the 17th is the previous cached day
        seedExpense(
          'e2',
          currency: 'USD',
          date: '2026-11-18',
          total: 999,
          payers: {'m2': 999},
          shares: {'m1': 333, 'm2': 666},
        ),
        // no GBP rates at all
        seedExpense(
          'e3',
          currency: 'GBP',
          total: 500,
          payers: {'m1': 500},
          shares: {'m1': 250, 'm2': 250},
        ),
        // already in the main currency: not touched
        seedExpense('e4', total: 700, payers: {'m1': 700}, shares: {'m1': 350, 'm2': 350}),
      ],
      payments: [
        seedPayment('p1', from: 'm2', to: 'm1', amount: 250, currency: 'USD', date: '2026-11-20'),
      ],
    );

    // TC-32-06
    test('converts records with a cached rate at their date and leaves the rest', () async {
      await cacheRates();
      await seedMixed();
      final result = await actions().convertAll('g1');
      expect(result.converted, 3);
      expect(result.needRate, 1);

      final e1 = await expenseRow('e1');
      expect(e1.fxRate, '75.0000000000');
      expect(e1.fxRateDate, '2026-11-20');
      expect(e1.fxSource, 'frankfurter');
      expect(e1.fxCurrency, 'INR');
      expect(e1.fxTotal, convert(1001, 'USD', 'INR', '75.0000000000'));
      expect(e1.fxTotal, 75075);

      // TC-32-05: the previous cached day's rate (17 Nov, 72) is used for 18 Nov
      final e2 = await expenseRow('e2');
      expect(e2.fxRate, '72.0000000000');
      expect(e2.fxRateDate, '2026-11-17');
      expect(e2.fxTotal, convert(999, 'USD', 'INR', '72.0000000000'));

      final p1 = await paymentRow('p1');
      expect(p1.fxCurrency, 'INR');
      expect(p1.fxAmount, convert(250, 'USD', 'INR', '75.0000000000'));
      expect(p1.fxAmount, 18750);

      // no rate: still unconverted; native: untouched
      expect((await expenseRow('e3')).fxTotal, isNull);
      expect((await expenseRow('e4')).fxTotal, isNull);
      expect((await expenseRow('e4')).fxCurrency, isNull);
      // GBP was looked up on the server once (offline-friendly best effort)
      expect(remote.betweenCalls.map((c) => c.$1), contains(containsAll({'GBP', 'INR'})));
    });

    // TC-32-06
    test('saved conversions are consistent: fx total = convert(total), parts sum to it', () async {
      await cacheRates();
      await seedMixed();
      await actions().convertAll('g1');
      for (final id in ['e1', 'e2']) {
        final row = await expenseRow(id);
        expect(row.fxTotal, convert(row.total, 'USD', 'INR', row.fxRate!));
        expect(_sum(_ints(row.fxPayers)), row.fxTotal);
        expect(_sum(_ints(row.fxShares)), row.fxTotal);
      }
    });

    // TC-32-06
    test(
      'only fx keys are queued, and the converted records then count in the main currency',
      () async {
        await cacheRates();
        await seedMixed();
        await actions().convertAll('g1');
        for (final entity in [('expense', 'e1'), ('expense', 'e2'), ('payment', 'p1')]) {
          final payloads = await outboxPayloads(entity.$1, entity.$2);
          expect(payloads, hasLength(1), reason: entity.$2);
          expect(payloads.single.keys, everyElement(startsWith('fx_')), reason: entity.$2);
        }
        expect(await outboxPayloads('expense', 'e3'), isEmpty);
        expect(await outboxPayloads('expense', 'e4'), isEmpty);

        final ledgerRows = [
          fxRecordOfExpense(await expenseRow('e1')),
          fxRecordOfExpense(await expenseRow('e2')),
          fxRecordOfExpense(await expenseRow('e3')),
          fxRecordOfPayment(await paymentRow('p1')),
        ];
        final view = convertedBalances('INR', ['m1', 'm2'], ledgerRows);
        expect([for (final m in view.missing) m.id], ['e3']);
      },
    );

    // TC-32-06
    test('with every rate present nothing is left; a second run has nothing to do', () async {
      await cacheRates();
      await db.seed(
        expenses: [
          seedExpense(
            'e1',
            currency: 'USD',
            total: 1000,
            payers: {'m1': 1000},
            shares: {'m1': 500, 'm2': 500},
          ),
        ],
      );
      expect(await actions().convertAll('g1'), (converted: 1, needRate: 0));
      expect(await actions().convertAll('g1'), (converted: 0, needRate: 0));
      expect(await outboxPayloads('expense', 'e1'), hasLength(1));
    });

    // TC-32-06
    test('works offline from the cache', () async {
      remote.error = const NetworkException();
      await cacheRates();
      await seedMixed();
      final result = await actions().convertAll('g1');
      expect((result.converted, result.needRate), (3, 1));
    });

    // TC-32-06
    test('a group with nothing to convert or an unknown group does nothing', () async {
      expect(await actions().convertAll('nope'), (converted: 0, needRate: 0));
      await db.seed(
        expenses: [
          seedExpense('e4', total: 700, payers: {'m1': 700}, shares: {'m1': 700}),
        ],
      );
      expect(await actions().convertAll('g1'), (converted: 0, needRate: 0));
      expect(remote.betweenCalls, isEmpty);
    });

    // TC-32-06
    test('a record that cannot be converted is counted, the others still convert', () async {
      await cacheRates();
      await db.seed(
        expenses: [
          seedExpense(
            'ok',
            currency: 'USD',
            total: 1000,
            payers: {'m1': 1000},
            shares: {'m1': 500, 'm2': 500},
          ),
          // converted total would not fit the money limits
          seedExpense(
            'huge',
            currency: 'USD',
            total: 900000000000,
            payers: {'m1': 900000000000},
            shares: {'m1': 900000000000},
          ),
          // not a date
          seedExpense(
            'baddate',
            currency: 'USD',
            date: 'garbage',
            total: 100,
            payers: {'m1': 100},
            shares: {'m1': 100},
          ),
        ],
      );
      final result = await actions().convertAll('g1');
      expect((result.converted, result.needRate), (1, 2));
      expect((await expenseRow('ok')).fxTotal, 75000);
      expect((await expenseRow('huge')).fxTotal, isNull);
      expect((await expenseRow('baddate')).fxTotal, isNull);
    });
  });
}
