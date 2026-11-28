import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

/// The expense's files in the editor (#29, D-034 P-7, W2-Y): photos and PDFs (`expense_attachments`) plus the
/// one receipt photo older versions stored in `receipt_path` ([savedPath]). Files picked here ([added]) and
/// saved files taken out ([removedIds]) are written on Save, in the expense's own transaction.
final class ReceiptDraft {
  const ReceiptDraft.none()
    : savedPath = null,
      removed = false,
      saved = const [],
      added = const [],
      removedIds = const {};

  /// The saved expense: its old single receipt (`receipt_path`) and its live [attachments].
  const ReceiptDraft.saved(this.savedPath, {List<LocalAttachment> attachments = const []})
    : removed = false,
      saved = attachments,
      added = const [],
      removedIds = const {};

  const ReceiptDraft._({
    required this.savedPath,
    required this.removed,
    required this.saved,
    required this.added,
    required this.removedIds,
  });

  /// Storage path of the old single receipt photo (`receipts` bucket), if the expense has one.
  final String? savedPath;

  /// The old receipt photo was removed in this session (Save clears `receipt_path`).
  final bool removed;

  /// The expense's saved files when the editor opened.
  final List<LocalAttachment> saved;

  /// Files picked in this session, in the order they were added.
  final List<NewAttachment> added;

  /// Saved files taken out in this session.
  final Set<String> removedIds;

  /// The old receipt photo still shows.
  bool get showsLegacy => savedPath != null && !removed;

  /// Saved files that stay.
  List<LocalAttachment> get kept => [
    for (final a in saved)
      if (!removedIds.contains(a.id)) a,
  ];

  /// Files the expense will have after Save.
  int get count => (showsLegacy ? 1 : 0) + kept.length + added.length;

  /// Bytes of the files after Save (the old receipt photo is not counted, like on the server).
  int get totalBytes =>
      kept.fold(0, (s, a) => s + a.sizeBytes) + added.fold(0, (s, a) => s + a.sizeBytes);

  /// Position of the first file added in this session (after every saved one).
  int get nextPosition => saved.fold(-1, (m, a) => a.position > m ? a.position : m) + 1;

  /// How many more files fit.
  int get room => AttachmentLimits.perExpense - count;

  /// Something to show in the editor (the toolbar chip is filled).
  bool get hasPhoto => count > 0;

  /// Save must write files or `receipt_path`.
  bool get changed => removed || added.isNotEmpty || removedIds.isNotEmpty;

  /// The last photo picked in this session (the one "Scan receipt" read), if any.
  PreparedImage? get picked => added.reversed.map((a) => a.image).nonNulls.firstOrNull;

  /// Adds a picked photo (receipt scan, share to Splitify) as a new attachment.
  ReceiptDraft pick(PreparedImage image) => addAll([NewAttachment.photo(image)]);

  /// Adds files, as many as fit.
  ReceiptDraft addAll(List<NewAttachment> files) => _copy(added: [...added, ...files.take(room)]);

  /// Takes out the old receipt photo (kept for compatibility with one-photo expenses).
  ReceiptDraft remove() => _copy(removed: savedPath != null);

  /// Takes out a saved file.
  ReceiptDraft removeSaved(String id) => _copy(removedIds: {...removedIds, id});

  /// Drops a file picked in this session.
  ReceiptDraft removeAdded(String id) => _copy(added: [...added.where((a) => a.id != id)]);

  ReceiptDraft _copy({bool? removed, List<NewAttachment>? added, Set<String>? removedIds}) =>
      ReceiptDraft._(
        savedPath: savedPath,
        removed: removed ?? this.removed,
        saved: saved,
        added: added ?? this.added,
        removedIds: removedIds ?? this.removedIds,
      );
}
