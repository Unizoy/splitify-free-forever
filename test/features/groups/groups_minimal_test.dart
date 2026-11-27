// D-033 minimal groups: the one-screen group form with people, the settings list, the invite sheet's link.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';

import '../../support/group_fakes.dart';
import '../../support/group_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key, {bool db = false}) async {
  if (_key(key).evaluate().isEmpty) {
    await tester.scrollUntilVisible(_key(key), 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(_key(key));
  await tester.pump();
  await tester.tap(_key(key));
  await settle(tester, db: db);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(_key(key));
  await tester.enterText(_key(key), text);
  await tester.pump();
}

String _text(WidgetTester tester, String key) => tester
    .widget<TextField>(find.descendant(of: _key(key), matching: find.byType(TextField)))
    .controller!
    .text;

Future<void> _seed(WidgetTester tester, List<Future<void> Function()> inserts) =>
    tester.runAsync(() async {
      for (final i in inserts) {
        await i();
      }
    });

Future<AppDatabase> _seeded(
  WidgetTester tester, {
  String type = 'trip',
  String? createdBy = 'u1',
  List<LocalMember> extra = const [],
}) async {
  final db = openTestDb(tester);
  await _seed(tester, [
    () => db.into(db.groups).insert(sampleGroup(id: 'g1', type: type, createdBy: createdBy)),
    () => db
        .into(db.groupMembers)
        .insert(sampleMember(id: 'm1', userId: 'u1', name: 'Asha', role: 'owner')),
    for (final m in extra) () => db.into(db.groupMembers).insert(m),
  ]);
  return db;
}

void main() {
  group('D-033 group form (one screen)', () {
    testWidgets('D-033 create with people: typed names become name-only members, the one still '
        'in the field too', (tester) async {
      final db = openTestDb(tester);
      final h = await pumpGroups(tester, '/groups/new', db: db);
      expect(find.text('New group'), findsOneWidget);
      await _type(tester, 'group-name', 'Goa trip');
      await _tap(tester, 'group-type-couple');
      await _type(tester, 'group-add-person', 'Ravi');
      await _tap(tester, 'group-add-person-button');
      expect(_key('group-new-person-0'), findsOneWidget);
      expect(_text(tester, 'group-add-person'), '');
      await _type(tester, 'group-add-person', 'Neha');
      expect(find.text('MEMBERS · 2'), findsOneWidget);
      await _tap(tester, 'group-save', db: true);

      final group = (await real(tester, () => db.select(db.groups).get())).single;
      expect(group.name, 'Goa trip');
      expect(group.type, 'couple');
      final members = await real(tester, () => db.select(db.groupMembers).get());
      expect(members.map((m) => m.displayName), containsAll(<String>['Ravi', 'Neha']));
      final ravi = members.singleWhere((m) => m.displayName == 'Ravi');
      final neha = members.singleWhere((m) => m.displayName == 'Neha');
      expect(ravi.userId, isNull);
      expect(neha.userId, isNull);
      expect(ravi.tint, 1);
      expect(neha.tint, 2);
      final outbox = await real(tester, () => db.select(db.outbox).get());
      expect(outbox.map((o) => o.entity), ['group', 'member', 'member']);
      expect(h.location, '/groups/${group.id}');
    });

    testWidgets('D-033 create without people writes the group and its owner only', (tester) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-name', 'Flat 4B');
      await _tap(tester, 'group-save', db: true);
      final members = await real(tester, () => db.select(db.groupMembers).get());
      expect(members.single.role, 'owner');
      final outbox = await real(tester, () => db.select(db.outbox).get());
      expect(outbox.single.entity, 'group');
    });

    testWidgets('D-033 a removed person is not saved', (tester) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-name', 'Goa trip');
      await _type(tester, 'group-add-person', 'Ravi');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      await _type(tester, 'group-add-person', 'Neha');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      await tester.tap(find.byTooltip('Remove Ravi'));
      await settle(tester);
      expect(find.text('Ravi'), findsNothing);
      await _tap(tester, 'group-save', db: true);
      final names = (await real(
        tester,
        () => db.select(db.groupMembers).get(),
      )).map((m) => m.displayName);
      expect(names, isNot(contains('Ravi')));
      expect(names, contains('Neha'));
    });

    testWidgets('D-033 a 51-letter person name shows the error, keeps the text, saves nothing', (
      tester,
    ) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-name', 'Goa trip');
      await _type(tester, 'group-add-person', 'x' * 51);
      await _tap(tester, 'group-add-person-button');
      expect(find.text('Enter a name (up to 50 characters)'), findsOneWidget);
      await _tap(tester, 'group-save', db: true);
      expect(_text(tester, 'group-add-person'), 'x' * 51);
      expect(await real(tester, () => db.select(db.groups).get()), isEmpty);
      // Typing again clears the error.
      await _type(tester, 'group-add-person', 'Ravi');
      expect(find.text('Enter a name (up to 50 characters)'), findsNothing);
    });

    testWidgets('D-033 an empty group name shows the error and keeps the typed people', (
      tester,
    ) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-add-person', 'Ravi');
      await _tap(tester, 'group-add-person-button');
      await _tap(tester, 'group-save', db: true);
      expect(find.text('Enter a group name'), findsOneWidget);
      expect(_key('group-new-person-0'), findsOneWidget);
      expect(await real(tester, () => db.select(db.groups).get()), isEmpty);
    });

    testWidgets('D-033 back closes at once when nothing was typed', (tester) async {
      final h = await pumpGroups(tester, '/groups', overrides: fixedGroupData());
      h.open('/groups/new');
      await settle(tester);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(h.location, '/groups');
    });

    testWidgets('D-033 back after typing asks first; Discard leaves without saving', (
      tester,
    ) async {
      final db = openTestDb(tester);
      final h = await pumpGroups(tester, '/groups', db: db);
      h.open('/groups/new');
      await settle(tester, db: true);
      await _type(tester, 'group-name', 'Goa trip');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('Discard this group?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(h.location, '/groups/new');
      expect(_text(tester, 'group-name'), 'Goa trip');
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      await _tap(tester, 'confirm-action');
      expect(h.location, '/groups');
      expect(await real(tester, () => db.select(db.groups).get()), isEmpty);
    });

    testWidgets('D-033 edit lists the members and adds new people on save', (tester) async {
      final db = await _seeded(
        tester,
        extra: [sampleMember(id: 'm2', name: 'Ravi', position: 1)],
      );
      final h = await pumpGroups(tester, '/groups', db: db);
      h.open('/groups/g1/edit');
      await settle(tester, db: true);
      expect(find.text('Edit group'), findsOneWidget);
      expect(_key('group-member-m1'), findsOneWidget);
      expect(_key('group-member-m2'), findsOneWidget);
      await _type(tester, 'group-add-person', 'Neha');
      await _tap(tester, 'group-save', db: true);
      final rows = await real(tester, () => db.select(db.groupMembers).get());
      final neha = rows.singleWhere((m) => m.displayName == 'Neha');
      expect(neha.groupId, 'g1');
      expect(neha.position, 2);
      expect(h.location, '/groups');
    });

    testWidgets('D-033 "Invite with a link or QR" saves a new group and opens its invite sheet', (
      tester,
    ) async {
      final db = openTestDb(tester);
      final h = await pumpGroups(tester, '/groups/new', db: db);
      await _type(tester, 'group-name', 'Goa trip');
      await _tap(tester, 'group-invite', db: true);
      await settle(tester, db: true);
      final group = (await real(tester, () => db.select(db.groups).get())).single;
      expect(h.location, '/groups/${group.id}');
      // Made offline: the code arrives once the group reaches the server.
      expect(_key('invite-no-code'), findsOneWidget);
    });

    testWidgets('D-033 "Invite" with an empty name saves nothing and asks for the name', (
      tester,
    ) async {
      final db = openTestDb(tester);
      await pumpGroups(tester, '/groups/new', db: db);
      await _tap(tester, 'group-invite', db: true);
      expect(find.text('Enter a group name'), findsOneWidget);
      expect(_key('invite-no-code'), findsNothing);
      expect(await real(tester, () => db.select(db.groups).get()), isEmpty);
    });

    testWidgets('D-033 edit: "Invite" opens the invite sheet straight away', (tester) async {
      final db = await _seeded(tester);
      await pumpGroups(tester, '/groups/g1/edit', db: db);
      await _tap(tester, 'group-invite');
      expect(find.text('ABCD-EFGH'), findsOneWidget);
    });
  });

  group('D-033 group settings list', () {
    testWidgets('D-033 the header shows name and "Trip · INR" and opens the one-screen form', (
      tester,
    ) async {
      final db = await _seeded(tester);
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);
      expect(find.text('Group settings'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Trip · INR'), findsOneWidget);
      await _tap(tester, 'settings-edit-group', db: true);
      expect(h.location, '/groups/g1/edit');
    });

    testWidgets('D-033 the rows come in Splitwise order: people, settings, data, leave/delete', (
      tester,
    ) async {
      final db = await _seeded(tester);
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      double y(String key) => tester.getTopLeft(_key(key)).dy;
      final order = [
        'settings-edit-group',
        'settings-add-member',
        'settings-invite',
        'member-m1',
        'settings-default-split',
        'settings-simplify',
        'settings-export',
        'settings-import',
        'settings-deleted-items',
        'settings-archive',
        'settings-leave',
        'settings-delete',
      ];
      // Tall surface so every row is built.
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await settle(tester, db: true);
      for (var i = 1; i < order.length; i++) {
        expect(
          y(order[i]),
          greaterThan(y(order[i - 1])),
          reason: '${order[i]} after ${order[i - 1]}',
        );
      }
    });

    testWidgets('D-033 "Invite via link or QR" shows code, link and copies the link', (
      tester,
    ) async {
      final db = await _seeded(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'settings-invite');
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.text('splitify://join?code=ABCDEFGH'), findsOneWidget);
      await _tap(tester, 'invite-copy-link');
      expect(copied, 'splitify://join?code=ABCDEFGH');
      expect(find.text('Link copied'), findsWidgets);
      await _tap(tester, 'invite-copy');
      expect(copied, 'ABCD-EFGH');
    });

    testWidgets('D-033 Leave asks first; Cancel keeps you in the group', (tester) async {
      final db = await _seeded(tester, createdBy: 'u2');
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'settings-leave');
      expect(find.text('Leave this group?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(h.remote.calls, isEmpty);
      expect(h.location, '/groups/g1/settings');
    });

    testWidgets('D-033 Delete asks first; Cancel writes nothing', (tester) async {
      final db = await _seeded(tester);
      await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, 'settings-delete');
      await tester.tap(find.text('Cancel'));
      await settle(tester, db: true);
      final g = (await real(tester, () => db.select(db.groups).get())).single;
      expect(g.deletedAt, isNull);
      expect(await real(tester, () => db.select(db.outbox).get()), isEmpty);
    });

    testWidgets('D-033 a friend (direct) group cannot be edited and has no simplify row', (
      tester,
    ) async {
      final db = await _seeded(tester, type: 'direct');
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);
      expect(_key('settings-simplify'), findsNothing);
      await tester.tap(_key('settings-edit-group'));
      await settle(tester);
      expect(h.location, '/groups/g1/settings');
    });
  });
}
