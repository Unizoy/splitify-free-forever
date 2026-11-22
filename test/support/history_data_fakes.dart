import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/history_remote.dart';
import 'package:splitify/data/sync/row_codec.dart';

/// Scripted [HistoryRemote]: serves [rows] like PostgREST would (one record, `seq > afterSeq`, oldest first)
/// and records every call. Set [error] to make every call fail.
class FakeHistoryRemote implements HistoryRemote {
  final rows = <Map<String, Object?>>[];
  final calls = <({String recordId, int afterSeq})>[];
  Object? error;

  @override
  Future<List<Map<String, Object?>>> versions(String recordId, {int afterSeq = 0}) async {
    calls.add((recordId: recordId, afterSeq: afterSeq));
    if (error != null) throw error!;
    return [
      for (final r in rows)
        if (r['record_id'] == recordId && (r['seq']! as int) > afterSeq) r,
    ]..sort((a, b) => (a['seq']! as int).compareTo(b['seq']! as int));
  }
}

/// A server `record_versions` row (snake_case JSON, snapshot as a map).
Map<String, Object?> versionRow(
  int id, {
  required int seq,
  String recordId = 'e1',
  String groupId = 'g1',
  String table = 'expenses',
  String op = 'update',
  Map<String, Object?>? snapshot,
  String? changedBy = 'u1',
  String changedAt = '2026-11-20T10:00:00Z',
}) => {
  'id': id,
  'table_name': table,
  'record_id': recordId,
  'group_id': groupId,
  'op': op,
  'snapshot':
      snapshot ??
      {
        'description': 'Dinner',
        'total': 10000,
        'currency': 'INR',
        'date': '2026-11-20',
        'category': 'food.dining',
        'payers': {'m1': 10000},
        'shares': {'m1': 5000, 'm2': 5000},
        'split_kind': 'equal',
      },
  'changed_by': changedBy,
  'changed_at': changedAt,
  'client_updated_at': changedAt,
  'seq': seq,
};

/// Inserts a plain row (server-shaped JSON) into [table] of [db].
Future<void> putRow(AppDatabase db, String table, Map<String, Object?> row) {
  final t = tableNamed(db, table);
  return insertRaw(db, t, columnValues(t, row), replace: true);
}

Map<String, Object?> memberRow(
  String id, {
  String groupId = 'g1',
  String? userId,
  String name = 'M',
  int position = 0,
  String? deletedAt,
}) => {
  'id': id,
  'group_id': groupId,
  'user_id': userId,
  'display_name': name,
  'position': position,
  'deleted_at': deletedAt,
};

Map<String, Object?> expenseRow(
  String id, {
  String groupId = 'g1',
  String description = 'Dinner',
  int total = 10000,
  String? deletedAt,
  String? deletedBy,
  int seq = 1,
  String syncState = 'synced',
}) => {
  'id': id,
  'group_id': groupId,
  'description': description,
  'date': '2026-11-20',
  'currency': 'INR',
  'total': total,
  'payers': {'m1': total},
  'shares': {'m1': total},
  'deleted_at': deletedAt,
  'deleted_by': deletedBy,
  'seq': seq,
  'sync_state': syncState,
};

Map<String, Object?> paymentRow(
  String id, {
  String groupId = 'g1',
  String? deletedAt,
  String? deletedBy,
  int seq = 1,
  String syncState = 'synced',
}) => {
  'id': id,
  'group_id': groupId,
  'from_member': 'm1',
  'to_member': 'm2',
  'amount': 5000,
  'currency': 'INR',
  'date': '2026-11-20',
  'deleted_at': deletedAt,
  'deleted_by': deletedBy,
  'seq': seq,
  'sync_state': syncState,
};

Map<String, Object?> commentRow(
  String id, {
  String groupId = 'g1',
  String targetId = 'e1',
  String targetType = 'expense',
  String body = 'hi',
  String? createdBy,
  String createdAt = '2026-11-20T10:00:00Z',
  String? deletedAt,
  String syncState = 'synced',
}) => {
  'id': id,
  'group_id': groupId,
  'target_type': targetType,
  'target_id': targetId,
  'body': body,
  'created_by': createdBy,
  'created_at': createdAt,
  'deleted_at': deletedAt,
  'sync_state': syncState,
};
