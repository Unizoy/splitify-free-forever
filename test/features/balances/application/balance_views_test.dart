import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balance_views.dart';

import '../../../support/ledger_seed.dart';

void main() {
  test('balanceStatusOf', () {
    expect(balanceStatusOf(const []), BalanceStatus.settled);
    expect(balanceStatusOf(const [0, 0]), BalanceStatus.settled);
    expect(balanceStatusOf(const [0, 5]), BalanceStatus.owed);
    expect(balanceStatusOf(const [-1, 0]), BalanceStatus.owe);
    expect(balanceStatusOf(const [-1, 1]), BalanceStatus.mixed);
  });

  test('orderCurrencies puts the first one in front, the rest alphabetical', () {
    expect(orderCurrencies(['USD', 'EUR', 'INR'], 'INR'), ['INR', 'EUR', 'USD']);
    expect(orderCurrencies(['USD', 'EUR'], 'INR'), ['EUR', 'USD']);
    expect(orderCurrencies(['USD', 'USD'], 'USD'), ['USD']);
  });

  test('decodeMinorMap reads ints (also written as floats)', () {
    expect(decodeMinorMap('{"a":100,"b":250.0}'), {'a': 100, 'b': 250});
    expect(decodeMinorMap('{}'), isEmpty);
  });

  group('groupBalancesOf', () {
    final members = [
      seedMember('m1', userId: 'u1', name: 'Mohit'),
      seedMember('m2', name: 'Asha', position: 1),
      seedMember('m3', name: 'Ravi', position: 2, userId: 'u3'),
    ];

    GroupLedger make({
      List<LocalExpense>? expenses,
      List<LocalPayment> payments = const [],
      List<LocalMember>? mem,
      bool simplify = false,
      String main = 'INR ',
    }) => GroupLedger(
      group: seedGroup(simplify: simplify, mainCurrency: main),
      members: mem ?? members,
      expenses:
          expenses ??
          [
            seedExpense(
              'e1',
              total: 30000,
              payers: {'m1': 30000},
              shares: {'m1': 10000, 'm2': 10000, 'm3': 10000},
            ),
          ],
      payments: payments,
    );

    test('computes nets, pairs and simplified per currency; finds me', () {
      final b = groupBalancesOf(make(), 'u1');
      expect(b.groupName, 'Goa trip');
      expect(b.mainCurrency, 'INR');
      expect(b.meId, 'm1');
      expect(b.hasRecords, isTrue);
      expect(b.unsynced, isFalse);
      expect(b.fromServer, isFalse);
      expect(b.currencies, ['INR']);
      expect(b.byCurrency['INR']!.nets, {'m1': 20000, 'm2': -10000, 'm3': -10000});
      expect(b.myNets, {'INR': 20000});
      expect(b.owed('m2', 'm1', 'INR'), 10000);
      expect(b.owed('m1', 'm2', 'INR'), 0);
      expect(b.owed('m2', 'm1', 'USD'), 0);
      expect(b.allSettled, isFalse);
      expect(b.nameOf('m2'), 'Asha');
      expect(b.nameOf('zz'), '');
      expect(b.member('m3')!.userId, 'u3');
      expect(b.shown('INR'), b.byCurrency['INR']!.pairs);
      expect(b.shown('INR', simplified: true), b.byCurrency['INR']!.simplified);
      expect(b.shown('USD'), isEmpty);
    });

    test('simplify on shows the simplified transfers', () {
      final b = groupBalancesOf(make(simplify: true), 'u1');
      expect(b.simplify, isTrue);
      expect(b.shown('INR'), b.byCurrency['INR']!.simplified);
      expect(b.shown('INR', simplified: false), b.byCurrency['INR']!.pairs);
    });

    test('payments settle up; settled group reads allSettled', () {
      final b = groupBalancesOf(
        make(
          payments: [
            seedPayment('p1', from: 'm2', to: 'm1', amount: 10000),
            seedPayment('p2', from: 'm3', to: 'm1', amount: 10000),
          ],
        ),
        'u1',
      );
      expect(b.allSettled, isTrue);
      expect(b.myNets, isEmpty);
    });

    test('payments to oneself or of zero are ignored', () {
      final b = groupBalancesOf(
        make(
          payments: [
            seedPayment('p1', from: 'm2', to: 'm2', amount: 500),
            seedPayment('p2', from: 'm2', to: 'm1', amount: 0),
          ],
        ),
        'u1',
      );
      expect(b.byCurrency['INR']!.nets['m2'], -10000);
    });

    test('currencies are kept apart, main currency first', () {
      final b = groupBalancesOf(
        make(
          expenses: [
            seedExpense(
              'e1',
              currency: 'USD',
              total: 1000,
              payers: {'m1': 1000},
              shares: {'m1': 500, 'm2': 500},
            ),
            seedExpense('e2', total: 200, payers: {'m2': 200}, shares: {'m1': 100, 'm2': 100}),
          ],
        ),
        'u1',
      );
      expect(b.currencies, ['INR', 'USD']);
      expect(b.myNets, {'INR': -100, 'USD': 500});
    });

    test('member ids this phone does not have yet go after everyone else', () {
      final b = groupBalancesOf(
        make(
          expenses: [
            seedExpense(
              'e1',
              total: 300,
              payers: {'zz': 300},
              shares: {'m1': 100, 'm2': 100, 'aa': 100},
            ),
          ],
        ),
        'u1',
      );
      expect(b.byCurrency['INR']!.nets, {'m1': -100, 'm2': -100, 'm3': 0, 'aa': -100, 'zz': 300});
      expect(b.byCurrency['INR']!.nets.keys.toList(), ['m1', 'm2', 'm3', 'aa', 'zz']);
    });

    test('inconsistent records log a warning and show no balances (no crash)', () {
      final logs = <LogRecord>[];
      final old = Logger.root.level;
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(logs.add);
      addTearDown(() {
        sub.cancel();
        Logger.root.level = old;
      });
      final b = groupBalancesOf(
        make(
          expenses: [
            seedExpense('bad', total: 100, payers: {'m1': 100}, shares: {'m1': 40, 'm2': 40}),
          ],
        ),
        'u1',
      );
      expect(b.byCurrency, isEmpty);
      expect(b.hasRecords, isTrue);
      expect(
        logs.where((r) => r.level == Level.WARNING && r.loggerName == 'balances'),
        hasLength(1),
      );
    });

    test('I am only an active member without a deleted mark', () {
      expect(groupBalancesOf(make(), null).meId, isNull);
      expect(groupBalancesOf(make(), 'someone-else').meId, isNull);
      final left = [
        seedMember('m1', userId: 'u1', status: 'left'),
        seedMember('m2', position: 1),
        seedMember('m3', position: 2),
      ];
      expect(groupBalancesOf(make(mem: left), 'u1').meId, isNull);
      final gone = [
        seedMember('m1', userId: 'u1', deletedAt: '2026-11-01T00:00:00Z'),
        seedMember('m2', position: 1),
        seedMember('m3', position: 2),
      ];
      expect(groupBalancesOf(make(mem: gone), 'u1').meId, isNull);
      expect(groupBalancesOf(make(mem: gone), 'u1').myNets, isEmpty);
    });

    test('an empty group has no records', () {
      final b = groupBalancesOf(make(expenses: const []), 'u1');
      expect(b.hasRecords, isFalse);
      expect(b.byCurrency, isEmpty);
      expect(b.allSettled, isTrue);
    });

    test('copyWith(unsynced) and withServer keep everything else', () {
      final b = groupBalancesOf(make(), 'u1');
      final u = b.copyWith(unsynced: true);
      expect((u.unsynced, u.meId, u.groupId, u.hasRecords), (true, 'm1', 'g1', true));
      expect(u.copyWith().unsynced, isTrue);
      expect(u.byCurrency, same(b.byCurrency));
      const server = Balances(
        nets: {'m1': 5, 'm2': -5},
        pairs: [Transfer('m2', 'm1', 5)],
        simplified: [],
      );
      final s = u.withServer(
        const ServerGroupBalances(
          groupId: 'g1',
          mainCurrency: 'INR',
          simplify: false,
          currencies: {'INR': server},
        ),
      );
      expect(s.fromServer, isTrue);
      expect(s.unsynced, isTrue);
      expect(s.byCurrency['INR'], same(server));
      expect(s.members, same(b.members));
      expect(s.owed('m2', 'm1', 'INR'), 5);
      final empty = groupBalancesOf(make(expenses: const []), 'u1').withServer(
        const ServerGroupBalances(
          groupId: 'g1',
          mainCurrency: 'INR',
          simplify: false,
          currencies: {'INR': server},
        ),
      );
      expect(empty.hasRecords, isTrue);
    });
  });

  group('myBalancesOf', () {
    test('sums my nets, lists people from what the group screens show', () {
      final g1 = groupBalancesOf(
        GroupLedger(
          group: seedGroup(),
          members: [
            seedMember('m1', userId: 'u1', name: 'Mohit'),
            seedMember('m2', name: 'Asha', position: 1, userId: 'u2'),
            seedMember('m3', name: 'Ravi', position: 2),
          ],
          expenses: [
            seedExpense(
              'e1',
              total: 30000,
              payers: {'m1': 30000},
              shares: {'m1': 10000, 'm2': 10000, 'm3': 10000},
            ),
          ],
          payments: const [],
        ),
        'u1',
      );
      final g2 = groupBalancesOf(
        GroupLedger(
          group: seedGroup(id: 'g2', name: 'Flat'),
          members: [
            seedMember('n1', groupId: 'g2', userId: 'u1', name: 'Mohit'),
            seedMember('n2', groupId: 'g2', name: 'Asha', position: 1, userId: 'u2'),
          ],
          expenses: [
            seedExpense(
              'e2',
              groupId: 'g2',
              total: 4000,
              payers: {'n2': 4000},
              shares: {'n1': 3000, 'n2': 1000},
            ),
            seedExpense(
              'e3',
              groupId: 'g2',
              currency: 'USD',
              total: 100,
              payers: {'n1': 100},
              shares: {'n2': 100},
            ),
          ],
          payments: const [],
        ),
        'u1',
      );
      final notMine = groupBalancesOf(
        GroupLedger(
          group: seedGroup(id: 'g9'),
          members: [seedMember('z1', groupId: 'g9')],
          expenses: const [],
          payments: const [],
        ),
        'u1',
      );
      final m = myBalancesOf([g1, g2, notMine]);
      expect(m.totals, {'INR': 20000 - 3000, 'USD': 100});
      expect(m.byGroup, {
        'g1': {'INR': 20000},
        'g2': {'INR': -3000, 'USD': 100},
      });
      // u2 is one person across both groups; Ravi is name-only (m:m3).
      expect([for (final p in m.people) p.key], ['m:m3', 'u:u2']);
      final asha = m.people.last;
      expect((asha.name, asha.seed), ('Asha', 'm2'));
      expect(asha.balances, {'INR': 10000 - 3000, 'USD': 100});
      expect(m.people.first.balances, {'INR': 10000});
      expect(m.peopleOwingMe, 2);
      expect(m.peopleIOwe, 0);
      expect(m.status, BalanceStatus.owed);
      // Σ per-group nets = overall (rule 3).
      expect(m.byGroup.values.fold<int>(0, (a, g) => a + (g['INR'] ?? 0)), m.totals['INR']);
      final u = m.copyWith(unsynced: true);
      expect((u.unsynced, u.fromServer), (true, false));
      expect(u.totals, same(m.totals));
      expect(u.copyWith().unsynced, isTrue);
    });

    test('people who net to zero drop out; nothing at all is settled', () {
      final g = groupBalancesOf(
        GroupLedger(
          group: seedGroup(),
          members: [
            seedMember('m1', userId: 'u1'),
            seedMember('m2', position: 1),
          ],
          expenses: [
            seedExpense('e1', total: 100, payers: {'m1': 100}, shares: {'m2': 100}),
          ],
          payments: [seedPayment('p1', from: 'm2', to: 'm1', amount: 100)],
        ),
        'u1',
      );
      final m = myBalancesOf([g]);
      expect(m.people, isEmpty);
      expect(m.totals, isEmpty);
      expect(m.status, BalanceStatus.settled);
      expect(myBalancesOf(const []).byGroup, isEmpty);
    });

    test('a third-party transfer is not mine', () {
      final g = groupBalancesOf(
        GroupLedger(
          group: seedGroup(),
          members: [
            seedMember('m1', userId: 'u1'),
            seedMember('m2', position: 1),
            seedMember('m3', position: 2),
          ],
          expenses: [
            seedExpense('e1', total: 100, payers: {'m2': 100}, shares: {'m3': 100}),
          ],
          payments: const [],
        ),
        'u1',
      );
      final m = myBalancesOf([g]);
      expect(m.people, isEmpty);
      expect(m.totals, isEmpty);
    });
  });

  group('MyBalances.fromServer', () {
    test('keeps non-zero numbers, keys people by user id or member id', () {
      final m = MyBalances.fromServer(
        ServerOverview(
          totals: const {'INR': 500, 'USD': 0},
          groups: [
            (groupId: 'g1', memberId: 'm1', balances: const {'INR': 500, 'USD': 0}),
            (groupId: 'g2', memberId: 'n1', balances: const {'INR': 0}),
          ],
          people: [
            (
              userId: 'u2',
              memberId: null,
              groupId: null,
              name: 'Asha',
              balances: const {'INR': -500},
            ),
            (
              userId: null,
              memberId: 'm9',
              groupId: 'g1',
              name: 'Ravi',
              balances: const {'INR': 5, 'USD': 0},
            ),
            (
              userId: null,
              memberId: null,
              groupId: null,
              name: 'Nobody',
              balances: const {'INR': 0},
            ),
          ],
        ),
      );
      expect(m.fromServer, isTrue);
      expect(m.totals, {'INR': 500});
      expect(m.byGroup, {
        'g1': {'INR': 500},
        'g2': <String, int>{},
      });
      expect([for (final p in m.people) (p.key, p.seed)], [('u:u2', 'u2'), ('m:m9', 'm9')]);
      expect(m.people[1].balances, {'INR': 5});
      expect(m.peopleOwingMe, 1);
      expect(m.peopleIOwe, 1);
    });

    test('a person without ids seeds by name', () {
      final m = MyBalances.fromServer(
        ServerOverview(
          totals: const {},
          groups: const [],
          people: [
            (userId: null, memberId: null, groupId: null, name: 'Anon', balances: const {'INR': 1}),
          ],
        ),
      );
      expect(m.people.single.seed, 'Anon');
      expect(m.people.single.key, 'm:null');
    });
  });
}
