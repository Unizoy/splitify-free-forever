// D-034 B5: when we are settled in every currency, the friend page hides the history up to the last full
// settle-up; with a balance open everything is listed.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/friends/application/friends_view.dart';

import '../../../support/ledger_seed.dart';
import '../friend_fixtures.dart';

void main() {
  final members = [
    seedMember('c1', groupId: 'g3', name: 'Mohit', userId: 'u1'),
    seedMember('c2', groupId: 'g3', name: 'Asha', userId: 'u2', position: 1),
  ];
  final group = seedGroup(id: 'g3', name: 'Me & Asha', type: 'direct');

  Friend friendWith({required List<LocalExpense> expenses, required List<LocalPayment> payments}) {
    final ledger = ledgerOf(group, members, expenses: expenses, payments: payments);
    return friendsOf([ledger], 'u1').single;
  }

  final movie = seedExpense(
    'e1',
    groupId: 'g3',
    date: '2026-11-01',
    total: 5000,
    payers: {'c1': 5000},
    shares: {'c1': 2500, 'c2': 2500},
  );
  final paid = seedPayment(
    'p1',
    groupId: 'g3',
    from: 'c2',
    to: 'c1',
    amount: 2500,
    date: '2026-11-05',
  );
  final cab = seedExpense(
    'e2',
    groupId: 'g3',
    date: '2026-11-10',
    total: 1000,
    payers: {'c2': 1000},
    shares: {'c1': 500, 'c2': 500},
  );
  final paidBack = seedPayment(
    'p2',
    groupId: 'g3',
    from: 'c1',
    to: 'c2',
    amount: 500,
    date: '2026-11-12',
  );

  test('settled: everything up to the last settle-up is history', () {
    final f = friendWith(expenses: [movie, cab], payments: [paid, paidBack]);
    final items = friendItems(f);
    expect(items, hasLength(4));
    expect(settledHistoryCount(f, items), 4);
  });

  test('a balance open: nothing is hidden', () {
    final f = friendWith(expenses: [movie, cab], payments: [paid]);
    expect(f.balances, isNotEmpty);
    expect(settledHistoryCount(f, friendItems(f)), 0);
  });

  test('records after the last settle-up that add up to zero still count as settled history', () {
    // A zero-sum expense (each paid their own share) after the settle-up.
    final own = seedExpense(
      'e3',
      groupId: 'g3',
      date: '2026-11-20',
      total: 2000,
      payers: {'c1': 1000, 'c2': 1000},
      shares: {'c1': 1000, 'c2': 1000},
    );
    final f = friendWith(expenses: [movie, own], payments: [paid]);
    final items = friendItems(f);
    expect(settledHistoryCount(f, items), items.length);
  });

  test('no shared items: nothing to hide', () {
    final f = friendWith(expenses: [], payments: []);
    expect(settledHistoryCount(f, friendItems(f)), 0);
  });

  test('the sample friends with balances hide nothing', () {
    for (final f in sampleFriends()) {
      if (f.balances.isNotEmpty) expect(settledHistoryCount(f, friendItems(f)), 0, reason: f.name);
    }
  });
}
