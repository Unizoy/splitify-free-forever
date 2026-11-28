// R4 device scenarios against the DEV project (prepared in round 4, run in round 5 with the emulator lock):
//   R4-DEV-01 a phone clock set back a day: A's losing edit (superseded) shows B's newer server copy (S-460);
//   R4-DEV-02 a refused edit (group archived for a moment) retried after B's newer edit shows B's (S-460);
//   R4-DEV-03 B's 100-mutation batch commits while A pushes and pulls in a loop: A gets every row (0031, S-467);
//   R4-DEV-04 an answer lost after the server committed: the retry is a duplicate, one row and one activity.
// A = the app's real sync engine as e2e-a; B = e2e-b through the multi-user harness (its own client).
// Run (holding the emulator lock, .qa build rules of the agent brief):
//   flutter test integration_test/r4_robustness_test.dart -d emulator-5554 \
//     --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=<ip>
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/remote/supabase_client.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';

/// Real time plus [skew] (the owner changed the phone's date).
class _SkewClock implements Clock {
  Duration skew = Duration.zero;

  @override
  DateTime now() => DateTime.now().toUtc().add(skew);
}

/// The app's [RemoteApi] that can lose the next answer after the server committed it.
class _LossyRemote implements RemoteApi {
  _LossyRemote(this.real);

  final RemoteApi real;
  bool loseNextAnswer = false;

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) async {
    final r = await real.applyMutations(batch);
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw const NetworkException('answer lost');
    }
    return r;
  }

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) => real.pullChanges(cursors: cursors, userSeq: userSeq, pageSize: pageSize);

  @override
  Future<void> refreshSession() => real.refreshSession();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('R4-DEV-01..04 conflicts, refused retries, commit-order race and lost answers', (
    tester,
  ) async {
    final env = devEnv();
    final remote = await initRemote(env);
    await remote.auth.signInWithPassword(email: e2eEmail('e2e-a'), password: env.e2ePassword);
    final a = Supabase.instance.client;
    final net = _LossyRemote(remote.api);
    final clock = _SkewClock();
    final db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(net),
        clockProvider.overrideWithValue(clock),
      ],
    );
    final sync = c.read(syncRepositoryProvider);
    final expenses = c.read(expensesRepositoryProvider);
    HarnessUser? b;
    String? gid;
    try {
      await sync.syncNow();
      gid = await c
          .read(groupsRepositoryProvider)
          .create(name: 'R4 ${DateTime.now().millisecondsSinceEpoch}', ownerName: 'E2E A');
      await sync.syncNow();
      final owner = (await (db.select(
        db.groupMembers,
      )..where((m) => m.groupId.equals(gid!))).getSingle()).id;
      b = await HarnessUser.signIn(env, 'e2e-b');
      final code =
          (await a.from('groups').select('invite_code').eq('id', gid).single())['invite_code']!
              as String;
      expect((await b.rpc('join_group', {'code': code}))['status'], 'joined');
      final bMember =
          (await b.client
                  .from('group_members')
                  .select('id')
                  .eq('group_id', gid)
                  .eq('user_id', b.id)
                  .single())['id']!
              as String;
      await sync.syncNow();

      Map<String, Object?> body(String d, {int total = 30000}) => {
        'description': d,
        'date': '2026-11-28',
        'currency': 'INR',
        'total': total,
        'payers': {owner: total},
        'shares': {owner: total - total ~/ 2, bMember: total ~/ 2},
      };
      Future<String> bWrites(String entity, String id, Map<String, Object?> data) async {
        final r = await b!.rpc('apply_mutations', {
          'batch': [
            {
              'mutation_id': newId(),
              'entity': entity,
              'op': 'upsert',
              'id': id,
              'group_id': gid,
              'client_updated_at': DateTime.now().toUtc().toIso8601String(),
              'source': 'app',
              'data': data,
            },
          ],
        });
        return ((r['results']! as List).single! as Map)['status']! as String;
      }

      Future<String> description(String id) async =>
          (await (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingle()).description;

      // R4-DEV-01: A holds B's newer edit, then edits with the phone a day behind.
      final x = await expenses.save(gid, body('Dinner'));
      await sync.syncNow();
      expect(await bWrites('expense', x, {'description': 'B newer'}), 'applied');
      await sync.syncNow();
      expect(await description(x), 'B newer');
      clock.skew = const Duration(days: -1);
      await expenses.save(gid, body('A with the wrong date'), id: x);
      await sync.syncNow();
      clock.skew = Duration.zero;
      expect(await description(x), 'B newer', reason: 'R4-DEV-01');
      expect((await sync.watchStatus().first).waiting, 0);

      // R4-DEV-02: refused while B archived the group; B un-archives and edits; A retries.
      final archived = DateTime.now().toUtc().toIso8601String();
      expect(await bWrites('group', gid, {'archived_at': archived}), 'applied');
      await expenses.save(gid, body('A while archived'), id: x);
      await sync.syncNow();
      final failed = (await db.select(db.outbox).get()).single;
      expect((failed.status, failed.lastError), (OutboxStatus.failed, 'GROUP_ARCHIVED'));
      expect(await bWrites('group', gid, {'archived_at': null}), 'applied');
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await bWrites('expense', x, {'description': 'B after archive'}), 'applied');
      await sync.syncNow(); // pulls B's edit; the row waits for A's decision
      await sync.retry(failed.seq);
      expect(await description(x), 'B after archive', reason: 'R4-DEV-02');

      // R4-DEV-03: B's big batch is still committing while A pushes one edit and pulls, again and again.
      final ids = [for (var i = 0; i < 100; i++) newId()];
      final big = b.rpc('apply_mutations', {
        'batch': [
          for (final (i, id) in ids.indexed)
            {
              'mutation_id': newId(),
              'entity': 'expense',
              'op': 'upsert',
              'id': id,
              'group_id': gid,
              'client_updated_at': DateTime.now().toUtc().toIso8601String(),
              'source': 'app',
              'data': body('B batch $i', total: 100 + i),
            },
        ],
      });
      var done = false;
      final waiting = big.whenComplete(() => done = true);
      var rounds = 0;
      while (!done && rounds < 40) {
        await expenses.save(gid, body('A during batch $rounds'));
        await sync.syncNow();
        rounds++;
      }
      await waiting;
      await sync.syncNow();
      final have = {
        for (final e in await (db.select(db.expenses)..where((e) => e.groupId.equals(gid!))).get())
          e.id,
      };
      expect(
        ids.where((id) => !have.contains(id)),
        isEmpty,
        reason: 'R4-DEV-03 after $rounds rounds',
      );

      // R4-DEV-04: the server commits, the answer is lost; the retry comes back as a duplicate.
      net.loseNextAnswer = true;
      final y = await expenses.save(gid, body('Lost answer'));
      await sync.syncNow();
      expect((await sync.watchStatus().first).phase, SyncPhase.offline);
      await sync.syncNow();
      await tester.pump();
      final row = await (db.select(db.expenses)..where((e) => e.id.equals(y))).getSingle();
      expect(row.syncState, SyncState.synced);
      final added = await (db.select(
        db.activity,
      )..where((r) => r.targetId.equals(y) & r.type.equals('expense_added'))).get();
      expect(added, hasLength(1), reason: 'R4-DEV-04 one activity row');
    } finally {
      try {
        if (b != null && gid != null) {
          await b.client.rpc<Object?>('leave_group', params: {'group_id': gid});
        }
        if (gid != null) {
          await c.read(groupsRepositoryProvider).delete(gid, gid);
          await sync.syncNow();
        }
      } on Exception catch (e) {
        printOnFailure('cleanup failed: $e');
      }
      await b?.dispose();
      c.dispose();
      await db.close();
      await a.auth.signOut(scope: SignOutScope.local);
    }
  });
}
