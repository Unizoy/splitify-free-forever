import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_compression.dart';
import 'package:splitify/features/photos/application/photo_providers.dart'
    show platformJpeg, readImageSize;

final _log = Logger('attachments');

/// Where new attachments come from (D-034 P-7): the camera, the Android photo picker (several at once) or
/// the system file picker for PDFs. None of them needs a storage permission.
enum AttachmentSource { camera, photos, pdf }

/// What a pick gave: the files that fit, and why others were left out (the first problem met).
typedef AttachmentPick = ({List<NewAttachment> files, AttachmentProblem? problem});

/// Picks up to [max] files; an empty list when the person backed out.
typedef AttachmentPicker = Future<AttachmentPick> Function(
  AttachmentSource source, {
  required int max,
});

/// Compresses a picked photo for an attachment (S-432): the stored JPEG with its longer side at most
/// [AttachmentLimits.photoSide] px, tried down [AttachmentLimits.ladder] until it fits
/// [AttachmentLimits.photoMaxBytes], plus a [AttachmentLimits.thumbSide] px thumbnail. HEIC and other
/// formats the size reader cannot decode are re-encoded once first. Logs the sizes (no content).
Future<NewAttachment> prepareAttachmentPhoto(
  Uint8List source, {
  required JpegEncode encode,
  required SizeReader sizeOf,
}) async {
  var input = source;
  ImageSize size;
  try {
    size = await sizeOf(input);
  } on Exception {
    input = await encode(input, bound: AttachmentLimits.photoSide * 2, quality: 95);
    size = await sizeOf(input);
  }
  late Uint8List full;
  var step = 0;
  for (final (side, quality) in AttachmentLimits.ladder) {
    step++;
    full = await encode(input, bound: squareBound(size, side), quality: quality);
    if (full.lengthInBytes <= AttachmentLimits.photoMaxBytes) break;
  }
  final thumb = await encode(
    input,
    bound: squareBound(size, AttachmentLimits.thumbSide),
    quality: AttachmentLimits.thumbQuality,
  );
  ImageSize? stored;
  try {
    stored = await sizeOf(full);
  } on Exception {
    stored = null;
  }
  _log.info(
    'photo ${size.width}x${size.height} ${source.lengthInBytes} B -> '
    '${stored?.width}x${stored?.height} ${full.lengthInBytes} B (step $step), '
    'thumb ${thumb.lengthInBytes} B',
  );
  return NewAttachment.photo(
    PreparedImage(full: full, thumb: thumb),
    width: stored?.width,
    height: stored?.height,
  );
}

/// A PDF read from the file picker, checked: a real PDF ([looksLikePdf]) of at most
/// [AttachmentLimits.pdfMaxBytes].
({NewAttachment? file, AttachmentProblem? problem}) preparePdf(Uint8List bytes, String name) {
  if (!looksLikePdf(bytes)) return (file: null, problem: AttachmentProblem.unreadable);
  if (bytes.lengthInBytes > AttachmentLimits.pdfMaxBytes) {
    return (file: null, problem: AttachmentProblem.tooBig);
  }
  _log.info('pdf ${bytes.lengthInBytes} B');
  return (file: NewAttachment.pdf(bytes, name: name), problem: null);
}

/// The device pickers (platform glue; proven on the device by `integration_test/w2y_test.dart`).
Future<AttachmentPick> pickAttachments(AttachmentSource source, {required int max}) async {
  if (max <= 0) return (files: const <NewAttachment>[], problem: AttachmentProblem.tooMany);
  switch (source) {
    case AttachmentSource.camera || AttachmentSource.photos:
      final platform = ImagePickerPlatform.instance;
      if (platform is ImagePickerAndroid) platform.useAndroidPhotoPicker = true;
      final picker = ImagePicker();
      final List<XFile> picked;
      if (source == AttachmentSource.camera) {
        final one = await picker.pickImage(source: ImageSource.camera, requestFullMetadata: false);
        picked = [?one];
      } else if (max == 1) {
        final one = await picker.pickImage(source: ImageSource.gallery, requestFullMetadata: false);
        picked = [?one];
      } else {
        picked = await picker.pickMultiImage(limit: max, requestFullMetadata: false);
      }
      final files = <NewAttachment>[];
      for (final f in picked.take(max)) {
        files.add(
          await prepareAttachmentPhoto(
            await f.readAsBytes(),
            encode: platformJpeg,
            sizeOf: readImageSize,
          ),
        );
      }
      return (files: files, problem: picked.length > max ? AttachmentProblem.tooMany : null);
    case AttachmentSource.pdf:
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      final files = <NewAttachment>[];
      AttachmentProblem? problem;
      for (final f in picked) {
        if (files.length >= max) {
          problem ??= AttachmentProblem.tooMany;
          break;
        }
        final size = await f.length();
        if (size != null && size > AttachmentLimits.pdfMaxBytes) {
          problem ??= AttachmentProblem.tooBig;
          continue;
        }
        final r = preparePdf(await f.readAsBytes(), f.name);
        if (r.file != null) files.add(r.file!);
        problem ??= r.problem;
      }
      return (files: files, problem: problem);
  }
}

/// The attachment picker (tests and device scenarios override it).
final attachmentPickerProvider = Provider<AttachmentPicker>((ref) => pickAttachments);
