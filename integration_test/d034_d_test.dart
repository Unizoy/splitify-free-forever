// D-034 WP-D device e2e (TC-D34D-05) on emulator-5554 against the DEV project as e2e-a: a test group with
// expenses, a payment and a comment is synced, then with REAL airplane mode on
//   - search finds the payment by amount and by person and the comment by text, offline;
//   - search opened from the group says "Search in <group>";
//   - Account → Your data: "Share instead" hands a .zip to the (stubbed) share sheet; the file exists on the
//     phone, unzips, and its JSON gives the ledger's nets; "Download my data" goes to the (stubbed) save
//     dialog and says "Saved …";
//   - the Totals tab walks back a month; Insights shows Category over time and Who paid.
// Run under the emulator lock with the host script, which switches airplane mode on `E2E-NET off|on` and takes
// light + dark screenshots on `UI-CAPTURE <name>`:
//   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_d.ps1"
// Built side by side as com.unizoy.splitify.qa with --no-uninstall (S-310, S-329). The group is deleted at the end.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/repositories/history_repository.dart' show CommentWrites;
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/export/application/backup_export.dart';
import 'package:splitify/features/insights/presentation/insights_routes.dart';
import 'package:splitify/features/search/presentation/search_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/features/export/zip_reader.dart';
import 'support/harness.dart';

/// Seconds each state stays up for the host's light + dark captures (`UI_HOLD`, 0 = none).
const _hold = int.fromEnvironment('UI_HOLD');

final _network = ConnectivityNetworkStatus();

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 1200));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  await _pumpFor(t, const Duration(seconds: _hold));
}

/// Asks the host to switch airplane mode and waits until the phone sees it.
Future<void> _net(WidgetTester t, {required bool on}) async {
  debugPrint('E2E-NET ${on ? 'on' : 'off'}');
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    final now = (await t.runAsync(_network.isOnline))!;
    if (now == on) {
      debugPrint('network is ${on ? 'on' : 'off'}');
      return;
    }
    await _pumpFor(t, const Duration(milliseconds: 500));
  }
  fail('network did not turn ${on ? 'on' : 'off'}');
}

Future<void> _until(WidgetTester t, bool Function() ok, String reason) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('Timed out: $reason');
    await _pumpFor(t, const Duration(milliseconds: 200));
  }
}

Future<void> _search(WidgetTester t, String text) async {
  await t.enterText(find.byKey(const Key('search-field')), text);
  await _pumpFor(t, const Duration(milliseconds: 1500));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-034 WP-D offline search, Download my data, totals by month, trends', (t) async {
    final env = devEnv();
    final services = await initRemote(env);
    await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final uid = services.auth.currentUser!.id;
    final client = Supabase.instance.client;
    final db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final shared = <File>[];
    final saved = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(SupabaseRemoteApi.client(client)),
        balancesRemoteProvider.overrideWithValue(SupabaseBalancesRemote.fromClient(client)),
        groupsRemoteProvider.overrideWithValue(services.groups),
        authRepositoryProvider.overrideWithValue(services.auth),
        profileRemoteProvider.overrideWithValue(services.profiles),
        // The share sheet and the save dialog are system screens: stubbed, the file goes to the app's temp
        // folder instead (the plan's "stub the share intent, check the file exists and parses").
        backupSharerProvider.overrideWithValue((bytes, name, subject) async {
          final f = File('${Directory.systemTemp.path}/$name');
          await f.writeAsBytes(bytes, flush: true);
          shared.add(f);
        }),
        backupSaverProvider.overrideWithValue((bytes, name, title) async {
          saved.add(name);
          return name;
        }),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);
    Future<void> sync() => t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });

    // The test group: me, Asha, Rahul; dinner (me) this month, cab (Asha) last month, Asha paid me ₹500,
    // and a comment on the dinner.
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final name = 'Goa trip (E2E D034 $stamp)';
    final gid = await groups.create(name: name, ownerName: 'Mohit', ownerUserId: uid, type: 'trip');
    final asha = await members.addNameOnly(gid, 'Asha');
    final rahul = await members.addNameOnly(gid, 'Rahul');
    final me = (await (db.select(
      db.groupMembers,
    )..where((m) => m.groupId.equals(gid) & m.userId.equals(uid))).getSingle()).id;
    final today = DateTime.now();
    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final lastMonth = DateTime(today.year, today.month - 1, 12);
    final expenses = container.read(expensesRepositoryProvider);
    await expenses.save(gid, {
      'kind': 'expense',
      'description': 'Dinner at Thalassa',
      'category': 'food.dining_out',
      'date': day(today),
      'currency': 'INR',
      'total': 240000,
      'payers': {me: 240000},
      'shares': {me: 80000, asha: 80000, rahul: 80000},
      'split_kind': 'equal',
    }, id: null);
    await expenses.save(gid, {
      'kind': 'expense',
      'description': 'Cab to airport',
      'category': 'travel.cab_auto',
      'date': day(lastMonth),
      'currency': 'INR',
      'total': 120000,
      'payers': {asha: 120000},
      'shares': {asha: 60000, me: 60000},
      'split_kind': 'equal',
    }, id: null);
    final payment = await container.read(paymentsRepositoryProvider).save(gid, {
      'from_member': asha,
      'to_member': me,
      'amount': 50000,
      'currency': 'INR',
      'date': day(today),
      'method': 'upi',
      'note': 'for the cab',
    });
    final dinner =
        (await (db.select(
                  db.expenses,
                )..where((e) => e.groupId.equals(gid) & e.description.equals('Dinner at Thalassa')))
                .getSingle())
            .id;
    await container
        .read(commentsRepositoryProvider)
        .add(
          groupId: gid,
          targetType: 'expense',
          targetId: dinner,
          body: 'Paid the tip in cash, 500 extra',
          authorId: uid,
        );
    await sync();
    addTearDown(() async {
      await groups.delete(gid, gid);
      await sync();
    });
    // Everything reached the server (the backup's "pending" flags are false below).
    expect(await (db.select(db.outbox)).get(), isEmpty, reason: 'synced before going offline');

    final router = buildRouter(initialLocation: Routes.groups);
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await pumpUntil(
      t,
      () => find.byKey(Key('group-card-$gid')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 90),
      reason: 'home',
    );

    // ---- Offline from here on (real airplane mode).
    await _net(t, on: false);
    try {
      // Search everything, offline.
      unawaited(router.push(SearchRoutes.search()));
      await _pumpFor(t, const Duration(seconds: 2));
      await _search(t, '500');
      expect(find.byKey(ValueKey('search-payment-$payment')), findsOneWidget);
      expect(find.text('“Paid the tip in cash, 500 extra”'), findsOneWidget);
      expect(find.byKey(const Key('search-kind-payments')), findsOneWidget);
      expect(find.byKey(const Key('search-kind-comments')), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await _capture(t, 'search-mixed');
      await _search(t, 'asha paid');
      expect(find.byKey(ValueKey('search-payment-$payment')), findsOneWidget);
      await _search(t, 'tip cash');
      expect(find.textContaining('Paid the tip'), findsOneWidget);
      await t.testTextInput.receiveAction(TextInputAction.search);
      await _pumpFor(t, const Duration(seconds: 1));
      router.pop();
      await _pumpFor(t, const Duration(seconds: 1));

      // Search opened from the group.
      unawaited(router.push(SearchRoutes.search(groupId: gid)));
      await _pumpFor(t, const Duration(seconds: 2));
      final field = t.widget<TextField>(find.byKey(const Key('search-field')));
      expect(field.decoration!.hintText, 'Search in $name');
      expect(find.byKey(const Key('search-recent')), findsOneWidget, reason: 'recent searches');
      FocusManager.instance.primaryFocus?.unfocus();
      await _capture(t, 'search-group');
      router.pop();
      await _pumpFor(t, const Duration(seconds: 1));

      // Account → Your data → Share instead / Download my data, offline.
      router.go(Routes.account);
      await _pumpFor(t, const Duration(seconds: 2));
      final row = find.byKey(const Key('settings-your-data'));
      await t.scrollUntilVisible(row, 300, scrollable: find.byType(Scrollable).first);
      await _pumpFor(t, const Duration(milliseconds: 500));
      await t.tap(row);
      await _pumpFor(t, const Duration(seconds: 2));
      expect(find.byKey(const Key('your-data')), findsOneWidget);
      await _capture(t, 'your-data');
      await t.tap(find.byKey(const Key('your-data-share')));
      await _until(t, () => shared.isNotEmpty, 'the zip reached the share sheet');
      final file = shared.single;
      expect(file.existsSync(), isTrue);
      expect(file.path, endsWith('.zip'));
      final texts = zipTexts(await file.readAsBytes());
      final json = jsonDecode(texts['splitify-backup.json']!) as Map<String, Object?>;
      expect(json['format'], 'splitify-backup');
      final g = (json['groups']! as List).cast<Map<String, Object?>>().firstWhere(
        (x) => (x['group']! as Map)['id'] == gid,
      );
      expect((g['expenses']! as List).length, 2);
      expect((g['payments']! as List).single, containsPair('amount', 50000));
      expect((g['payments']! as List).single, containsPair('pending', false));
      expect(texts.keys.where((k) => k.startsWith('csv/goa-trip-e2e-d034-$stamp')), hasLength(1));
      // Round trip: the JSON's nets are the ledger's.
      final nets = <String, int>{};
      for (final e in (g['expenses']! as List).cast<Map<String, Object?>>()) {
        (e['paid_by']! as Map).forEach((k, v) => nets[k as String] = (nets[k] ?? 0) + (v as int));
        (e['owed']! as Map).forEach((k, v) => nets[k as String] = (nets[k] ?? 0) - (v as int));
      }
      nets[asha] = nets[asha]! + 50000;
      nets[me] = nets[me]! - 50000;
      final ledger = await t.runAsync(
        () => container.read(ledgerRepositoryProvider).loadGroup(gid),
      );
      final local = groupBalancesOf(ledger!, uid).byCurrency['INR']!.nets;
      for (final id in [me, asha, rahul]) {
        expect(nets[id] ?? 0, local[id] ?? 0, reason: id);
      }
      await t.tap(find.byKey(const Key('your-data-download')));
      await _until(t, () => saved.isNotEmpty, 'the save dialog');
      await _pumpFor(t, const Duration(seconds: 1));
      expect(find.textContaining('Saved splitify-backup-'), findsOneWidget);
      await _capture(t, 'your-data-saved');
      await t.binding.handlePopRoute();
      await _pumpFor(t, const Duration(seconds: 1));

      // Totals: Month, then back one month.
      router.go(Routes.group(gid));
      await _pumpFor(t, const Duration(seconds: 3));
      await t.tap(find.text('Totals').last);
      await _pumpFor(t, const Duration(seconds: 2));
      await t.scrollUntilVisible(
        find.byKey(const Key('totals-period')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('Month'));
      await _pumpFor(t, const Duration(seconds: 1));
      await t.tap(find.byKey(const Key('totals-prev')));
      await _pumpFor(t, const Duration(seconds: 1));
      expect(find.text('₹1,200'), findsWidgets, reason: 'last month: the cab');
      await _capture(t, 'totals-month');

      // Insights: Category over time and Who paid.
      unawaited(router.push(InsightsRoutes.group(gid)));
      await _pumpFor(t, const Duration(seconds: 3));
      final trends = find.byKey(const Key('insights-category-trend'));
      await t.scrollUntilVisible(trends, 400, scrollable: find.byType(Scrollable).first);
      await _pumpFor(t, const Duration(seconds: 1));
      expect(find.byKey(const Key('insights-who-paid')), findsOneWidget);
      await _capture(t, 'insights-trends');
    } finally {
      await _net(t, on: true);
    }
  });
}
