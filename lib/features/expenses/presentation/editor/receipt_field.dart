import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/photo_source_sheet.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Receipt photo on the Details step (#29, 07 §2 "receipt (photo pill)"): a dashed "Add receipt photo"
/// tile, or the thumbnail (tap = full screen) with Replace and Remove.
class ReceiptField extends ConsumerWidget {
  const ReceiptField({required this.receipt, required this.onChanged, super.key});

  final ReceiptDraft receipt;
  final ValueChanged<ReceiptDraft> onChanged;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final image = await pickPhoto(context, ref);
    if (image != null) onChanged(receipt.pick(image));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!receipt.hasPhoto) return _AddTile(onTap: () => unawaited(_pick(context, ref)));
    return _PhotoRow(
      picked: receipt.picked,
      savedPath: receipt.savedPath,
      onReplace: () => unawaited(_pick(context, ref)),
      onRemove: () => onChanged(receipt.remove()),
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
      label: l.receiptAdd,
      excludeSemantics: true,
      onTap: onTap,
      child: CustomPaint(
        painter: DashedBorderPainter(color: c.primary.withValues(alpha: 0.55), radius: 24),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const Key('receipt-add'),
            onTap: onTap,
            borderRadius: AppRadii.all24,
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
                          l.receiptAdd,
                          style: context.text.body.w(700).copyWith(color: c.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.receiptAddHint,
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

class _PhotoRow extends ConsumerWidget {
  const _PhotoRow({
    required this.picked,
    required this.savedPath,
    required this.onReplace,
    required this.onRemove,
  });

  final PreparedImage? picked;
  final String? savedPath;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final image = picked;
    final path = savedPath;
    final pending =
        image == null &&
        path != null &&
        (ref
                .watch(
                  photoPendingProvider((bucket: MediaBuckets.receipts, path: path, thumb: true)),
                )
                .value ??
            false);
    final thumb = image != null
        ? MemoryPhoto(bytes: image.thumb, decodeWidth: 240)
        : StoredPhoto(
            bucket: MediaBuckets.receipts,
            path: path!,
            decodeWidth: 240,
            showProblem: false,
          );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final side = 88 * (1 + (scale.clamp(1, 2) - 1) * 0.4);
    void open() => unawaited(
      PhotoViewerScreen.open(
        context,
        title: l.receiptPhoto,
        bytes: image?.full,
        bucket: image == null ? MediaBuckets.receipts : null,
        path: image == null ? path : null,
      ),
    );
    return Container(
      key: const Key('receipt-photo'),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all24,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l.photoView,
            excludeSemantics: true,
            onTap: open,
            child: GestureDetector(
              key: const Key('receipt-open'),
              onTap: open,
              child: ClipRRect(
                borderRadius: AppRadii.all16,
                child: SizedBox.square(dimension: side, child: thumb),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.receiptPhoto, style: context.text.body.w(700)),
                if (pending) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(AppIcons.cloudUpload, size: 14, color: c.unsynced),
                      const SizedBox(width: AppSpacing.s1),
                      Flexible(
                        child: Text(
                          l.photoWaiting,
                          style: context.text.caption.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.s2),
                Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: AppSpacing.s2,
                  children: [
                    PillButton(
                      key: const Key('receipt-replace'),
                      label: l.photoReplace,
                      icon: AppIcons.replace,
                      variant: PillVariant.outline,
                      size: PillSize.medium,
                      expand: false,
                      onPressed: onReplace,
                    ),
                    PillButton(
                      key: const Key('receipt-remove'),
                      label: l.photoRemove,
                      variant: PillVariant.ghost,
                      size: PillSize.medium,
                      expand: false,
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
