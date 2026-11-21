import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The phone's local database (planning/04-sync-engine.md §2). Local truth for display; the sync engine keeps it
/// in step with the server. Schema changes bump [schemaVersion] with a step migration and a dumped schema in
/// `drift_schemas/` (tested by `test/data/local/migration_test.dart`).
@DriftDatabase(include: {'tables/schema.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
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
