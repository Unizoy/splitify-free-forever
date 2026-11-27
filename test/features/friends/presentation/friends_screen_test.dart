// TC-2-03 (Friends tab states), TC-16-01 (friend totals per currency on the rows): the Friends tab and the
// "Add friend expense" sheet, driven by fixed friends and a fake FriendActions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart';
import 'package:splitify/features/friends/presentation/friends_screen.dart';
import 'package:splitify/ui/components/components.dart';

import '../../expenses/presentation/presentation_harness.dart';
import '../friend_fixtures.dart';
import 'friends_harness.dart';

Finder _row(String key) => find.byKey(ValueKey('friend-$key'));

/// Where the stub route that was pushed says it is.
String _stub(WidgetTester t) => t.widget<Text>(find.byKey(const Key('stub'))).data!;

Finder _inRow(String key, Finder what) => find.descendant(of: _row(key), matching: what);

void main() {
  late List<Friend> friends;
  late FakeFriendActions? actions;

  setUp(() {
    friends = sampleFriends();
    actions = null;
  });

  Future<dynamic> pumpTab(
    WidgetTester t, {
    AsyncValue<List<Friend>>? value,
    bool unsynced = false,
    double scale = 1,
    FakeFriendActions Function(Ref ref)? make,
  }) => pumpFriends(
    t,
    const FriendsScreen(),
    scale: scale,
    overrides: friendOverrides(
      value ?? AsyncData(friends),
      unsynced: unsynced,
      actions:
          make ??
          (ref) {
            return actions = FakeFriendActions(ref);
          },
    ),
  );

  group('Friends tab states', () {
    // TC-2-03
    testWidgets('loading shows the skeleton and no list', (t) async {
      await pumpTab(t, value: const AsyncLoading());
      expect(find.byType(FriendsSkeleton), findsOneWidget);
      expect(find.byKey(const Key('friends-list')), findsNothing);
      expect(find.text('FRIENDS'), findsOneWidget);
    });

    // TC-2-03
    testWidgets('a failed load says so', (t) async {
      await pumpTab(t, value: AsyncError(Exception('db'), StackTrace.empty));
      expect(find.text('Balances could not be loaded'), findsOneWidget);
    });

    // TC-2-03
    testWidgets('no friends yet shows the empty state, and Add friend expense is still there', (
      t,
    ) async {
      await pumpTab(t, value: const AsyncData(<Friend>[]));
      expect(find.text('No friends yet'), findsOneWidget);
      expect(find.text('People you share a group with show up here.'), findsOneWidget);
      expect(find.byKey(const Key('friends-add-expense')), findsOneWidget);
      expect(find.byKey(const Key('friends-list')), findsNothing);
    });

    // TC-2-03
    testWidgets('the hero, the section count and the search field show', (t) async {
      await pumpTab(t);
      expect(find.text('FRIENDS\u00A0· 4'), findsOneWidget);
      expect(find.byKey(const Key('friends-search')), findsOneWidget);
      expect(find.text('Search friends'), findsOneWidget);
      expect(find.text('Add friend expense'), findsOneWidget);
    });

    // TC-2-03
    testWidgets('anything unsynced shows the "not synced yet" marker', (t) async {
      await pumpTab(t);
      expect(find.byType(SyncMarker), findsNothing);
      await pumpTab(t, unsynced: true);
      expect(find.byType(SyncMarker), findsOneWidget);
    });
  });

  group('Friends rows', () {
    // TC-16-01
    testWidgets('lists everyone alphabetically with their groups', (t) async {
      await pumpTab(t);
      expect(find.byType(FriendRow), findsNWidgets(4));
      final names = [
        for (final r in t.widgetList<FriendRow>(find.byType(FriendRow))) r.friend.name,
      ];
      expect(names, ['Asha Rao', 'Dev Shah', 'Meera Iyer', 'Rahul Mehta']);
      expect(_inRow('u:u2', find.text('Goa trip\u00A0· Flat 4B')), findsOneWidget);
      expect(_inRow('u:u3', find.text('Goa trip')), findsOneWidget);
      expect(_inRow('u:u8', find.text('Bali')), findsOneWidget);
    });

    // TC-16-01
    testWidgets('someone who owes me: green amount and "owes you"', (t) async {
      await pumpTab(t);
      // Rahul owes me 70.00.
      expect(_inRow('m:a3', find.text('owes you')), findsOneWidget);
      expect(_inRow('m:a3', find.textContaining('₹70')), findsOneWidget);
    });

    // TC-16-01
    testWidgets('someone I owe: amount and "you owe"', (t) async {
      await pumpTab(t);
      // Asha: +60 Goa, -100 Flat 4B, +25 direct = I owe 15.00.
      expect(_inRow('u:u2', find.text('you owe')), findsOneWidget);
      expect(_inRow('u:u2', find.textContaining('₹15')), findsOneWidget);
    });

    // TC-16-01
    testWidgets('a friend with nothing between us is "settled up" without an amount', (t) async {
      await pumpTab(t);
      expect(_inRow('u:u3', find.text('settled up')), findsOneWidget);
      expect(_inRow('u:u3', find.textContaining('₹')), findsNothing);
    });

    // TC-16-01
    testWidgets('owed in one currency and owing in another: both listed with signs, never summed', (
      t,
    ) async {
      await pumpTab(t);
      expect(_inRow('u:u8', find.text('Owed and owing')), findsOneWidget);
      expect(_inRow('u:u8', find.textContaining('+\u2060₹5')), findsOneWidget);
      expect(_inRow('u:u8', find.textContaining('−\u2060\$20')), findsOneWidget);
    });

    // TC-2-03
    testWidgets('a name-only friend with only a direct group shows "Friend expenses"', (t) async {
      final direct = friendsOf([directLedger()], 'u1');
      await pumpTab(t, value: AsyncData(direct));
      expect(_inRow('u:u2', find.text('Friend expenses')), findsOneWidget);
    });

    // TC-2-03
    testWidgets('three or more shared groups show the first two and a count', (t) async {
      final many = friendsOf([goaLedger(), flatLedger(), cycleLedger(), twoCurrencyLedger()], 'u1');
      await pumpTab(t, value: AsyncData(many));
      expect(_inRow('u:u2', find.text('Goa trip\u00A0· Flat 4B +2')), findsOneWidget);
    });

    // TC-2-03
    testWidgets('tapping a row opens the friend page', (t) async {
      await pumpTab(t);
      await t.tap(_row('m:a3'));
      await settle(t);
      expect(_stub(t), 'at /friends/m%3Aa3');
    });

    // TC-2-03
    testWidgets('large text still lays out (text scale 2.0)', (t) async {
      await pumpTab(t, scale: 2);
      expect(find.byType(FriendRow), findsWidgets);
      expect(t.takeException(), isNull);
    });
  });

  group('Friends search', () {
    Future<void> type(WidgetTester t, String text) async {
      await t.enterText(find.byKey(const Key('friends-search')), text);
      await settle(t, 2);
    }

    // TC-2-03
    testWidgets('filters by name in any case', (t) async {
      await pumpTab(t);
      await type(t, 'ASH');
      expect(find.byType(FriendRow), findsOneWidget);
      expect(_row('u:u2'), findsOneWidget);
      expect(find.text('FRIENDS\u00A0· 4'), findsOneWidget, reason: 'the count is of all friends');
    });

    // TC-2-03
    testWidgets('no match says who was not found; the clear button brings everyone back', (
      t,
    ) async {
      await pumpTab(t);
      expect(find.byKey(const Key('friends-search-clear')), findsNothing);
      await type(t, 'zzz');
      expect(find.text('No one called “zzz”'), findsOneWidget);
      expect(find.byType(FriendRow), findsNothing);
      expect(find.byKey(const Key('friends-search-clear')), findsOneWidget);

      await t.tap(find.byKey(const Key('friends-search-clear')));
      await settle(t, 2);
      expect(find.text('No one called “zzz”'), findsNothing);
      expect(find.byType(FriendRow), findsNWidgets(4));
      expect(find.byKey(const Key('friends-search-clear')), findsNothing);
    });
  });

  // D-033: the editor opens at once; its "With you and" picker chooses the friend (no friend sheet first).
  group('Add friend expense', () {
    testWidgets('D-033 Add friend expense opens the one-screen editor at once', (t) async {
      await pumpTab(t);
      await t.tap(find.byKey(const Key('friends-add-expense')));
      await settle(t, 10);
      expect(_stub(t), 'at /expense/new');
      expect(find.byKey(const Key('add-friend-picker')), findsNothing);
      expect(actions?.asked ?? const <String>[], isEmpty);
    });

    testWidgets('D-033 with no friends it opens the editor too', (t) async {
      await pumpTab(t, value: const AsyncData(<Friend>[]));
      await t.tap(find.byKey(const Key('friends-add-expense')));
      await settle(t, 10);
      expect(_stub(t), 'at /expense/new');
    });
  });
}
