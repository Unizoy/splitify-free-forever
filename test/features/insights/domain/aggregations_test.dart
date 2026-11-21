import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/insights/domain/aggregations.dart';

InsightExpense _e(
  String id, {
  String category = 'food.dining',
  String date = '2026-10-05',
  String currency = 'INR',
  int total = 30000,
  Map<String, int> owed = const {'me': 10000, 'a': 10000, 'b': 10000},
  String kind = 'expense',
  bool deleted = false,
  String? fxCurrency,
  int? fxTotal,
  Map<String, int>? fxOwed,
}) => InsightExpense(
  id: id,
  category: category,
  date: date,
  currency: currency,
  total: total,
  owed: owed,
  kind: kind,
  deleted: deleted,
  fxCurrency: fxCurrency,
  fxTotal: fxTotal,
  fxOwed: fxOwed,
);

void main() {
  group('TC-33-01 spendingPerCurrency', () {
    final expenses = [
      _e('1'),
      _e(
        '2',
        category: 'travel.taxi',
        date: '2026-11-02',
        total: 50000,
        owed: {'me': 0, 'a': 50000},
      ),
      _e(
        '3',
        category: 'travel.taxi',
        date: '2026-11-20',
        total: 70000,
        owed: {'me': 35000, 'b': 35000},
      ),
      _e('4', currency: 'USD', total: 1000, owed: {'me': 500, 'a': 500}),
      _e('iou', kind: expenseKindIou, total: 99900),
      _e('del', deleted: true, total: 88800),
    ];

    test('group scope: per currency, IOU and deleted excluded', () {
      final r = spendingPerCurrency(expenses, const GroupScope());
      expect(r.keys, ['INR', 'USD']);
      final inr = r['INR']!;
      expect(inr.currency, 'INR');
      expect(inr.total, 150000);
      expect(inr.count, 3);
      expect(inr.byCategory, const [
        CategorySpend('travel.taxi', 120000),
        CategorySpend('food.dining', 30000),
      ]);
      expect(inr.byMonth, const [MonthSpend('2026-10', 30000), MonthSpend('2026-11', 120000)]);
      expect(r['USD']!.total, 1000);
    });

    test('me scope: only my shares, zero shares skipped', () {
      final r = spendingPerCurrency(expenses, const MeScope({'me'}));
      final inr = r['INR']!;
      expect(inr.total, 45000);
      expect(inr.count, 2);
      expect(inr.byMonth, const [MonthSpend('2026-10', 10000), MonthSpend('2026-11', 35000)]);
      expect(r['USD']!.total, 500);
    });

    test('me scope sums my member ids across groups; nothing when not in it', () {
      final r = spendingPerCurrency([
        _e('g1', owed: {'me1': 100}),
        _e('g2', owed: {'me2': 200}),
      ], const MeScope({'me1', 'me2'}));
      expect(r['INR']!.total, 300);
      expect(spendingPerCurrency(expenses, const MeScope({'nobody'})), isEmpty);
    });

    test('categoryOf buckets keys; ties sorted by key', () {
      final r = spendingPerCurrency(
        [
          _e('1', category: 'food.b', total: 5),
          _e('2', category: 'food.a', total: 5),
          _e('3', category: 'home.x', total: 5),
        ],
        const GroupScope(),
        categoryOf: (c) => c.split('.').first,
      );
      expect(r['INR']!.byCategory, const [CategorySpend('food', 10), CategorySpend('home', 5)]);
      final tie = spendingPerCurrency([
        _e('1', category: 'z', total: 5),
        _e('2', category: 'a', total: 5),
      ], const GroupScope());
      expect(tie['INR']!.byCategory.map((c) => c.category), ['a', 'z']);
    });

    test('lastMonths fills zeros across a year boundary', () {
      final inr = spendingPerCurrency([
        _e('1', date: '2025-12-31', total: 7),
        _e('2', date: '2026-02-01', total: 9),
      ], const GroupScope())['INR']!;
      expect(inr.lastMonths(year: 2026, month: 2, count: 4), const [
        MonthSpend('2025-11', 0),
        MonthSpend('2025-12', 7),
        MonthSpend('2026-01', 0),
        MonthSpend('2026-02', 9),
      ]);
      expect(inr.lastMonths(year: 2026, month: 2), hasLength(12));
      expect(inr.lastMonths(year: 2026, month: 2).first.month, '2025-03');
    });

    test('monthKey pads', () {
      expect(monthKey(987, 3), '0987-03');
    });
  });

  group('TC-33-01 spendingInMainCurrency', () {
    final expenses = [
      _e('inr', total: 1000, owed: {'me': 400, 'a': 600}),
      _e(
        'usd-fx',
        currency: 'USD',
        total: 100,
        owed: {'me': 50, 'a': 50},
        fxCurrency: 'INR',
        fxTotal: 8400,
        fxOwed: {'me': 4200, 'a': 4200},
      ),
      _e(
        'usd-fx-no-parts',
        currency: 'USD',
        total: 10,
        owed: {'me': 5, 'a': 5},
        fxCurrency: 'INR',
        fxTotal: 840,
      ),
      _e(
        'eur-to-usd',
        currency: 'EUR',
        total: 10,
        owed: {'me': 10},
        fxCurrency: 'USD',
        fxTotal: 11,
      ),
      _e('eur-none', currency: 'EUR', total: 20, owed: {'a': 20}),
      _e('iou', kind: expenseKindIou, currency: 'EUR', total: 20),
      _e('del', deleted: true, currency: 'EUR', total: 20),
    ];

    test('group scope uses saved totals and counts the rest', () {
      final r = spendingInMainCurrency(expenses, const GroupScope(), 'INR');
      expect(r.summary.currency, 'INR');
      expect(r.summary.total, 1000 + 8400 + 840);
      expect(r.summary.count, 3);
      expect(r.unconvertedCount, 2);
    });

    test('me scope uses saved parts; no parts or other target counts as unconverted', () {
      final r = spendingInMainCurrency(expenses, const MeScope({'me'}), 'INR');
      expect(r.summary.total, 400 + 4200);
      expect(r.summary.count, 2);
      // usd-fx-no-parts and eur-to-usd involve me; eur-none does not.
      expect(r.unconvertedCount, 2);
    });

    test('zero converted share is skipped, not counted', () {
      final r = spendingInMainCurrency(
        [
          _e(
            'x',
            currency: 'USD',
            owed: {'a': 10},
            fxCurrency: 'INR',
            fxTotal: 840,
            fxOwed: {'a': 840},
          ),
        ],
        const MeScope({'me'}),
        'INR',
      );
      expect(r.summary.count, 0);
      expect(r.unconvertedCount, 0);
      expect(r.summary.byCategory, isEmpty);
    });
  });

  test('value types: equality, hash, toString', () {
    expect(const CategorySpend('a', 1), const CategorySpend('a', 1));
    expect(const CategorySpend('a', 1).hashCode, const CategorySpend('a', 1).hashCode);
    expect(const CategorySpend('a', 1) == const CategorySpend('a', 2), isFalse);
    expect(const CategorySpend('a', 1).toString(), 'CategorySpend(a, 1)');
    expect(const MonthSpend('2026-01', 1), const MonthSpend('2026-01', 1));
    expect(const MonthSpend('2026-01', 1).hashCode, const MonthSpend('2026-01', 1).hashCode);
    expect(const MonthSpend('2026-01', 1) == const MonthSpend('2026-02', 1), isFalse);
    expect(const MonthSpend('2026-01', 1).toString(), 'MonthSpend(2026-01, 1)');
    expect(_e('x').monthKey, '2026-10');
    expect(_e('x').isSpending, isTrue);
  });
}
