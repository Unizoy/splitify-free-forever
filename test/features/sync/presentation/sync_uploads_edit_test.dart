// Phase 15: waiting on Sync & storage (S-113) and "Edit" on a refused change.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/sync/presentation/sync_storage_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/fakes.dart';

Future<(FakeSyncRepository, GoRouter)> _pump(
  WidgetTester tester, {
  List<SyncIssue> issues = const [],
  List<SyncUpload> uploads = const [],
  double scale = 1,
}) async {
  final repo = FakeSyncRepository(
    status: SyncStatus(phase: SyncPhase.idle, failed: issues.length),
    issues: issues,
    uploads: uploads,
  );
  tester.view.physicalSize = const Size(412 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SyncStorageScreen()),
      GoRoute(
        path: '/expense/:id',
        builder: (_, s) => Scaffold(body: Text('expense ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/groups/:id/settings',
        builder: (_, s) => Scaffold(body: Text('settings ${s.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 21, 12))),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: const Size(412, 1400), textScaler: TextScaler.linear(scale)),
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
  return (repo, router);
}

const _waiting = SyncUpload(id: 'u-wait', bucket: 'receipts', recordId: 'e1', attempts: 0);
const _retrying = SyncUpload(id: 'u-try', bucket: 'group-covers', recordId: 'g1', attempts: 3);
const _skipped = SyncUpload(id: 'u-skip', bucket: 'receipts', recordId: 'e2', attempts: 8);

void main() {
  // TC-OFF-UPLOADS: waiting and retrying photos have no Retry button.
  testWidgets('uploads card: a row per photo with its state, no Retry before it is skipped', (
    tester,
  ) async {
    await _pump(tester, uploads: [_retrying, _waiting]);
    expect(find.byKey(const Key('sync-uploads-card')), findsOneWidget);
    expect(find.text('PHOTOS\u00A0· 2 WAITING'), findsOneWidget);
    expect(find.text('Upload failed 3 times, trying again'), findsOneWidget);
    expect(find.text('Waiting to upload'), findsOneWidget);
    expect(find.text('Group cover'), findsOneWidget);
    expect(find.text('Receipt photo'), findsOneWidget);
    expect(find.byKey(const Key('sync-upload-u-wait')), findsOneWidget);
    expect(find.byKey(const Key('sync-upload-retry-u-wait')), findsNothing);
    expect(find.byKey(const Key('sync-upload-retry-u-try')), findsNothing);
  });

  // TC-OFF-UPLOADS: Retry only for a skipped photo. At text 1.0 the Retry sits in a Row next to the text.
  testWidgets('uploads card: skipped photo has Retry and it retries that photo', (tester) async {
    final (repo, _) = await _pump(tester, uploads: [_skipped, _waiting]);
    expect(find.text('Upload stopped after 8 tries'), findsOneWidget);
    expect(find.byKey(const Key('sync-upload-retry-u-wait')), findsNothing);
    await tester.tap(find.byKey(const Key('sync-upload-retry-u-skip')));
    await tester.pump();
    expect(repo.calls, ['retryUpload:u-skip']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no waiting: no uploads card', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('sync-uploads-card')), findsNothing);
  });

  testWidgets('large text: the skipped row stacks Retry under the text', (tester) async {
    await _pump(tester, uploads: [_skipped], scale: 2);
    final title = tester.getTopLeft(find.text('Receipt photo'));
    final retry = tester.getTopLeft(find.byKey(const Key('sync-upload-retry-u-skip')));
    expect(retry.dy, greaterThan(title.dy));
    expect(tester.takeException(), isNull);
  });

  // TC-OFF-EDIT: Edit opens the refused record; a refused delete has none.
  testWidgets('Edit is there for an expense upsert, not for a delete, and opens the expense', (
    tester,
  ) async {
    final upsert = sampleIssue(seq: 7);
    final delete = SyncIssue(
      seq: 8,
      entity: SyncEntity.expense,
      op: SyncOp.delete,
      recordId: 'e9',
      groupId: 'g1',
      code: 'X',
      attempts: 1,
      createdAt: null,
    );
    final (_, router) = await _pump(tester, issues: [upsert, delete]);
    expect(find.byKey(const Key('sync-edit-7')), findsOneWidget);
    expect(find.byKey(const Key('sync-edit-8')), findsNothing);
    expect(find.byKey(const Key('sync-retry-8')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sync-edit-7')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.state.uri.path, '/expense/${upsert.recordId}');
    expect(find.text('expense ${upsert.recordId}'), findsOneWidget);
  });

  testWidgets('Edit on a member change opens the group settings', (tester) async {
    final (_, router) = await _pump(
      tester,
      issues: [sampleIssue(seq: 3, entity: SyncEntity.member)],
    );
    await tester.tap(find.byKey(const Key('sync-edit-3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.state.uri.path, '/groups/01900000-0000-7000-8000-000000000001/settings');
  });

  testWidgets('a comment issue without a target has no Edit', (tester) async {
    await _pump(tester, issues: [sampleIssue(seq: 4, entity: SyncEntity.comment)]);
    expect(find.byKey(const Key('sync-edit-4')), findsNothing);
  });
}
