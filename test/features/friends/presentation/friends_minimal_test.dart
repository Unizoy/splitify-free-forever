// D-033 (minimal flows like Splitwise): the one-sheet "Add friend" on the Friends tab, and the compact
// friend page (Settle up / Remind under the hero, Add expense at the bottom).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart' show syncRepositoryProvider;
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart'
    show notificationsRemoteProvider;

import '../../../support/fakes.dart' show FakeSyncRepository;
import '../../../support/group_harness.dart';
import '../../../support/notification_fakes.dart';
import '../friend_fixtures.dart';
import 'friends_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester t, String key, {bool db = false}) async {
  await t.ensureVisible(_key(key));
  await t.pump();
  await t.tap(_key(key));
  await settle(t, db: db);
}

void main() {
  group('D-033 Add friend sheet (Friends tab)', () {
    Future<GroupHarness> pumpTab(WidgetTester t) async {
      final db = openTestDb(t);
      return pumpGroups(t, '/friends', db: db, overrides: quietNotificationOverrides());
    }

    // D-033
    testWidgets(
      'D-033 the hero has Add friend; the empty state has its own button; both open the sheet',
      (t) async {
        await pumpTab(t);
        expect(_key('friends-add'), findsOneWidget);
        expect(find.byTooltip('Add friend'), findsOneWidget);
        expect(_key('friends-empty-add'), findsOneWidget);

        await _tap(t, 'friends-add');
        expect(find.text('Add a friend'), findsOneWidget);
        expect(_key('add-friend-name'), findsOneWidget);
        expect(_key('add-friend-save'), findsOneWidget);
        expect(find.text('Add friend'), findsWidgets);
        expect(_key('add-friend-invite'), findsOneWidget);
        expect(find.text('Add and invite with a link'), findsOneWidget);
      },
    );

    // D-033
    testWidgets('D-033 the empty-state button opens the same sheet', (t) async {
      await pumpTab(t);
      await _tap(t, 'friends-empty-add');
      expect(_key('add-friend-name'), findsOneWidget);
    });

    // D-033
    testWidgets('D-033 an empty name shows the inline error and writes nothing', (t) async {
      final h = await pumpTab(t);
      await _tap(t, 'friends-add');
      await _tap(t, 'add-friend-save', db: true);
      expect(find.text('Enter a name (up to 50 characters)'), findsOneWidget);
      expect(_key('add-friend-name'), findsOneWidget);
      expect(await real(t, () => h.db!.select(h.db!.groups).get()), isEmpty);
      expect(await real(t, () => h.db!.select(h.db!.outbox).get()), isEmpty);
    });

    // D-033
    testWidgets('D-033 a 51-letter name shows the error, keeps the text and writes nothing', (
      t,
    ) async {
      final h = await pumpTab(t);
      final long = 'a' * 51;
      await _tap(t, 'friends-add');
      await t.enterText(_key('add-friend-name'), long);
      await t.pump();
      await _tap(t, 'add-friend-invite', db: true);
      expect(find.text('Enter a name (up to 50 characters)'), findsOneWidget);
      expect(find.text(long), findsOneWidget);
      expect(await real(t, () => h.db!.select(h.db!.groups).get()), isEmpty);
      expect(await real(t, () => h.db!.select(h.db!.outbox).get()), isEmpty);
    });

    // D-033
    testWidgets(
      'D-033 Add friend writes a direct group and a name-only member, opens the friend page, says "added"',
      (t) async {
        final h = await pumpTab(t);
        await _tap(t, 'friends-add');
        await t.enterText(_key('add-friend-name'), '  Tanvi ');
        await t.pump();
        await _tap(t, 'add-friend-save', db: true);

        final db = h.db!;
        final groups = await real(t, () => db.select(db.groups).get());
        expect(groups, hasLength(1));
        expect(groups.single.type, 'direct');
        final members = await real(t, () => db.select(db.groupMembers).get());
        final friend = members.singleWhere((m) => m.userId == null);
        expect(friend.displayName, 'Tanvi');
        final outbox = await real(t, () => db.select(db.outbox).get());
        expect(outbox.map((o) => o.entity), containsAll(['group', 'member']));
        expect(h.location, '/friends/${Uri.encodeComponent('m:${friend.id}')}');
        expect(find.text('Tanvi added'), findsOneWidget);
        expect(_key('invite-no-code'), findsNothing);
      },
    );

    // D-033
    testWidgets(
      'D-033 Add and invite does the same writes, opens the friend page and the invite sheet',
      (t) async {
        final h = await pumpTab(t);
        await _tap(t, 'friends-add');
        await t.enterText(_key('add-friend-name'), 'Tanvi');
        await t.pump();
        await _tap(t, 'add-friend-invite', db: true);
        await settle(t, db: true);

        final db = h.db!;
        final groups = await real(t, () => db.select(db.groups).get());
        expect(groups.single.type, 'direct');
        final members = await real(t, () => db.select(db.groupMembers).get());
        final friend = members.singleWhere((m) => m.userId == null);
        expect(friend.displayName, 'Tanvi');
        final outbox = await real(t, () => db.select(db.outbox).get());
        expect(outbox.map((o) => o.entity), containsAll(['group', 'member']));
        expect(h.location, '/friends/${Uri.encodeComponent('m:${friend.id}')}');
        // Offline group: no invite code yet.
        expect(_key('invite-no-code'), findsOneWidget);
        expect(find.text('Tanvi added'), findsNothing);
      },
    );
  });

  group('D-033 friend page', () {
    Future<void> pumpPage(
      WidgetTester t,
      String key,
      List<Friend> friends, {
      FakeNotificationsRemote? remote,
    }) => pumpFriends(
      t,
      FriendPage(friendKey: key),
      overrides: [
        ...friendOverrides(AsyncData(friends), actions: (ref) => FakeFriendActions(ref)),
        notificationsRemoteProvider.overrideWithValue(remote ?? FakeNotificationsRemote()),
        syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
      ],
    );

    // Asha (u2, linked) owes me only in Goa.
    List<Friend> oneGroup() => friendsOf([goaLedger()], 'u1', profileNames: profileNames);

    // D-033
    testWidgets('D-033 Settle up sits under the hero, Add expense at the bottom', (t) async {
      await pumpPage(t, 'u:u2', oneGroup());
      final title = t.getTopLeft(find.text('Asha Rao').first).dy;
      final settle = t.getTopLeft(_key('friend-settle')).dy;
      final add = t.getTopLeft(_key('friend-add-expense'));
      expect(settle, greaterThan(title));
      expect(add.dy, greaterThan(settle));
      // The add bar is pinned to the bottom of the 915 px phone.
      expect(add.dy, greaterThan(915 * 0.8));
    });

    // D-033
    testWidgets('D-033 Remind shows for a linked friend who owes me', (t) async {
      await pumpPage(t, 'u:u2', oneGroup());
      expect(_key('friend-remind'), findsOneWidget);
    });

    // D-034 B3 (was D-033: hidden): a friend without the app gets a shared reminder instead of a push.
    testWidgets('D-034 Remind for a name-only friend who owes me opens "Share a reminder"', (
      t,
    ) async {
      final remote = FakeNotificationsRemote();
      await pumpPage(t, 'm:a3', oneGroup(), remote: remote);
      expect(_key('friend-settle'), findsOneWidget);
      expect(_key('friend-remind'), findsOneWidget);
      await _tap(t, 'friend-remind');
      expect(_key('remind-share-sheet'), findsOneWidget);
      expect(
        find.textContaining('Hi Rahul Mehta, a reminder about ₹70 for “Goa trip”'),
        findsOneWidget,
      );
      expect(remote.reminders, isEmpty, reason: 'no push and no activity for a shared reminder');
    });

    // D-033
    testWidgets('D-033 Remind is hidden when I owe the friend', (t) async {
      final iOwe = friendsOf([flatLedger()], 'u1', profileNames: profileNames);
      await pumpPage(t, 'u:u2', iOwe);
      expect(_key('friend-settle'), findsOneWidget);
      expect(_key('friend-remind'), findsNothing);
    });

    // D-033
    testWidgets('D-033 Remind with one group sends one reminder and says so', (t) async {
      final remote = FakeNotificationsRemote();
      await pumpPage(t, 'u:u2', oneGroup(), remote: remote);
      await _tap(t, 'friend-remind');
      expect(remote.reminders, [('g1', 'a2')]);
      expect(find.text('Reminder sent to Asha Rao'), findsOneWidget);
      expect(_key('friend-remind-picker'), findsNothing);
    });

    // D-033
    testWidgets('D-033 Remind with two groups asks which one first', (t) async {
      final remote = FakeNotificationsRemote();
      // Asha owes me in Goa and in our direct group.
      final two = friendsOf([goaLedger(), directLedger()], 'u1', profileNames: profileNames);
      await pumpPage(t, 'u:u2', two, remote: remote);
      await _tap(t, 'friend-remind');
      expect(_key('friend-remind-picker'), findsOneWidget);
      expect(remote.reminders, isEmpty);
      expect(find.byKey(const Key('remind-a2')), findsWidgets);
      expect(find.byKey(const Key('remind-c2')), findsWidgets);
    });
  });
}
