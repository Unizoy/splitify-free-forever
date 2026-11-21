import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/photos/application/photo_compression.dart';

/// Where a new photo comes from.
enum PhotoSource { camera, gallery }

/// Picks a photo and returns it compressed with its thumbnail, or null when the person backed out.
typedef PreparedPhotoPicker = Future<PreparedImage?> Function(PhotoSource source);

/// Camera, or the Android photo picker (no storage permission, S-110). Platform glue: proven on the
/// device (phase 10 e2e); the compression policy itself is [preparePhoto].
Future<PreparedImage?> pickPreparedPhoto(PhotoSource source) async {
  final platform = ImagePickerPlatform.instance;
  if (platform is ImagePickerAndroid) platform.useAndroidPhotoPicker = true;
  final file = await ImagePicker().pickImage(
    source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
    requestFullMetadata: false,
  );
  if (file == null) return null;
  return preparePhoto(await file.readAsBytes(), encode: platformJpeg, sizeOf: readImageSize);
}

/// JPEG re-encode on the platform (EXIF rotation applied, EXIF dropped so no location leaks).
Future<Uint8List> platformJpeg(Uint8List source, {required int bound, required int quality}) =>
    FlutterImageCompress.compressWithList(
      source,
      minWidth: bound,
      minHeight: bound,
      quality: quality,
    );

/// Pixel size from the image header (no full decode).
Future<ImageSize> readImageSize(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final d = await ui.ImageDescriptor.encoded(buffer);
    final size = (width: d.width, height: d.height);
    d.dispose();
    return size;
  } finally {
    buffer.dispose();
  }
}

/// The photo picker (tests and device scenarios override it).
final preparedPhotoPickerProvider = Provider<PreparedPhotoPicker>((ref) => pickPreparedPhoto);

/// One stored photo to show: [thumb] prefers the small local copy.
typedef PhotoRef = ({String bucket, String path, bool thumb});

/// The file to show for a stored photo (local first, else downloaded once through a signed URL).
/// Errors when it is not on this phone and cannot be fetched (offline): the UI shows a placeholder.
final storedPhotoProvider = FutureProvider.autoDispose.family<File, PhotoRef>(
  (ref, r) => ref.watch(mediaRepositoryProvider).file(r.bucket, r.path, thumb: r.thumb),
  retry: (_, _) => null,
);

/// True while the photo waits for upload.
final photoPendingProvider = StreamProvider.autoDispose.family<bool, PhotoRef>(
  (ref, r) => ref.watch(mediaRepositoryProvider).watchPending(r.bucket, r.path),
);
