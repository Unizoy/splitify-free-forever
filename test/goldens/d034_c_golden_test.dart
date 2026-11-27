// D-034 WP-C goldens: the group page with who owes whom (3 lines + "+1 more", trip dates and notes chips),
// a settled group with its history folded, the Groups filter sheet and the filtered list, the group form's
// trip dates and settle-up reminders, and the group notes — light and dark at text 1.0 and 2.0, plus a small
// phone (320 × 568) at text 1.0. Routed screens run in the real router; every state runs expectA11y
// (pumpFixedFrames).
import 'package:alchemist/alchemist.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider, syncRepositoryProvider;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/groups/application/group_extras_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';
import 'package:splitify/features/groups/presentation/group_filter_pill.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../data/sync/sync_fakes.dart' show FakeClock;
import '../support/fakes.dart' hide FakeClock;
import '../support/group_fakes.dart';
import '../support/group_harness.dart' show fixedGroupData;
import '../support/ledger_seed.dart';
import 'golden_support.dart';

const _phone = Size(goldenWidth, 915);
const _small = Size(320, 568);

const _goaId = 'g-goa';
const _flatId = 'g-flat';

final _goa = sampleGroup(id: _goaId, name: 'Goa trip').copyWith(
  tripStartsOn: const Value('2026-12-12'),
  tripEndsOn: const Value('2026-12-18'),
  settleReminder: const Value('weekly'),
  whiteboard: const Value(
    'Villa Sol, 12 Beach Road, Candolim\n'
    'Wi-Fi: VillaSol-5G · goa2026!\n'
    'Caretaker Joseph: 98200 12345\n'
    'Check-out 11 am on the 18th',
  ),
);
final _flat = sampleGroup(id: _flatId, name: 'Flat 4B', type: 'home');

List<LocalMember> _people(String g) => [
  sampleMember(id: '$g-m1', groupId: g, userId: 'u1', name: 'Mohit Bindal', role: 'owner', tint: 0),
  sampleMember(id: '$g-m2', groupId: g, userId: 'u2', name: 'Asha Rao', position: 1, tint: 1),
  sampleMember(id: '$g-m3', groupId: g, name: 'Rahul Mehta', position: 2, tint: 2),
  sampleMember(id: '$g-m4', groupId: g, name: 'Neha', position: 3, tint: 3),
  sampleMember(id: '$g-m5', groupId: g, name: 'Kiran', position: 4, tint: 4),
];

ExpenseFlow _flow(String currency, String payer, Map<String, int> shares) => ExpenseFlow(
  currency: currency,
  paid: {payer: shares.values.fold(0, (a, b) => a + b)},
  shares: shares,
);

/// Goa: Asha owes me ₹1,200, Rahul ₹450, I owe Neha ₹300, Kiran owes me $25 (behind "+1 more").
GroupBalances _goaBalances() {
  final m = _people(_goaId);
  final ids = [for (final x in m) x.id];
  return GroupBalances(
    groupId: _goaId,
    groupName: 'Goa trip',
    mainCurrency: 'INR',
    members: m,
    byCurrency: balancesByCurrency(ids, [
      _flow('INR', ids[0], {ids[1]: 120000, ids[2]: 45000}),
      _flow('INR', ids[3], {ids[0]: 30000}),
      _flow('USD', ids[0], {ids[4]: 2500}),
    ], const []),
    meId: ids[0],
    hasRecords: true,
  );
}

LocalExpense _exp(String id, String desc, String date, String payer, Map<String, int> shares) {
  final total = shares.values.fold(0, (a, b) => a + b);
  return seedExpense(
    id,
    groupId: _flatId,
    description: desc,
    date: date,
    total: total,
    payers: {payer: total},
    shares: shares,
  );
}

/// Flat: rent and groceries cancelled out (settled), then my own snacks (moves nothing, stays visible).
List<ExpenseView> _flatViews() {
  final m = _people(_flatId);
  return expenseViews(
    [
      _exp('f3', 'Snacks for me', '2026-11-20', m[0].id, {m[0].id: 25000}),
      _exp('f2', 'Groceries', '2026-11-12', m[1].id, {m[0].id: 120000}),
      _exp('f1', 'Electricity', '2026-11-03', m[0].id, {m[1].id: 120000}),
    ],
    m,
    'u1',
  );
}

List<Override> _data() => [
  ...fixedGroupData(
    groups: [_goa, _flat],
    members: {_goaId: _people(_goaId), _flatId: _people(_flatId)},
    balances: {
      _goaId: _goaBalances(),
      _flatId: GroupBalances(
        groupId: _flatId,
        groupName: 'Flat 4B',
        mainCurrency: 'INR',
        members: _people(_flatId),
        byCurrency: const {},
        meId: '$_flatId-m1',
        hasRecords: true,
      ),
    },
    expenses: {_flatId: _flatViews()},
    my: const MyBalances(
      totals: {'INR': 135000, 'USD': 2500},
      byGroup: {
        _goaId: {'INR': 135000, 'USD': 2500},
      },
      people: [],
    ),
  ),
  groupNotesEditProvider.overrideWith(
    (ref, id) => Stream.value((
      memberId: '$_goaId-m2',
      userId: 'u2',
      at: DateTime(2026, 11, 21, 18),
      pending: false,
    )),
  ),
];

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// A phone-sized app signed in as `u1`: the routed screen at [location], or [sheet] over a scrim.
class _App extends StatelessWidget {
  const _App({
    required this.size,
    required this.mode,
    required this.scale,
    required this.prefs,
    this.location,
    this.sheet,
  });

  final Size size;
  final ThemeMode mode;
  final double scale;
  final SharedPreferences prefs;
  final String? location;
  final (String Function(AppLocalizations l), Widget)? sheet;

  @override
  Widget build(BuildContext context) {
    final sheet = this.sheet;
    return SizedBox.fromSize(
      size: size,
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: const AuthUser(id: 'u1')),
          ),
          profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
          groupsRemoteProvider.overrideWithValue(FakeGroupsRemote()),
          syncNowProvider.overrideWithValue(() async {}),
          syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 10))),
          ..._data(),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            textScaler: TextScaler.linear(scale),
          ),
          child: sheet == null
              ? MaterialApp.router(
                  routerConfig: buildRouter(initialLocation: location!),
                  localizationsDelegates: _delegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: mode,
                  debugShowCheckedModeBanner: false,
                )
              : MaterialApp(
                  home: Builder(
                    builder: (context) => Scaffold(
                      backgroundColor: context.colors.scrim,
                      body: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: size.height - 24),
                          child: AppSheet(
                            title: sheet.$1(AppLocalizations.of(context)),
                            child: sheet.$2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  localizationsDelegates: _delegates,
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
}

typedef _Shot = ({
  String name,
  String? route,
  (String Function(AppLocalizations l), Widget)? sheet,
  Future<void> Function(WidgetTester t)? act,
});

_Shot _route(String name, String route, {Future<void> Function(WidgetTester t)? act}) =>
    (name: name, route: route, sheet: null, act: act);

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    // The Groups list opens filtered to groups with a balance (kept on the phone, C3).
    SharedPreferences.setMockInitialValues({GroupFilterController.storageKey: 'outstanding'});
    prefs = await SharedPreferences.getInstance();
  });

  final shots = <_Shot>[
    // C1 + C4 + C5 + C6 on the group page.
    _route('group_lines', '/groups/$_goaId'),
    // C2: a settled group, its history folded into one row.
    _route('group_settled', '/groups/$_flatId'),
    // C3: the filter sheet and the filtered list.
    (
      name: 'filter_sheet',
      route: null,
      sheet: (
        (l) => l.groupFilterLabel,
        GroupFilterOptions(value: GroupFilter.outstanding, onPicked: (_) {}),
      ),
      act: null,
    ),
    _route('groups_filtered', '/groups'),
    // C4: the end of the form, trip dates and reminders.
    _route(
      'form_trip',
      '/groups/$_goaId/edit',
      act: (t) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await t.scrollUntilVisible(
          find.byKey(const Key('group-reminder-next')),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await t.pump(const Duration(milliseconds: 100));
      },
    ),
    // C5: the group notes.
    _route(
      'notes',
      '/groups/$_goaId/notes',
      act: (t) async => FocusManager.instance.primaryFocus?.unfocus(),
    ),
  ];

  Future<void> Function(WidgetTester) pump(_Shot shot) => (t) async {
    await pumpFixedFrames(t);
    final act = shot.act;
    if (act != null) {
      await act(t);
      await pumpFixedFrames(t);
    }
  };

  for (final shot in shots) {
    Widget app(Size size, ThemeMode mode, double scale) => _App(
      size: size,
      mode: mode,
      scale: scale,
      prefs: prefs,
      location: shot.route,
      sheet: shot.sheet,
    );
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'D-034 C ${shot.name} ${mode.name} $suffix',
          fileName: 'd034c_${shot.name}_${mode.name}_$suffix',
          pumpBeforeTest: pump(shot),
          builder: () => app(_phone, mode, scale),
        );
      }
      // The tab shell's capsule nav bar (lib/ui, frozen for D-034) overflows at 320 dp: the Groups list has
      // no small-phone shot here (reported for wave 2).
      if (shot.name == 'groups_filtered') continue;
      goldenTest(
        'D-034 C ${shot.name} ${mode.name} small phone',
        fileName: 'd034c_${shot.name}_${mode.name}_small',
        pumpBeforeTest: pump(shot),
        builder: () => app(_small, mode, 1),
      );
    }
  }
}
