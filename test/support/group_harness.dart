import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../data/sync/sync_fakes.dart';
import 'fakes.dart' hide FakeClock;
import 'group_fakes.dart';

/// What a groups widget test gets back from [pumpGroups].
class GroupHarness {
  GroupHarness({
    required WidgetTester tester,
    required this.router,
    required this.remote,
    required this.syncs,
    required this.shared,
    this.db,
  }) : _tester = tester;

  final WidgetTester _tester;
  final GoRouter router;
  final FakeGroupsRemote remote;
  final AppDatabase? db;

  /// Number of times the app asked for a sync.
  final List<int> syncs;

  /// Texts handed to the share sheet.
  final List<String> shared;

  /// Pushes [path] on top of the current screen.
  void open(String path) => unawaited(router.push<Object?>(path));

  /// Path of the screen on top.
  String get location =>
      GoRouterState.of(_tester.element(find.byType(Scaffold).last)).uri.toString();
}

/// Pumps the whole app at [location], signed in as [userId] (null = signed out).
///
/// With [db] the real repositories run on that memory database (writes land in the tables and the outbox; the
/// engine never runs). Without it the caller must override the data providers through [overrides].
Future<GroupHarness> pumpGroups(
  WidgetTester tester,
  String location, {
  AppDatabase? db,
  FakeGroupsRemote? remote,
  String? userId = 'u1',
  List<Override> overrides = const [],
  DateTime? now,
  double textScale = 1.0,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fake = remote ?? FakeGroupsRemote();
  final syncs = <int>[];
  final shared = <String>[];
  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  final clock = FakeClock(now ?? DateTime.utc(2026, 11, 22, 10));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: userId == null ? null : AuthUser(id: userId)),
        ),
        profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
        groupsRemoteProvider.overrideWithValue(fake),
        textSharerProvider.overrideWithValue((t) async => shared.add(t)),
        syncNowProvider.overrideWithValue(() async => syncs.add(syncs.length)),
        clockProvider.overrideWithValue(clock),
        if (db != null) ...[
          appDatabaseProvider.overrideWithValue(db),
          remoteApiProvider.overrideWithValue(FakeRemoteApi()),
          localWriterProvider.overrideWith(
            (ref) => LocalWriter(db, clock, ref.watch(syncEngineProvider).serverClock),
          ),
          syncOfflineProvider.overrideWith((ref) => Stream.value(false)),
        ],
        ...overrides,
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(412, 915),
          devicePixelRatio: 3,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
        ),
      ),
    ),
  );
  await settle(tester, db: db != null);
  return GroupHarness(
    tester: tester,
    router: router,
    remote: fake,
    db: db,
    syncs: syncs,
    shared: shared,
  );
}

/// A few frames (the app has endless animations, so never `pumpAndSettle`). With [db] it also lets the real
/// sqlite futures finish first.
Future<void> settle(WidgetTester tester, {bool db = false, int? frames}) async {
  for (var i = 0; i < (frames ?? (db ? 30 : 6)); i++) {
    if (db) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Runs [body] on the real event loop (database reads).
Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
    (await tester.runAsync(() => body().timeout(const Duration(seconds: 5)))) as T;

/// Memory database, closed after the test (the widget tree goes first so its streams cancel).
AppDatabase openTestDb(WidgetTester tester) {
  final db = memoryDb();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    // Closing waits on stream clean-up timers that only fire when time moves.
    var closed = false;
    final closing = db.close().then((_) => closed = true);
    for (var i = 0; i < 40 && !closed; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await closing;
  });
  return db;
}

/// Fixed provider data (no database): used by screens that only read, and by the goldens.
List<Override> fixedGroupData({
  List<LocalGroup> groups = const [],
  Map<String, List<LocalMember>> members = const {},
  List<LocalGroup> deleted = const [],
  Set<String> unsynced = const {},
  bool offline = false,
  bool loading = false,
  Map<String, List<ExpenseView>> expenses = const {},
  Map<String, GroupBalances> balances = const {},
  MyBalances my = noBalances,
}) => [
  // Phase 09 reads: fixed balances per group (none = no records), no payments, totals or activity.
  for (final g in groups) ...[
    groupPaymentViewsProvider(g.id).overrideWithValue(const AsyncData([])),
    groupBalancesProvider(g.id).overrideWithValue(
      AsyncData(
        balances[g.id] ??
            GroupBalances(
              groupId: g.id,
              groupName: g.name,
              mainCurrency: g.mainCurrency,
              members: members[g.id] ?? const [],
              byCurrency: const {},
            ),
      ),
    ),
    groupTotalsProvider(g.id).overrideWithValue(
      AsyncData(
        GroupTotalsView(
          mainCurrency: g.mainCurrency,
          members: members[g.id] ?? const [],
          month: const {},
          allTime: const {},
        ),
      ),
    ),
    activityItemsProvider(g.id).overrideWithValue(const AsyncData([])),
  ],
  ...emptyBalanceOverrides(my: my),
  // Phase 08 Expenses tab: fixed rows per group (empty unless given).
  for (final g in groups)
    groupExpenseViewsProvider(g.id).overrideWithValue(AsyncData(expenses[g.id] ?? const [])),
  groupsListProvider.overrideWith(
    (ref) => loading ? StreamController<List<LocalGroup>>().stream : Stream.value(groups),
  ),
  groupProvider.overrideWith((ref, id) {
    final found = groups.where((g) => g.id == id);
    return Stream.value(found.isEmpty ? null : found.first);
  }),
  groupMembersProvider.overrideWith((ref, id) => Stream.value(members[id] ?? const [])),
  groupUnsyncedProvider.overrideWith((ref, id) => Stream.value(unsynced.contains(id))),
  deletedGroupsProvider.overrideWith((ref) => Stream.value(deleted)),
  syncOfflineProvider.overrideWith((ref) => Stream.value(offline)),
];
