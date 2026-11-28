// R3-A (layout, type, accessibility on every phone size): device screenshots of the key screens against the
// DEV project as e2e-a. It only seeds a small group and navigates (no checks), so the same file captures the
// screens before and after the change. With --dart-define=UI_HOLD=<s> it prints `UI-CAPTURE <name>` and holds
// each state while the host script takes the shots at several font scales and a small display size:
//   powershell -Command ". tool\env.ps1; & tool\e2e\capture_r3a.ps1 -Prefix before"
// Built side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) with --no-uninstall. The test
// group is soft-deleted at the end.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each state stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester t, String name) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await _pumpFor(t, const Duration(milliseconds: 900));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  final end = DateTime.now().add(const Duration(seconds: _hold));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
  debugPrint('UI-CAPTURED $name');
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R3-A key screens for the before/after screenshots', (t) async {
    final env = devEnv();
    final services = await initRemote(env);
    await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final uid = services.auth.currentUser!.id;
    final client = Supabase.instance.client;
    final db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(SupabaseRemoteApi.client(client)),
        balancesRemoteProvider.overrideWithValue(SupabaseBalancesRemote.fromClient(client)),
        groupsRemoteProvider.overrideWithValue(services.groups),
        authRepositoryProvider.overrideWithValue(services.auth),
        profileRemoteProvider.overrideWithValue(services.profiles),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);
    Future<void> sync() => t.runAsync(() async {
      await engine.sync();
      await engine.sync();
    });

    // A trip with three people, two expenses and a payment, so balances, rows and amounts show.
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
    final gid = await groups.create(
      name: 'Goa trip (E2E R3A $stamp)',
      ownerName: 'Mohit',
      ownerUserId: uid,
      type: 'trip',
    );
    final asha = await members.addNameOnly(gid, 'Asha Rao');
    final rahul = await members.addNameOnly(gid, 'Rahul Mehta');
    final me = (await (db.select(
      db.groupMembers,
    )..where((m) => m.groupId.equals(gid) & m.userId.equals(uid))).getSingle()).id;
    final today = DateTime.now();
    final expenses = container.read(expensesRepositoryProvider);
    await expenses.save(gid, {
      'kind': 'expense',
      'description': 'Dinner at Thalassa',
      'category': 'food.dining_out',
      'date': _day(today),
      'currency': 'INR',
      'total': 1234500,
      'payers': {me: 1234500},
      'shares': {me: 411500, asha: 411500, rahul: 411500},
      'split_kind': 'equal',
    });
    await expenses.save(gid, {
      'kind': 'expense',
      'description': 'Cab to the airport and back',
      'category': 'travel.cab_auto',
      'date': _day(today.subtract(const Duration(days: 3))),
      'currency': 'INR',
      'total': 120000,
      'payers': {asha: 120000},
      'shares': {asha: 60000, me: 60000},
      'split_kind': 'equal',
    });
    await container.read(paymentsRepositoryProvider).save(gid, {
      'from_member': rahul,
      'to_member': me,
      'amount': 50000,
      'currency': 'INR',
      'date': _day(today),
      'method': 'upi',
      'note': 'for dinner',
    });
    await sync();
    addTearDown(() async {
      await groups.delete(gid, gid);
      await sync();
    });
    final dinner =
        (await (db.select(
                  db.expenses,
                )..where((e) => e.groupId.equals(gid) & e.description.equals('Dinner at Thalassa')))
                .getSingle())
            .id;

    final router = buildRouter(initialLocation: Routes.groups);
    addTearDown(router.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
    await _pumpFor(t, const Duration(seconds: 2));
    debugPrint('UI-READY');

    Future<void> shot(String name, String path, {bool push = false}) async {
      if (push) {
        router.go(Routes.groups);
        await _pumpFor(t, const Duration(milliseconds: 600));
        router.push(path).ignore();
      } else {
        router.go(path);
      }
      await _pumpFor(t, const Duration(seconds: 3));
      await _capture(t, name);
    }

    await _capture(t, 'home');
    await shot('group', Routes.group(gid));
    await shot('group-balances', '${Routes.group(gid)}?tab=balances');
    await shot('editor', '/expense/new?group=$gid', push: true);
    await shot('expense', '/expense/$dinner', push: true);
    await shot('settle', '/settle?group=$gid&from=$me&to=$asha&currency=INR', push: true);
    await shot('friends', Routes.friends);
    await shot('activity', Routes.activity);
    await shot('account', Routes.account);
    await shot('search', '/search', push: true);
    debugPrint('R3A-CAPTURE OK');
  });
}
