// F14 (W2-Y, S-434): the monthly summary card's numbers — last month's shares per currency (IOUs, other
// months, other people and deleted groups left out), how many groups, the balances now, the first 7 days only.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/activity/application/monthly_summary.dart';
import 'package:splitify/features/activity/presentation/monthly_summary_card.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/l10n/app_localizations_en.dart';

import '../../../support/ledger_seed.dart';

GroupLedger _goa({String? deletedAt}) => GroupLedger(
  group: seedGroup(deletedAt: deletedAt),
  members: [
    seedMember('m1', userId: 'u1', name: 'Mohit'),
    seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
  ],
  expenses: [
    seedExpense(
      'e1',
      date: '2026-11-05',
      total: 30000,
      payers: {'m1': 30000},
      shares: {'m1': 15000, 'm2': 15000},
    ),
    seedExpense(
      'e2',
      date: '2026-11-30',
      total: 1000,
      payers: {'m2': 1000},
      shares: {'m1': 400, 'm2': 600},
    ),
    seedExpense(
      'iou',
      date: '2026-11-06',
      kind: 'iou',
      total: 500,
      payers: {'m2': 500},
      shares: {'m1': 500},
    ),
    seedExpense('oct', date: '2026-10-31', total: 900, payers: {'m1': 900}, shares: {'m1': 900}),
    seedExpense('dec', date: '2026-12-01', total: 700, payers: {'m1': 700}, shares: {'m1': 700}),
    seedExpense('hers', date: '2026-11-10', total: 800, payers: {'m2': 800}, shares: {'m2': 800}),
    seedExpense(
      'usd',
      date: '2026-11-12',
      currency: 'USD',
      total: 2000,
      payers: {'m1': 2000},
      shares: {'m1': 1000, 'm2': 1000},
    ),
  ],
  payments: const [],
);

GroupLedger _flat() => GroupLedger(
  group: seedGroup(id: 'g2', name: 'Flat', type: 'home'),
  members: [seedMember('f1', groupId: 'g2', userId: 'u1', name: 'Mohit')],
  expenses: [
    seedExpense(
      'r',
      groupId: 'g2',
      date: '2026-11-01',
      total: 5000,
      payers: {'f1': 5000},
      shares: {'f1': 5000},
    ),
  ],
  payments: const [],
);

const _balances = MyBalances(
  totals: {'INR': 12000, 'USD': -500, 'EUR': 0},
  byGroup: {},
  people: [],
);

void main() {
  final l = AppLocalizationsEn();

  test('the first days of December summarise November', () {
    final s = monthSummaryOf(
      ledgers: [_goa(), _flat()],
      userId: 'u1',
      today: DateTime(2026, 12, 3),
      balances: _balances,
    )!;
    expect(s.key, '2026-11');
    expect(s.spent, {'INR': 15000 + 400 + 5000, 'USD': 1000});
    expect(s.groups, 2);
    expect(s.balances, {'INR': 12000, 'USD': -500}, reason: 'zero balances left out');
    expect(s.unsynced, isFalse);
  });

  test('January looks back at December of the year before', () {
    final s = monthSummaryOf(
      ledgers: [
        GroupLedger(
          group: seedGroup(),
          members: [seedMember('m1', userId: 'u1')],
          expenses: [
            seedExpense(
              'x',
              date: '2026-12-24',
              total: 100,
              payers: {'m1': 100},
              shares: {'m1': 100},
            ),
          ],
          payments: const [],
        ),
      ],
      userId: 'u1',
      today: DateTime(2027, 1, 1),
      balances: _balances,
    )!;
    expect(s.key, '2026-12');
    expect(s.spent, {'INR': 100});
  });

  test('no card after the 7th, without spending, for someone else or in a deleted group', () {
    MonthSummary? on(DateTime day, {List<GroupLedger>? ledgers, String user = 'u1'}) =>
        monthSummaryOf(ledgers: ledgers ?? [_goa()], userId: user, today: day, balances: _balances);
    expect(on(DateTime(2026, 12, 7)), isNotNull);
    expect(on(DateTime(2026, 12, 8)), isNull);
    expect(on(DateTime(2026, 11, 2))!.spent, {
      'INR': 900,
    }, reason: 'in November it is about October');
    expect(on(DateTime(2026, 12, 2), user: 'nobody'), isNull);
    expect(on(DateTime(2026, 12, 2), ledgers: [_goa(deletedAt: '2026-11-29T00:00:00Z')]), isNull);
  });

  test('unsynced balances mark the card', () {
    final s = monthSummaryOf(
      ledgers: [_flat()],
      userId: 'u1',
      today: DateTime(2026, 12, 1),
      balances: _balances.copyWith(unsynced: true),
    )!;
    expect(s.unsynced, isTrue);
  });

  test('the card lines: spent per currency, then owed, owe or settled', () {
    final s = monthSummaryOf(
      ledgers: [_goa(), _flat()],
      userId: 'u1',
      today: DateTime(2026, 12, 3),
      balances: _balances,
    )!;
    final lines = monthSummaryLines(l, s);
    expect(lines.first, startsWith('You spent ₹204'));
    expect(lines.first, contains(r' + $10'));
    expect(lines.first, endsWith('across 2 groups'));
    expect(lines.skip(1), ["You're owed ₹120", r'You owe $5']);
    final settled = MonthSummary(
      month: DateTime(2026, 12),
      spent: const {'INR': 100},
      groups: 1,
      balances: const {},
    );
    expect(monthSummaryLines(l, settled), ['You spent ₹1 across 1 group', "You're all settled up"]);
  });
}
