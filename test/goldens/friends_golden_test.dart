import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/upi/upi_link.dart';
import 'package:splitify/data/data_providers.dart' show groupUnsyncedProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/friends/presentation/friends_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;
import 'package:splitify/features/groups/presentation/group_settings_screen.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';
import 'package:splitify/features/payments/presentation/upi_pay.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/balances/balance_fixtures.dart';
import '../features/friends/friend_fixtures.dart';
import '../features/friends/presentation/friends_harness.dart';
import '../support/group_fakes.dart' as gf;
import 'golden_support.dart';

/// One golden scenario: the screen, what feeds it, and the frame height (long screens scroll in the
/// app; the picture shows the top of them).
typedef _Case = ({
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  double height,
});

_Case _case(
  String name,
  Widget Function() screen,
  List<Override> Function() overrides, {
  double height = 915,
}) => (name: name, screen: screen, overrides: overrides, height: height);

/// What a bottom sheet looks like over its scrim (a routed modal cannot be captured inside alchemist's
/// own app frame, so the sheet body is drawn directly).
Widget _sheet(String title, Widget body) => Builder(
  builder: (context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: title, child: body),
    ),
  ),
);

UpiLink _link() => const UpiLinkBuilder().build(
  vpa: 'asha.rao@okaxis',
  name: 'Asha Rao',
  amountMinor: 50000,
  currencyCode: 'INR',
  note: 'Splitify: Goa trip',
);

/// Goa trip where I owe Asha (who has a UPI ID) 500.00.
GroupBalances _iOweAsha() => GroupBalances(
  groupId: gid,
  groupName: 'Goa trip',
  mainCurrency: 'INR',
  members: goaMembers(),
  byCurrency: const {
    'INR': Balances(
      nets: {'m1': -50000, 'm2': 50000, 'm3': 0, 'm4': 0},
      pairs: [Transfer('m1', 'm2', 50000)],
      simplified: [Transfer('m1', 'm2', 50000)],
    ),
  },
  meId: 'm1',
  hasRecords: true,
);

const SettleArgs _upiArgs = (groupId: gid, from: 'm1', to: 'm2', currency: 'INR', paymentId: null);

List<Override> _upiSettle() => [
  settleProvider(_upiArgs).overrideWith(
    () => FixedSettleController(
      _upiArgs,
      sampleSettleDraft(from: 'm1', to: 'm2', amountText: '500', balances: _iOweAsha()),
    ),
  ),
  upiIdProvider('u2').overrideWith((ref) => Stream.value('asha.rao@okaxis')),
];

List<Friend> _ashaOwed() =>
    friendsOf([goaLedger(), directLedger()], 'u1', profileNames: profileNames);

/// Celebration as the dialog shows it, with its entrance animation at the last frame.
Widget _celebration() => Builder(
  builder: (context) {
    final l = AppLocalizations.of(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: Scaffold(
        backgroundColor: context.colors.scrim,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Celebration(
                  lead: l.celebrationLead,
                  highlight: l.celebrationHighlight,
                  message: l.celebrationSettledWith('Asha'),
                  seed: 'Asha',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

List<_Case> _cases() => [
  _case(
    'friends_tab',
    () => const FriendsScreen(),
    () => friendOverrides(AsyncData(sampleFriends())),
  ),
  _case(
    'friends_empty',
    () => const FriendsScreen(),
    () => friendOverrides(const AsyncData(<Friend>[])),
  ),
  _case(
    'friend_page_owed',
    () => const FriendPage(friendKey: 'u:u2'),
    () => friendOverrides(AsyncData(_ashaOwed())),
    height: 1300,
  ),
  _case(
    'friend_page_owe',
    () => const FriendPage(friendKey: 'u:u2'),
    () => friendOverrides(AsyncData(sampleFriends())),
    height: 1400,
  ),
  _case(
    'settle_up_upi',
    () => const SettleUpScreen(groupId: gid, from: 'm1', to: 'm2', currency: 'INR'),
    _upiSettle,
    height: 1500,
  ),
  _case(
    'upi_return_sheet',
    () => _sheet(
      'Did the payment go through?',
      UpiResultSheet(link: _link(), payeeName: 'Asha Rao', amountMinor: 50000),
    ),
    () => const [],
  ),
  _case(
    'upi_no_app_sheet',
    () => _sheet(
      'No UPI app found',
      UpiResultSheet(link: _link(), payeeName: 'Asha Rao', amountMinor: 50000, noApp: true),
    ),
    () => const [],
  ),
  _case(
    'group_settings_simplify',
    () => const GroupSettingsScreen(groupId: gid),
    () => [
      groups.groupProvider.overrideWith((ref, id) => Stream.value(gf.sampleGroup(id: gid))),
      groups.groupMembersProvider.overrideWith((ref, id) => Stream.value(goaMembers())),
      groupUnsyncedProvider.overrideWith((ref, id) => Stream.value(false)),
      groups.currentUserIdProvider.overrideWithValue('u1'),
    ],
    height: 1100,
  ),
  _case('settled_celebration', _celebration, () => const []),
];

void main() {
  // Phase 11 screens: light and dark at text scale 1.0 and 2.0 (TC-B3-03).
  for (final c in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 11 ${c.name} ${mode.name} $suffix',
          fileName: 'friends_${c.name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(
            c.screen(),
            overrides: c.overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, c.height),
          ),
        );
      }
    }
  }
}
