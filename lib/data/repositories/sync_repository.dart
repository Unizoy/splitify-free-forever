import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value, Variable;
import 'package:flutter/foundation.dart' show immutable;
import 'package:logging/logging.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/repositories.dart' as repos;
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/data/sync/uploads.dart';

final _log = Logger('sync');

/// What "Sync & storage" and the sync markers show (04 §9).
@immutable
class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.lastSync,
    this.waiting = 0,
    this.failed = 0,
    this.lastError,
  });

  final SyncPhase phase;

  /// End of the last successful push + pull (UTC); null = never on this phone.
  final DateTime? lastSync;

  /// Outbox changes not on the server yet (queued or in flight).
  final int waiting;

  /// Changes the server refused (Sync issues: retry or discard).
  final int failed;

  /// Code of the last failed run (`network`, `AUTH_EXPIRED`, a server code), null after a good run.
  final String? lastError;

  bool get allSynced => waiting == 0 && failed == 0;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.phase == phase &&
      other.lastSync == lastSync &&
      other.waiting == waiting &&
      other.failed == failed &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(phase, lastSync, waiting, failed, lastError);
}

/// One change the server refused.
class SyncIssue {
  const SyncIssue({
    required this.seq,
    required this.entity,
    required this.op,
    required this.recordId,
    required this.groupId,
    required this.code,
    required this.attempts,
    required this.createdAt,
    this.targetType,
    this.targetId,
  });

  final int seq;
  final SyncEntity entity;
  final SyncOp op;
  final String recordId;
  final String groupId;
  final String code;
  final int attempts;
  final DateTime? createdAt;

  /// Comments: what the comment is on (`expense` / `payment`) so "Edit" can open it.
  final String? targetType;
  final String? targetId;
}

/// A photo on this phone that is not on the server yet (04 §6, S-113).
@immutable
class SyncUpload {
  const SyncUpload({
    required this.id,
    required this.bucket,
    required this.recordId,
    required this.attempts,
  });

  final String id;
  final String bucket;
  final String recordId;

  /// Refusals so far; at [UploadQueue.skipAfter] the queue stops trying.
  final int attempts;

  bool get skipped => attempts >= UploadQueue.skipAfter;

  @override
  bool operator ==(Object other) =>
      other is SyncUpload &&
      other.id == id &&
      other.bucket == bucket &&
      other.recordId == recordId &&
      other.attempts == attempts;

  @override
  int get hashCode => Object.hash(id, bucket, recordId, attempts);
}

/// Sync state and actions for features (status, issues, "Sync now", sign-out flush, wipe).
class SyncRepository {
  SyncRepository(this.engine);

  final SyncEngine engine;

  AppDatabase get _db => engine.db;

  /// Live status: engine phase + last sync time + outbox counts.
  Stream<SyncStatus> watchStatus() {
    final subs = <StreamSubscription<Object?>>[];
    late final StreamController<SyncStatus> out;
    var phase = engine.phase;
    DateTime? last;
    var lastKnown = false;
    (int, int)? counts;

    void emit() {
      final c = counts;
      if (!lastKnown || c == null || out.isClosed) return;
      out.add(
        SyncStatus(
          phase: phase,
          lastSync: last,
          waiting: c.$1,
          failed: c.$2,
          lastError: engine.lastError,
        ),
      );
    }

    out = StreamController<SyncStatus>(
      onListen: () {
        subs
          ..add(
            engine.phases.listen((p) {
              phase = p;
              emit();
            }),
          )
          ..add(
            engine.dao.watchMeta(SyncEngine.lastSyncKey).listen((v) {
              last = v == null ? null : DateTime.tryParse(v)?.toUtc();
              lastKnown = true;
              emit();
            }, onError: out.addError),
          )
          ..add(
            _watchCounts().listen((c) {
              counts = c;
              emit();
            }, onError: out.addError),
          );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }

  Stream<(int, int)> _watchCounts() => _db
      .customSelect(
        "SELECT COALESCE(SUM(status IN ('queued', 'in_flight')), 0) AS waiting, "
        "COALESCE(SUM(status = 'failed'), 0) AS failed FROM outbox",
        readsFrom: {_db.outbox},
      )
      .map((r) => (r.read<int>('waiting'), r.read<int>('failed')))
      .watchSingle();

  /// Refused changes, oldest first.
  Stream<List<SyncIssue>> watchIssues() => engine.queue.watchFailed().map(
    (items) => [
      for (final i in items)
        SyncIssue(
          seq: i.seq,
          entity: SyncEntity.values.firstWhere(
            (e) => e.wire == i.entity,
            orElse: () => SyncEntity.expense,
          ),
          op: SyncOp.values.asNameMap()[i.op] ?? SyncOp.upsert,
          recordId: i.recordId,
          groupId: i.groupId,
          code: i.lastError ?? 'REJECTED',
          attempts: i.attempts,
          createdAt: DateTime.tryParse(i.createdAt)?.toUtc(),
          targetType: _payloadText(i.payload, 'target_type'),
          targetId: _payloadText(i.payload, 'target_id'),
        ),
    ],
  );

  static String? _payloadText(String payload, String key) {
    try {
      final v = (jsonDecode(payload) as Map<String, Object?>)[key];
      return v is String ? v : null;
    } on Object {
      return null;
    }
  }

  /// True while anything on this phone is not on the server yet (rule 3 marker on overall balances).
  Stream<bool> watchAnyUnsynced() => _db
      .customSelect(
        "SELECT EXISTS (SELECT 1 FROM outbox "
        "UNION ALL SELECT 1 FROM expenses WHERE sync_state <> 'synced' "
        "UNION ALL SELECT 1 FROM payments WHERE sync_state <> 'synced' "
        "UNION ALL SELECT 1 FROM group_members WHERE sync_state <> 'synced' "
        "UNION ALL SELECT 1 FROM \"groups\" WHERE sync_state <> 'synced') AS u",
        readsFrom: {_db.outbox, _db.expenses, _db.payments, _db.groupMembers, _db.groups},
      )
      .map((r) => r.read<bool>('u'))
      .watchSingle();

  /// True when changes or photos still have to go up (the app schedules a background run on pause).
  Future<bool> hasWaiting() async {
    final r = await _db
        .customSelect(
          "SELECT EXISTS (SELECT 1 FROM outbox WHERE status <> 'failed' "
          'UNION ALL SELECT 1 FROM pending_uploads WHERE attempts < ?) AS w',
          variables: [Variable<int>(UploadQueue.skipAfter)],
          readsFrom: {_db.outbox, _db.pendingUploads},
        )
        .getSingle();
    return r.read<bool>('w');
  }

  /// Group ids with a row not on the server yet (Groups home cards, one query for all cards).
  Stream<Set<String>> watchUnsyncedGroupIds() => _db
      .customSelect(
        "SELECT group_id AS g FROM expenses WHERE sync_state <> 'synced' "
        "UNION SELECT group_id FROM payments WHERE sync_state <> 'synced' "
        "UNION SELECT group_id FROM group_members WHERE sync_state <> 'synced' "
        "UNION SELECT id FROM \"groups\" WHERE sync_state <> 'synced'",
        readsFrom: {_db.expenses, _db.payments, _db.groupMembers, _db.groups},
      )
      .map((r) => r.read<String>('g'))
      .watch()
      .map((ids) => ids.toSet());

  /// True while a row of the group is not on the server yet (group cards, balances).
  Stream<bool> watchGroupUnsynced(String groupId) => repos.watchGroupUnsynced(_db, groupId);

  /// "Sync now" / pull-to-refresh. Never throws; the outcome shows in [watchStatus].
  Future<void> syncNow() => engine.sync();

  /// Count of local edits that lost to a newer server edit, per push (one-time snackbar, 04 §3).
  Stream<int> get superseded => engine.superseded;

  /// Sync issues → retry: back in the queue, then sync.
  Future<void> retry(int seq) async {
    await engine.queue.retry(seq);
    await engine.sync();
  }

  /// Photos waiting to go up, skipped ones first.
  Stream<List<SyncUpload>> watchUploads() =>
      (_db.select(_db.pendingUploads)
            ..orderBy([(u) => OrderingTerm.desc(u.attempts), (u) => OrderingTerm.asc(u.id)]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                SyncUpload(id: r.id, bucket: r.bucket, recordId: r.recordId, attempts: r.attempts),
            ],
          );

  /// A skipped photo gets a fresh set of tries, then sync.
  Future<void> retryUpload(String id) async {
    await (_db.update(
      _db.pendingUploads,
    )..where((u) => u.id.equals(id))).write(const PendingUploadsCompanion(attempts: Value(0)));
    await engine.sync();
  }

  /// Sync issues → discard: drops the local change; the next pull brings the server copy back.
  Future<void> discard(int seq) async {
    await engine.queue.discard(seq);
    await engine.sync();
  }

  /// Sign-out (04 §7): send waiting changes first, best effort within [timeout]. True when nothing is left.
  Future<bool> pushBeforeSignOut({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      await engine.push().timeout(timeout);
    } on Exception catch (e) {
      _log.info('sign-out push incomplete: $e');
    }
    try {
      final left = await (_db.select(_db.outbox)..limit(1)).get();
      return left.isEmpty;
    } on Exception {
      return false;
    }
  }

  /// Deletes every local row (sign-out, account deletion).
  Future<void> wipeLocal() => _db.wipe();

  static const ownerKey = 'owner';

  /// After a sign-in: the local database belongs to [userId]. A database kept by a 401 sign-out (04 §7) that
  /// belongs to someone else is wiped first; true when that happened (the caller wipes photo files too).
  Future<bool> adoptOwner(String userId) async {
    final owner = await engine.dao.meta(ownerKey);
    if (owner == userId) return false;
    final other = owner != null;
    if (other) {
      _log.info('local data of another account found: wiping');
      await _db.wipe();
    }
    await engine.dao.setMeta(ownerKey, userId);
    return other;
  }
}
