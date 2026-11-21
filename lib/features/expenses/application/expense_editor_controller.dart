import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show authRepositoryProvider;
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';

/// Which expense the editor opens: a new one in [groupId], or the saved [expenseId].
typedef ExpenseEditorArgs = ({String? groupId, String? expenseId});

/// Thrown when the group or expense to edit is not on this phone.
class ExpenseNotFound implements Exception {
  const ExpenseNotFound();
}

/// The signed-in user's id (null in tests and when signed out).
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authRepositoryProvider).currentUser?.id,
);

/// Loads from the local database only, so a failure (e.g. [ExpenseNotFound]) is shown at once
/// instead of being retried.
final expenseEditorProvider = AsyncNotifierProvider.autoDispose
    .family<ExpenseEditorController, ExpenseDraft, ExpenseEditorArgs>(
      ExpenseEditorController.new,
      retry: _noRetry,
    );

Duration? _noRetry(int retryCount, Object error) => null;

/// Add/edit expense (#5–9, #13, #35): loads the group's people and the saved expense (or the group's
/// default split), keeps the draft, and saves through the expenses repository → outbox.
class ExpenseEditorController extends AsyncNotifier<ExpenseDraft> {
  ExpenseEditorController(this.args);

  final ExpenseEditorArgs args;

  @override
  Future<ExpenseDraft> build() async {
    final expenses = ref.read(expensesRepositoryProvider);
    final saved = args.expenseId == null ? null : await expenses.watchOne(args.expenseId!).first;
    if (args.expenseId != null && (saved == null || saved.deletedAt != null)) {
      throw const ExpenseNotFound();
    }
    final groupId = saved?.groupId ?? args.groupId;
    if (groupId == null) throw const ExpenseNotFound();
    final group = await ref.read(groupsRepositoryProvider).watchOne(groupId).first;
    if (group == null) throw const ExpenseNotFound();
    final all = await expenses.watchAllMembers(groupId).first;
    final active = [
      for (final m in all)
        if (m.deletedAt == null) m,
    ];
    final uid = ref.read(currentUserIdProvider);
    final meId = active.where((m) => uid != null && m.userId == uid).map((m) => m.id).firstOrNull;
    final activeIds = [for (final m in active) m.id];

    if (saved == null) {
      final currency = group.mainCurrency;
      final preset = DefaultSplit.decode(group.defaultSplit)?.resolve(activeIds);
      final now = ref.read(clockProvider).now();
      return ExpenseDraft(
        groupId: groupId,
        groupName: group.name,
        currency: currency,
        members: _people(active, meId),
        split: SplitDraft.initial(activeIds, Currencies.exponentOf(currency), preset: preset),
        date: DateTime(now.year, now.month, now.day),
        payerId: meId ?? activeIds.firstOrNull,
        payers: const {},
        category: ExpenseCategories.normalize(
          await expenses.lastCategory(groupId) ?? ExpenseCategories.defaultKey,
        ),
      );
    }

    final shares = _ints(saved.shares);
    final payers = _ints(saved.payers);
    final values = saved.splitValues == null ? const <String, int>{} : _ints(saved.splitValues!);
    final extra = [
      for (final m in all)
        if (m.deletedAt != null && (shares.containsKey(m.id) || payers.containsKey(m.id))) m,
    ];
    final exponent = Currencies.exponentOf(saved.currency);
    return ExpenseDraft(
      groupId: groupId,
      groupName: group.name,
      expenseId: saved.id,
      currency: saved.currency,
      members: _people([...active, ...extra], meId),
      split: SplitDraft.stored(
        members: activeIds,
        exponent: exponent,
        kind: splitKindOf(saved.splitKind),
        participants: shares.keys.toList(),
        values: values,
      ),
      date: parseIsoDate(saved.date),
      payerId: payers.length == 1 ? payers.keys.first : null,
      payers: payers,
      amountText: ScaledInput.format(saved.total, exponent),
      description: saved.description,
      category: ExpenseCategories.normalize(saved.category),
      notes: saved.notes ?? '',
    );
  }

  /// Applies [change] to the loaded draft.
  void edit(ExpenseDraft Function(ExpenseDraft d) change) {
    final d = state.value;
    if (d != null) state = AsyncData(change(d));
  }

  /// Saves (offline first) and returns the expense id, or null when the draft is not valid.
  Future<String?> save() async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    final row = d.toRow();
    if (!d.isEdit) row['created_at'] = ref.read(clockProvider).now().toUtc().toIso8601String();
    return await ref.read(expensesRepositoryProvider).save(d.groupId, row, id: d.expenseId);
  }

  static List<EditorMember> _people(List<LocalMember> members, String? meId) => [
    for (final m in members) (id: m.id, name: m.displayName, isMe: m.id == meId),
  ];
}

Map<String, int> _ints(String json) {
  final m = jsonDecode(json) as Map<String, Object?>;
  return {for (final e in m.entries) e.key: e.value! as int};
}
