import 'package:drift/drift.dart';
import 'package:splitify/data/local/daos/search_index_dao.dart';

part 'app_database.g.dart';

/// The phone's local database (planning/04-sync-engine.md §2). Local truth for display; the sync engine keeps it
/// in step with the server. Schema changes bump [schemaVersion] with a step migration and a dumped schema in
/// `drift_schemas/` (tested by `test/data/local/migration_test.dart`).
@DriftDatabase(include: {'tables/schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 (phase 12): edit-history cache.
      if (from < 2) {
        await m.createTable(recordVersions);
        await m.createIndex(recordVersionsRecord);
      }
      // v4 (phase 13): bell cache + notification settings. (v3 was never used.)
      if (from < 4) {
        await m.createTable(notifications);
        await m.createIndex(notificationsSeq);
        await m.createTable(notificationSettings);
      }
      // v5 (phase 14): exchange-rate cache.
      if (from < 5) {
        await m.createTable(fxRates);
        await m.createIndex(fxRatesCurrencyDate);
      }
      // v6 (phase 16): recurring templates; the search table gains expense/group ids and is filled.
      if (from < 6) {
        await m.createTable(recurringTemplates);
        await m.createIndex(recurringTemplatesGroup);
        await m.createIndex(recurringTemplatesExpense);
        await m.deleteTable('expense_search');
        await m.create(expenseSearch);
        await SearchIndex.all(this);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Deletes every row (sign-out by a different user, 04 §7).
  Future<void> wipe() => transaction(() async {
    for (final t in allTables) {
      await delete(t).go();
    }
  });
}
