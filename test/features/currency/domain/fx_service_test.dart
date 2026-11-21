import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';

/// Honours the [RatesSource] contract.
final class MemoryRates implements RatesSource {
  MemoryRates(this.rows);

  final List<EurRate> rows;
  final calls = <(Set<String>, DateTime)>[];

  @override
  Future<List<EurRate>> ratesOnOrBefore(Set<String> currencies, DateTime date) async {
    calls.add((currencies, date));
    return [
      for (final r in rows)
        if (currencies.contains(r.currency) && !r.date.isAfter(date)) r,
    ];
  }
}

/// Ignores its arguments and returns every row.
final class RawRates implements RatesSource {
  RawRates(this.rows);

  final List<EurRate> rows;

  @override
  Future<List<EurRate>> ratesOnOrBefore(Set<String> currencies, DateTime date) async => rows;
}

final d1 = DateTime.utc(2026, 11, 19);
final d2 = DateTime.utc(2026, 11, 20);
final d3 = DateTime.utc(2026, 11, 21);

EurRate row(DateTime date, String currency, String rate) =>
    EurRate(date: date, currency: currency, rate: rate);

FxRate found(FxLookup r) => (r as FxRateFound).rate;
FxNeedsManualRate manual(FxLookup r) => r as FxNeedsManualRate;

void main() {
  final cache = [
    row(d1, 'INR', '98'),
    row(d1, 'USD', '1.2'),
    row(d2, 'INR', '100'),
    row(d2, 'USD', '1.25'),
    row(d2, 'EUR', '1'),
  ];

  group('rate', () {
    test('cross rate on the exact date', () async {
      final source = MemoryRates(cache);
      final r = found(await FxService(source).rate('INR', 'USD', d2));
      expect(r.from, 'INR');
      expect(r.to, 'USD');
      expect(r.rate, '0.0125000000');
      expect(r.effectiveDate, d2);
      expect(r.source, FxSource.frankfurter);
      expect(r.source.code, 'frankfurter');
      expect(r.isFallback, isFalse);
      expect(source.calls.single.$1, {'INR', 'USD'});
      expect(source.calls.single.$2, d2);
    });

    test('EUR needs no row and counts as 1', () async {
      final service = FxService(MemoryRates(cache));
      expect(found(await service.rate('EUR', 'INR', d2)).rate, '100.0000000000');
      expect(found(await service.rate('INR', 'EUR', d2)).rate, '0.0100000000');
    });

    // TC-32-05
    test('missing date falls back to the most recent earlier one', () async {
      final r = found(await FxService(MemoryRates(cache)).rate('USD', 'INR', d3));
      expect(r.rate, '80.0000000000');
      expect(r.effectiveDate, d2);
      expect(r.isFallback, isTrue);
    });

    test('both rates come from one shared date', () async {
      final rows = [row(d1, 'INR', '98'), row(d1, 'USD', '1.2'), row(d2, 'INR', '100')];
      final r = found(await FxService(MemoryRates(rows)).rate('USD', 'INR', d3));
      expect(r.rate, '81.6666666667');
      expect(r.effectiveDate, d1);
      expect(r.isFallback, isTrue);
    });

    test('ignores rows after the date or of other currencies', () async {
      final rows = [...cache, row(d3, 'INR', '200'), row(d3, 'USD', '1'), row(d2, 'GBP', '0.9')];
      final r = found(await FxService(RawRates(rows)).rate('INR', 'USD', d2));
      expect(r.rate, '0.0125000000');
      expect(r.effectiveDate, d2);
    });

    test('unlisted or unknown currency asks for a manual rate without reading the cache', () async {
      final source = MemoryRates(cache);
      final m = manual(await FxService(source).rate('VED', 'XYZ', d2));
      expect(m.from, 'VED');
      expect(m.to, 'XYZ');
      expect(m.date, d2);
      expect(m.reason, FxMissingReason.unlistedCurrency);
      expect(m.currencies, ['VED', 'XYZ']);
      expect(() => m.currencies.add('X'), throwsUnsupportedError);
      expect(source.calls, isEmpty);
      expect(manual(await FxService(source).rate('INR', 'VED', d2)).currencies, ['VED']);
    });

    test('empty cache or a date before it asks for a manual rate', () async {
      final empty = manual(await FxService(MemoryRates([])).rate('INR', 'USD', d2));
      expect(empty.reason, FxMissingReason.noRates);
      expect(empty.currencies, ['INR', 'USD']);
      final early = manual(
        await FxService(MemoryRates(cache)).rate('INR', 'USD', DateTime.utc(2026)),
      );
      expect(early.reason, FxMissingReason.noRates);
      expect(early.currencies, ['INR', 'USD']);
    });

    test('names the currency without cached rates', () async {
      final m = manual(
        await FxService(MemoryRates([row(d2, 'INR', '100')])).rate('INR', 'USD', d2),
      );
      expect(m.reason, FxMissingReason.noRates);
      expect(m.currencies, ['USD']);
    });

    test('no shared date names both currencies', () async {
      final rows = [row(d1, 'INR', '98'), row(d2, 'USD', '1.25')];
      final m = manual(await FxService(MemoryRates(rows)).rate('INR', 'USD', d2));
      expect(m.reason, FxMissingReason.noRates);
      expect(m.currencies, ['INR', 'USD']);
    });

    test('bad cached rate throws InvalidRate', () async {
      final service = FxService(MemoryRates([row(d2, 'INR', '0')]));
      await expectLater(service.rate('EUR', 'INR', d2), throwsA(isA<InvalidRate>()));
    });

    test('same currency or a non-date throws', () async {
      final service = FxService(MemoryRates(cache));
      await expectLater(service.rate('INR', 'INR', d2), throwsArgumentError);
      await expectLater(
        service.rate('INR', 'USD', DateTime(2026, 11, 20)),
        throwsA(isA<NotADate>()),
      );
    });
  });

  group('manualRate', () {
    const service = FxService(_NoRates());

    test('valid rate is kept as canonical decimal text', () {
      final r = service.manualRate('USD', 'INR', d3, ' 89.50 ');
      expect(r.from, 'USD');
      expect(r.to, 'INR');
      expect(r.rate, '89.5');
      expect(r.effectiveDate, d3);
      expect(r.source, FxSource.manual);
      expect(r.source.code, 'manual');
      expect(r.isFallback, isFalse);
      expect(service.manualRate('INR', 'USD', d3, '0.0000000001').rate, '0.0000000001');
      expect(service.manualRate('VED', 'INR', d3, '12').rate, '12');
    });

    test('invalid rate throws InvalidRate', () {
      for (final bad in ['', '0', '-1', 'abc', '1.00000000001']) {
        expect(
          () => service.manualRate('USD', 'INR', d3, bad),
          throwsA(isA<InvalidRate>()),
          reason: bad,
        );
      }
    });

    test('same currency or a non-date throws', () {
      expect(() => service.manualRate('INR', 'INR', d3, '1'), throwsArgumentError);
      expect(
        () => service.manualRate('USD', 'INR', DateTime.utc(2026, 11, 21, 5), '1'),
        throwsA(isA<NotADate>()),
      );
    });
  });
}

final class _NoRates implements RatesSource {
  const _NoRates();

  @override
  Future<List<EurRate>> ratesOnOrBefore(Set<String> currencies, DateTime date) =>
      throw StateError('manualRate must not read the cache');
}
