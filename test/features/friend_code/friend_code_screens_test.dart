// D-034 B4: the Add friend sheet's two new rows, "My friend code" (QR, code, link, Copy, Share, Reset, offline
// copy) and "Add a friend by code" (type / paste / scan, friendly errors, group invites go to join, the deep link
// fills the code), each under the real router.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/friend_code/presentation/friend_code_screen.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart' show QrRing;

import '../../support/group_fakes.dart';
import '../../support/group_harness.dart';
import '../../support/notification_fakes.dart';
import 'friend_code_fakes.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester t, String key, {bool db = false}) async {
  await t.ensureVisible(_key(key));
  await t.pump();
  await t.tap(_key(key));
  await settle(t, db: db);
}

void main() {
  late FakeFriendCodeRemote remote;
  String? scanned;

  setUp(() {
    remote = FakeFriendCodeRemote();
    scanned = null;
  });

  Future<GroupHarness> pump(WidgetTester t, String location, {FakeGroupsRemote? groups}) =>
      pumpGroups(
        t,
        location,
        db: openTestDb(t),
        remote: groups,
        overrides: [
          ...quietNotificationOverrides(),
          friendsRemoteProvider.overrideWithValue(remote),
          friendQrScannerProvider.overrideWithValue((_) async => scanned),
        ],
      );

  group('Add friend sheet', () {
    testWidgets('has "Show my code" and "Scan a friend\'s code" under the name form', (t) async {
      await pump(t, '/friends');
      await _tap(t, 'friends-add');
      expect(find.text('Show my code'), findsOneWidget);
      expect(find.text("Scan a friend's code"), findsOneWidget);
    });

    testWidgets('"Scan a friend\'s code" opens add a friend by code', (t) async {
      final h = await pump(t, '/friends');
      await _tap(t, 'friends-add');
      await _tap(t, 'add-friend-scan-code', db: true);
      expect(h.location, '/friends/code');
      expect(find.text('Add a friend by code'), findsOneWidget);
    });
  });

  group('My friend code', () {
    testWidgets('shows the QR of the link, the code and the link; Share sends both', (t) async {
      final h = await pump(t, '/friends');
      await _tap(t, 'friends-add');
      await _tap(t, 'add-friend-my-code', db: true);
      expect(find.text('My friend code'), findsOneWidget);
      expect(find.text('ABCD-2345'), findsOneWidget);
      expect(find.text('splitify://friend?code=ABCD2345'), findsOneWidget);
      expect(t.widget<QrRing>(find.byType(QrRing)).data, 'splitify://friend?code=ABCD2345');
      await _tap(t, 'friend-code-share');
      expect(h.shared.single, contains('ABCD-2345'));
      expect(h.shared.single, contains('splitify://friend?code=ABCD2345'));
    });

    testWidgets('Copy puts the code on the clipboard', (t) async {
      final copied = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData')
          copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(t, '/friends');
      await _tap(t, 'friends-add');
      await _tap(t, 'add-friend-my-code', db: true);
      await _tap(t, 'friend-code-copy');
      await _tap(t, 'friend-code-copy-link');
      expect(copied, ['ABCD-2345', 'splitify://friend?code=ABCD2345']);
    });

    testWidgets('Reset asks first, then shows the new code', (t) async {
      await pump(t, '/friends');
      await _tap(t, 'friends-add');
      await _tap(t, 'add-friend-my-code', db: true);
      await _tap(t, 'friend-code-reset');
      expect(find.text('Reset your friend code?'), findsOneWidget);
      await t.tap(find.text('Reset code').last);
      await settle(t, db: true);
      expect(remote.rotations, 1);
      expect(find.text('WXYZ-6789'), findsOneWidget);
    });

    testWidgets('offline the first time: "needs internet" with Retry', (t) async {
      remote.offline = true;
      await pump(t, '/friends');
      await _tap(t, 'friends-add');
      await _tap(t, 'add-friend-my-code', db: true);
      expect(_key('friend-code-offline'), findsOneWidget);
      expect(find.textContaining('needs internet the first time'), findsOneWidget);
      remote.offline = false;
      await _tap(t, 'friend-code-retry', db: true);
      expect(find.text('ABCD-2345'), findsOneWidget);
    });
  });

  group('Add a friend by code', () {
    testWidgets('a typed code adds the friend and opens their page', (t) async {
      final h = await pump(t, '/friends/code');
      await t.enterText(_key('friend-code-field'), 'a');
      await t.pump();
      await t.enterText(_key('friend-code-field'), 'ab');
      await t.pump();
      expect(remote.added, isEmpty, reason: 'typing waits for the button');
      await t.enterText(_key('friend-code-field'), 'ABCD2345');
      await settle(t, db: true);
      // More than one character at once is a paste: added right away.
      expect(remote.added, ['ABCD2345']);
      expect(h.location, '/friends/u%3Au2');
      expect(find.text('Asha Rao is now your friend'), findsOneWidget);
    });

    testWidgets('Add friend with a code from a deep link takes one tap', (t) async {
      final h = await pump(t, 'splitify://friend?code=abcd-2345');
      expect(find.text('Add a friend by code'), findsOneWidget);
      expect(find.text('ABCD-2345'), findsOneWidget);
      expect(remote.added, isEmpty, reason: 'a link waits for the tap');
      await _tap(t, 'friend-code-add', db: true);
      expect(remote.added, ['ABCD2345']);
      expect(h.location, '/friends/u%3Au2');
    });

    testWidgets('already friends says so', (t) async {
      remote.answer = (
        groupId: 'g',
        friendUserId: 'u2',
        friendMemberId: 'c2',
        friendName: 'Asha Rao',
        created: false,
      );
      await pump(t, '/friends/code/ABCD2345');
      await _tap(t, 'friend-code-add', db: true);
      expect(find.text('You and Asha Rao are already friends'), findsOneWidget);
    });

    for (final (code, text) in [
      (
        FriendCodeFailureCode.invalidCode,
        "That code doesn't match anyone. Check it and try again.",
      ),
      (FriendCodeFailureCode.ownCode, "That's your own code. Ask your friend for theirs."),
      (FriendCodeFailureCode.rateLimited, 'Too many wrong codes. Try again in an hour.'),
      (FriendCodeFailureCode.offline, 'Adding a friend by code needs internet.'),
    ]) {
      testWidgets('${code.name}: a friendly inline message, the code stays', (t) async {
        if (code == FriendCodeFailureCode.offline) {
          remote.offline = true;
        } else {
          remote.addFailure = code;
        }
        final h = await pump(t, '/friends/code/ABCD2345');
        await _tap(t, 'friend-code-add', db: true);
        expect(find.text(text), findsOneWidget);
        expect(find.text('ABCD-2345'), findsOneWidget);
        expect(h.location, '/friends/code/ABCD2345');
      });
    }

    testWidgets('a short code is refused without a server call', (t) async {
      await pump(t, '/friends/code');
      await t.enterText(_key('friend-code-field'), 'AB');
      await t.pump();
      await _tap(t, 'friend-code-add');
      expect(find.text("That code doesn't match anyone. Check it and try again."), findsOneWidget);
      expect(remote.added, isEmpty);
    });

    testWidgets('a scanned friend QR adds at once', (t) async {
      scanned = 'splitify://friend?code=WXYZ6789';
      final h = await pump(t, '/friends/code');
      await _tap(t, 'friend-code-scan', db: true);
      expect(remote.added, ['WXYZ6789']);
      expect(h.location, '/friends/u%3Au2');
    });

    testWidgets('a scanned group invite goes to the join screen', (t) async {
      scanned = 'splitify://join?code=ABCD2345';
      final groups = FakeGroupsRemote()
        ..previews.add(const GroupFailure(GroupFailureCode.invalidCode));
      final h = await pump(t, '/friends/code', groups: groups);
      await _tap(t, 'friend-code-scan', db: true);
      expect(remote.added, isEmpty);
      expect(h.location, '/join/ABCD2345');
      expect(groups.calls, ['preview:ABCD2345'], reason: 'the join screen looks the invite up');
    });

    testWidgets('a QR that is no code says so', (t) async {
      scanned = 'upi://pay?pa=asha@okaxis';
      await pump(t, '/friends/code');
      await _tap(t, 'friend-code-scan');
      expect(find.text('That QR is not a Splitify friend code'), findsOneWidget);
    });
  });
}
