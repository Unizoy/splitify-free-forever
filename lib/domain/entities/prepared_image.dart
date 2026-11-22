import 'dart:typed_data';

/// A picked photo after compression (04 §6): the JPEG to upload and a small thumbnail kept on this phone.
final class PreparedImage {
  const PreparedImage({required this.full, required this.thumb});

  /// JPEG, quality ≤ 80, longer side ≤ 1600 px, ≤ 500 KB.
  final Uint8List full;

  /// JPEG, longer side ≤ 480 px (lists, detail thumbnail, offline view after upload).
  final Uint8List thumb;
}

/// Storage buckets (03 §3) and their object paths.
abstract final class MediaBuckets {
  static const receipts = 'receipts';
  static const groupCovers = 'group-covers';

  /// `<group_id>/<expense_id>/<uuid>.jpg`.
  static String receiptPath(String groupId, String expenseId, String fileId) =>
      '$groupId/$expenseId/$fileId.jpg';

  /// `<group_id>/<uuid>.jpg`.
  static String coverPath(String groupId, String fileId) => '$groupId/$fileId.jpg';
}
