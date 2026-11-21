import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/expense_parts_dao.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/sync/row_codec.dart';
import 'package:splitify/data/sync/sync_types.dart';

/// Stores one `pull_changes` page in one transaction (04 §4): rows upserted by id unless the row has a local
/// outbox mutation (pending edits win locally until pushed), expense parts rebuilt, cursors advanced last.
class PullApplier {
  PullApplier(this.db);

  final AppDatabase db;

  /// Parent tables first.
  static const tables = [
    'groups',
    'group_members',
    'expenses',
    'payments',
    'comments',
    'activity',
    'profiles',
  ];
  static const _groupScoped = [
    'group_members',
    'expenses',
    'payments',
    'comments',
    'activity',
    'expense_parts',
  ];

  Future<void> apply(PullPage page) => db.transaction(() async {
    final dao = SyncDao(db);
    for (final g in page.lostGroups) {
      await forgetGroup(g);
    }
    final pending = {for (final o in await db.select(db.outbox).get()) o.recordId};
    for (final name in tables) {
      final table = tableNamed(db, name);
      final hasState = table.$columns.any((c) => c.name == 'sync_state');
      for (final row in page.rows[name] ?? const <Map<String, Object?>>[]) {
        final id = row['id']! as String;
        if (pending.contains(id)) continue;
        final values = columnValues(table, row);
        if (hasState) values['sync_state'] = const Variable<Object>(SyncState.synced);
        await insertRaw(db, table, values, replace: true);
        if (name == 'expenses') await rebuildExpenseParts(db, id);
      }
    }
    for (final e in page.nextCursors.entries) {
      if (page.lostGroups.contains(e.key)) continue;
      await dao.setCursor(SyncDao.groupScope(e.key), e.value);
    }
    await dao.setCursor(SyncDao.userScope, page.userSeq);
  });

  /// Lost access to a group: its local rows, outbox items and cursor go.
  Future<void> forgetGroup(String groupId) async {
    for (final name in _groupScoped) {
      await db.customUpdate(
        'DELETE FROM "$name" WHERE group_id = ?',
        variables: [Variable<String>(groupId)],
        updates: {tableNamed(db, name)},
        updateKind: UpdateKind.delete,
      );
    }
    await (db.delete(db.groups)..where((g) => g.id.equals(groupId))).go();
    await (db.delete(db.outbox)..where((o) => o.groupId.equals(groupId))).go();
    await (db.delete(
      db.syncCursors,
    )..where((c) => c.scope.equals(SyncDao.groupScope(groupId)))).go();
  }
}
