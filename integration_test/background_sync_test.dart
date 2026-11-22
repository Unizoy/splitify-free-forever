// S-160 / phase 19: one REAL WorkManager run on the emulator. Driven by `tool/e2e/background_sync.ps1`, which
// reacts to the markers this test prints:
//   E2E-NET off|on -> adb airplane mode on/off      E2E-HOME -> HOME key (the app goes to the background)
//   E2E-JOBS       -> `cmd jobscheduler run -f` for every job of the app (forces WorkManager's jobs to run now)
// The app runs with the real `WorkmanagerBackgroundSync` (bootstrap wiring). Offline, a group is created (queued);
// HOME pauses the app, so SyncBinding registers the one-off WorkManager task; then the network comes back and
// the jobs are forced. Pass = the outbox empties while the app is in the background and the server has the group.
// The script also saves WorkManager's logcat lines (worker result) and `dumpsys jobscheduler` as evidence.
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/background_sync_task.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/sync/background_sync.dart';
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/features/currency/application/currency_providers.dart'
    show fxAutoRefreshProvider;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

const _staged = bool.fromEnvironment('E2E_WORKER');

final _network = ConnectivityNetworkStatus();

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Waits on the real clock without pumping frames (the app is in the background).
Future<void> _waitReal(
  Future<bool> Function() check, {
  required String reason,
  int seconds = 120,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('Timed out: $reason');
}

Future<int> _outbox(AppDatabase db) async =>
    (await db
            .customSelect('SELECT COUNT(*) AS n FROM outbox', variables: <Variable<Object>>[])
            .getSingle())
        .read<int>('n');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'W1 WorkManager sends a change queued offline while the app is in the background',
    skip: !_staged,
    (t) async {
      final env = devEnv();
      final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
      final remote = (await t.runAsync(() => initRemote(env)))!;
      final background = (await t.runAsync(initBackgroundSync))!;
      expect(background, isA<WorkmanagerBackgroundSync>(), reason: 'the real WorkManager wiring');
      if (remote.auth.currentUser == null) {
        await t.runAsync(
          () => remote.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword),
        );
      }
      final c = ProviderContainer(
        overrides: [
          ...appOverrides(
            env: env,
            prefs: prefs,
            remote: remote,
            background: background,
            network: _network,
          ),
          fxAutoRefreshProvider.overrideWith((ref) {}),
        ],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const App()));
      await _pumpFor(
        t,
        const Duration(seconds: 4),
      ); // first sync + WorkManager periodic task registered

      debugPrint('E2E-NET off');
      await _waitReal(() async => !await _network.isOnline(), reason: 'network off', seconds: 60);
      await _pumpFor(t, const Duration(seconds: 1));

      final uid = remote.auth.currentUser!.id;
      final name = 'Worker check ${DateTime.now().millisecondsSinceEpoch}';
      final gid = (await t.runAsync(
        () => c
            .read(groupsRepositoryProvider)
            .create(name: name, ownerName: 'E2E A', ownerUserId: uid),
      ))!;
      await _pumpFor(t, const Duration(seconds: 3)); // the debounced sync runs and fails offline
      final db = c.read(appDatabaseProvider);
      final queued = (await t.runAsync(() => _outbox(db)))!;
      expect(queued, greaterThan(0), reason: 'the new group waits in the outbox');
      debugPrint('W1 queued $queued change(s) for group $gid');

      // HOME: SyncBinding sees the pause with changes waiting and registers the one-off WorkManager task.
      debugPrint('E2E-HOME');
      await Future<void>.delayed(const Duration(seconds: 5));
      debugPrint('E2E-NET on');
      await _waitReal(() async => _network.isOnline(), reason: 'network on', seconds: 60);
      debugPrint('E2E-JOBS');
      await _waitReal(() async => await _outbox(db) == 0, reason: 'outbox sent in the background');
      debugPrint('W1 outbox empty in the background');

      final rows = await Supabase.instance.client.from('groups').select('id').eq('id', gid);
      expect(rows, hasLength(1), reason: 'the server has the group');
      debugPrint('W1 done: server has $gid');
    // Keep the process alive until WorkManager's run finishes, so its result lands in logcat as evidence.
    await Future<void>.delayed(const Duration(seconds: 20));
    },
  );
}
