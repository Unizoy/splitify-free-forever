// D-033 (minimal flows like Splitwise): the one import setup screen (file, "Import into" from Account, people),
// Preview import, Back from the preview, Change file.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';
import 'package:splitify/ui/components/components.dart' show PillButton;

import '../../../support/fakes.dart';
import '../../../support/group_harness.dart';
import '../../../support/ledger_seed.dart';

class _Picker implements ImportFilePicker {
  _Picker(this.fixtures);

  /// Files handed out in turn (the last one repeats).
  final List<String> fixtures;
  var _i = 0;

  @override
  Future<PickedFile?> pick() async {
    final name = fixtures[_i < fixtures.length ? _i++ : fixtures.length - 1];
    return (
      name: name,
      bytes: Uint8List.fromList(File('test/fixtures/splitwise/$name').readAsBytesSync()),
    );
  }
}

Finder _key(String k) => find.byKey(Key(k));

Finder _nameField() =>
    find.descendant(of: _key('import-group-name'), matching: find.byType(TextField));

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = testDb();
  });

  Future<void> open(WidgetTester t, String location, List<String> files) async {
    await t.runAsync(
      () => db.seed(
        groups: [
          seedGroup(id: 'g1', name: 'Goa trip'),
          seedGroup(id: 'g2', name: 'Flat 4B'),
          seedGroup(id: 'g3', name: 'Old trip', archivedAt: '2026-11-01T00:00:00Z'),
        ],
        members: [
          seedMember('m1', name: 'Mohit', userId: 'u1'),
          seedMember('m2', name: 'Priya', position: 1),
          seedMember('m3', name: 'Zed', position: 2),
          seedMember('n1', groupId: 'g2', name: 'Mohit', userId: 'u1'),
          seedMember('n2', groupId: 'g2', name: 'Kiran', position: 1),
        ],
      ),
    );
    await pumpGroups(
      t,
      location,
      db: db,
      overrides: [importFilePickerProvider.overrideWithValue(_Picker(files))],
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

  Future<void> tapKey(WidgetTester t, String key, {int frames = 12}) async {
    final f = _key(key);
    await t.ensureVisible(f);
    await t.tap(f);
    await settle(t, db: true, frames: frames);
  }

  VoidCallback? continueAction(WidgetTester t) =>
      t.widget<PillButton>(_key('import-continue')).onPressed;

  Finder inRow(String person, Finder what) =>
      find.descendant(of: _key('import-person-$person'), matching: what);

  group('D-033 import from a group', () {
    // D-033
    testWidgets(
      'D-033 pick leads to ONE setup screen with the file, the people and Preview import',
      (t) async {
        await open(t, '/groups/g1/import', ['group_inr_usd.csv']);
        await tapKey(t, 'import-pick');
        expect(_key('import-setup'), findsOneWidget);
        expect(_key('import-file'), findsOneWidget);
        expect(
          find.descendant(of: _key('import-file'), matching: find.text('group_inr_usd.csv')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _key('import-file'), matching: find.text('8 rows · INR, USD')),
          findsOneWidget,
        );
        expect(_key('import-change-file'), findsOneWidget);
        for (final n in ['Aarav', 'Priya', 'Rohan', 'Meera']) {
          expect(_key('import-person-$n'), findsOneWidget);
        }
        expect(_key('import-continue'), findsOneWidget);
        expect(find.text('Preview import'), findsOneWidget);
        // No group chooser from a group.
        expect(find.text('IMPORT INTO'), findsNothing);
        expect(_key('import-new-group'), findsNothing);
        expect(_key('import-group-name'), findsNothing);
        expect(_key('import-group-g1'), findsNothing);
      },
    );

    // D-033
    testWidgets('D-033 Back from the preview returns to the setup screen with the mapping kept', (
      t,
    ) async {
      await open(t, '/groups/g1/import', ['group_inr_usd.csv']);
      await tapKey(t, 'import-pick');
      await tapKey(t, 'import-person-Rohan');
      await tapKey(t, 'import-choice-skip');
      expect(inRow('Rohan', find.text('Skipped')), findsOneWidget);

      await tapKey(t, 'import-continue');
      expect(_key('import-summary'), findsOneWidget);
      expect(_key('import-setup'), findsNothing);

      await t.tap(find.byTooltip('Back'));
      await settle(t, db: true, frames: 12);
      expect(_key('import-setup'), findsOneWidget);
      expect(_key('import-summary'), findsNothing);
      expect(inRow('Rohan', find.text('Skipped')), findsOneWidget);
    });

    // D-033
    testWidgets('D-033 Change file with a bad file returns to the file step with the error', (
      t,
    ) async {
      await open(t, '/groups/g1/import', ['group_inr_usd.csv', 'bad_header.csv']);
      await tapKey(t, 'import-pick');
      expect(_key('import-setup'), findsOneWidget);
      await tapKey(t, 'import-change-file');
      expect(_key('import-error'), findsOneWidget);
      expect(_key('import-setup'), findsNothing);
      expect(_key('import-pick'), findsOneWidget);
    });

    // D-033
    testWidgets('D-033 Change file with another good file stays on the setup screen', (t) async {
      await open(t, '/groups/g1/import', ['group_inr_usd.csv', 'checksum_mismatch.csv']);
      await tapKey(t, 'import-pick');
      await tapKey(t, 'import-change-file');
      expect(_key('import-setup'), findsOneWidget);
      expect(
        find.descendant(of: _key('import-file'), matching: find.text('checksum_mismatch.csv')),
        findsOneWidget,
      );
    });
  });

  group('D-033 import from Account', () {
    // D-033
    testWidgets(
      'D-033 after the pick: "Import into", New group selected, name prefilled, one chip per live group',
      (t) async {
        await open(t, '/account/import', ['group_inr_usd.csv']);
        await tapKey(t, 'import-pick');
        expect(_key('import-setup'), findsOneWidget);
        expect(find.text('IMPORT INTO'), findsOneWidget);
        expect(_key('import-new-group'), findsOneWidget);
        expect(t.widget<TextField>(_nameField()).controller!.text, 'Group inr usd');
        expect(_key('import-group-g1'), findsOneWidget);
        expect(_key('import-group-g2'), findsOneWidget);
        // Archived groups are not offered.
        expect(_key('import-group-g3'), findsNothing);
        expect(continueAction(t), isNotNull);
      },
    );

    // D-033
    testWidgets('D-033 clearing the group name disables Preview import; typing a name enables it', (
      t,
    ) async {
      await open(t, '/account/import', ['group_inr_usd.csv']);
      await tapKey(t, 'import-pick');
      await t.enterText(_nameField(), '');
      await t.pump();
      expect(continueAction(t), isNull);
      await t.enterText(_nameField(), 'Goa');
      await t.pump();
      expect(continueAction(t), isNotNull);
      await t.enterText(_nameField(), 'a' * 61);
      await t.pump();
      expect(continueAction(t), isNull);
      expect(find.text('Use up to 60 characters'), findsOneWidget);
    });

    // D-033
    testWidgets(
      'D-033 an existing group chip switches the people to its members and hides the name; New group returns',
      (t) async {
        await open(t, '/account/import', ['group_inr_usd.csv']);
        await tapKey(t, 'import-pick');
        // New group: the only choice for "you" is the placeholder member.
        await tapKey(t, 'import-person-Aarav');
        expect(_key('import-choice-_me'), findsOneWidget);
        expect(_key('import-choice-m2'), findsNothing);
        await tapKey(t, 'import-choice-skip');

        await tapKey(t, 'import-group-g1');
        expect(_key('import-group-name'), findsNothing);
        // "Priya" is matched to the group's member of that name.
        expect(inRow('Priya', find.text('Priya')), findsWidgets);
        await tapKey(t, 'import-person-Aarav');
        expect(_key('import-choice-m2'), findsOneWidget);
        expect(_key('import-choice-m3'), findsOneWidget);
        expect(_key('import-choice-_me'), findsNothing);
        await tapKey(t, 'import-choice-skip');

        await tapKey(t, 'import-new-group');
        expect(_key('import-group-name'), findsOneWidget);
        expect(t.widget<TextField>(_nameField()).controller!.text, 'Group inr usd');
        await tapKey(t, 'import-person-Aarav');
        expect(_key('import-choice-_me'), findsOneWidget);
        expect(_key('import-choice-m2'), findsNothing);
      },
    );

    // D-033
    testWidgets(
      'D-033 import into a new group end to end: the group exists locally, expenses are in the outbox',
      (t) async {
        await open(t, '/account/import', ['group_inr_usd.csv']);
        await tapKey(t, 'import-pick');
        await t.enterText(_nameField(), 'Flat trip');
        await t.pump();
        await tapKey(t, 'import-continue');
        expect(_key('import-totals-ok'), findsOneWidget);
        await tapKey(t, 'import-run', frames: 40);
        await settle(t, db: true, frames: 30);
        expect(_key('import-done'), findsOneWidget);

        final groups = await t.runAsync(() => db.select(db.groups).get()) ?? [];
        final made = groups.where((g) => g.name == 'Flat trip').toList();
        expect(made, hasLength(1));
        final expenses = await t.runAsync(() => db.select(db.expenses).get()) ?? [];
        expect(expenses.where((e) => e.groupId == made.single.id), isNotEmpty);
        final outbox = await t.runAsync(() => db.select(db.outbox).get()) ?? [];
        final exp = outbox.where((o) => o.entity == 'expense').toList();
        expect(exp, isNotEmpty);
        expect(exp.every((o) => o.payload.contains('"source":"import"')), isTrue);
        expect(outbox.any((o) => o.entity == 'group' && o.recordId == made.single.id), isTrue);
      },
    );
  });
}
