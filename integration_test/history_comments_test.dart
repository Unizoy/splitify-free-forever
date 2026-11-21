// Phase 12 (TC-13-03, TC-20-04 integ): comment offline, sync, delete + restore an expense, then read the
// real edit history. Runs against the DEV project as e2e-a:
//   flutter test integration_test/history_comments_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json [--dart-define=PIN_HOST_IP=<ip resolved on the PC>]
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/history_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/history/presentation/history_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/net_pin.dart';

/// The real server, switched off while "offline" (every call fails like a dropped network).
class SwitchableRemote implements RemoteApi {
  SwitchableRemote(this.inner);

  final RemoteApi inner;
  bool online = false;

  void _check() {
    if (!online) throw const NetworkException('offline (test)');
  }

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) {
    _check();
    return inner.applyMutations(batch);
  }

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) {
    _check();
    return inner.pullChanges(cursors: cursors, userSeq: userSeq, pageSize: pageSize);
  }

  @override
  Future<void> refreshSession() => inner.refreshSession();
}

/// The real history reads, switched off while "offline".
class SwitchableHistoryRemote implements HistoryRemote {
  SwitchableHistoryRemote(this.inner);

  final HistoryRemote inner;
  bool online = false;

  @override
  Future<List<Map<String, Object?>>> versions(String recordId, {int afterSeq = 0}) {
    if (!online) return Future.error(const NetworkException('offline (test)'));
    return inner.versions(recordId, afterSeq: afterSeq);
  }
}

Future<void> _pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(WidgetTester t, bool Function() done, Duration timeout, String what) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 200));
    if (done()) return;
  }
  fail('Timed out waiting for: $what');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // TC-13-03, TC-20-04
  testWidgets('comment offline, delete + restore online, history shows the whole story', (t) async {
    final env = Env.load();
    pinHost(Uri.parse(env.supabaseUrl).host);
    final remote = await initRemote(env);
    await remote.auth.signInWithPassword(email: 'e2e-a@splitify.test', password: env.e2ePassword);
    final uid = remote.auth.currentUser!.id;
    final client = Supabase.instance.client;
    final server = SwitchableRemote(SupabaseRemoteApi.client(client));
    final history = SwitchableHistoryRemote(SupabaseHistoryRemote.fromClient(client));
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(server),
        historyRemoteProvider.overrideWithValue(history),
        authRepositoryProvider.overrideWithValue(remote.auth),
      ],
    );
    addTearDown(container.dispose);
    final engine = container.read(syncEngineProvider);

    Future<void> syncAll() async {
      await t.runAsync(() async {
        for (var i = 0; i < 4; i++) {
          await engine.sync();
          if ((await db.select(db.outbox).get()).isEmpty) break;
        }
      });
      expect(
        await t.runAsync(() => db.select(db.outbox).get()),
        isEmpty,
        reason: 'outbox not empty: ${engine.lastError}',
      );
    }

    Future<List<Map<String, dynamic>>> activityOf(String type, String targetId) async {
      final rows = await t.runAsync(
        () => client.from('activity').select().eq('type', type).eq('target_id', targetId),
      );
      return rows!;
    }

    // a) Offline: a group, a name-only member and one expense.
    final groups = container.read(groupsRepositoryProvider);
    final members = container.read(membersRepositoryProvider);
    final expenses = container.read(expensesRepositoryProvider);
    final gid = await groups.create(
      name: 'E2E history ${DateTime.now().millisecondsSinceEpoch}',
      ownerName: 'E2E A',
      ownerUserId: uid,
    );
    final asha = await members.addNameOnly(gid, 'Asha');
    final me = (await members.watchForGroup(gid).first).firstWhere((m) => m.userId == uid).id;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final eid = await expenses.save(gid, {
      'kind': 'expense',
      'description': 'History dinner',
      'notes': null,
      'category': 'food.dining_out',
      'date': today,
      'currency': 'INR',
      'total': 1000,
      'payers': {me: 1000},
      'shares': {me: 500, asha: 500},
      'split_kind': 'equal',
      'split_values': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final router = buildRouter(initialLocation: '/expense/$eid');
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
        ),
      ),
    );
    await _pumpFor(t, const Duration(seconds: 2));

    const body = 'Did we include the tip?';
    await t.enterText(find.byKey(const Key('comment-field')), body);
    await t.pump();
    await t.tap(find.byKey(const Key('comment-send')));
    await _pumpFor(t, const Duration(seconds: 1));

    expect(find.text(body, skipOffstage: false), findsWidgets);
    final localComments = await (db.select(
      db.comments,
    )..where((c) => c.targetId.equals(eid))).get();
    expect(localComments, hasLength(1));
    final cid = localComments.single.id;
    expect(localComments.single.body, body);
    expect(localComments.single.syncState, isNot(SyncState.synced));

    // b) Online: sync; the server has the comment and its activity row.
    server.online = true;
    history.online = true;
    await syncAll();
    final serverComment = await t.runAsync(
      () => client.from('comments').select().eq('id', cid).single(),
    );
    expect(serverComment!['body'], body);
    expect(serverComment['created_by'], uid);
    expect(serverComment['target_id'], eid);
    expect(await activityOf('comment_added', cid), isNotEmpty);
    final syncedComment = await (db.select(
      db.comments,
    )..where((c) => c.id.equals(cid))).getSingle();
    expect(syncedComment.syncState, SyncState.synced);

    // c) Delete the expense and sync.
    await expenses.delete(eid, gid);
    await _pumpFor(t, const Duration(milliseconds: 500));
    await syncAll();
    var serverExpense = await t.runAsync(
      () => client.from('expenses').select().eq('id', eid).single(),
    );
    expect(serverExpense!['deleted_at'], isNotNull);
    expect(await activityOf('expense_deleted', eid), isNotEmpty);

    // d) Deleted items screen: restore it.
    router.go(HistoryRoutes.deleted(gid));
    await _pumpFor(t, const Duration(seconds: 2));
    final restore = find.byKey(Key('restore-$eid'));
    expect(restore, findsOneWidget);
    await t.tap(restore);
    await _pumpFor(t, const Duration(seconds: 1));
    await syncAll();
    serverExpense = await t.runAsync(() => client.from('expenses').select().eq('id', eid).single());
    expect(serverExpense!['deleted_at'], isNull);
    expect(await activityOf('expense_restored', eid), isNotEmpty);
    final localExpense = await (db.select(db.expenses)..where((e) => e.id.equals(eid))).getSingle();
    expect(localExpense.deletedAt, isNull);

    // e) The real edit history tells the whole story.
    router.go(HistoryRoutes.expense(eid));
    await _pumpFor(t, const Duration(seconds: 1));
    final headlines = ['You added this', 'You deleted this', 'You restored this'];
    await _pumpUntil(
      t,
      () => headlines.every((h) => find.text(h, skipOffstage: false).evaluate().isNotEmpty),
      const Duration(seconds: 15),
      'history headlines $headlines',
    );
    for (final h in headlines) {
      expect(find.text(h, skipOffstage: false), findsWidgets);
    }

    // f) Tidy up the dev project: soft-delete the test group (creator only, restorable).
    await groups.delete(gid, gid);
    await t.runAsync(engine.sync);
  });
}
