// R4 sync stress: an in-memory model of the server's `apply_mutations` / `pull_changes` (0009, 0026, 0029,
// 0030 bodies) with transactions, so several simulated phones can push and pull concurrently.
import 'dart:async';
import 'dart:math';

import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/remote/remote_api.dart';

/// Server time that tests move forward by hand.
class SimClock implements Clock {
  SimClock(this.time);
  DateTime time;

  @override
  DateTime now() => time;

  void advance(Duration d) => time = time.add(d);
}

/// Synced tables in the order `pull_changes` lists them.
const simTables = [
  'groups',
  'group_members',
  'expenses',
  'expense_attachments',
  'payments',
  'comments',
  'activity',
];

/// Client-writable columns per entity (`sync_apply_one` 0026, `sync_apply_attachment` 0029).
const _cols = <String, List<String>>{
  'group': [
    'name',
    'type',
    'main_currency',
    'cover_kind',
    'cover_path',
    'simplify_debts',
    'default_split',
    'archived_at',
    'trip_starts_on',
    'trip_ends_on',
    'settle_reminder',
    'whiteboard',
  ],
  'member': ['display_name', 'position', 'tint'],
  'expense': [
    'kind',
    'description',
    'notes',
    'category',
    'date',
    'currency',
    'total',
    'payers',
    'shares',
    'split_kind',
    'split_values',
    'fx_rate',
    'fx_rate_date',
    'fx_source',
    'fx_currency',
    'fx_total',
    'fx_payers',
    'fx_shares',
    'receipt_path',
  ],
  'payment': [
    'from_member',
    'to_member',
    'amount',
    'currency',
    'date',
    'method',
    'note',
    'fx_rate',
    'fx_rate_date',
    'fx_source',
    'fx_currency',
    'fx_amount',
  ],
  'comment': ['target_type', 'target_id', 'body'],
  'attachment': ['name', 'position'],
};

const _tableOf = {
  'group': 'groups',
  'member': 'group_members',
  'expense': 'expenses',
  'payment': 'payments',
  'comment': 'comments',
  'attachment': 'expense_attachments',
};

/// One server transaction (one `apply_mutations` call). Rows it writes are invisible to other
/// transactions until [commit]; touching a row another open transaction wrote first commits that one
/// (Postgres would make this one wait for the row lock until the other commits).
class SimTx {
  SimTx._(this.server);

  final SimServer server;
  final _staged = <String, Map<String, Map<String, Object?>>>{};
  final _log = <String, Map<String, Object?>>{};
  final _versions = <Map<String, Object?>>[];
  final _order = <String, List<String>>{};

  /// Lower bound of every seq this transaction takes (0031: the shared advisory lock taken before the first
  /// `nextval`); null until it writes.
  int? floor;
  bool open = true;

  Map<String, Object?>? _get(String table, String id) {
    final mine = _staged[table]?[id];
    if (mine != null) return mine;
    server._waitFor(this, table, id);
    return server.rows[table]![id];
  }

  void _put(String table, Map<String, Object?> row) {
    server._waitFor(this, table, row['id']! as String);
    floor ??= server.seq + 1;
    row['seq'] = ++server.seq;
    (_staged[table] ??= {})[row['id']! as String] = row;
  }

  bool _isMember(String uid, String groupId) =>
      [
        ...server.rows['group_members']!.values.where(
          (m) => _staged['group_members']?[m['id']] == null,
        ),
        ...?_staged['group_members']?.values,
      ].any(
        (m) =>
            m['group_id'] == groupId &&
            m['user_id'] == uid &&
            m['status'] == 'active' &&
            m['deleted_at'] == null,
      );

  /// One mutation, as `apply_mutations` does it (dedupe, membership, LWW, history, activity).
  MutationResult apply(Map<String, Object?> m, String uid) {
    final mid = m['mutation_id']! as String;
    final done = _log[mid] ?? server._logFor(this, mid);
    if (done != null) {
      return MutationResult(mid, MutationStatus.duplicate, seq: done['seq'] as int?);
    }
    final MutationResult r;
    try {
      r = _applyOne(m, uid);
    } on _Reject catch (e) {
      return MutationResult(mid, MutationStatus.rejected, code: e.code);
    }
    _log[mid] = {'status': r.status.name, 'seq': r.seq};
    (_order[uid] ??= []).add(mid);
    return r;
  }

  MutationResult _applyOne(Map<String, Object?> m, String uid) {
    final mid = m['mutation_id']! as String;
    final entity = m['entity'] as String? ?? '';
    final op = m['op'] as String? ?? '';
    final id = m['id'] as String?;
    final group = m['group_id'] as String?;
    final data = (m['data'] as Map?)?.cast<String, Object?>() ?? const {};
    final table = _tableOf[entity];
    if (table == null ||
        !const ['upsert', 'delete', 'restore'].contains(op) ||
        id == null ||
        group == null ||
        (entity == 'group' && id != group)) {
      throw const _Reject('INVALID_MUTATION');
    }
    final now = server.clock.now().toUtc();
    final sent = DateTime.tryParse(m['client_updated_at'] as String? ?? '')?.toUtc() ?? now;
    final t = sent.isAfter(now) ? now : sent;
    final row = _get(table, id);
    if (!(entity == 'group' && row == null) && !_isMember(uid, group)) {
      throw const _Reject('NOT_MEMBER');
    }
    if (row != null && entity != 'group' && row['group_id'] != group) {
      throw const _Reject('ID_CONFLICT');
    }
    if (row == null && op != 'upsert') throw const _Reject('NOT_FOUND');
    final cols = _cols[entity]!;
    final filtered = <String, Object?>{
      for (final e in data.entries)
        if (cols.contains(e.key) && (row != null || e.value != null)) e.key: e.value,
    };
    if (row != null && t.isBefore(DateTime.parse(row['client_updated_at']! as String))) {
      _versions.add({
        'table_name': table,
        'record_id': id,
        'op': 'conflict_lost',
        'snapshot': {...row, ...filtered, 'client_updated_at': _ts(t), 'lost_op': op},
        'mutation_id': mid,
      });
      return MutationResult(mid, MutationStatus.superseded, seq: row['seq']! as int);
    }
    final stamp = _ts(now);
    final Map<String, Object?> next;
    final String vop;
    if (row == null) {
      vop = 'insert';
      final defaults = switch (entity) {
        'group' => {
          'type': 'other',
          'main_currency': 'INR',
          'cover_kind': 'generated',
          'simplify_debts': false,
          'settle_reminder': 'off',
        },
        'member' => {'role': 'member', 'status': 'active'},
        'expense' => {
          'kind': 'expense',
          'category': 'other.general',
          'split_kind': 'equal',
          'source': 'app',
        },
        'payment' => {'method': 'cash'},
        'attachment' => {
          'expense_id': data['expense_id'],
          'kind': data['kind'],
          'path': data['path'],
          'thumb_path': data['thumb_path'],
          'size_bytes': data['size_bytes'] ?? 0,
          'width': data['width'],
          'height': data['height'],
          'position': 0,
        },
        _ => const <String, Object?>{},
      };
      next = {
        ...defaults,
        ...filtered,
        'id': id,
        if (entity != 'group') 'group_id': group,
        'created_at': stamp,
        'created_by': uid,
        'updated_at': stamp,
        'updated_by': uid,
        'client_updated_at': _ts(t),
        'deleted_at': null,
        'deleted_by': null,
      };
    } else {
      vop = op == 'upsert' ? 'update' : op;
      next = {
        ...row,
        if (op == 'upsert') ...filtered,
        if (op == 'delete') ...{'deleted_at': stamp, 'deleted_by': uid},
        if (op == 'restore') ...{'deleted_at': null, 'deleted_by': null},
        'updated_at': stamp,
        'updated_by': uid,
        'client_updated_at': _ts(t),
      };
    }
    _validate(entity, next);
    _put(table, next);
    if (entity == 'group' && row == null) {
      final owner = (data['owner_member'] as Map?)?.cast<String, Object?>() ?? const {};
      _put('group_members', {
        'id': owner['id'] ?? newId(),
        'group_id': id,
        'user_id': uid,
        'display_name': owner['display_name'] ?? 'Me',
        'position': 0,
        'role': 'owner',
        'status': 'active',
        'tint': owner['tint'],
        'created_at': stamp,
        'created_by': uid,
        'updated_at': stamp,
        'updated_by': uid,
        'client_updated_at': _ts(t),
        'deleted_at': null,
        'deleted_by': null,
      });
    }
    _versions.add({
      'table_name': table,
      'record_id': id,
      'op': vop,
      'snapshot': {...next},
      'mutation_id': mid,
    });
    if (!(entity == 'attachment' && vop == 'update')) {
      _put('activity', {
        'id': newId(),
        'group_id': group,
        'actor_user_id': uid,
        'actor_member_id': null,
        'type': '${entity}_$vop',
        'target_type': entity,
        'target_id': id,
        'data': {'mutation_id': mid},
        'created_at': stamp,
      });
    }
    return MutationResult(mid, MutationStatus.applied, seq: next['seq']! as int);
  }

  /// The row checks the triggers and `sync_apply_*` make (sums, members of the group, amounts > 0).
  void _validate(String entity, Map<String, Object?> r) {
    Set<String> members() => {
      for (final m in [
        ...server.rows['group_members']!.values,
        ...?_staged['group_members']?.values,
      ])
        if (m['group_id'] == r['group_id']) m['id']! as String,
    };
    int sum(Object? m) => ((m as Map?) ?? const {}).values.fold(0, (a, v) => a + (v! as int));
    switch (entity) {
      case 'expense':
        final total = r['total'] as int? ?? 0;
        if (total <= 0) throw const _Reject('AMOUNT_NOT_POSITIVE');
        if (sum(r['payers']) != total || sum(r['shares']) != total) {
          throw const _Reject('SPLIT_SUM_MISMATCH');
        }
        final known = members();
        for (final k in [...(r['payers']! as Map).keys, ...(r['shares']! as Map).keys]) {
          if (!known.contains(k)) throw const _Reject('UNKNOWN_MEMBER');
        }
        if (r['fx_currency'] != null &&
            (sum(r['fx_payers']) != r['fx_total'] || sum(r['fx_shares']) != r['fx_total'])) {
          throw const _Reject('FX_SUM_MISMATCH');
        }
      case 'payment':
        final known = members();
        if ((r['amount'] as int? ?? 0) <= 0) throw const _Reject('AMOUNT_NOT_POSITIVE');
        if (r['from_member'] == r['to_member']) throw const _Reject('SAME_MEMBER');
        if (!known.contains(r['from_member']) || !known.contains(r['to_member'])) {
          throw const _Reject('UNKNOWN_MEMBER');
        }
      case 'comment':
        if ((r['body'] as String? ?? '').trim().isEmpty) throw const _Reject('EMPTY_COMMENT');
    }
  }

  /// Makes this transaction's rows visible (rows keep the seqs they got while it ran).
  void commit() {
    if (!open) return;
    open = false;
    server._open.remove(this);
    _staged.forEach((table, rows) => server.rows[table]!.addAll(rows));
    server.mutationLog.addAll(_log);
    server.versions.addAll(_versions);
    _order.forEach((uid, ids) => (server.applyOrder[uid] ??= []).addAll(ids));
    for (final id in _log.keys) {
      server.applyCount[id] = (server.applyCount[id] ?? 0) + 1;
    }
  }
}

class _Reject implements Exception {
  const _Reject(this.code);
  final String code;
}

String _ts(DateTime t) => t.toUtc().toIso8601String();

/// The server: committed rows per table, the global `sync_seq`, `mutation_log`, `record_versions`.
class SimServer {
  SimServer({required this.clock, this.horizon = true});

  final SimClock clock;

  /// 0031 fix on: `pull_changes` never returns rows at or above the lowest seq an open transaction may
  /// still commit. Off = the 0029 body (rows can be skipped for good, see the race test).
  bool horizon;

  int seq = 0;
  final rows = {for (final t in simTables) t: <String, Map<String, Object?>>{}};
  final mutationLog = <String, Map<String, Object?>>{};
  final versions = <Map<String, Object?>>[];

  /// First-time application order of each user's mutations.
  final applyOrder = <String, List<String>>{};

  /// How often each mutation id was applied (must stay 1).
  final applyCount = <String, int>{};
  final _open = <SimTx>[];

  SimTx begin() {
    final tx = SimTx._(this);
    _open.add(tx);
    return tx;
  }

  /// Applies [batch] for [uid] in one transaction committed at once.
  List<MutationResult> applyNow(List<Map<String, Object?>> batch, String uid) {
    final tx = begin();
    final out = [for (final m in batch) tx.apply(m, uid)];
    tx.commit();
    return out;
  }

  void _waitFor(SimTx me, String table, String id) {
    for (final other in [..._open]) {
      if (other != me && (other._staged[table]?.containsKey(id) ?? false)) other.commit();
    }
  }

  Map<String, Object?>? _logFor(SimTx me, String mid) {
    for (final other in [..._open]) {
      if (other != me && other._log.containsKey(mid)) other.commit();
    }
    return mutationLog[mid];
  }

  /// Server-side write outside `apply_mutations` (seed data, `join_group`, removing a member).
  void write(String table, Map<String, Object?> row) {
    final tx = begin().._put(table, {...row});
    tx.commit();
  }

  Set<String> groupsOf(String uid) => {
    for (final m in rows['group_members']!.values)
      if (m['user_id'] == uid && m['status'] == 'active' && m['deleted_at'] == null)
        m['group_id']! as String,
  };

  /// `pull_changes(cursors, since_user_seq, page_size)` over committed rows.
  PullPage pull(String uid, Map<String, int> cursors, int userSeq, int pageSize) {
    final mine = groupsOf(uid);
    final size = pageSize.clamp(1, 1000);
    final floors = [for (final t in _open) ?t.floor];
    final limit = horizon && floors.isNotEmpty ? floors.reduce(min) : null;
    final changes = <({String table, int seq, Map<String, Object?> row})>[];
    for (final table in simTables) {
      for (final r in rows[table]!.values) {
        final g = (table == 'groups' ? r['id'] : r['group_id'])! as String;
        if (!mine.contains(g)) continue;
        final s = r['seq']! as int;
        if (s <= (cursors[g] ?? 0)) continue;
        if (limit != null && s >= limit) continue;
        changes.add((table: table, seq: s, row: r));
      }
    }
    changes.sort((a, b) => a.seq.compareTo(b.seq));
    final more = changes.length > size;
    final page = changes.take(size).toList();
    final vmax = page.isEmpty ? 0 : page.last.seq;
    return PullPage(
      serverTime: clock.now().toUtc(),
      rows: {
        for (final t in simTables)
          t: [
            for (final c in page)
              if (c.table == t) _copy(c.row),
          ],
      },
      nextCursors: {for (final g in mine) g: max(cursors[g] ?? 0, vmax)},
      userSeq: userSeq,
      lostGroups: [
        for (final g in cursors.keys)
          if (!mine.contains(g)) g,
      ]..sort(),
      hasMore: more,
    );
  }

  /// Live rows of [table] in [groupId].
  List<Map<String, Object?>> live(String table, String groupId) => [
    for (final r in rows[table]!.values)
      if ((table == 'groups' ? r['id'] : r['group_id']) == groupId && r['deleted_at'] == null) r,
  ];

  /// Balances the server computes for a group (fixed order: position, then id; payments to oneself and
  /// zero payments skipped like the phone).
  Map<String, Balances> balances(String groupId) {
    final members =
        [
          for (final m in rows['group_members']!.values)
            if (m['group_id'] == groupId) m,
        ]..sort((a, b) {
          final p = (a['position']! as int).compareTo(b['position']! as int);
          return p != 0 ? p : (a['id']! as String).compareTo(b['id']! as String);
        });
    Map<String, int> minor(Object? m) => {
      for (final e in ((m as Map?) ?? const {}).entries) e.key as String: e.value as int,
    };
    final flows = [
      for (final e in live('expenses', groupId))
        ExpenseFlow(
          currency: e['currency']! as String,
          paid: minor(e['payers']),
          shares: minor(e['shares']),
        ),
    ];
    final payments = [
      for (final p in live('payments', groupId))
        if (p['from_member'] != p['to_member'] && (p['amount']! as int) > 0)
          Payment(
            currency: p['currency']! as String,
            from: p['from_member']! as String,
            to: p['to_member']! as String,
            amount: p['amount']! as int,
          ),
    ];
    final order = [for (final m in members) m['id']! as String];
    final extra = {
      for (final f in flows) ...[...f.paid.keys, ...f.shares.keys],
      for (final p in payments) ...[p.from, p.to],
    }.difference(order.toSet()).toList()..sort();
    return balancesByCurrency([...order, ...extra], flows, payments);
  }
}

Map<String, Object?> _copy(Map<String, Object?> r) => {
  for (final e in r.entries)
    e.key: e.value is Map ? Map<String, Object?>.from(e.value! as Map) : e.value,
};

/// What can go wrong on one call (fuzz picks them at random, tests script them).
enum SimFault {
  none,

  /// Connection fails before the server sees the request.
  dropBefore,

  /// The server commits, the answer never arrives.
  dropAfter,

  /// The request reaches the server twice (a proxy retry); the second answer comes back.
  duplicate,

  /// Results come back in another order.
  shuffle,

  /// Some results are missing from the answer.
  partial,

  /// 401 once; the refresh works.
  authOnce,

  /// The app is killed after the server committed (the call never returns).
  hangAfter,

  /// The app is killed before the request is sent (the call never returns).
  hangBefore,

  /// Every mutation is refused for now (e.g. GROUP_ARCHIVED while someone archived the group).
  rejectAll,
}

/// One phone's door to [SimServer], with scripted or random faults and latency.
class SimRemote implements RemoteApi {
  SimRemote(this.server, this.uid, this.random);

  final SimServer server;
  final String uid;
  final Random random;

  bool online = true;

  /// One-shot faults for the next calls (tests); then [chance] picks random ones (fuzz).
  final applyFaults = <SimFault>[];
  final pullFaults = <SimFault>[];
  double chance = 0;

  /// Up to this many event-loop turns of latency before and after the server works.
  int latency = 0;

  /// Fires when a call hangs (the test then kills the app).
  Completer<void> hung = Completer<void>();

  int inFlight = 0;
  int maxInFlight = 0;
  int applyCalls = 0;
  int pullCalls = 0;
  int refreshes = 0;
  final supersededResults = <String>{};

  static const _applyRandom = [
    SimFault.dropBefore,
    SimFault.dropAfter,
    SimFault.duplicate,
    SimFault.shuffle,
    SimFault.partial,
    SimFault.authOnce,
  ];

  SimFault _next(List<SimFault> script, List<SimFault> pool) {
    if (script.isNotEmpty) return script.removeAt(0);
    if (chance > 0 && random.nextDouble() < chance) return pool[random.nextInt(pool.length)];
    return SimFault.none;
  }

  Future<void> _wait() async {
    for (var i = random.nextInt(latency + 1); i > 0; i--) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<Never> _hang() {
    if (!hung.isCompleted) hung.complete();
    return Completer<Never>().future;
  }

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) async {
    applyCalls++;
    if (!online) throw const NetworkException('offline');
    final fault = _next(applyFaults, _applyRandom);
    inFlight++;
    maxInFlight = max(maxInFlight, inFlight);
    try {
      await _wait();
      if (fault == SimFault.dropBefore) throw const NetworkException('connection reset');
      if (fault == SimFault.authOnce) throw const AuthExpiredException();
      if (fault == SimFault.hangBefore) {
        inFlight--;
        return await _hang();
      }
      if (fault == SimFault.rejectAll) {
        return ApplyResponse(server.clock.now().toUtc(), [
          for (final m in batch)
            MutationResult(
              m['mutation_id']! as String,
              MutationStatus.rejected,
              code: 'GROUP_ARCHIVED',
            ),
        ]);
      }
      final tx = server.begin();
      var results = [for (final m in batch) tx.apply(m, uid)];
      await _wait();
      tx.commit();
      if (fault == SimFault.duplicate) results = server.applyNow(batch, uid);
      await _wait();
      if (fault == SimFault.dropAfter) throw const NetworkException('response lost');
      if (fault == SimFault.hangAfter) {
        inFlight--;
        return await _hang();
      }
      if (fault == SimFault.shuffle) results = [...results]..shuffle(random);
      if (fault == SimFault.partial && results.length > 1) {
        results = [...results]..removeAt(random.nextInt(results.length));
      }
      for (final r in results) {
        if (r.status == MutationStatus.superseded) supersededResults.add(r.mutationId);
      }
      return ApplyResponse(server.clock.now().toUtc(), results);
    } finally {
      if (fault != SimFault.hangAfter && fault != SimFault.hangBefore) inFlight--;
    }
  }

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) async {
    pullCalls++;
    if (!online) throw const NetworkException('offline');
    final fault = _next(pullFaults, const [SimFault.dropBefore, SimFault.dropAfter]);
    await _wait();
    if (fault == SimFault.dropBefore) throw const NetworkException('connection reset');
    if (fault == SimFault.hangBefore) return await _hang();
    final page = server.pull(uid, cursors, userSeq, pageSize);
    await _wait();
    if (fault == SimFault.dropAfter) throw const NetworkException('response lost');
    if (fault == SimFault.hangAfter) return await _hang();
    return page;
  }

  @override
  Future<void> refreshSession() async {
    refreshes++;
  }
}
