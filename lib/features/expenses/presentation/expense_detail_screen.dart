import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/comments/presentation/comment_thread.dart';
import 'package:splitify/features/history/presentation/history_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Expense detail (`/expense/:id`, #13, 712 layout): the group's cover hero with the category,
/// description, serif amount and the viewer's side; then who paid, how it was split, details,
/// history (phase 12) and the comment thread with its composer pinned at the bottom. Edit and delete (soft,
/// with undo) on top.
class ExpenseDetailScreen extends ConsumerWidget {
  const ExpenseDetailScreen({required this.expenseId, super.key});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(expenseViewProvider(expenseId));
    final v = view.value;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
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
    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: _Hero(view: v, group: group),
          bottom: OverlapSheet(child: _Body(view: v)),
        ),
      ),
      bottomNavigationBar: CommentComposer(
        target: _commentTarget(v),
        readOnly: group?.archivedAt != null,
      ),
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
    await actions.delete(e);
    unawaited(HapticFeedback.mediumImpact());
    await navigator.maybePop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.expDeleted),
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
    final (tone, label) = switch (net) {
      > 0 => (StatusPillTone.positive, l.expYouLentAmount(money(net))),
      < 0 => (StatusPillTone.negative, l.expYouBorrowedAmount(money(-net))),
      _ => (StatusPillTone.glass, view.involved ? l.expNoBalanceLong : l.expNotInvolvedLong),
    };
    final category = categoryOf(e.category);
    final g = group;
    return HeroHeader(
      art: g == null ? null : (seed: g.id, family: _family(g.type)),
      leading: HeroIconButton(
        icon: AppIcons.back,
        tooltip: l.back,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        HeroIconButton(
          key: const Key('expense-edit'),
          icon: AppIcons.edit,
          tooltip: l.expEdit,
          onPressed: () => unawaited(context.push(ExpenseRoutes.edit(e.id))),
        ),
        HeroIconButton(
          key: const Key('expense-delete'),
          icon: AppIcons.trash,
          tooltip: l.expDelete,
          onPressed: () => unawaited(_delete(context, ref)),
        ),
      ],
      titleWidget: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: c.onHero, shape: BoxShape.circle),
            child: Icon(category.icon, size: 28, color: category.color),
          ),
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
              style: context.text.heroDisplay.copyWith(
                color: c.onHero,
                // Instrument Serif has no ₹ glyph: the symbol falls back to Inter.
                fontFamilyFallback: const [AppFonts.sans],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          StatusPill(label: label, tone: tone),
        ],
      ),
    );
  }

  static CoverFamily _family(String type) => switch (type) {
    'trip' => CoverFamily.trip,
    'home' => CoverFamily.home,
    'couple' => CoverFamily.couple,
    'direct' => CoverFamily.direct,
    _ => CoverFamily.other,
  };
}

class _Body extends StatelessWidget {
  const _Body({required this.view});

  final ExpenseView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final e = view.expense;
    String money(int v) => MoneyFormatter.detail.format(v, e.currency);
    String name(String id) => id == view.meId ? l.you : view.nameOf(id);
    final kind = splitKindOf(e.splitKind);
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
        SectionLabel(l.expPaidByLabel),
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
        SectionLabel(l.expSplitLabel(l.splitKind(kind))),
        for (var i = 0; i < owed.length; i++)
          _PersonRow(
            name: name(owed[i].key),
            avatarName: view.nameOf(owed[i].key),
            seed: owed[i].key,
            trailing: owed[i].value == 0 ? l.expOwesNothing : l.expOwes(money(owed[i].value)),
            divider: i < owed.length - 1,
          ),
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.expDetailsLabel),
        DashedListRow(
          icon: categoryOf(e.category).icon,
          label: l.category(e.category),
          value: l.category(categoryOf(e.category).name),
        ),
        DashedListRow(
          icon: AppIcons.calendar,
          label: l.expDateLabel,
          value: shortDate(context, parseIsoDate(e.date)),
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
        DashedListRow(
          key: const Key('expense-history'),
          icon: AppIcons.history,
          label: l.expHistory,
          showDivider: false,
          onTap: () => unawaited(context.push(HistoryRoutes.expense(e.id))),
        ),
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

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.avatarName,
    required this.seed,
    required this.trailing,
    required this.divider,
    this.emphasis = false,
  });

  final String name;
  final String avatarName;
  final String seed;
  final String trailing;
  final bool divider;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            child: Row(
              children: [
                Avatar(name: avatarName, seed: seed),
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: Text(name, style: context.text.body.w(600))),
                const SizedBox(width: AppSpacing.s3),
                Text(
                  trailing,
                  textAlign: TextAlign.end,
                  style: context.text.amount.copyWith(color: emphasis ? c.owedText : c.textPrimary),
                ),
              ],
            ),
          ),
          if (divider) const DashedDivider(),
        ],
      ),
    );
  }
}
