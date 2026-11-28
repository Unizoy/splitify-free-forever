// R4 sync stress: a server and 2–3 phones sharing groups, plus the invariants checked after everything
// settles (no lost or duplicated rows, outbox order kept, phone = server, balances equal, rule 3, rule 4).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/local/daos/expense_parts_dao.dart' show rebuildExpenseParts;
import 'package:splitify/data/sync/row_codec.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/domain/balance_check.dart';

import 'sim_phone.dart';
import 'sim_server.dart';

const uA = '01900000-0000-7000-8000-00000000aaaa';
const uB = '01900000-0000-7000-8000-00000000bbbb';
const uC = '01900000-0000-7000-8000-00000000cccc';
const g1 = '01900000-0000-7000-8000-0000000000f1';
const g2 = '01900000-0000-7000-8000-0000000000f2';
const g3 = '01900000-0000-7000-8000-0000000000f3';

String memberId(String group, String user) =>
    '01900000-0000-7000-8000-00${group.substring(34)}${user.substring(32)}0000';

class SimWorld {
  SimWorld._(this.server, this.dir);

  final SimServer server;
  final Directory dir;
  final phones = <SimPhone>[];

  /// Server + phones A, B (+ C). Groups: g1 = A, B, C + a name-only member; g2 = A, B; g3 = B, C (when C
  /// exists) with [bigGroup] extra name-only members in g1.
  static Future<SimWorld> create({
    int seed = 1,
    int phones = 3,
    bool horizon = true,
    int pageSize = 500,
    int batchSize = 50,
    int bigGroup = 0,
  }) async {
    final server = SimServer(clock: SimClock(DateTime.utc(2026, 11, 28, 9)), horizon: horizon);
    final dir = Directory.systemTemp.createTempSync('r4sync');
    final w = SimWorld._(server, dir);
    final users = [uA, uB, uC].take(phones).toList();
    void group(String id, String name, List<String> who, {int extra = 0}) {
      server.write(
        'groups',
        w._row({'id': id, 'name': name, 'type': 'trip', 'main_currency': 'INR'}),
      );
      for (var i = 0; i < who.length; i++) {
        server.write(
          'group_members',
          w._row({
            'id': memberId(id, who[i]),
            'group_id': id,
            'user_id': who[i],
            'display_name': 'U${who[i].substring(32)}',
            'position': i,
            'role': i == 0 ? 'owner' : 'member',
            'status': 'active',
          }),
        );
      }
      for (var i = 0; i < extra; i++) {
        server.write(
          'group_members',
          w._row({
            'id': '01900000-0000-7000-8000-99${id.substring(34)}${i.toString().padLeft(8, '0')}',
            'group_id': id,
            'user_id': null,
            'display_name': 'Name only $i',
            'position': who.length + i,
            'role': 'member',
            'status': 'active',
          }),
        );
      }
    }

    group(g1, 'Goa', users, extra: 1 + bigGroup);
    group(g2, 'Flat', users.take(2).toList());
    if (phones > 2) group(g3, 'Office', [uB, uC]);
    for (var i = 0; i < users.length; i++) {
      final p = SimPhone(
        'phone${String.fromCharCode(65 + i)}',
        users[i],
        server,
        dir,
        seed: seed * 31 + i,
        pageSize: pageSize,
        batchSize: batchSize,
      );
      await p.open();
      w.phones.add(p);
    }
    for (final p in w.phones) {
      await p.engine.sync();
    }
    return w;
  }

  Map<String, Object?> _row(Map<String, Object?> r) {
    final t = server.clock.now().toUtc().toIso8601String();
    return {
      'created_at': t,
      'updated_at': t,
      'client_updated_at': t,
      'deleted_at': null,
      'deleted_by': null,
      ...r,
    };
  }

  SimPhone get a => phones[0];
  SimPhone get b => phones[1];
  SimPhone get c => phones[2];

  /// Everyone online, no faults, no latency; syncs round after round until nothing moves, then once more.
  Future<void> settle({int rounds = 30}) async {
    for (final p in phones) {
      p.remote
        ..online = true
        ..chance = 0
        ..latency = 0
        ..applyFaults.clear()
        ..pullFaults.clear();
    }
    for (var i = 0; i < rounds; i++) {
      final before = server.seq;
      for (final p in phones) {
        await p.engine.sync();
        await p.noteQueued();
      }
      var empty = true;
      for (final p in phones) {
        if ((await p.db.select(p.db.outbox).get()).isNotEmpty) empty = false;
      }
      if (empty && server.seq == before) {
        for (final p in phones) {
          await p.engine.sync();
        }
        return;
      }
    }
    fail('did not settle in $rounds rounds');
  }

  Future<void> dispose() async {
    for (final p in phones) {
      await p.close();
    }
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a file for a moment; the temp folder is cleaned up later.
    }
  }

  /// Every invariant of the R4 sync package after [settle].
  Future<void> expectConverged() async {
    for (final p in phones) {
      final why = '${p.name} (${p.kills} kills)';
      final mine = server.groupsOf(p.uid);
      expect(await p.db.select(p.db.outbox).get(), isEmpty, reason: '$why outbox');
      expect(p.engine.phase, SyncPhase.idle, reason: '$why phase ${p.engine.lastError}');

      // No lost or duplicated rows: the phone holds exactly the server's rows of its groups.
      for (final table in simTables) {
        final local = await p.db.customSelect('SELECT * FROM "$table"').get();
        final cols = tableNamed(
          p.db,
          table,
        ).$columns.map((c) => c.name).where((c) => c != 'sync_state').toSet();
        final serverRows = {
          for (final r in server.rows[table]!.values)
            if (mine.contains(table == 'groups' ? r['id'] : r['group_id'])) r['id']! as String: r,
        };
        final localRows = {for (final r in local) r.data['id']! as String: r.data};
        expect(localRows.keys.toSet(), serverRows.keys.toSet(), reason: '$why $table ids');
        for (final id in serverRows.keys) {
          final s = serverRows[id]!;
          final shared = cols.where(s.containsKey).toList()..sort();
          expect(
            canonicalRow(localRows[id]!, shared),
            canonicalRow(s, shared),
            reason: '$why $table $id',
          );
          if (localRows[id]!.containsKey('sync_state')) {
            expect(localRows[id]!['sync_state'], SyncState.synced, reason: '$why $table $id state');
          }
        }
      }

      // Derived parts match their expenses (deleted ones have none).
      final before = await p.db
          .customSelect('SELECT * FROM expense_parts ORDER BY expense_id, member_id')
          .get();
      for (final e in await p.db.select(p.db.expenses).get()) {
        await p.db.transaction(() => rebuildExpenseParts(p.db, e.id));
      }
      final after = await p.db
          .customSelect('SELECT * FROM expense_parts ORDER BY expense_id, member_id')
          .get();
      expect(
        [for (final r in before) r.data],
        [for (final r in after) r.data],
        reason: '$why expense_parts',
      );

      // Server and phone balances are equal, per currency (rule 3, rule 4).
      final views = await p.balances();
      for (final v in views) {
        final s = server.balances(v.groupId);
        expect(
          balancesFingerprint(v.byCurrency),
          balancesFingerprint(s),
          reason: '$why balances ${v.groupId}',
        );
        _expectCurrenciesApart(v.groupId, s, why);
      }

      // Rule 3: per-group balances add up to the overall balance, per currency; people add up too.
      final me = myBalancesOf(views);
      final sums = <String, int>{};
      for (final g in me.byGroup.values) {
        g.forEach((c, v) => sums[c] = (sums[c] ?? 0) + v);
      }
      sums.removeWhere((_, v) => v == 0);
      expect(me.totals, sums, reason: '$why overall = sum of groups');
      final people = <String, int>{};
      for (final x in me.people) {
        x.balances.forEach((c, v) => people[c] = (people[c] ?? 0) + v);
      }
      people.removeWhere((_, v) => v == 0);
      expect(people, me.totals, reason: '$why overall = sum of people');

      // Nothing lost or applied twice; the server applied this phone's mutations in queue order.
      for (final id in p.queued) {
        expect(
          server.mutationLog.containsKey(id),
          isTrue,
          reason: '$why mutation $id never applied',
        );
        expect(
          server.applyCount[id],
          1,
          reason: '$why mutation $id applied ${server.applyCount[id]}x',
        );
      }
      expect(server.applyOrder[p.uid] ?? const <String>[], p.queued, reason: '$why order');
      expect(
        p.supersededShown,
        p.remote.supersededResults.length,
        reason: '$why superseded snackbar',
      );
      expect(p.remote.maxInFlight, lessThanOrEqualTo(1), reason: '$why single flight');
    }
  }

  /// Rule 4: every currency block is computed from that currency's records alone and nets to zero.
  void _expectCurrenciesApart(String groupId, Map<String, Balances> s, String why) {
    final codes = {
      for (final e in server.live('expenses', groupId)) e['currency']! as String,
      for (final x in server.live('payments', groupId))
        if (x['from_member'] != x['to_member']) x['currency']! as String,
    };
    expect(s.keys.toSet(), codes, reason: '$why currencies $groupId');
    for (final e in s.entries) {
      expect(e.value.nets.values.fold(0, (a, b) => a + b), 0, reason: '$why ${e.key} nets sum');
    }
  }
}
