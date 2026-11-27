// TC-D34D-04 (D-034 WP-D, F13): the month navigator's maths and a group's totals for any month.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/insights/application/totals_months.dart';
import 'package:splitify/features/insights/domain/month_period.dart';

void main() {
  group('addMonths', () {
    // TC-D34D-04
    test('steps across years both ways', () {
      expect(addMonths('2026-11', 1), '2026-12');
      expect(addMonths('2026-12', 1), '2027-01');
      expect(addMonths('2026-01', -1), '2025-12');
      expect(addMonths('2026-03', -14), '2025-01');
      expect(addMonths('2026-03', 0), '2026-03');
      expect(addMonths('0999-12', 1), '1000-01');
    });

    // TC-D34D-04
    test('12 steps forward then back is the same month', () {
      for (var m = 1; m <= 12; m++) {
        final key = '2026-${m.toString().padLeft(2, '0')}';
        expect(addMonths(addMonths(key, 12), -12), key);
        expect(addMonths(key, 12).substring(0, 4), '2027');
      }
    });
  });

  group('MonthRange', () {
    // TC-D34D-04
    test('spans the months with spending and always this month', () {
      final r = MonthRange.of(['2026-08', '2026-03', '2026-10'], '2026-11');
      expect((r.first, r.last), ('2026-03', '2026-11'));
      expect(r.canGoBack('2026-03'), isFalse);
      expect(r.canGoBack('2026-04'), isTrue);
      expect(r.canGoForward('2026-11'), isFalse);
      expect(r.canGoForward('2026-10'), isTrue);
      expect(r.clamp('2025-01'), '2026-03');
      expect(r.clamp('2027-01'), '2026-11');
      expect(r.clamp('2026-06'), '2026-06');
    });

    // TC-D34D-04
    test('a future-dated expense extends it; nothing at all is just this month', () {
      final r = MonthRange.of(['2027-02'], '2026-11');
      expect((r.first, r.last), ('2026-11', '2027-02'));
      final none = MonthRange.of(const [], '2026-11');
      expect(none.canGoBack('2026-11'), isFalse);
      expect(none.canGoForward('2026-11'), isFalse);
    });
  });

  group('TotalsMonths', () {
    const inputs = [
      TotalsExpense(
        currency: 'INR',
        total: 30000,
        date: '2026-11-03',
        paid: {'a': 30000},
        shares: {'a': 15000, 'b': 15000},
      ),
      TotalsExpense(
        currency: 'USD',
        total: 1000,
        date: '2026-11-04',
        paid: {'b': 1000},
        shares: {'a': 500, 'b': 500},
      ),
      TotalsExpense(currency: 'INR', total: 70000, date: '2026-09-30', paid: {'b': 70000}),
      TotalsExpense(currency: 'INR', total: 999, date: '2026-06-01', kind: 'iou'),
    ];

    // TC-D34D-04
    test('lists months with spending (loans are not) and totals each one per currency', () {
      final m = TotalsMonths(inputs);
      expect(m.months, ['2026-09', '2026-11']);
      final nov = m.of('2026-11');
      expect(nov.keys, ['INR', 'USD']);
      expect(nov['INR']!.spent, 30000);
      expect(nov['INR']!.paid, {'a': 30000});
      expect(nov['USD']!.shares, {'a': 500, 'b': 500});
      expect(m.of('2026-09')['INR']!.spent, 70000);
      expect(m.of('2026-10'), isEmpty);
      expect(m.of('2026-06'), isEmpty);
      // The same numbers as the group totals of that month.
      expect(m.of('2026-11')['INR']!.count, groupTotals(inputs, month: '2026-11')['INR']!.count);
      expect(identical(m.of('2026-11'), m.of('2026-11')), isTrue);
    });
  });
}
