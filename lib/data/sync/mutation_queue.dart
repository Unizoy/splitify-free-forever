import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/sync/row_codec.dart';
import 'package:splitify/data/sync/sync_types.dart';

/// The outbox (04 §2–3): ordered local mutations waiting for `apply_mutations`.
class MutationQueue {
  MutationQueue(this.db);

  final AppDatabase db;

  /// Appends one mutation; call inside the transaction that changed the local row.
  Future<void> enqueue({
    required SyncEntity entity,
    required SyncOp op,
    required String recordId,
    required String groupId,
    required Map<String, Object?> data,
    required String clientUpdatedAt,
    required String createdAt,
  }) => db
      .into(db.outbox)
      .insert(
        OutboxCompanion.insert(
          mutationId: newId(),
          entity: entity.wire,
          op: op.name,
          recordId: recordId,
          groupId: groupId,
          payload: jsonEncode(data),
          clientUpdatedAt: clientUpdatedAt,
          createdAt: createdAt,
        ),
      );

  /// Up to [limit] queued mutations in order. A failed mutation blocks only later ones for the same record.
  Future<List<OutboxItem>> nextBatch([int limit = 50]) {
    final failed = db.selectOnly(db.outbox)
      ..addColumns([db.outbox.recordId])
      ..where(db.outbox.status.equals(OutboxStatus.failed));
    return (db.select(db.outbox)
          ..where((o) => o.status.equals(OutboxStatus.queued) & o.recordId.isNotInQuery(failed))
          ..orderBy([(o) => OrderingTerm.asc(o.seq)])
          ..limit(limit))
        .get();
  }

  /// After a crash mid-push, in-flight items go back to the queue (the server dedupes by `mutation_id`).
  Future<void> resetInFlight() =>
      (db.update(db.outbox)..where((o) => o.status.equals(OutboxStatus.inFlight))).write(
        const OutboxCompanion(status: Value(OutboxStatus.queued)),
      );

  Future<void> markInFlight(List<OutboxItem> items) =>
      (db.update(db.outbox)..where((o) => o.seq.isIn(items.map((i) => i.seq)))).write(
        const OutboxCompanion(status: Value(OutboxStatus.inFlight)),
      );

  /// Network failure: back to the queue with one more attempt counted.
  Future<void> requeue(List<OutboxItem> items, String error) => db.transaction(() async {
    for (final i in items) {
      await (db.update(db.outbox)..where((o) => o.seq.equals(i.seq))).write(
        OutboxCompanion(
          status: const Value(OutboxStatus.queued),
          attempts: Value(i.attempts + 1),
          lastError: Value(error),
        ),
      );
    }
  });

  /// Applied or duplicate: the item is done (the row stays pending until the pull brings its seq).
  Future<void> complete(OutboxItem item) =>
      (db.delete(db.outbox)..where((o) => o.seq.equals(item.seq))).go();

  /// Rejected by the server: item and row are marked failed (Sync issues: retry or discard).
  Future<void> fail(OutboxItem item, String code) async {
    await (db.update(db.outbox)..where((o) => o.seq.equals(item.seq))).write(
      OutboxCompanion(
        status: const Value(OutboxStatus.failed),
        attempts: Value(item.attempts + 1),
        lastError: Value(code),
      ),
    );
    await _setRowState(item, SyncState.failed);
  }

  /// Sync issues → retry.
  Future<void> retry(int seq) => db.transaction(() async {
    final item = await _item(seq);
    if (item == null) return;
    await (db.update(db.outbox)..where((o) => o.seq.equals(seq))).write(
      const OutboxCompanion(status: Value(OutboxStatus.queued)),
    );
    await _setRowState(item, SyncState.pending);
  });

  /// Sync issues → discard: drop the local change and re-pull the group so the server copy comes back.
  Future<void> discard(int seq) => db.transaction(() async {
    final item = await _item(seq);
    if (item == null) return;
    await (db.delete(db.outbox)..where((o) => o.recordId.equals(item.recordId))).go();
    final table = _tableOf(item);
    await db.customUpdate(
      'DELETE FROM "${table.actualTableName}" WHERE id = ? AND seq = 0',
      variables: [Variable<String>(item.recordId)],
      updates: {table},
      updateKind: UpdateKind.delete,
    );
    await _setRowState(item, SyncState.synced);
    await SyncDao(db).setCursor(SyncDao.groupScope(item.groupId), 0);
  });

  /// The JSON object sent to `apply_mutations`.
  Map<String, Object?> toWire(OutboxItem i) {
    final data = jsonDecode(i.payload) as Map<String, Object?>;
    return {
      'mutation_id': i.mutationId,
      'entity': i.entity,
      'op': i.op,
      'id': i.recordId,
      'group_id': i.groupId,
      'base_seq': null,
      'client_updated_at': i.clientUpdatedAt,
      'source': data['source'] ?? 'app',
      'data': data,
    };
  }

  Stream<int> watchCount(String status) {
    final count = db.outbox.seq.count();
    return (db.selectOnly(db.outbox)
          ..addColumns([count])
          ..where(db.outbox.status.equals(status)))
        .map((r) => r.read(count)!)
        .watchSingle();
  }

  Stream<List<OutboxItem>> watchFailed() =>
      (db.select(db.outbox)
            ..where((o) => o.status.equals(OutboxStatus.failed))
            ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
          .watch();

  Future<OutboxItem?> _item(int seq) =>
      (db.select(db.outbox)..where((o) => o.seq.equals(seq))).getSingleOrNull();

  TableInfo<Table, Object?> _tableOf(OutboxItem i) =>
      tableNamed(db, SyncEntity.values.firstWhere((e) => e.wire == i.entity).table);

  Future<void> _setRowState(OutboxItem item, String state) {
    final table = _tableOf(item);
    return db.customUpdate(
      'UPDATE "${table.actualTableName}" SET sync_state = ? WHERE id = ?',
      variables: [Variable<String>(state), Variable<String>(item.recordId)],
      updates: {table},
      updateKind: UpdateKind.update,
    );
  }
}
