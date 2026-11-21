// Phase 09 T7 (TC-25-03, TC-15-04): "a week in Goa". A (e2e-a) uses the app; B (e2e-b) and C (e2e-c)
// use the API through the multi-user harness. Seven days of expenses with every split type and two
// payments (one recorded by C through the API, one by A on the Settle up screen) → the phone's balances,
// the server's `group_balances` and an independent oracle (the reference algorithm, written out here)
// agree; the after-sync check finds no difference (T3); then everyone settles what the Balances tab
// shows → every net and pair is zero on the phone and on the server, and the tab says "all settled".
//   flutter test integration_test/balances_week_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json [--dart-define=PIN_HOST_IP=<ip resolved on the PC>]
// With `--dart-define=UI_HOLD=<s>` it also holds each screen and prints `UI-CAPTURE <name>` for
// `.claude/skills/ui-review/scripts/capture_markers.ps1` (device UI review, G5).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/domain/balance_check.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart' show FolderTabs;
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no captures).
const _hold = int.fromEnvironment('UI_HOLD');

/// One expense as the oracle sees it.
typedef _Flow = ({Map<String, int> paid, Map<String, int> shares});

/// One payment as the oracle sees it.
typedef _Pay = ({String from, String to, int amount});

/// The reference algorithm (planning/reference/money_reference.py, 05 §5), written out independently of
/// `lib/core/money/balances.dart`: nets, and per-expense north-west matching summed per pair.
({Map<String, int> nets, Map<(String, String), int> pairs}) _oracle(
  List<String> order,
  List<_Flow> expenses,
  List<_Pay> payments,
) {
  final nets = {for (final m in order) m: 0};
  final acc = <(String, String), int>{}; // (lower, higher) in fixed order; + = lower owes higher
  void add(String debtor, String creditor, int x) {
    final i = order.indexOf(debtor);
    final j = order.indexOf(creditor);
    final key = i < j ? (debtor, creditor) : (creditor, debtor);
    acc[key] = (acc[key] ?? 0) + (i < j ? x : -x);
  }

  for (final e in expenses) {
    e.paid.forEach((m, v) => nets[m] = nets[m]! + v);
    e.shares.forEach((m, v) => nets[m] = nets[m]! - v);
    final debtors = <(String, int)>[];
    final creditors = <(String, int)>[];
    for (final m in order) {
      final v = (e.paid[m] ?? 0) - (e.shares[m] ?? 0);
      if (v < 0) debtors.add((m, -v));
      if (v > 0) creditors.add((m, v));
    }
    var i = 0;
    var j = 0;
    while (i < debtors.length && j < creditors.length) {
      final x = debtors[i].$2 < creditors[j].$2 ? debtors[i].$2 : creditors[j].$2;
      add(debtors[i].$1, creditors[j].$1, x);
      debtors[i] = (debtors[i].$1, debtors[i].$2 - x);
      creditors[j] = (creditors[j].$1, creditors[j].$2 - x);
      if (debtors[i].$2 == 0) i++;
      if (creditors[j].$2 == 0) j++;
    }
  }
  for (final p in payments) {
    nets[p.from] = nets[p.from]! + p.amount;
    nets[p.to] = nets[p.to]! - p.amount;
    add(p.from, p.to, -p.amount);
  }
  final pairs = <(String, String), int>{};
  acc.forEach((k, v) {
    if (v > 0) pairs[k] = v;
    if (v < 0) pairs[(k.$2, k.$1)] = -v;
  });
  return (nets: nets, pairs: pairs);
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitFor(WidgetTester t, Finder f, {int seconds = 20}) async {
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

Finder _tab(String label) =>
    find.descendant(of: find.byType(FolderTabs), matching: find.text(label)).first;

/// Holds the screen for the host captures (real-time waits, never a tight pump loop: S-086 / phase 07).
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

  testWidgets('TC-25-03 a week in Goa: balances = oracle = server; everyone settles → all zero', (
    t,
  ) async {
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
    final c = (await t.runAsync(() => HarnessUser.signIn(env, 'e2e-c')))!;

    // Day 0: A creates the trip (offline-first write, then sync); B and C join with the invite code.
    final gid = await container
        .read(groupsRepositoryProvider)
        .create(
          name: 'E2E Goa week ${DateTime.now().millisecondsSinceEpoch}',
          ownerName: 'E2E A',
          ownerUserId: uidA,
          type: 'trip',
        );
    await sync();
    final code =
        (await t.runAsync(
              () => client.from('groups').select('invite_code').eq('id', gid).single(),
            ))!['invite_code']!
            as String;
    for (final h in [b, c]) {
      final r = (await t.runAsync(() => h.rpc('join_group', {'code': code})))!;
      expect(r['group_id'], gid);
    }
    await sync();
    final rows = await (db.select(db.groupMembers)..where((m) => m.groupId.equals(gid))).get();
    String memberOf(String uid) => rows.firstWhere((m) => m.userId == uid).id;
    final a = memberOf(uidA);
    final mb = memberOf(b.id);
    final mc = memberOf(c.id);
    final order = [
      for (final m
          in [...rows]..sort((x, y) {
            final p = x.position.compareTo(y.position);
            return p != 0 ? p : x.id.compareTo(y.id);
          }))
        m.id,
    ];
    expect(order.toSet(), {a, mb, mc});

    // Seven days, every split type, payers A, B and C.
    final flows = <_Flow>[];
    Map<String, Object?> expense(
      String description,
      String date,
      int total,
      String payer,
      SplitKind kind,
      List<String> people, [
      Map<String, int> values = const {},
    ]) {
      final fixed = [
        for (final m in order)
          if (people.contains(m)) m,
      ];
      final shares = split(total, kind, fixed, values);
      flows.add((paid: {payer: total}, shares: shares));
      return {
        'kind': 'expense',
        'description': description,
        'category': 'travel.hotel',
        'date': date,
        'currency': 'INR',
        'total': total,
        'payers': {payer: total},
        'shares': shares,
        'split_kind': kind.name,
        'split_values': kind == SplitKind.equal ? null : values,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
    }

    Future<void> viaApi(HarnessUser h, String entity, Map<String, Object?> data) async {
      final r = (await t.runAsync(
        () => h.rpc('apply_mutations', {
          'batch': [
            {
              'mutation_id': newId(),
              'entity': entity,
              'op': 'upsert',
              'id': newId(),
              'group_id': gid,
              'client_updated_at': DateTime.now().toUtc().toIso8601String(),
              'source': 'app',
              'data': data,
            },
          ],
        }),
      ))!;
      expect(((r['results']! as List).single! as Map)['status'], 'applied', reason: '$r');
    }

    final mine = container.read(expensesRepositoryProvider);
    final everyone = [a, mb, mc];
    await mine.save(
      gid,
      expense('Villa, 3 nights', '2026-11-15', 900000, a, SplitKind.equal, everyone),
    );
    await viaApi(
      b,
      'expense',
      expense('Seafood dinner', '2026-11-16', 240050, mb, SplitKind.exact, everyone, {
        a: 100000,
        mb: 70050,
        mc: 70000,
      }),
    );
    await viaApi(
      c,
      'expense',
      expense('Cab to the fort', '2026-11-17', 150000, mc, SplitKind.percent, everyone, {
        a: 5000,
        mb: 2500,
        mc: 2500,
      }),
    );
    await mine.save(
      gid,
      expense(
        'Scuba dive',
        '2026-11-18',
        600000,
        a,
        SplitKind.shares,
        [a, mb],
        {a: 2000, mb: 1000},
      ),
    );
    await viaApi(
      b,
      'expense',
      expense('Groceries', '2026-11-19', 123456, mb, SplitKind.adjust, everyone, {a: 10000}),
    );
    await viaApi(
      c,
      'expense',
      expense('Beach lunch', '2026-11-20', 99999, mc, SplitKind.equal, everyone),
    );
    await mine.save(
      gid,
      expense('Scooter fuel', '2026-11-21', 180000, a, SplitKind.equal, [a, mc]),
    );
    // Payment 1: C pays A ₹1,000 (recorded by C through the API).
    final payments = <_Pay>[(from: mc, to: a, amount: 100000)];
    await viaApi(c, 'payment', {
      'from_member': mc,
      'to_member': a,
      'amount': 100000,
      'currency': 'INR',
      'date': '2026-11-20',
      'method': 'upi',
    });
    await sync();

    // The app, signed in as A.
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
    await _pumpFor(t, const Duration(seconds: 2));

    // Payment 2: A pays B ₹200 on the Settle up screen (method UPI, typed amount).
    router.go(PaymentRoutes.settle(gid, from: a, to: mb, currency: 'INR'));
    await _waitFor(t, find.byKey(const Key('settle-save')));
    await t.enterText(find.byKey(const Key('settle-amount')), '200');
    FocusManager.instance.primaryFocus?.unfocus();
    await _pumpFor(t, const Duration(milliseconds: 500));
    await _tap(t, find.byKey(const Key('method-upi')));
    await _tap(t, find.byKey(const Key('settle-save')));
    await _waitFor(t, find.byKey(const Key('group-settle')));
    payments.add((from: a, to: mb, amount: 20000));
    final pending = await (db.select(db.payments)..where((p) => p.groupId.equals(gid))).get();
    expect(pending.where((p) => p.syncState != SyncState.synced), hasLength(1));
    await sync();

    // Phone = server = oracle (nets and original pairs, simplify off).
    final expected = _oracle(order, flows, payments);
    expect(expected.nets.values.fold(0, (x, y) => x + y), 0);
    final ledger = (await t.runAsync(
      () => container.read(ledgerRepositoryProvider).loadGroup(gid),
    ))!;
    expect(ledger.expenses, hasLength(7));
    expect(ledger.payments, hasLength(2));
    final local = groupBalancesOf(ledger, uidA);
    final inr = local.byCurrency['INR']!;
    for (final m in order) {
      expect(inr.nets[m] ?? 0, expected.nets[m], reason: 'local net of $m');
    }
    expect({for (final p in inr.pairs) (p.from, p.to): p.amount}, expected.pairs);
    final server = (await t.runAsync(
      () => container.read(balancesRemoteProvider).groupBalances(gid),
    ))!;
    final sInr = server.currencies['INR']!;
    for (final m in order) {
      expect(sInr.nets[m] ?? 0, expected.nets[m], reason: 'server net of $m');
    }
    expect({for (final p in sInr.pairs) (p.from, p.to): p.amount}, expected.pairs);

    // T3 / TC-15-04: the after-sync check finds the same checksum on both sides.
    final check = (await t.runAsync(() => container.read(balanceCheckerProvider).checkGroup(gid)))!;
    expect(check.matches, isTrue);
    expect(check.localChecksum, balancesChecksum(server.currencies));
    final overview = (await t.runAsync(
      () => container.read(balanceCheckerProvider).checkOverview(),
    ))!;
    expect(overview.differences, isNot(contains(gid)));
    expect(
      overview.server.groups.firstWhere((g) => g.groupId == gid).balances['INR'] ?? 0,
      expected.nets[a],
    );

    // The Balances tab shows my net in the banner and every pair.
    router.go(Routes.group(gid));
    await _waitFor(t, find.byKey(const Key('group-settle')));
    await _capture(t, 'group-expenses');
    await _tap(t, _tab('Balances'));
    await _waitFor(t, find.byKey(const Key('balances-banner')));
    final myNet = expected.nets[a]!;
    expect(myNet, isNot(0));
    expect(
      find.descendant(
        of: find.byKey(const Key('balances-banner')),
        matching: find.text(listMoney(myNet.abs(), 'INR')),
      ),
      findsOneWidget,
    );
    for (final p in expected.pairs.keys) {
      expect(find.byKey(Key('transfer-INR-${p.$1}-${p.$2}')), findsOneWidget);
    }
    await _capture(t, 'group-balances');
    await _tap(t, _tab('Totals'));
    await _waitFor(t, find.byKey(const Key('totals-tab')));
    await _capture(t, 'group-totals');

    if (_hold > 0) {
      // Device UI review of the other phase 09 screens with this real data.
      await _tap(t, find.byKey(const Key('group-settle')));
      await _waitFor(t, find.byKey(const Key('settle-picker')));
      await _capture(t, 'settle-picker');
      router.go(PaymentRoutes.settle(gid, from: a, to: mb, currency: 'INR'));
      await _waitFor(t, find.byKey(const Key('settle-save')));
      await _capture(t, 'settle-up');
      final paid = pending.firstWhere((p) => p.fromMember == a);
      router.go(PaymentRoutes.detail(paid.id));
      await _waitFor(t, find.byKey(const Key('payment-detail-amount')));
      await _capture(t, 'payment-detail');
      router.go(PaymentRoutes.groupActivity(gid));
      await _pumpFor(t, const Duration(seconds: 2));
      await _capture(t, 'group-activity');
      router.go(Routes.activity);
      await _pumpFor(t, const Duration(seconds: 2));
      await _capture(t, 'activity');
      router.go(Routes.groups);
      await _waitFor(t, find.byKey(const Key('groups-glass')));
      await _capture(t, 'groups-home');
      router.go(Routes.account);
      await _waitFor(t, find.byKey(const Key('account-wallet')));
      await _capture(t, 'account');
    }

    // Everyone settles what the tab shows: A on the Settle up screen (prefilled), B and C via the API.
    for (final entry in expected.pairs.entries) {
      final (from, to) = entry.key;
      if (from == a) {
        router.go(PaymentRoutes.settle(gid, from: from, to: to, currency: 'INR'));
        await _waitFor(t, find.byKey(const Key('settle-save')));
        expect(find.byKey(const Key('settle-gauge')), findsOneWidget);
        await _tap(t, find.byKey(const Key('settle-save')));
        await _waitFor(t, find.byKey(const Key('group-settle')));
      } else {
        await viaApi(from == mb ? b : c, 'payment', {
          'from_member': from,
          'to_member': to,
          'amount': entry.value,
          'currency': 'INR',
          'date': '2026-11-22',
          'method': 'cash',
        });
      }
    }
    await sync();
    final after = (await t.runAsync(
      () => container.read(ledgerRepositoryProvider).loadGroup(gid),
    ))!;
    final settled = groupBalancesOf(after, uidA).byCurrency['INR']!;
    expect(settled.nets.values.every((v) => v == 0), isTrue, reason: '${settled.nets}');
    expect(settled.pairs, isEmpty);
    final serverAfter = (await t.runAsync(
      () => container.read(balancesRemoteProvider).groupBalances(gid),
    ))!;
    expect(serverAfter.currencies['INR']!.nets.values.every((v) => v == 0), isTrue);
    expect(serverAfter.currencies['INR']!.pairs, isEmpty);
    final checkAfter = (await t.runAsync(
      () => container.read(balanceCheckerProvider).checkGroup(gid),
    ))!;
    expect(checkAfter.matches, isTrue);

    router.go(Routes.group(gid));
    await _waitFor(t, find.byKey(const Key('group-settle')));
    await _tap(t, _tab('Balances'));
    await _waitFor(t, find.text("You're all settled"));
    expect(find.byKey(const Key('group-status-settled')), findsOneWidget);
    await _capture(t, 'group-balances-settled');

    // Tidy up the dev project: soft-delete the test group (creator only, restorable).
    await container.read(groupsRepositoryProvider).delete(gid, gid);
    await sync();
    await t.runAsync(() async {
      await b.dispose();
      await c.dispose();
    });
    // Let the router leave the group before the database closes.
    router.go(Routes.groups);
    await _pumpFor(t, const Duration(seconds: 1));
    await t.pumpWidget(const SizedBox());
  });
}
