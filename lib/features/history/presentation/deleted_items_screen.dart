import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/history/application/deleted_items_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Deleted items (`/groups/:id/deleted`, 08 #20): the group's deleted expenses and payments, newest delete
/// first; any member can restore one (D-008). Works offline: restore goes through the outbox.
class DeletedItemsScreen extends ConsumerWidget {
  const DeletedItemsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(deletedItemsProvider(groupId));
    final group = ref.watch(groupProvider(groupId)).value;
    final archived = group?.archivedAt != null;
    final view = async.value;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.s2,
            AppSpacing.screen,
            AppSpacing.s10,
          ),
          children: [
            PageTitle(title: l.delTitle, subtitle: l.delSubtitle),
            const SizedBox(height: AppSpacing.s6),
            if (archived && (view?.items.isNotEmpty ?? false)) ...[
              Text(
                l.delArchivedNote,
                key: const Key('deleted-archived-note'),
                style: context.text.bodySmall.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s3),
            ],
            if (view == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
                child: Center(
                  child: DotsPulse(color: context.colors.primary, semanticLabel: l.loading),
                ),
              )
            else if (view.items.isEmpty)
              EmptyState(
                key: const Key('deleted-empty'),
                icon: AppIcons.restore,
                title: l.delEmptyTitle,
                message: l.delEmptyBody,
              )
            else
              for (final item in view.items) ...[
                _DeletedItemRow(
                  item: item,
                  view: view,
                  enabled: !archived,
                  onRestore: () async {
                    await ref.read(deletedItemActionsProvider).restore(item);
                    if (context.mounted) showGroupMessage(context, l.delRestored);
                  },
                ),
                const DashedDivider(),
              ],
          ],
        ),
      ),
    );
  }
}

class _DeletedItemRow extends StatelessWidget {
  const _DeletedItemRow({
    required this.item,
    required this.view,
    required this.enabled,
    required this.onRestore,
  });

  final DeletedItem item;
  final DeletedItemsView view;
  final bool enabled;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    String member(String id) =>
        id == view.meMemberId ? l.you : (view.memberNames[id] ?? l.histFormerMember);
    final e = item.expense;
    final p = item.payment;
    final title = e != null
        ? e.description
        : l.histPaymentTitle(member(p!.fromMember), member(p.toMember));
    final amount = e != null
        ? MoneyFormatter.detail.format(e.total, e.currency)
        : MoneyFormatter.detail.format(p!.amount, p.currency);
    final at = DateTime.tryParse(item.deletedAt)?.toLocal();
    final date = at == null ? '' : shortDate(context, at);
    final who = item.deletedByMe ? l.expYouLower : (item.deletedByName ?? l.histFormerMember);
    final caption = l.delBy(who, date);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final icon = e != null
        ? TintedIcon.category(categoryOf(e.category), size: 44)
        : TintedIcon(icon: AppIcons.coins, color: c.primary, size: 44);
    final button = PillButton(
      key: Key('restore-${item.id}'),
      label: l.restore,
      icon: AppIcons.restore,
      variant: PillVariant.outline,
      size: PillSize.medium,
      expand: false,
      onPressed: enabled ? onRestore : null,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.body.w(600)),
        const SizedBox(height: 2),
        Text(amount, style: context.text.amount.copyWith(color: c.textPrimary)),
        const SizedBox(height: 2),
        Text(caption, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
        if (item.unsynced) ...[
          const SizedBox(height: AppSpacing.s1),
          const SyncMarker(compact: true),
        ],
      ],
    );
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  button,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(child: text),
                  const SizedBox(width: AppSpacing.s3),
                  button,
                ],
              ),
      ),
    );
  }
}
