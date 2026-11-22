import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/features/groups/presentation/join_screen.dart';
import 'package:splitify/ui/components/components.dart';

import '../../support/group_fakes.dart';
import '../../support/group_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  if (_key(key).evaluate().isEmpty) {
    await tester.scrollUntilVisible(_key(key), 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(_key(key));
  await tester.pump();
  await tester.tap(_key(key));
  await settle(tester);
}

Future<void> _enterCode(WidgetTester tester, String text) async {
  await tester.enterText(_key('join-code'), text);
  await tester.pump();
}

String _fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.descendant(of: _key('join-code'), matching: find.byType(TextField)))
    .controller!
    .text;

bool _submitEnabled(WidgetTester tester) =>
    tester.widget<PillButton>(_key('join-submit')).onPressed != null;

const _ravi = (id: 'm1', name: 'Ravi', tint: 1);
const _neha = (id: 'm2', name: 'Neha', tint: 2);
const _dev = (id: 'm3', name: 'Dev', tint: null);

FakeGroupsRemote _remoteWith(Object preview) => FakeGroupsRemote()..previews.add(preview);

void main() {
  // ---------------------------------------------------------------- TC-3-03 states
  group('Join screen', () {
    testWidgets('TC-3-03 typing formats the code with an auto dash and O becomes 0', (
      tester,
    ) async {
      await pumpGroups(tester, '/join', overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      expect(_fieldText(tester), 'ABCD-EFGH');
      await _enterCode(tester, 'abcdefgo');
      expect(_fieldText(tester), 'ABCD-EFG0');
      await _enterCode(tester, 'ab');
      expect(_fieldText(tester), 'AB');
    });

    testWidgets('TC-3-03 a malformed code is refused without calling the server', (tester) async {
      final h = await pumpGroups(tester, '/join', overrides: fixedGroupData());
      await _enterCode(tester, 'abc');
      await _tap(tester, 'join-find');
      expect(find.text("That code doesn't match any group"), findsOneWidget);
      expect(h.remote.calls, isEmpty);
    });

    testWidgets('TC-3-03 typing again clears the error', (tester) async {
      await pumpGroups(tester, '/join', overrides: fixedGroupData());
      await _enterCode(tester, 'abc');
      await _tap(tester, 'join-find');
      await _enterCode(tester, 'abcd');
      expect(find.text("That code doesn't match any group"), findsNothing);
    });

    testWidgets('TC-3-03 INVALID_CODE from the server shows the same message', (tester) async {
      final remote = _remoteWith(const GroupFailure(GroupFailureCode.invalidCode));
      await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      expect(remote.calls, ['preview:ABCDEFGH']);
      expect(find.text("That code doesn't match any group"), findsOneWidget);
    });

    testWidgets('TC-3-03 RATE_LIMITED asks the user to wait', (tester) async {
      final remote = _remoteWith(const GroupFailure(GroupFailureCode.rateLimited));
      await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      expect(find.text('Too many tries. Wait a minute and try again.'), findsOneWidget);
    });

    testWidgets('TC-3-03 offline says joining needs internet', (tester) async {
      final remote = _remoteWith(const GroupFailure(GroupFailureCode.offline));
      await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      expect(find.text('Joining needs internet'), findsOneWidget);
    });

    testWidgets('TC-3-03 preview shows the cover, the name and the member count', (tester) async {
      final remote = _remoteWith(samplePreview(memberCount: 5));
      await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      expect(_key('join-preview'), findsOneWidget);
      expect(find.text('Goa trip'), findsWidgets);
      expect(find.text('5 members'), findsOneWidget);
      // No free spots: "I'm new here" is implied and joining is allowed straight away.
      expect(_key('join-carousel'), findsNothing);
      expect(_submitEnabled(tester), isTrue);
      expect(find.text('Join group'), findsWidgets);
    });

    testWidgets('TC-3-03 an archived group shows the read-only notice', (tester) async {
      final remote = _remoteWith(samplePreview(archived: true));
      await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      expect(
        find.text('This group is archived. You can join, but it is read-only.'),
        findsOneWidget,
      );
    });

    testWidgets('TC-3-03 already a member: Open group opens it without joining', (tester) async {
      final remote = _remoteWith(samplePreview(alreadyMember: true));
      final h = await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      expect(find.text("You're already in this group."), findsOneWidget);
      expect(find.text('Open group'), findsOneWidget);
      await _tap(tester, 'join-submit');
      expect(h.location, '/groups/g-goa');
      expect(remote.calls, ['preview:ABCDEFGH']);
    });

    testWidgets('TC-3-03 /join?code= looks the group up straight away', (tester) async {
      final remote = _remoteWith(samplePreview());
      await pumpGroups(tester, '/join?code=ABCDEFGH', remote: remote, overrides: fixedGroupData());
      expect(remote.calls, ['preview:ABCDEFGH']);
      expect(_key('join-preview'), findsOneWidget);
    });

    testWidgets('TC-3-03 /join/:code looks the group up straight away', (tester) async {
      final remote = _remoteWith(samplePreview());
      await pumpGroups(tester, '/join/abcd-efgh', remote: remote, overrides: fixedGroupData());
      expect(remote.calls, ['preview:ABCDEFGH']);
      expect(_key('join-preview'), findsOneWidget);
    });

    testWidgets('TC-3-03 a bad code in the link stays on the enter step', (tester) async {
      final remote = FakeGroupsRemote();
      await pumpGroups(tester, '/join?code=nope', remote: remote, overrides: fixedGroupData());
      expect(remote.calls, isEmpty);
      expect(_key('join-find'), findsOneWidget);
    });

    testWidgets('TC-3-03 scanning a Splitify QR shows the preview', (tester) async {
      final remote = _remoteWith(samplePreview());
      await pumpGroups(
        tester,
        '/join',
        remote: remote,
        overrides: [
          ...fixedGroupData(),
          qrScannerProvider.overrideWithValue((_) async => 'splitify://join?code=ABCDEFGH'),
        ],
      );
      await _tap(tester, 'join-scan');
      expect(remote.calls, ['preview:ABCDEFGH']);
      expect(_key('join-preview'), findsOneWidget);
    });

    testWidgets('TC-3-03 scanning something else says it is not an invite', (tester) async {
      final remote = FakeGroupsRemote();
      await pumpGroups(
        tester,
        '/join',
        remote: remote,
        overrides: [
          ...fixedGroupData(),
          qrScannerProvider.overrideWithValue((_) async => 'https://example.com/not-a-qr'),
        ],
      );
      await _tap(tester, 'join-scan');
      expect(find.text('That QR is not a Splitify invite'), findsOneWidget);
      expect(remote.calls, isEmpty);
    });

    testWidgets('TC-3-03 closing the scanner without a code changes nothing', (tester) async {
      final remote = FakeGroupsRemote();
      await pumpGroups(
        tester,
        '/join',
        remote: remote,
        overrides: [...fixedGroupData(), qrScannerProvider.overrideWithValue((_) async => null)],
      );
      await _tap(tester, 'join-scan');
      expect(remote.calls, isEmpty);
      expect(find.text('That QR is not a Splitify invite'), findsNothing);
    });

    testWidgets('TC-3-03 Use another code goes back to the enter step', (tester) async {
      final remote = _remoteWith(samplePreview());
      await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      await _tap(tester, 'join-other-code');
      expect(_key('join-find'), findsOneWidget);
      expect(_key('join-preview'), findsNothing);
    });

    testWidgets('TC-3-04 joining without a spot calls join and opens the group', (tester) async {
      final remote = _remoteWith(samplePreview())..joinedGroupId = 'g-goa';
      final h = await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      await _tap(tester, 'join-submit');
      expect(remote.calls, ['preview:ABCDEFGH', 'join:ABCDEFGH:-']);
      expect(h.syncs, isNotEmpty, reason: 'the group is pulled onto the phone after joining');
      expect(h.location, '/groups/g-goa');
      expect(find.text('You joined Goa trip'), findsOneWidget);
    });

    testWidgets('TC-3-04 a join the server refuses shows its message', (tester) async {
      final remote = _remoteWith(samplePreview())
        ..joins.add(const GroupFailure(GroupFailureCode.groupFull));
      final h = await pumpGroups(tester, '/join', remote: remote, overrides: fixedGroupData());
      await _enterCode(tester, 'abcdefgh');
      await _tap(tester, 'join-find');
      await _tap(tester, 'join-submit');
      expect(find.text('This group already has 100 members.'), findsOneWidget);
      expect(h.location, '/join');
    });
  });

  // ---------------------------------------------------------------- TC-4-03 claim picker
  group('Claim picker', () {
    Future<GroupHarness> openPicker(WidgetTester tester, FakeGroupsRemote remote) async {
      final h = await pumpGroups(
        tester,
        '/join?code=ABCDEFGH',
        remote: remote,
        overrides: fixedGroupData(),
      );
      expect(_key('join-carousel'), findsOneWidget);
      return h;
    }

    testWidgets('TC-4-03 free spots show the carousel; submit waits for a choice', (tester) async {
      final remote = _remoteWith(samplePreview(unclaimed: [_ravi, _neha, _dev]));
      await openPicker(tester, remote);
      expect(find.text('Are you one of these people?'), findsOneWidget);
      expect(find.text("I'm Ravi"), findsOneWidget);
      expect(find.text("I'm new here"), findsOneWidget);
      expect(_submitEnabled(tester), isFalse);
      await _tap(tester, 'join-claim');
      expect(_submitEnabled(tester), isTrue);
      expect(find.text('Join as Ravi'), findsOneWidget);
    });

    testWidgets('TC-4-03 claiming the first spot joins with its member id', (tester) async {
      final remote = _remoteWith(samplePreview(unclaimed: [_ravi, _neha, _dev]))
        ..joinedGroupId = 'g-goa';
      final h = await openPicker(tester, remote);
      await _tap(tester, 'join-claim');
      await _tap(tester, 'join-submit');
      expect(remote.calls, ['preview:ABCDEFGH', 'join:ABCDEFGH:m1']);
      expect(h.location, '/groups/g-goa');
    });

    testWidgets('TC-4-03 swiping the carousel changes who you claim', (tester) async {
      final remote = _remoteWith(samplePreview(unclaimed: [_ravi, _neha, _dev]));
      await openPicker(tester, remote);
      await tester.drag(find.byType(PageView), const Offset(-70, 0));
      await settle(tester);
      expect(find.text("I'm Neha"), findsOneWidget);
      // Swiping counts as a choice.
      expect(_submitEnabled(tester), isTrue);
      expect(find.text('Join as Neha'), findsOneWidget);
      await _tap(tester, 'join-submit');
      expect(remote.calls.last, 'join:ABCDEFGH:m2');
    });

    testWidgets("TC-4-03 I'm new here joins without a claim", (tester) async {
      final remote = _remoteWith(samplePreview(unclaimed: [_ravi, _neha]));
      await openPicker(tester, remote);
      await _tap(tester, 'join-new');
      expect(_submitEnabled(tester), isTrue);
      await _tap(tester, 'join-submit');
      expect(remote.calls.last, 'join:ABCDEFGH:-');
    });

    testWidgets('TC-4-03 ALREADY_CLAIMED re-checks the free spots', (tester) async {
      final remote = FakeGroupsRemote()
        ..previews.addAll([
          samplePreview(unclaimed: [_ravi, _neha]),
          samplePreview(unclaimed: [_neha]),
        ])
        ..joins.add(const GroupFailure(GroupFailureCode.alreadyClaimed));
      final h = await openPicker(tester, remote);
      await _tap(tester, 'join-claim');
      await _tap(tester, 'join-submit');
      expect(remote.calls, ['preview:ABCDEFGH', 'join:ABCDEFGH:m1', 'preview:ABCDEFGH']);
      expect(h.location, '/join?code=ABCDEFGH');
      // The list is fresh: Ravi is gone, the choice starts again.
      expect(find.text("I'm Neha"), findsOneWidget);
      expect(find.text("I'm Ravi"), findsNothing);
      expect(_submitEnabled(tester), isFalse);
    });

    testWidgets('TC-4-03 ALREADY_CLAIMED keeps its message on screen after the re-check', (
      tester,
    ) async {
      final remote = FakeGroupsRemote()
        ..previews.addAll([
          samplePreview(unclaimed: [_ravi, _neha]),
          samplePreview(unclaimed: [_neha]),
        ])
        ..joins.add(const GroupFailure(GroupFailureCode.alreadyClaimed));
      await openPicker(tester, remote);
      await _tap(tester, 'join-claim');
      await _tap(tester, 'join-submit');
      expect(find.text('Someone already claimed that spot. Pick another one.'), findsOneWidget);
      expect(_key('join-error'), findsOneWidget);
    });
  });
}
