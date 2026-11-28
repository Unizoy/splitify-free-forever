import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/attachments/application/attachment_picker.dart';
import 'package:splitify/features/attachments/presentation/attachment_widgets.dart';
import 'package:splitify/features/attachments/presentation/pdf_viewer_screen.dart';
import 'package:splitify/features/photos/presentation/photo_viewer_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

final _log = Logger('attachments');

/// The line for a file that could not be added.
String attachmentProblemText(AppLocalizations l, AttachmentProblem p) => switch (p) {
  AttachmentProblem.tooMany => l.w2yAttachTooMany(AttachmentLimits.perExpense),
  AttachmentProblem.tooBig => l.w2yAttachTooBig(AttachmentLimits.pdfMaxBytes ~/ (1024 * 1024)),
  AttachmentProblem.tooMuchInTotal => l.w2yAttachTooMuch(
    AttachmentLimits.bytesPerExpense ~/ (1024 * 1024),
  ),
  AttachmentProblem.unreadable => l.w2yAttachUnreadable,
};

/// "Add photo or PDF": the source sheet (camera, photos, PDF), then the picker; returns what fits next to
/// [count] files of [totalBytes] (empty when the person backed out) and says why anything was left out.
Future<List<NewAttachment>> pickAttachmentFiles(
  BuildContext context,
  WidgetRef ref, {
  required int count,
  required int totalBytes,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  final room = AttachmentLimits.perExpense - count;
  if (room <= 0) {
    say(attachmentProblemText(l, AttachmentProblem.tooMany));
    return const [];
  }
  final picker = ref.read(attachmentPickerProvider);
  final source = await showAppSheet<AttachmentSource>(
    context,
    title: l.w2yAttachSourceTitle,
    builder: (sheet) => const _Sources(),
  );
  if (source == null) return const [];
  AttachmentPick pick;
  try {
    pick = await picker(source, max: room);
  } on Exception catch (e) {
    _log.warning('attachment pick failed: ${e.runtimeType}');
    say(l.w2yAttachUnreadable);
    return const [];
  }
  final out = <NewAttachment>[];
  var total = totalBytes;
  var problem = pick.problem;
  for (final f in pick.files) {
    final p = attachmentProblem(
      count: count + out.length,
      totalBytes: total,
      sizeBytes: f.sizeBytes,
      isPdf: f.kind == AttachmentKind.pdf,
    );
    if (p != null) {
      problem ??= p;
      continue;
    }
    out.add(f);
    total += f.sizeBytes;
  }
  if (problem != null) say(attachmentProblemText(l, problem));
  return out;
}

class _Sources extends StatelessWidget {
  const _Sources();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionTile(
          key: const Key('attach-camera'),
          label: l.photoTake,
          leading: Icon(AppIcons.camera, size: 20, color: c.primary),
          onTap: () => Navigator.of(context).pop(AttachmentSource.camera),
        ),
        const SizedBox(height: AppSpacing.s3),
        OptionTile(
          key: const Key('attach-photos'),
          label: l.w2yAttachPhotos,
          leading: Icon(AppIcons.images, size: 20, color: c.primary),
          onTap: () => Navigator.of(context).pop(AttachmentSource.photos),
        ),
        const SizedBox(height: AppSpacing.s3),
        OptionTile(
          key: const Key('attach-pdf'),
          label: l.w2yAttachPdfPick,
          leading: Icon(AttachmentIcons.pdf, size: 20, color: c.primary),
          onTap: () => Navigator.of(context).pop(AttachmentSource.pdf),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          l.w2yAttachSourceHint,
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// Opens one file full screen: a photo at full resolution (its thumbnail shows while the big one
/// loads), a PDF in the page viewer. [onRemove] (null = read only) returns true when it removed the file.
Future<void> openAttachment(
  BuildContext context,
  AttachmentItem item, {
  Future<bool> Function()? onRemove,
}) {
  final l = AppLocalizations.of(context);
  switch (item) {
    case PickedAttachment(:final file) when file.image != null:
      return PhotoViewerScreen.open(
        context,
        title: l.w2yAttachPhotoTitle,
        bytes: file.image!.full,
        onRemove: onRemove,
        heroTag: AppHeroTags.attachment(item.key),
      );
    case PickedAttachment(:final file):
      return PdfViewerScreen.open(
        context,
        name: file.name ?? l.w2yAttachPdf,
        bytes: file.pdf,
        onRemove: onRemove,
      );
    case SavedAttachment(:final row) when row.kind == AttachmentKind.pdf.wire:
      return PdfViewerScreen.open(
        context,
        name: row.name ?? l.w2yAttachPdf,
        path: row.path,
        onRemove: onRemove,
      );
    case SavedAttachment(:final row):
      return PhotoViewerScreen.open(
        context,
        title: l.w2yAttachPhotoTitle,
        bucket: AttachmentPaths.bucket,
        path: row.path,
        placeholderPath: row.thumbPath,
        onRemove: onRemove,
        heroTag: AppHeroTags.attachment(item.key),
      );
    case LegacyReceipt(:final path):
      return PhotoViewerScreen.open(
        context,
        title: l.receiptPhoto,
        bucket: MediaBuckets.receipts,
        path: path,
        onRemove: onRemove,
        heroTag: AppHeroTags.attachment(item.key),
      );
  }
}
