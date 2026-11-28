// Phase 09 balances on the Groups home (glass card, cards, Settle up), the group detail (status
// pill, Settle up, tabs) and the Account tab (wallet, breakdown, stats), on fixed provider data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/application/account_stats.dart' show AccountStats;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show BalancesTab;
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/ui/components/components.dart';

import '../../../support/group_fakes.dart' show sampleGroup;
import '../../../support/group_harness.dart';
import '../balance_fixtures.dart' hide sampleGroup;

final _goa = sampleGroup(id: gid, name: 'Goa trip');
final _flat = sampleGroup(id: flatGid, name: 'Flat 4B', type: 'home');
final _calm = sampleGroup(id: 'g-calm', name: 'Us two', type: 'couple');
final _members = {gid: goaMembers(), flatGid: flatMembers()};

List<Override> _data({
  List<LocalGroup>? groups,
  MyBalances my = noBalancesView,
  Map<String, GroupBalances>? balances,
  AccountStats? stats,
}) => [
  ...fixedGroupData(
    groups: groups ?? [_goa, _flat],
    members: _members,
    balances: balances ?? {gid: goaOwed(), flatGid: flatOwed()},
    my: my,
    stats: stats ?? sampleStats,
  ),
  // Settle up opens through the real router: give it a form that needs no database.
  settleProvider((groupId: flatGid, from: 'f2', to: 'f1', currency: 'INR', paymentId: null))
      .overrideWith(
        () => FixedSettleController((
          groupId: flatGid,
          from: 'f2',
          to: 'f1',
          currency: 'INR',
          paymentId: null,
        ), sampleSettleDraft()),
      ),
  settleProvider(settleArgsGoaAshaToMe)
      .overrideWith(() => FixedSettleController(settleArgsGoaAshaToMe, sampleSettleDraft())),
  settleProvider(settleArgsGoaOther)
      .overrideWith(() => FixedSettleController(settleArgsGoaOther, sampleSettleDraft())),
];

const noBalancesView = MyBalances(totals: {}, byGroup: {}, people: []);
const SettleArgs settleArgsGoaAshaToMe = (
  groupId: gid,
  from: 'm2',
  to: 'm1',
  currency: 'INR',
  paymentId: null,
);
const SettleArgs settleArgsGoaOther = (
  groupId: gid,
  from: null,
  to: null,
  currency: null,
  paymentId: null,
);

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

String _text(WidgetTester t, String key) => t.widget<Text>(_key(key)).data!;

String _pill(WidgetTester t, String key) => t.widget<StatusPill>(_key(key)).label;

GroupCoverCard _card(WidgetTester t, String id) => t.widget<GroupCoverCard>(_key('group-card-$id'));

/// Scrolls the page up by about one card row: the grid is lazy (S-454), so cards past the first screen
/// are only built once they come near it.
Future<void> _showSecondRow(WidgetTester t) async {
  await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
  await settle(t);
}

void main() {
  group('Groups home glass card', () {
    // TC-15-01
    testWidgets('owed: amount, status pill, caption and a Settle up button', (t) async {
      await pumpGroups(t, '/groups', overrides: _data(my: myOwed));
      expect(_text(t, 'groups-overall-amount'), '₹1,400');
      expect(_pill(t, 'groups-status-owed'), 'You are owed');
      expect(
        find.text('2 groups\u00A0· 2\u00A0people owe you\u00A0· you owe 1\u00A0person'),
        findsOneWidget,
      );
      expect(find.text('Overall'), findsOneWidget);
      expect(_key('groups-settle'), findsOneWidget);
      expect(find.text('Settle up'), findsOneWidget);
      expect(_key('groups-sync-marker'), findsNothing);
    });

    // TC-15-01
    testWidgets('owe: the amount I owe, and only the people I owe in the caption', (t) async {
      await pumpGroups(t, '/groups', overrides: _data(my: myOwe));
      expect(_text(t, 'groups-overall-amount'), '₹300');
      expect(_pill(t, 'groups-status-owe'), 'You owe');
      expect(find.text('2 groups\u00A0· you owe 1\u00A0person'), findsOneWidget);
    });

    // TC-15-01, TC-14-02
    testWidgets('owed in one currency and owing in another: signed amounts, never one total', (
      t,
    ) async {
      await pumpGroups(t, '/groups', overrides: _data(my: myMixed));
      expect(_pill(t, 'groups-status-mixed'), 'Owed and owing');
      expect(_text(t, 'groups-overall-amount'), allOf(contains('₹900'), startsWith('+')));
      expect(find.textContaining('\$20'), findsWidgets);
    });

    // TC-15-01
    testWidgets('settled: All settled, zero, and just the group count', (t) async {
      await pumpGroups(t, '/groups', overrides: _data());
      expect(_pill(t, 'groups-status-settled'), 'All settled');
      expect(_text(t, 'groups-overall-amount'), '₹0');
      expect(find.text('2 groups'), findsOneWidget);
    });

    // TC-15-01
    testWidgets('rows not on the server yet are marked on the glass card', (t) async {
      await pumpGroups(t, '/groups', overrides: _data(my: myOwedUnsynced));
      expect(_key('groups-sync-marker'), findsOneWidget);
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // TC-15-01
    testWidgets('no groups: a hint and no Settle up button', (t) async {
      await pumpGroups(t, '/groups', overrides: _data(groups: const []));
      expect(find.text('Add a group to start splitting bills.'), findsOneWidget);
      expect(_key('groups-settle'), findsNothing);
    });
  });

  group('Groups home cards', () {
    // TC-15-01
    testWidgets('each card shows my side in that group', (t) async {
      await pumpGroups(
        t,
        '/groups',
        overrides: _data(groups: [_goa, _flat, _calm], my: myOwed),
      );
      await _showSecondRow(t);
      expect(_card(t, gid).statusLabel, 'You are owed');
      expect(_card(t, gid).amountText, '₹900');
      expect(_card(t, flatGid).amountText, '₹500');
      expect(_card(t, 'g-calm').statusLabel, 'Settled');
      expect(_card(t, 'g-calm').amountText, isNull);
    });

    // TC-15-01
    testWidgets('a group where I owe says You owe', (t) async {
      await pumpGroups(t, '/groups', overrides: _data(my: myOwe));
      expect(_card(t, gid).statusLabel, 'You owe');
      expect(_card(t, gid).amountText, '₹300');
      expect(_card(t, flatGid).statusLabel, 'Settled');
    });

    // TC-15-01
    testWidgets('mixed currencies in a group show signed amounts', (t) async {
      await pumpGroups(
        t,
        '/groups',
        overrides: _data(groups: [_goa], my: myMixed, balances: {gid: goaMixed()}),
      );
      expect(_card(t, gid).statusLabel, 'Owed and owing');
      expect(
        _card(t, gid).amountText,
        allOf(contains('₹900'), contains('\$20'), contains('\u00A0· ')),
      );
    });

    // TC-15-01
    testWidgets('unsettled groups come first, then the rest in their order', (t) async {
      await pumpGroups(
        t,
        '/groups',
        overrides: _data(groups: [_calm, _goa, _flat], my: myOwed),
      );
      await _showSecondRow(t);
      Offset at(String id) => t.getTopLeft(_key('group-card-$id'));
      // Grid of two columns: goa top-left, flat top-right, the settled group on the second row.
      expect(at(gid).dy, at(flatGid).dy);
      expect(at(gid).dx, lessThan(at(flatGid).dx));
      expect(at('g-calm').dy, greaterThan(at(gid).dy));
      expect(find.text('ACTIVE GROUPS\u00A0· 3'), findsOneWidget);
    });

    // TC-15-01
    testWidgets('an archived group with nothing owed is labelled Archived', (t) async {
      final old = sampleGroup(id: 'g-old', name: 'Old trip', archivedAt: '2026-11-01T10:00:00Z');
      await pumpGroups(
        t,
        '/groups',
        overrides: _data(groups: [_goa, old], my: myOwed),
      );
      await _tap(t, 'groups-archived');
      expect(_card(t, 'g-old').statusLabel, 'Archived');
    });
  });

  group('Groups home Settle up', () {
    // TC-25-02
    testWidgets('opens a sheet with my transfers per group and Settle opens Settle up', (t) async {
      final h = await pumpGroups(t, '/groups', overrides: _data(my: myOwed));
      await _tap(t, 'groups-settle');
      expect(find.text('Settle up with'), findsOneWidget);
      final sheet = _key('settle-everywhere');
      expect(find.descendant(of: sheet, matching: find.text('GOA TRIP')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('FLAT 4B')), findsOneWidget);
      // D-033 rows: the other person and "owes you ₹…".
      expect(find.descendant(of: sheet, matching: find.text('Dev Shah')), findsOneWidget);
      expect(find.text('owes you ₹500'), findsOneWidget);
      await t.tap(_key('settle-pick-INR-f2-f1'));
      await settle(t);
      expect(h.location, '/settle?group=g-flat&from=f2&to=f1&currency=INR');
      expect(find.text('Settle up with'), findsNothing);
    });

    // TC-25-02
    testWidgets('with nothing to settle there is no Settle up button (final QA)', (t) async {
      await pumpGroups(
        t,
        '/groups',
        overrides: _data(groups: [_goa], balances: {gid: goaSettled()}),
      );
      expect(_key('groups-status-settled'), findsOneWidget);
      expect(_key('groups-settle'), findsNothing);
    });
  });

  group('Group detail', () {
    Future<GroupHarness> open(
      WidgetTester t,
      GroupBalances b, {
      LocalGroup? group,
      double scale = 1,
    }) => pumpGroups(
      t,
      '/groups/$gid',
      textScale: scale,
      overrides: _data(groups: [group ?? _goa], balances: {gid: b}),
    );

    // TC-15-02
    testWidgets('status pill: owed', (t) async {
      await open(t, goaOwed());
      expect(_pill(t, 'group-status-owed'), 'You are owed ₹900');
    });

    // TC-15-02
    testWidgets('status pill: owe', (t) async {
      await open(t, goaOwe());
      expect(_pill(t, 'group-status-owe'), 'You owe ₹300');
    });

    // TC-15-02, TC-14-02
    testWidgets('status pill: mixed carries the signed amounts', (t) async {
      await open(t, goaMixed());
      final label = _pill(t, 'group-status-mixed');
      expect(label, startsWith('Owed and owing\u00A0· '));
      expect(label, allOf(contains('₹900'), contains('\$20')));
    });

    // TC-15-02
    testWidgets('status pill: settled', (t) async {
      await open(t, goaSettled());
      expect(_pill(t, 'group-status-settled'), 'All settled');
    });

    // TC-15-02
    testWidgets('an archived group shows Archived instead of a balance', (t) async {
      await open(
        t,
        goaOwed(),
        group: sampleGroup(id: gid, name: 'Goa trip', archivedAt: '2026-11-01T10:00:00Z'),
      );
      expect(_key('group-status-owed'), findsNothing);
      expect(find.text('Archived'), findsWidgets);
      expect(_key('group-settle'), findsNothing);
    });

    // TC-25-02
    testWidgets('Settle up opens the picker; a transfer opens Settle up prefilled', (t) async {
      final h = await open(t, goaOwed());
      await _tap(t, 'group-settle');
      expect(_key('settle-picker'), findsOneWidget);
      expect(find.text('owes you ₹1,200'), findsOneWidget);
      await t.tap(_key('settle-pick-INR-m2-m1'));
      await settle(t);
      expect(h.location, '/settle?group=g-goa&from=m2&to=m1&currency=INR');
    });

    // TC-25-02
    testWidgets('the picker offers a different payment when everyone is settled', (t) async {
      final h = await open(t, goaSettled());
      await _tap(t, 'group-settle');
      expect(find.text('Everyone in this group is settled up.'), findsOneWidget);
      await t.tap(_key('settle-other'));
      await settle(t);
      expect(h.location, '/settle?group=g-goa');
    });

    // TC-15-03
    testWidgets('the Balances tab shows the banner and the pairs', (t) async {
      await open(t, goaOwed());
      await t.tap(find.text('Balances'));
      await settle(t);
      expect(find.byType(BalancesTab), findsOneWidget);
      expect(find.text('You are owed here'), findsOneWidget);
      expect(find.text('Asha Rao owes you'), findsOneWidget);
    });

    // TC-21-02
    testWidgets('the Totals tab opens with its empty state when nothing was spent', (t) async {
      await open(t, goaOwed());
      await t.tap(find.text('Totals'));
      await settle(t);
      expect(find.text('No spending yet'), findsOneWidget);
    });

    // TC-15-02
    testWidgets('large text: both bottom buttons are still there', (t) async {
      await open(t, goaOwed(), scale: 2);
      expect(_key('group-settle'), findsOneWidget);
      expect(_key('group-add-expense'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Account wallet', () {
    WalletCard wallet(WidgetTester t) => t.widget<WalletCard>(_key('account-wallet'));

    // TC-15-01
    testWidgets('owed: the amount, the status and how many groups', (t) async {
      await pumpGroups(t, '/account', overrides: _data(my: myOwed));
      expect(wallet(t).amounts, ['₹1,400']);
      expect(wallet(t).statusLabel, 'You are owed');
      expect(wallet(t).caption, 'Across 2 groups');
    });

    // TC-15-01
    testWidgets('owe, mixed and settled', (t) async {
      await pumpGroups(t, '/account', overrides: _data(my: myOwe));
      expect(wallet(t).amounts, ['₹300']);
      expect(wallet(t).statusLabel, 'You owe');
    });

    // TC-15-01, TC-14-02
    testWidgets('mixed currencies list one signed amount each', (t) async {
      await pumpGroups(t, '/account', overrides: _data(my: myMixed));
      expect(wallet(t).statusLabel, 'Owed and owing');
      expect(wallet(t).amounts, hasLength(2));
      expect(wallet(t).amounts.first, allOf(contains('₹900'), startsWith('+')));
      expect(wallet(t).amounts.last, contains('\$20'));
    });

    // TC-15-01
    testWidgets('settled shows ₹0 and All settled', (t) async {
      await pumpGroups(t, '/account', overrides: _data());
      expect(wallet(t).amounts, ['₹0']);
      expect(wallet(t).statusLabel, 'All settled');
    });

    // TC-15-01
    // D-033 (S-344): the "Your stats" card (expenses, groups) is gone; the spending card keeps the numbers.
    testWidgets('the spending card shows this month, groups and people', (t) async {
      await pumpGroups(t, '/account', overrides: _data(my: myOwed));
      expect(find.text('₹12,345.50'), findsOneWidget);
      expect(find.text('18'), findsNothing);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });

    // TC-15-01
    testWidgets('tapping the wallet lists my balance in each group', (t) async {
      final h = await pumpGroups(t, '/account', overrides: _data(my: myOwed));
      await _tap(t, 'account-wallet');
      expect(find.text('Balances by group'), findsOneWidget);
      expect(_key('wallet-breakdown'), findsOneWidget);
      final goa = t.widget<AmountRow>(_key('wallet-group-g-goa'));
      expect((goa.title, goa.amountText, goa.amountCaption), ('Goa trip', '₹900', 'You are owed'));
      expect(t.widget<AmountRow>(_key('wallet-group-g-flat')).amountText, '₹500');
      await t.tap(_key('wallet-group-g-flat'));
      await settle(t);
      expect(h.location, '/groups/g-flat');
    });

    // TC-15-01
    testWidgets('the breakdown says everything is settled when it is', (t) async {
      await pumpGroups(t, '/account', overrides: _data());
      await _tap(t, 'account-wallet');
      expect(find.text("You're all settled up in every group."), findsOneWidget);
      expect(_key('wallet-breakdown'), findsNothing);
    });
  });
}
