// Drift schema harness (04 §2): the live schema must equal the dumped drift_schemas/drift_schema_v<N>.json.
// Each new schema version adds a dump (`dart run drift_dev schema dump ...`), regenerates
// test/data/local/generated and a step test here.
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema v5 matches the dumped schema', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
    expect(db.schemaVersion, 5);
  });

  test('v1 -> v5 adds the history (12), bell (13) and exchange-rate (14) caches', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
    expect(await db.select(db.recordVersions).get(), isEmpty);
    expect(await db.select(db.notifications).get(), isEmpty);
    expect(await db.select(db.fxRates).get(), isEmpty);
  });

  test(
    'v2 -> v5 adds the notifications cache and settings (phase 13) and rates (phase 14)',
    () async {
      final connection = await verifier.startAt(2);
      final db = AppDatabase(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 5);
      expect(await db.select(db.notificationSettings).get(), isEmpty);
      expect(await db.select(db.fxRates).get(), isEmpty);
    },
  );

  test('v4 -> v5 adds the exchange-rate cache (phase 14)', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
    expect(await db.select(db.fxRates).get(), isEmpty);
  });
}
