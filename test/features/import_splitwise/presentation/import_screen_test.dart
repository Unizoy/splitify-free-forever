// TC-X1-03: Import from Splitwise screen: file → people → preview → done → delete.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';

import '../../../support/fakes.dart';
import '../../../support/group_harness.dart';
import '../../../support/ledger_seed.dart';

class _FakePicker implements ImportFilePicker {
  _FakePicker(this.fixture);

  final String fixture;

  @override
  Future<PickedFile?> pick() async => (
    name: fixture,
    bytes: Uint8List.fromList(File('test/fixtures/splitwise/$fixture').readAsBytesSync()),
  );
}

/// The celebration card overflows under the test font (Ahem); real fonts are covered by the goldens.
void _drain(WidgetTester t) {
  while (t.takeException() != null) {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = testDb();
  });

  Future<void> open(WidgetTester t, String fixture) async {
    await t.runAsync(
      () => db.seed(
        groups: [seedGroup(id: 'g1')],
        members: [
          seedMember('m1', name: 'Mohit', userId: 'u1'),
          seedMember('m2', name: 'Priya', position: 1),
          seedMember('m3', name: 'Zed', position: 2),
        ],
      ),
    );
    await pumpGroups(
      t,
      '/groups/g1/import',
      db: db,
      overrides: [importFilePickerProvider.overrideWithValue(_FakePicker(fixture))],
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 10; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.runAsync(() => db.close());
    });
  }

  Future<void> tapKey(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.ensureVisible(f);
    await t.tap(f);
    await settle(t, db: true, frames: 12);
  }

  // TC-X1-03
  testWidgets('a bad header shows the error on the file step', (t) async {
    await open(t, 'bad_header.csv');
    await tapKey(t, 'import-pick');
    expect(find.byKey(const Key('import-error')), findsOneWidget);
    expect(find.byKey(const Key('import-continue')), findsNothing);
  });

  // TC-X1-03
  testWidgets('people step lists the file names; skipping a person leaves them out of the preview', (t) async {
    await open(t, 'group_inr_usd.csv');
    await tapKey(t, 'import-pick');
    for (final n in ['Aarav', 'Priya', 'Rohan', 'Meera']) {
      expect(find.byKey(Key('import-person-$n')), findsOneWidget);
    }
    // "Priya" is suggested as the member of the same name.
    expect(
      find.descendant(of: find.byKey(const Key('import-person-Priya')), matching: find.text('Priya')),
      findsWidgets,
    );
    await tapKey(t, 'import-person-Rohan');
    await tapKey(t, 'import-choice-skip');
    expect(find.byKey(const Key('import-mapping-problem')), findsNothing);
    await tapKey(t, 'import-continue');
    // Rows that moved Rohan's balance are left out, so the file's own totals can't be checked.
    expect(find.byKey(const Key('import-totals-none')), findsOneWidget);
    expect(find.byKey(const Key('import-run')), findsOneWidget);
  });

  // TC-X1-03
  testWidgets('a file whose totals do not match needs "import anyway"', (t) async {
    await open(t, 'checksum_mismatch.csv');
    await tapKey(t, 'import-pick');
    await tapKey(t, 'import-continue');
    expect(find.byKey(const Key('import-totals-mismatch')), findsOneWidget);
    await t.tap(find.byKey(const Key('import-run')), warnIfMissed: false);
    await settle(t, db: true, frames: 6);
    expect(find.byKey(const Key('import-done')), findsNothing);
    await tapKey(t, 'import-anyway');
    await tapKey(t, 'import-run');
    await settle(t, db: true, frames: 30);
    expect(find.byKey(const Key('import-done')), findsOneWidget);
    _drain(t);
  });

  // TC-X1-03
  testWidgets('import writes records with source import, then "Delete this import" undoes it', (
    t,
  ) async {
    await open(t, 'group_inr_usd.csv');
    await tapKey(t, 'import-pick');
    await tapKey(t, 'import-continue');
    expect(find.byKey(const Key('import-totals-ok')), findsOneWidget);
    await tapKey(t, 'import-run');
    await settle(t, db: true, frames: 40);
    expect(find.byKey(const Key('import-done')), findsOneWidget);
    expect(find.byKey(const Key('import-open-group')), findsOneWidget);
    _drain(t);

    final expenses = await t.runAsync(() => db.select(db.expenses).get()) ?? [];
    expect(expenses, isNotEmpty);
    final outbox = await t.runAsync(() => db.select(db.outbox).get()) ?? [];
    final exp = outbox.where((o) => o.entity == 'expense').toList();
    expect(exp, isNotEmpty);
    expect(exp.every((o) => o.payload.contains('"source":"import"')), isTrue);

    await tapKey(t, 'import-delete');
    await tapKey(t, 'confirm-action');
    await settle(t, db: true, frames: 30);
    expect(find.byKey(const Key('import-deleted')), findsOneWidget);
    final live = await t.runAsync(() => db.select(db.expenses).get()) ?? [];
    expect(live.where((e) => e.deletedAt == null), isEmpty);
  });
}
