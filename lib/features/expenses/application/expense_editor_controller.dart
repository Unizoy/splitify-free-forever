import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/default_split.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show authRepositoryProvider;
import 'package:splitify/features/currency/application/conversion_actions.dart'
    show savedFxOfExpense;
import 'package:splitify/features/currency/domain/conversion.dart' show expenseFxAfterEdit;
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/recurring/application/recurring_providers.dart'
    show RecurringView, localDate;
import 'package:splitify/features/recurring/application/repeat_draft.dart';

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

/// "Edit future copies" of a repeating expense (#12): the same editor on the template [String] id.
final templateEditorProvider = AsyncNotifierProvider.autoDispose
    .family<ExpenseEditorController, ExpenseDraft, String>(
      (String id) => ExpenseEditorController((groupId: null, expenseId: null), templateId: id),
      retry: _noRetry,
    );

/// Add/edit expense (#5–9, #13, #35): loads the group's people and the saved expense (or the group's
/// default split), keeps the draft, and saves through the expenses repository → outbox.
class ExpenseEditorController extends AsyncNotifier<ExpenseDraft> {
  ExpenseEditorController(this.args, {this.templateId});

  final ExpenseEditorArgs args;

  /// Edits this template's future copies instead of one expense.
  final String? templateId;

  @override
  Future<ExpenseDraft> build() async {
    if (templateId != null) return _buildTemplate(templateId!);
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
        canRepeat: true,
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
      receipt: saved.receiptPath == null
          ? const ReceiptDraft.none()
          : ReceiptDraft.saved(saved.receiptPath!),
      canRepeat: saved.source != 'recurring' && saved.kind == 'expense' && await _noTemplate(saved),
    );
  }

  Future<bool> _noTemplate(LocalExpense e) async =>
      await ref
          .read(recurringRepositoryProvider)
          .watchForExpense(e.id, recurringId: e.recurringId)
          .first ==
      null;

  /// Template mode: the template's expense fields, its first date and its repeat.
  Future<ExpenseDraft> _buildTemplate(String id) async {
    final t = await ref.read(recurringRepositoryProvider).watchOne(id).first;
    if (t == null || t.deletedAt != null) throw const ExpenseNotFound();
    final group = await ref.read(groupsRepositoryProvider).watchOne(t.groupId).first;
    if (group == null) throw const ExpenseNotFound();
    final all = await ref.read(expensesRepositoryProvider).watchAllMembers(t.groupId).first;
    final active = [
      for (final m in all)
        if (m.deletedAt == null) m,
    ];
    final uid = ref.read(currentUserIdProvider);
    final meId = active.where((m) => uid != null && m.userId == uid).map((m) => m.id).firstOrNull;
    final f = jsonDecode(t.template) as Map<String, Object?>;
    final currency = (f['currency'] as String? ?? group.mainCurrency).trim();
    final shares = _map(f['shares']);
    final payers = _map(f['payers']);
    final values = _map(f['split_values']);
    final extra = [
      for (final m in all)
        if (m.deletedAt != null && (shares.containsKey(m.id) || payers.containsKey(m.id))) m,
    ];
    final exponent = Currencies.exponentOf(currency);
    final total = (f['total'] as num?)?.toInt() ?? 0;
    final end = t.endDate;
    return ExpenseDraft(
      groupId: t.groupId,
      groupName: group.name,
      currency: currency,
      members: _people([...active, ...extra], meId),
      split: SplitDraft.stored(
        members: [for (final m in active) m.id],
        exponent: exponent,
        kind: splitKindOf(f['split_kind'] as String? ?? 'equal'),
        participants: shares.keys.toList(),
        values: values,
      ),
      date: parseIsoDate(t.anchorDate),
      payerId: payers.length == 1 ? payers.keys.first : null,
      payers: payers,
      amountText: total > 0 ? ScaledInput.format(total, exponent) : '',
      description: f['description'] as String? ?? '',
      category: ExpenseCategories.normalize(
        f['category'] as String? ?? ExpenseCategories.defaultKey,
      ),
      notes: f['notes'] as String? ?? '',
      repeat: RepeatDraft(interval: t.repeatInterval, endsOn: end == null ? null : localDate(end)),
      templateId: t.id,
    );
  }

  /// Applies [change] to the loaded draft.
  void edit(ExpenseDraft Function(ExpenseDraft d) change) {
    final d = state.value;
    if (d != null) state = AsyncData(change(d));
  }

  /// Saves (offline first) and returns the expense id, or null when the draft is not valid. A new
  /// receipt photo is queued for upload in the same transaction (#29); a removed or replaced photo
  /// that never went up is forgotten.
  Future<String?> save() async {
    final d = state.value;
    if (d == null || !d.canSave) return null;
    if (d.isTemplate) return _saveTemplate(d);
    final row = d.toRow();
    if (!d.isEdit) row['created_at'] = ref.read(clockProvider).now().toUtc().toIso8601String();
    if (d.isEdit) row.addAll(await _fxAfterEdit(d, row));
    final id = d.expenseId ?? newId();
    final receipt = d.receipt;
    final media = ref.read(mediaRepositoryProvider);
    final old = receipt.savedPath;
    if (receipt.changed && old != null) await media.discardPending(MediaBuckets.receipts, old);
    final picked = receipt.picked;
    if (picked != null) {
      await media.saveExpenseWithReceipt(d.groupId, id, row, picked);
    } else {
      if (receipt.removed) row['receipt_path'] = null;
      await ref.read(expensesRepositoryProvider).save(d.groupId, row, id: id);
    }
    // "Repeat" (#12): a template next to the expense, also through the outbox.
    final rule = d.canRepeat ? d.repeat.ruleFrom(d.date) : null;
    if (rule != null) {
      await ref
          .read(recurringRepositoryProvider)
          .create(groupId: d.groupId, expenseId: id, rule: rule, template: d.templateFields());
    }
    return id;
  }

  /// Template mode: future copies get the new fields and repeat; returns the template id.
  Future<String?> _saveTemplate(ExpenseDraft d) async {
    final repo = ref.read(recurringRepositoryProvider);
    final t = await repo.watchOne(d.templateId!).first;
    if (t == null) return null;
    final rule = d.repeat.ruleFrom(d.date);
    await repo.edit(
      t,
      template: d.templateFields(),
      interval: rule?.interval,
      endsOn: rule?.endsOn,
      clearEnd: rule?.endsOn == null,
    );
    return t.id;
  }

  /// A saved conversion follows the edit (phase 14, S-151): same currency → the saved rate re-converts
  /// the new amounts; another currency → the conversion is dropped.
  Future<Map<String, Object?>> _fxAfterEdit(ExpenseDraft d, Map<String, Object?> row) async {
    final saved = await ref.read(expensesRepositoryProvider).watchOne(d.expenseId!).first;
    if (saved == null) return const {};
    return expenseFxAfterEdit(
      saved: savedFxOfExpense(saved),
      oldCurrency: saved.currency.trim(),
      currency: d.currency,
      total: row['total']! as int,
      paid: (row['payers']! as Map).cast<String, int>(),
      shares: (row['shares']! as Map).cast<String, int>(),
      order: [for (final m in d.members) m.id],
    );
  }

  static List<EditorMember> _people(List<LocalMember> members, String? meId) => [
    for (final m in members) (id: m.id, name: m.displayName, isMe: m.id == meId),
  ];
}

/// Member id → minor units of a template's JSON map; non-number entries (an imported expense's
/// batch id and summary, S-190) are skipped.
Map<String, int> _map(Object? v) => v is Map
    ? {
        for (final e in v.entries)
          if (e.value is num) e.key as String: (e.value! as num).toInt(),
      }
    : const {};

/// Member id → minor units. Non-number entries are skipped: imported expenses keep their batch id
/// and summary in `split_values` (phase 18, S-190).
Map<String, int> _ints(String json) {
  final m = jsonDecode(json) as Map<String, Object?>;
  return {
    for (final e in m.entries)
      if (e.value is int) e.key: e.value! as int,
  };
}
