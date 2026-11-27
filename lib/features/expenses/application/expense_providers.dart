import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';

/// One expense as the group list and the detail screen show it.
final class ExpenseView {
  const ExpenseView({
    required this.expense,
    required this.paid,
    required this.owed,
    required this.names,
    this.meId,
    this.userNames = const {},
  });

  final LocalExpense expense;

  /// Minor units paid / owed per member id.
  final Map<String, int> paid;
  final Map<String, int> owed;

  /// Display names by member id (removed members too).
  final Map<String, String> names;

  /// The viewer's member id in this group, if any.
  final String? meId;

  /// Display names by account id (who added or edited the expense).
  final Map<String, String> userNames;

  String nameOf(String memberId) => names[memberId] ?? '';

  /// The single payer, or null when several people paid.
  String? get singlePayer => paid.length == 1 ? paid.keys.first : null;

  /// The viewer's `paid − owed`: positive = lent, negative = borrowed.
  int get myNet => meId == null ? 0 : (paid[meId] ?? 0) - (owed[meId] ?? 0);

  /// The viewer paid or owes something in this expense.
  bool get involved => meId != null && ((paid[meId] ?? 0) != 0 || (owed[meId] ?? 0) != 0);

  bool get unsynced => expense.syncState != SyncState.synced;

  /// Soft-deleted (D-034 A4): the detail page shows it read-only with Restore.
  bool get deleted => expense.deletedAt != null;

  /// A loan (`kind = 'iou'`, #11): one lender, one borrower, not spending.
  bool get isLoan => expense.kind == 'iou';

  /// Lender and borrower of a loan (null for other expenses).
  String? get lender => isLoan ? paid.keys.firstOrNull : null;
  String? get borrower => isLoan ? owed.keys.firstOrNull : null;
}

Map<String, int> _ints(String? json) {
  if (json == null) return const {};
  final m = jsonDecode(json) as Map<String, Object?>;
  return {for (final e in m.entries) e.key: e.value! as int};
}

/// Builds the views for [expenses] (newest first, as the repository streams them).
List<ExpenseView> expenseViews(
  List<LocalExpense> expenses,
  List<LocalMember> members,
  String? userId,
) {
  final names = {for (final m in members) m.id: m.displayName};
  final userNames = {
    for (final m in members)
      if (m.userId != null) m.userId!: m.displayName,
  };
  final meId = members
      .where((m) => userId != null && m.userId == userId && m.deletedAt == null)
      .map((m) => m.id)
      .firstOrNull;
  // Paid / owed rows follow the group's member order, like the editor (final QA, S-252).
  final order = {for (var i = 0; i < members.length; i++) members[i].id: i};
  Map<String, int> ordered(Map<String, int> m) => {
    for (final k
        in m.keys.toList()
          ..sort((a, b) => (order[a] ?? order.length).compareTo(order[b] ?? order.length)))
      k: m[k]!,
  };
  return [
    for (final e in expenses)
      ExpenseView(
        expense: e,
        paid: ordered(_ints(e.payers)),
        owed: ordered(_ints(e.shares)),
        names: names,
        meId: meId,
        userNames: userNames,
      ),
  ];
}

final _groupExpensesProvider = StreamProvider.autoDispose.family<List<LocalExpense>, String>(
  (ref, groupId) => ref.watch(expensesRepositoryProvider).watchForGroup(groupId),
);

final _groupMembersProvider = StreamProvider.autoDispose.family<List<LocalMember>, String>(
  (ref, groupId) => ref.watch(expensesRepositoryProvider).watchAllMembers(groupId),
);

final _expenseProvider = StreamProvider.autoDispose.family<LocalExpense?, String>(
  (ref, id) => ref.watch(expensesRepositoryProvider).watchOne(id),
);

/// The group's live expenses for the Expenses tab (#13, 07 §2), newest first.
final groupExpenseViewsProvider = Provider.autoDispose
    .family<AsyncValue<List<ExpenseView>>, String>((ref, groupId) {
      final uid = ref.watch(currentUserIdProvider);
      final e = ref.watch(_groupExpensesProvider(groupId));
      final m = ref.watch(_groupMembersProvider(groupId));
      for (final v in [e, m]) {
        if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
      }
      if (!e.hasValue || !m.hasValue) return const AsyncLoading();
      return AsyncData(expenseViews(e.requireValue, m.requireValue, uid));
    });

/// One expense (detail screen), a deleted one too (D-034 A4: opened from Activity it offers Restore);
/// data(null) when it is not on this phone.
final expenseViewProvider = Provider.autoDispose.family<AsyncValue<ExpenseView?>, String>((
  ref,
  id,
) {
  final e = ref.watch(_expenseProvider(id));
  if (!e.hasValue) return e.hasError ? AsyncError(e.error!, e.stackTrace!) : const AsyncLoading();
  final expense = e.value;
  if (expense == null) return const AsyncData(null);
  final uid = ref.watch(currentUserIdProvider);
  return ref
      .watch(_groupMembersProvider(expense.groupId))
      .whenData((m) => expenseViews([expense], m, uid).first);
});

/// Delete (soft, with undo) and restore (#13, rule 9); replace or remove the receipt photo (#29).
final expenseActionsProvider = Provider<ExpenseActions>(ExpenseActions.new);

class ExpenseActions {
  ExpenseActions(this._ref);

  final Ref _ref;

  Future<void> delete(LocalExpense e) =>
      _ref.read(expensesRepositoryProvider).delete(e.id, e.groupId);

  Future<void> restore(LocalExpense e) =>
      _ref.read(expensesRepositoryProvider).restore(e.id, e.groupId);

  /// New receipt photo for a saved expense (only `receipt_path` changes; the old photo stays on the
  /// server for the history, or is forgotten when it never went up).
  Future<void> replaceReceipt(LocalExpense e, PreparedImage image) async {
    final media = _ref.read(mediaRepositoryProvider);
    final old = e.receiptPath;
    if (old != null) await media.discardPending(MediaBuckets.receipts, old);
    await media.saveExpenseWithReceipt(e.groupId, e.id, const {}, image);
  }

  Future<void> removeReceipt(LocalExpense e) async {
    final old = e.receiptPath;
    if (old != null) {
      await _ref.read(mediaRepositoryProvider).discardPending(MediaBuckets.receipts, old);
    }
    await _ref.read(expensesRepositoryProvider).save(e.groupId, {'receipt_path': null}, id: e.id);
  }
}

/// The group an expense belongs to (detail hero cover, editor header).
final expenseGroupProvider = StreamProvider.autoDispose.family<LocalGroup?, String>(
  (ref, id) => ref.watch(groupsRepositoryProvider).watchOne(id),
);
