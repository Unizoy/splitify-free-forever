// Shared harness for the phase 14 widget tests: a real in-memory database, a fake exchange-rate server,
// a themed app with a button that opens whatever the test wants.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/fx_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/features/balances/application/balances_providers.dart'
    show lastSyncProvider;
import 'package:splitify/features/expenses/application/expense_editor_controller.dart' as editor;
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../support/fakes.dart';
import '../../support/ledger_seed.dart';
import '../expenses/presentation/presentation_harness.dart';

/// Exchange-rate server: [rows] are what `between` returns; [error] makes it behave offline.
class FakeFxRemote implements FxRatesRemote {
  FakeFxRemote({this.rows = const [], this.error});

  List<RemoteFxRate> rows;
  Exception? error;
  final betweenCalls = <(Set<String>, String, String)>[];

  /// When set, `between` waits for it (a slow server).
  Completer<void>? gate;
  int changedSinceCalls = 0;

  @override
  Future<List<RemoteFxRate>> changedSince({
    required String? since,
    required String fromDate,
    int offset = 0,
    int limit = 1000,
  }) async {
    changedSinceCalls++;
    if (error != null) throw error!;
    return const [];
  }

  @override
  Future<List<RemoteFxRate>> between(Set<String> currencies, String from, String to) async {
    betweenCalls.add((currencies, from, to));
    await gate?.future;
    if (error != null) throw error!;
    return rows;
  }
}

/// A server that is not reachable.
FakeFxRemote offlineRemote() => FakeFxRemote(error: const NetworkException());

/// Real in-memory database with group g1 (INR): Mohit (me, u1), Asha, Ravi.
Future<AppDatabase> seededDb() async {
  final db = testDb();
  await db.seed(
    groups: [seedGroup()],
    members: [
      seedMember('m1', name: 'Mohit', userId: 'u1'),
      seedMember('m2', name: 'Asha', position: 1),
      seedMember('m3', name: 'Ravi', position: 2),
    ],
  );
  return db;
}

/// EUR-based cache: on 20 Nov 1 EUR = 90 INR = 1.2 USD (USD to INR 75.0000000000); on 17 Nov
/// 1 EUR = 90 INR = 1.25 USD (72.0000000000).
Future<void> cacheRates(AppDatabase db, {bool only20 = false, bool only17 = false}) async {
  for (final r in [
    if (!only17) ('2026-11-20', 'INR', '90'),
    if (!only17) ('2026-11-20', 'USD', '1.2'),
    if (!only20) ('2026-11-17', 'INR', '90'),
    if (!only20) ('2026-11-17', 'USD', '1.25'),
  ]) {
    await db.into(db.fxRates).insert(LocalFxRate(date: r.$1, currency: r.$2, rate: r.$3));
  }
}

/// Overrides for a real database (both `currentUserIdProvider`s, see LEARNINGS).
List<Override> dbOverrides(
  AppDatabase db,
  FakeFxRemote remote, {
  String? user = 'u1',
  bool lastSync = true,
}) => [
  appDatabaseProvider.overrideWithValue(db),
  clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 22, 12))),
  fxRatesRemoteProvider.overrideWithValue(remote),
  if (lastSync) lastSyncProvider.overrideWithValue(null),
  groups.currentUserIdProvider.overrideWithValue(user),
  editor.currentUserIdProvider.overrideWithValue(user),
];

/// Pumps a themed app on a phone screen showing [home]; the [overrides] sit on the root scope (app
/// sheets use the root navigator). Closes [db] at the end.
Future<void> pumpApp(
  WidgetTester t, {
  required List<Override> overrides,
  required Widget home,
  AppDatabase? db,
  double scale = 1,
  ThemeMode mode = ThemeMode.light,
}) async {
  usePhone(t);
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  if (db != null) {
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 50));
      // a real wait: closing a Drift database never finishes under the fake clock with writes in flight
      await t.runAsync(() => db.close().timeout(const Duration(seconds: 3), onTimeout: () {}));
    });
  }
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
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
        home: home,
      ),
    ),
  );
}

/// [pumpApp] with a home button `open` that runs [onOpen].
Future<void> pumpOpener(
  WidgetTester t, {
  required List<Override> overrides,
  required void Function(BuildContext context, WidgetRef ref) onOpen,
  AppDatabase? db,
  double scale = 1,
  ThemeMode mode = ThemeMode.light,
}) async {
  await pumpApp(
    t,
    overrides: overrides,
    db: db,
    scale: scale,
    mode: mode,
    home: Scaffold(
      body: Center(
        child: Consumer(
          builder: (context, ref, _) => ElevatedButton(
            key: const Key('open'),
            onPressed: () => onOpen(context, ref),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await settle(t, 2);
}

/// Taps `open` and lets the sheet and its streams settle.
Future<void> openSheet(WidgetTester t, [int frames = 12]) async {
  await t.tap(find.byKey(const Key('open')));
  await settle(t, frames);
}

/// Builds an async provider in real time and keeps it alive until the test ends. Drift `.first` reads
/// inside a controller's `build` never complete under the widget tester's fake clock, so the widget
/// finds the controller already loaded. A build that throws is kept as its error state.
Future<void> warm<T>(
  WidgetTester t,
  ProviderListenable<AsyncValue<T>> provider,
  Future<T> Function(ProviderContainer c) load,
) async {
  final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  // listen inside runAsync: the build starts with the first listener
  final sub = await t.runAsync(() async {
    final sub = c.listen(provider, (_, _) {});
    try {
      await load(c);
    } on Object {
      // the error state is what the screen shows
    }
    // late work started by the build (server fetch) lands too
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return sub;
  });
  addTearDown(sub!.close);
}

/// Lets work that needs the real clock finish (Drift transactions and stream cancels do not complete under
/// the widget tester's fake clock), then pumps the result onto the screen.
Future<void> settleReal(WidgetTester t, [int rounds = 2]) async {
  for (var i = 0; i < rounds; i++) {
    await settle(t, 2);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await settle(t);
}
