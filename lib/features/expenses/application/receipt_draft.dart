import 'package:splitify/domain/entities/prepared_image.dart';

/// The receipt photo in the expense editor (#29): one photo per expense, kept, replaced or removed.
final class ReceiptDraft {
  const ReceiptDraft.none() : savedPath = null, picked = null, removed = false;

  /// The saved expense's `receipt_path`.
  const ReceiptDraft.saved(String this.savedPath) : picked = null, removed = false;

  const ReceiptDraft._(this.savedPath, this.picked, {required this.removed});

  /// Storage path of the photo already saved with the expense, if any.
  final String? savedPath;

  /// A new photo picked in this editor session (replaces the saved one on Save).
  final PreparedImage? picked;

  /// The saved photo was removed in this session.
  final bool removed;

  /// Something to show in the editor.
  bool get hasPhoto => picked != null || (savedPath != null && !removed);

  /// Save must write `receipt_path`.
  bool get changed => picked != null || removed;

  ReceiptDraft pick(PreparedImage image) => ReceiptDraft._(savedPath, image, removed: false);

  ReceiptDraft remove() => ReceiptDraft._(savedPath, null, removed: savedPath != null);
}
