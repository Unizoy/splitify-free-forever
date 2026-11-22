import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/currency/application/conversion_actions.dart'
    show savedFxOfPayment;
import 'package:splitify/features/currency/presentation/conversion_tile.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/application/expense_providers.dart'
    show expenseGroupProvider;
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/comments/presentation/comment_thread.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show SectionLabel, coverFamilyFor;
import 'package:splitify/features/history/presentation/history_routes.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart'
    show methodIcon, methodLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Payment detail (`/payment/:id`, #25): the group's cover hero with both people, the serif amount
/// and "You paid Asha"; method, date and note; edit and delete (soft, with undo); history and the
/// comment thread with its composer pinned at the bottom (phase 12).
class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({required this.paymentId, super.key});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(paymentViewProvider(paymentId));
    final v = async.value;
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
            child: async.isLoading
                ? DotsPulse(color: context.colors.primary, semanticLabel: l.loading)
                : EmptyState(
                    icon: AppIcons.payment,
                    title: l.payNotFoundTitle,
                    message: l.payNotFoundBody,
                  ),
          ),
        ),
      );
    }
    final group = ref.watch(expenseGroupProvider(v.payment.groupId)).value;
    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: _Hero(view: v, seed: group?.id, type: group?.type),
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

CommentTarget _commentTarget(PaymentView v) =>
    (groupId: v.payment.groupId, targetType: 'payment', targetId: v.payment.id);

String _name(AppLocalizations l, PaymentView v, String id, {bool start = true}) {
  if (id == v.meId) return start ? l.you : l.youLower;
  final n = v.nameOf(id);
  return n.isEmpty ? l.someone : n;
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.view, required this.seed, required this.type});

  final PaymentView view;
  final String? seed;
  final String? type;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final actions = ref.read(paymentActionsProvider);
    final p = view.payment;
    await actions.delete(p);
    unawaited(HapticFeedback.mediumImpact());
    await navigator.maybePop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.payDeleted),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: l.expUndo, onPressed: () => unawaited(actions.restore(p))),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final p = view.payment;
    final s = seed;
    return HeroHeader(
      art: s == null ? null : (seed: s, family: coverFamilyFor(type ?? 'other')),
      leading: HeroIconButton(
        icon: AppIcons.back,
        tooltip: l.back,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        HeroIconButton(
          key: const Key('payment-edit'),
          icon: AppIcons.edit,
          tooltip: l.payEdit,
          onPressed: () => unawaited(context.push(PaymentRoutes.edit(p.id))),
        ),
        HeroIconButton(
          key: const Key('payment-delete'),
          icon: AppIcons.trash,
          tooltip: l.payDelete,
          onPressed: () => unawaited(_delete(context, ref)),
        ),
      ],
      titleWidget: Column(
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(
                  name: view.nameOf(p.fromMember),
                  seed: p.fromMember,
                  size: AvatarSize.s56,
                  ring: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                  child: Icon(AppIcons.arrowRight, size: 22, color: c.onHero),
                ),
                Avatar(
                  name: view.nameOf(p.toMember),
                  seed: p.toMember,
                  size: AvatarSize.s56,
                  ring: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            l.settlePaidSentence(
              _name(l, view, p.fromMember),
              _name(l, view, p.toMember, start: false),
            ),
            textAlign: TextAlign.center,
            style: context.text.sheetTitle.copyWith(color: c.onHero),
          ),
          const SizedBox(height: AppSpacing.s1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              MoneyFormatter.detail.format(p.amount, p.currency.trim()),
              key: const Key('payment-detail-amount'),
              maxLines: 1,
              style: context.text.amountHero.copyWith(color: c.onHero),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          StatusPill(label: l.payTitle, icon: AppIcons.settle, tone: StatusPillTone.glass),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.view});

  final PaymentView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final p = view.payment;
    final note = p.note?.trim() ?? '';
    final added = _addedLine(context, l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.unsynced) ...[
          const Center(child: SyncMarker()),
          const SizedBox(height: AppSpacing.s4),
        ],
        SectionLabel(l.payDetailsLabel),
        DashedListRow(
          icon: methodIcon(p.method),
          label: l.payMethodLabel,
          value: methodLabel(l, p.method),
        ),
        DashedListRow(
          icon: AppIcons.calendar,
          label: l.expDateLabel,
          value: shortDate(context, parseIsoDate(p.date)),
        ),
        ConversionTile(
          recordId: p.id,
          groupId: p.groupId,
          currency: p.currency.trim(),
          saved: savedFxOfPayment(p),
          payment: true,
        ),
        if (note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AppIcons.notes, size: 22, color: c.textSecondary),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Semantics(
                    label: l.payNoteLabel,
                    child: Text(note, style: context.text.body),
                  ),
                ),
              ],
            ),
          ),
        DashedListRow(
          key: const Key('payment-history'),
          icon: AppIcons.history,
          label: l.expHistory,
          showDivider: false,
          onTap: () => unawaited(context.push(HistoryRoutes.payment(p.id))),
        ),
        if (added != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Text(
            added,
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

  String? _addedLine(BuildContext context, AppLocalizations l) {
    final created = view.payment.createdAt;
    final at = created == null ? null : DateTime.tryParse(created)?.toLocal();
    if (at == null) return null;
    final by = view.payment.createdBy;
    final who = by == null ? l.you : view.userNames[by];
    final date = shortDate(context, at);
    return who == null ? l.expAddedOn(date) : l.expAddedBy(who, date);
  }
}
