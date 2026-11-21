import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/history_remote.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/row_codec.dart';

/// Edit history (08 #20, S-130): `record_versions` of one record, cached in Drift so a history once seen
/// stays readable offline. Versions are append-only on the server, so only newer ones are fetched.
class HistoryRepository {
  HistoryRepository(this.db, this.remote);

  final AppDatabase db;
  final HistoryRemote remote;

  /// Cached versions of [recordId], oldest first.
  Stream<List<LocalVersion>> watch(String recordId) =>
      (db.select(db.recordVersions)
            ..where((v) => v.recordId.equals(recordId))
            ..orderBy([(v) => OrderingTerm.asc(v.seq), (v) => OrderingTerm.asc(v.id)]))
          .watch();

  /// Fetches the versions of [recordId] newer than the cache and stores them; returns how many arrived.
  /// Throws the remote's exceptions (offline → `NetworkException`); the cache stays as it was.
  Future<int> refresh(String recordId) async {
    final max = db.recordVersions.seq.max();
    final row =
        await (db.selectOnly(db.recordVersions)
              ..addColumns([max])
              ..where(db.recordVersions.recordId.equals(recordId)))
            .getSingle();
    final rows = await remote.versions(recordId, afterSeq: row.read(max) ?? 0);
    if (rows.isEmpty) return 0;
    await db.transaction(() async {
      for (final r in rows) {
        await insertRaw(db, db.recordVersions, columnValues(db.recordVersions, r), replace: true);
      }
    });
    return rows.length;
  }
}

/// Deleted items of a group (08 #20 "Deleted items"): soft-deleted rows stay on the phone as tombstones.
extension DeletedExpenseReads on ExpensesRepository {
  /// Deleted expenses of [groupId], most recently deleted first.
  Stream<List<LocalExpense>> watchDeleted(String groupId) =>
      (db.select(db.expenses)
            ..where((e) => e.groupId.equals(groupId) & e.deletedAt.isNotNull())
            ..orderBy([(e) => OrderingTerm.desc(e.deletedAt), (e) => OrderingTerm.desc(e.id)]))
          .watch();
}

extension HistoryPaymentReads on PaymentsRepository {
  /// Deleted payments of [groupId], most recently deleted first.
  Stream<List<LocalPayment>> watchDeleted(String groupId) =>
      (db.select(db.payments)
            ..where((p) => p.groupId.equals(groupId) & p.deletedAt.isNotNull())
            ..orderBy([(p) => OrderingTerm.desc(p.deletedAt), (p) => OrderingTerm.desc(p.id)]))
          .watch();

  /// One payment as stored on this phone (deleted ones too), for its history.
  Stream<LocalPayment?> watchPayment(String id) =>
      (db.select(db.payments)..where((p) => p.id.equals(id))).watchSingleOrNull();
}

/// Comment writes (08 #13): the author and time are kept on the local row so the thread shows "you" and the
/// delete action before the server has the comment (the server sets both itself).
extension CommentWrites on CommentsRepository {
  Future<String> add({
    required String groupId,
    required String targetType,
    required String targetId,
    required String body,
    String? authorId,
  }) => save(groupId, {
    'target_type': targetType,
    'target_id': targetId,
    'body': body,
    'created_at': writer.clock.now().toUtc().toIso8601String(),
    'created_by': ?authorId,
  });
}
