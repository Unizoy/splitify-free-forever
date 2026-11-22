import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/currency_reads.dart';

import '../../support/fakes.dart';
import '../../support/ledger_seed.dart';

void main() {
  late AppDatabase db;
  late CurrencyReads reads;
  setUp(() {
    db = testDb();
    reads = CurrencyReads(db);
  });
  tearDown(() => db.close());

  LocalExpense expense(
    String id,
    String currency, {
    String? createdAt,
    String date = '2026-11-01',
    String? deletedAt,
  }) => seedExpense(
    id,
    currency: currency,
    date: date,
    total: 100,
    payers: {'m1': 100},
    shares: {'m1': 100},
    deletedAt: deletedAt,
  ).copyWith(createdAt: Value(createdAt));

  LocalPayment payment(
    String id,
    String currency, {
    String? createdAt,
    String date = '2026-11-01',
    String? deletedAt,
  }) => seedPayment(
    id,
    from: 'm1',
    to: 'm2',
    amount: 100,
    currency: currency,
    date: date,
    deletedAt: deletedAt,
  ).copyWith(createdAt: Value(createdAt));

  Future<List<String>> recent({int limit = 5}) => reads.watchRecent(limit: limit).first;

  test('empty ledger gives no currencies', () async {
    expect(await recent(), isEmpty);
  });

  test('distinct currencies of expenses and payments, most recently used first', () async {
    await db.seed(
      expenses: [
        expense('e1', 'USD', createdAt: '2026-11-18T10:00:00Z'),
        expense('e2', 'USD', createdAt: '2026-11-10T10:00:00Z'),
        expense('e3', 'INR', createdAt: '2026-11-15T10:00:00Z'),
      ],
      payments: [
        payment('p1', 'EUR', createdAt: '2026-11-20T10:00:00Z'),
        payment('p2', 'INR', createdAt: '2026-11-16T10:00:00Z'),
      ],
    );
    expect(await recent(), ['EUR', 'USD', 'INR']);
  });

  test('a missing created_at falls back to the record date', () async {
    await db.seed(
      expenses: [
        expense('e1', 'USD', createdAt: '2026-11-18T10:00:00Z'),
        expense('e2', 'GBP', date: '2026-11-22'),
      ],
      payments: [payment('p1', 'EUR', date: '2026-11-19')],
    );
    expect(await recent(), ['GBP', 'EUR', 'USD']);
  });

  test('codes are trimmed and grouped; deleted records do not count', () async {
    await db.seed(
      expenses: [
        expense('e1', 'GBP ', createdAt: '2026-11-18T10:00:00Z'),
        expense('e2', 'GBP', createdAt: '2026-11-17T10:00:00Z'),
        expense('e3', 'JPY', createdAt: '2026-11-21T10:00:00Z', deletedAt: '2026-11-22T00:00:00Z'),
      ],
      payments: [
        payment('p1', 'CHF', createdAt: '2026-11-21T10:00:00Z', deletedAt: '2026-11-22T00:00:00Z'),
      ],
    );
    expect(await recent(), ['GBP']);
  });

  test('ties are ordered by code and the list is capped at the limit', () async {
    await db.seed(
      expenses: [
        for (final c in ['SEK', 'AUD', 'CAD', 'NOK'])
          expense('e$c', c, createdAt: '2026-11-18T10:00:00Z'),
      ],
    );
    expect(await recent(), ['AUD', 'CAD', 'NOK', 'SEK']);
    expect(await recent(limit: 2), ['AUD', 'CAD']);
  });

  test('re-emits when a new currency is used', () async {
    await db.seed(expenses: [expense('e1', 'INR', createdAt: '2026-11-18T10:00:00Z')]);
    final emissions = <List<String>>[];
    final sub = reads.watchRecent().listen(emissions.add);
    await pumpEventQueue();
    await db.seed(expenses: [expense('e2', 'USD', createdAt: '2026-11-19T10:00:00Z')]);
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions.first, ['INR']);
    expect(emissions.last, ['USD', 'INR']);
  });
}
