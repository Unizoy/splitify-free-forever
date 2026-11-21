import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/fx.dart';
import 'package:splitify/core/money/money_error.dart';
import 'package:splitify/features/currency/domain/conversion.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';

int _sum(Object? m) => (m! as Map<String, int>).values.fold(0, (a, b) => a + b);

FxRate _rate({
  String from = 'USD',
  String to = 'INR',
  String rate = '83.5',
  FxSource source = FxSource.frankfurter,
}) => FxRate(
  from: from,
  to: to,
  rate: rate,
  effectiveDate: DateTime.utc(2026, 11, 18),
  source: source,
  isFallback: false,
);

SavedFx _saved({String currency = 'INR', String rate = '83.5'}) => SavedFx(
  rate: rate,
  rateDate: DateTime.utc(2026, 11, 18),
  source: FxSource.frankfurter,
  currency: currency,
  total: 83500,
);

void main() {
  group('SavedFx.tryRead', () {
    SavedFx? read({
      String? rate = '83.5',
      String? rateDate = '2026-11-18',
      String? source = 'frankfurter',
      String? currency = 'INR',
      int? total = 83500,
    }) => SavedFx.tryRead(
      rate: rate,
      rateDate: rateDate,
      source: source,
      currency: currency,
      total: total,
    );

    test('reads a full conversion (trims the code, keeps a timestamp date)', () {
      final s = read(rateDate: '2026-11-18T00:00:00Z', currency: 'INR ')!;
      expect(s.rate, '83.5');
      expect(s.rateDate, DateTime.utc(2026, 11, 18));
      expect(s.source, FxSource.frankfurter);
      expect(s.currency, 'INR');
      expect(s.total, 83500);
    });

    test('manual source is kept, unknown falls back to frankfurter', () {
      expect(read(source: 'manual')!.source, FxSource.manual);
      expect(read(source: 'other')!.source, FxSource.frankfurter);
    });

    test('a half-saved conversion counts as none', () {
      expect(read(rate: null), isNull);
      expect(read(rateDate: null), isNull);
      expect(read(source: null), isNull);
      expect(read(currency: null), isNull);
      expect(read(total: null), isNull);
    });

    test('an unreadable rate or date counts as none', () {
      expect(read(rate: 'abc'), isNull);
      expect(read(rate: '0'), isNull);
      expect(read(rateDate: 'nope'), isNull);
    });

    test('asRate rebuilds an FxRate for the record currency', () {
      final r = _saved().asRate('USD');
      expect(r.from, 'USD');
      expect(r.to, 'INR');
      expect(r.rate, '83.5');
      expect(r.effectiveDate, DateTime.utc(2026, 11, 18));
      expect(r.isFallback, isFalse);
    });
  });

  group('fullOrder', () {
    test('appends unknown ids sorted, once, after the given order', () {
      expect(fullOrder(['b', 'a'], ['z', 'a', 'c', 'z']), ['b', 'a', 'c', 'z']);
      expect(fullOrder(const [], const []), isEmpty);
    });
  });

  group('expenseFxColumns', () {
    test('converts total and re-allocates parts so they still sum', () {
      final c = expenseFxColumns(
        total: 1000,
        paid: {'a': 1000},
        shares: {'a': 333, 'b': 333, 'c': 334},
        order: ['a', 'b', 'c'],
        rate: _rate(),
      );
      expect(c['fx_rate'], '83.5');
      expect(c['fx_rate_date'], '2026-11-18');
      expect(c['fx_source'], 'frankfurter');
      expect(c['fx_currency'], 'INR');
      expect(c['fx_total'], convert(1000, 'USD', 'INR', '83.5'));
      expect(c['fx_total'], 83500);
      expect(_sum(c['fx_payers']), 83500);
      expect(_sum(c['fx_shares']), 83500);
    });

    test('members missing from the order still get a place', () {
      final c = expenseFxColumns(
        total: 1000,
        paid: {'x': 1000},
        shares: {'y': 500, 'x': 500},
        order: const [],
        rate: _rate(source: FxSource.manual),
      );
      expect(c['fx_source'], 'manual');
      expect(_sum(c['fx_shares']), 83500);
    });

    test('throws the money error when the converted total is too large', () {
      expect(
        () => expenseFxColumns(
          total: 900000000000,
          paid: {'a': 900000000000},
          shares: {'a': 900000000000},
          order: ['a'],
          rate: _rate(rate: '1000'),
        ),
        throwsA(isA<MoneyError>()),
      );
    });
  });

  group('paymentFxColumns', () {
    test('converts the amount', () {
      final c = paymentFxColumns(amount: 1000, rate: _rate());
      expect(c, {
        'fx_rate': '83.5',
        'fx_rate_date': '2026-11-18',
        'fx_source': 'frankfurter',
        'fx_currency': 'INR',
        'fx_amount': 83500,
      });
    });

    test('throws when the converted amount is out of bounds', () {
      expect(
        () => paymentFxColumns(amount: 900000000000, rate: _rate(rate: '1000')),
        throwsA(isA<MoneyError>()),
      );
    });
  });

  group('expenseFxAfterEdit', () {
    Map<String, Object?> edit({
      SavedFx? saved,
      String oldCurrency = 'USD',
      String currency = 'USD',
      int total = 2000,
    }) => expenseFxAfterEdit(
      saved: saved,
      oldCurrency: oldCurrency,
      currency: currency,
      total: total,
      paid: {'a': total},
      shares: {'a': total ~/ 2, 'b': total - total ~/ 2},
      order: ['a', 'b'],
    );

    test('no saved conversion: nothing to write', () {
      expect(edit(), isEmpty);
    });

    test('same currency keeps the saved rate and re-converts the new amounts', () {
      final c = edit(saved: _saved());
      expect(c['fx_rate'], '83.5');
      expect(c['fx_total'], 167000);
      expect(_sum(c['fx_payers']), 167000);
      expect(_sum(c['fx_shares']), 167000);
    });

    test('a new currency or the target currency clears the conversion', () {
      expect(edit(saved: _saved(), currency: 'GBP'), clearedExpenseFx);
      expect(edit(saved: _saved(currency: 'USD')), clearedExpenseFx);
    });

    test('amounts that cannot be converted clear it', () {
      expect(edit(saved: _saved(rate: '1000'), total: 900000000000), clearedExpenseFx);
    });
  });

  group('paymentFxAfterEdit', () {
    Map<String, Object?> edit({SavedFx? saved, String currency = 'USD', int amount = 2000}) =>
        paymentFxAfterEdit(saved: saved, oldCurrency: 'USD', currency: currency, amount: amount);

    test('none, kept, cleared', () {
      expect(edit(), isEmpty);
      expect(edit(saved: _saved())['fx_amount'], 167000);
      expect(edit(saved: _saved(), currency: 'GBP'), clearedPaymentFx);
      expect(edit(saved: _saved(currency: 'USD')), clearedPaymentFx);
      expect(edit(saved: _saved(rate: '1000'), amount: 900000000000), clearedPaymentFx);
    });
  });

  test('cleared maps null every fx column', () {
    expect(clearedExpenseFx.values.every((v) => v == null), isTrue);
    expect(clearedExpenseFx.keys, containsAll(['fx_total', 'fx_payers', 'fx_shares']));
    expect(clearedPaymentFx.keys, contains('fx_amount'));
    expect(clearedPaymentFx.values.every((v) => v == null), isTrue);
  });
}
