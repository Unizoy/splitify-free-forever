import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/history/application/deleted_items_providers.dart';

import '../../../support/history_data_fakes.dart';
import 'history_app_env.dart';

void main() {
  late HistoryEnv env;

  setUp(() async => env = await HistoryEnv.create());
  tearDown(() => env.dispose());

  DeletedItemsView view([String g = 'g1']) =>
      env.container.read(deletedItemsProvider(g)).requireValue;

  Future<void> open([String g = 'g1']) async {
    env.keep(deletedItemsProvider(g));
    await pumpEventQueue();
  }

  group('deletedItemsProvider', () {
    test('is loading until the streams answer', () {
      expect(env.container.read(deletedItemsProvider('g1')).isLoading, isTrue);
    });

    test('an empty group has no items but still has names and me', () async {
      await open();
      final v = view();
      expect(v.items, isEmpty);
      expect(v.memberNames, {'m1': 'Mohit', 'm2': 'Asha', 'm3': 'Ravi'});
      expect(v.meMemberId, 'm1');
    });

    test('mixes expenses and payments, most recently deleted first, skipping live rows', () async {
      await putRow(env.db, 'expenses', expenseRow('e-old', deletedAt: '2026-11-19T10:00:00Z'));
      await putRow(env.db, 'expenses', expenseRow('e-new', deletedAt: '2026-11-21T10:00:00Z'));
      await putRow(env.db, 'expenses', expenseRow('e-live'));
      await putRow(env.db, 'payments', paymentRow('p-mid', deletedAt: '2026-11-20T10:00:00Z'));
      await putRow(env.db, 'payments', paymentRow('p-live'));
      await putRow(
        env.db,
        'expenses',
        expenseRow('e-other', groupId: 'g2', deletedAt: '2026-11-22T10:00:00Z'),
      );
      await open();
      final items = view().items;
      expect(items.map((i) => i.id), ['e-new', 'p-mid', 'e-old']);
      expect(items[0].expense, isNotNull);
      expect(items[0].payment, isNull);
      expect(items[1].payment, isNotNull);
      expect(items[1].expense, isNull);
      expect(items[0].deletedAt, '2026-11-21T10:00:00Z');
    });

    // TC-20-04
    test('deleted by me: null deleted_by (local delete) or my user id', () async {
      await putRow(env.db, 'expenses', expenseRow('a', deletedAt: '2026-11-21T10:00:00Z'));
      await putRow(
        env.db,
        'expenses',
        expenseRow('b', deletedAt: '2026-11-20T10:00:00Z', deletedBy: 'u1'),
      );
      await open();
      for (final i in view().items) {
        expect(i.deletedByMe, isTrue, reason: i.id);
        expect(i.deletedByName, isNull, reason: i.id);
      }
    });

    test('deleted by another member shows that member name', () async {
      await putRow(
        env.db,
        'expenses',
        expenseRow('a', deletedAt: '2026-11-21T10:00:00Z', deletedBy: 'u2'),
      );
      await putRow(
        env.db,
        'payments',
        paymentRow('p', deletedAt: '2026-11-20T10:00:00Z', deletedBy: 'u2'),
      );
      await open();
      for (final i in view().items) {
        expect(i.deletedByMe, isFalse);
        expect(i.deletedByName, 'Asha');
      }
    });

    test('deleted by an unknown account has no name and is not mine', () async {
      await putRow(
        env.db,
        'expenses',
        expenseRow('a', deletedAt: '2026-11-21T10:00:00Z', deletedBy: 'u9'),
      );
      await open();
      final i = view().items.single;
      expect(i.deletedByMe, isFalse);
      expect(i.deletedByName, isNull);
    });

    test('unsynced follows the row sync state', () async {
      await putRow(
        env.db,
        'expenses',
        expenseRow('a', deletedAt: '2026-11-21T10:00:00Z', syncState: 'pending'),
      );
      await putRow(env.db, 'payments', paymentRow('p', deletedAt: '2026-11-20T10:00:00Z'));
      await open();
      final byId = {for (final i in view().items) i.id: i};
      expect(byId['a']!.unsynced, isTrue);
      expect(byId['p']!.unsynced, isFalse);
    });

    test('a signed-out user is never "me" but null deleted_by still counts as mine', () async {
      env.dispose();
      env = await HistoryEnv.create(userId: null);
      await putRow(env.db, 'expenses', expenseRow('a', deletedAt: '2026-11-21T10:00:00Z'));
      await open();
      expect(view().meMemberId, isNull);
      expect(view().items.single.deletedByMe, isTrue);
    });

    test('a member who left is not "me" but keeps a name', () async {
      await putRow(
        env.db,
        'group_members',
        memberRow('m1', userId: 'u1', name: 'Mohit', deletedAt: '2026-11-21T10:00:00Z'),
      );
      await open();
      expect(view().meMemberId, isNull);
      expect(view().memberNames['m1'], 'Mohit');
    });

    test('follows live deletes', () async {
      await putRow(env.db, 'expenses', expenseRow('a'));
      await open();
      expect(view().items, isEmpty);
      await env.container.read(expensesRepositoryProvider).delete('a', 'g1');
      await pumpEventQueue();
      expect(view().items.map((i) => i.id), ['a']);
      expect(view().items.single.unsynced, isTrue);
    });
  });

  group('DeletedItemActions.restore', () {
    // TC-20-04
    test('restoring an expense clears deleted_at and queues a restore mutation', () async {
      await putRow(env.db, 'expenses', expenseRow('a', deletedAt: '2026-11-21T10:00:00Z'));
      await open();
      await env.container.read(deletedItemActionsProvider).restore(view().items.single);
      final row = await env.db.select(env.db.expenses).getSingle();
      expect(row.deletedAt, isNull);
      expect(row.syncState, SyncState.pending);
      final out = await env.db.select(env.db.outbox).getSingle();
      expect(out.entity, SyncEntity.expense.wire);
      expect(out.op, SyncOp.restore.name);
      expect(out.recordId, 'a');
      expect(out.groupId, 'g1');
      await pumpEventQueue();
      expect(view().items, isEmpty);
    });

    // TC-20-04
    test('restoring a payment clears deleted_at and queues a restore mutation', () async {
      await putRow(env.db, 'payments', paymentRow('p', deletedAt: '2026-11-21T10:00:00Z'));
      await open();
      await env.container.read(deletedItemActionsProvider).restore(view().items.single);
      final row = await env.db.select(env.db.payments).getSingle();
      expect(row.deletedAt, isNull);
      final out = await env.db.select(env.db.outbox).getSingle();
      expect(out.entity, SyncEntity.payment.wire);
      expect(out.op, SyncOp.restore.name);
      expect(out.recordId, 'p');
    });
  });
}
