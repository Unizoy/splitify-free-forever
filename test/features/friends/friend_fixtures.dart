// Shared data for the phase 11 friends tests: ledgers built from stored rows.
// Me = user `u1`. Asha (u2) is in three groups (Goa, Flat, our direct group); Rahul is name-only in Goa;
// Priya was removed from Flat but still owes me Rs 5; Dev (u3) has no records yet.
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/friends/application/friends_view.dart';

import '../../support/ledger_seed.dart';

GroupLedger ledgerOf(
  LocalGroup group,
  List<LocalMember> members, {
  List<LocalExpense> expenses = const [],
  List<LocalPayment> payments = const [],
}) => GroupLedger(group: group, members: members, expenses: expenses, payments: payments);

/// Goa trip: Asha owes me 60.00 (after paying 40.00), Rahul owes me 70.00 net, Dev nothing yet.
GroupLedger goaLedger({bool simplify = false}) => ledgerOf(
  seedGroup(id: 'g1', name: 'Goa trip', simplify: simplify),
  [
    seedMember('a1', groupId: 'g1', name: 'Mohit Bindal', userId: 'u1'),
    seedMember('a2', groupId: 'g1', name: 'Asha', userId: 'u2', position: 1),
    seedMember('a3', groupId: 'g1', name: 'Rahul Mehta', position: 2),
    seedMember('a4', groupId: 'g1', name: 'Dev Shah', userId: 'u3', position: 3),
  ],
  expenses: [
    seedExpense(
      'e1',
      groupId: 'g1',
      description: 'Dinner',
      total: 30000,
      payers: {'a1': 30000},
      shares: {'a1': 10000, 'a2': 10000, 'a3': 10000},
    ),
    // Rahul paid; Asha is not in it.
    seedExpense(
      'e2',
      groupId: 'g1',
      description: 'Cab',
      date: '2026-11-19',
      total: 6000,
      payers: {'a3': 6000},
      shares: {'a1': 3000, 'a3': 3000},
    ),
  ],
  payments: [
    seedPayment('p1', groupId: 'g1', from: 'a2', to: 'a1', amount: 4000, date: '2026-11-21'),
    // Not between me and anyone: never on a friend page of mine.
    seedPayment('p2', groupId: 'g1', from: 'a3', to: 'a4', amount: 100, date: '2026-11-21'),
  ],
);

/// Flat 4B: I owe Asha 100.00; Priya (removed) still owes me 5.00; Kiran (removed) owes nothing.
GroupLedger flatLedger({bool priyaSettled = false}) => ledgerOf(
  seedGroup(id: 'g2', name: 'Flat 4B', createdAt: '2026-11-05T10:00:00Z'),
  [
    seedMember('b1', groupId: 'g2', name: 'Mohit Bindal', userId: 'u1'),
    seedMember('b2', groupId: 'g2', name: 'Asha R', userId: 'u2', position: 1),
    seedMember(
      'b3',
      groupId: 'g2',
      name: 'Priya Nair',
      position: 2,
      status: 'removed',
      deletedAt: '2026-11-10T10:00:00Z',
    ),
    seedMember(
      'b4',
      groupId: 'g2',
      name: 'Kiran',
      position: 3,
      status: 'removed',
      deletedAt: '2026-11-10T10:00:00Z',
    ),
  ],
  expenses: [
    seedExpense(
      'e3',
      groupId: 'g2',
      description: 'Rent',
      total: 20000,
      payers: {'b2': 20000},
      shares: {'b1': 10000, 'b2': 10000},
    ),
    seedExpense(
      'e4',
      groupId: 'g2',
      description: 'Milk',
      date: '2026-11-18',
      total: 1000,
      payers: {'b1': 1000},
      shares: {'b1': 500, 'b3': 500},
    ),
  ],
  payments: [
    if (priyaSettled)
      seedPayment('p3', groupId: 'g2', from: 'b3', to: 'b1', amount: 500, date: '2026-11-19'),
  ],
);

/// Our direct group: Asha owes me 25.00.
GroupLedger directLedger({String id = 'g3'}) => ledgerOf(
  seedGroup(id: id, name: 'Me & Asha', type: 'direct', createdAt: '2026-11-08T10:00:00Z'),
  [
    seedMember('c1', groupId: id, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('c2', groupId: id, name: 'Asha', userId: 'u2', position: 1),
  ],
  expenses: [
    seedExpense(
      'e5',
      groupId: id,
      description: 'Movie',
      date: '2026-11-22',
      total: 5000,
      payers: {'c1': 5000},
      shares: {'c1': 2500, 'c2': 2500},
    ),
  ],
);

/// A group of two other people (u2 is in it): I am not a member, so it never counts.
GroupLedger othersLedger() => ledgerOf(
  seedGroup(id: 'g4', name: 'Their trip'),
  [
    seedMember('x1', groupId: 'g4', name: 'Bob', userId: 'u9'),
    seedMember('x2', groupId: 'g4', name: 'Asha', userId: 'u2', position: 1),
    seedMember('x3', groupId: 'g4', name: 'Zed', position: 2),
  ],
  expenses: [
    seedExpense(
      'e6',
      groupId: 'g4',
      total: 1000,
      payers: {'x1': 1000},
      shares: {'x1': 500, 'x2': 500},
    ),
  ],
);

/// A group I left (my member is removed): ignored too.
GroupLedger leftLedger() => ledgerOf(seedGroup(id: 'g5', name: 'Old flat'), [
  seedMember(
    'y1',
    groupId: 'g5',
    name: 'Mohit Bindal',
    userId: 'u1',
    status: 'removed',
    deletedAt: '2026-11-10T10:00:00Z',
  ),
  seedMember('y2', groupId: 'g5', name: 'Bob', userId: 'u5', position: 1),
]);

/// Three people in a cycle: I owe Asha 10.00, Asha owes Kabir 10.00, Kabir owes me 10.00. Every net is 0,
/// so simplified shows nothing and the original debts show the three pairs.
GroupLedger cycleLedger({bool simplify = false, String id = 'g6'}) => ledgerOf(
  seedGroup(id: id, name: 'Cycle', simplify: simplify, createdAt: '2026-11-12T10:00:00Z'),
  [
    seedMember('k1', groupId: id, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('k2', groupId: id, name: 'Asha', userId: 'u2', position: 1),
    seedMember('k3', groupId: id, name: 'Kabir', userId: 'u7', position: 2),
  ],
  expenses: [
    seedExpense('k-e1', groupId: id, total: 1000, payers: {'k2': 1000}, shares: {'k1': 1000}),
    seedExpense('k-e2', groupId: id, total: 1000, payers: {'k3': 1000}, shares: {'k2': 1000}),
    seedExpense('k-e3', groupId: id, total: 1000, payers: {'k1': 1000}, shares: {'k3': 1000}),
  ],
);

/// Rupees and dollars in one group: Asha owes me 10.00 INR and 20.00 USD.
GroupLedger twoCurrencyLedger({bool simplify = false, String id = 'g7'}) => ledgerOf(
  seedGroup(id: id, name: 'Abroad', simplify: simplify, createdAt: '2026-11-13T10:00:00Z'),
  [
    seedMember('t1', groupId: id, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('t2', groupId: id, name: 'Asha', userId: 'u2', position: 1),
  ],
  expenses: [
    seedExpense(
      't-e1',
      groupId: id,
      total: 2000,
      payers: {'t1': 2000},
      shares: {'t1': 1000, 't2': 1000},
    ),
    seedExpense(
      't-e2',
      groupId: id,
      currency: 'USD',
      total: 4000,
      payers: {'t1': 4000},
      shares: {'t1': 2000, 't2': 2000},
    ),
  ],
);

const profileNames = {'u2': 'Asha Rao'};

/// Meera is owed 5.00 and owes 20.00 USD: a mixed friend.
GroupLedger mixedLedger() => ledgerOf(
  seedGroup(id: 'g8', name: 'Bali', createdAt: '2026-11-14T10:00:00Z'),
  [
    seedMember('z1', groupId: 'g8', name: 'Mohit Bindal', userId: 'u1'),
    seedMember('z2', groupId: 'g8', name: 'Meera Iyer', userId: 'u8', position: 1),
  ],
  expenses: [
    seedExpense(
      'z-e1',
      groupId: 'g8',
      description: 'Scooter',
      date: '2026-10-30',
      total: 1000,
      payers: {'z1': 1000},
      shares: {'z1': 500, 'z2': 500},
    ),
    seedExpense(
      'z-e2',
      groupId: 'g8',
      description: 'Villa deposit',
      date: '2026-10-29',
      currency: 'USD',
      total: 4000,
      payers: {'z2': 4000},
      shares: {'z1': 2000, 'z2': 2000},
    ),
  ],
);

/// The Friends tab sample: Asha owes me (net: I owe her 15.00 across three groups), Dev settled, Meera mixed,
/// Rahul owes me 70.00. Priya (removed, paid back) is not listed.
List<Friend> sampleFriends() => friendsOf(
  [goaLedger(), flatLedger(priyaSettled: true), directLedger(), mixedLedger()],
  'u1',
  profileNames: profileNames,
);
