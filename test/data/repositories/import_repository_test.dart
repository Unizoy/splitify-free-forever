import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/repositories/import_repository.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/server_clock.dart';

import '../../support/fakes.dart' show testDb;
import '../sync/sync_fakes.dart' show FakeClock;

ImportWrite _expense(String id, {String description = 'Dinner'}) => (
  id: id,
  data: {
    'kind': 'expense',
    'description': description,
    'category': 'food.dining_out',
    'date': '2026-01-05',
    'currency': 'INR',
    'total': 1000,
    'payers': {'m1': 1000},
    'shares': {'m1': 500, 'm2': 500},
    'split_kind': 'exact',
    'split_values': {'m1': 500, 'm2': 500, 'import_batch_id': 'b1'},
    'source': 'import',
  },
);

ImportWrite _payment(String id, {String source = 'import'}) => (
  id: id,
  data: {
    'from_member': 'm2',
    'to_member': 'm1',
    'amount': 500,
    'currency': 'INR',
    'date': '2026-01-06',
    'method': 'other',
    'source': source,
  },
);

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ImportRepository repo;

  setUp(() {
    db = testDb();
    clock = FakeClock(DateTime.utc(2026, 11, 22, 9));
    repo = ImportRepository(db, LocalWriter(db, clock, ServerClock(clock, SyncDao(db))));
  });

  tearDown(() => db.close());

  Future<List<OutboxItem>> outbox() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();

  Map<String, Object?> payload(OutboxItem i) => jsonDecode(i.payload) as Map<String, Object?>;

  Future<void> runBatch({
    String id = 'b1',
    List<ImportWrite>? payments,
    List<ImportWrite>? expenses,
    void Function(int, int)? onProgress,
  }) => repo.run(
    batchId: id,
    groupId: 'g1',
    source: 'splitwise',
    payments: payments ?? [_payment('p1')],
    expenses: expenses ?? [_expense('e1'), _expense('e2', description: 'Lunch')],
    memberIds: ['m1', 'm2'],
    fileName: 'trip.csv',
    onProgress: onProgress,
  );

  group('run', () {
    test('records the batch, then queues payments before expenses with source import', () async {
      final progress = <(int, int)>[];
      await runBatch(onProgress: (d, t) => progress.add((d, t)));

      final batch = await db.select(db.importBatches).getSingle();
      expect(batch.id, 'b1');
      expect(batch.groupId, 'g1');
      expect(batch.source, 'splitwise');
      expect(batch.fileName, 'trip.csv');
      expect(jsonDecode(batch.expenseIds), ['e1', 'e2']);
      expect(jsonDecode(batch.paymentIds), ['p1']);
      expect(jsonDecode(batch.memberIds), ['m1', 'm2']);
      expect(batch.createdAt, '2026-11-22T09:00:00.000Z');
      expect(batch.deletedAt, isNull);

      final items = await outbox();
      expect(items.map((i) => (i.entity, i.op, i.recordId)), [
        ('payment', 'upsert', 'p1'),
        ('expense', 'upsert', 'e1'),
        ('expense', 'upsert', 'e2'),
      ]);
      expect(items.every((i) => payload(i)['source'] == 'import'), isTrue);
      expect(progress, [(1, 3), (2, 3), (3, 3)]);
    });

    test('local expense rows keep source import', () async {
      await runBatch();
      final rows = await db.select(db.expenses).get();
      expect(rows.map((r) => r.id), unorderedEquals(['e1', 'e2']));
      expect(rows.every((r) => r.source == 'import'), isTrue);
      expect(await db.select(db.payments).get(), hasLength(1));
    });
  });

  group('watchForGroup and liveCounts', () {
    test('lists non-deleted batches of the group, newest first', () async {
      await runBatch(expenses: [_expense('e1')]);
      clock.time = DateTime.utc(2026, 11, 23);
      await runBatch(id: 'b2', payments: [], expenses: [_expense('e2')]);
      clock.time = DateTime.utc(2026, 11, 24);
      await runBatch(id: 'b3', payments: [], expenses: [_expense('e3')]);
      await repo.deleteBatch('b3');
      final list = await repo.watchForGroup('g1').first;
      expect(list.map((b) => b.id), ['b2', 'b1']);
      expect(await repo.watchForGroup('other').first, isEmpty);
    });

    test('liveCounts counts records not deleted', () async {
      await runBatch();
      expect(await repo.liveCounts('b1'), (expenses: 2, payments: 1));
      await db.customStatement("UPDATE expenses SET deleted_at = 'x' WHERE id = 'e2'");
      expect(await repo.liveCounts('b1'), (expenses: 1, payments: 1));
      expect(await repo.liveCounts('nope'), (expenses: 0, payments: 0));
    });
  });

  group('deleteBatch', () {
    test('undo note on the first live expense, then deletes expenses before payments', () async {
      await runBatch();
      final before = (await outbox()).length;
      final progress = <(int, int)>[];
      final n = await repo.deleteBatch('b1', onProgress: (d, t) => progress.add((d, t)));
      expect(n, 3);
      expect(progress, [(1, 3), (2, 3), (3, 3)]);

      final items = (await outbox()).skip(before).toList();
      expect(items.map((i) => (i.entity, i.op, i.recordId)), [
        ('expense', 'upsert', 'e1'),
        ('expense', 'delete', 'e1'),
        ('expense', 'delete', 'e2'),
        ('payment', 'delete', 'p1'),
      ]);
      final undo = payload(items.first);
      expect(undo['source'], 'import');
      final values = undo['split_values']! as Map<String, Object?>;
      expect(values['import_undo'], {'expenses': 2, 'payments': 1});
      expect(values['import_batch_id'], 'b1');
      expect(values['m1'], 500);
      expect(
        items.skip(1).every((i) => payload(i).length == 1 && payload(i)['source'] == 'import'),
        isTrue,
      );

      final batch = await db.select(db.importBatches).getSingle();
      expect(batch.deletedAt, isNotNull);
      expect((await db.select(db.expenses).get()).every((e) => e.deletedAt != null), isTrue);
      expect((await db.select(db.payments).get()).single.deletedAt, isNotNull);
      expect(await repo.watchForGroup('g1').first, isEmpty);
    });

    test('records already deleted are skipped', () async {
      await runBatch();
      await db.customStatement("UPDATE expenses SET deleted_at = 'x' WHERE id = 'e1'");
      final before = (await outbox()).length;
      expect(await repo.deleteBatch('b1'), 2);
      final items = (await outbox()).skip(before).toList();
      expect(items.map((i) => (i.op, i.recordId)), [
        ('upsert', 'e2'),
        ('delete', 'e2'),
        ('delete', 'p1'),
      ]);
      expect((payload(items.first)['split_values']! as Map)['import_undo'], {
        'expenses': 1,
        'payments': 1,
      });
    });

    test('with no live expense the payments are deleted as app records, no upsert', () async {
      await runBatch();
      await db.customStatement("UPDATE expenses SET deleted_at = 'x'");
      final before = (await outbox()).length;
      expect(await repo.deleteBatch('b1'), 1);
      final items = (await outbox()).skip(before).toList();
      expect(items.map((i) => (i.entity, i.op, i.recordId)), [('payment', 'delete', 'p1')]);
      expect(payload(items.single), {'source': 'app'});
    });

    test('an unknown batch deletes nothing and returns 0', () async {
      expect(await repo.deleteBatch('nope'), 0);
      expect(await outbox(), isEmpty);
    });
  });
}
