import 'dart:typed_data';

import 'package:splitify/core/utils/text_clip.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

/// What an expense attachment is (D-034 P-7, 0029): a photo (high-resolution JPEG + thumbnail) or a PDF.
enum AttachmentKind {
  photo('photo'),
  pdf('pdf');

  const AttachmentKind(this.wire);

  /// Value of the `kind` column.
  final String wire;

  static AttachmentKind of(String wire) => wire == 'pdf' ? pdf : photo;
}

/// Limits of attachments (S-432). The server enforces the same (0029: photo <= 3 MB, PDF <= 5 MB,
/// <= 10 live files and 25 MB per expense); the app stays below them so a refusal never surprises anyone.
///
/// Storage budget (Supabase free plan, 1 GB for the whole project): a photo is a JPEG with its longer side
/// <= [photoSide] px under [photoMaxBytes] (typically 0.4–1.1 MB for a phone photo of a bill) plus a
/// [thumbSide] px thumbnail (~30–60 KB); a PDF is stored as picked, up to [pdfMaxBytes].
abstract final class AttachmentLimits {
  /// Live files per expense (photos and PDFs together).
  static const perExpense = 10;

  /// All live files of one expense together.
  static const bytesPerExpense = 25 * 1024 * 1024;

  /// A PDF as picked (the bucket refuses more).
  static const pdfMaxBytes = 5 * 1024 * 1024;

  /// Longer side of the stored photo ("full resolution on tap"; receipts stay sharp when zoomed).
  static const photoSide = 3072;

  /// The stored photo after compression.
  static const photoMaxBytes = 1536 * 1024;

  /// Thumbnails (lists, the expense page, offline view).
  static const thumbSide = 480;
  static const thumbQuality = 70;

  /// Tried in order until the JPEG fits [photoMaxBytes] (longer side, quality).
  static const ladder = <(int, int)>[
    (3072, 85),
    (3072, 78),
    (2560, 75),
    (2048, 72),
    (1600, 70),
    (1280, 65),
  ];

  /// A PDF name shown on the tile and kept with the file (`name` column).
  static const nameMaxLength = 120;
}

/// The `expense-files` bucket and its object paths (0029).
abstract final class AttachmentPaths {
  static const bucket = 'expense-files';

  /// `<group>/<expense>/<id>.jpg` or `.pdf`.
  static String file(String groupId, String expenseId, String id, AttachmentKind kind) =>
      '$groupId/$expenseId/$id.${kind == AttachmentKind.pdf ? 'pdf' : 'jpg'}';

  /// `<group>/<expense>/<id>-thumb.jpg` (photos only).
  static String thumb(String groupId, String expenseId, String id) =>
      '$groupId/$expenseId/$id-thumb.jpg';

  /// Content type of an object by its path (uploads).
  static String contentType(String path) =>
      path.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';

  /// Whether this phone keeps its own copy after the upload: attachment thumbnails and PDFs (small, opened
  /// offline), covers and avatars; full attachment photos and receipts come back through a signed URL when
  /// opened.
  static bool keepAfterUpload(String bucket, String path) {
    if (bucket == AttachmentPaths.bucket) {
      return path.endsWith('-thumb.jpg') || path.toLowerCase().endsWith('.pdf');
    }
    return bucket != MediaBuckets.receipts;
  }
}

/// A file picked in this editor session (or on the expense page), not saved yet.
final class NewAttachment {
  /// A compressed photo: [image] holds the stored JPEG and its thumbnail.
  NewAttachment.photo(PreparedImage this.image, {String? id, this.width, this.height})
    : id = id ?? newId(),
      kind = AttachmentKind.photo,
      pdf = null,
      name = null;

  /// A PDF as picked, with its file name.
  NewAttachment.pdf(Uint8List this.pdf, {required String name, String? id})
    : id = id ?? newId(),
      kind = AttachmentKind.pdf,
      image = null,
      width = null,
      height = null,
      name = cleanAttachmentName(name);

  final String id;
  final AttachmentKind kind;
  final PreparedImage? image;
  final Uint8List? pdf;
  final String? name;

  /// Pixel size of the stored photo, when known.
  final int? width;
  final int? height;

  /// Bytes the stored file takes (the thumbnail is not counted, like on the server).
  int get sizeBytes => image?.full.lengthInBytes ?? pdf!.lengthInBytes;

  /// The `expense_attachments` columns of this file on [expenseId] (an upsert of a new row).
  Map<String, Object?> row(String groupId, String expenseId, {required int position}) => {
    'expense_id': expenseId,
    'kind': kind.wire,
    'path': AttachmentPaths.file(groupId, expenseId, id, kind),
    'thumb_path': kind == AttachmentKind.photo
        ? AttachmentPaths.thumb(groupId, expenseId, id)
        : null,
    'name': name,
    'size_bytes': sizeBytes,
    'width': width,
    'height': height,
    'position': position,
  };
}

/// A file name fit to keep: no folders, no control characters, at most [AttachmentLimits.nameMaxLength]
/// characters (the extension kept when it has to be shortened); null when nothing is left.
String? cleanAttachmentName(String? raw) {
  if (raw == null) return null;
  var name = raw.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
  if (name.isEmpty) return null;
  const max = AttachmentLimits.nameMaxLength;
  if (name.length > max) {
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 && name.length - dot <= 8 ? name.substring(dot) : '';
    name = '${clipText(name, max - ext.length).trimRight()}$ext';
  }
  return name;
}

/// Why a file can't be added.
enum AttachmentProblem {
  /// [AttachmentLimits.perExpense] files already.
  tooMany,

  /// The file is bigger than its limit.
  tooBig,

  /// All files together would pass [AttachmentLimits.bytesPerExpense].
  tooMuchInTotal,

  /// Not a PDF (or a photo the phone could not read).
  unreadable,
}

/// The first problem with adding a file of [sizeBytes] ([isPdf]) to an expense that already holds [count]
/// files of [totalBytes]; null when it fits.
AttachmentProblem? attachmentProblem({
  required int count,
  required int totalBytes,
  required int sizeBytes,
  required bool isPdf,
}) {
  if (count >= AttachmentLimits.perExpense) return AttachmentProblem.tooMany;
  if (isPdf && sizeBytes > AttachmentLimits.pdfMaxBytes) return AttachmentProblem.tooBig;
  if (totalBytes + sizeBytes > AttachmentLimits.bytesPerExpense) {
    return AttachmentProblem.tooMuchInTotal;
  }
  return null;
}

/// True when [bytes] start like a PDF file (`%PDF-`).
bool looksLikePdf(Uint8List bytes) =>
    bytes.length >= 5 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46 &&
    bytes[4] == 0x2d;
