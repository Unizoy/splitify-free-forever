import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';
import 'package:splitify/features/photos/application/photo_compression.dart';
import 'package:splitify/features/photos/application/photo_providers.dart';

/// Recognises the text of the picture at a file path (D-034 A3). On the phone, offline: ML Kit's bundled
/// Latin model (S-370). Tests and device scenarios override [receiptOcrProvider].
typedef ReceiptOcr = Future<List<OcrLine>> Function(String path);

/// Picks a receipt picture and returns its file path (null when the person backs out).
typedef ReceiptImagePicker = Future<String?> Function(PhotoSource source);

/// Turns the picked file into the receipt photo kept with the expense (compressed, with a thumbnail).
typedef ReceiptPhotoPreparer = Future<PreparedImage> Function(String path);

/// ML Kit text recognition on [path] (EXIF rotation applied by ML Kit). Platform glue: proven on the
/// device (`integration_test/d034_a_test.dart`).
Future<List<OcrLine>> mlKitOcr(String path) async {
  final recognizer = TextRecognizer();
  try {
    final text = await recognizer.processImage(InputImage.fromFilePath(path));
    return [
      for (final block in text.blocks)
        for (final line in block.lines)
          OcrLine(
            line.text,
            left: line.boundingBox.left.round(),
            top: line.boundingBox.top.round(),
            right: line.boundingBox.right.round(),
            bottom: line.boundingBox.bottom.round(),
          ),
    ];
  } finally {
    await recognizer.close();
  }
}

/// Camera, or the Android photo picker (no storage permission, S-110), at full size: the text model
/// reads the original, the expense keeps a compressed copy.
Future<String?> pickReceiptPath(PhotoSource source) async {
  final platform = ImagePickerPlatform.instance;
  if (platform is ImagePickerAndroid) platform.useAndroidPhotoPicker = true;
  final file = await ImagePicker().pickImage(
    source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
    requestFullMetadata: false,
  );
  return file?.path;
}

Future<PreparedImage> _prepare(String path) async =>
    preparePhoto(await File(path).readAsBytes(), encode: platformJpeg, sizeOf: readImageSize);

final receiptOcrProvider = Provider<ReceiptOcr>((ref) => mlKitOcr);

final receiptImagePickerProvider = Provider<ReceiptImagePicker>((ref) => pickReceiptPath);

final receiptPhotoPreparerProvider = Provider<ReceiptPhotoPreparer>((ref) => _prepare);

/// What a scan gives the editor: the text read from the receipt and the photo to attach (null when the
/// file could not be turned into one).
typedef ScanOutcome = ({ReceiptScan scan, PreparedImage? photo});

/// Reads the receipt at [path]: the photo for the expense and the parsed text ([exponent] = the
/// expense currency's decimals). Never saves anything (S-373).
Future<ScanOutcome> readReceipt(
  ReceiptOcr ocr,
  ReceiptPhotoPreparer prepare,
  String path, {
  required int exponent,
  DateTime? today,
}) async {
  PreparedImage? photo;
  try {
    photo = await prepare(path);
  } on Exception {
    photo = null;
  }
  final lines = await ocr(path);
  final scan = parseReceipt(receiptRows(lines), exponent: exponent, today: today);
  return (scan: scan, photo: photo);
}
