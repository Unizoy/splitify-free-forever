// D-033 Pay via UPI on the one-screen Record a payment, on the emulator against the DEV project (TC-26-02 /
// TC-26-03 with the minimal flow). A (e2e-a) uses the app; B (e2e-b, UPI ID e2e.b@okaxis) joins A's group
// through the API and pays the train for both, so A owes B ₹300 — the group's only balance:
//  - Group page → Settle up opens Record a payment at once (one balance), prefilled ₹300, amber
//    "Pay ₹300 via UPI" with "Record cash payment" under it.
//  - FAKE_UPI=installed (default): `tool/fake_upi_app` receives the link (the test prints `UPI-EXPECT <uri>`,
//    the host compares it with the app's `FAKE_UPI` logcat line), hands back, "Mark as paid" records a UPI
//    payment, the short celebration plays and the server has the row.
//  - FAKE_UPI=absent (fake app uninstalled): "No UPI app found" with the fallbacks; "Not yet" records nothing.
//   powershell -File tool\fake_upi_app\run_upi_e2e.ps1 -Test minimal_pay_upi_test
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/upi/upi_link.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

const _hold = int.fromEnvironment('UI_HOLD');
const _fakeUpi = String.fromEnvironment('FAKE_UPI', defaultValue: 'installed');
const _vpaB = 'e2e.b@okaxis';

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 30}) => pumpUntil(
  t,
  () => f.evaluate().isNotEmpty,
  timeout: Duration(seconds: seconds),
  reason: '$f',
);

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 600));
}

Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(milliseconds: 800));
  if (_hold == 0) return;
  debugPrint('UI-CAPTURE $name');
  final end = DateTime.now().add(const Duration(seconds: _hold));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await t.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D-033 Pay via UPI on Record a payment ($_fakeUpi)', (t) async {
    final env = devEnv();
    final services = await initRemote(env);
    await services.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final uidA = services.auth.currentUser!.id;
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
        friendsRemoteProvider.overrideWithValue(SupabaseFriendsRemote.fromClient(client)),
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

    final b = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-b')))!;
    addTearDown(() => t.runAsync(b.dispose));
    await t.runAsync(
      () => b.client.rpc<Object?>(
        'update_profile',
        params: {
          'p_display_name': 'E2E B',
          'p_upi_id': _vpaB,
          'p_default_currency': 'INR',
          'p_avatar_path': null,
        },
      ),
    );

    // A's group; B joins and paid the train for both: A owes B ₹300.
    final groupName = 'E2E Pay ${DateTime.now().millisecondsSinceEpoch % 100000}';
    final groups = container.read(groupsRepositoryProvider);
    final gid = await groups.create(
      name: groupName,
      ownerName: 'E2E A',
      ownerUserId: uidA,
      type: 'trip',
    );
    await sync();
    addTearDown(() async {
      await groups.delete(gid, gid);
      await sync();
    });
    final code =
        (await t.runAsync(
              () => client.from('groups').select('invite_code').eq('id', gid).single(),
            ))!['invite_code']!
            as String;
    expect((await t.runAsync(() => b.rpc('join_group', {'code': code})))!['group_id'], gid);
    await sync();
    final rows = await (db.select(db.groupMembers)..where((m) => m.groupId.equals(gid))).get();
    final a = rows.firstWhere((m) => m.userId == uidA).id;
    final mb = rows.firstWhere((m) => m.userId == b.id).id;
    final r = (await t.runAsync(
      () => b.rpc('apply_mutations', {
        'batch': [
          {
            'mutation_id': newId(),
            'entity': 'expense',
            'op': 'upsert',
            'id': newId(),
            'group_id': gid,
            'client_updated_at': DateTime.now().toUtc().toIso8601String(),
            'source': 'app',
            'data': {
              'kind': 'expense',
              'description': 'Train tickets',
              'category': 'travel.train_bus',
              'date': '2026-11-26',
              'currency': 'INR',
              'total': 60000,
              'payers': {mb: 60000},
              'shares': {a: 30000, mb: 30000},
              'split_kind': 'equal',
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
          },
        ],
      }),
    ))!;
    expect(((r['results']! as List).single! as Map)['status'], 'applied', reason: '$r');
    await sync();

    final router = buildRouter(initialLocation: Routes.group(gid));
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
    await _waitFor(t, find.byKey(const Key('group-status-owe')));
    await _pumpFor(t, const Duration(seconds: 1));

    // One balance: Settle up opens Record a payment at once, prefilled, Pay via UPI first.
    await _tap(t, find.byKey(const Key('group-settle')));
    await _waitFor(t, find.byKey(const Key('settle-upi')));
    expect(find.byKey(const Key('settle-picker')), findsNothing);
    expect(find.text('Pay ₹300 via UPI'), findsOneWidget);
    expect(find.text('Record cash payment'), findsOneWidget);
    await _capture(t, 'upi');
    await _capture(t, 'upi-dark');
    final link = const UpiLinkBuilder().build(
      vpa: _vpaB,
      name: 'E2E B',
      amountMinor: 30000,
      currencyCode: 'INR',
      note: 'Splitify: $groupName',
    );
    debugPrint('UPI-EXPECT ${link.uri}');

    var leftApp = false;
    final lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        if (s != AppLifecycleState.resumed) leftApp = true;
      },
    );
    addTearDown(lifecycle.dispose);
    await t.tap(find.byKey(const Key('settle-upi')));
    if (_fakeUpi == 'absent') {
      await _waitFor(t, find.byKey(const Key('upi-no-app')));
      expect(find.byKey(const Key('upi-copy-id')), findsWidgets);
      expect(find.byKey(const Key('upi-qr')), findsWidgets);
      await _capture(t, 'upi-no-app');
      await _tap(t, find.byKey(const Key('upi-not-yet')));
      expect(find.byKey(const Key('settle-upi')), findsOneWidget, reason: 'the form stays');
      final none = await (db.select(db.payments)..where((p) => p.groupId.equals(gid))).get();
      expect(none, isEmpty, reason: 'nothing is recorded without "Mark as paid"');
      debugPrint('D-033-UPI-ABSENT OK');
      return;
    }
    // The fake UPI app takes the foreground and hands back after 1.5 s (real time, no pumping while paused).
    final back = DateTime.now().add(const Duration(seconds: 45));
    while (!(leftApp && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) &&
        DateTime.now().isBefore(back)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    expect(leftApp, isTrue, reason: 'the fake UPI app opened');
    await _waitFor(t, find.byKey(const Key('upi-return')));
    await _capture(t, 'upi-return');
    expect(
      await (db.select(db.payments)..where((p) => p.groupId.equals(gid))).get(),
      isEmpty,
      reason: 'not recorded before "Mark as paid" (rule 13)',
    );
    await _tap(t, find.byKey(const Key('upi-mark-paid')));
    await _waitFor(t, find.byKey(const Key('settled-celebration')), seconds: 10);
    await _capture(t, 'upi-celebration');
    await pumpUntil(
      t,
      () => find.byKey(const Key('settled-celebration')).evaluate().isEmpty,
      timeout: const Duration(seconds: 10),
      reason: 'the celebration closes itself',
    );
    expect(find.byKey(const Key('group-settle')), findsOneWidget, reason: 'back on the group');
    final paid = await (db.select(db.payments)..where((p) => p.groupId.equals(gid))).getSingle();
    expect((paid.method, paid.amount, paid.fromMember, paid.toMember), ('upi', 30000, a, mb));
    await sync();
    final server = (await t.runAsync(
      () => client.from('payments').select('method, amount').eq('id', paid.id).single(),
    ))!;
    expect((server['method'], (server['amount'] as num).toInt()), ('upi', 30000));
    debugPrint('D-033-UPI-INSTALLED OK');
  });
}
