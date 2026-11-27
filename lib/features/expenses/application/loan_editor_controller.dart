import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';

/// Which loan the form opens: a new one in [groupId] (optionally with [withMember] picked, from a friend
/// page), or the saved [expenseId].
typedef LoanEditorArgs = ({String? groupId, String? expenseId, String? withMember});

/// Thrown when the viewer has no member in the group (cannot say "I lent").
class LoanNotPossible implements Exception {
  const LoanNotPossible();
}

/// Local database only, so failures show at once (no retry).
final loanEditorProvider = AsyncNotifierProvider.autoDispose
    .family<LoanEditorController, LoanDraft, LoanEditorArgs>(
      LoanEditorController.new,
      retry: (_, _) => null,
    );

/// "Record a loan" (#11): loads the group's people (or the saved IOU) and saves through the expenses
/// repository → outbox, offline first.
class LoanEditorController extends AsyncNotifier<LoanDraft> {
  LoanEditorController(this.args);

  final LoanEditorArgs args;

  @override
  Future<LoanDraft> build() async {
    final expenses = ref.read(expensesRepositoryProvider);
    final saved = args.expenseId == null ? null : await expenses.watchOne(args.expenseId!).first;
    if (args.expenseId != null &&
        (saved == null || saved.deletedAt != null || saved.kind != 'iou')) {
      throw const ExpenseNotFound();
    }
    final groupId = saved?.groupId ?? args.groupId;
    if (groupId == null) throw const ExpenseNotFound();
    final group = await ref.read(groupsRepositoryProvider).watchOne(groupId).first;
    if (group == null) throw const ExpenseNotFound();
    final all = await expenses.watchAllMembers(groupId).first;
    final payers = saved == null ? const <String, int>{} : _ints(saved.payers);
    final shares = saved == null ? const <String, int>{} : _ints(saved.shares);
    final people = [
      for (final m in all)
        if (m.deletedAt == null || payers.containsKey(m.id) || shares.containsKey(m.id)) m,
    ];
    final uid = ref.read(currentUserIdProvider);
    final meId = people
        .where((m) => uid != null && m.userId == uid && m.deletedAt == null)
        .map((m) => m.id)
        .firstOrNull;
    final members = [for (final m in people) (id: m.id, name: m.displayName, isMe: m.id == meId)];

    if (saved == null) {
      if (meId == null) throw const LoanNotPossible();
      final others = members.where((m) => m.id != meId).toList();
      final picked = others.any((m) => m.id == args.withMember)
          ? args.withMember
          : (others.length == 1 ? others.first.id : null);
      return LoanDraft(
        groupId: groupId,
        groupName: group.name,
        groupType: group.type,
        currency: group.mainCurrency,
        members: members,
        selfId: meId,
        personId: picked,
        date: ref.read(clockProvider).today(),
      );
    }

    final lender = payers.keys.first;
    final borrower = shares.keys.first;
    final iBorrowed = meId != null && borrower == meId;
    final self = iBorrowed ? borrower : lender;
    return LoanDraft(
      groupId: groupId,
      groupName: group.name,
      groupType: group.type,
      currency: saved.currency.trim(),
      members: members,
      selfId: self,
      selfIsMe: self == meId,
      expenseId: saved.id,
      direction: iBorrowed ? LoanDirection.borrowed : LoanDirection.lent,
      personId: iBorrowed ? lender : borrower,
      amountText: ScaledInput.format(saved.total, Currencies.exponentOf(saved.currency)),
      note: saved.description,
      notes: saved.notes ?? '',
      date: parseIsoDate(saved.date),
    );
  }

  void edit(LoanDraft Function(LoanDraft d) change) {
    final d = state.value;
    if (d != null) state = AsyncData(change(d));
  }

  /// Saves (offline first) and returns the expense id, or null when the form is not valid.
  Future<String?> save({required String defaultDescription}) async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    final row = d.toRow(defaultDescription: defaultDescription);
    if (!d.isEdit) row['created_at'] = ref.read(clockProvider).now().toUtc().toIso8601String();
    return ref.read(expensesRepositoryProvider).save(d.groupId, row, id: d.expenseId);
  }
}

Map<String, int> _ints(String json) {
  final m = jsonDecode(json) as Map<String, Object?>;
  return {for (final e in m.entries) e.key: e.value! as int};
}
