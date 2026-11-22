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

  test('schema v4 matches the dumped schema', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
    expect(db.schemaVersion, 4);
  });

  test('v1 -> v4 adds the edit-history cache (phase 12) and the bell tables (phase 13)', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
    expect(await db.select(db.recordVersions).get(), isEmpty);
    expect(await db.select(db.notifications).get(), isEmpty);
  });

  test('v2 -> v4 adds the notifications cache and settings (phase 13)', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
    expect(await db.select(db.notificationSettings).get(), isEmpty);
  });
}
