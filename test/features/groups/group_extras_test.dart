// D-034 WP-C unit tests: the group page's lines (C1), the settled-history finder (C2), the Groups filter (C3)
// and the settle-up nudge schedule mirrored from 0026 (C4).
import 'package:glados/glados.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';

import '../../support/ledger_seed.dart';

GroupBalances _balances({
  required Map<String, List<ExpenseFlow>> flows,
  bool simplify = false,
  String? meId = 'm1',
  String main = 'INR',
}) {
  const order = ['m1', 'm2', 'm3', 'm4', 'm5'];
  return GroupBalances(
    groupId: 'g1',
    groupName: 'Goa trip',
    mainCurrency: main,
    members: [for (final (i, id) in order.indexed) seedMember(id, position: i, name: id)],
    byCurrency: balancesByCurrency(order, [for (final f in flows.values) ...f], const []),
    simplify: simplify,
    meId: meId,
    hasRecords: true,
  );
}

ExpenseFlow _flow(String currency, String payer, Map<String, int> shares) => ExpenseFlow(
  currency: currency,
  paid: {payer: shares.values.fold(0, (a, b) => a + b)},
  shares: shares,
);

LedgerEntry _e(String id, String date, Map<String, int> deltas, {String currency = 'INR'}) =>
    (id: id, date: date, createdAt: '${date}T10:00:00Z', currency: currency, deltas: deltas);

void main() {
  group('myBalanceLines (C1)', () {
    test('my lines only, in the Balances tab order, main currency first', () {
      final b = _balances(
        flows: {
          'a': [
            _flow('USD', 'm1', {'m1': 500, 'm3': 500}),
            _flow('INR', 'm1', {'m1': 10000, 'm2': 20000}),
            _flow('INR', 'm4', {'m4': 1000, 'm1': 5000, 'm5': 3000}),
          ],
        },
      );
      final lines = myBalanceLines(b);
      expect(lines.first.currency, 'INR');
      expect(lines.last, (currency: 'USD', other: 'm3', amount: 500, iOwe: false));
      expect(lines, contains((currency: 'INR', other: 'm2', amount: 20000, iOwe: false)));
      expect(lines, contains((currency: 'INR', other: 'm4', amount: 5000, iOwe: true)));
      // m5 owes m4: not mine.
      expect(lines.where((l) => l.other == 'm5'), isEmpty);
      // Exactly the tab's rows that involve me, in order.
      final tab = [
        for (final c in b.currencies)
          for (final t in b.shown(c))
            if (t.from == 'm1' || t.to == 'm1') (c, t.from == 'm1' ? t.to : t.from),
      ];
      expect([for (final l in lines) (l.currency, l.other)], tab);
    });

    test('follows simplify when it is on (rule 12: totals unchanged)', () {
      // m2 owes m1 300, m1 owes m3 300 -> simplified: m2 pays m3, nothing for me.
      final flows = {
        'a': [
          _flow('INR', 'm1', {'m2': 300}),
          _flow('INR', 'm3', {'m1': 300}),
        ],
      };
      expect(myBalanceLines(_balances(flows: flows)), hasLength(2));
      expect(myBalanceLines(_balances(flows: flows, simplify: true)), isEmpty);
    });

    test('nothing when I am not a member or everything is settled', () {
      final flows = {
        'a': [
          _flow('INR', 'm1', {'m2': 300}),
        ],
      };
      expect(myBalanceLines(_balances(flows: flows, meId: null)), isEmpty);
      expect(
        myBalanceLines(
          _balances(
            flows: {
              'a': [
                _flow('INR', 'm1', {'m1': 300}),
              ],
            },
          ),
        ),
        isEmpty,
      );
    });
  });

  group('settledHistoryIds (C2)', () {
    test('open balance: nothing folds', () {
      expect(
        settledHistoryIds([
          _e('e1', '2026-11-01', {'a': 100, 'b': -100}),
        ]),
        isEmpty,
      );
    });

    test('settled: everything up to the last settle-up folds, later no-ops stay', () {
      final ids = settledHistoryIds([
        _e('e1', '2026-11-01', {'a': 100, 'b': -100}),
        _e('p1', '2026-11-03', {'b': 100, 'a': -100}),
        _e('e2', '2026-11-05', {'a': 50, 'c': -50}),
        _e('p2', '2026-11-06', {'c': 50, 'a': -50}),
        // Asha paid for herself only: moves nothing.
        _e('e3', '2026-11-08', {'a': 0}),
      ]);
      expect(ids, {'e1', 'p1', 'e2', 'p2'});
    });

    test('date order, not list order; the same day goes by creation time, then id', () {
      final ids = settledHistoryIds([
        _e('p1', '2026-11-03', {'b': 100, 'a': -100}),
        _e('e1', '2026-11-01', {'a': 100, 'b': -100}),
        (id: 'late', date: '2026-11-03', createdAt: null, currency: 'INR', deltas: const {'x': 0}),
      ]);
      expect(ids, {'e1', 'p1'});
    });

    test('every currency must be settled (rule 4)', () {
      final entries = [
        _e('e1', '2026-11-01', {'a': 100, 'b': -100}),
        _e('p1', '2026-11-02', {'b': 100, 'a': -100}),
        _e('u1', '2026-11-03', {'a': 500, 'b': -500}, currency: 'USD'),
      ];
      expect(settledHistoryIds(entries), isEmpty);
      expect(
        settledHistoryIds([
          ...entries,
          _e('u2', '2026-11-04', {'b': 500, 'a': -500}, currency: 'USD'),
        ]),
        {'e1', 'p1', 'u1', 'u2'},
      );
    });

    test('a group that was never open folds nothing', () {
      expect(
        settledHistoryIds([
          _e('e1', '2026-11-01', {'a': 0}),
        ]),
        isEmpty,
      );
    });

    test('deltas: expenses paid − owed, payments to oneself or of nothing move nothing', () {
      expect(expenseDeltas({'a': 300}, {'a': 100, 'b': 200}), {'a': 200, 'b': -200});
      expect(paymentDeltas('b', 'a', 200), {'b': 200, 'a': -200});
      expect(paymentDeltas('a', 'a', 200), isEmpty);
      expect(paymentDeltas('a', 'b', 0), isEmpty);
    });

    Glados2(any.intInRange(1, 6), any.nonEmptyList(any.intInRange(1, 100000))).test(
      'property: settling every debt folds exactly the records before the payments and the payments',
      (people, amounts) {
        // Expenses paid by member 0 for member i, then each debt paid back: always settled at the end.
        final entries = <LedgerEntry>[];
        for (var i = 0; i < amounts.length; i++) {
          final debtor = 'm${1 + i % people}';
          entries.add(_e('e$i', '2026-10-01', {'m0': amounts[i], debtor: -amounts[i]}));
        }
        for (var i = 0; i < amounts.length; i++) {
          final debtor = 'm${1 + i % people}';
          entries.add(_e('p$i', '2026-11-01', {debtor: amounts[i], 'm0': -amounts[i]}));
        }
        final ids = settledHistoryIds(entries);
        expect(ids, {for (final e in entries) e.id});
        // Without the last payment the group is open again: nothing folds.
        expect(settledHistoryIds(entries.sublist(0, entries.length - 1)), isEmpty);
      },
    );
  });

  group('groupMatches (C3)', () {
    test('the four filters', () {
      const owe = {'INR': -200};
      const owed = {'INR': 300};
      const mixed = {'INR': -200, 'USD': 500};
      const settled = <String, int>{};
      for (final mine in [owe, owed, mixed, settled]) {
        expect(groupMatches(GroupFilter.all, mine), isTrue);
      }
      expect(
        [
          for (final m in [owe, owed, mixed, settled]) groupMatches(GroupFilter.outstanding, m),
        ],
        [true, true, true, false],
      );
      expect(
        [
          for (final m in [owe, owed, mixed, settled]) groupMatches(GroupFilter.iOwe, m),
        ],
        [true, false, true, false],
      );
      expect(
        [
          for (final m in [owe, owed, mixed, settled]) groupMatches(GroupFilter.owedToMe, m),
        ],
        [false, true, true, false],
      );
    });

    test('stored names', () {
      expect(GroupFilter.parse('iOwe'), GroupFilter.iOwe);
      expect(GroupFilter.parse(null), GroupFilter.all);
      expect(GroupFilter.parse('bogus'), GroupFilter.all);
      expect(SettleReminder.parse('weekly'), SettleReminder.weekly);
      expect(SettleReminder.parse(null), SettleReminder.off);
    });
  });

  group('nextSettleNudge (C4, mirrors private.send_settle_nudges)', () {
    // 2026-11-04 is a Wednesday.
    final created = DateTime(2026, 11, 4);

    test('weekly: the creation weekday, never the creation day itself', () {
      expect(
        nextSettleNudge(
          reminder: SettleReminder.weekly,
          today: DateTime(2026, 11, 10),
          createdDay: created,
        ),
        (day: DateTime(2026, 11, 11), reason: NudgeReason.weekly),
      );
      expect(
        nextSettleNudge(
          reminder: SettleReminder.weekly,
          today: DateTime(2026, 11, 11),
          createdDay: created,
        )!.day,
        DateTime(2026, 11, 11),
      );
      expect(
        nextSettleNudge(reminder: SettleReminder.weekly, today: created, createdDay: created)!.day,
        DateTime(2026, 11, 11),
      );
    });

    test('monthly: the 1st (today when it is the 1st), across the year end', () {
      expect(
        nextSettleNudge(reminder: SettleReminder.monthly, today: DateTime(2026, 12, 2))!.day,
        DateTime(2027),
      );
      expect(
        nextSettleNudge(reminder: SettleReminder.monthly, today: DateTime(2026, 12))!.day,
        DateTime(2026, 12),
      );
    });

    test('trip end: the day after, whatever the setting, and first on a tie', () {
      expect(
        nextSettleNudge(
          reminder: SettleReminder.off,
          today: DateTime(2026, 12),
          tripEndsOn: DateTime(2026, 12, 18),
        ),
        (day: DateTime(2026, 12, 19), reason: NudgeReason.tripEnd),
      );
      // 2026-12-02 is a Wednesday: the weekly day and the trip end fall together.
      expect(
        nextSettleNudge(
          reminder: SettleReminder.weekly,
          today: DateTime(2026, 12),
          createdDay: created,
          tripEndsOn: DateTime(2026, 12),
        ),
        (day: DateTime(2026, 12, 2), reason: NudgeReason.tripEnd),
      );
      // A trip that ended long ago: only the regular reminder.
      expect(
        nextSettleNudge(
          reminder: SettleReminder.monthly,
          today: DateTime(2026, 12, 5),
          tripEndsOn: DateTime(2026, 11, 1),
        )!.reason,
        NudgeReason.monthly,
      );
      expect(nextSettleNudge(reminder: SettleReminder.off, today: DateTime(2026, 12)), isNull);
    });

    test('days as text', () {
      expect(parseDay('2026-12-18'), DateTime(2026, 12, 18));
      expect(parseDay('2026-12-18T00:00:00Z'), DateTime(2026, 12, 18));
      expect(parseDay(null), isNull);
      expect(parseDay('bad'), isNull);
      expect(isoDay(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
