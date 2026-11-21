import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';

/// Cursors (`group:<id>` / `user`) and key/value sync metadata.
class SyncDao {
  SyncDao(this.db);

  final AppDatabase db;

  static const userScope = 'user';
  static String groupScope(String id) => 'group:$id';

  Future<String?> meta(String key) async =>
      (await (db.select(db.syncMeta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setMeta(String key, String value) =>
      db.into(db.syncMeta).insertOnConflictUpdate(SyncMetaEntry(key: key, value: value));

  Stream<String?> watchMeta(String key) => (db.select(
    db.syncMeta,
  )..where((m) => m.key.equals(key))).watchSingleOrNull().map((m) => m?.value);

  /// Group id → cursor.
  Future<Map<String, int>> groupCursors() async {
    final rows = await (db.select(db.syncCursors)..where((c) => c.scope.like('group:%'))).get();
    return {for (final r in rows) r.scope.substring(6): r.seq};
  }

  Future<int> userCursor() async =>
      (await (db.select(
        db.syncCursors,
      )..where((c) => c.scope.equals(userScope))).getSingleOrNull())?.seq ??
      0;

  Future<void> setCursor(String scope, int seq) =>
      db.into(db.syncCursors).insertOnConflictUpdate(SyncCursor(scope: scope, seq: seq));
}
