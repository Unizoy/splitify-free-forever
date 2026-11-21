// UI review scenario for "Sync & storage" (phase 06 T5, ui-review skill): signs in e2e-a on the dev project,
// opens the screen through Account → settings, and holds two real states on screen while the host script
// `.claude/skills/ui-review/scripts/capture_markers.ps1` takes light / dark / 200 % screenshots on each
// `UI-CAPTURE <name>` log line. Also walks Retry → Discard on a change the server really refused.
// Run through the capture script, or: flutter test integration_test/scenarios/sync_storage_review_test.dart
//   -d emulator-5554 --dart-define-from-file=secrets/env.dev.json
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/harness.dart';

/// Seconds each state stays on screen for the host captures (`UI_HOLD`, default 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

class _Switch implements RemoteApi {
  _Switch(this.real);

  final RemoteApi real;
  bool online = true;

  Future<T> _call<T>(Future<T> Function() f) =>
      online ? f() : Future.error(const NetworkException('offline'));

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) =>
      _call(() => real.applyMutations(batch));

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) => _call(() => real.pullChanges(cursors: cursors, userSeq: userSeq, pageSize: pageSize));

  @override
  Future<void> refreshSession() => real.refreshSession();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> hold(WidgetTester tester, String name) async {
    if (_hold == 0) return;
    debugPrint('UI-CAPTURE $name');
    final end = DateTime.now().add(const Duration(seconds: _hold));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('Sync & storage on the dev project: synced, then offline with a refused change', (
    tester,
  ) async {
    final env = devEnv();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final r = await initRemote(env);
    await r.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final net = _Switch(r.api);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appOverrides(
          env: env,
          prefs: prefs,
          remote: RemoteServices(auth: r.auth, profiles: r.profiles, api: net),
        ),
        child: const App(),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(App)));
    await pumpUntil(tester, () => c.read(routerProvider).state.uri.path == Routes.groups);
    await c.read(syncRepositoryProvider).syncNow();

    // Real path: Account → gear → Sync & storage.
    c.read(routerProvider).go(Routes.account);
    await pumpUntil(tester, () => find.byTooltip('Account settings').evaluate().isNotEmpty);
    await tester.tap(find.byTooltip('Account settings'));
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.byKey(const Key('settings-sync')));
    await tester.tap(find.byKey(const Key('settings-sync')));
    await pumpUntil(tester, () => find.text('Everything is synced').evaluate().isNotEmpty);
    expect(find.text('Last sync just now'), findsOneWidget);
    await hold(tester, 'sync-storage');

    // A change the server refuses (expense in a group this user is not in), then one more while offline.
    final expenses = c.read(expensesRepositoryProvider);
    final stranger = newId();
    final member = newId();
    Map<String, Object?> data(String d) => {
      'description': d,
      'date': '2026-11-21',
      'currency': 'INR',
      'total': 1000,
      'payers': {member: 1000},
      'shares': {member: 1000},
    };
    final refused = await expenses.save(stranger, data('Refused'));
    await c.read(syncRepositoryProvider).syncNow();
    net.online = false;
    await expenses.save(stranger, data('Waiting'), id: refused);
    await c.read(syncRepositoryProvider).syncNow();
    await pumpUntil(tester, () => find.text('1 change needs attention').evaluate().isNotEmpty);
    expect(find.text('You are no longer in this group.'), findsOneWidget);
    await hold(tester, 'sync-storage-issues');

    // Discard drops both local changes of that record; the screen is calm again once back online.
    await tester.ensureVisible(find.textContaining('Discard').first);
    await tester.tap(find.textContaining('Discard').first);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('discard-confirm')));
    net.online = true;
    await pumpUntil(tester, () => find.text('Everything is synced').evaluate().isNotEmpty);
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  });
}
