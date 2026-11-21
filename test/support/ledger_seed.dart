// Row builders and inserts for phase 09 data/application tests (balances, payments, activity).
import 'dart:convert';

import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';

LocalGroup seedGroup({
  String id = 'g1',
  String name = 'Goa trip',
  String type = 'trip',
  String mainCurrency = 'INR',
  bool simplify = false,
  String? archivedAt,
  String? deletedAt,
  String createdAt = '2026-11-01T10:00:00Z',
  int seq = 1,
  String syncState = SyncState.synced,
}) => LocalGroup(
  id: id,
  name: name,
  type: type,
  mainCurrency: mainCurrency,
  coverKind: 'generated',
  simplifyDebts: simplify,
  archivedAt: archivedAt,
  deletedAt: deletedAt,
  createdAt: createdAt,
  seq: seq,
  syncState: syncState,
);

LocalMember seedMember(
  String id, {
  String groupId = 'g1',
  String? name,
  String? userId,
  int position = 0,
  String status = 'active',
  String? deletedAt,
  int seq = 1,
  String syncState = SyncState.synced,
}) => LocalMember(
  id: id,
  groupId: groupId,
  userId: userId,
  displayName: name ?? id.toUpperCase(),
  position: position,
  role: 'member',
  status: status,
  deletedAt: deletedAt,
  seq: seq,
  syncState: syncState,
);

LocalExpense seedExpense(
  String id, {
  String groupId = 'g1',
  String kind = 'expense',
  String description = 'Dinner',
  String date = '2026-11-20',
  String currency = 'INR',
  required int total,
  required Map<String, int> payers,
  required Map<String, int> shares,
  String? createdBy,
  String? deletedAt,
  int seq = 1,
  String syncState = SyncState.synced,
}) => LocalExpense(
  id: id,
  groupId: groupId,
  kind: kind,
  description: description,
  category: 'other.general',
  date: date,
  currency: currency,
  total: total,
  payers: jsonEncode(payers),
  shares: jsonEncode(shares),
  splitKind: 'equal',
  source: 'app',
  createdBy: createdBy,
  deletedAt: deletedAt,
  seq: seq,
  syncState: syncState,
);

LocalPayment seedPayment(
  String id, {
  String groupId = 'g1',
  required String from,
  required String to,
  required int amount,
  String currency = 'INR',
  String date = '2026-11-21',
  String method = 'cash',
  String? note,
  String? deletedAt,
  int seq = 1,
  String syncState = SyncState.synced,
}) => LocalPayment(
  id: id,
  groupId: groupId,
  fromMember: from,
  toMember: to,
  amount: amount,
  currency: currency,
  date: date,
  method: method,
  note: note,
  deletedAt: deletedAt,
  seq: seq,
  syncState: syncState,
);

LocalActivity seedActivity(
  String id,
  String type, {
  String groupId = 'g1',
  String? actorUserId,
  String? actorMemberId,
  String? targetType,
  String? targetId,
  Map<String, Object?> data = const {},
  String createdAt = '2026-11-21T10:00:00Z',
  int seq = 1,
}) => LocalActivity(
  id: id,
  groupId: groupId,
  actorUserId: actorUserId,
  actorMemberId: actorMemberId,
  type: type,
  targetType: targetType,
  targetId: targetId,
  data: jsonEncode(data),
  createdAt: createdAt,
  seq: seq,
);

OutboxItem seedOutbox(
  int seq,
  String entity,
  String op,
  String recordId, {
  String groupId = 'g1',
  Map<String, Object?> payload = const {},
  String createdAt = '2026-11-22T09:00:00Z',
}) => OutboxItem(
  seq: seq,
  mutationId: 'mut-$seq',
  entity: entity,
  op: op,
  recordId: recordId,
  groupId: groupId,
  payload: jsonEncode(payload),
  clientUpdatedAt: createdAt,
  createdAt: createdAt,
  attempts: 0,
  status: OutboxStatus.queued,
);

extension SeedDb on AppDatabase {
  Future<void> seed({
    List<LocalGroup> groups = const [],
    List<LocalMember> members = const [],
    List<LocalExpense> expenses = const [],
    List<LocalPayment> payments = const [],
    List<LocalActivity> activity = const [],
    List<OutboxItem> outbox = const [],
  }) async {
    for (final g in groups) {
      await into(this.groups).insertOnConflictUpdate(g);
    }
    for (final m in members) {
      await into(groupMembers).insertOnConflictUpdate(m);
    }
    for (final e in expenses) {
      await into(this.expenses).insertOnConflictUpdate(e);
    }
    for (final p in payments) {
      await into(this.payments).insertOnConflictUpdate(p);
    }
    for (final a in activity) {
      await into(this.activity).insertOnConflictUpdate(a);
    }
    for (final o in outbox) {
      await into(this.outbox).insertOnConflictUpdate(o);
    }
  }
}
