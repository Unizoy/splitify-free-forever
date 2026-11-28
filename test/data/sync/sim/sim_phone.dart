// R4 sync stress: one simulated phone = its own SQLite file, the real SyncEngine / LocalWriter /
// repositories, a clock that can be wrong by any amount, and a SimRemote with faults.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/balances/application/balance_views.dart';

import '../sync_fakes.dart' show ManualTimers;
import 'sim_server.dart';

/// Phone time = server time + [skew] (a wrong or changed phone clock).
class SkewClock implements Clock {
  SkewClock(this.base);
  final Clock base;
  Duration skew = Duration.zero;

  @override
  DateTime now() => base.now().add(skew);
}

class SimPhone {
  SimPhone(
    this.name,
    this.uid,
    this.server,
    this.dir, {
    required int seed,
    this.pageSize = 500,
    this.batchSize = 50,
  }) : random = Random(seed),
       clock = SkewClock(server.clock) {
    remote = SimRemote(server, uid, Random(seed + 7));
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  final String name;
  final String uid;
  final SimServer server;
  final Directory dir;
  final Random random;
  final SkewClock clock;
  final int pageSize;
  final int batchSize;
  late SimRemote remote;

  late AppDatabase db;
  late SyncEngine engine;
  late LocalWriter writer;
  late GroupsRepository groups;
  late MembersRepository members;
  late ExpensesRepository expenses;
  late PaymentsRepository payments;
  late CommentsRepository comments;
  StreamSubscription<int>? _lost;

  /// Edits this phone was told lost to a newer one (the one-time snackbar).
  int supersededShown = 0;

  /// Every mutation id this phone queued, in queue order.
  final queued = <String>[];
  int _seenSeq = 0;
  int kills = 0;

  File get file => File('${dir.path}${Platform.pathSeparator}$name.sqlite');

  Future<void> open() async {
    db = AppDatabase(NativeDatabase(file, setup: (raw) => raw.execute('PRAGMA synchronous = OFF')));
    // Test-only log of every queued mutation (items leave the outbox as soon as they are applied).
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS r4_queued (seq INTEGER PRIMARY KEY, mutation_id TEXT NOT NULL)',
    );
    await db.customStatement(
      'CREATE TRIGGER IF NOT EXISTS r4_queued_log AFTER INSERT ON outbox '
      'BEGIN INSERT INTO r4_queued (seq, mutation_id) VALUES (new.seq, new.mutation_id); END',
    );
    engine = SyncEngine(
      db: db,
      remote: remote,
      clock: clock,
      timer: ManualTimers().call,
      random: Random(random.nextInt(1 << 30)),
      batchSize: batchSize,
      pageSize: pageSize,
    );
    writer = LocalWriter(db, clock, engine.serverClock);
    groups = GroupsRepository(db, writer);
    members = MembersRepository(db, writer);
    expenses = ExpensesRepository(db, writer);
    payments = PaymentsRepository(db, writer);
    comments = CommentsRepository(db, writer);
    _lost = engine.superseded.listen((n) => supersededShown += n);
  }

  /// The app is killed: whatever the engine awaits never returns; the database file stays.
  Future<void> kill() async {
    kills++;
    await _lost?.cancel();
    // The old engine may be parked on a call that never returns; it is simply dropped.
    await db.close();
    remote.hung = Completer<void>();
    await open();
  }

  Future<void> close() async {
    await _lost?.cancel();
    await engine.dispose();
    await db.close();
  }

  /// Notes the mutation ids queued since the last call (outbox seq order).
  Future<void> noteQueued() async {
    final rows = await db
        .customSelect(
          'SELECT seq, mutation_id FROM r4_queued WHERE seq > ? ORDER BY seq',
          variables: [Variable<int>(_seenSeq)],
        )
        .get();
    for (final r in rows) {
      queued.add(r.read<String>('mutation_id'));
      _seenSeq = max(_seenSeq, r.read<int>('seq'));
    }
  }

  // ------------------------------------------------------------------ local reads

  Future<List<LocalGroup>> liveGroups() =>
      (db.select(db.groups)..where((g) => g.deletedAt.isNull())).get();

  Future<List<LocalMember>> activeMembers(String groupId) async {
    final rows =
        await (db.select(db.groupMembers)..where(
              (m) => m.groupId.equals(groupId) & m.deletedAt.isNull() & m.status.equals('active'),
            ))
            .get();
    return rows..sort((a, b) {
      final p = a.position.compareTo(b.position);
      return p != 0 ? p : a.id.compareTo(b.id);
    });
  }

  Future<List<LocalExpense>> allExpenses(String groupId) =>
      (db.select(db.expenses)..where((e) => e.groupId.equals(groupId))).get();

  Future<List<LocalPayment>> allPayments(String groupId) =>
      (db.select(db.payments)..where((p) => p.groupId.equals(groupId))).get();

  Future<String?> myMemberId(String groupId) async =>
      (await activeMembers(groupId)).where((m) => m.userId == uid).map((m) => m.id).firstOrNull;

  /// Local balances of every live group, as the screens compute them.
  Future<List<GroupBalances>> balances() async {
    final ledgers = await LedgerRepository(db).loadAll();
    return [for (final l in ledgers) groupBalancesOf(l, uid)];
  }

  String today() => clock.now().toUtc().toIso8601String().substring(0, 10);

  // ------------------------------------------------------------------ writes (all through repositories)

  T pick<T>(List<T> xs) => xs[random.nextInt(xs.length)];

  static const currencies = ['INR', 'INR', 'INR', 'USD', 'EUR', 'JPY', 'KWD', 'BHD'];

  /// A valid expense body over the group's active members (equal or by shares; one or two payers).
  Future<Map<String, Object?>?> expenseBody(String groupId, {String? currency}) async {
    final people = await activeMembers(groupId);
    if (people.isEmpty) return null;
    final total = 1 + random.nextInt(random.nextBool() ? 999 : 5000000);
    final chosen = [
      for (final m in people)
        if (random.nextInt(3) > 0) m.id,
    ];
    if (chosen.isEmpty) chosen.add(people.first.id);
    final shares = <String, int>{};
    if (random.nextBool()) {
      final n = chosen.length;
      for (var i = 0; i < n; i++) {
        shares[chosen[i]] = total ~/ n + (i < total % n ? 1 : 0);
      }
    } else {
      final w = [for (final _ in chosen) 1 + random.nextInt(5)];
      final sw = w.fold(0, (a, b) => a + b);
      var left = total;
      for (var i = 0; i < chosen.length; i++) {
        final v = i == chosen.length - 1 ? left : total * w[i] ~/ sw;
        shares[chosen[i]] = v;
        left -= v;
      }
    }
    final payer = pick(people).id;
    final payers = <String, int>{payer: total};
    if (people.length > 1 && total > 1 && random.nextInt(4) == 0) {
      final other = people.firstWhere((m) => m.id != payer).id;
      final part = 1 + random.nextInt(total - 1);
      payers
        ..[payer] = total - part
        ..[other] = part;
    }
    final code = currency ?? pick(currencies);
    final body = <String, Object?>{
      'description':
          'E${random.nextInt(1 << 20)} ${pick(const ['Dinner', 'Taxi', 'चाय', 'شاي', '🍕 Pizza'])}',
      'date': today(),
      'currency': code,
      'total': total,
      'payers': payers,
      'shares': shares,
      'split_kind': 'equal',
    };
    if (code != 'INR' && random.nextInt(3) == 0) {
      // A saved conversion (rule 4): the INR total and parts re-allocated so they still add up.
      final fxTotal = max(1, total * 83 ~/ 1);
      Map<String, int> scale(Map<String, int> m) {
        final out = <String, int>{};
        var left = fxTotal;
        final keys = m.keys.toList();
        for (var i = 0; i < keys.length; i++) {
          final v = i == keys.length - 1 ? left : fxTotal * m[keys[i]]! ~/ total;
          out[keys[i]] = v;
          left -= v;
        }
        return out;
      }

      body.addAll({
        'fx_rate': '83.0000000000',
        'fx_rate_date': today(),
        'fx_source': 'manual',
        'fx_currency': 'INR',
        'fx_total': fxTotal,
        'fx_payers': scale(payers),
        'fx_shares': scale(shares),
      });
    }
    return body;
  }

  /// One random local action through the repositories; returns a label for the trace.
  Future<String> randomWrite() async {
    final gs = await liveGroups();
    if (gs.isEmpty) return 'no group';
    final g = pick(gs).id;
    final ex = await allExpenses(g);
    final pays = await allPayments(g);
    switch (random.nextInt(14)) {
      case 0 || 1 || 2:
        final body = await expenseBody(g);
        if (body == null) return 'no members';
        await expenses.save(g, body);
        return 'add expense';
      case 3 || 4:
        final live = ex.where((e) => e.deletedAt == null).toList();
        if (live.isEmpty) return 'no expense to edit';
        final body = await expenseBody(g);
        if (body == null) return 'no members';
        await expenses.save(g, body, id: pick(live).id);
        return 'edit expense';
      case 5:
        final live = ex.where((e) => e.deletedAt == null).toList();
        if (live.isEmpty) return 'no expense to delete';
        await expenses.delete(pick(live).id, g);
        return 'delete expense';
      case 6:
        final gone = ex.where((e) => e.deletedAt != null).toList();
        if (gone.isEmpty) return 'no expense to restore';
        await expenses.restore(pick(gone).id, g);
        return 'restore expense';
      case 7:
        final people = await activeMembers(g);
        if (people.length < 2) return 'too few members';
        final from = pick(people);
        final to = pick(people.where((m) => m.id != from.id).toList());
        await payments.save(g, {
          'from_member': from.id,
          'to_member': to.id,
          'amount': 1 + random.nextInt(100000),
          'currency': pick(currencies),
          'date': today(),
        });
        return 'add payment';
      case 8:
        final live = pays.where((p) => p.deletedAt == null).toList();
        if (live.isEmpty) return 'no payment';
        final p = pick(live);
        if (random.nextBool()) {
          await payments.delete(p.id, g);
          return 'delete payment';
        }
        await payments.save(g, {
          'from_member': p.fromMember,
          'to_member': p.toMember,
          'amount': 1 + random.nextInt(100000),
          'currency': p.currency,
          'date': p.date,
        }, id: p.id);
        return 'edit payment';
      case 9:
        final gone = pays.where((p) => p.deletedAt != null).toList();
        if (gone.isEmpty) return 'no payment to restore';
        await payments.restore(pick(gone).id, g);
        return 'restore payment';
      case 10:
        if (ex.isEmpty) return 'no expense to comment';
        final cs = await (db.select(
          db.comments,
        )..where((c) => c.groupId.equals(g) & c.deletedAt.isNull())).get();
        if (cs.isNotEmpty && random.nextBool()) {
          await comments.delete(pick(cs).id, g);
          return 'delete comment';
        }
        await comments.save(g, {
          'target_type': 'expense',
          'target_id': pick(ex).id,
          'body': 'c${random.nextInt(999)} ✓ مرحبا',
        });
        return 'add comment';
      case 11:
        if (ex.isEmpty) return 'no expense to attach';
        final atts = await (db.select(
          db.expenseAttachments,
        )..where((a) => a.groupId.equals(g))).get();
        if (atts.isNotEmpty && random.nextBool()) {
          final a = pick(atts);
          await writer.write(
            SyncEntity.attachment,
            a.deletedAt == null ? SyncOp.delete : SyncOp.restore,
            a.id,
            g,
          );
          return 'remove/restore attachment';
        }
        final id = newId();
        final e = pick(ex).id;
        await writer.write(SyncEntity.attachment, SyncOp.upsert, id, g, {
          'expense_id': e,
          'kind': 'photo',
          'path': '$g/$e/$id.jpg',
          'size_bytes': 1000 + random.nextInt(500000),
          'position': atts.length,
        });
        return 'add attachment';
      case 12:
        await members.addNameOnly(
          g,
          'P${random.nextInt(999)} ${pick(const ['Asha', 'رامي', 'נועה', '👩🏽‍💻'])}',
        );
        return 'add member';
      default:
        if (random.nextBool()) {
          await groups.update(g, {'name': 'G${random.nextInt(999)}'});
          return 'rename group';
        }
        await groups.update(g, {'simplify_debts': random.nextBool()});
        return 'simplify';
    }
  }

  /// Batch settle-up (S-405): one payment per group and currency where I owe, all in one transaction,
  /// the biggest balance first.
  Future<String> batchSettle() async {
    final rows = <({String groupId, Map<String, Object?> data})>[];
    for (final b in await balances()) {
      final me = b.meId;
      if (me == null) continue;
      for (final c in b.currencies) {
        final nets = b.byCurrency[c]!.nets;
        final mine = nets[me] ?? 0;
        if (mine >= 0) continue;
        final creditors = nets.entries.where((e) => e.value > 0).toList()
          ..sort((a, x) => x.value.compareTo(a.value));
        if (creditors.isEmpty) continue;
        rows.add((
          groupId: b.groupId,
          data: {
            'from_member': me,
            'to_member': creditors.first.key,
            'amount': min(-mine, creditors.first.value),
            'currency': c,
            'date': today(),
            'batch_id': newId(),
          },
        ));
      }
    }
    if (rows.isEmpty) return 'nothing to settle';
    await payments.saveAll(rows);
    return 'batch settle ${rows.length}';
  }
}

/// Canonical text of a row for comparisons (JSON columns decoded, sync-only columns dropped).
String canonicalRow(Map<String, Object?> row, Iterable<String> columns) {
  final out = <String, Object?>{};
  for (final c in columns) {
    var v = row[c];
    if (v is String && (v.startsWith('{') || v.startsWith('['))) {
      try {
        v = jsonDecode(v);
      } on FormatException {
        // plain text that starts with a brace
      }
    }
    if (v is Map) {
      v = Map.fromEntries(v.entries.toList()..sort((a, b) => '${a.key}'.compareTo('${b.key}')));
    }
    if (v is bool) v = v ? 1 : 0;
    out[c] = v;
  }
  return jsonEncode(out);
}
