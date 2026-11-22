import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_types.dart';

/// A record an import writes: new id + snake_case server columns (with `source`).
typedef ImportWrite = ({String id, Map<String, Object?> data});

/// Keys an import adds to an expense's `split_values` (not member ids; readers skip them, S-190):
/// the batch id, the summary the server turns into `import_completed`, and the "import deleted" note.
const importBatchKey = 'import_batch_id';
const importSummaryKey = 'import_summary';
const importUndoKey = 'import_undo';

/// Imports (X1, phase 18): writes a batch through the normal outbox (offline-sync rule 2) and
/// remembers it on this phone so it can be deleted again (S-190).
class ImportRepository {
  ImportRepository(this.db, this.writer);

  final AppDatabase db;
  final LocalWriter writer;

  /// Writes [payments] then [expenses] (each its own outbox mutation, in order) and records the
  /// batch first, so a crash half-way can still be undone. [onProgress] gets (done, total).
  Future<void> run({
    required String batchId,
    required String groupId,
    required String source,
    required List<ImportWrite> payments,
    required List<ImportWrite> expenses,
    List<String> memberIds = const [],
    String? fileName,
    void Function(int done, int total)? onProgress,
  }) async {
    await db
        .into(db.importBatches)
        .insert(
          ImportBatchesCompanion.insert(
            id: batchId,
            groupId: groupId,
            source: source,
            fileName: Value(fileName),
            expenseIds: Value(jsonEncode([for (final e in expenses) e.id])),
            paymentIds: Value(jsonEncode([for (final p in payments) p.id])),
            memberIds: Value(jsonEncode(memberIds)),
            createdAt: writer.clock.now().toUtc().toIso8601String(),
          ),
        );
    final total = payments.length + expenses.length;
    var done = 0;
    for (final p in payments) {
      await writer.write(SyncEntity.payment, SyncOp.upsert, p.id, groupId, p.data);
      onProgress?.call(++done, total);
    }
    for (final e in expenses) {
      await writer.write(SyncEntity.expense, SyncOp.upsert, e.id, groupId, e.data);
      onProgress?.call(++done, total);
    }
  }

  /// Imports of [groupId] done on this phone that were not deleted, newest first.
  Stream<List<LocalImportBatch>> watchForGroup(String groupId) =>
      (db.select(db.importBatches)
            ..where((b) => b.groupId.equals(groupId) & b.deletedAt.isNull())
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .watch();

  /// How many records of [batchId] are still live (expenses, payments).
  Future<({int expenses, int payments})> liveCounts(String batchId) async {
    final live = await _live(batchId);
    return (expenses: live.expenses.length, payments: live.payments.length);
  }

  /// "Delete this import": soft-deletes every record of the batch that is still live (restorable from
  /// Deleted items, rule 9). The server logs one "import deleted" activity, carried by the first live
  /// expense; with no expense left the payments are deleted as ordinary records. Returns the count.
  Future<int> deleteBatch(String batchId, {void Function(int done, int total)? onProgress}) async {
    final batch = await (db.select(
      db.importBatches,
    )..where((b) => b.id.equals(batchId))).getSingleOrNull();
    if (batch == null) return 0;
    final live = await _live(batchId);
    final source = live.expenses.isEmpty ? 'app' : 'import';
    if (live.expenses.isNotEmpty) {
      final first = live.expenses.first;
      final values = first.splitValues == null
          ? <String, Object?>{}
          : (jsonDecode(first.splitValues!) as Map).cast<String, Object?>();
      await writer.write(SyncEntity.expense, SyncOp.upsert, first.id, batch.groupId, {
        'split_values': {
          ...values,
          importUndoKey: {'expenses': live.expenses.length, 'payments': live.payments.length},
        },
        'source': 'import',
      });
    }
    final total = live.expenses.length + live.payments.length;
    var done = 0;
    for (final e in live.expenses) {
      await writer.write(SyncEntity.expense, SyncOp.delete, e.id, batch.groupId, {
        'source': source,
      });
      onProgress?.call(++done, total);
    }
    for (final p in live.payments) {
      await writer.write(SyncEntity.payment, SyncOp.delete, p.id, batch.groupId, {
        'source': source,
      });
      onProgress?.call(++done, total);
    }
    await (db.update(db.importBatches)..where((b) => b.id.equals(batchId))).write(
      ImportBatchesCompanion(deletedAt: Value(writer.clock.now().toUtc().toIso8601String())),
    );
    return total;
  }

  Future<({List<LocalExpense> expenses, List<LocalPayment> payments})> _live(String batchId) async {
    final batch = await (db.select(
      db.importBatches,
    )..where((b) => b.id.equals(batchId))).getSingleOrNull();
    if (batch == null) return (expenses: <LocalExpense>[], payments: <LocalPayment>[]);
    final expenseIds = (jsonDecode(batch.expenseIds) as List).cast<String>();
    final paymentIds = (jsonDecode(batch.paymentIds) as List).cast<String>();
    final expenses = await (db.select(
      db.expenses,
    )..where((e) => e.id.isIn(expenseIds) & e.deletedAt.isNull())).get();
    final payments = await (db.select(
      db.payments,
    )..where((p) => p.id.isIn(paymentIds) & p.deletedAt.isNull())).get();
    // Keep the import's own order (the first expense carries the undo note).
    final order = {for (var i = 0; i < expenseIds.length; i++) expenseIds[i]: i};
    expenses.sort((a, b) => order[a.id]!.compareTo(order[b.id]!));
    return (expenses: expenses, payments: payments);
  }
}
