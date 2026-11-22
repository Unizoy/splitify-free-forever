import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/domain/rules/recurrence.dart' show formatIsoDate, parseIsoDate;
import 'package:splitify/features/currency/domain/fx_service.dart';

final _log = Logger('fx');

/// The phone's copy of the server's exchange rates (05 §6, phase 14 T3), so conversions work offline.
///
/// [refresh] pulls rows written since the last pull (cursor = the newest `fetched_at` seen, kept in
/// `sync_meta`); the first pull takes the last [initialDays] days. [ensureFor] fetches the days just before an
/// older record's date when the cache has nothing for them. Reads ([ratesOnOrBefore]) are local only.
class FxRatesRepository implements RatesSource {
  FxRatesRepository(this.db, this.remote, this.clock);

  final AppDatabase db;
  final FxRatesRemote remote;
  final Clock clock;

  /// `sync_meta` keys: newest server `fetched_at` stored, and when the last pull finished (device time).
  static const cursorKey = 'fx_rates_cursor';
  static const refreshedKey = 'fx_rates_refreshed_at';

  /// The server fetches twice a day (03 §6); pulling more often finds nothing new.
  static const minInterval = Duration(hours: 6);

  /// First pull: this many days back.
  static const initialDays = 90;

  /// [ensureFor] looks this many days before the record date (weekends, lagging currencies).
  static const lookbackDays = 10;

  /// Server page size (PostgREST's default row cap).
  static const pageSize = 1000;

  SyncDao get _meta => SyncDao(db);

  /// Pulls new server rates unless the last pull is younger than [minInterval] ([force] skips that check).
  /// Returns the number of rows stored, or null when it did not pull (too soon, or offline: the cache stays).
  Future<int?> refresh({bool force = false}) async {
    final now = clock.now().toUtc();
    if (!force) {
      final last = DateTime.tryParse(await _meta.meta(refreshedKey) ?? '');
      if (last != null && now.difference(last) < minInterval && !now.isBefore(last)) return null;
    }
    final since = await _meta.meta(cursorKey);
    final fromDate = formatIsoDate(now.subtract(const Duration(days: initialDays)));
    var stored = 0;
    String? newest = since;
    try {
      for (var offset = 0; ; offset += pageSize) {
        final page = await remote.changedSince(
          since: since,
          fromDate: fromDate,
          offset: offset,
          limit: pageSize,
        );
        await _store(page);
        stored += page.length;
        for (final r in page) {
          if (newest == null || _after(r.fetchedAt, newest)) newest = r.fetchedAt;
        }
        if (page.length < pageSize) break;
      }
    } on Exception catch (e) {
      _log.fine('rates not refreshed (${e.runtimeType}); $stored rows stored');
      return null;
    }
    await db.transaction(() async {
      if (newest != null) await _meta.setMeta(cursorKey, newest);
      await _meta.setMeta(refreshedKey, now.toIso8601String());
    });
    _log.fine('rates refreshed: $stored rows');
    return stored;
  }

  /// Makes sure the cache has rates of [currencies] in the [lookbackDays] days up to [date] (date-only UTC),
  /// fetching them from the server when none are cached (older records; best effort, offline is fine).
  Future<void> ensureFor(Set<String> currencies, DateTime date) async {
    final wanted = {
      for (final c in currencies)
        if (c != 'EUR') c,
    };
    if (wanted.isEmpty) return;
    final from = formatIsoDate(date.subtract(const Duration(days: lookbackDays)));
    final to = formatIsoDate(date);
    final have =
        await (db.selectOnly(db.fxRates, distinct: true)
              ..addColumns([db.fxRates.currency])
              ..where(
                db.fxRates.currency.isIn(wanted) &
                    db.fxRates.date.isBiggerOrEqualValue(from) &
                    db.fxRates.date.isSmallerOrEqualValue(to),
              ))
            .map((r) => r.read(db.fxRates.currency)!)
            .get();
    if (have.toSet().containsAll(wanted)) return;
    try {
      await _store(await remote.between(wanted, from, to));
    } on Exception catch (e) {
      _log.fine('rates for $to not fetched (${e.runtimeType})');
    }
  }

  @override
  Future<List<EurRate>> ratesOnOrBefore(Set<String> currencies, DateTime date) async {
    if (currencies.isEmpty) return const [];
    final rows =
        await (db.select(db.fxRates)..where(
              (r) =>
                  r.currency.isIn(currencies) & r.date.isSmallerOrEqualValue(formatIsoDate(date)),
            ))
            .get();
    return [
      for (final r in rows) EurRate(date: parseIsoDate(r.date), currency: r.currency, rate: r.rate),
    ];
  }

  /// Number of cached rows (Sync & storage, tests).
  Future<int> count() async {
    final n = db.fxRates.date.count();
    return (await (db.selectOnly(db.fxRates)..addColumns([n])).getSingle()).read(n) ?? 0;
  }

  Future<void> _store(List<RemoteFxRate> rows) async {
    if (rows.isEmpty) return;
    await db.batch((b) {
      b.insertAllOnConflictUpdate(db.fxRates, [
        for (final r in rows)
          LocalFxRate(date: r.date, currency: r.currency, rate: r.rate, fetchedAt: r.fetchedAt),
      ]);
    });
  }

  static bool _after(String a, String b) {
    final x = DateTime.tryParse(a);
    final y = DateTime.tryParse(b);
    if (x == null || y == null) return a.compareTo(b) > 0;
    return x.isAfter(y);
  }
}
