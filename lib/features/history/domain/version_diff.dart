import 'package:flutter/foundation.dart';
import 'package:splitify/core/money/money.dart';

/// Edit-history diff builder (phase 12 T1, spec 08 §20, TC-20-02).
///
/// Turns the ordered `record_versions` rows of one expense or payment into
/// timeline entries. Values stay display-neutral: money is [Money], dates are
/// UTC dates, members are ids (the UI resolves names), text stays raw.

/// Which table a version belongs to (`record_versions.table_name`).
enum HistoryRecordKind { expense, payment }

/// Timeline operation (`record_versions.op`; `insert` → [create]).
enum HistoryOp { create, update, delete, restore, conflictLost }

/// A field that can change between versions.
///
/// Value types in [FieldChange.oldValue] / [FieldChange.newValue]:
/// [amount] → [Money] (total + currency; a currency change shows here);
/// [date] → [DateTime] (UTC date); [payers] / [shares] → `Map<String, Money>`;
/// [splitValues] → `Map<String, String>`; [fromMember] / [toMember] → member
/// id; everything else → [String]. A missing value is `null`.
enum HistoryField {
  description,
  amount,
  date,
  category,
  payers,
  shares,
  splitKind,
  splitValues,
  notes,
  receipt,
  kind,
  method,
  fromMember,
  toMember,
}

/// One pulled `record_versions` row (or its Drift mirror).
@immutable
class VersionRecord {
  const VersionRecord({
    required this.seq,
    required this.op,
    required this.snapshot,
    required this.changedAt,
    this.changedBy,
  });

  /// Builds from a PostgREST / RPC row (`snake_case` keys).
  factory VersionRecord.fromJson(Map<String, Object?> json) => VersionRecord(
    seq: _int(json['seq'])!,
    op: json['op']! as String,
    snapshot: (json['snapshot']! as Map).cast<String, Object?>(),
    changedAt: DateTime.parse(json['changed_at']! as String).toUtc(),
    changedBy: json['changed_by'] as String?,
  );

  final int seq;
  final String op;
  final Map<String, Object?> snapshot;
  final DateTime changedAt;
  final String? changedBy;
}

/// Per-member change inside [HistoryField.payers], [HistoryField.shares] or
/// [HistoryField.splitValues]. `null` = member not in that version.
@immutable
class MemberValueChange {
  const MemberValueChange(this.memberId, this.oldValue, this.newValue);

  final String memberId;
  final Object? oldValue;
  final Object? newValue;

  @override
  bool operator ==(Object other) =>
      other is MemberValueChange &&
      other.memberId == memberId &&
      other.oldValue == oldValue &&
      other.newValue == newValue;

  @override
  int get hashCode => Object.hash(memberId, oldValue, newValue);

  @override
  String toString() => 'MemberValueChange($memberId: $oldValue → $newValue)';
}

/// One changed field. [members] lists changed members (sorted by id) for map
/// fields and is empty otherwise.
@immutable
class FieldChange {
  const FieldChange(this.field, this.oldValue, this.newValue, [this.members = const []]);

  final HistoryField field;
  final Object? oldValue;
  final Object? newValue;
  final List<MemberValueChange> members;

  @override
  String toString() => 'FieldChange(${field.name}: $oldValue → $newValue)';
}

/// One timeline row.
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.seq,
    required this.op,
    required this.changedAt,
    required this.changedBy,
    required this.deleted,
    required this.changes,
  });

  final int seq;
  final HistoryOp op;
  final DateTime changedAt;

  /// Auth user id of the editor (`null` for system writes).
  final String? changedBy;

  /// Whether the record is deleted in this version's snapshot.
  final bool deleted;

  /// Fields changed against the applied version before it. For [HistoryOp.create]
  /// every present field with `oldValue == null`.
  final List<FieldChange> changes;

  /// A version that lost a conflict: shown muted, "Not applied (a newer edit
  /// won)", and never the baseline for later diffs.
  bool get muted => op == HistoryOp.conflictLost;
}

/// Builds the timeline for one record from versions in `seq` order (oldest
/// first). Conflict versions are diffed against the applied version before
/// them; the next applied version is diffed against the applied one too.
List<HistoryEntry> buildHistory(HistoryRecordKind kind, List<VersionRecord> versions) {
  final out = <HistoryEntry>[];
  Map<HistoryField, Object?>? applied;
  for (final v in versions) {
    final op = _op(v.op);
    final now = _fields(kind, v.snapshot);
    out.add(
      HistoryEntry(
        seq: v.seq,
        op: op,
        changedAt: v.changedAt,
        changedBy: v.changedBy,
        deleted: _deleted(v.snapshot),
        changes: _diff(applied ?? const {}, now),
      ),
    );
    if (op != HistoryOp.conflictLost) applied = now;
  }
  return out;
}

HistoryOp _op(String op) => switch (op) {
  'insert' => HistoryOp.create,
  'update' => HistoryOp.update,
  'delete' => HistoryOp.delete,
  'restore' => HistoryOp.restore,
  'conflict_lost' => HistoryOp.conflictLost,
  _ => throw FormatException('Unknown record_versions op', op),
};

bool _deleted(Map<String, Object?> s) => s['deleted_at'] != null || s['deleted'] == true;

Map<HistoryField, Object?> _fields(HistoryRecordKind kind, Map<String, Object?> s) {
  final currency = s['currency'] as String?;
  return switch (kind) {
    HistoryRecordKind.expense => {
      HistoryField.description: s['description'],
      HistoryField.amount: _money(s['total'], currency),
      HistoryField.date: _date(s['date']),
      HistoryField.category: s['category'],
      HistoryField.payers: _moneyMap(s['payers'], currency),
      HistoryField.shares: _moneyMap(s['shares'], currency),
      HistoryField.splitKind: s['split_kind'],
      HistoryField.splitValues: _textMap(s['split_values']),
      HistoryField.notes: s['notes'],
      HistoryField.receipt: s['receipt_path'],
      HistoryField.kind: s['kind'],
    },
    HistoryRecordKind.payment => {
      HistoryField.amount: _money(s['amount'], currency),
      HistoryField.date: _date(s['date']),
      HistoryField.fromMember: s['from_member'],
      HistoryField.toMember: s['to_member'],
      HistoryField.method: s['method'],
      HistoryField.notes: s['note'],
    },
  };
}

List<FieldChange> _diff(Map<HistoryField, Object?> before, Map<HistoryField, Object?> after) {
  final out = <FieldChange>[];
  for (final MapEntry(key: field, value: now) in after.entries) {
    final was = before[field];
    if (was is Map || now is Map) {
      final members = _memberDiff(_asMap(was), _asMap(now));
      if (members.isNotEmpty) out.add(FieldChange(field, was, now, members));
    } else if (was != now) {
      out.add(FieldChange(field, was, now));
    }
  }
  return out;
}

Map<String, Object?> _asMap(Object? v) => v is Map<String, Object?> ? v : const {};

List<MemberValueChange> _memberDiff(Map<String, Object?> before, Map<String, Object?> after) {
  final ids = {...before.keys, ...after.keys}.toList()..sort();
  return [
    for (final id in ids)
      if (before[id] != after[id]) MemberValueChange(id, before[id], after[id]),
  ];
}

int? _int(Object? v) => switch (v) {
  final int i => i,
  final String s => int.parse(s),
  null => null,
  _ => throw FormatException('Expected integer minor units', v),
};

Money? _money(Object? minor, String? currency) {
  final m = _int(minor);
  return m == null || currency == null ? null : Money(m, currency);
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  final d = DateTime.parse(v as String);
  return DateTime.utc(d.year, d.month, d.day);
}

Map<String, Money>? _moneyMap(Object? v, String? currency) {
  if (v is! Map || currency == null) return null;
  return {for (final e in v.entries) e.key as String: Money(_int(e.value)!, currency)};
}

Map<String, String>? _textMap(Object? v) {
  if (v is! Map) return null;
  return {for (final e in v.entries) e.key as String: '${e.value}'};
}
