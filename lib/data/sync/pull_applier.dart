import 'package:drift/drift.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/expense_parts_dao.dart';
import 'package:splitify/data/local/daos/search_index_dao.dart';
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
    'expense_attachments',
    'payments',
    'comments',
    'recurring_templates',
    'activity',
    'profiles',
  ];
  static const _groupScoped = [
    'group_members',
    'expenses',
    'expense_attachments',
    'payments',
    'comments',
    'recurring_templates',
    'activity',
    'expense_parts',
    'record_versions',
    'expense_search',
  ];

  Future<void> apply(PullPage page) => db.transaction(() async {
    final dao = SyncDao(db);
    for (final g in page.lostGroups) {
      await forgetGroup(g);
    }
    final pending = {for (final o in await db.select(db.outbox).get()) o.recordId};
    final indexExpenses = <String, String>{}; // expense id -> group id
    final indexGroups = <String>{};
    final profiles = <String>[];
    for (final name in tables) {
      final table = tableNamed(db, name);
      final hasState = table.$columns.any((c) => c.name == 'sync_state');
      for (final row in page.rows[name] ?? const <Map<String, Object?>>[]) {
        final id = row['id']! as String;
        if (pending.contains(id)) continue;
        final values = columnValues(table, row);
        // 0028 (W2-X F11): the server keeps an ad-hoc group as type 'other' + is_adhoc; the phone as 'adhoc'.
        if (name == 'groups' && row['is_adhoc'] == true)
          values['type'] = const Variable<Object>('adhoc');
        if (hasState) values['sync_state'] = const Variable<Object>(SyncState.synced);
        await insertRaw(db, table, values, replace: true);
        if (name == 'expenses') {
          await rebuildExpenseParts(db, id);
          indexExpenses[id] = row['group_id']! as String;
        }
        if (name == 'group_members') indexGroups.add(row['group_id']! as String);
        if (name == 'profiles') profiles.add(id);
      }
    }
    // Offline search (#34): new names re-index their groups, other pulled expenses one by one.
    if (profiles.isNotEmpty) {
      final linked = await (db.select(
        db.groupMembers,
      )..where((m) => m.userId.isIn(profiles))).get();
      indexGroups.addAll(linked.map((m) => m.groupId));
    }
    await SearchIndex.groups(db, indexGroups);
    await SearchIndex.expenses(db, [
      for (final e in indexExpenses.entries)
        if (!indexGroups.contains(e.value)) e.key,
    ]);
    for (final e in page.nextCursors.entries) {
      if (page.lostGroups.contains(e.key)) continue;
      await dao.setCursor(SyncDao.groupScope(e.key), e.value);
    }
    await dao.setCursor(SyncDao.userScope, page.userSeq);
  });

  /// Lost access to a group: its local rows, outbox items, waiting uploads and cursor go.
  Future<void> forgetGroup(String groupId) async {
    // R4 (S-461): uploads for its records (cover, receipts, attachments) would only be refused from now on,
    // retried until skipped and then listed in "Sync & storage" for good.
    await db.customUpdate(
      'DELETE FROM pending_uploads WHERE record_id = ?1 '
      'OR record_id IN (SELECT id FROM expenses WHERE group_id = ?1) '
      'OR record_id IN (SELECT id FROM expense_attachments WHERE group_id = ?1)',
      variables: [Variable<String>(groupId)],
      updates: {db.pendingUploads},
      updateKind: UpdateKind.delete,
    );
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
