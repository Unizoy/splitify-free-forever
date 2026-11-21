import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/features/activity/presentation/activity_screen.dart';
import 'package:splitify/features/activity/presentation/group_activity_screen.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
import 'package:splitify/features/balances/presentation/totals_tab.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../data/sync/sync_fakes.dart' show FakeClock;
import '../features/balances/balance_fixtures.dart';
import '../support/fakes.dart' hide FakeClock;
import '../support/group_fakes.dart' as gf;
import '../support/group_harness.dart' show fixedGroupData;
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

class _TabHost extends StatelessWidget {
  const _TabHost(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: child,
      ),
    ),
  );
}

/// The Expenses tab with payments: its own scope, because the shared harness already fixes the
/// group's payments to none.
class _ListWithPayments extends StatelessWidget {
  const _ListWithPayments();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      groupExpenseViewsProvider(gid).overrideWithValue(AsyncData(sampleViews())),
      groupPaymentViewsProvider(gid).overrideWithValue(AsyncData(samplePayments())),
    ],
    child: const _TabHost(ExpenseList(groupId: gid)),
  );
}

List<Override> _balances(GroupBalances b) => [
  groupBalancesProvider(gid).overrideWithValue(AsyncData(b)),
];

SettleUpScreen _settleScreen() =>
    const SettleUpScreen(groupId: gid, from: 'm1', to: 'm3', currency: 'INR');

List<Override> _settle(SettleDraft d) => [
  settleProvider(settleArgs).overrideWith(() => FixedSettleController(settleArgs, d)),
];

List<_Case> _cases() => [
  _case('tab_owed', () => const _TabHost(BalancesTab(groupId: gid)), () => _balances(goaOwed())),
  _case(
    'tab_settled',
    () => const _TabHost(BalancesTab(groupId: gid)),
    () => _balances(goaSettled()),
  ),
  _case(
    'tab_simplified',
    () => const _TabHost(BalancesTab(groupId: gid)),
    () => _balances(goaOwed(simplify: true)),
  ),
  _case(
    'tab_two_currencies',
    () => const _TabHost(BalancesTab(groupId: gid)),
    () => _balances(goaMixed()),
    height: 1500,
  ),
  _case('tab_empty', () => const _TabHost(BalancesTab(groupId: gid)), () => _balances(goaEmpty())),
  _case(
    'totals',
    () => const _TabHost(TotalsTab(groupId: gid)),
    () => [groupTotalsProvider(gid).overrideWithValue(AsyncData(sampleTotals()))],
    height: 1000,
  ),
  _case(
    'settle_up_partial',
    _settleScreen,
    () => _settle(sampleSettleDraft(amountText: '150', note: 'Thanks for the cab')),
    height: 1350,
  ),
  _case(
    'settle_up_nothing_owed',
    _settleScreen,
    () => _settle(sampleSettleDraft(to: 'm4', amountText: '')),
    height: 1350,
  ),
  _case(
    'payment_detail',
    () => const PaymentDetailScreen(paymentId: 'p1'),
    () => [
      paymentViewProvider('p1').overrideWithValue(AsyncData(paymentView())),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      // Phase 12: the comment thread (empty here; its states are in history_comments_golden_test).
      commentThreadProvider((groupId: gid, targetType: 'payment', targetId: 'p1'))
          .overrideWithValue(const AsyncData([])),
    ],
  ),
  _case(
    'activity_screen',
    () => const ActivityScreen(),
    () => [activityItemsProvider(null).overrideWithValue(AsyncData(sampleActivity()))],
    height: 1100,
  ),
  _case(
    'group_activity',
    () => const GroupActivityScreen(groupId: gid),
    () => [
      activityItemsProvider(gid).overrideWithValue(AsyncData(sampleActivity())),
      groupProvider.overrideWith((ref, id) => Stream.value(gf.sampleGroup(id: gid))),
    ],
    height: 1000,
  ),
  _case('expense_list_payments', () => const _ListWithPayments(), () => const [], height: 1000),
];

/// The activity feed on its own (TC-18-03): day headers, sentences, amounts, a pending row.
class _FeedFrame extends StatelessWidget {
  const _FeedFrame();

  @override
  Widget build(BuildContext context) => _TabHost(ActivityFeed(items: sampleActivity()));
}

const _frame = Size(goldenWidth, 915);

/// A whole app (router, themes) in a phone-sized frame, signed in as `u1`, with fixed data.
class _PhoneApp extends StatelessWidget {
  const _PhoneApp({
    required this.location,
    required this.mode,
    required this.scale,
    required this.prefs,
    required this.data,
  });

  final String location;
  final ThemeMode mode;
  final double scale;
  final SharedPreferences prefs;
  final List<Override> data;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: _frame,
    child: ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: const AuthUser(id: 'u1')),
        ),
        profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
        groupsRemoteProvider.overrideWithValue(gf.FakeGroupsRemote()),
        syncNowProvider.overrideWithValue(() async {}),
        syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 10))),
        ...data,
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: _frame,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          textScaler: TextScaler.linear(scale),
        ),
        child: MaterialApp.router(
          routerConfig: buildRouter(initialLocation: location),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          debugShowCheckedModeBanner: false,
        ),
      ),
    ),
  );
}

List<Override> _homeData() => fixedGroupData(
  groups: [
    gf.sampleGroup(id: gid, name: 'Goa trip'),
    gf.sampleGroup(id: flatGid, name: 'Flat 4B', type: 'home', createdAt: '2026-11-19T10:00:00Z'),
    gf.sampleGroup(id: 'g-calm', name: 'Us two', type: 'couple', createdAt: '2026-11-18T10:00:00Z'),
  ],
  members: {gid: goaMembers(), flatGid: flatMembers()},
  balances: {gid: goaOwed(), flatGid: flatOwed()},
  my: myOwed,
  stats: sampleStats,
);

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // TC-18-03 (activity feed) and the phase 09 screens: light and dark at text scale 1.0 and 2.0.
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final (suffix, scale) in goldenScales) {
      // TC-18-03
      goldenTest(
        'TC-18-03 activity feed ${mode.name} $suffix',
        fileName: 'balances_activity_feed_${mode.name}_$suffix',
        pumpBeforeTest: pumpFixedFrames,
        builder: () => expenseApp(const _FeedFrame(), mode: mode, scale: scale),
      );
    }
  }

  for (final c in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 09 ${c.name} ${mode.name} $suffix',
          fileName: 'balances_${c.name}_${mode.name}_$suffix',
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

  // The router uses a shared navigator key, so these run one app at a time.
  for (final (name, route) in const [('groups_home', '/groups'), ('account', '/account')]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'phase 09 $name with balances ${mode.name} $suffix',
          fileName: 'balances_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () =>
              _PhoneApp(location: route, mode: mode, scale: scale, prefs: prefs, data: _homeData()),
        );
      }
    }
  }
}
