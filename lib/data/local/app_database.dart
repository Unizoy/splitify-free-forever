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
  int get schemaVersion => 11;

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
      // v7 (phase 18): imports done on this phone.
      if (from < 7) {
        await m.createTable(importBatches);
        await m.createIndex(importBatchesGroup);
      }
      // v8 (phase 18b) added the local-only `payment_captures` table of the payment bubble; v9 drops it again,
      // so a phone below v8 has nothing to create.
      // v9 (D-030, S-293): the payment bubble is off main; its table (and its index) goes. Nothing in it was ever
      // synced.
      if (from < 9) await m.deleteTable('payment_captures');
      // v10 (D-034 WP-C, 0026): trip dates, settle-up reminders and the group notes on `groups`. Existing rows
      // get them with the next pull (null = not set / reminders off).
      if (from < 10) {
        await m.addColumn(groups, groups.tripStartsOn);
        await m.addColumn(groups, groups.tripEndsOn);
        await m.addColumn(groups, groups.settleReminder);
        await m.addColumn(groups, groups.whiteboard);
      }
      // v11 (W2-Y, 0029, S-431): several photos and PDFs per expense. An older app already pulled (and skipped)
      // attachments other phones added, so every group is pulled once more from the start (rows are upserts).
      if (from < 11) {
        await m.createTable(expenseAttachments);
        await m.createIndex(expenseAttachmentsExpense);
        await customStatement("UPDATE sync_cursors SET seq = 0 WHERE scope LIKE 'group:%'");
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
