import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';

import '../../support/group_fakes.dart';
import '../../support/group_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key, {bool db = false}) async {
  if (_key(key).evaluate().isEmpty) {
    // Lazy lists build only what is near the screen: scroll the page to it.
    await tester.scrollUntilVisible(_key(key), 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(_key(key));
  await tester.pump();
  await tester.tap(_key(key));
  await settle(tester, db: db);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_key(key), text);
  await tester.pump();
}

Future<void> _seedGroup(
  AppDatabase db, {
  String id = 'g1',
  String name = 'Goa trip',
  String? archivedAt,
  String? deletedAt,
  String? createdBy = 'u1',
}) async {
  await db
      .into(db.groups)
      .insert(
        sampleGroup(
          id: id,
          name: name,
          archivedAt: archivedAt,
          deletedAt: deletedAt,
          createdBy: createdBy,
        ),
      );
}

Future<void> _seedMember(
  AppDatabase db, {
  required String id,
  String groupId = 'g1',
  String? userId,
  String name = 'Member',
  int position = 0,
  String role = 'member',
  String? claimedAt,
  int? tint,
  String syncState = 'synced',
}) async {
  await db
      .into(db.groupMembers)
      .insert(
        sampleMember(
          id: id,
          groupId: groupId,
          userId: userId,
          name: name,
          position: position,
          role: role,
          claimedAt: claimedAt,
          tint: tint,
          syncState: syncState,
        ),
      );
}

/// Inserts through the real loop.
Future<void> seed(WidgetTester tester, List<Future<void> Function()> inserts) async {
  await tester.runAsync(() async {
    for (final i in inserts) {
      await i();
    }
  });
}

void main() {
  // ---------------------------------------------------------------- TC-1-04 grid
  group('Groups grid', () {
    testWidgets('TC-1-04 loading shows a skeleton', (tester) async {
      await pumpGroups(tester, '/groups', overrides: fixedGroupData(loading: true));
      expect(find.bySemanticsLabel('Loading your groups'), findsOneWidget);
    });

    testWidgets('TC-1-04 empty state has New and Join that open the right screens', (tester) async {
      final h = await pumpGroups(tester, '/groups', overrides: fixedGroupData());
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Create your first group'), findsOneWidget);
      await _tap(tester, 'groups-empty-new');
      expect(h.location, '/groups/new');
      h.router.pop();
      await settle(tester);
      expect(h.location, '/groups');
      await _tap(tester, 'groups-empty-join');
      expect(h.location, '/join');
    });

    testWidgets('TC-1-04 list shows cards, hides archived until tapped, opens a group', (
      tester,
    ) async {
      final groups = [
        sampleGroup(id: 'g1', name: 'Goa trip'),
        sampleGroup(id: 'g2', name: 'Flat 4B', type: 'home', syncState: 'pending'),
        sampleGroup(id: 'g3', name: 'Old trip', archivedAt: '2026-11-01T00:00:00Z'),
      ];
      final h = await pumpGroups(tester, '/groups', overrides: fixedGroupData(groups: groups));
      expect(_key('group-card-g1'), findsOneWidget);
      expect(_key('group-card-g2'), findsOneWidget);
      expect(_key('group-card-g3'), findsNothing);
      expect(find.text('ACTIVE GROUPS\u00A0· 2'), findsOneWidget);
      // Both Join and New stay available with groups present.
      expect(_key('groups-join'), findsOneWidget);
      expect(_key('groups-new'), findsOneWidget);

      await _tap(tester, 'groups-archived');
      expect(_key('group-card-g3'), findsOneWidget);
      await _tap(tester, 'groups-archived');
      expect(_key('group-card-g3'), findsNothing);

      await _tap(tester, 'group-card-g1');
      expect(h.location, '/groups/g1');
    });

    testWidgets('TC-1-04 offline note shows only while offline', (tester) async {
      await pumpGroups(tester, '/groups', overrides: fixedGroupData(offline: true));
      expect(_key('groups-offline'), findsOneWidget);
    });

    testWidgets('TC-1-04 online hides the offline note', (tester) async {
      await pumpGroups(tester, '/groups', overrides: fixedGroupData());
      expect(_key('groups-offline'), findsNothing);
    });

    testWidgets('TC-1-04 opening the tab syncs once', (tester) async {
      final h = await pumpGroups(tester, '/groups', overrides: fixedGroupData());
      expect(h.syncs, hasLength(1));
    });
  });

  // ---------------------------------------------------------------- group form
  group('Group form', () {
    testWidgets('TC-1-01 empty name shows the required error and writes nothing', (tester) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _tap(tester, 'group-save', db: true);
      expect(find.text('Enter a group name'), findsOneWidget);
      expect(await real(tester, () => db.select(db.groups).get()), isEmpty);
    });

    testWidgets('TC-1-01 a 61 letter name shows the too-long error', (tester) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-name', 'a' * 61);
      await _tap(tester, 'group-save', db: true);
      expect(find.text('Use up to 60 characters'), findsOneWidget);
      expect(await real(tester, () => db.select(db.groups).get()), isEmpty);
    });

    testWidgets('TC-1-01 create writes the group and an outbox row, then opens it', (tester) async {
      final db = openTestDb(tester);
      final h = await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-name', '  Goa trip ');
      await _tap(tester, 'group-type-home');
      await _tap(tester, 'group-save', db: true);

      final groups = await real(tester, () => db.select(db.groups).get());
      expect(groups, hasLength(1));
      expect(groups.single.name, 'Goa trip');
      expect(groups.single.type, 'home');
      expect(groups.single.mainCurrency, 'INR');
      expect(groups.single.syncState, 'pending');
      final outbox = await real(tester, () => db.select(db.outbox).get());
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'group');
      expect(outbox.single.recordId, groups.single.id);
      expect(h.location, '/groups/${groups.single.id}');
      // The owner member exists locally right away.
      final members = await real(tester, () => db.select(db.groupMembers).get());
      expect(members.single.role, 'owner');
    });

    testWidgets('TC-1-01 the type tile chosen is the type saved (default trip)', (tester) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-name', 'Weekend');
      await _tap(tester, 'group-save', db: true);
      final groups = await real(tester, () => db.select(db.groups).get());
      expect(groups.single.type, 'trip');
    });

    testWidgets('TC-1-03 edit pre-fills and saves the new name', (tester) async {
      final db = openTestDb(tester);
      await seed(tester, [() => _seedGroup(db)]);
      final h = await pumpGroups(tester, '/groups', db: db);
      h.open('/groups/g1/edit');
      await settle(tester, db: true);
      expect(find.text('Edit group'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Goa trip'), findsOneWidget);
      await _type(tester, 'group-name', 'Goa 2026');
      await _tap(tester, 'group-type-couple');
      await _tap(tester, 'group-save', db: true);
      final g = (await real(tester, () => db.select(db.groups).get())).single;
      expect(g.name, 'Goa 2026');
      expect(g.type, 'couple');
      expect(h.location, '/groups');
    });
  });

  // ---------------------------------------------------------------- group detail
  group('Group detail', () {
    final members = [
      sampleMember(id: 'm1', userId: 'u1', name: 'Asha', role: 'owner'),
      sampleMember(id: 'm2', name: 'Ravi', position: 1, tint: 2),
      sampleMember(id: 'm3', name: 'Neha', position: 2),
    ];

    testWidgets('TC-1-04 shows the name, member count and switches tabs', (tester) async {
      await pumpGroups(
        tester,
        '/groups/g1',
        overrides: fixedGroupData(
          groups: [sampleGroup(id: 'g1')],
          members: {'g1': members},
          unsynced: {'g1'},
        ),
      );
      expect(find.text('Goa trip'), findsWidgets);
      expect(find.text('3 members'), findsOneWidget);
      expect(find.byType(ExpenseList), findsOneWidget); // phase 08 Expenses tab
      await settle(tester);
      // D-033: one Add expense on the page (the bar), not a second one in the empty list.
      expect(_key('expenses-empty-add'), findsNothing);
      expect(_key('group-add-expense'), findsOneWidget);
      expect(find.byType(SyncMarker), findsOneWidget);
      await tester.tap(find.text('Balances'));
      await settle(tester);
      expect(find.text('Balances show up here'), findsOneWidget);
      await tester.tap(find.text('Totals'));
      await settle(tester);
      expect(find.text('No spending yet'), findsOneWidget); // phase 09 Totals tab, no expenses
      // The invisible sizing label of FolderTabs sits over the first tab; it must not swallow this tap.
      await tester.tap(
        find.descendant(of: find.byType(FolderTabs), matching: find.text('Expenses')).first,
      );
      await settle(tester);
      expect(find.text('No expenses yet'), findsOneWidget);
      expect(_key('group-add-expense'), findsOneWidget);
    });

    testWidgets('TC-1-05 an archived group shows the banner; Unarchive writes archived_at null', (
      tester,
    ) async {
      final db = openTestDb(tester);
      await seed(tester, [
        () => _seedGroup(db, archivedAt: '2026-11-01T00:00:00Z'),
        () => _seedMember(db, id: 'm1', userId: 'u1', name: 'Asha', role: 'owner'),
      ]);
      await pumpGroups(tester, '/groups/g1', db: db);
      expect(_key('group-archived-banner'), findsOneWidget);
      expect(_key('group-add-expense'), findsNothing);
      await _tap(tester, 'group-unarchive', db: true);
      final g = (await real(tester, () => db.select(db.groups).get())).single;
      expect(g.archivedAt, null);
      expect(g.syncState, 'pending');
      expect(_key('group-archived-banner'), findsNothing);
    });

    testWidgets('TC-1-04 an unknown group shows the not-found state', (tester) async {
      await pumpGroups(tester, '/groups/nope', overrides: fixedGroupData());
      expect(find.text('This group is not on this phone.'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- settings
  group('Group settings', () {
    Future<AppDatabase> seeded(
      WidgetTester tester, {
      String? createdBy = 'u1',
      List<Future<void> Function(AppDatabase)> extra = const [],
    }) async {
      final db = openTestDb(tester);
      await seed(tester, [
        () => _seedGroup(db, createdBy: createdBy),
        () => _seedMember(db, id: 'm1', userId: 'u1', name: 'Asha', role: 'owner'),
        for (final e in extra) () => e(db),
      ]);
      return db;
    }

    testWidgets('TC-4-01 add a name-only member with a chosen colour', (tester) async {
      final db = await seeded(tester);
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'settings-add-member');
      await _type(tester, 'member-name', 'Ravi');
      await _tap(tester, 'member-tint-3');
      await _tap(tester, 'member-save', db: true);
      final rows = await real(tester, () => db.select(db.groupMembers).get());
      final ravi = rows.singleWhere((m) => m.displayName == 'Ravi');
      expect(ravi.tint, 3);
      expect(ravi.userId, null);
      expect(ravi.position, 1);
      expect(ravi.syncState, 'pending');
      final outbox = await real(tester, () => db.select(db.outbox).get());
      expect(outbox.single.entity, 'member');
      expect(find.text('Not joined yet'), findsOneWidget);
    });

    testWidgets('TC-4-01 an empty member name is refused', (tester) async {
      final db = await seeded(tester);
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'settings-add-member');
      await _tap(tester, 'member-save');
      expect(_key('member-name'), findsOneWidget);
      expect(await real(tester, () => db.select(db.groupMembers).get()), hasLength(1));
    });

    testWidgets('TC-4-02 rename a member', (tester) async {
      final db = await seeded(
        tester,
        extra: [(db) => _seedMember(db, id: 'm2', name: 'Ravi', position: 1, tint: 1)],
      );
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'member-m2');
      await _tap(tester, 'member-rename');
      expect(find.widgetWithText(TextField, 'Ravi'), findsOneWidget);
      await _type(tester, 'member-name', 'Ravindra');
      await _tap(tester, 'member-save', db: true);
      final rows = await real(tester, () => db.select(db.groupMembers).get());
      expect(rows.singleWhere((m) => m.id == 'm2').displayName, 'Ravindra');
      expect(find.text('Ravindra'), findsOneWidget);
    });

    testWidgets('TC-4-04 removing a synced member calls the server and syncs', (tester) async {
      final db = await seeded(
        tester,
        extra: [(db) => _seedMember(db, id: 'm2', name: 'Ravi', position: 1)],
      );
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'member-m2');
      await _tap(tester, 'member-remove');
      expect(find.text('Remove Ravi?'), findsOneWidget);
      await _tap(tester, 'confirm-action');
      expect(h.remote.calls, ['remove:g1:m2']);
      expect(h.syncs, isNotEmpty);
    });

    testWidgets('TC-4-04 NONZERO_BALANCE tells the user to settle up first', (tester) async {
      final db = await seeded(
        tester,
        extra: [(db) => _seedMember(db, id: 'm2', name: 'Ravi', position: 1)],
      );
      final remote = FakeGroupsRemote()
        ..actionFailure = const GroupFailure(GroupFailureCode.nonzeroBalance);
      await pumpGroups(tester, '/groups/g1/settings', db: db, remote: remote);
      await _tap(tester, 'member-m2');
      await _tap(tester, 'member-remove');
      await _tap(tester, 'confirm-action');
      expect(
        find.text('Settle up first. This person still has a balance in this group.'),
        findsOneWidget,
      );
    });

    testWidgets('TC-4-04 a member the server never saw is removed locally', (tester) async {
      final db = await seeded(
        tester,
        extra: [(db) => _seedMember(db, id: 'm2', name: 'Ravi', position: 1, syncState: 'pending')],
      );
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'member-m2');
      await _tap(tester, 'member-remove');
      await _tap(tester, 'confirm-action', db: true);
      expect(h.remote.calls, isEmpty);
      final row = (await real(
        tester,
        () => db.select(db.groupMembers).get(),
      )).singleWhere((m) => m.id == 'm2');
      expect(row.deletedAt != null, isTrue);
    });

    testWidgets('TC-4-05 unlink is offered only for claimed members, not me or name-only', (
      tester,
    ) async {
      final db = await seeded(
        tester,
        extra: [
          (db) => _seedMember(
            db,
            id: 'm2',
            userId: 'u2',
            name: 'Ravi',
            position: 1,
            claimedAt: '2026-11-10T00:00:00Z',
          ),
          (db) => _seedMember(db, id: 'm3', name: 'Neha', position: 2),
        ],
      );
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);

      // Claimed: unlink is there; confirm calls the server.
      await _tap(tester, 'member-m2');
      expect(_key('member-unlink'), findsOneWidget);
      await _tap(tester, 'member-unlink');
      expect(find.text('Unlink Ravi?'), findsOneWidget);
      await _tap(tester, 'confirm-action');
      expect(h.remote.calls, ['unlink:g1:m2']);

      // Name-only: no unlink.
      await _tap(tester, 'member-m3');
      expect(_key('member-rename'), findsOneWidget);
      expect(_key('member-unlink'), findsNothing);
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);

      // Me: no unlink, Leave instead of Remove.
      await _tap(tester, 'member-m1');
      expect(_key('member-unlink'), findsNothing);
      expect(_key('member-remove'), findsNothing);
      expect(_key('member-leave'), findsOneWidget);
    });

    testWidgets('TC-1-06 Delete group is shown to the creator only', (tester) async {
      final db = await seeded(tester, createdBy: 'u2');
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      // Lazy list: the leave row sits below the export row (phase 17); scroll to it.
      await tester.scrollUntilVisible(
        _key('settings-leave'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(_key('settings-leave'), findsOneWidget);
      expect(_key('settings-delete'), findsNothing);
    });

    testWidgets('TC-1-06 the creator deletes the group (soft delete in the outbox)', (
      tester,
    ) async {
      final db = await seeded(tester);
      final h = await pumpGroups(tester, '/groups', db: db);
      h.open('/groups/g1/settings');
      await settle(tester, db: true);
      await _tap(tester, 'settings-delete');
      await _tap(tester, 'confirm-action', db: true);
      final g = (await real(tester, () => db.select(db.groups).get())).single;
      expect(g.deletedAt != null, isTrue);
      final outbox = await real(tester, () => db.select(db.outbox).get());
      expect(outbox.single.op, 'delete');
      expect(h.location, '/groups');
      expect(find.text('Group deleted'), findsOneWidget);
    });

    testWidgets('TC-1-05 Archive writes archived_at', (tester) async {
      final db = await seeded(tester);
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'settings-archive', db: true);
      final g = (await real(tester, () => db.select(db.groups).get())).single;
      expect(g.archivedAt != null, isTrue);
    });

    testWidgets('TC-4-06 leave calls the server and returns to the Groups tab', (tester) async {
      final db = await seeded(tester, createdBy: 'u2');
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'settings-leave');
      await _tap(tester, 'confirm-action');
      expect(h.remote.calls, ['leave:g1']);
      expect(h.location, '/groups');
    });

    testWidgets('TC-4-06 leave while owing shows the server answer', (tester) async {
      final db = await seeded(tester, createdBy: 'u2');
      final remote = FakeGroupsRemote()
        ..actionFailure = const GroupFailure(GroupFailureCode.nonzeroBalance);
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db, remote: remote);
      await _tap(tester, 'settings-leave');
      await _tap(tester, 'confirm-action');
      expect(find.textContaining('Settle up first'), findsOneWidget);
      expect(h.location, '/groups/g1/settings');
    });
  });

  // ---------------------------------------------------------------- invite sheet
  group('Invite sheet', () {
    testWidgets('TC-3-01 shows the code, shares the exact text, resets after confirm', (
      tester,
    ) async {
      final remote = FakeGroupsRemote()..rotations.add('WXYZ2345');
      final h = await pumpGroups(
        tester,
        '/groups/g1',
        remote: remote,
        overrides: fixedGroupData(groups: [sampleGroup(id: 'g1')]),
      );
      await _tap(tester, 'group-invite');
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(_key('invite-no-code'), findsNothing);

      await _tap(tester, 'invite-share');
      expect(h.shared, ['Join my group “Goa trip” on Splitify Free Forever: code ABCD-EFGH']);

      await _tap(tester, 'invite-reset');
      expect(remote.calls, isEmpty, reason: 'nothing happens before the user confirms');
      await _tap(tester, 'confirm-action');
      expect(remote.calls, ['rotate:g1']);
      expect(find.text('WXYZ-2345'), findsOneWidget);
      expect(find.text('ABCD-EFGH'), findsNothing);
    });

    testWidgets('TC-3-01 a group without a code yet shows the connect hint', (tester) async {
      await pumpGroups(
        tester,
        '/groups/g1',
        overrides: fixedGroupData(groups: [sampleGroup(id: 'g1', inviteCode: null)]),
      );
      await _tap(tester, 'group-invite');
      expect(_key('invite-no-code'), findsOneWidget);
      expect(_key('invite-share'), findsNothing);
    });

    testWidgets('TC-3-01 reset offline shows the internet message', (tester) async {
      final remote = FakeGroupsRemote()
        ..rotations.add(const GroupFailure(GroupFailureCode.offline));
      await pumpGroups(
        tester,
        '/groups/g1',
        remote: remote,
        overrides: fixedGroupData(groups: [sampleGroup(id: 'g1')]),
      );
      await _tap(tester, 'group-invite');
      await _tap(tester, 'invite-reset');
      await _tap(tester, 'confirm-action');
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.textContaining('internet'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------- deleted groups
  group('Deleted groups', () {
    testWidgets('TC-1-07 restore clears deleted_at; an expired one cannot be restored', (
      tester,
    ) async {
      final db = openTestDb(tester);
      await seed(tester, [
        () => _seedGroup(db, name: 'Goa trip', deletedAt: '2026-11-20T10:00:00Z'),
        () => _seedGroup(db, id: 'g2', name: 'Old trip', deletedAt: '2026-10-01T10:00:00Z'),
      ]);
      final h = await pumpGroups(tester, '/account', db: db);
      h.open(Routes.deletedGroups);
      await settle(tester, db: true);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Old trip'), findsOneWidget);
      expect(find.text('Too late to restore'), findsOneWidget);
      expect(find.text('28\u00A0days left'), findsOneWidget);
      expect(tester.widget<PillButton>(_key('restore-g2')).onPressed, null);

      await _tap(tester, 'restore-g1', db: true);
      final rows = await real(tester, () => db.select(db.groups).get());
      expect(rows.singleWhere((g) => g.id == 'g1').deletedAt, null);
      expect(rows.singleWhere((g) => g.id == 'g2').deletedAt != null, isTrue);
      final outbox = await real(tester, () => db.select(db.outbox).get());
      expect(outbox.single.op, 'restore');
      expect(outbox.single.recordId, 'g1');
      expect(find.text('Group restored'), findsOneWidget);
    });

    testWidgets('TC-1-07 nothing deleted shows the empty state', (tester) async {
      final h = await pumpGroups(tester, '/account', overrides: fixedGroupData());
      h.open(Routes.deletedGroups);
      await settle(tester);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    test('TC-1-07 restoreDaysLeft counts whole days of the 30 day window', () {
      final deleted = DateTime.utc(2026, 11, 1).toIso8601String();
      expect(restoreDaysLeft(deleted, DateTime.utc(2026, 11, 1)), 30);
      expect(restoreDaysLeft(deleted, DateTime.utc(2026, 11, 22)), 9);
      expect(restoreDaysLeft(deleted, DateTime.utc(2026, 11, 22, 12)), 8);
      expect(restoreDaysLeft(deleted, DateTime.utc(2026, 12, 1)), 0);
      expect(restoreDaysLeft(deleted, DateTime.utc(2026, 12, 1, 0, 0, 1)), -1);
      expect(restoreDaysLeft(deleted, DateTime.utc(2027, 3, 1)), -1);
    });
  });

  // ---------------------------------------------------------------- router
  group('Auth redirect', () {
    test('TC-3-02 the invite link opens the join screen with its code', () {
      expect(
        authRedirect(Uri.parse('splitify://join?code=ABCDEFGH'), signedIn: true),
        '/join?code=ABCDEFGH',
      );
    });

    test('TC-3-02 the invite link without a code opens the plain join screen', () {
      expect(authRedirect(Uri.parse('splitify://join'), signedIn: true), '/join');
    });

    test('TC-3-02 signed out, /join goes to welcome', () {
      expect(authRedirect(Uri.parse('/join'), signedIn: false), '/welcome');
    });

    test('TC-3-02 signed in, /join stays', () {
      expect(authRedirect(Uri.parse('/join?code=ABCDEFGH'), signedIn: true), null);
    });
  });
}
