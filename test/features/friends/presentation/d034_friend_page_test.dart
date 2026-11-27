// D-034 on the friend page: B1 the Settle up sheet starts with "Everything with Asha" when we have balances in
// several groups (it opens the batch form), B5 settled history collapses behind "Show settled items (N)", and B3
// a push that cannot go offers "Share instead".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart' show syncRepositoryProvider;
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart' show textSharerProvider;
import 'package:splitify/features/notifications/application/notifications_providers.dart'
    show notificationsRemoteProvider;

import '../../../support/fakes.dart' show FakeSyncRepository;
import '../../../support/ledger_seed.dart';
import '../../../support/notification_fakes.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../friend_fixtures.dart';
import 'friends_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

String _stub(WidgetTester t) => t.widget<Text>(_key('stub')).data!;

/// Asha settled everything with me in our friend group: a movie, her payment back.
List<Friend> _settledAsha() => friendsOf(
  [
    ledgerOf(
      seedGroup(id: 'g3', name: 'Me & Asha', type: 'direct'),
      [
        seedMember('c1', groupId: 'g3', name: 'Mohit Bindal', userId: 'u1'),
        seedMember('c2', groupId: 'g3', name: 'Asha', userId: 'u2', position: 1),
      ],
      expenses: [
        seedExpense(
          'e5',
          groupId: 'g3',
          description: 'Movie',
          date: '2026-11-02',
          total: 5000,
          payers: {'c1': 5000},
          shares: {'c1': 2500, 'c2': 2500},
        ),
      ],
      payments: [
        seedPayment('p9', groupId: 'g3', from: 'c2', to: 'c1', amount: 2500, date: '2026-11-04'),
      ],
    ),
  ],
  'u1',
  profileNames: profileNames,
);

void main() {
  final shared = <String>[];

  Future<void> pumpPage(
    WidgetTester t,
    String key,
    List<Friend> friends, {
    FakeNotificationsRemote? remote,
  }) {
    shared.clear();
    return pumpFriends(
      t,
      FriendPage(friendKey: key),
      overrides: [
        ...friendOverrides(AsyncData(friends), actions: (ref) => FakeFriendActions(ref)),
        notificationsRemoteProvider.overrideWithValue(remote ?? FakeNotificationsRemote()),
        syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
        textSharerProvider.overrideWithValue((text) async => shared.add(text)),
      ],
    );
  }

  group('B1 Settle up with several groups', () {
    testWidgets('the sheet starts with "Everything with Asha" (all groups, one form)', (t) async {
      // Goa: she owes me ₹60; our friend group: ₹25. Both in rupees.
      final two = friendsOf([goaLedger(), directLedger()], 'u1', profileNames: profileNames);
      await pumpPage(t, 'u:u2', two);
      await t.tap(_key('friend-settle'));
      await settle(t, 10);
      expect(find.text('Everything with Asha Rao'), findsOneWidget);
      expect(find.text('owes you ₹85 · 2 groups'), findsOneWidget);
      expect(find.text('Or settle one group'), findsOneWidget);
      expect(
        t.getTopLeft(_key('settle-all-INR')).dy,
        lessThan(t.getTopLeft(_key('friend-settle-one-group')).dy),
      );
      await t.tap(_key('settle-all-INR'));
      await settle(t, 10);
      expect(_stub(t), 'at /settle/all?friend=u%3Au2&currency=INR');
    });

    testWidgets('owing and owed in different groups: the net, the way it goes', (t) async {
      // Sample Asha: owes me ₹60 (Goa) and ₹25 (direct), I owe her ₹100 (Flat): I owe ₹15 overall.
      await pumpPage(t, 'u:u2', sampleFriends());
      await t.tap(_key('friend-settle'));
      await settle(t, 10);
      expect(find.text('you owe ₹15 · 3 groups'), findsOneWidget);
    });

    testWidgets('a single balance still opens the form at once', (t) async {
      await pumpPage(t, 'u:u2', friendsOf([goaLedger()], 'u1', profileNames: profileNames));
      await t.tap(_key('friend-settle'));
      await settle(t, 10);
      expect(_key('friend-settle-picker'), findsNothing);
      expect(_stub(t), startsWith('at /settle?group=g1'));
    });
  });

  group('B5 settled history', () {
    testWidgets('settled in every currency: the history hides behind one row', (t) async {
      await pumpPage(t, 'u:u2', _settledAsha());
      expect(_key('friend-status-settled'), findsOneWidget);
      expect(find.text('Show settled items (2)'), findsOneWidget);
      expect(find.text('Movie'), findsNothing);
      await t.tap(_key('friend-show-settled'));
      await settle(t);
      expect(find.text('Movie'), findsOneWidget);
      expect(find.text('Hide settled items'), findsOneWidget);
      await t.tap(_key('friend-show-settled'));
      await settle(t);
      expect(find.text('Movie'), findsNothing);
    });

    testWidgets('a balance open: everything is listed as before', (t) async {
      await pumpPage(t, 'u:u2', friendsOf([directLedger()], 'u1', profileNames: profileNames));
      expect(_key('friend-show-settled'), findsNothing);
      expect(find.text('Movie'), findsOneWidget);
    });
  });

  group('B3 share instead', () {
    testWidgets('a push that cannot go (offline) offers "Share instead", which shares the text', (
      t,
    ) async {
      final remote = FakeNotificationsRemote()
        ..reminderError = const ReminderFailure(ReminderFailureCode.offline);
      await pumpPage(
        t,
        'u:u2',
        friendsOf([goaLedger()], 'u1', profileNames: profileNames),
        remote: remote,
      );
      await t.tap(_key('friend-remind'));
      await settle(t);
      expect(find.text('Needs internet. Connect and try again.'), findsOneWidget);
      await t.tap(find.text('Share instead'));
      await settle(t);
      expect(_key('remind-share-sheet'), findsOneWidget);
      await t.tap(_key('remind-share'));
      await settle(t);
      expect(shared.single, 'Hi Asha Rao, a reminder about ₹60 for “Goa trip”.');
    });
  });
}
