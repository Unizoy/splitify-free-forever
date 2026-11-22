// TC-2-03 (friend page states), TC-16-01 (what each group shows between us), TC-25-02 (Settle up from a
// friend): the friend page, driven by fixed friends and a fake FriendActions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/ui/components/components.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../friend_fixtures.dart';
import 'friends_harness.dart';

Finder _inKey(String key, Finder what) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: what);

String _stub(WidgetTester t) => t.widget<Text>(find.byKey(const Key('stub'))).data!;

void main() {
  late FakeFriendActions? actions;

  setUp(() => actions = null);

  Future<void> pumpPage(
    WidgetTester t,
    String key, {
    List<Friend>? friends,
    AsyncValue<List<Friend>>? value,
    bool unsynced = false,
    double scale = 1,
    GroupFailure? failure,
  }) async {
    await pumpFriends(
      t,
      FriendPage(friendKey: key),
      scale: scale,
      overrides: friendOverrides(
        value ?? AsyncData(friends ?? sampleFriends()),
        unsynced: unsynced,
        actions: (ref) => actions = FakeFriendActions(ref, failure: failure),
      ),
    );
  }

  group('FriendPage states', () {
    // TC-2-03
    testWidgets('a friend that is not on this phone says so', (t) async {
      await pumpPage(t, 'u:nobody');
      expect(find.text("This friend isn't on this phone"), findsOneWidget);
      expect(find.byKey(const Key('friend-settle')), findsNothing);
    });

    // TC-2-03
    testWidgets('while loading it shows the loader, not "not found"', (t) async {
      await pumpPage(t, 'u:u2', value: const AsyncLoading());
      expect(find.byType(DotsPulse), findsOneWidget);
      expect(find.text("This friend isn't on this phone"), findsNothing);
    });

    // TC-2-03
    testWidgets('settled: a settled pill and an empty "nothing shared" list', (t) async {
      await pumpPage(t, 'u:u3');
      expect(find.text('Dev Shah'), findsWidgets);
      expect(find.byKey(const Key('friend-status-settled')), findsOneWidget);
      expect(_inKey('friend-status-settled', find.text('All settled')), findsOneWidget);
      expect(find.text('Nothing shared yet'), findsOneWidget);
      expect(find.text('Add an expense with Dev Shah to get started.'), findsOneWidget);
      // Dev is only in Goa, so "By group" lists it with nothing owed.
      expect(find.text('BY GROUP'), findsOneWidget);
      expect(_inKey('friend-group-g1', find.text('settled up')), findsOneWidget);
    });

    // TC-16-01
    testWidgets('owed: the pill says who owes what', (t) async {
      await pumpPage(t, 'm:a3');
      expect(_inKey('friend-status-owed', find.text('Rahul Mehta owes you ₹70')), findsOneWidget);
      expect(find.byKey(const Key('friend-status-owe')), findsNothing);
    });

    // TC-16-01
    testWidgets('owing: the pill says what I owe', (t) async {
      await pumpPage(t, 'u:u2');
      expect(_inKey('friend-status-owe', find.text('You owe Asha Rao ₹15')), findsOneWidget);
    });

    // TC-16-01
    testWidgets('owed and owing in two currencies: one pill with both, signed', (t) async {
      await pumpPage(t, 'u:u8');
      expect(find.byKey(const Key('friend-status-mixed')), findsOneWidget);
      expect(find.text('Owed and owing · +₹5 · −\$20'), findsOneWidget);
    });

    // TC-2-03
    testWidgets('anything unsynced shows the "not synced yet" marker', (t) async {
      await pumpPage(t, 'u:u2', unsynced: true);
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // TC-2-03
    testWidgets('large text (2.0) stacks the buttons and lays out', (t) async {
      await pumpPage(t, 'u:u2', scale: 2);
      expect(find.byKey(const Key('friend-settle')), findsOneWidget);
      expect(find.byKey(const Key('friend-add-expense')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('FriendPage content', () {
    // TC-16-01
    testWidgets('"By group" shows what each shared group shows between us, with the direct one', (
      t,
    ) async {
      await pumpPage(t, 'u:u2');
      expect(find.text('BY GROUP'), findsOneWidget);
      expect(_inKey('friend-group-g1', find.text('Goa trip')), findsOneWidget);
      expect(_inKey('friend-group-g1', find.text('owes you')), findsOneWidget);
      expect(_inKey('friend-group-g1', find.textContaining('₹60')), findsOneWidget);
      expect(_inKey('friend-group-g2', find.text('Flat 4B')), findsOneWidget);
      expect(_inKey('friend-group-g2', find.text('you owe')), findsOneWidget);
      expect(_inKey('friend-group-g2', find.textContaining('₹100')), findsOneWidget);
      expect(_inKey('friend-group-g3', find.text('Just you two')), findsOneWidget);
      expect(_inKey('friend-group-g3', find.textContaining('₹25')), findsOneWidget);
    });

    // TC-2-03
    testWidgets('tapping a normal group opens it; the direct group is not a link', (t) async {
      await pumpPage(t, 'u:u2');
      await t.ensureVisible(find.byKey(const ValueKey('friend-group-g3')));
      await t.tap(find.byKey(const ValueKey('friend-group-g3')), warnIfMissed: false);
      await settle(t);
      expect(find.byKey(const Key('stub')), findsNothing);
      await t.ensureVisible(find.byKey(const ValueKey('friend-group-g1')));
      await t.tap(find.byKey(const ValueKey('friend-group-g1')));
      await settle(t);
      expect(_stub(t), 'at /groups/g1');
    });

    // TC-2-03
    testWidgets('a friend I only share a direct group with has no "By group" section', (t) async {
      final only = friendsOf([directLedger()], 'u1');
      await pumpPage(t, 'u:u2', friends: only);
      expect(find.text('BY GROUP'), findsNothing);
      expect(find.text('SHARED EXPENSES'), findsOneWidget);
      expect(find.byKey(const ValueKey('friend-item-e5')), findsOneWidget);
    });

    // TC-2-03
    testWidgets('expense and payment rows with the group and date, newest first', (t) async {
      await pumpPage(t, 'u:u2');
      expect(find.text('SHARED EXPENSES'), findsOneWidget);
      // Newest first: Movie (22 Nov), the payment (21 Nov), Rent and Dinner (20 Nov).
      double top(String id) => t.getTopLeft(find.byKey(ValueKey('friend-item-$id'))).dy;
      expect(top('e5'), lessThan(top('p1')));
      expect(top('p1'), lessThan(top('e3')));
      expect(top('e3'), lessThan(top('e1')));
      // Only what involves both of us.
      expect(find.byKey(const ValueKey('friend-item-e2')), findsNothing);
      expect(find.byKey(const ValueKey('friend-item-p2')), findsNothing);

      expect(_inKey('friend-item-e1', find.text('Dinner')), findsOneWidget);
      expect(_inKey('friend-item-e1', find.text('Goa trip · 20 Nov')), findsOneWidget);
      expect(_inKey('friend-item-e1', find.textContaining('₹100')), findsOneWidget);
      expect(_inKey('friend-item-e1', find.text('you lent')), findsOneWidget);
      expect(_inKey('friend-item-e3', find.text('you borrowed')), findsOneWidget);
      expect(_inKey('friend-item-e5', find.text('Just you two · 22 Nov')), findsOneWidget);

      expect(_inKey('friend-item-p1', find.text('Asha Rao paid you')), findsOneWidget);
      expect(_inKey('friend-item-p1', find.text('Goa trip · 21 Nov')), findsOneWidget);
      expect(_inKey('friend-item-p1', find.textContaining('₹40')), findsOneWidget);
      expect(_inKey('friend-item-p1', find.text('you received')), findsOneWidget);
    });

    // TC-2-03
    testWidgets('a payment I made reads "You paid <friend>"', (t) async {
      final goa = goaLedger();
      final ledger = ledgerOf(
        goa.group,
        goa.members,
        payments: [seedPayment('p5', groupId: 'g1', from: 'a1', to: 'a2', amount: 2500)],
      );
      await pumpPage(t, 'u:u2', friends: friendsOf([ledger], 'u1'));
      expect(_inKey('friend-item-p5', find.text('You paid Asha')), findsOneWidget);
      expect(_inKey('friend-item-p5', find.text('you paid')), findsOneWidget);
    });

    // TC-2-03
    testWidgets('month headers split the list', (t) async {
      final goa = goaLedger();
      final ledger = ledgerOf(
        goa.group,
        goa.members,
        expenses: [
          ...goa.expenses,
          seedExpense(
            'e0',
            groupId: 'g1',
            description: 'Welcome drinks',
            date: '2026-10-30',
            total: 2000,
            payers: {'a2': 2000},
            shares: {'a1': 1000, 'a2': 1000},
          ),
        ],
      );
      await pumpPage(t, 'u:u2', friends: friendsOf([ledger], 'u1'));
      expect(find.text('NOVEMBER 2026'), findsOneWidget);
      expect(find.text('OCTOBER 2026'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('NOVEMBER 2026')).dy,
        lessThan(t.getTopLeft(find.text('OCTOBER 2026')).dy),
      );
      expect(
        t.getTopLeft(find.byKey(const ValueKey('friend-item-e1'))).dy,
        lessThan(t.getTopLeft(find.text('OCTOBER 2026')).dy),
      );
    });

    // TC-2-03
    testWidgets('an unsynced expense shows its marker', (t) async {
      final goa = goaLedger();
      final ledger = ledgerOf(
        goa.group,
        goa.members,
        expenses: [
          seedExpense(
            'e0',
            groupId: 'g1',
            total: 2000,
            payers: {'a2': 2000},
            shares: {'a1': 1000, 'a2': 1000},
            syncState: 'pending',
          ),
        ],
      );
      await pumpPage(t, 'u:u2', friends: friendsOf([ledger], 'u1'));
      expect(_inKey('friend-item-e0', find.byType(SyncMarker)), findsOneWidget);
    });

    // TC-2-03
    testWidgets('tapping an item opens the expense or the payment', (t) async {
      await pumpPage(t, 'u:u2');
      await t.ensureVisible(find.byKey(const ValueKey('friend-item-e1')));
      await t.tap(find.byKey(const ValueKey('friend-item-e1')));
      await settle(t);
      expect(_stub(t), 'at /expense/e1');
    });

    // TC-2-03
    testWidgets('tapping a payment opens it', (t) async {
      await pumpPage(t, 'u:u2');
      await t.ensureVisible(find.byKey(const ValueKey('friend-item-p1')));
      await t.tap(find.byKey(const ValueKey('friend-item-p1')));
      await settle(t);
      expect(_stub(t), 'at /payment/p1');
    });
  });

  group('FriendPage actions', () {
    // TC-25-02
    testWidgets('Settle up with exactly one transfer opens Settle up prefilled', (t) async {
      await pumpPage(t, 'm:a3');
      await t.tap(find.byKey(const Key('friend-settle')));
      await settle(t);
      expect(_stub(t), 'at /settle?group=g1&from=a3&to=a1&currency=INR');
    });

    // TC-25-02
    testWidgets('Settle up with several transfers asks which one, by group', (t) async {
      await pumpPage(t, 'u:u2');
      await t.tap(find.byKey(const Key('friend-settle')));
      await settle(t, 10);
      expect(find.byKey(const Key('friend-settle-picker')), findsOneWidget);
      expect(find.text('Settle up with Asha Rao'), findsOneWidget);
      expect(find.byKey(const Key('stub')), findsNothing);
      // One "Settle" per transfer: Goa trip, Flat 4B, Just you two.
      final settles = find.descendant(
        of: find.byKey(const Key('friend-settle-picker')),
        matching: find.text('Settle'),
      );
      expect(settles, findsNWidgets(3));

      // The second one is what I owe Asha in Flat 4B.
      await t.tap(settles.at(1));
      await settle(t, 10);
      expect(_stub(t), 'at /settle?group=g2&from=b1&to=b2&currency=INR');
      expect(find.byKey(const Key('friend-settle-picker')), findsNothing);
    });

    // TC-25-02
    testWidgets('Settle up with nothing between us says "settled up"', (t) async {
      await pumpPage(t, 'u:u3');
      await t.tap(find.byKey(const Key('friend-settle')));
      await settle(t);
      expect(find.text('You and Dev Shah are settled up'), findsOneWidget);
      expect(find.byKey(const Key('stub')), findsNothing);
      expect(find.byKey(const Key('friend-settle-picker')), findsNothing);
    });

    // TC-2-03
    testWidgets('the invite button shows only for a name-only friend that has a direct group', (
      t,
    ) async {
      final tanviDirect = ledgerOf(seedGroup(id: 'g9', name: 'Me & Tanvi', type: 'direct'), [
        seedMember('d1', groupId: 'g9', name: 'Mohit Bindal', userId: 'u1'),
        seedMember('d2', groupId: 'g9', name: 'Tanvi', position: 1),
      ]);
      final all = friendsOf([tanviDirect, goaLedger(), directLedger()], 'u1');
      await pumpPage(t, 'm:d2', friends: all);
      expect(find.byKey(const Key('friend-invite')), findsOneWidget);
      expect(find.byTooltip('Invite Tanvi to claim their spot'), findsOneWidget);
    });

    // TC-2-03
    testWidgets('no invite for a name-only friend without a direct group, or for a linked friend', (
      t,
    ) async {
      await pumpPage(t, 'm:a3');
      expect(find.byKey(const Key('friend-invite')), findsNothing);
      await pumpPage(t, 'u:u2');
      expect(find.byKey(const Key('friend-invite')), findsNothing);
    });

    // TC-2-03
    testWidgets('Add expense opens the stepper in our direct group', (t) async {
      await pumpPage(t, 'u:u2');
      await t.tap(find.byKey(const Key('friend-add-expense')));
      await settle(t);
      expect(actions!.asked, ['u:u2']);
      expect(_stub(t), 'at /expense/new?group=g-friend');
    });

    // TC-2-03
    testWidgets('Add expense offline for a linked friend with no direct group needs the internet', (
      t,
    ) async {
      final noDirect = friendsOf([goaLedger()], 'u1', profileNames: profileNames);
      await pumpPage(
        t,
        'u:u2',
        friends: noDirect,
        failure: const GroupFailure(GroupFailureCode.offline),
      );
      await t.tap(find.byKey(const Key('friend-add-expense')));
      await settle(t);
      expect(
        find.text(
          'Connect to the internet once to start sharing with Asha Rao. After that it works offline.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('stub')), findsNothing);
    });

    // TC-2-03 (S-116)
    testWidgets('Record a loan opens the loan form with the friend picked', (t) async {
      await pumpPage(t, 'u:u2');
      await t.tap(find.byKey(const Key('friend-loan')));
      await settle(t);
      expect(actions!.asked, ['loan u:u2']);
      expect(_stub(t), 'at /loan/new?group=g-friend&with=c2');
    });

    // TC-2-03 (S-116)
    testWidgets('Record a loan offline for a new linked friend needs the internet', (t) async {
      await pumpPage(t, 'u:u2', failure: const GroupFailure(GroupFailureCode.offline));
      await t.tap(find.byKey(const Key('friend-loan')));
      await settle(t);
      expect(find.textContaining('Connect to the internet once'), findsOneWidget);
    });
  });
}
