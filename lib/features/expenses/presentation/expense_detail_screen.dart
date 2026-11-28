import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/currency/application/conversion_actions.dart'
    show savedFxOfExpense;
import 'package:splitify/features/currency/presentation/conversion_tile.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/itemize_draft.dart';
import 'package:splitify/core/money/currencies.dart';
import 'package:splitify/core/money/scaled_input.dart';
import 'package:splitify/features/expenses/presentation/category_trend_card.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/expenses/presentation/receipt_card.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show groupCoverImage;
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/comments/presentation/comment_thread.dart';
import 'package:splitify/features/history/presentation/history_routes.dart';
import 'package:splitify/features/recurring/application/recurring_providers.dart';
import 'package:splitify/features/recurring/presentation/recurring_tile.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Expense detail (`/expense/:id`, #13, 712 layout): the group's cover hero with the category,
/// description, serif amount and the viewer's side; then who paid, how it was split, details,
/// history (phase 12) and the comment thread with its composer pinned at the bottom. Edit and delete (soft,
/// with undo) on top.
class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({required this.expenseId, this.initial, super.key});

  final String expenseId;

  /// The list row's view, shown until the page's own read answers, so the icon hero flies on the first
  /// frame of the push (S-288).
  final ExpenseView? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(expenseViewProvider(expenseId));
    final v = view.value ?? (view.isLoading ? initial : null);
    if (v == null) {
      return Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: view.isLoading
                ? DotsPulse(color: context.colors.primary, semanticLabel: l.loading)
                : EmptyState(
                    icon: AppIcons.receipt,
                    title: l.expNotFoundTitle,
                    message: l.expNotFoundBody,
                  ),
          ),
        ),
      );
    }
    final group = ref.watch(expenseGroupProvider(v.expense.groupId)).value;
    // A deleted expense (D-034 A4) and an archived group are read-only.
    final readOnly = group?.archivedAt != null || v.deleted;
    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: _Hero(view: v, group: group),
          bottom: OverlapSheet(
            child: _Body(view: v, readOnly: readOnly, archived: group?.archivedAt != null),
          ),
        ),
      ),
      // A deleted expense takes no new comments (its thread stays readable); an archived group says why.
      bottomNavigationBar: v.deleted
          ? null
          : CommentComposer(target: _commentTarget(v), readOnly: readOnly),
    );
  }
}

CommentTarget _commentTarget(ExpenseView v) =>
    (groupId: v.expense.groupId, targetType: 'expense', targetId: v.expense.id);

class _Hero extends ConsumerWidget {
  const _Hero({required this.view, required this.group});

  final ExpenseView view;
  final LocalGroup? group;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final actions = ref.read(expenseActionsProvider);
    final e = view.expense;
    // Deleting the expense a repeat was started from also stops the repeat (copies made stay, #12).
    final template = ref
        .read(expenseRecurringProvider((expenseId: e.id, recurringId: e.recurringId)))
        .value;
    final stops = template != null && template.active && template.expenseId == e.id;
    await actions.delete(e);
    if (stops) await ref.read(recurringActionsProvider).stop(template);
    unawaited(HapticFeedback.mediumImpact());
    await navigator.maybePop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(stops ? l.recurringDeleteAlsoStops : l.expDeleted),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: l.expUndo, onPressed: () => unawaited(actions.restore(e))),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final e = view.expense;
    String money(int v) => MoneyFormatter.detail.format(v, e.currency);
    final net = view.myNet;
    final deleted = view.deleted;
    final (tone, label) = switch (net) {
      > 0 => (StatusPillTone.positive, l.expYouLentAmount(money(net))),
      < 0 => (StatusPillTone.negative, l.expYouBorrowedAmount(money(-net))),
      _ => (StatusPillTone.glass, view.involved ? l.expNoBalanceLong : l.expNotInvolvedLong),
    };
    final category = categoryOf(e.category);
    final g = group;
    return HeroHeader(
      art: g == null ? null : (seed: g.id, family: _family(g.type)),
      photo: g == null ? null : groupCoverImage(ref, g, width: 1200),
      leading: HeroIconButton(
        icon: AppIcons.back,
        tooltip: l.back,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        // A deleted expense: Restore lives in the card under the hero (one button, S-410).
        if (!deleted) ...[
          HeroIconButton(
            key: const Key('expense-edit'),
            icon: AppIcons.edit,
            tooltip: l.expEdit,
            onPressed: () => unawaited(
              context.push(view.isLoan ? ExpenseRoutes.editLoan(e.id) : ExpenseRoutes.edit(e.id)),
            ),
          ),
          HeroIconButton(
            key: const Key('expense-delete'),
            icon: AppIcons.trash,
            tooltip: l.expDelete,
            onPressed: () => unawaited(_delete(context, ref)),
          ),
        ],
      ],
      titleWidget: Column(
        children: [
          Hero(
            tag: AppHeroTags.expense(e.id),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: c.onHero, shape: BoxShape.circle),
              child: view.isLoan
                  ? Icon(AppIcons.loanFill, size: 28, color: c.primary)
                  : Icon(category.icon, size: 28, color: category.color),
            ),
          ),
          if (view.isLoan) ...[
            const SizedBox(height: AppSpacing.s3),
            StatusPill(label: l.loanChip, icon: AppIcons.loan, tone: StatusPillTone.glass),
          ],
          if (e.source == 'recurring') ...[
            const SizedBox(height: AppSpacing.s3),
            StatusPill(
              key: const Key('expense-recurring-pill'),
              label: l.recurringChip,
              icon: AppIcons.repeat,
              tone: StatusPillTone.glass,
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          Text(
            e.description,
            textAlign: TextAlign.center,
            style: context.text.sheetTitle.copyWith(color: c.onHero),
          ),
          const SizedBox(height: AppSpacing.s1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              money(e.total),
              key: const Key('expense-detail-amount'),
              maxLines: 1,
              style: context.text.amountHero.copyWith(color: c.onHero),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (deleted)
            StatusPill(
              key: const Key('expense-deleted-pill'),
              label: l.entryDeletedPill,
              icon: AppIcons.trash,
              tone: StatusPillTone.negative,
            )
          else
            StatusPill(label: label, tone: tone),
        ],
      ),
    );
  }

  static CoverFamily _family(String type) => switch (type) {
    'trip' => CoverFamily.trip,
    'home' => CoverFamily.home,
    'couple' => CoverFamily.couple,
    'direct' || 'adhoc' => CoverFamily.direct,
    _ => CoverFamily.other,
  };
}

class _Body extends StatelessWidget {
  const _Body({required this.view, this.readOnly = false, this.archived = false});

  final ExpenseView view;

  /// Archived group (read-only).
  final bool readOnly;

  /// The group itself is archived (a deleted expense cannot be restored then, S-410).
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final e = view.expense;
    String money(int v) => MoneyFormatter.detail.format(v, e.currency);
    String name(String id) => id == view.meId ? l.you : view.nameOf(id);
    final kind = splitKindOf(e.splitKind);
    final items = _itemsOf(e);
    final added = _addedLine(context, l);
    final edited = _editedLine(context, l);
    final payers = view.paid.entries.where((p) => p.value != 0).toList();
    final owed = view.owed.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.unsynced) ...[
          const Center(child: SyncMarker()),
          const SizedBox(height: AppSpacing.s4),
        ],
        if (view.deleted) ...[
          _DeletedNote(expense: e, archived: archived),
          const SizedBox(height: AppSpacing.s6),
        ],
        SectionLabel(view.isLoan ? l.loanLentBy : l.expPaidByLabel),
        for (var i = 0; i < payers.length; i++)
          _PersonRow(
            name: name(payers[i].key),
            avatarName: view.nameOf(payers[i].key),
            seed: payers[i].key,
            trailing: money(payers[i].value),
            emphasis: true,
            divider: i < payers.length - 1,
          ),
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(
          view.isLoan
              ? l.loanBorrowedBy
              : l.expSplitLabel(items != null ? l.entrySplitItems : l.splitKind(kind)),
        ),
        for (var i = 0; i < owed.length; i++)
          _PersonRow(
            name: name(owed[i].key),
            avatarName: view.nameOf(owed[i].key),
            seed: owed[i].key,
            trailing: owed[i].value == 0 ? l.expOwesNothing : l.expOwes(money(owed[i].value)),
            divider: i < owed.length - 1,
          ),
        if (items != null) ...[
          const SizedBox(height: AppSpacing.s6),
          SectionLabel(l.entryItemsLabel),
          for (final (i, item) in items.items.indexed)
            _PersonRow(
              name: item.name.isEmpty ? l.entryItemHint : item.name,
              avatarName: item.name.isEmpty ? l.entryItemHint : item.name,
              seed: 'item-$i',
              itemRow: true,
              trailing: money(ScaledInput.parse(item.amountText, items.exponent) ?? 0),
              caption: [
                for (final id in view.owed.keys)
                  if (item.members.contains(id)) name(id),
              ].join(', '),
              divider: i < items.items.length - 1,
            ),
        ],
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.expDetailsLabel),
        if (view.isLoan)
          DashedListRow(icon: AppIcons.info, label: l.loanNotSpending)
        else
          DashedListRow(
            icon: categoryOf(e.category).icon,
            label: l.expCategoryLabel,
            value: categoryValue(l, e.category),
          ),
        DashedListRow(
          icon: AppIcons.calendar,
          label: l.expDateLabel,
          value: shortDate(context, parseIsoDate(e.date)),
        ),
        if (!view.isLoan)
          RecurringTile(expenseId: e.id, recurringId: e.recurringId, readOnly: readOnly),
        ConversionTile(
          recordId: e.id,
          groupId: e.groupId,
          currency: e.currency.trim(),
          saved: savedFxOfExpense(e),
        ),
        if (e.notes != null && e.notes!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.notes, size: 22, color: c.textSecondary),
                const SizedBox(width: AppSpacing.s4),
                Expanded(child: Text(e.notes!.trim(), style: context.text.body)),
              ],
            ),
          ),
        // The receipt photo and the other files (W2-Y); nothing when the expense has none.
        ReceiptCard(expense: e, readOnly: readOnly),
        if (!view.isLoan && !view.deleted)
          CategoryTrendCard(groupId: e.groupId, category: e.category),
        DashedListRow(
          key: const Key('expense-history'),
          icon: AppIcons.history,
          label: l.expHistory,
          showDivider: false,
          onTap: () => unawaited(context.push(HistoryRoutes.expense(e.id))),
        ),
        if (e.source == 'recurring') ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            l.recurringCopyLine,
            key: const Key('expense-recurring-line'),
            textAlign: TextAlign.center,
            style: context.text.caption.copyWith(color: c.textSecondary),
          ),
        ],
        if (added != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            added,
            textAlign: TextAlign.center,
            style: context.text.caption.copyWith(color: c.textSecondary),
          ),
        ],
        if (edited != null) ...[
          const SizedBox(height: AppSpacing.s1),
          Text(
            edited,
            key: const Key('expense-edited-line'),
            textAlign: TextAlign.center,
            style: context.text.caption.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        SectionLabel(l.expComments),
        const SizedBox(height: AppSpacing.s3),
        CommentThread(target: _commentTarget(view)),
      ],
    );
  }

  /// "Edited by Asha on 22 Nov 2026" once the server has an edit (its `updated_at` moved past `created_at`).
  String? _editedLine(BuildContext context, AppLocalizations l) {
    final e = view.expense;
    final created = e.createdAt == null ? null : DateTime.tryParse(e.createdAt!);
    final updated = e.updatedAt == null ? null : DateTime.tryParse(e.updatedAt!);
    if (created == null || updated == null || !updated.isAfter(created)) return null;
    final by = e.updatedBy;
    final who = by == null ? null : view.userNames[by];
    final date = shortDate(context, updated.toLocal());
    return who == null ? l.expEditedOn(date) : l.expEditedBy(who, date);
  }

  String? _addedLine(BuildContext context, AppLocalizations l) {
    final created = view.expense.createdAt;
    if (created == null) return null;
    final at = DateTime.tryParse(created)?.toLocal();
    if (at == null) return null;
    final by = view.expense.createdBy;
    final who = by == null ? l.you : view.userNames[by];
    final date = shortDate(context, at);
    return who == null ? l.expAddedOn(date) : l.expAddedBy(who, date);
  }
}

/// Restores a deleted expense (D-034 A4, rule 9): the outbox `restore` mutation; the server writes
/// `expense_restored` to Activity. The page stays and turns back into the normal one.
Future<void> restoreExpense(BuildContext context, WidgetRef ref, LocalExpense e) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(expenseActionsProvider).restore(e);
  unawaited(HapticFeedback.mediumImpact());
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l.entryRestored), duration: const Duration(seconds: 3)));
}

/// "This expense was deleted …" with the Restore button, at the top of a deleted expense's page.
class _DeletedNote extends ConsumerWidget {
  const _DeletedNote({required this.expense, this.archived = false});

  final LocalExpense expense;

  /// An archived group is read-only (the server refuses the restore): the card only explains (S-410).
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      key: const Key('expense-deleted-note'),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.trash, size: 22, color: c.textSecondary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  archived ? l.qaExpenseRestoreArchived : l.entryDeletedNote,
                  style: context.text.body,
                ),
              ),
            ],
          ),
          if (!archived) ...[
            const SizedBox(height: AppSpacing.s4),
            PillButton(
              key: const Key('expense-restore'),
              label: l.entryRestoreExpense,
              icon: AppIcons.restore,
              onPressed: () => unawaited(restoreExpense(context, ref, expense)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The lines of an itemized expense (D-034 A2), read from `split_values`; null for other expenses.
ItemizeDraft? _itemsOf(LocalExpense e) => e.splitKind == 'exact'
    ? ItemizeDraft.fromStored(e.splitValues, Currencies.exponentOf(e.currency.trim()))
    : null;

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.avatarName,
    required this.seed,
    required this.trailing,
    required this.divider,
    this.emphasis = false,
    this.caption,
    this.itemRow = false,
  });

  /// An item line (receipt icon instead of an avatar).
  final bool itemRow;

  final String name;
  final String avatarName;
  final String seed;
  final String trailing;
  final bool divider;
  final bool emphasis;

  /// A second line under the name (who had an item).
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amount = Text(
      trailing,
      textAlign: TextAlign.end,
      style: context.text.amount.w(emphasis ? 700 : 600).copyWith(color: c.textPrimary),
    );
    // Large text (phase 19 polish): the amount goes under the name, so names never break inside a word.
    final stacked = context.stackRows;
    final line = caption;
    final title = line == null
        ? Text(name, style: context.text.body.w(600))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: context.text.body.w(600)),
              Text(line, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
            ],
          );
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            child: Row(
              children: [
                if (itemRow)
                  TintedIcon(icon: AppIcons.receipt, color: c.primary)
                else
                  Avatar(name: avatarName, seed: seed),
                const SizedBox(width: AppSpacing.s3),
                if (stacked)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: AppSpacing.s1),
                        amount,
                      ],
                    ),
                  )
                else ...[
                  Expanded(child: title),
                  const SizedBox(width: AppSpacing.s3),
                  amount,
                ],
              ],
            ),
          ),
          if (divider) const DashedDivider(),
        ],
      ),
    );
  }
}
