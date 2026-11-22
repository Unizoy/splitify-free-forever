import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/history_repository.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/data/sync/server_clock.dart';
import 'package:splitify/data/sync/sync_types.dart';

import '../support/fakes.dart' show testDb;
import '../support/history_data_fakes.dart';
import 'sync/sync_fakes.dart' show FakeClock;

void main() {
  late AppDatabase db;
  late FakeHistoryRemote remote;
  late HistoryRepository repo;
  late FakeClock clock;
  late LocalWriter writer;

  setUp(() {
    db = testDb();
    remote = FakeHistoryRemote();
    repo = HistoryRepository(db, remote);
    clock = FakeClock(DateTime.utc(2026, 11, 22, 8, 30));
    writer = LocalWriter(db, clock, ServerClock(clock, SyncDao(db)));
  });

  tearDown(() => db.close());

  Future<List<LocalVersion>> cached() => db.select(db.recordVersions).get();

  group('HistoryRepository.refresh', () {
    test('first fetch starts at seq 0, stores the rows and returns the count', () async {
      remote.rows.addAll([
        versionRow(1, seq: 3, op: 'insert'),
        versionRow(2, seq: 5, op: 'update'),
      ]);
      expect(await repo.refresh('e1'), 2);
      expect(remote.calls.single, (recordId: 'e1', afterSeq: 0));
      final rows = await cached();
      expect(rows.map((r) => (r.id, r.seq, r.op)), [(1, 3, 'insert'), (2, 5, 'update')]);
      final v = rows.first;
      expect(v.tableName$, 'expenses');
      expect(v.recordId, 'e1');
      expect(v.groupId, 'g1');
      expect(v.changedBy, 'u1');
      expect(v.changedAt, '2026-11-20T10:00:00Z');
      expect((jsonDecode(v.snapshot) as Map)['description'], 'Dinner');
    });

    test('later fetches only ask for versions newer than the cache', () async {
      remote.rows.addAll([versionRow(1, seq: 3, op: 'insert'), versionRow(2, seq: 5)]);
      await repo.refresh('e1');
      remote.rows.add(versionRow(3, seq: 9, op: 'delete'));
      expect(await repo.refresh('e1'), 1);
      expect(remote.calls.last.afterSeq, 5);
      expect(await cached(), hasLength(3));
    });

    test('nothing new returns 0 and leaves the cache alone', () async {
      remote.rows.add(versionRow(1, seq: 3, op: 'insert'));
      await repo.refresh('e1');
      expect(await repo.refresh('e1'), 0);
      expect(remote.calls.last.afterSeq, 3);
      expect(await cached(), hasLength(1));
    });

    test('the cursor is per record', () async {
      remote.rows.addAll([
        versionRow(1, seq: 50, recordId: 'other', op: 'insert'),
        versionRow(2, seq: 2, op: 'insert'),
      ]);
      await repo.refresh('other');
      expect(await repo.refresh('e1'), 1);
      expect(remote.calls.last, (recordId: 'e1', afterSeq: 0));
    });

    test('a version that arrives again replaces the cached one', () async {
      remote.rows.add(versionRow(1, seq: 3, op: 'update'));
      await repo.refresh('e1');
      // The server row was rewritten (same id, higher seq) so it is fetched again.
      remote.rows
        ..clear()
        ..add(versionRow(1, seq: 4, op: 'delete'));
      expect(await repo.refresh('e1'), 1);
      final rows = await cached();
      expect(rows, hasLength(1));
      expect(rows.single.op, 'delete');
      expect(rows.single.seq, 4);
    });

    test('an offline fetch throws and keeps what was cached', () async {
      remote.rows.add(versionRow(1, seq: 3, op: 'insert'));
      await repo.refresh('e1');
      remote.error = const NetworkException();
      await expectLater(repo.refresh('e1'), throwsA(isA<NetworkException>()));
      expect(await cached(), hasLength(1));
    });

    test('a bad row rolls the whole batch back', () async {
      remote.rows.addAll([
        versionRow(1, seq: 3, op: 'insert'),
        {...versionRow(2, seq: 4)}..remove('snapshot'), // NOT NULL column missing
      ]);
      await expectLater(repo.refresh('e1'), throwsA(anything));
      expect(await cached(), isEmpty);
    });
  });

  group('HistoryRepository.watch', () {
    test('emits one record oldest first and follows refreshes', () async {
      remote.rows.addAll([
        versionRow(7, seq: 8, op: 'update'),
        versionRow(6, seq: 2, op: 'insert'),
        versionRow(9, seq: 4, recordId: 'other', op: 'insert'),
      ]);
      final seen = <List<int>>[];
      final sub = repo.watch('e1').listen((l) => seen.add([for (final v in l) v.seq]));
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await repo.refresh('e1');
      await pumpEventQueue();
      expect(seen.last, [2, 8]);
      remote.rows.add(versionRow(10, seq: 12, op: 'delete'));
      await repo.refresh('e1');
      await pumpEventQueue();
      expect(seen.last, [2, 8, 12]);
      await sub.cancel();
    });

    test('equal seq falls back to id order', () async {
      await putRow(db, 'record_versions', versionRow(5, seq: 1));
      await putRow(db, 'record_versions', versionRow(4, seq: 1));
      final list = await repo.watch('e1').first;
      expect(list.map((v) => v.id), [4, 5]);
    });
  });

  group('deleted reads', () {
    test('watchDeleted (expenses) lists this group tombstones, newest delete first', () async {
      await putRow(db, 'expenses', expenseRow('a', deletedAt: '2026-11-20T10:00:00Z'));
      await putRow(db, 'expenses', expenseRow('b', deletedAt: '2026-11-21T10:00:00Z'));
      await putRow(db, 'expenses', expenseRow('live'));
      await putRow(
        db,
        'expenses',
        expenseRow('x', groupId: 'g2', deletedAt: '2026-11-22T10:00:00Z'),
      );
      final list = await ExpensesRepository(db, writer).watchDeleted('g1').first;
      expect(list.map((e) => e.id), ['b', 'a']);
    });

    test('watchDeleted (payments) lists this group tombstones, newest delete first', () async {
      await putRow(db, 'payments', paymentRow('a', deletedAt: '2026-11-20T10:00:00Z'));
      await putRow(db, 'payments', paymentRow('b', deletedAt: '2026-11-21T10:00:00Z'));
      await putRow(db, 'payments', paymentRow('live'));
      await putRow(
        db,
        'payments',
        paymentRow('x', groupId: 'g2', deletedAt: '2026-11-22T10:00:00Z'),
      );
      final list = await PaymentsRepository(db, writer).watchDeleted('g1').first;
      expect(list.map((p) => p.id), ['b', 'a']);
    });

    test('watchDeleted streams a delete as it happens', () async {
      final expenses = ExpensesRepository(db, writer);
      await putRow(db, 'expenses', expenseRow('a'));
      final seen = <List<String>>[];
      final sub = expenses.watchDeleted('g1').listen((l) => seen.add([for (final e in l) e.id]));
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await expenses.delete('a', 'g1');
      await pumpEventQueue();
      expect(seen.last, ['a']);
      await expenses.restore('a', 'g1');
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await sub.cancel();
    });

    test('watchPayment returns the stored payment, deleted ones too, or null', () async {
      final payments = PaymentsRepository(db, writer);
      expect(await payments.watchPayment('p1').first, isNull);
      await putRow(db, 'payments', paymentRow('p1', deletedAt: '2026-11-20T10:00:00Z', seq: 4));
      final p = await payments.watchPayment('p1').first;
      expect(p!.id, 'p1');
      expect(p.deletedAt, isNotNull);
      expect(p.seq, 4);
    });
  });

  group('CommentWrites.add', () {
    // TC-13-03
    test('writes a pending local row with author and time, and one outbox mutation', () async {
      final comments = CommentsRepository(db, writer);
      final id = await comments.add(
        groupId: 'g1',
        targetType: 'expense',
        targetId: 'e1',
        body: 'Paid in cash',
        authorId: 'u1',
      );
      final row = await db.select(db.comments).getSingle();
      expect(row.id, id);
      expect(row.groupId, 'g1');
      expect(row.targetType, 'expense');
      expect(row.targetId, 'e1');
      expect(row.body, 'Paid in cash');
      expect(row.createdBy, 'u1');
      expect(row.createdAt, '2026-11-22T08:30:00.000Z');
      expect(row.syncState, SyncState.pending);

      final out = await db.select(db.outbox).getSingle();
      expect(out.entity, SyncEntity.comment.wire);
      expect(out.op, SyncOp.upsert.name);
      expect(out.recordId, id);
      expect(out.groupId, 'g1');
      final payload = jsonDecode(out.payload) as Map;
      expect(payload['body'], 'Paid in cash');
      expect(payload['target_type'], 'expense');
      expect(payload['target_id'], 'e1');
    });

    test('without an author the row has no created_by', () async {
      await CommentsRepository(
        db,
        writer,
      ).add(groupId: 'g1', targetType: 'payment', targetId: 'p1', body: 'ok');
      final row = await db.select(db.comments).getSingle();
      expect(row.createdBy, isNull);
      expect(row.targetType, 'payment');
    });
  });

  group('PullApplier.forgetGroup', () {
    test('removes the lost group record_versions and keeps other groups', () async {
      await putRow(db, 'record_versions', versionRow(1, seq: 1, groupId: 'g1'));
      await putRow(db, 'record_versions', versionRow(2, seq: 2, groupId: 'g1', recordId: 'e2'));
      await putRow(db, 'record_versions', versionRow(3, seq: 1, groupId: 'g2', recordId: 'e3'));
      await PullApplier(db).forgetGroup('g1');
      final left = await db.select(db.recordVersions).get();
      expect(left.map((v) => v.id), [3]);
      expect(
        await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM record_versions WHERE group_id = ?',
              variables: [Variable<String>('g1')],
            )
            .map((r) => r.read<int>('n'))
            .getSingle(),
        0,
      );
    });
  });
}
