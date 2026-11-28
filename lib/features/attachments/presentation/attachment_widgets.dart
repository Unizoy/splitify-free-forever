import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';
import 'package:splitify/features/photos/presentation/stored_photo.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/painters/dashed.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Icons of the attachment screens (Phosphor, from the bundled font; kept here so the shared icon list stays
/// untouched by this package).
abstract final class AttachmentIcons {
  static const IconData pdf = IconData(0xe702, fontFamily: 'PhosphorRegular');
  static const IconData paperclip = IconData(0xe39a, fontFamily: 'PhosphorRegular');
  static const IconData openExternal = IconData(0xe5de, fontFamily: 'PhosphorRegular');
}

/// One file on an expense, as the editor and the expense page show it.
sealed class AttachmentItem {
  const AttachmentItem();

  /// Stable key for widgets and tests.
  String get key;
  AttachmentKind get kind;

  /// File name (PDFs).
  String? get name;

  /// Stored size, when known.
  int? get sizeBytes;
}

/// A saved attachment (`expense_attachments`).
final class SavedAttachment extends AttachmentItem {
  const SavedAttachment(this.row);

  final LocalAttachment row;

  @override
  String get key => row.id;
  @override
  AttachmentKind get kind => AttachmentKind.of(row.kind);
  @override
  String? get name => row.name;
  @override
  int? get sizeBytes => row.sizeBytes;
}

/// The one receipt photo of an older expense (`receipt_path`, `receipts` bucket).
final class LegacyReceipt extends AttachmentItem {
  const LegacyReceipt(this.path);

  final String path;

  @override
  String get key => 'legacy:$path';
  @override
  AttachmentKind get kind => AttachmentKind.photo;
  @override
  String? get name => null;
  @override
  int? get sizeBytes => null;
}

/// A file picked in this session, not saved yet.
final class PickedAttachment extends AttachmentItem {
  const PickedAttachment(this.file);

  final NewAttachment file;

  @override
  String get key => file.id;
  @override
  AttachmentKind get kind => file.kind;
  @override
  String? get name => file.name;
  @override
  int? get sizeBytes => file.sizeBytes;
}

/// "340 KB" / "1.4 MB" in the phone's language.
String attachmentSize(AppLocalizations l, String locale, int bytes) {
  if (bytes < 1024 * 1024)
    return l.w2yAttachSizeKb(NumberFormat.decimalPattern(locale).format((bytes / 1024).ceil()));
  return l.w2yAttachSizeMb(
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(bytes / (1024 * 1024)),
  );
}

/// Screen-reader label of a tile: "Photo 2 of 3" / "PDF, Hotel invoice.pdf, 1.2 MB".
String attachmentLabel(
  AppLocalizations l,
  String locale,
  AttachmentItem item,
  int index,
  int count,
) {
  if (item.kind == AttachmentKind.photo) return l.w2yAttachPhotoLabel(index + 1, count);
  final size = item.sizeBytes;
  return l.w2yAttachPdfLabel(
    item.name ?? l.w2yAttachPdf,
    size == null ? '' : attachmentSize(l, locale, size),
  );
}

/// A square tile: the photo's thumbnail or a PDF card (icon, name, size); a cloud badge while it waits
/// for upload, and an optional remove button in the corner (48 dp target).
class AttachmentTile extends ConsumerWidget {
  const AttachmentTile({
    required this.item,
    required this.side,
    required this.label,
    required this.onOpen,
    this.onRemove,
    super.key,
  });

  final AttachmentItem item;
  final double side;
  final String label;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final decode = (side * MediaQuery.devicePixelRatioOf(context)).round();
    final waiting = switch (item) {
      SavedAttachment(:final row) =>
        ref
                .watch(
                  photoPendingProvider((
                    bucket: AttachmentPaths.bucket,
                    path: row.path,
                    thumb: false,
                  )),
                )
                .value ??
            false,
      LegacyReceipt(:final path) =>
        ref
                .watch(
                  photoPendingProvider((bucket: MediaBuckets.receipts, path: path, thumb: true)),
                )
                .value ??
            false,
      PickedAttachment() => false,
    };
    final Widget body = switch (item) {
      PickedAttachment(:final file) when file.image != null => MemoryPhoto(
        bytes: file.image!.thumb,
        decodeWidth: decode,
      ),
      SavedAttachment(:final row) when row.kind != AttachmentKind.pdf.wire => StoredPhoto(
        bucket: AttachmentPaths.bucket,
        path: row.thumbPath ?? row.path,
        decodeWidth: decode,
        showProblem: false,
      ),
      LegacyReceipt(:final path) => StoredPhoto(
        bucket: MediaBuckets.receipts,
        path: path,
        decodeWidth: decode,
        showProblem: false,
      ),
      _ => _PdfFace(item: item),
    };
    // A photo flies from its tile into the viewer (S-451).
    final photoTile = switch (item) {
      PickedAttachment(:final file) => file.image != null,
      SavedAttachment(:final row) => row.kind != AttachmentKind.pdf.wire,
      LegacyReceipt() => true,
    };
    final face = photoTile ? Hero(tag: AppHeroTags.attachment(item.key), child: body) : body;
    return SizedBox.square(
      dimension: side,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              onTap: onOpen,
              child: Pressable(
                key: Key('attachment-open-${item.key}'),
                onTap: onOpen,
                borderRadius: AppRadii.all16,
                scale: AppMotion.rowPressScale,
                child: ClipRRect(
                  borderRadius: AppRadii.all16,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.all16,
                      border: Border.all(color: c.border),
                    ),
                    child: face,
                  ),
                ),
              ),
            ),
          ),
          if (waiting)
            Positioned(
              left: AppSpacing.s1,
              bottom: AppSpacing.s1,
              child: Semantics(
                label: l.photoWaiting,
                child: Container(
                  key: Key('attachment-waiting-${item.key}'),
                  padding: const EdgeInsets.all(AppSpacing.s1),
                  decoration: BoxDecoration(
                    color: AppPalette.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(AppIcons.cloudUpload, size: 14, color: c.onHero),
                ),
              ),
            ),
          if (onRemove != null)
            Positioned(
              // A 48 dp target around the small circle on the tile's corner.
              top: -AppSpacing.s3,
              right: -AppSpacing.s3,
              child: Semantics(
                button: true,
                label: l.w2yAttachRemoveLabel,
                excludeSemantics: true,
                onTap: onRemove,
                child: Pressable(
                  key: Key('attachment-remove-${item.key}'),
                  onTap: onRemove,
                  circle: true,
                  child: SizedBox.square(
                    dimension: AppSpacing.minTouch,
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c.ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 2),
                        ),
                        child: Icon(AppIcons.close, size: 13, color: c.onInk),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PdfFace extends StatelessWidget {
  const _PdfFace({required this.item});

  final AttachmentItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final size = item.sizeBytes;
    return ColoredBox(
      color: c.surfaceMuted,
      child: LayoutBuilder(
        builder: (context, box) {
          // Small tiles (320 dp phones, large text) keep the icon and one line of the name.
          final roomy =
              box.maxHeight >= 96 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.4);
          return Padding(
            padding: EdgeInsets.all(roomy ? AppSpacing.s2 : AppSpacing.s1 + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(AttachmentIcons.pdf, size: roomy ? 26 : 20, color: c.oweText),
                const Spacer(),
                Text(
                  item.name ?? l.w2yAttachPdf,
                  maxLines: roomy ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.caption.w(600).copyWith(color: c.textPrimary),
                ),
                if (size != null && roomy)
                  Text(
                    attachmentSize(l, locale, size),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The dashed square at the end of the grid: "Add".
class AddAttachmentTile extends StatelessWidget {
  const AddAttachmentTile({required this.side, required this.onTap, super.key});

  final double side;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return SizedBox.square(
      dimension: side,
      child: Semantics(
        button: true,
        label: l.w2yAttachAdd,
        excludeSemantics: true,
        onTap: onTap,
        child: CustomPaint(
          painter: DashedBorderPainter(color: c.primary.withValues(alpha: 0.55), radius: 16),
          child: Pressable(
            key: const Key('attachment-add'),
            onTap: onTap,
            borderRadius: AppRadii.all16,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.plus, size: 22, color: c.primary),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    l.w2yAttachAddShort,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.w(700).copyWith(color: c.primary),
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

/// The files as a grid of squares (three across, bigger with large text up to the width), with "Add" at
/// the end while there is room.
class AttachmentGrid extends StatelessWidget {
  const AttachmentGrid({
    required this.items,
    required this.onOpen,
    this.onRemove,
    this.onAdd,
    super.key,
  });

  final List<AttachmentItem> items;
  final void Function(AttachmentItem item) onOpen;
  final void Function(AttachmentItem item)? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AppSpacing.s3;
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
        final across = scale >= 1.6 ? 2 : 3;
        final side = ((box.maxWidth - gap * (across - 1)) / across).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (i, item) in items.indexed)
              AttachmentTile(
                key: ValueKey(item.key),
                item: item,
                side: side,
                label: attachmentLabel(l, locale, item, i, items.length),
                onOpen: () => onOpen(item),
                onRemove: onRemove == null ? null : () => onRemove!(item),
              ),
            if (onAdd != null && items.length < AttachmentLimits.perExpense)
              AddAttachmentTile(side: side, onTap: onAdd!),
          ],
        );
      },
    );
  }
}

/// "3 of 10 files · 2.4 MB" under the grid.
class AttachmentSummaryLine extends StatelessWidget {
  const AttachmentSummaryLine({required this.count, required this.bytes, super.key});

  final int count;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Text(
      l.w2yAttachCount(count, AttachmentLimits.perExpense, attachmentSize(l, locale, bytes)),
      style: context.text.caption.copyWith(color: c.textSecondary),
    );
  }
}
