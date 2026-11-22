import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/fx_rates_repository.dart';

import '../../support/fakes.dart';

/// Scripted server: serves [rows] like PostgREST (cursor, from-date, paging) and records every call.
class _FakeFxRemote implements FxRatesRemote {
  List<RemoteFxRate> rows = [];
  Exception? error;
  final changedCalls = <({String? since, String fromDate, int offset, int limit})>[];
  final betweenCalls = <({Set<String> currencies, String from, String to})>[];

  @override
  Future<List<RemoteFxRate>> changedSince({
    required String? since,
    required String fromDate,
    int offset = 0,
    int limit = 1000,
  }) async {
    changedCalls.add((since: since, fromDate: fromDate, offset: offset, limit: limit));
    if (error != null) throw error!;
    final hits = [
      for (final r in rows)
        if (r.date.compareTo(fromDate) >= 0 && (since == null || r.fetchedAt.compareTo(since) > 0))
          r,
    ];
    return hits.skip(offset).take(limit).toList();
  }

  @override
  Future<List<RemoteFxRate>> between(Set<String> currencies, String from, String to) async {
    betweenCalls.add((currencies: currencies, from: from, to: to));
    if (error != null) throw error!;
    return [
      for (final r in rows)
        if (currencies.contains(r.currency) &&
            r.date.compareTo(from) >= 0 &&
            r.date.compareTo(to) <= 0)
          r,
    ];
  }
}

RemoteFxRate _row(String date, String currency, String rate, [String? fetchedAt]) =>
    (date: date, currency: currency, rate: rate, fetchedAt: fetchedAt ?? '${date}T14:00:00+00:00');

void main() {
  late AppDatabase db;
  late _FakeFxRemote remote;
  late FakeClock clock;
  late FxRatesRepository repo;

  setUp(() {
    db = testDb();
    remote = _FakeFxRemote();
    clock = FakeClock(DateTime.utc(2026, 11, 22, 12));
    repo = FxRatesRepository(db, remote, clock);
  });
  tearDown(() => db.close());

  Future<void> cache(String date, String currency, String rate) =>
      db.into(db.fxRates).insert(LocalFxRate(date: date, currency: currency, rate: rate));

  group('refresh', () {
    test('first pull takes the last 90 days, stores rows and sets cursor + time', () async {
      remote.rows = [
        _row('2026-11-20', 'USD', '1.08', '2026-11-20T14:00:00+00:00'),
        _row('2026-11-21', 'INR', '90.5', '2026-11-21T14:00:00+00:00'),
        _row('2026-01-01', 'INR', '88', '2026-11-21T14:00:00+00:00'), // older than 90 days
      ];
      expect(await repo.refresh(), 2);
      expect(remote.changedCalls.single.since, isNull);
      expect(remote.changedCalls.single.fromDate, '2026-08-24');
      expect(remote.changedCalls.single.offset, 0);
      expect(remote.changedCalls.single.limit, 1000);
      expect(await repo.count(), 2);
      final meta = SyncDao(db);
      expect(await meta.meta(FxRatesRepository.cursorKey), '2026-11-21T14:00:00+00:00');
      expect(await meta.meta(FxRatesRepository.refreshedKey), clock.now().toIso8601String());
    });

    test(
      'is throttled to once per 6 hours; later pulls use the cursor; force skips the check',
      () async {
        remote.rows = [_row('2026-11-20', 'USD', '1.08')];
        expect(await repo.refresh(), 1);

        clock.advance(const Duration(hours: 5, minutes: 59));
        expect(await repo.refresh(), isNull);
        expect(remote.changedCalls, hasLength(1));

        remote.rows = [...remote.rows, _row('2026-11-22', 'USD', '1.09')];
        clock.advance(const Duration(minutes: 1));
        expect(await repo.refresh(), 1);
        expect(remote.changedCalls.last.since, '2026-11-20T14:00:00+00:00');
        expect(await repo.count(), 2);

        expect(await repo.refresh(force: true), 0);
        expect(remote.changedCalls, hasLength(3));
      },
    );

    test('a clock that went backwards does not block the pull', () async {
      await repo.refresh();
      clock.advance(const Duration(hours: -2));
      expect(await repo.refresh(), 0);
      expect(remote.changedCalls, hasLength(2));
    });

    test('pages by 1000 until a short page', () async {
      remote.rows = [
        for (var i = 0; i < 1001; i++)
          _row(
            DateTime.utc(2026, 9).add(Duration(days: i % 60)).toIso8601String().substring(0, 10),
            'C${i.toString().padLeft(3, '0')}',
            '1',
            '2026-11-20T${(i ~/ 100).toString().padLeft(2, '0')}:00:00+00:00',
          ),
      ];
      expect(await repo.refresh(), 1001);
      expect([for (final c in remote.changedCalls) c.offset], [0, 1000]);
      expect(await repo.count(), 1001);
      expect(await SyncDao(db).meta(FxRatesRepository.cursorKey), '2026-11-20T10:00:00+00:00');
    });

    test('a full last page is followed by one more (empty) page', () async {
      remote.rows = [
        for (var i = 0; i < 1000; i++) _row('2026-11-20', 'C${i.toString().padLeft(3, '0')}', '1'),
      ];
      expect(await repo.refresh(), 1000);
      expect([for (final c in remote.changedCalls) c.offset], [0, 1000]);
    });

    test('offline returns null, keeps the cache and does not touch the meta', () async {
      await cache('2026-11-19', 'USD', '1.07');
      remote.error = const NetworkException();
      expect(await repo.refresh(), isNull);
      expect(await repo.count(), 1);
      expect(await SyncDao(db).meta(FxRatesRepository.refreshedKey), isNull);
      expect(await SyncDao(db).meta(FxRatesRepository.cursorKey), isNull);
      // the failed pull does not start the 6 h throttle
      remote.error = null;
      expect(await repo.refresh(), 0);
    });

    test('a changed row updates the cached one', () async {
      remote.rows = [_row('2026-11-20', 'USD', '1.08', '2026-11-20T14:00:00+00:00')];
      await repo.refresh();
      remote.rows = [_row('2026-11-20', 'USD', '1.10', '2026-11-21T14:00:00+00:00')];
      expect(await repo.refresh(force: true), 1);
      expect(await repo.count(), 1);
      expect((await db.select(db.fxRates).getSingle()).rate, '1.10');
    });

    test('cursor compares unparseable times as text', () async {
      remote.rows = [
        _row('2026-11-20', 'USD', '1', 'a'),
        _row('2026-11-20', 'GBP', '1', 'b'),
        _row('2026-11-20', 'CHF', '1', '2026-11-20T00:00:00Z'),
      ];
      await repo.refresh();
      expect(await SyncDao(db).meta(FxRatesRepository.cursorKey), 'b');
    });

    test('an empty first pull stores no cursor but marks the pull', () async {
      expect(await repo.refresh(), 0);
      expect(await SyncDao(db).meta(FxRatesRepository.cursorKey), isNull);
      expect(await SyncDao(db).meta(FxRatesRepository.refreshedKey), isNotNull);
    });
  });

  group('ensureFor', () {
    final day = DateTime.utc(2026, 11, 20);

    test('EUR alone needs nothing', () async {
      await repo.ensureFor({'EUR'}, day);
      await repo.ensureFor(const {}, day);
      expect(remote.betweenCalls, isEmpty);
    });

    test(
      'fetches the 10 days up to the date when the cache lacks a currency (EUR left out)',
      () async {
        remote.rows = [
          _row('2026-11-12', 'USD', '1.05'),
          _row('2026-11-01', 'USD', '1.01'), // outside the window
          _row('2026-11-14', 'INR', '90'),
        ];
        await repo.ensureFor({'EUR', 'USD', 'INR'}, day);
        expect(remote.betweenCalls.single.currencies, {'USD', 'INR'});
        expect(remote.betweenCalls.single.from, '2026-11-10');
        expect(remote.betweenCalls.single.to, '2026-11-20');
        expect(await repo.count(), 2);
      },
    );

    test('does not fetch when every wanted currency has a row in the window', () async {
      await cache('2026-11-10', 'USD', '1.05');
      await cache('2026-11-20', 'INR', '90');
      await repo.ensureFor({'USD', 'INR'}, day);
      expect(remote.betweenCalls, isEmpty);
    });

    test('fetches when one currency is only cached outside the window', () async {
      await cache('2026-11-09', 'USD', '1.05');
      await cache('2026-11-21', 'USD', '1.06');
      await cache('2026-11-15', 'INR', '90');
      await repo.ensureFor({'USD', 'INR'}, day);
      expect(remote.betweenCalls, hasLength(1));
    });

    test('offline is fine', () async {
      remote.error = const NetworkException();
      await repo.ensureFor({'USD'}, day);
      expect(remote.betweenCalls, hasLength(1));
      expect(await repo.count(), 0);
    });
  });

  group('ratesOnOrBefore (local only)', () {
    test('filters by currency and date', () async {
      await cache('2026-11-18', 'USD', '1.05');
      await cache('2026-11-20', 'USD', '1.06');
      await cache('2026-11-21', 'USD', '1.07');
      await cache('2026-11-19', 'INR', '90.25');
      await cache('2026-11-19', 'GBP', '0.8');
      final rows = await repo.ratesOnOrBefore({'USD', 'INR'}, DateTime.utc(2026, 11, 20));
      expect(
        {
          for (final r in rows)
            '${r.currency} ${r.date.toIso8601String().substring(0, 10)} ${r.rate}',
        },
        {'USD 2026-11-18 1.05', 'USD 2026-11-20 1.06', 'INR 2026-11-19 90.25'},
      );
      expect(rows.first.date.isUtc, isTrue);
      expect(remote.changedCalls, isEmpty);
      expect(remote.betweenCalls, isEmpty);
    });

    test('an empty currency set reads nothing', () async {
      await cache('2026-11-18', 'USD', '1.05');
      expect(await repo.ratesOnOrBefore(const {}, DateTime.utc(2026, 11, 20)), isEmpty);
    });
  });

  test('count is 0 on an empty cache', () async {
    expect(await repo.count(), 0);
  });
}
