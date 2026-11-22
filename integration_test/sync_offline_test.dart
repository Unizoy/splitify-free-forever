// Phase 06 T7 on the dev project: user A (the app's sync engine, real Supabase RPCs) creates a group and an
// expense while offline, reconnects and syncs; harness user B joins and sees both through `pull_changes`. Then
// A edits offline, B edits later online: B's edit wins, A's version stays in `record_versions` (TC-27-13 core).
// "Offline" = the app's network door refuses every call (S-211); airplane mode is phase 15's TC-27-11.
// Run: flutter test integration_test/sync_offline_test.dart -d emulator-5554 \
//        --dart-define-from-file=secrets/env.dev.json
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// The app's [RemoteApi] with an on/off switch: off = every call fails like having no network.
class _NetworkSwitch implements RemoteApi {
  _NetworkSwitch(this.real);

  final RemoteApi real;
  bool online = true;
  int refused = 0;

  Future<T> _call<T>(Future<T> Function() f) {
    if (online) return f();
    refused++;
    return Future.error(const NetworkException('offline'));
  }

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

  testWidgets('T7 offline group + expense reach user B after reconnect; last save wins', (
    tester,
  ) async {
    final env = devEnv();
    final remote = await initRemote(env);
    await remote.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final a = Supabase.instance.client;
    final net = _NetworkSwitch(remote.api);
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(net),
      ],
    );
    final sync = c.read(syncRepositoryProvider);
    final engine = c.read(syncEngineProvider);
    final lost = <int>[];
    final lostSub = engine.superseded.listen(lost.add);
    HarnessUser? b;
    String? gid;
    try {
      await sync.syncNow(); // measures the server clock offset
      expect((await sync.watchStatus().first).phase, SyncPhase.idle);

      // A, offline: new group + expense go to Drift and the outbox only.
      net.online = false;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final groupName = 'T7 offline $stamp';
      gid = await c.read(groupsRepositoryProvider).create(name: groupName, ownerName: 'E2E A');
      final owner = (await (db.select(
        db.groupMembers,
      )..where((m) => m.groupId.equals(gid!))).getSingle()).id;
      Map<String, Object?> expense(String description) => {
        'description': description,
        'date': '2026-11-21',
        'currency': 'INR',
        'total': 50000,
        'payers': {owner: 50000},
        'shares': {owner: 50000},
      };
      final eid = await c.read(expensesRepositoryProvider).save(gid, expense('Offline dinner'));
      await sync.syncNow();
      var status = await sync.watchStatus().first;
      expect(status.phase, SyncPhase.offline);
      expect(status.waiting, 2);
      expect(net.refused, greaterThan(0));
      expect(await sync.watchGroupUnsynced(gid).first, isTrue);

      // Reconnect: pushed in order, pulled back, markers clear.
      net.online = true;
      await sync.syncNow();
      status = await sync.watchStatus().first;
      expect((status.phase, status.waiting, status.failed), (SyncPhase.idle, 0, 0));
      expect(await sync.watchGroupUnsynced(gid).first, isFalse);

      // B joins with the invite code and sees the group and the expense through the RPCs.
      b = await HarnessUser.signIn(env, 'e2e-b');
      final code =
          (await a.from('groups').select('invite_code').eq('id', gid).single())['invite_code']!
              as String;
      expect((await b.rpc('join_group', {'code': code}))['status'], 'joined');
      // B (an e2e user since phase 06) belongs to many test groups by now: page like the sync engine does,
      // following next_cursors / user_seq until has_more is false (phase 19).
      final rows = <String, List<Object?>>{};
      Object? cursors = {gid: 0};
      Object? userSeq = 0;
      for (var i = 0; i < 50; i++) {
        final page = await b.rpc('pull_changes', {
          'cursors': cursors,
          'since_user_seq': userSeq,
          'page_size': 500,
        });
        (page['rows']! as Map).forEach(
          (k, v) => rows.putIfAbsent(k as String, () => []).addAll((v as List?) ?? const []),
        );
        cursors = {...(cursors! as Map), ...((page['next_cursors'] as Map?) ?? const {})};
        userSeq = page['user_seq'];
        if (page['has_more'] != true) break;
      }
      List<Map<String, Object?>> table(String t) => [
        for (final r in rows[t] ?? const []) (r! as Map).cast<String, Object?>(),
      ];
      expect(table('groups').where((g) => g['id'] == gid).single['name'], groupName);
      final seen = table('expenses').where((e) => e['id'] == eid).single;
      expect(
        (seen['description'], seen['total'], seen['currency']),
        ('Offline dinner', 50000, 'INR'),
      );
      expect(seen['created_by'], a.auth.currentUser!.id);

      // A edits offline first; B edits the same expense later, online; A reconnects.
      net.online = false;
      await c.read(expensesRepositoryProvider).save(gid, expense('A offline edit'), id: eid);
      await Future<void>.delayed(const Duration(seconds: 2));
      final bTime = (await engine.serverClock.now()).toIso8601String();
      final applied = await b.rpc('apply_mutations', {
        'batch': [
          {
            'mutation_id': newId(),
            'entity': 'expense',
            'op': 'upsert',
            'id': eid,
            'group_id': gid,
            'base_seq': null,
            'client_updated_at': bTime,
            'source': 'app',
            'data': {'description': 'B later edit'},
          },
        ],
      });
      expect(((applied['results']! as List).single! as Map)['status'], 'applied');
      net.online = true;
      await sync.syncNow();
      await tester.pump();
      expect(lost, [1], reason: "A's older edit is superseded");
      final local = await (db.select(db.expenses)..where((e) => e.id.equals(eid))).getSingle();
      expect((local.description, local.syncState), ('B later edit', SyncState.synced));

      // Both versions are kept (rule 6): B's update and A's losing edit.
      final versions = await b.client
          .from('record_versions')
          .select('op, snapshot')
          .eq('record_id', eid)
          .order('id');
      final byOp = <String, List<String>>{};
      for (final v in versions) {
        byOp
            .putIfAbsent(v['op']! as String, () => [])
            .add((v['snapshot']! as Map)['description']! as String);
      }
      expect(byOp['insert'], ['Offline dinner']);
      expect(byOp['update'], contains('B later edit'));
      expect(byOp['conflict_lost'], ['A offline edit']);
    } finally {
      // Leave dev tidy: B leaves, A soft-deletes the group.
      try {
        if (b != null && gid != null)
          await b.client.rpc<Object?>('leave_group', params: {'group_id': gid});
        if (gid != null) {
          await c.read(groupsRepositoryProvider).delete(gid, gid);
          net.online = true;
          await sync.syncNow();
        }
      } on Exception catch (e) {
        debugPrintCleanup(e);
      }
      await lostSub.cancel();
      await b?.dispose();
      c.dispose();
      await db.close();
      await a.auth.signOut(scope: SignOutScope.local);
    }
  });
}

void debugPrintCleanup(Object e) => printOnFailure('cleanup failed: $e');
