import 'package:flutter/material.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/features/sync/application/sync_texts.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One refused change: what it was, why, how often it was tried, and Retry / Discard.
class SyncIssueCard extends StatelessWidget {
  const SyncIssueCard({
    required this.issue,
    required this.onRetry,
    required this.onDiscard,
    this.busy = false,
    super.key,
  });

  final SyncIssue issue;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  /// An action for this change is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final retry = PillButton(
      key: Key('sync-retry-${issue.seq}'),
      label: l.retryLabel,
      icon: AppIcons.sync,
      variant: PillVariant.outline,
      size: PillSize.medium,
      loading: busy,
      onPressed: busy ? null : onRetry,
    );
    final discard = PillButton(
      key: Key('sync-discard-${issue.seq}'),
      label: l.discardLabel,
      variant: PillVariant.ghost,
      size: PillSize.medium,
      onPressed: busy ? null : onDiscard,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all24,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.surfaceMuted, shape: BoxShape.circle),
                  child: Icon(syncEntityIcon(issue.entity), size: 20, color: c.oweText),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.syncIssueEntity(issue.entity.wire)} · ${l.syncIssueOp(issue.op.name)}',
                        style: context.text.body.w(600),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        syncIssueReason(l, issue),
                        style: context.text.bodySmall.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        '${l.syncIssueTries(issue.attempts)} · ${l.syncErrorCode(issue.code)}',
                        style: context.text.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (large)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                retry,
                const SizedBox(height: AppSpacing.s2),
                discard,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: retry),
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: discard),
              ],
            ),
        ],
      ),
    );
  }
}

/// Asks before throwing a local change away.
Future<bool?> confirmDiscard(BuildContext context) {
  final l = AppLocalizations.of(context);
  return showAppSheet<bool>(
    context,
    title: l.discardTitle,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.discardBody, style: context.text.body.copyWith(color: context.colors.textSecondary)),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('discard-confirm'),
          label: l.discardLabel,
          icon: AppIcons.trash,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          label: l.cancelLabel,
          variant: PillVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
}
