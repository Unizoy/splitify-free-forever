import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/currency/domain/converted_balances.dart';

FxRecord _inrExpense(String id, int total, {String date = '2026-11-10'}) => FxRecord.expense(
  id: id,
  date: date,
  currency: 'INR',
  amount: total,
  paid: {'a': total},
  shares: {'a': total ~/ 2, 'b': total - total ~/ 2},
);

FxRecord _usdExpense(String id, String date, {bool converted = true, String fx = 'INR'}) =>
    FxRecord.expense(
      id: id,
      date: date,
      currency: 'USD',
      amount: 1000,
      paid: {'b': 1000},
      shares: {'a': 500, 'b': 500},
      fxCurrency: converted ? fx : null,
      fxAmount: converted ? 83500 : null,
      fxPaid: converted ? {'b': 83500} : null,
      fxShares: converted ? {'a': 41750, 'b': 41750} : null,
    );

void main() {
  test('native main-currency records count as they are', () {
    final r = convertedBalances('INR', ['a', 'b'], [_inrExpense('e1', 10000)]);
    expect(r.complete, isTrue);
    expect(r.missing, isEmpty);
    expect(r.currency, 'INR');
    expect(r.balances!.nets, {'a': 5000, 'b': -5000});
  });

  test('foreign records without a conversion are listed newest first, no balances', () {
    final r = convertedBalances(
      'INR',
      ['a', 'b'],
      [
        _inrExpense('e1', 10000),
        _usdExpense('old', '2026-11-01', converted: false),
        _usdExpense('new', '2026-11-19', converted: false),
        const FxRecord.payment(
          id: 'p1',
          date: '2026-11-12',
          currency: 'EUR',
          amount: 500,
          from: 'a',
          to: 'b',
        ),
      ],
    );
    expect([for (final m in r.missing) m.id], ['new', 'p1', 'old']);
    expect(r.balances, isNull);
    expect(r.complete, isFalse);
  });

  test('a conversion to a different currency than main does not count', () {
    final r = convertedBalances('INR', ['a', 'b'], [_usdExpense('e', '2026-11-01', fx: 'EUR')]);
    expect([for (final m in r.missing) m.id], ['e']);
  });

  test('an expense conversion without parts does not count', () {
    const e = FxRecord.expense(
      id: 'e',
      date: '2026-11-01',
      currency: 'USD',
      amount: 1000,
      paid: {'a': 1000},
      shares: {'a': 1000},
      fxCurrency: 'INR',
      fxAmount: 83500,
    );
    expect(e.countsIn('INR'), isFalse);
    expect(e.isPayment, isFalse);
  });

  test('foreign records count through their saved conversion; payments too', () {
    final r = convertedBalances(
      'INR',
      ['a', 'b'],
      [
        _inrExpense('e1', 10000),
        _usdExpense('e2', '2026-11-18'),
        const FxRecord.payment(
          id: 'p1',
          date: '2026-11-19',
          currency: 'USD',
          amount: 100,
          from: 'a',
          to: 'b',
          fxCurrency: 'INR',
          fxAmount: 8350,
        ),
        const FxRecord.payment(
          id: 'p2',
          date: '2026-11-19',
          currency: 'INR',
          amount: 1000,
          from: 'b',
          to: 'b',
        ),
      ],
    );
    expect(r.complete, isTrue);
    // e1: a +5000, b -5000. e2 (converted): b paid 83500, owes 41750 -> b +41750, a -41750.
    // p1: a pays b 8350 -> a +8350, b -8350. p2 (same person) is ignored.
    expect(r.balances!.nets, {'a': 5000 - 41750 + 8350, 'b': -5000 + 41750 - 8350});
  });

  // TC-17-04
  test('simplify runs on the converted nets', () {
    final r = convertedBalances(
      'INR',
      ['a', 'b', 'c'],
      [
        const FxRecord.expense(
          id: 'e1',
          date: '2026-11-10',
          currency: 'INR',
          amount: 9000,
          paid: {'a': 9000},
          shares: {'a': 3000, 'b': 3000, 'c': 3000},
        ),
        const FxRecord.expense(
          id: 'e2',
          date: '2026-11-11',
          currency: 'USD',
          amount: 100,
          paid: {'b': 100},
          shares: {'a': 50, 'c': 50},
          fxCurrency: 'INR',
          fxAmount: 8000,
          fxPaid: {'b': 8000},
          fxShares: {'a': 4000, 'c': 4000},
        ),
      ],
    );
    expect(r.complete, isTrue);
    // a: +9000-3000-4000 = 2000; b: -3000+8000 = 5000; c: -3000-4000 = -7000.
    expect(r.balances!.nets, {'a': 2000, 'b': 5000, 'c': -7000});
    final transfers = r.balances!.simplified;
    expect(transfers.fold(0, (s, t) => s + t.amount), 7000);
    expect(transfers.every((t) => t.from == 'c'), isTrue);
    expect(transfers.length, 2);
  });

  test('unknown member ids are appended to the order', () {
    final r = convertedBalances('INR', ['a'], [_inrExpense('e1', 10000)]);
    expect(r.complete, isTrue);
    expect(r.balances!.nets.keys, containsAll(['a', 'b']));
  });

  test('records that cannot be combined give no balances but nothing missing', () {
    final r = convertedBalances(
      'INR',
      ['a'],
      [
        const FxRecord.expense(
          id: 'bad',
          date: '2026-11-01',
          currency: 'INR',
          amount: 100,
          paid: {'a': 100},
          shares: {'a': -50},
        ),
      ],
    );
    expect(r.missing, isEmpty);
    expect(r.balances, isNull);
    expect(r.complete, isFalse);
  });
}
