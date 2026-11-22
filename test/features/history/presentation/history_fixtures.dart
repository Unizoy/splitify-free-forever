// Shared sample data for the history, deleted-items and comment screens (widget tests + goldens).
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/history/application/deleted_items_providers.dart';
import 'package:splitify/features/history/application/history_providers.dart';
import 'package:splitify/features/history/domain/version_diff.dart';

import '../../expenses/expense_fixtures.dart';

const expenseTarget = (kind: HistoryRecordKind.expense, id: 'e1');
const paymentTarget = (kind: HistoryRecordKind.payment, id: 'p1');

/// Account ids: u1 is the signed-in user (member m1).
const userNames = {'u1': 'Mohit Bindal', 'u2': 'Asha Rao', 'u3': 'Rahul Mehta'};

VersionRecord expenseVersion(
  int seq,
  String op, {
  String by = 'u1',
  String at = '2026-11-20T10:00:00Z',
  String description = 'Dinner at Thalassa',
  int total = 240000,
  Map<String, int>? shares,
  String splitKind = 'equal',
  bool deleted = false,
}) => VersionRecord(
  seq: seq,
  op: op,
  changedBy: by,
  changedAt: DateTime.parse(at),
  snapshot: {
    'description': description,
    'total': total,
    'currency': 'INR',
    'date': '2026-11-20',
    'category': 'food.dining_out',
    'payers': {'m1': total},
    'shares': shares ?? {for (final m in ids) m: total ~/ 4},
    'split_kind': splitKind,
    if (deleted) 'deleted_at': '2026-11-21T08:00:00Z',
  },
);

/// Create, an edit (amount, description, per-member split), a delete, a restore and a conflict_lost entry.
List<VersionRecord> fullExpenseVersions() => [
  expenseVersion(1, 'insert'),
  expenseVersion(
    2,
    'update',
    by: 'u2',
    at: '2026-11-20T12:30:00Z',
    description: 'Dinner at Thalassa (4 people)',
    total: 200000,
    shares: const {'m1': 80000, 'm2': 40000, 'm3': 40000, 'm4': 40000},
    splitKind: 'exact',
  ),
  expenseVersion(
    3,
    'delete',
    at: '2026-11-21T08:00:00Z',
    description: 'Dinner at Thalassa (4 people)',
    total: 200000,
    shares: const {'m1': 80000, 'm2': 40000, 'm3': 40000, 'm4': 40000},
    splitKind: 'exact',
    deleted: true,
  ),
  expenseVersion(
    4,
    'restore',
    by: 'u2',
    at: '2026-11-21T09:00:00Z',
    description: 'Dinner at Thalassa (4 people)',
    total: 200000,
    shares: const {'m1': 80000, 'm2': 40000, 'm3': 40000, 'm4': 40000},
    splitKind: 'exact',
  ),
  expenseVersion(
    5,
    'conflict_lost',
    by: 'u3',
    at: '2026-11-21T09:30:00Z',
    description: 'Dinner at Thalassa (4 people)',
    total: 180000,
    shares: const {'m1': 45000, 'm2': 45000, 'm3': 45000, 'm4': 45000},
  ),
];

VersionRecord paymentVersion(
  int seq,
  String op, {
  String by = 'u3',
  String at = '2026-11-20T10:00:00Z',
  int amount = 50000,
  String method = 'cash',
}) => VersionRecord(
  seq: seq,
  op: op,
  changedBy: by,
  changedAt: DateTime.parse(at),
  snapshot: {
    'amount': amount,
    'currency': 'INR',
    'date': '2026-11-20',
    'from_member': 'm3',
    'to_member': 'm2',
    'method': method,
  },
);

List<VersionRecord> paymentVersions() => [
  paymentVersion(1, 'insert'),
  paymentVersion(2, 'update', by: 'u2', at: '2026-11-20T15:00:00Z', amount: 60000, method: 'upi'),
];

LocalPayment samplePayment({
  String id = 'p1',
  int amount = 60000,
  String from = 'm3',
  String to = 'm2',
  String syncState = SyncState.synced,
  String? deletedAt,
}) => LocalPayment(
  id: id,
  groupId: gid,
  fromMember: from,
  toMember: to,
  amount: amount,
  currency: 'INR',
  date: '2026-11-20',
  method: 'upi',
  createdAt: '2026-11-20T10:00:00Z',
  createdBy: 'u3',
  deletedAt: deletedAt,
  seq: 1,
  syncState: syncState,
);

/// A [HistoryView] built like the provider does, from [versions] (oldest first).
HistoryView historyView({
  HistoryTarget target = expenseTarget,
  List<VersionRecord>? versions,
  bool pending = false,
  LocalExpense? expense,
  LocalPayment? payment,
}) {
  final isExpense = target.kind == HistoryRecordKind.expense;
  return HistoryView(
    target: target,
    record: (
      groupId: gid,
      seq: 1,
      pending: pending,
      expense: isExpense ? (expense ?? sampleExpense()) : null,
      payment: isExpense ? null : (payment ?? samplePayment()),
    ),
    entries: buildHistory(target.kind, versions ?? const []).reversed.toList(),
    memberNames: memberNames,
    userNames: userNames,
    meUserId: 'u1',
    meMemberId: 'm1',
  );
}

LocalComment sampleComment(
  String id,
  String body, {
  String by = 'u2',
  String at = '2026-11-21T08:15:00Z',
  String syncState = SyncState.synced,
}) => LocalComment(
  id: id,
  groupId: gid,
  targetType: 'expense',
  targetId: 'e1',
  body: body,
  createdAt: at,
  createdBy: by,
  seq: 1,
  syncState: syncState,
);

CommentView commentView(LocalComment c, {String? name, String? memberId}) =>
    CommentView(comment: c, mine: c.createdBy == 'u1', authorName: name, authorMemberId: memberId);

/// Asha and Rahul talk, then "me" replies (not synced yet).
List<CommentView> sampleThread() => [
  commentView(
    sampleComment('c1', 'Did we include the service charge?'),
    name: 'Asha Rao',
    memberId: 'm2',
  ),
  commentView(
    sampleComment('c2', 'Yes, it is in the total.', by: 'u3', at: '2026-11-21T08:40:00Z'),
    name: 'Rahul Mehta',
    memberId: 'm3',
  ),
  commentView(
    sampleComment(
      'c3',
      'Great, thanks both!',
      by: 'u1',
      at: '2026-11-21T09:05:00Z',
      syncState: SyncState.pending,
    ),
    name: 'Mohit Bindal',
    memberId: 'm1',
  ),
];

/// Deleted items: an expense deleted by Asha and a payment deleted on this phone.
DeletedItemsView sampleDeleted() => (
  items: [
    DeletedItem(
      id: 'p1',
      deletedAt: '2026-11-21T12:00:00Z',
      payment: samplePayment(deletedAt: '2026-11-21T12:00:00Z', syncState: SyncState.pending),
      deletedByMe: true,
    ),
    DeletedItem(
      id: 'e1',
      deletedAt: '2026-11-20T12:00:00Z',
      expense: sampleExpense(),
      deletedByName: 'Asha Rao',
    ),
  ],
  memberNames: memberNames,
  meMemberId: 'm1',
);
