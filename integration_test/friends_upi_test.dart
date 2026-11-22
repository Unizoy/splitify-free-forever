// Phase 11 device scenario (TC-2-02, TC-26-02, TC-26-03, TC-17-03 on the device). A (e2e-a) uses the app;
// B (e2e-b) uses the API through the multi-user harness and has a UPI ID.
//  1. A and B share a group; B paid the train → A owes B.
//  2. Friends tab → B's row → friend page; "Add expense" makes our direct group on the server (online once,
//     S-120) and opens the stepper; A adds "Coffee" there, B finds the same direct group and adds "Snacks" →
//     both expenses are on A's friend page and in B's `my_overview` total with A (TC-2-02); the phone's
//     total = server total = Σ group pairs.
//  3. Settle up with B → "Pay ₹300 via UPI": with the fake UPI app installed it receives the link (the test
//     prints `UPI-EXPECT <uri>`; tool/fake_upi_app/run_upi_e2e.ps1 compares it with the app's `FAKE_UPI`
//     logcat line, TC-26-02), returns, "Mark as paid" records a UPI payment and the Celebration plays;
//     with `--dart-define=FAKE_UPI=absent` (app uninstalled) the "No UPI app found" sheet shows (TC-26-03).
//  4. Group settings → Simplify debts on → the server logs `settings_changed` (T3).
//   powershell -File tool\fake_upi_app\run_upi_e2e.ps1     (builds/installs the fake app, runs both paths)
// With `--dart-define=UI_HOLD=<s>` it prints `UI-CAPTURE <name>` for the device UI review (G5).
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
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no captures).
const _hold = int.fromEnvironment('UI_HOLD');

/// `installed` (default): the fake UPI app answers `upi://pay`; `absent`: no UPI app on the emulator.
const _fakeUpi = String.fromEnvironment('FAKE_UPI', defaultValue: 'installed');

const _vpaB = 'e2e.b@okaxis';

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 25}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $f');
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _pumpFor(t, const Duration(milliseconds: 500));
}

/// Holds the screen for the host captures (real-time waits, never a tight pump loop).
Future<void> _capture(WidgetTester t, String name) async {
  await _pumpFor(t, const Duration(seconds: 1));
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

  testWidgets('TC-2-02 / TC-26-02 / TC-26-03 friends, friend expenses and Pay via UPI', (t) async {
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

    Future<void> viaApi(String groupId, String entity, Map<String, Object?> data) async {
      final r = (await t.runAsync(
        () => b.rpc('apply_mutations', {
          'batch': [
            {
              'mutation_id': newId(),
              'entity': entity,
              'op': 'upsert',
              'id': newId(),
              'group_id': groupId,
              'client_updated_at': DateTime.now().toUtc().toIso8601String(),
              'source': 'app',
              'data': data,
            },
          ],
        }),
      ))!;
      expect(((r['results']! as List).single! as Map)['status'], 'applied', reason: '$r');
    }

    Map<String, Object?> expense(String what, int total, String payer, Map<String, int> shares) => {
      'kind': 'expense',
      'description': what,
      'category': 'food.dining_out',
      'date': '2026-11-22',
      'currency': 'INR',
      'total': total,
      'payers': {payer: total},
      'shares': shares,
      'split_kind': 'equal',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Earlier (failed) runs may have left test groups behind: soft-delete A's E2E friend groups and direct
    // groups first, so the totals below only count this run.
    final leftovers = (await t.runAsync(
      () => client
          .from('groups')
          .select('id, name, type')
          .eq('created_by', uidA)
          .isFilter('deleted_at', null),
    ))!;
    final stale = [
      for (final g in leftovers)
        if (g['type'] == 'direct' || (g['name']! as String).startsWith('E2E Friends'))
          g['id']! as String,
    ];
    if (stale.isNotEmpty) {
      await t.runAsync(
        () => client.rpc<Object?>(
          'apply_mutations',
          params: {
            'batch': [
              for (final id in stale)
                {
                  'mutation_id': newId(),
                  'entity': 'group',
                  'op': 'delete',
                  'id': id,
                  'group_id': id,
                  'client_updated_at': DateTime.now().toUtc().toIso8601String(),
                  'source': 'app',
                  'data': <String, Object?>{},
                },
            ],
          },
        ),
      );
    }

    // 1. A's group; B joins; B paid the train for both (A owes B ₹300).
    final groupName = 'E2E Friends ${DateTime.now().millisecondsSinceEpoch}';
    final gid = await container
        .read(groupsRepositoryProvider)
        .create(name: groupName, ownerName: 'E2E A', ownerUserId: uidA, type: 'trip');
    await sync();
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
    await viaApi(gid, 'expense', expense('Train tickets', 60000, mb, {a: 30000, mb: 30000}));
    await sync();

    // The app, signed in as A, on the Friends tab.
    final router = buildRouter(initialLocation: Routes.friends);
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
    final bKey = 'u:${b.id}';
    final bRow = find.byKey(ValueKey('friend-$bKey'));
    await _waitFor(t, bRow);
    await _capture(t, 'friends-tab');

    // 2. Friend page → Add expense: the direct group is made on the server and the stepper opens.
    await _tap(t, bRow);
    await _waitFor(t, find.byKey(const Key('friend-status-owe')));
    await _tap(t, find.byKey(const Key('friend-add-expense')));
    // The stepper opens in our new direct group (made by the server, then pulled).
    final opened = DateTime.now().add(const Duration(seconds: 45));
    String? directOrNull;
    while (DateTime.now().isBefore(opened)) {
      await t.pump(const Duration(milliseconds: 200));
      directOrNull = await container.read(friendsRepositoryProvider).findDirectGroup(uidA, b.id);
      if (directOrNull != null && find.text('Paid by').evaluate().isNotEmpty) break;
    }
    if (directOrNull == null || find.text('Paid by').evaluate().isEmpty) {
      final texts = [for (final w in t.widgetList<Text>(find.byType(Text))) ?w.data];
      fail('the add-expense stepper did not open in a direct group; on screen: $texts');
    }
    final directId = directOrNull;
    final direct = await (db.select(db.groups)..where((g) => g.id.equals(directId))).getSingle();
    expect(direct.type, 'direct');
    final dm = await (db.select(db.groupMembers)..where((m) => m.groupId.equals(directId))).get();
    final da = dm.firstWhere((m) => m.userId == uidA).id;
    final db2 = dm.firstWhere((m) => m.userId == b.id).id;
    // TC-2-01 on the device: B finds the same direct group.
    final found = (await t.runAsync(
      () => b.rpc('find_or_create_direct_group', {'friend_user_id': uidA}),
    ))!;
    expect(found['group_id'], directId);
    expect(found['member_id'], da);

    // A adds "Coffee" (₹200, B owes A ₹100) offline-first; B adds "Snacks" (₹80, A owes B ₹40).
    router.go(FriendRoutes.page(bKey));
    await _pumpFor(t, const Duration(seconds: 1));
    final coffee = await container
        .read(expensesRepositoryProvider)
        .save(directId, expense('Coffee', 20000, da, {da: 10000, db2: 10000}));
    await viaApi(directId, 'expense', expense('Snacks', 8000, db2, {da: 4000, db2: 4000}));
    await sync();

    // TC-2-02: both expenses on A's friend page. In the trip A owes B ₹300; in the direct group B owes A
    // ₹100 − ₹40 = ₹60. Other groups A and B share (other test runs) add to the total, so compare parts.
    await _waitFor(t, find.byKey(ValueKey('friend-item-$coffee')));
    expect(find.text('Snacks'), findsOneWidget);
    expect(find.text('Train tickets'), findsOneWidget);
    expect(find.byKey(ValueKey('friend-group-$gid')), findsOneWidget);
    expect(find.byKey(ValueKey('friend-group-$directId')), findsOneWidget);
    final friend = container.read(friendProvider(bKey)).value!;
    Map<String, int> amountsIn(String id) =>
        friend.links.firstWhere((l) => l.group.id == id).amounts;
    expect(amountsIn(gid), {'INR': -30000});
    expect(amountsIn(directId), {'INR': 6000});
    final total = friend.balances['INR'] ?? 0;
    expect(
      friend.links.fold<int>(0, (s, l) => s + (l.amounts['INR'] ?? 0)),
      total,
      reason: 'friend total = Σ group pairs',
    );
    // …and the server agrees from both sides (my_overview friends).
    final bOverview = (await t.runAsync(() => b.rpc('my_overview')))!;
    final aForB = (bOverview['friends']! as List).cast<Map<String, Object?>>().firstWhere(
      (f) => f['user_id'] == uidA,
    );
    expect((aForB['balances']! as Map)['INR'] ?? 0, -total);
    final aOverview = (await t.runAsync(
      () => container.read(balancesRemoteProvider).myOverview(),
    ))!;
    expect(aOverview.people.firstWhere((p) => p.userId == b.id).balances['INR'] ?? 0, total);
    await _capture(t, 'friend-page');

    // 3. Settle up with B in the trip: Pay ₹300 via UPI.
    router.go(PaymentRoutes.settle(gid, from: a, to: mb, currency: 'INR'));
    await _waitFor(t, find.byKey(const Key('settle-upi')), seconds: 30);
    expect(find.text('Pay ₹300 via UPI'), findsOneWidget);
    await _capture(t, 'settle-up-upi');
    final link = const UpiLinkBuilder().build(
      vpa: _vpaB,
      name: 'E2E B',
      amountMinor: 30000,
      currencyCode: 'INR',
      note: 'Splitify: $groupName',
    );
    debugPrint('UPI-EXPECT ${link.uri}');
    // The fake UPI app takes the foreground (Splitify pauses) and hands back after 1.5 s.
    var leftApp = false;
    final lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        if (s != AppLifecycleState.resumed) leftApp = true;
      },
    );
    addTearDown(lifecycle.dispose);
    await t.tap(find.byKey(const Key('settle-upi')));
    if (_fakeUpi == 'absent') {
      // TC-26-03: nothing answers upi://pay → the fallback sheet.
      await _waitFor(t, find.byKey(const Key('upi-no-app')));
      expect(find.byKey(const Key('upi-copy-id')), findsWidgets);
      expect(find.byKey(const Key('upi-qr')), findsWidgets);
      await _capture(t, 'upi-no-app');
      await _tap(t, find.byKey(const Key('upi-not-yet')));
      final none = await (db.select(db.payments)..where((p) => p.groupId.equals(gid))).get();
      expect(none, isEmpty, reason: 'nothing is recorded without "Mark as paid"');
    } else {
      // TC-26-02: the fake app gets the link, comes back; Mark as paid records it.
      // Wait (real time, no pumping while paused) until the app went away and came back.
      final back = DateTime.now().add(const Duration(seconds: 45));
      while (!(leftApp && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) &&
          DateTime.now().isBefore(back)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(leftApp, isTrue, reason: 'the fake UPI app opened');
      await _waitFor(t, find.byKey(const Key('upi-return')), seconds: 30);
      await _pumpFor(t, const Duration(seconds: 1));
      await _capture(t, 'upi-return');
      await _tap(t, find.byKey(const Key('upi-mark-paid')));
      await _waitFor(t, find.byKey(const Key('settled-celebration')), seconds: 10);
      // It closes itself, then Settle up closes.
      final gone = DateTime.now().add(const Duration(seconds: 10));
      while (find.byKey(const Key('settled-celebration')).evaluate().isNotEmpty &&
          DateTime.now().isBefore(gone)) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(find.byKey(const Key('settled-celebration')), findsNothing);
      final paid = await (db.select(db.payments)..where((p) => p.groupId.equals(gid))).get();
      expect(paid, hasLength(1));
      expect((paid.single.method, paid.single.amount, paid.single.fromMember), ('upi', 30000, a));
      await sync();
      final server = (await t.runAsync(
        () => client.from('payments').select('method, amount').eq('id', paid.single.id).single(),
      ))!;
      expect((server['method'], server['amount']), ('upi', 30000));
    }

    // 4. Simplify debts on in the trip's settings → settings_changed on the server.
    router.go(Routes.groupSettings(gid));
    await _waitFor(t, find.byKey(const Key('settings-simplify')));
    await _tap(t, find.byKey(const Key('settings-simplify')));
    await _pumpFor(t, const Duration(seconds: 1));
    await _capture(t, 'group-settings-simplify');
    await sync();
    final last = (await t.runAsync(
      () => client
          .from('activity')
          .select('type, data')
          .eq('group_id', gid)
          .order('seq', ascending: false)
          .limit(1)
          .single(),
    ))!;
    expect(last['type'], 'settings_changed');
    expect((last['data']! as Map)['simplify_debts'], true);

    // Tidy up the dev project: soft-delete both test groups (A created them; restorable).
    router.go(Routes.groups);
    await _pumpFor(t, const Duration(seconds: 1));
    await container.read(groupsRepositoryProvider).delete(gid, gid);
    await container.read(groupsRepositoryProvider).delete(directId, directId);
    await sync();
    await t.runAsync(b.dispose);
    await t.pumpWidget(const SizedBox());
  });
}
