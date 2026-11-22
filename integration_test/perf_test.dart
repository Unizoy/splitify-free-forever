// T7 performance on the emulator (phase 15): a group with 2,000 expenses (seeded like a pull from the server)
// → open the group, scroll its list (frame timings in profile mode), and time the balance recompute after
// one more local expense. Run with the host driver:
//   flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart \
//     -d emulator-5554 --dart-define-from-file=secrets/env.dev.json
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';

const _expenses = int.fromEnvironment('PERF_EXPENSES', defaultValue: 2000);

/// Signed in as [id] without a server (the perf run never syncs).
class _SignedIn implements AuthRepository {
  const _SignedIn(this.id);

  final String id;

  @override
  AuthUser? get currentUser => AuthUser(id: id);

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One page as `pull_changes` would send it: a group, 6 members and [n] expenses over ~2 years.
PullPage _page(String gid, String uid, List<String> members, int n) {
  final start = DateTime.utc(2025, 1, 1);
  return PullPage(
    serverTime: DateTime.now().toUtc(),
    userSeq: 0,
    nextCursors: {gid: n + 10},
    rows: {
      'groups': [
        {'id': gid, 'name': 'Perf trip', 'type': 'trip', 'main_currency': 'INR', 'seq': 1},
      ],
      'group_members': [
        for (var i = 0; i < members.length; i++)
          {
            'id': members[i],
            'group_id': gid,
            'user_id': i == 0 ? uid : null,
            'display_name': i == 0 ? 'Me' : 'Friend $i',
            'position': i,
            'role': i == 0 ? 'owner' : 'member',
            'status': 'active',
            'seq': 2 + i,
          },
      ],
      'expenses': [
        for (var i = 0; i < n; i++)
          () {
            final total = 1000 + (i * 37) % 90000;
            final payer = members[i % members.length];
            final share = total ~/ members.length;
            final shares = {for (final m in members) m: share};
            shares[members.first] = total - share * (members.length - 1);
            return {
              'id': newId(),
              'group_id': gid,
              'kind': 'expense',
              'description': 'Expense ${i + 1}',
              'notes': null,
              'category': i.isEven ? 'food.dining_out' : 'travel.taxi',
              'date': start.add(Duration(hours: i * 8)).toIso8601String().substring(0, 10),
              'currency': 'INR',
              'total': total,
              'payers': {payer: total},
              'shares': shares,
              'split_kind': 'equal',
              'split_values': null,
              'source': 'app',
              'created_at': start.add(Duration(hours: i * 8)).toIso8601String(),
              'seq': 10 + i,
            };
          }(),
      ],
    },
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T7 $_expenses expenses: open, scroll, balance recompute', (t) async {
    final env = Env.load();
    const uid = '00000000-0000-4000-8000-0000000000aa';
    final gid = newId();
    final members = [for (var i = 0; i < 6; i++) newId()];
    final db = AppDatabase(NativeDatabase.memory());
    final seed = Stopwatch()..start();
    await t.runAsync(() => PullApplier(db).apply(_page(gid, uid, members, _expenses)));
    seed.stop();

    final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
    final container = ProviderContainer(
      overrides: [
        ...appOverrides(
          env: env,
          prefs: prefs,
          remote: const RemoteServices(auth: _SignedIn(uid), profiles: null),
        ),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    // Balance recompute: load the ledger and compute balances (what every change re-runs).
    final ledgerRepo = container.read(ledgerRepositoryProvider);
    final cold = Stopwatch()..start();
    final ledger = (await t.runAsync(() => ledgerRepo.loadGroup(gid)))!;
    final load = cold.elapsedMilliseconds;
    groupBalancesOf(ledger, uid);
    cold.stop();
    final runs = <int>[];
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      final l = (await t.runAsync(() => ledgerRepo.loadGroup(gid)))!;
      groupBalancesOf(l, uid);
      runs.add(sw.elapsedMilliseconds);
    }
    runs.sort();

    // After one more local expense, how long until the group's balances show it.
    await t.pumpWidget(UncontrolledProviderScope(container: container, child: const App()));
    final balances = Completer<int>();
    // Balances are computed from the ledger stream; done when the ledger holds the new expense.
    final sub = container.listen(groupLedgerProvider(gid), (_, next) {
      final v = next.value;
      if (v != null && v.expenses.length > _expenses && !balances.isCompleted) {
        groupBalancesOf(v, uid);
        balances.complete(0);
      }
    });
    final change = Stopwatch()..start();
    await t.runAsync(
      () => container.read(expensesRepositoryProvider).save(gid, {
        'kind': 'expense',
        'description': 'One more',
        'notes': null,
        'category': 'food.dining_out',
        'date': '2026-11-22',
        'currency': 'INR',
        'total': 600,
        'payers': {members.first: 600},
        'shares': {for (final m in members) m: 100},
        'split_kind': 'equal',
        'split_values': null,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    var waited = 0;
    while (!balances.isCompleted && waited < 200) {
      await t.pump(const Duration(milliseconds: 10));
      waited++;
    }
    final recompute = change.elapsedMilliseconds;
    sub.close();

    // Open the group and scroll its list.
    final open = Stopwatch()..start();
    await binding.traceAction(() async {
      container.read(routerProvider).go(Routes.group(gid));
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    }, reportKey: 'open_timeline');
    open.stop();
    // Repeating animations (loaders) never settle: pump fixed frames instead of pumpAndSettle.
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    await frames(120);
    final list = find.byType(Scrollable).first;
    await binding.traceAction(() async {
      for (var i = 0; i < 6; i++) {
        await t.fling(list, const Offset(0, -1400), 3000);
        await frames(70);
      }
      for (var i = 0; i < 3; i++) {
        await t.fling(list, const Offset(0, 1400), 3000);
        await frames(70);
      }
    }, reportKey: 'scroll_timeline');

    binding.reportData!.addAll({
      'expenses': _expenses,
      'seed_ms': seed.elapsedMilliseconds,
      'ledger_load_cold_ms': load,
      'balance_cold_ms': cold.elapsedMilliseconds,
      'balance_median_ms': runs[runs.length ~/ 2],
      'balance_max_ms': runs.last,
      'change_to_balances_ms': recompute,
      'open_group_ms': open.elapsedMilliseconds,
    });
    debugPrint('PERF ${binding.reportData}');
    await t.runAsync(db.close);
  });
}
