import 'package:drift/drift.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/expense_parts_dao.dart';
import 'package:splitify/data/sync/mutation_queue.dart';
import 'package:splitify/data/sync/row_codec.dart';
import 'package:splitify/data/sync/server_clock.dart';
import 'package:splitify/data/sync/sync_types.dart';

/// The one write path for features (offline-sync rule 2): a single transaction updates the local row
/// (`sync_state = pending`) and appends the outbox mutation. [onWrite] nudges the engine (debounced there).
class LocalWriter {
  LocalWriter(this.db, this.clock, this.serverClock, {this.onWrite});

  final AppDatabase db;
  final Clock clock;
  final ServerClock serverClock;
  void Function()? onWrite;

  late final MutationQueue _queue = MutationQueue(db);

  /// Upsert/delete/restore of one record. [data] holds snake_case server columns (upsert) and may carry
  /// extra keys for the server only (e.g. `owner_member` on group create); unknown keys never reach Drift.
  /// [alongside] runs inside the same transaction (e.g. queueing a photo upload, phase 10) — never wrap
  /// `write` in an outer transaction: the sync nudge it schedules would keep that transaction's zone.
  Future<void> write(
    SyncEntity entity,
    SyncOp op,
    String id,
    String groupId, [
    Map<String, Object?> data = const {},
    Future<void> Function()? alongside,
  ]) async {
    final cua = (await serverClock.now()).toIso8601String();
    final now = clock.now().toUtc().toIso8601String();
    await db.transaction(() async {
      final table = tableNamed(db, entity.table);
      final row = <String, Object?>{
        if (op == SyncOp.upsert) ...data,
        if (op == SyncOp.delete) 'deleted_at': now,
        if (op == SyncOp.restore) 'deleted_at': null,
        'id': id,
        if (entity != SyncEntity.group) 'group_id': groupId,
        'client_updated_at': cua,
        'sync_state': SyncState.pending,
      };
      final values = columnValues(table, row);
      final exists =
          (await db
              .customSelect(
                'SELECT 1 FROM "${table.actualTableName}" WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .getSingleOrNull()) !=
          null;
      if (exists) {
        final cols = values.keys.where((k) => k != 'id').toList();
        await db.customUpdate(
          'UPDATE "${table.actualTableName}" SET ${cols.map((c) => '"$c" = ?').join(', ')} WHERE id = ?',
          variables: [for (final c in cols) values[c]!, Variable<String>(id)],
          updates: {table},
          updateKind: UpdateKind.update,
        );
      } else {
        await insertRaw(db, table, values);
      }
      if (entity == SyncEntity.expense) await rebuildExpenseParts(db, id);
      await _queue.enqueue(
        entity: entity,
        op: op,
        recordId: id,
        groupId: groupId,
        data: data,
        clientUpdatedAt: cua,
        createdAt: now,
      );
      if (alongside != null) await alongside();
    });
    onWrite?.call();
  }

  /// Local-only row the server creates itself (the owner member of a new group); replaced by the pull.
  Future<void> writeShadow(SyncEntity entity, Map<String, Object?> row) async {
    final table = tableNamed(db, entity.table);
    await insertRaw(
      db,
      table,
      columnValues(table, {...row, 'sync_state': SyncState.pending}),
      replace: true,
    );
  }
}
