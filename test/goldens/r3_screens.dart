// R3-A screen catalogue for the size matrix (r3_sizes_golden_test.dart): every main screen and sheet with
// fixed sample data, built for any phone/tablet size, theme and text scale. Routed screens use the real
// router (tab shell, capsule nav); the rest are pumped as the app's home like the feature goldens.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/account/presentation/account_settings_sheet.dart';
import 'package:splitify/features/account/presentation/appearance_screen.dart';
import 'package:splitify/features/activity/application/monthly_summary.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/paid_split_sheet.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/loan_screen.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';
import 'package:splitify/features/notifications/presentation/notification_settings_screen.dart';
import 'package:splitify/features/notifications/presentation/notifications_screen.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';
import 'package:splitify/features/receipt_scan/application/receipt_ocr.dart';
import 'package:splitify/features/receipt_scan/presentation/scan_review_sheet.dart';
import 'package:splitify/features/search/application/search_controller.dart';
import 'package:splitify/features/search/application/search_everything.dart';
import 'package:splitify/features/search/presentation/search_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/account/crash_toggle_test.dart' show accountSettingsOverrides;
import '../features/balances/balance_fixtures.dart' as bf;
import '../features/expenses/expense_fixtures.dart';
import '../features/expenses/presentation/loan_screen_test.dart'
    show FixedLoanController, newLoan, sampleLoan;
import '../features/friends/friend_fixtures.dart' as ff;
import '../features/friends/presentation/friends_harness.dart';
import '../features/insights/insights_fixtures.dart' as inf;
import '../features/notifications/presentation/notif_harness.dart';
import '../support/attachment_fixtures.dart';
import '../support/fakes.dart';
import '../support/group_fakes.dart' as gf;
import '../support/group_harness.dart' show fixedGroupData;
import '../support/notification_fakes.dart';
import '../support/sample_photo.dart';

/// Builds one screen at [size] in [mode] with text scale [scale].
typedef R3Build = Widget Function(SharedPreferences prefs, Size size, ThemeMode mode, double scale);

/// One screen or sheet of the matrix.
typedef R3Screen = ({String name, R3Build build});

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

final _now = DateTime.utc(2026, 11, 22, 10);

/// The whole app at [location] (router, tab shell), signed in as `u1`, with [data] and then [extra]
/// (an inner scope, so it may replace what [data] fixes).
class _Routed extends StatelessWidget {
  const _Routed({
    required this.location,
    required this.prefs,
    required this.size,
    required this.mode,
    required this.scale,
    this.data = const [],
    this.extra = const [],
    this.sync,
  });

  final String location;
  final SharedPreferences prefs;
  final Size size;
  final ThemeMode mode;
  final double scale;
  final List<Override> data;
  final List<Override> extra;
  final FakeSyncRepository? sync;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: const AuthUser(id: 'u1')),
        ),
        profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
        groupsRemoteProvider.overrideWithValue(
          gf.FakeGroupsRemote()
            ..previews.add(
              gf.samplePreview(
                memberCount: 4,
                unclaimed: const [
                  (id: 'u-1', name: 'Ravi', tint: 1),
                  (id: 'u-2', name: 'Neha', tint: 3),
                ],
              ),
            ),
        ),
        syncNowProvider.overrideWithValue(() async {}),
        syncRepositoryProvider.overrideWithValue(
          sync ??
              FakeSyncRepository(
                status: SyncStatus(
                  phase: SyncPhase.idle,
                  lastSync: _now.subtract(const Duration(minutes: 5)),
                ),
              ),
        ),
        clockProvider.overrideWithValue(FakeClock(_now)),
        ...data,
      ],
      child: ProviderScope(
        overrides: [monthSummaryProvider.overrideWithValue(null), ...extra],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            textScaler: TextScaler.linear(scale),
          ),
          child: MaterialApp.router(
            routerConfig: buildRouter(initialLocation: location),
            localizationsDelegates: _delegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    ),
  );
}

/// A sheet body at the bottom of a dimmed screen, like the real modal sheet (D-032 golden pattern).
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.title, required this.child});

  final String Function(AppLocalizations l) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height - 24),
        child: AppSheet(title: title(AppLocalizations.of(context)), child: child),
      ),
    ),
  );
}

/// A plain page around [child] (lists that live on a tab).
class _Page extends StatelessWidget {
  const _Page({required this.child});

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

R3Screen _routed(
  String name,
  String location, {
  List<Override> Function()? data,
  List<Override> Function()? extra,
  FakeSyncRepository Function()? sync,
}) => (
  name: name,
  build: (prefs, size, mode, scale) => _Routed(
    location: location,
    prefs: prefs,
    size: size,
    mode: mode,
    scale: scale,
    data: data?.call() ?? _richData(),
    extra: extra?.call() ?? const [],
    sync: sync?.call(),
  ),
);

R3Screen _home(
  String name,
  Widget Function() screen,
  List<Override> Function() overrides, {
  bool targets = false,
}) => (
  name: name,
  build: (prefs, size, mode, scale) => expenseApp(
    screen(),
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides()],
    mode: mode,
    scale: scale,
    size: size,
    targets: targets ? sampleTargets() : const [],
  ),
);

/// Four groups, balances in two of them, the Goa expenses, activity and friends.
List<Override> _richData() => fixedGroupData(
  groups: [
    gf.sampleGroup(id: gid, name: 'Goa trip'),
    gf.sampleGroup(
      id: bf.flatGid,
      name: 'Flat 4B',
      type: 'home',
      createdAt: '2026-11-19T10:00:00Z',
    ),
    gf.sampleGroup(id: 'g-us', name: 'Us two', type: 'couple', createdAt: '2026-11-18T10:00:00Z'),
    gf.sampleGroup(
      id: 'g-office',
      name: 'Office lunches with the whole design team',
      type: 'other',
      createdAt: '2026-11-17T10:00:00Z',
    ),
  ],
  members: {gid: bf.goaMembers(), bf.flatGid: bf.flatMembers()},
  balances: {gid: bf.goaOwed(), bf.flatGid: bf.flatOwed()},
  expenses: {gid: sampleViews()},
  my: bf.myOwed,
  stats: bf.sampleStats,
  activity: bf.sampleActivity(),
);

List<Friend> _friends() => ff.sampleFriends();

List<Friend> _ashaOwed() =>
    friendsOf([ff.goaLedger(), ff.directLedger()], 'u1', profileNames: ff.profileNames);

const ExpenseEditorArgs _editArgs = (groupId: null, expenseId: 'e1');
const ExpenseEditorArgs _newArgs = (groupId: gid, expenseId: null);

List<Override> _editor(ExpenseDraft Function() draft) => [
  friendsProvider.overrideWithValue(
    const AsyncData([
      Friend(key: 'u:vikram', name: 'Vikram Shah', seed: 'm9', links: [], balances: {}),
    ]),
  ),
  for (final a in [_editArgs, _newArgs])
    expenseEditorProvider(a).overrideWith(() => FixedEditorController(a, draft())),
];

ExpenseDraft _newDraft() => sampleDraft(
  amount: '',
  description: '',
  category: 'other.general',
  categoryOrigin: CategoryOrigin.initial,
  expenseId: null,
  canRepeat: true,
);

ExpenseDraft _editDraft() => sampleDraft(
  amount: '12345.50',
  description: 'Dinner at Thalassa with the whole gang',
  notes: 'Table by the window',
);

ExpenseDraft _itemsFull() {
  var it = SplitDraft.initial(ids, 2).switchToItems().items!;
  final k = it.items.first.key;
  it = it.setName(k, 'Paneer tikka').setAmount(k, '360');
  it = it.toggleMember(k, 'm3').toggleMember(k, 'm4');
  it = it.addItem(ids);
  it = it.setName(it.items[1].key, 'Butter naan').setAmount(it.items[1].key, '160');
  it = it.addItem(const ['m3']);
  it = it.setName(it.items[2].key, 'Mango lassi').setAmount(it.items[2].key, '120');
  it = it.setExtra(ItemExtra.tax, '32').setExtra(ItemExtra.service, '32');
  return sampleDraft(
    expenseId: null,
    amount: '704',
    description: 'Dinner at Punjab Grill',
    split: SplitDraft.initial(ids, 2).withItems(it),
  );
}

ScanOutcome _found() => (
  scan: parseReceipt(const [
    'HOTEL SARAVANA BHAVAN',
    'Date: 21/11/2026',
    'Masala Dosa  2  90.00  180.00',
    'Ghee Roast  1  140.00  140.00',
    'Mini Meals  2  220.00  440.00',
    'Filter Coffee  4  35.00  140.00',
    'Sub Total  900.00',
    'Service Charge @ 5%  45.00',
    'CGST @ 2.5%  23.63',
    'SGST @ 2.5%  23.63',
    'Round Off  -0.26',
    'Grand Total  Rs. 992.00',
  ]),
  photo: PreparedImage(full: samplePhotoPng, thumb: samplePhotoPng),
);

List<Override> _detail(String id, ExpenseView view) => [
  noRepeat(id),
  expenseViewProvider(id).overrideWithValue(AsyncData(view)),
  noAttachments(id),
  expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
  commentThreadProvider((groupId: gid, targetType: 'expense', targetId: id))
      .overrideWithValue(const AsyncData([])),
];

const SettleArgs _upiArgs = (groupId: gid, from: 'm1', to: 'm2', currency: 'INR', paymentId: null);

/// I owe Asha ₹12,500 (she has a UPI ID).
GroupBalances _oweAsha() => GroupBalances(
  groupId: gid,
  groupName: 'Goa trip',
  mainCurrency: 'INR',
  members: bf.goaMembers(),
  byCurrency: const {
    'INR': Balances(
      nets: {'m1': -1250000, 'm2': 1250000, 'm3': 0, 'm4': 0},
      pairs: [Transfer('m1', 'm2', 1250000)],
      simplified: [Transfer('m1', 'm2', 1250000)],
    ),
  },
  meId: 'm1',
  hasRecords: true,
);

/// Search controller with a fixed state (no typing in goldens).
class _FixedSearch extends ExpenseSearchController {
  _FixedSearch(this.fixed) : super(null);

  final SearchState fixed;

  @override
  SearchState build() => fixed;
}

List<SearchHit> _hits() => [
  (
    view: sampleView(
      sampleExpense(
        id: 'r3',
        description: 'Villa rent',
        category: 'rent.rent',
        date: '2026-11-20',
        total: 4000000,
        payers: const {'m1': 4000000},
        syncState: SyncState.pending,
      ),
    ),
    groupName: 'Goa trip',
  ),
  (
    view: sampleView(
      sampleExpense(
        id: 'x1',
        description: 'Rent for the scooter, two days',
        category: 'travel.fuel',
        date: '2026-10-12',
        total: 150000,
        payers: const {'m2': 150000},
        shares: const {'m1': 75000, 'm2': 75000},
      ),
    ),
    groupName: 'Flat 302',
  ),
  (
    view: sampleView(
      sampleExpense(
        id: 'r1',
        description: 'Villa rent',
        category: 'rent.rent',
        date: '2026-09-20',
        total: 4000000,
        payers: const {'m1': 4000000},
      ),
    ),
    groupName: 'Goa trip',
  ),
];

List<Override> _search() => [
  searchControllerProvider(null).overrideWith(() => _FixedSearch(const SearchState(text: 'rent'))),
  searchResultsProvider(null).overrideWithValue(AsyncData(_hits())),
  searchGroupsProvider.overrideWith((ref) => Stream.value([sampleGroup()])),
  searchPaymentHitsProvider(null).overrideWithValue(const AsyncData([])),
  searchCommentHitsProvider(null).overrideWithValue(const AsyncData([])),
  recentSearchesProvider.overrideWithBuild((ref, notifier) => const []),
];

List<Override> _notifSettings() => [
  ...notifOverrides(
    repo: FakeNotificationsRepository(
      prefs: const NotificationPrefs()
          .withKind(NotificationKind.comments, NotificationChannel.push, on: false)
          .withKind(NotificationKind.reminders, NotificationChannel.inapp, on: false)
          .withMuted('g-flat', muted: true),
    ),
  ),
  groupsListProvider.overrideWithValue(
    AsyncData([gf.sampleGroup(), gf.sampleGroup(id: 'g-flat', name: 'Flat 4B', type: 'home')]),
  ),
];

FakeSyncRepository _syncIssues() => FakeSyncRepository(
  status: SyncStatus(
    phase: SyncPhase.offline,
    waiting: 2,
    failed: 1,
    lastSync: _now.subtract(const Duration(minutes: 40)),
    lastError: 'offline',
  ),
  issues: [sampleIssue()],
  uploads: const [
    SyncUpload(id: 'u1', bucket: 'receipts', recordId: 'e1', attempts: 0),
    SyncUpload(id: 'u2', bucket: 'group-covers', recordId: 'g1', attempts: 3),
  ],
  unsynced: true,
);

/// Every main screen and sheet (R3-A task 1), in the order of the app.
List<R3Screen> r3Screens() => [
  _routed('welcome', Routes.welcome, data: () => const []),
  _routed(
    'sign_in',
    Routes.signIn,
    data: () => const [],
    extra: () => [googleConfiguredProvider.overrideWithValue(true)],
  ),
  _routed('sign_in_code', '${Routes.signInCode}?email=asha.rao.long.name%40splitify.test'),
  _routed(
    'home',
    Routes.groups,
    extra: () => [friendsProvider.overrideWithValue(AsyncData(_friends()))],
  ),
  _routed('group_expenses', Routes.group(gid)),
  _routed('group_balances', '${Routes.group(gid)}?tab=balances'),
  _routed(
    'group_totals',
    '${Routes.group(gid)}?tab=totals',
    extra: () => [groupTotalsProvider(gid).overrideWithValue(AsyncData(bf.sampleTotals()))],
  ),
  _home(
    'editor_new',
    () => const ExpenseEditorScreen(groupId: gid),
    () => _editor(_newDraft),
    targets: true,
  ),
  _home(
    'editor_edit',
    () => const ExpenseEditorScreen(expenseId: 'e1'),
    () => _editor(_editDraft),
    targets: true,
  ),
  _home(
    'split_sheet',
    () => _SheetHost(
      title: (l) => l.expPaidSplitTitle,
      child: PaidSplitPanel(
        draft: sampleDraft(
          expenseId: null,
          amount: '1200',
          split: SplitDraft.initial(
            ids,
            2,
          ).withValues(SplitKind.shares, {'m1': 2000, 'm2': 1000, 'm3': 1000, 'm4': 0}),
        ),
        onPayer: (_) {},
        onMultiple: () {},
        onPayerText: (_, _) {},
        onSplit: (_) {},
        onDone: () {},
      ),
    ),
    () => const [],
  ),
  _home(
    'items_sheet',
    () => _SheetHost(
      title: (l) => l.expPaidSplitTitle,
      child: PaidSplitPanel(
        draft: _itemsFull(),
        onPayer: (_) {},
        onMultiple: () {},
        onPayerText: (_, _) {},
        onSplit: (_) {},
        onUseTotal: (_) {},
        onDone: () {},
      ),
    ),
    () => const [],
  ),
  _home(
    'scan_review',
    () => _SheetHost(
      title: (l) => l.entryScanTitle,
      child: ScanReviewPanel(
        outcome: _found(),
        draft: sampleDraft(expenseId: null, amount: '500', description: ''),
        onDone: (_) {},
        onRetry: () {},
      ),
    ),
    () => const [],
  ),
  _home(
    'expense_detail',
    () => const ExpenseDetailScreen(expenseId: 'e1'),
    () => _detail(
      'e1',
      sampleView(
        sampleExpense(
          description: 'Dinner at Thalassa with the whole gang',
          // A lakh amount: Indian grouping (₹1,23,456.50) on the hero and in every row (S-448).
          total: 12345650,
          payers: const {'m1': 12345650},
          shares: const {'m1': 3086413, 'm2': 3086413, 'm3': 3086412, 'm4': 3086412},
          notes: 'Table by the window, paid by card.',
        ),
      ),
    ),
  ),
  _home(
    'settle_up',
    () => const SettleUpScreen(groupId: gid, from: 'm1', to: 'm2', currency: 'INR'),
    () => [
      settleProvider(_upiArgs).overrideWith(
        () => bf.FixedSettleController(
          _upiArgs,
          bf.sampleSettleDraft(to: 'm2', amountText: '12500', balances: _oweAsha()),
        ),
      ),
      upiIdProvider('u2').overrideWith((ref) => Stream.value('asha@okaxis')),
      upiIdProvider('u1').overrideWith((ref) => Stream.value(null)),
    ],
  ),
  _home(
    'loan',
    () => const LoanScreen(groupId: gid),
    () => [
      loanEditorProvider(newLoan).overrideWith(
        () => FixedLoanController(
          newLoan,
          sampleLoan(person: 'm2', amount: '25000', note: 'Cab money'),
        ),
      ),
    ],
  ),
  _routed(
    'friends',
    Routes.friends,
    extra: () => [friendsProvider.overrideWithValue(AsyncData(_friends()))],
  ),
  _home(
    'friend_page',
    () => const FriendPage(friendKey: 'u:u2'),
    () => friendOverrides(AsyncData(_ashaOwed())),
  ),
  _routed('activity', Routes.activity),
  _home('search', () => const SearchScreen(), _search),
  _home(
    'insights',
    () => const InsightsScreen(mode: InsightsMode.group, groupId: inf.goaId),
    () => inf.insightsOverrides(inf.allInsightLedgers()),
  ),
  _routed('account', Routes.account),
  _home(
    'account_settings',
    () => const _Page(child: AccountSettingsList()),
    accountSettingsOverrides,
  ),
  _home(
    'appearance_sheet',
    () => _SheetHost(title: (l) => l.appearance, child: const AppearancePicker()),
    () => const [],
  ),
  _home('notification_settings', () => const NotificationSettingsScreen(), _notifSettings),
  // The edit form: the new-group form autofocuses its name, and a blinking caret makes the picture flaky.
  _routed('group_form', Routes.editGroup(gid)),
  _routed('group_settings', Routes.groupSettings(gid)),
  _home(
    'invite_sheet',
    // Nested: the group data fixes the group's payments, which the harness also fixes.
    () => ProviderScope(
      overrides: fixedGroupData(
        groups: [gf.sampleGroup(id: gid, name: 'Goa trip')],
        members: {gid: bf.goaMembers()},
      ),
      child: _SheetHost(
        title: (l) => l.invitePeople,
        child: const InviteSheetBody(groupId: gid),
      ),
    ),
    () => const [],
  ),
  _routed('join', '${Routes.join}?code=ABCDEFGH'),
  _home(
    'notifications',
    () => const NotificationsScreen(),
    () => notifOverrides(repo: FakeNotificationsRepository(rows: sampleNotifRows())),
  ),
  _routed('sync_storage', Routes.syncStorage, sync: _syncIssues),
];
