// Drift schema harness (04 §2): the live schema must equal the dumped drift_schemas/drift_schema_v<N>.json.
// Each new schema version adds a dump (`dart run drift_dev schema dump ...`), regenerates
// test/data/local/generated and a step test here.
import 'package:drift/drift.dart' show Variable;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';

import 'generated/schema.dart';

/// Whether the phone's database has a table or index called [name].
Future<bool> _has(AppDatabase db, String name) async =>
    (await db
            .customSelect(
              'SELECT name FROM sqlite_master WHERE name = ?',
              variables: [Variable(name)],
            )
            .get())
        .isNotEmpty;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema v10 matches the dumped schema', () async {
    final connection = await verifier.startAt(10);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    expect(db.schemaVersion, 10);
  });

  test('v9 -> v10 adds trip dates, settle-up reminders and the group notes (D-034 WP-C)', () async {
    final schema = await verifier.schemaAt(9);
    schema.rawDatabase.execute(
      "INSERT INTO \"groups\" (id, name, type, seq, sync_state) VALUES ('g1', 'Goa trip', 'trip', 4, 'synced')",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    final g = (await db.select(db.groups).get()).single;
    expect((g.name, g.type, g.seq), ('Goa trip', 'trip', 4));
    expect(
      (g.tripStartsOn, g.tripEndsOn, g.settleReminder, g.whiteboard),
      (null, null, null, null),
    );
    await db.customStatement(
      "UPDATE \"groups\" SET trip_starts_on = '2026-12-12', trip_ends_on = '2026-12-18', "
      "settle_reminder = 'weekly', whiteboard = 'Wi-Fi: goa2026' WHERE id = 'g1'",
    );
    final edited = (await db.select(db.groups).get()).single;
    expect(
      (edited.tripStartsOn, edited.tripEndsOn, edited.settleReminder, edited.whiteboard),
      ('2026-12-12', '2026-12-18', 'weekly', 'Wi-Fi: goa2026'),
    );
  });

  test('v8 -> v10 drops the payment bubble\'s local table and keeps the rest (D-030)', () async {
    final schema = await verifier.schemaAt(8);
    schema.rawDatabase
      ..execute("INSERT INTO \"groups\" (id, name) VALUES ('g1', 'Flat')")
      ..execute(
        'INSERT INTO payment_captures (id, amount, app_package, app_name, source, captured_at) '
        "VALUES ('c1', 50000, 'com.phonepe.app', 'PhonePe', 'notification', '2026-11-20T08:30:00Z')",
      );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    expect(await _has(db, 'payment_captures'), isFalse);
    expect(await _has(db, 'payment_captures_time'), isFalse);
    expect((await db.select(db.groups).get()).single.name, 'Flat');
  });

  test('v7 -> v10 never leaves the payment bubble\'s table behind', () async {
    final connection = await verifier.startAt(7);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    expect(await _has(db, 'payment_captures'), isFalse);
    expect(await db.select(db.importBatches).get(), isEmpty);
  });

  test('v6 -> v10 adds the import batches (phase 18)', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    expect(await db.select(db.importBatches).get(), isEmpty);
  });

  test(
    'v5 -> v10 adds recurring templates and fills the rebuilt search table (phase 16)',
    () async {
      final schema = await verifier.schemaAt(5);
      schema.rawDatabase
        ..execute("INSERT INTO \"groups\" (id, name) VALUES ('g1', 'Flat')")
        ..execute(
          "INSERT INTO group_members (id, group_id, display_name) VALUES ('m1', 'g1', 'Asha')",
        )
        ..execute(
          'INSERT INTO expenses (id, group_id, description, date, currency, total, payers, shares) '
          "VALUES ('e1', 'g1', 'Dinner', '2026-11-01', 'INR', 120000, '{\"m1\":120000}', '{\"m1\":120000}')",
        );
      final connection = schema.newConnection();
      final db = AppDatabase(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 10);
      expect(await db.select(db.recurringTemplates).get(), isEmpty);
      final rows = await db.customSelect('SELECT * FROM expense_search').get();
      expect(rows, hasLength(1));
      expect(rows.single.read<String>('expense_id'), 'e1');
      expect(rows.single.read<String>('member_names'), 'Asha');
      expect(rows.single.read<String>('amount_text'), '1200 1,200');
    },
  );

  test('v1 -> v10 adds the history (12), bell (13) and exchange-rate (14) caches', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    expect(await db.select(db.recordVersions).get(), isEmpty);
    expect(await db.select(db.notifications).get(), isEmpty);
    expect(await db.select(db.fxRates).get(), isEmpty);
  });

  test(
    'v2 -> v10 adds the notifications cache and settings (phase 13) and rates (phase 14)',
    () async {
      final connection = await verifier.startAt(2);
      final db = AppDatabase(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 10);
      expect(await db.select(db.notificationSettings).get(), isEmpty);
      expect(await db.select(db.fxRates).get(), isEmpty);
    },
  );

  test('v4 -> v10 adds the exchange-rate cache (phase 14)', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    expect(await db.select(db.fxRates).get(), isEmpty);
  });
}
