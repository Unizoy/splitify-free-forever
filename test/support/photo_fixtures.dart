// Shared photo fixtures for widget tests and goldens (no network, no platform picker).
import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';

import 'sample_photo.dart';

/// The sample photo as a compressed pick (full and thumbnail are the same small PNG).
final PreparedImage samplePrepared = PreparedImage(full: samplePhotoPng, thumb: samplePhotoPng);

/// A temp file holding the sample photo; [deleteAfter] runs the clean-up (pass `addTearDown`).
File samplePhotoFile(void Function(Future<void> Function()) deleteAfter, [String name = 'p.png']) {
  final dir = Directory.systemTemp.createTempSync('splitify_photo');
  final file = File('${dir.path}/$name')..writeAsBytesSync(samplePhotoPng);
  deleteAfter(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return file;
}

/// Picker that always answers [image] (null = the person backed out).
Override pickerReturns(PreparedImage? image) =>
    preparedPhotoPickerProvider.overrideWithValue((source) async => image);

/// Picker that fails like an unreadable photo.
Override pickerThrows() => preparedPhotoPickerProvider.overrideWithValue(
  (source) async => throw Exception('cannot read photo'),
);

/// Stored receipt [path] resolves to [file] (thumb and full), optionally waiting for upload.
///
/// [ready] holds the answer back until it completes (goldens decode the file on the real event loop first).
List<Override> storedReceipt(
  String path,
  File file, {
  bool pending = false,
  Future<void> Function()? ready,
}) => [
  for (final thumb in [true, false])
    storedPhotoProvider((bucket: MediaBuckets.receipts, path: path, thumb: thumb))
        .overrideWith((ref) async {
          await ready?.call();
          return file;
        }),
  photoPendingProvider((bucket: MediaBuckets.receipts, path: path, thumb: true))
      .overrideWith((ref) => Stream.value(pending)),
];

/// Stored group cover [path] resolves to [file].
Override storedGroupCover(String path, File file, {Future<void> Function()? ready}) =>
    storedPhotoProvider((bucket: MediaBuckets.groupCovers, path: path, thumb: false))
        .overrideWith((ref) async {
          await ready?.call();
          return file;
        });
