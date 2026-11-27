// D-034 WP-D goldens: search with mixed results (expenses, payments, comments + type chips), search
// opened from a group with recent searches, Insights' trend cards, the Totals month view and the
// Your data sheet — light and dark at text 1.0 and 2.0, plus a small phone (320 × 568) at text 1.0;
// every state runs the tap-target / label checks (expectA11y in pumpFixedFrames).
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/account/presentation/your_data_sheet.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/balances/presentation/totals_tab.dart';
import 'package:splitify/features/export/application/backup_export.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/application/totals_months.dart';
import 'package:splitify/features/insights/presentation/trend_cards.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/search/application/search_controller.dart';
import 'package:splitify/features/search/application/search_everything.dart';
import 'package:splitify/features/search/presentation/search_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/balances/balance_fixtures.dart' show sampleTotals;
import '../features/expenses/expense_fixtures.dart';
import '../support/ledger_seed.dart';
import 'golden_support.dart';

const _phone = Size(goldenWidth, 915);
const _small = Size(320, 568);

class _FixedSearch extends ExpenseSearchController {
  _FixedSearch(super.group, this.fixed);

  final SearchState fixed;

  @override
  SearchState build() => fixed;
}

final _members = [
  seedMember('m1', groupId: gid, name: 'Mohit Bindal', userId: 'u1'),
  seedMember('m2', groupId: gid, name: 'Asha Rao', userId: 'u2', position: 1),
  seedMember('m3', groupId: gid, name: 'Rahul Mehta', position: 2),
];

PaymentView _payment(
  String id,
  String from,
  String to,
  int amount,
  String date, {
  bool pending = false,
}) => paymentViews(
  [
    seedPayment(
      id,
      groupId: gid,
      from: from,
      to: to,
      amount: amount,
      date: date,
      syncState: pending ? SyncState.pending : SyncState.synced,
    ),
  ],
  _members,
  'u1',
).first;

LocalComment _comment(String id, String body, String target, {String type = 'expense'}) =>
    LocalComment(
      id: id,
      groupId: gid,
      targetType: type,
      targetId: target,
      body: body,
      createdAt: '2026-11-20T15:30:00Z',
      createdBy: 'u1',
      seq: 1,
      syncState: SyncState.synced,
    );

List<Override> _search(
  SearchState s, {
  String? group,
  bool hits = true,
  List<String> recent = const [],
}) {
  final dinner = sampleExpense();
  return [
    searchControllerProvider(group).overrideWith(() => _FixedSearch(group, s)),
    searchGroupsProvider.overrideWith((ref) => Stream.value([sampleGroup()])),
    searchResultsProvider(group).overrideWithValue(
      AsyncData(hits ? [(view: sampleView(dinner), groupName: 'Goa trip')] : const []),
    ),
    searchPaymentHitsProvider(group).overrideWithValue(
      AsyncData(
        hits
            ? [
                (view: _payment('p1', 'm2', 'm1', 50000, '2026-11-18'), groupName: 'Goa trip'),
                (
                  view: _payment('p2', 'm1', 'm3', 125050, '2026-10-05', pending: true),
                  groupName: 'Goa trip',
                ),
              ]
            : const [],
      ),
    ),
    searchCommentHitsProvider(group).overrideWithValue(
      AsyncData(
        hits
            ? [
                (
                  comment: _comment('c1', 'Paid the tip in cash, 500 extra', dinner.id),
                  authorName: 'Mohit Bindal',
                  expense: dinner,
                  payment: null,
                  groupName: 'Goa trip',
                ),
              ]
            : const [],
      ),
    ),
    recentSearchesProvider.overrideWithBuild((ref, notifier) => recent),
  ];
}

/// Goa: three people taking turns to pay, over a few months.
GroupLedger _ledger() {
  final ids = ['m1', 'm2', 'm3'];
  LocalExpense e(String id, String cat, String date, int total, String payer) => seedExpense(
    id,
    groupId: gid,
    date: date,
    total: total,
    payers: {payer: total},
    shares: {for (final m in ids) m: total ~/ 3}..[ids.first] = total - 2 * (total ~/ 3),
  ).copyWith(category: cat);
  return GroupLedger(
    group: seedGroup(id: gid),
    members: _members,
    expenses: [
      e('e1', 'travel.hotel', '2026-10-03', 900000, 'm1'),
      e('e2', 'food.dining_out', '2026-11-18', 300000, 'm2'),
      e('e3', 'food.snacks', '2026-10-21', 60000, 'm3'),
      e('e4', 'travel.cab_auto', '2026-09-12', 180000, 'm2'),
      e('e5', 'food.takeaway', '2026-08-02', 90000, 'm1'),
      e('e6', 'shopping.gifts', '2026-07-14', 150000, 'm3'),
    ],
    payments: const [],
  );
}

/// Both trend cards on their own (the rest of Insights has its own goldens).
class _Trends extends StatefulWidget {
  const _Trends();

  @override
  State<_Trends> createState() => _TrendsState();
}

class _TrendsState extends State<_Trends> {
  final _view = insightsViewOf(
    [_ledger()],
    (mode: InsightsMode.group, groupId: gid),
    userId: 'u1',
    defaultCurrency: 'INR',
    today: DateTime(2026, 11, 22),
  );
  String _month = '2026-10';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          CategoryTrendCard(
            view: _view,
            category: 'food',
            month: _month,
            onCategory: (_) {},
            onMonth: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: AppSpacing.s5),
          WhoPaidCard(
            view: _view,
            memberId: 'm2',
            month: _month,
            onMember: (_) {},
            onMonth: (m) => setState(() => _month = m),
          ),
        ],
      ),
    ),
  );
}

class _TotalsHost extends StatelessWidget {
  const _TotalsHost();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: TotalsTab(groupId: gid),
      ),
    ),
  );
}

TotalsMonths _months() {
  TotalsExpense e(String date, int total, String payer) => TotalsExpense(
    currency: 'INR',
    total: total,
    date: date,
    paid: {payer: total},
    shares: {'m1': total ~/ 4, 'm2': total ~/ 4, 'm3': total ~/ 4, 'm4': total - 3 * (total ~/ 4)},
  );
  return TotalsMonths([
    e('2026-11-20', 90000, 'm1'),
    e('2026-10-02', 240000, 'm2'),
    e('2026-10-28', 64000, 'm1'),
    e('2026-08-15', 30000, 'm3'),
  ]);
}

/// [AppSheet] at the bottom of a dimmed screen, like the real modal sheet.
class _SheetHost extends StatelessWidget {
  const _SheetHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        child: AppSheet(
          title: AppLocalizations.of(context).backupTitle,
          child: const YourDataPanel(),
        ),
      ),
    ),
  );
}

/// Lets a tap's press-in and spring-back finish (frame by frame), so the goldens show buttons at rest.
Future<void> _rest(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

typedef _Shot = ({
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  Future<void> Function(WidgetTester t)? act,
});

final _shots = <_Shot>[
  (
    name: 'search_mixed',
    screen: () => const SearchScreen(),
    overrides: () => _search(const SearchState(text: 'Goa 500')),
    act: null,
  ),
  (
    name: 'search_payments_only',
    screen: () => const SearchScreen(),
    overrides: () => _search(const SearchState(text: 'Goa 500', kind: SearchKind.payments)),
    act: null,
  ),
  (
    name: 'search_group_recent',
    screen: () => const SearchScreen(groupId: gid),
    overrides: () => _search(
      const SearchState(groupId: gid),
      group: gid,
      recent: const ['dinner', 'Asha 500', 'cab to airport'],
    ),
    act: (t) async => FocusManager.instance.primaryFocus?.unfocus(),
  ),
  (
    name: 'search_group_empty',
    screen: () => const SearchScreen(groupId: gid),
    overrides: () => _search(const SearchState(groupId: gid), group: gid, hits: false),
    act: (t) async => FocusManager.instance.primaryFocus?.unfocus(),
  ),
  (name: 'insights_trends', screen: () => const _Trends(), overrides: () => const [], act: null),
  (
    name: 'totals_month',
    screen: () => const _TotalsHost(),
    overrides: () => [
      groupTotalsProvider(gid).overrideWithValue(AsyncData(sampleTotals())),
      totalsMonthsProvider(gid).overrideWithValue(AsyncData(_months())),
    ],
    act: (t) async {
      await t.tap(find.text('Month'));
      await _rest(t);
      await t.tap(find.byKey(const Key('totals-prev')));
      await _rest(t);
    },
  ),
  (
    name: 'totals_month_empty',
    screen: () => const _TotalsHost(),
    overrides: () => [
      groupTotalsProvider(gid).overrideWithValue(AsyncData(sampleTotals())),
      totalsMonthsProvider(gid).overrideWithValue(AsyncData(_months())),
    ],
    act: (t) async {
      await t.tap(find.text('Month'));
      await _rest(t);
      for (var i = 0; i < 2; i++) {
        await t.tap(find.byKey(const Key('totals-prev')));
        await _rest(t);
      }
    },
  ),
  (
    name: 'your_data',
    screen: () => const _SheetHost(),
    overrides: () => [
      backupCountsProvider.overrideWith(
        (ref) => Stream.value((groups: 4, expenses: 128, payments: 17, pending: 3)),
      ),
    ],
    act: null,
  ),
];

void main() {
  Future<void> Function(WidgetTester) pump(_Shot shot) => (t) async {
    await pumpFixedFrames(t);
    final act = shot.act;
    if (act != null) {
      await act(t);
      await pumpFixedFrames(t);
    }
  };

  for (final shot in _shots) {
    Widget app(Size size, ThemeMode mode, double scale) => expenseApp(
      shot.screen(),
      overrides: shot.overrides(),
      mode: mode,
      scale: scale,
      size: size,
    );
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'D-034 WP-D ${shot.name} ${mode.name} $suffix',
          fileName: 'd034_d_${shot.name}_${mode.name}_$suffix',
          pumpBeforeTest: pump(shot),
          builder: () =>
              app(scale > 1 ? Size(goldenWidth, _phone.height * 1.8) : _phone, mode, scale),
        );
      }
      goldenTest(
        'D-034 WP-D ${shot.name} ${mode.name} small phone',
        fileName: 'd034_d_${shot.name}_${mode.name}_small',
        pumpBeforeTest: pump(shot),
        builder: () => app(_small, mode, 1),
      );
    }
  }
}
