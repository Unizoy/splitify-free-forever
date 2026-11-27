// TC-D34D-03 (D-034 WP-D, P-6): "Category over time" and "Who paid": buckets and months, main currency
// with saved conversions only, loans left out, fixed member order, and the numbers matching the Totals
// tab for the same month.
import 'dart:math';

import 'package:glados/glados.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/balances/application/totals_providers.dart' show totalsInputs;
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/domain/aggregations.dart';

import '../../../support/ledger_seed.dart';

InsightExpense _e(
  String date,
  int total, {
  String category = 'food.dining_out',
  String currency = 'INR',
  Map<String, int>? paid,
  Map<String, int>? owed,
  String kind = 'expense',
  String? fxCurrency,
  int? fxTotal,
  Map<String, int>? fxPaid,
  Map<String, int>? fxOwed,
  bool deleted = false,
}) => InsightExpense(
  id: '$date-$total',
  category: category,
  date: date,
  currency: currency,
  total: total,
  kind: kind,
  paid: paid ?? {'a': total},
  owed: owed ?? {'a': total ~/ 2, 'b': total - total ~/ 2},
  fxCurrency: fxCurrency,
  fxTotal: fxTotal,
  fxPaid: fxPaid,
  fxOwed: fxOwed,
  deleted: deleted,
);

void main() {
  group('categoryTrends', () {
    final expenses = [
      _e('2026-11-03', 30000),
      _e('2026-11-20', 5000, category: 'food.snacks'),
      _e('2026-10-01', 70000, category: 'travel.hotel'),
      _e('2025-11-30', 99900),
      _e('2026-09-09', 4000, kind: 'iou'),
      _e('2026-09-10', 6000, deleted: true),
      _e(
        '2026-08-08',
        1000,
        currency: 'USD',
        fxCurrency: 'INR',
        fxTotal: 84000,
        fxOwed: {'a': 84000},
      ),
      _e('2026-08-09', 2000, currency: 'EUR'),
    ];

    // TC-D34D-03
    test('one 12-month series per parent category, oldest first, zeros kept', () {
      final t = categoryTrends(
        expenses,
        const GroupScope(),
        'INR',
        categoryOf: ExpenseCategories.parentOf,
        year: 2026,
        month: 11,
      );
      expect(t.keys, ['food', 'travel']);
      final food = t['food']!;
      expect(food, hasLength(12));
      expect(food.first.month, '2025-12');
      expect(food.last, const MonthSpend('2026-11', 35000));
      expect(food.where((m) => m.month == '2026-08').single.minor, 84000);
      // November 2025 is outside the window.
      expect(food.fold(0, (s, m) => s + m.minor), 35000 + 84000);
      expect(t['travel']!.where((m) => m.minor > 0).single, const MonthSpend('2026-10', 70000));
    });

    // TC-D34D-03
    test('a month\'s categories add up to the month bar (same left-out rules)', () {
      final t = categoryTrends(
        expenses,
        const GroupScope(),
        'INR',
        categoryOf: ExpenseCategories.parentOf,
        year: 2026,
        month: 11,
      );
      final bars = spendingInMainCurrency(
        expenses,
        const GroupScope(),
        'INR',
      ).summary.lastMonths(year: 2026, month: 11);
      for (var i = 0; i < 12; i++) {
        final sum = t.values.fold(0, (s, series) => s + series[i].minor);
        expect(sum, bars[i].minor, reason: bars[i].month);
      }
    });

    // TC-D34D-03
    test('Me counts only my shares', () {
      final t = categoryTrends(
        expenses,
        const MeScope({'b'}),
        'INR',
        categoryOf: ExpenseCategories.parentOf,
        year: 2026,
        month: 11,
      );
      expect(t['food']!.last.minor, 15000 + 2500);
      // My converted share is not saved for the USD expense: left out.
      expect(t['food']!.where((m) => m.month == '2026-08').single.minor, 0);
    });
  });

  group('paidShareMonths', () {
    // TC-D34D-03
    test('fixed member order, strangers after (sorted), people with nothing left out', () {
      final rows = paidShareMonths(
        [
          _e('2026-11-03', 30000, paid: {'b': 30000}, owed: {'a': 10000, 'b': 10000, 'z': 10000}),
          _e('2026-10-03', 9000, paid: {'a': 9000, 'y': 0}, owed: {'a': 4500, 'b': 4500}),
        ],
        'INR',
        order: const ['a', 'b', 'c'],
        year: 2026,
        month: 11,
      );
      expect(rows.map((r) => r.memberId), ['a', 'b', 'z']);
      final a = rows.first;
      expect(a.months, hasLength(12));
      expect(a.months.last, const PaidShareMonth('2026-11', 0, 10000));
      expect(a.months[10], const PaidShareMonth('2026-10', 9000, 4500));
      expect((a.paid, a.share), (9000, 14500));
      expect((rows[1].paid, rows[1].share), (30000, 14500));
    });

    // TC-D34D-03
    test(
      'main currency, saved conversions with both parts, no loans or deleted, in the window',
      () {
        final rows = paidShareMonths(
          [
            _e('2026-11-01', 1000),
            _e(
              '2026-11-02',
              100,
              currency: 'USD',
              fxCurrency: 'INR',
              fxTotal: 8400,
              fxPaid: {'a': 8400},
              fxOwed: {'a': 4200, 'b': 4200},
            ),
            // Converted total but no converted parts: left out.
            _e('2026-11-03', 100, currency: 'USD', fxCurrency: 'INR', fxTotal: 8400),
            _e('2026-11-04', 100, currency: 'EUR'),
            _e('2026-11-05', 700, kind: 'iou'),
            _e('2026-11-06', 800, deleted: true),
            _e('2025-11-30', 5000),
          ],
          'INR',
          order: const ['a', 'b'],
          year: 2026,
          month: 11,
        );
        expect(rows.first.months.last, const PaidShareMonth('2026-11', 9400, 4700));
        expect(rows[1].months.last, const PaidShareMonth('2026-11', 0, 4700));
        expect(rows.first.paid, 9400, reason: 'November 2025 is outside the window');
      },
    );

    // TC-D34D-03
    test('nothing to show: no rows', () {
      expect(paidShareMonths(const [], 'INR', order: const ['a'], year: 2026, month: 1), isEmpty);
    });
  });

  group('trend numbers match the Totals tab', () {
    GroupLedger ledger(Random r) {
      const ids = ['m1', 'm2', 'm3'];
      final members = [
        seedMember('m1', name: 'Mohit', userId: 'u1'),
        seedMember('m2', name: 'Asha', position: 1),
        seedMember('m3', name: 'Ravi', position: 2),
      ];
      final expenses = [
        for (var i = 0; i < 1 + r.nextInt(25); i++)
          () {
            final total = 1 + r.nextInt(500000);
            final payer = ids[r.nextInt(3)];
            final among = ids.where((_) => r.nextBool()).toList();
            final people = among.isEmpty ? [payer] : among;
            final base = total ~/ people.length;
            final shares = {for (final p in people) p: base};
            shares[people.first] = base + total - base * people.length;
            return seedExpense(
              'e$i',
              date: '2026-${(1 + r.nextInt(11)).toString().padLeft(2, '0')}-1${r.nextInt(9)}',
              total: total,
              kind: r.nextInt(8) == 0 ? 'iou' : 'expense',
              payers: {payer: total},
              shares: shares,
            ).copyWith(category: ['food.snacks', 'travel.hotel', 'rent.rent'][r.nextInt(3)]);
          }(),
      ];
      return GroupLedger(
        group: seedGroup(),
        members: members,
        expenses: expenses,
        payments: const [],
      );
    }

    // TC-D34D-03: property over random INR groups.
    Glados(any.positiveIntOrZero, ExploreConfig(numRuns: 200)).test(
      'for every month: Σ categories = spent, each person paid / share = Totals',
      (seed) {
        final l = ledger(Random(seed));
        final v = insightsViewOf(
          [l],
          (mode: InsightsMode.group, groupId: 'g1'),
          userId: 'u1',
          defaultCurrency: 'INR',
          today: DateTime(2026, 11, 22),
        );
        final inputs = totalsInputs(l);
        for (var i = 0; i < 12; i++) {
          final month = v.months[i].month;
          final totals = groupTotals(inputs, month: month)['INR'];
          final spent = v.categoryTrends.values.fold(0, (s, series) => s + series[i].minor);
          expect(spent, totals?.spent ?? 0, reason: month);
          expect(v.months[i].minor, totals?.spent ?? 0, reason: month);
          for (final t in v.whoPaid) {
            expect(t.months[i].paid, totals?.paid[t.memberId] ?? 0, reason: '$month ${t.memberId}');
            expect(
              t.months[i].share,
              totals?.shares[t.memberId] ?? 0,
              reason: '$month ${t.memberId}',
            );
          }
        }
        expect(v.meMemberId, 'm1');
        expect(v.memberNames['m2'], 'Asha');
      },
    );

    // TC-D34D-03
    test('Me mode has no "Who paid"', () {
      final v = insightsViewOf(
        [ledger(Random(1))],
        (mode: InsightsMode.me, groupId: null),
        userId: 'u1',
        defaultCurrency: 'INR',
        today: DateTime(2026, 11, 22),
      );
      expect(v.whoPaid, isEmpty);
      expect(v.meMemberId, isNull);
    });
  });
}
