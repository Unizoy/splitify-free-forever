// Shared fixtures for the attachment widget tests and goldens (W2-Y): saved rows, picked files, a fake
// picker, a fake PDF platform and stored-file overrides. No network, no platform channel.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/features/attachments/application/attachment_picker.dart';
import 'package:splitify/features/attachments/application/attachment_providers.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';

import 'photo_fixtures.dart';
import 'sample_photo.dart';

const attachmentGroup = 'g-goa';

/// A saved attachment row of expense [expenseId] (photo or PDF) with the paths the app would give it.
LocalAttachment sampleAttachmentRow({
  String id = 'a1',
  String expenseId = 'e1',
  AttachmentKind kind = AttachmentKind.photo,
  String? name,
  int sizeBytes = 340 * 1024,
  int position = 0,
}) => LocalAttachment(
  id: id,
  groupId: attachmentGroup,
  expenseId: expenseId,
  kind: kind.wire,
  path: AttachmentPaths.file(attachmentGroup, expenseId, id, kind),
  thumbPath: kind == AttachmentKind.photo
      ? AttachmentPaths.thumb(attachmentGroup, expenseId, id)
      : null,
  name: kind == AttachmentKind.pdf ? (name ?? 'Hotel invoice.pdf') : null,
  sizeBytes: sizeBytes,
  position: position,
  seq: 1,
  syncState: 'synced',
);

/// A picked photo (the sample PNG as full and thumbnail).
NewAttachment pickedPhoto({String? id}) => NewAttachment.photo(samplePrepared, id: id);

/// A picked PDF of [bytes] bytes (starts with `%PDF-`).
NewAttachment pickedPdf({String name = 'Hotel invoice.pdf', int bytes = 340 * 1024, String? id}) {
  final data = Uint8List(bytes);
  data.setRange(0, 5, const [0x25, 0x50, 0x44, 0x46, 0x2d]);
  return NewAttachment.pdf(data, name: name, id: id);
}

/// What a fake picker saw.
class PickerCall {
  PickerCall(this.source, this.max);

  final AttachmentSource source;
  final int max;
}

/// A picker that answers [files] / [problem] (or throws [error]) and records its calls.
class FakeAttachmentPicker {
  FakeAttachmentPicker({this.files = const [], this.problem, this.error});

  List<NewAttachment> files;
  AttachmentProblem? problem;
  Object? error;
  final calls = <PickerCall>[];

  Future<AttachmentPick> call(AttachmentSource source, {required int max}) async {
    calls.add(PickerCall(source, max));
    if (error != null) throw error!;
    return (files: files, problem: problem);
  }

  Override get override => attachmentPickerProvider.overrideWithValue(call);
}

/// A PDF platform with [pages] pages (each the sample PNG); [canOpen] is the answer of "Open with".
class FakePdfPlatform implements PdfPlatform {
  FakePdfPlatform({this.pages = 2, this.canOpen = true, this.fails = false});

  final int pages;
  final bool canOpen;
  final bool fails;
  final opened = <String>[];
  final rendered = <int>[];

  @override
  Future<int> pageCount(String path) async {
    if (fails) throw Exception('not a pdf');
    return pages;
  }

  @override
  Future<Uint8List> renderPage(String path, int index, int width) async {
    rendered.add(index);
    return samplePhotoPng;
  }

  @override
  Future<bool> openExternally(String path, String name) async {
    opened.add(path);
    return canOpen;
  }
}

/// Every stored photo of [rows] (thumbnail and full) resolves to [file]; nothing waits for upload. PDFs
/// resolve to [file] through [attachmentFileProvider]. [ready] holds the answers back (goldens decode the
/// file on the real event loop first).
List<Override> storedAttachments(
  List<LocalAttachment> rows,
  File file, {
  Future<void> Function()? ready,
}) => [
  for (final r in rows) ...[
    for (final path in [r.path, ?r.thumbPath])
      for (final thumb in [true, false])
        storedPhotoProvider((bucket: AttachmentPaths.bucket, path: path, thumb: thumb))
            .overrideWith((ref) async {
              await ready?.call();
              return file;
            }),
    for (final path in [r.path, ?r.thumbPath])
      for (final thumb in [true, false])
        photoPendingProvider((bucket: AttachmentPaths.bucket, path: path, thumb: thumb))
            .overrideWith((ref) => Stream.value(false)),
    if (r.kind == AttachmentKind.pdf.wire)
      attachmentFileProvider(r.path).overrideWith((ref) async => file),
  ],
];

/// A temp PDF-ish file for [attachmentFileProvider] overrides (the fake platform never reads it).
File samplePdfFile(void Function(Future<void> Function()) deleteAfter) =>
    samplePhotoFile(deleteAfter, 'invoice.pdf');

/// The expense page reads the expense's files from the database: goldens without one say "none" (W2-Y).
Override noAttachments(String expenseId) =>
    expenseAttachmentsProvider(expenseId)
        .overrideWith((ref) => Stream.value(const <LocalAttachment>[]));
