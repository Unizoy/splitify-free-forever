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

/// Payment detail (`/payment/:id`, #25), compact like Splitwise's (D-033): the group's cover hero with both
/// people, "You paid Asha" and the serif amount; one "Cash · 21 Nov 2026" line, the note, history and
/// "Added by …"; edit and delete (soft, with undo) on top, like the expense detail; then the comment thread
/// with its composer pinned at the bottom (phase 12). A deleted payment (opened from Activity) is read-only: a
/// "Deleted" pill in the hero and Restore instead of edit and delete (D-034 B2).
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
    final archived = group?.archivedAt != null;
    return Scaffold(
      body: SingleChildScrollView(
        child: OverlapColumn(
          top: _Hero(view: v, seed: group?.id, type: group?.type),
          bottom: OverlapSheet(
            child: _Body(
              view: v,
              restore: v.deleted ? _RestoreCard(view: v, archived: archived) : null,
            ),
          ),
        ),
      ),
      bottomNavigationBar: v.deleted
          ? null
          : CommentComposer(target: _commentTarget(v), readOnly: archived),
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
        if (!view.deleted) ...[
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
      ],
      titleWidget: Column(
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(name: view.nameOf(p.fromMember), seed: p.fromMember, ring: true),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                  child: Icon(AppIcons.arrowRight, size: 18, color: c.onHero),
                ),
                Avatar(name: view.nameOf(p.toMember), seed: p.toMember, ring: true),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l.settlePaidSentence(
              _name(l, view, p.fromMember),
              _name(l, view, p.toMember, start: false),
            ),
            key: const Key('payment-detail-sentence'),
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
          if (view.deleted) ...[
            const SizedBox(height: AppSpacing.s3),
            StatusPill(
              key: const Key('payment-deleted-pill'),
              label: l.settle2Deleted,
              icon: AppIcons.trash,
              tone: StatusPillTone.negative,
            ),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.view, this.restore});

  final PaymentView view;

  /// The Restore card of a deleted payment (it replaces the comment thread).
  final Widget? restore;

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
        if (restore case final r?) ...[r, const SizedBox(height: AppSpacing.s4)],
        // One line for how and when (Splitwise-compact, D-033): "Cash · 21 Nov 2026".
        DashedListRow(
          key: const Key('payment-method-date'),
          icon: methodIcon(p.method),
          label: methodLabel(l, p.method),
          value: shortDate(context, parseIsoDate(p.date)),
        ),
        // A deleted payment is read-only: no conversion to start from it.
        if (!view.deleted)
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
                    child: Text(note, key: const Key('payment-note'), style: context.text.body),
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
            key: const Key('payment-added'),
            textAlign: TextAlign.center,
            style: context.text.caption.copyWith(color: c.textSecondary),
          ),
        ],
        if (restore == null) ...[
          const SizedBox(height: AppSpacing.s6),
          SectionLabel(l.expComments),
          const SizedBox(height: AppSpacing.s3),
          CommentThread(target: _commentTarget(view)),
        ],
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

/// "This payment was deleted" with Restore (the existing soft-delete restore → outbox → `payment_restored`).
/// An archived group is read-only on the server, so it only explains.
class _RestoreCard extends ConsumerStatefulWidget {
  const _RestoreCard({required this.view, required this.archived});

  final PaymentView view;
  final bool archived;

  @override
  ConsumerState<_RestoreCard> createState() => _RestoreCardState();
}

class _RestoreCardState extends ConsumerState<_RestoreCard> {
  bool _busy = false;

  Future<void> _restore() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    await ref.read(paymentActionsProvider).restore(widget.view.payment);
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.settle2Restored)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      key: const Key('payment-deleted'),
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
                  widget.archived ? l.settle2RestoreArchived : l.settle2DeletedBody,
                  style: context.text.body,
                ),
              ),
            ],
          ),
          if (!widget.archived) ...[
            const SizedBox(height: AppSpacing.s4),
            PillButton(
              key: const Key('payment-restore'),
              label: l.settle2Restore,
              icon: AppIcons.restore,
              loading: _busy,
              onPressed: () => unawaited(_restore()),
            ),
          ],
        ],
      ),
    );
  }
}
