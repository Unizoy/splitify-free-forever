// Phase 06 T5: "Sync & storage" (04 §9) and the sync markers wired to the providers.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/sync/application/debug_log.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/sync_marker.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/fakes.dart';

class _Shared {
  final shared = <(String, String)>[];
}

Future<(FakeSyncRepository, GoRouter, _Shared)> _pump(
  WidgetTester tester,
  String location, {
  SyncStatus status = const SyncStatus(phase: SyncPhase.idle),
  List<SyncIssue> issues = const [],
  bool unsynced = false,
  double scale = 1,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = FakeSyncRepository(status: status, issues: issues, unsynced: unsynced);
  final share = _Shared();
  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(user: const AuthUser(id: 'u1')),
        ),
        profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
        syncRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 21, 12))),
        debugLogLinesProvider.overrideWithValue(() => ['line 1']),
        debugLogSharerProvider.overrideWithValue((s, t) async => share.shared.add((s, t))),
        ...emptyBalanceOverrides(),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: const Size(412, 915), textScaler: TextScaler.linear(scale)),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return (repo, router, share);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('all synced: headline, last sync, counts, Sync now runs a sync', (tester) async {
    final (repo, _, _) = await _pump(
      tester,
      Routes.syncStorage,
      status: SyncStatus(phase: SyncPhase.idle, lastSync: DateTime.utc(2026, 11, 21, 11, 55)),
    );
    expect(find.text('Sync & storage'), findsOneWidget);
    expect(find.text('Everything is synced'), findsOneWidget);
    expect(find.text('Last sync 5 min ago'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('Need attention'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsNothing);

    repo.syncGate = Completer<void>();
    await tester.tap(find.byKey(const Key('sync-now')));
    await tester.pump();
    expect(repo.calls, ['sync']);
    // Busy while running: a second tap does nothing.
    await tester.tap(find.byKey(const Key('sync-now')));
    await tester.pump();
    expect(repo.calls, ['sync']);
    repo.syncGate!.complete();
    await tester.pump();
  });

  testWidgets('waiting offline and never synced', (tester) async {
    await _pump(
      tester,
      Routes.syncStorage,
      status: const SyncStatus(phase: SyncPhase.offline, waiting: 3, lastError: 'offline'),
    );
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.textContaining('sync when you are back online'), findsOneWidget);
    expect(find.text('Last sync never'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('refused changes: retry, discard after confirm, cancel keeps it', (tester) async {
    final (repo, _, _) = await _pump(
      tester,
      Routes.syncStorage,
      status: const SyncStatus(phase: SyncPhase.idle, failed: 2),
      issues: [
        sampleIssue(),
        sampleIssue(seq: 8, entity: SyncEntity.payment, code: 'X'),
      ],
    );
    expect(find.text('2 changes need attention'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(find.text('Expense\u00A0· Edit'), findsOneWidget);
    expect(find.text('Payment\u00A0· Edit'), findsOneWidget);
    expect(find.text('You are no longer in this group.'), findsOneWidget);
    expect(find.text('Tried 2 times'), findsWidgets);
    expect(find.textContaining('NOT_MEMBER'), findsNothing, reason: 'no developer codes on screen');

    await tester.tap(find.byKey(const Key('sync-retry-7')));
    await tester.pump();
    expect(repo.calls, ['retry:7']);

    await tester.scrollUntilVisible(find.byKey(const Key('export-debug-log')), 200);
    await tester.tap(find.byKey(const Key('sync-discard-8')));
    await _settle(tester);
    expect(find.text('Discard this change?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(repo.calls, ['retry:7']);

    await tester.tap(find.byKey(const Key('sync-discard-8')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('discard-confirm')));
    await _settle(tester);
    expect(repo.calls, ['retry:7', 'discard:8']);
  });

  testWidgets('large text stacks the issue actions', (tester) async {
    await _pump(
      tester,
      Routes.syncStorage,
      status: const SyncStatus(phase: SyncPhase.idle, failed: 1),
      issues: [sampleIssue()],
      scale: 2,
    );
    await tester.scrollUntilVisible(find.byKey(const Key('sync-discard-7')), 200);
    final retry = tester.getTopLeft(find.byKey(const Key('sync-retry-7')));
    final discard = tester.getTopLeft(find.byKey(const Key('sync-discard-7')));
    expect(discard.dy, greaterThan(retry.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('export debug log shares the report', (tester) async {
    final (_, _, share) = await _pump(
      tester,
      Routes.syncStorage,
      status: const SyncStatus(phase: SyncPhase.idle, failed: 1),
      issues: [sampleIssue()],
    );
    await tester.scrollUntilVisible(find.byKey(const Key('export-debug-log')), 200);
    await tester.ensureVisible(find.byKey(const Key('export-debug-log')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('export-debug-log')));
    await tester.pump();
    final (subject, text) = share.shared.single;
    expect(subject, 'Splitify debug log');
    expect(text, contains('issue: seq=7'));
    expect(text, contains('line 1'));
  });

  testWidgets('settings row shows the state and opens the screen', (tester) async {
    final (_, router, _) = await _pump(
      tester,
      Routes.account,
      status: const SyncStatus(phase: SyncPhase.idle, waiting: 2),
    );
    await tester.tap(find.byTooltip('Account settings'));
    await _settle(tester);
    expect(find.text('2 waiting'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('settings-sync')));
    await tester.tap(find.byKey(const Key('settings-sync')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(router.state.uri.path, Routes.syncStorage);
    expect(find.text('Everything is synced'), findsNothing);
    expect(find.text('2 changes waiting to sync'), findsOneWidget);
  });

  testWidgets('account shows the marker only while something is not synced', (tester) async {
    await _pump(tester, Routes.account);
    expect(find.byType(SyncMarker), findsNothing);
    await _pump(tester, Routes.account, unsynced: true);
    expect(find.byKey(const Key('account-sync-marker')), findsOneWidget);
  });
}
