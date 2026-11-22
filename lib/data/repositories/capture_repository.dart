import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/device/capture_bridge.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/payment_capture.dart';
import 'package:splitify/domain/rules/capture_validator.dart';

final _log = Logger('capture');

/// "Payments to add" on this phone (phase 18b, S-224): imports what the native bubble caught into the
/// local-only `payment_captures` table (never synced, no outbox — nothing reaches the server until the user
/// saves an expense) and forgets rows when they are added, dismissed or older than 7 days.
class CaptureRepository {
  CaptureRepository(this.db, this.bridge, this.clock);

  final AppDatabase db;
  final CaptureBridge bridge;
  final Clock clock;
  Future<int>? _running;

  /// Pending captures, newest first (expired ones are hidden even before the next purge).
  Stream<List<PaymentCapture>> watchPending() {
    final since = _cutoff();
    return (db.select(db.paymentCaptures)
          ..where((c) => c.capturedAt.isBiggerOrEqualValue(since))
          ..orderBy([(c) => OrderingTerm.desc(c.capturedAt), (c) => OrderingTerm.asc(c.id)]))
        .watch()
        .map((rows) => [for (final r in rows) ?_entity(r)]);
  }

  Future<PaymentCapture?> get(String id) async {
    final r = await (db.select(
      db.paymentCaptures,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return r == null ? null : _entity(r);
  }

  /// Pulls new captures and dismissals from the native store (start, resume, capture link). Returns how many
  /// captures were stored. Concurrent calls share one run.
  Future<int> importNow() => _running ??= _import().whenComplete(() => _running = null);

  Future<int> _import() async {
    final now = clock.now().toUtc();
    final export = await bridge.export();
    final ok = <PaymentCapture>[];
    final bad = <String>[];
    for (final raw in export.captures) {
      final c = CaptureValidator.parse(raw, now: now);
      if (c != null) {
        ok.add(c);
      } else if (raw is Map && raw['id'] is String) {
        bad.add(raw['id']! as String);
      }
    }
    await db.transaction(() async {
      for (final c in ok) {
        await db.into(db.paymentCaptures).insertOnConflictUpdate(_row(c));
      }
      if (export.dismissed.isNotEmpty) {
        await (db.delete(db.paymentCaptures)..where((c) => c.id.isIn(export.dismissed))).go();
      }
      await (db.delete(
        db.paymentCaptures,
      )..where((c) => c.capturedAt.isSmallerThanValue(_cutoff()))).go();
    });
    if (bad.isNotEmpty) _log.warning('dropped ${bad.length} invalid capture(s)');
    if (ok.isNotEmpty || bad.isNotEmpty || export.dismissed.isNotEmpty) {
      await bridge.ack(captures: [for (final c in ok) c.id, ...bad], dismissed: export.dismissed);
    }
    return ok.length;
  }

  /// The expense was saved: the capture is done.
  Future<void> remove(String id) =>
      (db.delete(db.paymentCaptures)..where((c) => c.id.equals(id))).go();

  /// "Not now" from the list (also drops a copy the native side may still hold).
  Future<void> dismiss(String id) async {
    await remove(id);
    await bridge.dismiss(id);
  }

  /// Up to [limit] groups and friends, most recently used first (an expense added there, else the group's own
  /// creation): the bubble's chips. A friend chip carries the friend's name.
  Future<List<CaptureChip>> recentChips({required String? myUserId, int limit = 3}) async {
    final rows = await db
        .customSelect(
          'SELECT g.id AS id, g.type AS type, '
          'CASE WHEN g.type = \'direct\' THEN (SELECT m.display_name FROM group_members m '
          'WHERE m.group_id = g.id AND m.deleted_at IS NULL AND m.user_id IS NOT ?1 '
          'ORDER BY m.position LIMIT 1) ELSE g.name END AS name, '
          'MAX(COALESCE(e.created_at, g.created_at, \'\')) AS last '
          'FROM "groups" g LEFT JOIN expenses e ON e.group_id = g.id AND e.deleted_at IS NULL '
          'WHERE g.deleted_at IS NULL AND g.archived_at IS NULL '
          'GROUP BY g.id ORDER BY last DESC, g.id LIMIT ?2',
          variables: [Variable<String>(myUserId), Variable<int>(limit)],
          readsFrom: {db.groups, db.groupMembers, db.expenses},
        )
        .get();
    return [
      for (final r in rows)
        if ((r.readNullable<String>('name') ?? '').trim().isNotEmpty)
          (
            id: r.read<String>('id'),
            name: r.read<String>('name').trim(),
            friend: r.read<String>('type') == 'direct',
          ),
    ];
  }

  String _cutoff() => clock.now().toUtc().subtract(CaptureValidator.keep).toIso8601String();

  static LocalPaymentCapture _row(PaymentCapture c) => LocalPaymentCapture(
    id: c.id,
    amount: c.amount,
    currency: c.currency,
    payee: c.payee,
    note: c.note,
    ref: c.ref,
    appPackage: c.appPackage,
    appName: c.appName,
    source: c.source.name,
    capturedAt: c.capturedAt.toUtc().toIso8601String(),
  );

  static PaymentCapture? _entity(LocalPaymentCapture r) {
    final source = CaptureSource.fromWire(r.source);
    final at = DateTime.tryParse(r.capturedAt);
    if (source == null || at == null) return null;
    return PaymentCapture(
      id: r.id,
      amount: r.amount,
      currency: r.currency,
      payee: r.payee,
      note: r.note,
      ref: r.ref,
      appPackage: r.appPackage,
      appName: r.appName,
      source: source,
      capturedAt: at.toUtc(),
    );
  }
}
