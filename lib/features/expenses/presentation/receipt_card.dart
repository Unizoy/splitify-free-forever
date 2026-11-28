import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/attachments/application/attachment_providers.dart';
import 'package:splitify/features/attachments/presentation/attachment_flows.dart';
import 'package:splitify/features/attachments/presentation/attachment_widgets.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show confirmAction;
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The expense's files on its page (07 "receipt thumbnail", W2-Y): one photo stays the wide rounded photo
/// with "Open photo"; several files (photos and PDFs) are a grid under "Receipts and files". A tap opens the
/// file full screen (photos at full resolution, PDFs page by page) with Remove; removing shows Undo. A
/// deleted expense or an archived group is read-only. Nothing shows when the expense has no files.
class ReceiptCard extends ConsumerWidget {
  const ReceiptCard({required this.expense, this.readOnly = false, super.key});

  final LocalExpense expense;

  /// A deleted expense (D-034 A4) or an archived group: files open without Remove.
  final bool readOnly;

  Future<bool> Function()? _remover(BuildContext context, WidgetRef ref, AttachmentItem item) {
    if (readOnly) return null;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    void say(String text, {SnackBarAction? action}) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
    return switch (item) {
      // The photo older versions kept in `receipt_path`: removing it clears the column (as before).
      LegacyReceipt() => () async {
        final yes = await confirmAction(
          context,
          title: l.receiptRemoveTitle,
          body: l.receiptRemoveBody,
          confirm: l.photoRemove,
          icon: AppIcons.trash,
        );
        if (!yes) return false;
        await ref.read(expenseActionsProvider).removeReceipt(expense);
        say(l.receiptRemoved);
        return true;
      },
      SavedAttachment(:final row) => () async {
        final repo = ref.read(attachmentsRepositoryProvider);
        await repo.remove(row);
        say(
          l.w2yAttachRemoved(row.kind),
          action: SnackBarAction(label: l.expUndo, onPressed: () => unawaited(repo.restore(row))),
        );
        return true;
      },
      PickedAttachment() => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final rows =
        ref.watch(expenseAttachmentsProvider(expense.id)).value ?? const <LocalAttachment>[];
    final legacy = expense.receiptPath;
    final items = <AttachmentItem>[
      if (legacy != null) LegacyReceipt(legacy),
      for (final r in rows) SavedAttachment(r),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    void open(AttachmentItem item) =>
        unawaited(openAttachment(context, item, onRemove: _remover(context, ref, item)));
    final single = items.length == 1 && items.single.kind == AttachmentKind.photo;
    final bytes = rows.fold(0, (s, r) => s + r.sizeBytes);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4, bottom: AppSpacing.s2),
      child: single
          ? _WidePhoto(item: items.single, onOpen: () => open(items.single))
          : Column(
              key: const Key('expense-attachments'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AttachmentIcons.paperclip, size: 20, color: c.textSecondary),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        l.w2yAttachTitle,
                        style: context.text.body.w(700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (bytes > 0) ...[
                  const SizedBox(height: AppSpacing.s1),
                  AttachmentSummaryLine(count: items.length, bytes: bytes),
                ],
                const SizedBox(height: AppSpacing.s3),
                AttachmentGrid(items: items, onOpen: open),
              ],
            ),
    );
  }
}

/// One photo: wide and rounded, "Open photo" (and "Uploads when you're online" while it waits).
class _WidePhoto extends ConsumerWidget {
  const _WidePhoto({required this.item, required this.onOpen});

  final AttachmentItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final (bucket, path, waitPath) = switch (item) {
      SavedAttachment(:final row) => (AttachmentPaths.bucket, row.thumbPath ?? row.path, row.path),
      LegacyReceipt(:final path) => (MediaBuckets.receipts, path, path),
      PickedAttachment() => throw StateError('only saved files show on the expense page'),
    };
    final pending =
        ref.watch(photoPendingProvider((bucket: bucket, path: waitPath, thumb: true))).value ??
        false;
    final width = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
        .round();
    return Semantics(
      button: true,
      label: l.photoView,
      excludeSemantics: true,
      onTap: onOpen,
      child: Pressable(
        key: const Key('expense-receipt'),
        onTap: onOpen,
        scale: AppMotion.rowPressScale,
        child: ClipRRect(
          borderRadius: AppRadii.all24,
          child: SizedBox(
            height: 184,
            child: Stack(
              fit: StackFit.expand,
              children: [
                StoredPhoto(bucket: bucket, path: path, decodeWidth: width),
                Positioned(
                  left: AppSpacing.s3,
                  bottom: AppSpacing.s3,
                  right: AppSpacing.s3,
                  child: Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      _Chip(icon: AppIcons.zoomIn, text: l.photoView),
                      if (pending) _Chip(icon: AppIcons.cloudUpload, text: l.photoWaiting),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.all24,
                    border: Border.all(color: c.border),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: AppPalette.black.withValues(alpha: 0.55),
        borderRadius: AppRadii.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.onHero),
          const SizedBox(width: AppSpacing.s1),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.caption.w(600).copyWith(color: c.onHero),
            ),
          ),
        ],
      ),
    );
  }
}
