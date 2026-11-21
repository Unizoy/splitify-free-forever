import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/activity_repository.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';

import '../../support/fakes.dart';
import '../../support/ledger_seed.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = testDb());
  tearDown(() => db.close());

  group('LedgerRepository', () {
    Future<void> seedTwoGroups() => db.seed(
      groups: [
        seedGroup(id: 'g2', name: 'Flat', createdAt: '2026-11-02T10:00:00Z'),
        seedGroup(),
        seedGroup(id: 'g3', name: 'Gone', deletedAt: '2026-11-10T00:00:00Z'),
      ],
      members: [
        seedMember('m2', position: 1),
        seedMember('m1', position: 0),
        seedMember('mb', position: 1),
        seedMember('ma', position: 1, deletedAt: '2026-11-15T00:00:00Z', status: 'removed'),
        seedMember('x1', groupId: 'g2'),
      ],
      expenses: [
        seedExpense('e1', total: 100, payers: {'m1': 100}, shares: {'m2': 100}),
        seedExpense('e2', date: '2026-11-22', total: 200, payers: {'m1': 200}, shares: {'m2': 200}),
        seedExpense(
          'e3',
          total: 300,
          payers: {'m1': 300},
          shares: {'m2': 300},
          deletedAt: '2026-11-21T00:00:00Z',
        ),
        seedExpense('e4', groupId: 'g2', total: 50, payers: {'x1': 50}, shares: {'x1': 50}),
      ],
      payments: [
        seedPayment('p1', from: 'm2', to: 'm1', amount: 10),
        seedPayment('p2', from: 'm2', to: 'm1', amount: 20, date: '2026-11-22'),
        seedPayment('p3', from: 'm2', to: 'm1', amount: 30, deletedAt: '2026-11-22T00:00:00Z'),
      ],
    );

    test('loadGroup returns members in fixed order, live records newest first', () async {
      await seedTwoGroups();
      final l = (await LedgerRepository(db).loadGroup('g1'))!;
      expect(l.group.name, 'Goa trip');
      // position, then id; removed members stay (old records still name them).
      expect([for (final m in l.members) m.id], ['m1', 'm2', 'ma', 'mb']);
      expect([for (final e in l.expenses) e.id], ['e2', 'e1']);
      expect([for (final p in l.payments) p.id], ['p2', 'p1']);
    });

    test('loadGroup is null for an unknown or deleted group', () async {
      await seedTwoGroups();
      final r = LedgerRepository(db);
      expect(await r.loadGroup('nope'), isNull);
      expect(await r.loadGroup('g3'), isNull);
    });

    test('a group without records has empty lists', () async {
      await db.seed(groups: [seedGroup()]);
      final l = (await LedgerRepository(db).loadGroup('g1'))!;
      expect(l.members, isEmpty);
      expect(l.expenses, isEmpty);
      expect(l.payments, isEmpty);
    });

    test('loadAll lists live groups oldest first with their own records', () async {
      await seedTwoGroups();
      final all = await LedgerRepository(db).loadAll();
      expect([for (final l in all) l.group.id], ['g1', 'g2']);
      expect([for (final e in all[1].expenses) e.id], ['e4']);
      expect(all[1].payments, isEmpty);
      expect([for (final m in all[1].members) m.id], ['x1']);
    });

    test('watchGroup emits at once and again after a write', () async {
      await seedTwoGroups();
      final r = LedgerRepository(db);
      final it = StreamIterator(r.watchGroup('g1'));
      expect(await it.moveNext(), isTrue);
      expect(it.current!.payments, hasLength(2));
      await db.seed(
        payments: [seedPayment('p9', from: 'm1', to: 'm2', amount: 5)],
      );
      expect(await it.moveNext(), isTrue);
      expect(it.current!.payments, hasLength(3));
      await it.cancel();
    });

    test('watchAll emits every live ledger', () async {
      await seedTwoGroups();
      final first = await LedgerRepository(db).watchAll().first;
      expect(first, hasLength(2));
    });

    test('watchPayment returns deleted payments too, null when missing', () async {
      await seedTwoGroups();
      final r = LedgerRepository(db);
      expect((await r.watchPayment('p3').first)!.deletedAt, isNotNull);
      expect((await r.watchPayment('p1').first)!.amount, 10);
      expect(await r.watchPayment('zz').first, isNull);
    });
  });

  group('ActivityRepository', () {
    test('load: newest first, optional group filter, group and member lookups', () async {
      await db.seed(
        groups: [
          seedGroup(),
          seedGroup(id: 'g2', name: 'Flat'),
          seedGroup(id: 'g3', name: 'Gone', deletedAt: '2026-11-10T00:00:00Z'),
        ],
        members: [
          seedMember('m1'),
          seedMember('x1', groupId: 'g2', deletedAt: '2026-11-01'),
        ],
        activity: [
          seedActivity('a1', 'group_created', createdAt: '2026-11-01T10:00:00Z', seq: 1),
          seedActivity('a2', 'expense_added', createdAt: '2026-11-03T10:00:00Z', seq: 2),
          seedActivity('a3', 'expense_edited', createdAt: '2026-11-03T10:00:00Z', seq: 3),
          seedActivity('a4', 'group_created', groupId: 'g2', createdAt: '2026-11-02T10:00:00Z'),
        ],
        outbox: [
          seedOutbox(1, 'group', 'upsert', 'g1'),
          seedOutbox(2, 'group', 'upsert', 'g2', groupId: 'g2'),
        ],
      );
      final all = await ActivityRepository(db).load();
      expect([for (final a in all.activity) a.id], ['a3', 'a2', 'a4', 'a1']);
      expect([for (final o in all.pending) o.seq], [2, 1]);
      expect(all.groups.keys, containsAll(['g1', 'g2', 'g3']));
      expect(all.members.keys, containsAll(['m1', 'x1']));
      expect(all.expenses, isEmpty);
      expect(all.payments, isEmpty);

      final one = await ActivityRepository(db).load(groupId: 'g2');
      expect([for (final a in one.activity) a.id], ['a4']);
      expect([for (final o in one.pending) o.seq], [2]);
    });

    test('load fetches the expenses and payments pending changes and comments point at', () async {
      await db.seed(
        groups: [seedGroup()],
        members: [seedMember('m1')],
        expenses: [
          seedExpense('e1', total: 100, payers: {'m1': 100}, shares: {'m1': 100}),
          seedExpense('e2', total: 100, payers: {'m1': 100}, shares: {'m1': 100}),
          seedExpense('e3', total: 100, payers: {'m1': 100}, shares: {'m1': 100}),
        ],
        payments: [
          seedPayment('p1', from: 'm1', to: 'm1', amount: 1),
          seedPayment('p2', from: 'm1', to: 'm1', amount: 1),
          seedPayment('p3', from: 'm1', to: 'm1', amount: 1),
        ],
        activity: [
          seedActivity(
            'c1',
            'comment_added',
            data: {'target_type': 'expense', 'target_id': 'e1'},
            seq: 1,
          ),
          seedActivity(
            'c2',
            'comment_added',
            data: {'target_type': 'payment', 'target_id': 'p1'},
            seq: 2,
          ),
          // Not a comment row: its data is not looked at.
          seedActivity(
            'x',
            'expense_added',
            data: {'target_type': 'expense', 'target_id': 'e3'},
            seq: 3,
          ),
        ],
        outbox: [
          seedOutbox(1, 'expense', 'upsert', 'e2'),
          seedOutbox(2, 'payment', 'upsert', 'p2'),
          seedOutbox(3, 'comment', 'upsert', 'c9'),
        ],
      );
      final s = await ActivityRepository(db).load();
      expect(s.expenses.keys.toSet(), {'e1', 'e2'});
      expect(s.payments.keys.toSet(), {'p1', 'p2'});
    });

    test('comment rows with odd data point at nothing', () async {
      await db.seed(
        groups: [seedGroup()],
        activity: [
          seedActivity('c1', 'comment_added', data: {'target_type': 'group'}, seq: 1),
          seedActivity('c2', 'comment_added', data: {'target_type': 'expense'}, seq: 2),
        ],
      );
      await db.customStatement("UPDATE activity SET data = '[1]' WHERE id = 'c1'");
      final s = await ActivityRepository(db).load();
      expect(s.expenses, isEmpty);
      expect(s.activity, hasLength(2));
    });

    test('load stops at the newest ${ActivityRepository.limit} rows', () async {
      await db.batch((b) {
        b.insertAll(db.activity, [
          for (var i = 1; i <= ActivityRepository.limit + 5; i++)
            ActivityCompanion.insert(
              id: 'a$i',
              groupId: 'g1',
              type: 'expense_added',
              seq: Value(i),
              createdAt: Value(
                DateTime.utc(2026, 1, 1).add(Duration(minutes: i)).toIso8601String(),
              ),
            ),
        ]);
      });
      final s = await ActivityRepository(db).load();
      expect(s.activity, hasLength(ActivityRepository.limit));
      expect(s.activity.first.id, 'a${ActivityRepository.limit + 5}');
    });

    test('watch emits at once and again when activity arrives', () async {
      await db.seed(groups: [seedGroup()]);
      final it = StreamIterator(ActivityRepository(db).watch(groupId: 'g1'));
      expect(await it.moveNext(), isTrue);
      expect(it.current.activity, isEmpty);
      await db.seed(activity: [seedActivity('a1', 'expense_added')]);
      expect(await it.moveNext(), isTrue);
      expect(it.current.activity.single.id, 'a1');
      await it.cancel();
    });
  });
}
