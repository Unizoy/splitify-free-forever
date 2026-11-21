import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/balances/domain/group_totals.dart';

void main() {
  const dinner = TotalsExpense(
    currency: 'INR',
    total: 30000,
    date: '2026-11-05',
    paid: {'a': 30000},
    shares: {'a': 10000, 'b': 10000, 'c': 10000},
  );
  const loan = TotalsExpense(
    currency: 'INR',
    total: 50000,
    date: '2026-11-06',
    kind: 'iou',
    paid: {'a': 50000},
    shares: {'b': 50000},
  );

  group('groupTotals', () {
    // TC-21-01
    test('TC-21-01 totals exclude IOUs (payments are never passed in)', () {
      final t = groupTotals([dinner, loan]);
      expect(t.keys, ['INR']);
      expect(t['INR']!.spent, 30000);
      expect(t['INR']!.count, 1);
      expect(t['INR']!.paid, {'a': 30000});
      expect(t['INR']!.shares, {'a': 10000, 'b': 10000, 'c': 10000});
      expect(loan.isSpending, isFalse);
      expect(dinner.isSpending, isTrue);
    });

    // TC-21-01
    test('TC-21-01 a group with only IOUs has no totals', () {
      expect(groupTotals([loan]), isEmpty);
      expect(groupTotals(const []), isEmpty);
    });

    test('currencies are never added together and come out alphabetical', () {
      const usd = TotalsExpense(
        currency: 'USD',
        total: 1000,
        date: '2026-11-07',
        paid: {'a': 1000},
        shares: {'b': 1000},
      );
      final t = groupTotals([usd, dinner]);
      expect(t.keys, ['INR', 'USD']);
      expect(t['INR']!.spent, 30000);
      expect(t['USD']!.spent, 1000);
    });

    test('sums several expenses per member and leaves zero parts out', () {
      const second = TotalsExpense(
        currency: 'INR',
        total: 20000,
        date: '2026-11-09',
        paid: {'b': 20000, 'c': 0},
        shares: {'a': 10000, 'b': 10000, 'c': 0},
      );
      final t = groupTotals([dinner, second])['INR']!;
      expect(t.spent, 50000);
      expect(t.count, 2);
      expect(t.paid, {'a': 30000, 'b': 20000});
      expect(t.shares, {'a': 20000, 'b': 20000, 'c': 10000});
      expect(() => t.paid['z'] = 1, throwsUnsupportedError);
    });

    test('the month filter keeps only expenses dated in that month', () {
      const october = TotalsExpense(
        currency: 'INR',
        total: 7000,
        date: '2026-10-31',
        paid: {'a': 7000},
        shares: {'a': 7000},
      );
      final all = groupTotals([dinner, october]);
      final nov = groupTotals([dinner, october], month: '2026-11');
      final oct = groupTotals([dinner, october], month: '2026-10');
      expect(all['INR']!.spent, 37000);
      expect(nov['INR']!.spent, 30000);
      expect(oct['INR']!.spent, 7000);
      expect(groupTotals([dinner], month: '2025-01'), isEmpty);
    });
  });

  test('monthKeyOf pads year and month', () {
    expect(monthKeyOf(DateTime(2026, 11, 22)), '2026-11');
    expect(monthKeyOf(DateTime(2026, 3, 1)), '2026-03');
    expect(monthKeyOf(DateTime(987, 1, 1)), '0987-01');
  });
}
