// R4-SYNC-01…14: sync engine stress over a modelled server (test/data/sync/sim/) and 2–3 phones with their
// own SQLite files: conflicts, clock skew, lost answers, duplicate deliveries, out-of-order acks, app kills
// mid-batch and mid-pull, pagination, nudge storms, access changes, 50-member groups, and a seeded fuzz.
// After everything settles: no lost or duplicated rows, outbox order kept, phone = server (rows and
// balances), per-group balances add up to the overall balance (rule 3), currencies never mixed (rule 4).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/sync/sync_types.dart';

import 'sim/sim_phone.dart';
import 'sim/sim_server.dart';
import 'sim/sim_world.dart';

void main() {
  late SimWorld w;

  tearDown(() => w.dispose());

  Future<String> addExpense(SimPhone p, String group, {String currency = 'INR'}) async {
    final body = (await p.expenseBody(group, currency: currency))!;
    final id = await p.expenses.save(group, body);
    await p.noteQueued();
    return id;
  }

  Future<void> edit(SimPhone p, String group, String id, String description) async {
    final body = (await p.expenseBody(group, currency: 'INR'))!..['description'] = description;
    await p.expenses.save(group, body, id: id);
    await p.noteQueued();
  }

  Future<String> description(SimPhone p, String id) async =>
      (await (p.db.select(p.db.expenses)..where((e) => e.id.equals(id))).getSingle()).description;

  test('R4-SYNC-01 a losing edit made with a clock set back a day shows the server copy', () async {
    w = await SimWorld.create(phones: 2);
    final x = await addExpense(w.a, g1);
    await w.settle();
    w.server.clock.advance(const Duration(minutes: 1));
    await edit(w.b, g1, x, 'B newer');
    await w.b.engine.sync();
    await w.a.engine.sync(); // A now holds B's version and measured its offset
    expect(await description(w.a, x), 'B newer');

    w.a.clock.skew = const Duration(days: -1); // the owner changes the phone's date
    w.server.clock.advance(const Duration(minutes: 1));
    await edit(w.a, g1, x, 'A with wrong clock');
    await w.a.engine.sync();
    expect(w.a.supersededShown, 1);
    expect(await description(w.a, x), 'B newer', reason: 'the newer server copy must come back');
    await w.settle();
    await w.expectConverged();
  });

  test(
    'R4-SYNC-02 retrying a refused edit that a newer one beat meanwhile shows the newer one',
    () async {
      w = await SimWorld.create(phones: 2);
      final x = await addExpense(w.a, g1);
      await w.settle();
      w.server.clock.advance(const Duration(minutes: 1));
      await edit(w.a, g1, x, 'A first');
      w.a.remote.applyFaults.add(SimFault.rejectAll); // e.g. the group was archived for a moment
      await w.a.engine.sync();
      final failed = (await w.a.db.select(w.a.db.outbox).get()).single;
      expect(failed.status, OutboxStatus.failed);

      w.server.clock.advance(const Duration(minutes: 1));
      await edit(w.b, g1, x, 'B later');
      await w.b.engine.sync();
      await w.a.engine.sync(); // pulls B's version; skipped locally (A's edit waits in Sync issues)
      expect(await description(w.a, x), 'A first');

      await w.a.engine.queue.retry(failed.seq);
      await w.a.engine.sync(); // superseded: B's edit is newer
      expect(await description(w.a, x), 'B later');
      await w.settle();
      await w.expectConverged();
    },
  );

  test('R4-SYNC-03 rows committed out of seq order are never skipped (0031 horizon)', () async {
    Future<Set<String>> run({required bool horizon}) async {
      final world = await SimWorld.create(phones: 2, horizon: horizon);
      try {
        final slow = await addExpense(world.a, g1);
        final item = (await world.a.db.select(world.a.db.outbox).get()).single;
        // A's batch is still running on the server (seq taken, not committed)…
        final tx = world.server.begin()..apply(world.a.engine.queue.toWire(item), uA);
        // …while B saves and pulls.
        await addExpense(world.b, g1);
        await world.b.engine.sync();
        tx.commit();
        await world.b.engine.sync();
        final onB = {for (final e in await world.b.db.select(world.b.db.expenses).get()) e.id};
        return {slow}.difference(onB);
      } finally {
        await world.dispose();
      }
    }

    w = await SimWorld.create(phones: 2);
    expect(await run(horizon: false), isNotEmpty, reason: 'the 0029 pull_changes loses the row');
    expect(await run(horizon: true), isEmpty);
  });

  test('R4-SYNC-04 a lost answer after commit is retried as duplicates: nothing twice', () async {
    w = await SimWorld.create(phones: 2);
    for (var i = 0; i < 4; i++) {
      await addExpense(w.a, g1);
    }
    w.a.remote.applyFaults.addAll([SimFault.dropAfter, SimFault.duplicate]);
    await w.a.engine.sync();
    expect(w.a.engine.phase, SyncPhase.offline);
    await w.a.engine.sync();
    await w.settle();
    await w.expectConverged();
    expect(w.server.live('activity', g1).where((r) => r['type'] == 'expense_insert'), hasLength(4));
  });

  for (final fault in [SimFault.hangAfter, SimFault.hangBefore]) {
    test(
      'R4-SYNC-05 app killed mid-batch (${fault.name}), database reopened: order kept, nothing lost',
      () async {
        w = await SimWorld.create(phones: 2, batchSize: 3);
        final g = await w.a.groups.create(name: 'Trip', ownerName: 'A', ownerUserId: uA);
        await w.a.noteQueued();
        for (var i = 0; i < 4; i++) {
          await addExpense(w.a, g1);
          await addExpense(w.a, g);
        }
        w.a.remote.applyFaults.addAll([SimFault.none, fault]);
        final running = w.a.engine.sync();
        await Future.any([w.a.remote.hung.future, running]);
        expect(w.a.remote.hung.isCompleted, isTrue);
        await w.a.kill();
        expect(
          (await w.a.db.select(w.a.db.outbox).get()).where(
            (o) => o.status == OutboxStatus.inFlight,
          ),
          isNotEmpty,
        );
        await w.settle();
        await w.expectConverged();
      },
    );
  }

  test(
    'R4-SYNC-06 app killed mid-pull: the page is pulled again, cursors never ran ahead',
    () async {
      w = await SimWorld.create(phones: 2, pageSize: 2);
      for (var i = 0; i < 6; i++) {
        await addExpense(w.b, g1);
      }
      await w.b.engine.sync();
      final cursor = (await w.a.engine.dao.groupCursors())[g1];
      w.a.remote.pullFaults.add(SimFault.hangAfter);
      final running = w.a.engine.sync();
      await Future.any([w.a.remote.hung.future, running]);
      await w.a.kill();
      expect((await w.a.engine.dao.groupCursors())[g1], cursor);
      await w.settle();
      await w.expectConverged();
    },
  );

  test('R4-SYNC-07 out-of-order and partial acks keep the queue order and apply once', () async {
    w = await SimWorld.create(phones: 2, batchSize: 4);
    for (var i = 0; i < 10; i++) {
      await addExpense(w.a, i.isEven ? g1 : g2);
    }
    w.a.remote.applyFaults.addAll([
      SimFault.shuffle,
      SimFault.partial,
      SimFault.partial,
      SimFault.shuffle,
    ]);
    await w.a.engine.sync();
    await w.settle();
    await w.expectConverged();
  });

  test('R4-SYNC-08 pull pagination (pages of 1…7) across groups converges', () async {
    for (final size in [1, 2, 3, 7]) {
      w = await SimWorld.create(pageSize: size, seed: size);
      for (var i = 0; i < 12; i++) {
        final p = w.phones[i % 3];
        await p.randomWrite();
        await p.noteQueued();
      }
      await w.settle();
      await w.expectConverged();
      await w.dispose();
    }
    w = await SimWorld.create(phones: 2);
  });

  test(
    'R4-SYNC-09 Realtime nudge storm: one push in flight per phone, everything converges',
    () async {
      w = await SimWorld.create(batchSize: 2, pageSize: 3);
      for (final p in w.phones) {
        p.remote.latency = 3;
      }
      for (var round = 0; round < 6; round++) {
        final all = <Future<void>>[];
        for (final p in w.phones) {
          for (var i = 0; i < 10; i++) {
            all.add(p.engine.sync());
          }
          all.add(() async {
            await p.randomWrite();
            await p.noteQueued();
          }());
        }
        await Future.wait(all);
      }
      await w.settle();
      await w.expectConverged();
    },
  );

  test('R4-SYNC-10 removed from a group with edits waiting: the group and its queue go', () async {
    w = await SimWorld.create();
    await addExpense(w.c, g1);
    await addExpense(w.c, g3);
    final row = {...w.server.rows['group_members']![memberId(g1, uC)]!, 'status': 'removed'};
    w.server.write('group_members', row);
    await w.c.engine.sync();
    expect(await w.c.db.select(w.c.db.groups).get(), hasLength(1));
    expect(await w.c.db.select(w.c.db.outbox).get(), isEmpty);
    // The g1 expense never reached the server; drop it from what C expects.
    w.c.queued.removeWhere((id) => !w.server.mutationLog.containsKey(id));
    await w.settle();
    await w.expectConverged();
  });

  test('R4-SYNC-11 a group made offline is pulled whole by someone who joins it', () async {
    w = await SimWorld.create(phones: 2);
    w.a.remote.online = false;
    final g = await w.a.groups.create(name: 'Offline trip', ownerName: 'A', ownerUserId: uA);
    await w.a.noteQueued();
    await w.a.members.addNameOnly(g, 'Ravi');
    await w.a.noteQueued();
    for (var i = 0; i < 3; i++) {
      await addExpense(w.a, g, currency: i == 0 ? 'JPY' : 'INR');
    }
    await w.a.engine.sync();
    expect(w.a.engine.phase, SyncPhase.offline);
    w.a.remote.online = true;
    await w.a.engine.sync();
    // B joins with the invite (join_group RPC): a linked member at the next position.
    w.server.write('group_members', {
      'id': memberId(g, uB).replaceRange(24, 26, '77'),
      'group_id': g,
      'user_id': uB,
      'display_name': 'B',
      'position': 2,
      'role': 'member',
      'status': 'active',
      'created_at': w.server.clock.now().toIso8601String(),
      'client_updated_at': w.server.clock.now().toIso8601String(),
      'deleted_at': null,
    });
    await w.settle();
    await w.expectConverged();
    expect(await w.b.expenses.watchForGroup(g).first, hasLength(3));
  });

  test('R4-SYNC-12 50-member group, every currency kind, three phones', () async {
    w = await SimWorld.create(bigGroup: 46, pageSize: 25);
    for (var i = 0; i < 30; i++) {
      final p = w.phones[i % 3];
      await addExpense(p, g1, currency: SimPhone.currencies[i % SimPhone.currencies.length]);
      if (i % 5 == 0) await p.batchSettle();
      await p.noteQueued();
    }
    await w.settle();
    await w.expectConverged();
    expect((await w.a.activeMembers(g1)).length, 50);
  });

  test('R4-SYNC-13 phones whose clocks are a day off either way still converge', () async {
    w = await SimWorld.create();
    w.a.clock.skew = const Duration(days: 1);
    w.b.clock.skew = const Duration(days: -1);
    w.c.clock.skew = const Duration(minutes: 7);
    for (var i = 0; i < 25; i++) {
      final p = w.phones[i % 3];
      await p.randomWrite();
      await p.noteQueued();
      w.server.clock.advance(const Duration(seconds: 20));
      if (i % 4 == 0) await p.engine.sync();
    }
    await w.settle();
    await w.expectConverged();
  });

  final seeds = int.tryParse(Platform.environment['R4_FUZZ_SEEDS'] ?? '') ?? 6;
  final steps = int.tryParse(Platform.environment['R4_FUZZ_STEPS'] ?? '') ?? 120;
  for (var seed = 1; seed <= seeds; seed++) {
    test(
      'R4-SYNC-14 fuzz seed $seed ($steps steps): random offline work, faults, kills and skew',
      () async {
        final r = Random(seed);
        w = await SimWorld.create(
          seed: seed,
          phones: seed.isEven ? 3 : 2,
          pageSize: 1 + r.nextInt(12),
          batchSize: 1 + r.nextInt(6),
        );
        final trace = <String>[];
        try {
          for (var step = 0; step < steps; step++) {
            w.server.clock.advance(Duration(seconds: r.nextInt(120)));
            final p = w.phones[r.nextInt(w.phones.length)];
            p.remote
              ..chance = r.nextDouble() * 0.4
              ..latency = r.nextInt(4);
            final roll = r.nextInt(100);
            final String what;
            if (roll < 45) {
              final n = 1 + r.nextInt(3);
              for (var i = 0; i < n; i++) {
                trace.add('$step ${p.name} ${await p.randomWrite()}');
              }
              what = 'writes';
            } else if (roll < 60) {
              await p.engine.sync();
              what = 'sync ${p.engine.phase.name}';
            } else if (roll < 70) {
              final all = [for (final x in w.phones) x.engine.sync()];
              trace.add('$step ${p.name} ${await p.randomWrite()} during sync');
              await Future.wait(all);
              what = 'all sync';
            } else if (roll < 76) {
              p.remote.online = !p.remote.online;
              what = 'online=${p.remote.online}';
            } else if (roll < 82) {
              p.clock.skew = [
                Duration.zero,
                const Duration(days: 1),
                const Duration(days: -1),
                const Duration(minutes: 7),
                const Duration(seconds: -30),
              ][r.nextInt(5)];
              what = 'skew ${p.clock.skew}';
            } else if (roll < 88) {
              final kind = r.nextInt(4);
              p.remote.online = true;
              if (kind < 3) {
                (kind < 2 ? p.remote.applyFaults : p.remote.pullFaults).add(
                  kind == 1 ? SimFault.hangBefore : SimFault.hangAfter,
                );
                final running = p.engine.sync();
                await Future.any([p.remote.hung.future, running]);
              }
              p.remote
                ..applyFaults.clear()
                ..pullFaults.clear();
              await p.kill();
              what = 'kill $kind';
            } else if (roll < 94) {
              final all = <Future<void>>[
                for (var i = 0; i < 8; i++) p.engine.sync(),
                p.randomWrite().then(trace.add),
              ];
              await Future.wait(all);
              what = 'nudge storm';
            } else {
              what = await p.batchSettle();
            }
            await p.noteQueued();
            trace.add('$step ${p.name} $what');
          }
          await w.settle();
          await w.expectConverged();
        } on Object {
          printOnFailure(
            'seed $seed trace (last 60):\n${trace.skip(max(0, trace.length - 60)).join('\n')}',
          );
          rethrow;
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}
