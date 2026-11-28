import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/features/attachments/presentation/attachment_flows.dart';
import 'package:splitify/features/attachments/presentation/attachment_widgets.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The expense's files in the receipt sheet (#29, W2-Y): a dashed "Add photo or PDF" tile, or a grid of the
/// photos and PDFs (tap = full screen, × = take out before Save) with "Add" while there is room. Nothing is
/// written until Save.
class ReceiptField extends ConsumerWidget {
  const ReceiptField({required this.receipt, required this.onChanged, super.key});

  final ReceiptDraft receipt;
  final ValueChanged<ReceiptDraft> onChanged;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final files = await pickAttachmentFiles(
      context,
      ref,
      count: receipt.count,
      totalBytes: receipt.totalBytes,
    );
    if (files.isNotEmpty) onChanged(receipt.addAll(files));
  }

  ReceiptDraft _without(AttachmentItem item) => switch (item) {
    LegacyReceipt() => receipt.remove(),
    SavedAttachment(:final row) => receipt.removeSaved(row.id),
    PickedAttachment(:final file) => receipt.removeAdded(file.id),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <AttachmentItem>[
      if (receipt.showsLegacy) LegacyReceipt(receipt.savedPath!),
      for (final a in receipt.kept) SavedAttachment(a),
      for (final a in receipt.added) PickedAttachment(a),
    ];
    if (items.isEmpty) return _AddTile(onTap: () => unawaited(_add(context, ref)));
    return Column(
      key: const Key('receipt-photo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AttachmentGrid(
          items: items,
          onOpen: (item) => unawaited(
            openAttachment(
              context,
              item,
              onRemove: () async {
                onChanged(_without(item));
                return true;
              },
            ),
          ),
          onRemove: (item) => onChanged(_without(item)),
          onAdd: receipt.room > 0 ? () => unawaited(_add(context, ref)) : null,
        ),
        const SizedBox(height: AppSpacing.s2),
        AttachmentSummaryLine(count: receipt.count, bytes: receipt.totalBytes),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: true,
      label: l.w2yAttachAdd,
      excludeSemantics: true,
      onTap: onTap,
      child: CustomPaint(
        painter: DashedBorderPainter(color: c.primary.withValues(alpha: 0.55), radius: 24),
        child: Pressable(
          key: const Key('receipt-add'),
          onTap: onTap,
          borderRadius: AppRadii.all24,
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Row(
                children: [
                  TintedIcon(icon: AppIcons.cameraPlus, color: c.primary, size: 48),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.w2yAttachAdd,
                          style: context.text.body.w(700).copyWith(color: c.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.w2yAttachAddHint(AttachmentLimits.perExpense),
                          style: context.text.bodySmall.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Scan receipt" (D-034 A3) at the top of the receipt sheet: reads the amount, date and items from a
/// photo on this phone; the photo is attached too.
class ScanReceiptTile extends StatelessWidget {
  const ScanReceiptTile({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      button: true,
      label: '${l.entryScanReceipt}, ${l.entryScanReceiptHint}',
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('receipt-scan'),
        onTap: onTap,
        borderRadius: AppRadii.all24,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadii.all24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.primaryFill, shape: BoxShape.circle),
                child: Icon(AppIcons.scan, size: 24, color: c.onPrimaryFill),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.entryScanReceipt,
                      style: context.text.body.w(700).copyWith(color: c.onPrimaryContainer),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.entryScanReceiptHint,
                      style: context.text.bodySmall.copyWith(color: c.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18, color: c.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
