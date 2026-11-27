// TC-29 UI: group cover photo in the group form (S-073) and the "Record a loan" button on the group page.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/ui/components/components.dart' show OptionTile;

import '../../../support/group_fakes.dart';
import '../../../support/group_harness.dart';
import '../../../support/photo_fixtures.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester t, String key) async {
  if (_key(key).evaluate().isEmpty) {
    await t.scrollUntilVisible(_key(key), 300, scrollable: find.byType(Scrollable).first);
  }
  await t.ensureVisible(_key(key));
  await t.pump();
  await t.tap(_key(key));
  await settle(t);
}

/// Group actions that only record what the form asked for.
class _SpyActions extends GroupActions {
  _SpyActions(super.ref, this.calls);

  final List<String> calls;

  @override
  Future<String> create({
    required String name,
    required String type,
    required String currency,
    required String ownerName,
    String? id,
  }) async {
    calls.add('create $name');
    return id ?? 'new';
  }

  @override
  Future<void> update(
    String id, {
    required String name,
    required String type,
    required String currency,
  }) async => calls.add('update $id $name');

  @override
  Future<void> setCoverPhoto(String id, PreparedImage image, {String? oldPath}) async =>
      calls.add('setCoverPhoto $id old=$oldPath');

  @override
  Future<void> useGeneratedCover(String id, {String? oldPath}) async =>
      calls.add('useGeneratedCover $id old=$oldPath');
}

const _photoPath = 'g1/c1.jpg';

LocalGroup _photoGroup() =>
    sampleGroup(id: 'g1').copyWith(coverKind: 'photo', coverPath: const Value(_photoPath));

Future<List<String>> _pumpForm(WidgetTester t, String location, {LocalGroup? group}) async {
  final calls = <String>[];
  final file = samplePhotoFile(addTearDown);
  await pumpGroups(
    t,
    location,
    overrides: [
      ...fixedGroupData(groups: [?group]),
      groupActionsProvider.overrideWith((ref) => _SpyActions(ref, calls)),
      pickerReturns(samplePrepared),
      storedPhotoProvider((bucket: MediaBuckets.groupCovers, path: _photoPath, thumb: false))
          .overrideWith((ref) async => file),
    ],
  );
  return calls;
}

void main() {
  // D-033: the cover is a small tile beside the name; tapping it opens the cover sheet.
  group('Group form cover', () {
    Future<void> openSheet(WidgetTester t) => _tap(t, 'group-cover');

    bool selected(WidgetTester t, String key) => t.widget<OptionTile>(_key(key)).selected;

    // TC-29 UI
    testWidgets('a new group starts with the generated cover and its hint', (t) async {
      await _pumpForm(t, '/groups/new');
      expect(_key('group-cover-preview'), findsOneWidget);
      await openSheet(t);
      expect(selected(t, 'cover-generated'), isTrue);
      expect(_key('cover-saved-photo'), findsNothing);
      expect(find.text('Choose a photo'), findsOneWidget);
      expect(find.text('Every group gets its own generated cover.'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('picking a photo switches the hint and the option label', (t) async {
      await _pumpForm(t, '/groups/new');
      await openSheet(t);
      await _tap(t, 'cover-photo');
      await _tap(t, 'photo-gallery');
      await openSheet(t);
      expect(selected(t, 'cover-saved-photo'), isTrue);
      expect(find.text('Your photo is shrunk and shared with group members only.'), findsOneWidget);
      expect(find.text('Change photo'), findsOneWidget);
      expect(find.text('Every group gets its own generated cover.'), findsNothing);
    });

    // TC-29 UI
    testWidgets('going back to Generated restores the generated hint and keeps the photo', (
      t,
    ) async {
      await _pumpForm(t, '/groups/new');
      await openSheet(t);
      await _tap(t, 'cover-photo');
      await _tap(t, 'photo-gallery');
      await openSheet(t);
      await _tap(t, 'cover-generated');
      await openSheet(t);
      expect(find.text('Every group gets its own generated cover.'), findsOneWidget);
      // The picked photo is kept: one tap switches back to it.
      expect(selected(t, 'cover-saved-photo'), isFalse);
      await _tap(t, 'cover-saved-photo');
      await openSheet(t);
      expect(selected(t, 'cover-saved-photo'), isTrue);
    });

    // TC-29 UI
    testWidgets('saving a new group with a photo creates it, then sets the cover photo', (t) async {
      final calls = await _pumpForm(t, '/groups/new');
      await t.enterText(_key('group-name'), 'Goa 2026');
      await t.pump();
      await openSheet(t);
      await _tap(t, 'cover-photo');
      await _tap(t, 'photo-gallery');
      await _tap(t, 'group-save');
      expect(calls.length, 2);
      expect(calls[0], 'create Goa 2026');
      expect(calls[1], startsWith('setCoverPhoto '));
      expect(calls[1], endsWith('old=null'));
    });

    // TC-29 UI
    testWidgets('a new group without a photo makes no cover call', (t) async {
      final calls = await _pumpForm(t, '/groups/new');
      await t.enterText(_key('group-name'), 'Goa 2026');
      await t.pump();
      await _tap(t, 'group-save');
      expect(calls, ['create Goa 2026']);
    });

    // TC-29 UI
    testWidgets('a group with a photo cover opens with the photo selected', (t) async {
      await _pumpForm(t, '/groups/g1/edit', group: _photoGroup());
      await openSheet(t);
      expect(selected(t, 'cover-saved-photo'), isTrue);
      expect(find.text('Change photo'), findsOneWidget);
      expect(find.text('Your photo is shrunk and shared with group members only.'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('switching a photo group to generated calls useGeneratedCover', (t) async {
      final calls = await _pumpForm(t, '/groups/g1/edit', group: _photoGroup());
      await openSheet(t);
      await _tap(t, 'cover-generated');
      await _tap(t, 'group-save');
      expect(calls, ['update g1 Goa trip', 'useGeneratedCover g1 old=$_photoPath']);
    });

    // TC-29 UI
    testWidgets('keeping the photo cover makes no cover call', (t) async {
      final calls = await _pumpForm(t, '/groups/g1/edit', group: _photoGroup());
      await _tap(t, 'group-save');
      expect(calls, ['update g1 Goa trip']);
    });

    // TC-29 UI
    testWidgets('replacing the photo passes the old path to setCoverPhoto', (t) async {
      final calls = await _pumpForm(t, '/groups/g1/edit', group: _photoGroup());
      await openSheet(t);
      await _tap(t, 'cover-photo');
      await _tap(t, 'photo-gallery');
      await _tap(t, 'group-save');
      expect(calls, ['update g1 Goa trip', 'setCoverPhoto g1 old=$_photoPath']);
    });
  });

  group('Group page', () {
    // TC-11-02
    testWidgets('the loan button opens /loan/new?group=<id>', (t) async {
      final h = await pumpGroups(
        t,
        '/groups/g1',
        overrides: fixedGroupData(groups: [sampleGroup(id: 'g1')]),
      );
      await _tap(t, 'group-loan');
      expect(h.location, '/loan/new?group=g1');
    });

    // TC-11-02
    testWidgets('an archived group has no loan button', (t) async {
      await pumpGroups(
        t,
        '/groups/g1',
        overrides: fixedGroupData(
          groups: [sampleGroup(id: 'g1', archivedAt: '2026-11-01T00:00:00Z')],
        ),
      );
      expect(_key('group-loan'), findsNothing);
    });
  });
}
