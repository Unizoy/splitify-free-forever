import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/data/repositories/history_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;

/// One deleted expense or payment (group → settings → Deleted items, 08 #20).
final class DeletedItem {
  const DeletedItem({
    required this.id,
    required this.deletedAt,
    this.expense,
    this.payment,
    this.deletedByName,
    this.deletedByMe = false,
  });

  final String id;

  /// When it was deleted (UTC ISO text as stored).
  final String deletedAt;
  final LocalExpense? expense;
  final LocalPayment? payment;

  /// Who deleted it, when known; null for an unknown account.
  final String? deletedByName;

  /// Deleted on this phone (not synced yet) or by the signed-in user.
  final bool deletedByMe;

  bool get unsynced => (expense?.syncState ?? payment!.syncState) != SyncState.synced;
}

/// Everything deleted in the group plus member names, most recently deleted first.
typedef DeletedItemsView = ({
  List<DeletedItem> items,
  Map<String, String> memberNames,
  String? meMemberId,
});

final _deletedExpensesProvider = StreamProvider.autoDispose.family<List<LocalExpense>, String>(
  (ref, groupId) => ref.watch(expensesRepositoryProvider).watchDeleted(groupId),
);

final _deletedPaymentsProvider = StreamProvider.autoDispose.family<List<LocalPayment>, String>(
  (ref, groupId) => ref.watch(paymentsRepositoryProvider).watchDeleted(groupId),
);

final _membersProvider = StreamProvider.autoDispose.family<List<LocalMember>, String>(
  (ref, groupId) => ref.watch(expensesRepositoryProvider).watchAllMembers(groupId),
);

final deletedItemsProvider = Provider.autoDispose.family<AsyncValue<DeletedItemsView>, String>((
  ref,
  groupId,
) {
  final e = ref.watch(_deletedExpensesProvider(groupId));
  final p = ref.watch(_deletedPaymentsProvider(groupId));
  final m = ref.watch(_membersProvider(groupId));
  for (final v in [e, p, m]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!e.hasValue || !p.hasValue || !m.hasValue) return const AsyncLoading();
  final uid = ref.watch(currentUserIdProvider);
  final members = m.requireValue;
  final byUser = {
    for (final x in members)
      if (x.userId != null) x.userId!: x.displayName,
  };
  DeletedItem item(
    String id,
    String at,
    String? by, {
    LocalExpense? expense,
    LocalPayment? payment,
  }) {
    // A delete made on this phone has no deleted_by until the server has it.
    final mine = by == null || by == uid;
    return DeletedItem(
      id: id,
      deletedAt: at,
      expense: expense,
      payment: payment,
      deletedByMe: mine,
      deletedByName: mine ? null : byUser[by],
    );
  }

  final items = [
    for (final x in e.requireValue) item(x.id, x.deletedAt!, x.deletedBy, expense: x),
    for (final x in p.requireValue) item(x.id, x.deletedAt!, x.deletedBy, payment: x),
  ]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  return AsyncData((
    items: items,
    memberNames: {for (final x in members) x.id: x.displayName},
    meMemberId: members
        .where((x) => uid != null && x.userId == uid && x.deletedAt == null)
        .map((x) => x.id)
        .firstOrNull,
  ));
});

/// Restore (op `restore` through the outbox; the server writes `*_restored` activity and a version).
final deletedItemActionsProvider = Provider<DeletedItemActions>(DeletedItemActions.new);

class DeletedItemActions {
  DeletedItemActions(this._ref);

  final Ref _ref;

  Future<void> restore(DeletedItem item) {
    final e = item.expense;
    if (e != null) return _ref.read(expensesRepositoryProvider).restore(e.id, e.groupId);
    final p = item.payment!;
    return _ref.read(paymentsRepositoryProvider).restore(p.id, p.groupId);
  }
}
