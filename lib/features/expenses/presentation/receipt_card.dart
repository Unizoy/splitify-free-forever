import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show confirmAction;
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/photo_source_sheet.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The receipt on the expense detail (07 "receipt thumbnail"): a wide rounded photo with "Open photo"
/// (and "Uploads when you're online" while it waits); opens the full-screen viewer with Replace and
/// Remove.
class ReceiptCard extends ConsumerWidget {
  const ReceiptCard({required this.expense, super.key});

  final LocalExpense expense;

  Future<void> _open(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(expenseActionsProvider);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    return PhotoViewerScreen.open(
      context,
      title: l.receiptPhoto,
      bucket: MediaBuckets.receipts,
      path: expense.receiptPath,
      onReplace: () async {
        final image = await pickPhoto(context, ref);
        if (image == null) return false;
        await actions.replaceReceipt(expense, image);
        say(l.receiptReplaced);
        return true;
      },
      onRemove: () async {
        final yes = await confirmAction(
          context,
          title: l.receiptRemoveTitle,
          body: l.receiptRemoveBody,
          confirm: l.photoRemove,
          icon: AppIcons.trash,
        );
        if (!yes) return false;
        await actions.removeReceipt(expense);
        say(l.receiptRemoved);
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final path = expense.receiptPath!;
    final ref0 = (bucket: MediaBuckets.receipts, path: path, thumb: true);
    final pending = ref.watch(photoPendingProvider(ref0)).value ?? false;
    final width = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
        .round();
    return Semantics(
      button: true,
      label: l.photoView,
      excludeSemantics: true,
      onTap: () => unawaited(_open(context, ref)),
      child: Pressable(
        key: const Key('expense-receipt'),
        onTap: () => unawaited(_open(context, ref)),
        scale: AppMotion.rowPressScale,
        child: ClipRRect(
          borderRadius: AppRadii.all24,
          child: SizedBox(
            height: 184,
            child: Stack(
              fit: StackFit.expand,
              children: [
                StoredPhoto(bucket: MediaBuckets.receipts, path: path, decodeWidth: width),
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
