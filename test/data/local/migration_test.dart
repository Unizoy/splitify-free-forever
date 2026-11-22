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

  test('schema v3 matches the dumped schema', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
    expect(db.schemaVersion, 3);
  });

  test('v1 -> v3 adds the edit-history and exchange-rate caches (phases 12, 14)', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
    expect(await db.select(db.recordVersions).get(), isEmpty);
    expect(await db.select(db.fxRates).get(), isEmpty);
  });

  test('v2 -> v3 adds the exchange-rate cache (phase 14)', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
    expect(await db.select(db.fxRates).get(), isEmpty);
  });
}
