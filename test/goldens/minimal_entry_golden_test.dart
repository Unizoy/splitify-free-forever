// D-033 minimal pass (home, shell, account): the hero screens scrolled so the status-bar band shows (Groups
// home, group page, Activity), the settings list on Account, Notification settings, Security and the
// Appearance sheet — light and dark at text 1.0 and 2.0, plus a small phone (360 × 640). Every state runs
// the a11y guidelines (48 dp targets, labels, tap actions).
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart' show clockProvider, syncRepositoryProvider;
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/features/account/presentation/appearance_screen.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../data/sync/sync_fakes.dart' show FakeClock;
import '../features/expenses/expense_fixtures.dart' show sampleViews;
import '../support/fakes.dart' hide FakeClock;
import '../support/group_fakes.dart';
import '../support/group_harness.dart' show fixedGroupData;
import 'golden_support.dart';

const _delegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The whole app at [location] in a phone frame with a 24 dp status bar, signed in, fixed data.
class _PhoneApp extends StatelessWidget {
  const _PhoneApp({
    required this.location,
    required this.mode,
    required this.scale,
    required this.size,
    required this.prefs,
    required this.data,
    this.sheet = false,
  });

  final String location;
  final ThemeMode mode;
  final double scale;
  final Size size;
  final SharedPreferences prefs;
  final List<Override> data;

  /// Shows the Appearance sheet over a scrim instead of a routed screen.
  final bool sheet;

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
        groupsRemoteProvider.overrideWithValue(FakeGroupsRemote()),
        syncNowProvider.overrideWithValue(() async {}),
        syncRepositoryProvider.overrideWithValue(FakeSyncRepository()),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 10))),
        ...data,
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          textScaler: TextScaler.linear(scale),
        ),
        child: sheet
            ? MaterialApp(
                home: Builder(
                  builder: (context) => Scaffold(
                    backgroundColor: context.colors.scrim,
                    body: Align(
                      alignment: Alignment.bottomCenter,
                      child: AppSheet(
                        title: AppLocalizations.of(context).appearance,
                        child: const AppearancePicker(),
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
              )
            : MaterialApp.router(
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
  );
}

final _goa = sampleGroup(id: 'g-goa', name: 'Goa trip');

List<Override> _homeData() => fixedGroupData(
  groups: [
    _goa,
    sampleGroup(id: 'g-flat', name: 'Flat 4B', type: 'home'),
    sampleGroup(id: 'g-us', name: 'Us two', type: 'couple'),
    sampleGroup(id: 'g-office', name: 'Office lunches', type: 'other'),
  ],
);

List<Override> _groupData() => fixedGroupData(
  groups: [_goa],
  members: {
    'g-goa': [
      sampleMember(id: 'm-asha', userId: 'u1', name: 'Asha Rao', role: 'owner'),
      sampleMember(id: 'm-ravi', name: 'Ravi Menon', position: 1, tint: 1),
    ],
  },
  expenses: {'g-goa': sampleViews()},
);

List<Override> _activityData() => fixedGroupData(
  groups: [_goa],
  activity: [
    for (var i = 0; i < 14; i++)
      ActivityItem(
        id: 'a$i',
        type: i.isEven ? 'expense_added' : 'payment_added',
        groupId: 'g-goa',
        groupName: 'Goa trip',
        at: DateTime(2026, 11, 22, 9).subtract(Duration(hours: i * 7)),
        actor: (name: i.isEven ? 'Ravi Menon' : 'Asha Rao', seed: 'm$i', isMe: false),
        from: (name: 'Ravi Menon', seed: 'm-ravi', isMe: false),
        to: (name: 'Asha Rao', seed: 'm-asha', isMe: true),
        description: ['Dinner at Thalassa', 'Cab to airport', 'Groceries'][i % 3],
        amount: 120000 + i * 1550,
        currency: 'INR',
        targetType: 'expense',
        targetId: 'e$i',
      ),
  ],
);

/// Scrolls the page's vertical scroll view to [offset] (what a drag does), then the usual checks.
Future<void> Function(WidgetTester) _scrolledTo(double offset) => (t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 1500));
  if (offset > 0) {
    final page = t
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.position.axis == Axis.vertical);
    page.position.jumpTo(offset.clamp(0, page.position.maxScrollExtent));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }
  await expectA11y(t);
};

typedef _Shot = ({String name, String route, List<Override> Function() data, double scroll});

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final shots = <_Shot>[
    (name: 'home_scrolled', route: Routes.groups, data: _homeData, scroll: 140),
    (name: 'group_scrolled', route: '/groups/g-goa', data: _groupData, scroll: 300),
    (name: 'activity', route: Routes.activity, data: _activityData, scroll: 0),
    (name: 'activity_scrolled', route: Routes.activity, data: _activityData, scroll: 420),
    (name: 'account_settings', route: Routes.account, data: _homeData, scroll: 640),
    (name: 'notification_settings', route: '/account/notifications', data: _homeData, scroll: 0),
    (name: 'security', route: '/account/security', data: _homeData, scroll: 0),
    (name: 'appearance_sheet', route: Routes.account, data: _homeData, scroll: 0),
  ];

  for (final s in shots) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'D-033 ${s.name} ${mode.name} $suffix',
          fileName: 'minimal_entry_${s.name}_${mode.name}_$suffix',
          pumpBeforeTest: _scrolledTo(s.scroll),
          builder: () => _PhoneApp(
            location: s.route,
            mode: mode,
            scale: scale,
            size: const Size(goldenWidth, 915),
            prefs: prefs,
            data: s.data(),
            sheet: s.name == 'appearance_sheet',
          ),
        );
      }
    }
    goldenTest(
      'D-033 ${s.name} small phone',
      fileName: 'minimal_entry_${s.name}_small_light_text100',
      pumpBeforeTest: _scrolledTo(s.scroll * 0.8),
      builder: () => _PhoneApp(
        location: s.route,
        mode: ThemeMode.light,
        scale: 1,
        size: const Size(360, 640),
        prefs: prefs,
        data: s.data(),
        sheet: s.name == 'appearance_sheet',
      ),
    );
  }
}
