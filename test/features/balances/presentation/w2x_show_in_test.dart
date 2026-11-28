// W2-X P-9: "Show in INR" on the Home overall card and a friend's page header: saved conversions only,
// labelled, and what has no saved rate stays in its own currency (rule 4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/currency/application/in_currency_providers.dart';
import 'package:splitify/features/currency/domain/in_currency.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/ui/components/components.dart';

import '../../../support/group_fakes.dart' show sampleGroup;
import '../../../support/group_harness.dart';
import '../../friends/friend_fixtures.dart' as ff;
import '../../friends/presentation/friends_harness.dart';
import '../balance_fixtures.dart' hide sampleGroup;

final _goa = sampleGroup(id: gid, name: 'Goa trip');

const _twoCurrencies = MyBalances(
  totals: {'INR': 50000, 'USD': 2000},
  byGroup: {
    gid: {'INR': 50000, 'USD': 2000},
  },
  people: [
    PersonBalance(key: 'u:u2', name: 'Asha Rao', seed: 'm2', balances: {'INR': 50000, 'USD': 2000}),
  ],
);

List<Override> _home(MyBalances my, {InCurrency? inInr}) => [
  ...fixedGroupData(
    groups: <LocalGroup>[_goa],
    members: {gid: goaMembers()},
    balances: {gid: goaOwed()},
    my: my,
    stats: sampleStats,
  ),
  myTotalInProvider('INR').overrideWithValue(inInr),
];

Finder _key(String k) => find.byKey(Key(k));

String _text(WidgetTester t, String key) => t.widget<Text>(_key(key)).data!;

Future<void> _toggle(WidgetTester t) async {
  await t.ensureVisible(_key('show-in-currency'));
  await t.tap(_key('show-in-currency'));
  await settle(t);
}

void main() {
  group('Home overall card', () {
    testWidgets('one currency only: no switch', (t) async {
      await pumpGroups(t, '/groups', overrides: _home(myOwed));
      expect(_key('show-in-currency'), findsNothing);
    });

    testWidgets('rupees and dollars: "Show in INR" shows the saved-rate total, labelled', (
      t,
    ) async {
      await pumpGroups(
        t,
        '/groups',
        overrides: _home(
          _twoCurrencies,
          inInr: const InCurrency(
            currency: 'INR',
            amount: 125000,
            notConverted: {'EUR': 500},
            counted: true,
          ),
        ),
      );
      expect(find.text('Show in INR'), findsOneWidget);
      expect(_text(t, 'groups-overall-amount'), '₹500');
      await _toggle(t);
      expect(_text(t, 'groups-overall-converted'), '₹1,250');
      expect(_key('groups-overall-amount'), findsNothing);
      expect(find.text('In INR · saved rates'), findsOneWidget);
      expect(find.text('Also €5 not converted'), findsOneWidget);
      expect(find.text('By currency'), findsOneWidget);
      await _toggle(t);
      expect(_text(t, 'groups-overall-amount'), '₹500');
      expect(find.text('In INR · saved rates'), findsNothing);
    });

    testWidgets('no saved rates at all: says so and keeps every currency apart', (t) async {
      await pumpGroups(
        t,
        '/groups',
        overrides: _home(
          _twoCurrencies,
          inInr: const InCurrency(currency: 'INR', notConverted: {'USD': 2000}),
        ),
      );
      await _toggle(t);
      expect(find.text('No saved INR rates for these yet'), findsOneWidget);
      expect(_text(t, 'groups-overall-amount'), '₹500');
      expect(_key('groups-overall-converted'), findsNothing);
    });
  });

  group('friend page header', () {
    Future<void> pumpPage(WidgetTester t, List<Friend> friends, String key) => pumpFriends(
      t,
      FriendPage(friendKey: key),
      overrides: friendOverrides(AsyncData(friends)),
    ).then((_) {});

    testWidgets('a friend in two currencies: INR from saved rates, the rest kept apart', (t) async {
      final friends = friendsOf([ff.twoCurrencyLedger()], 'u1');
      await pumpPage(t, friends, 'u:u2');
      final before = t.widget<StatusPill>(_key('friend-status-owed')).label;
      expect(before, contains('₹10'));
      expect(before, contains(r'$20'));
      await _toggle(t);
      // No dollar record has a saved INR rate: the pill keeps the dollars next to the rupees.
      final after = t.widget<StatusPill>(_key('friend-status-owed')).label;
      expect(after, contains('₹10'));
      expect(after, contains(r'$20'));
      expect(find.text('In INR · saved rates'), findsOneWidget);
    });

    testWidgets('only rupees: no switch', (t) async {
      final friends = friendsOf([ff.goaLedger()], 'u1');
      await pumpPage(t, friends, 'u:u2');
      expect(_key('show-in-currency'), findsNothing);
    });
  });
}
