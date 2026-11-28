import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/repositories/attachments_repository.dart';
import 'package:splitify/domain/entities/attachment.dart';

/// Photos and PDFs of expenses (W2-Y).
final attachmentsRepositoryProvider = Provider<AttachmentsRepository>(
  (ref) => AttachmentsRepository(
    db: ref.watch(appDatabaseProvider),
    writer: ref.watch(localWriterProvider),
    files: ref.watch(mediaFilesProvider),
  ),
);

/// The live files of one expense, in order.
final expenseAttachmentsProvider = StreamProvider.autoDispose.family<List<LocalAttachment>, String>(
  (ref, expenseId) => ref.watch(attachmentsRepositoryProvider).watchForExpense(expenseId),
);

/// The local file of a stored attachment (PDF or full photo): this phone's copy, else downloaded once
/// through a signed URL. Errors with `MediaOffline` when it is not here and the phone is offline.
final attachmentFileProvider = FutureProvider.autoDispose.family<File, String>(
  (ref, path) => ref.watch(mediaRepositoryProvider).file(AttachmentPaths.bucket, path),
  retry: (_, _) => null,
);

/// Android's own PDF tools (`splitify/pdf` in MainActivity: PdfRenderer and an ACTION_VIEW intent). No PDF
/// library is bundled, so the APK does not grow (S-433).
abstract interface class PdfPlatform {
  /// Number of pages; throws [PlatformException] when the file is not a readable PDF.
  Future<int> pageCount(String path);

  /// Page [index] as a PNG [width] pixels wide (white background).
  Future<Uint8List> renderPage(String path, int index, int width);

  /// Opens the PDF in another app; false when no app can show PDFs.
  Future<bool> openExternally(String path, String name);
}

class MethodChannelPdf implements PdfPlatform {
  const MethodChannelPdf();

  static const _channel = MethodChannel('splitify/pdf');

  @override
  Future<int> pageCount(String path) async =>
      (await _channel.invokeMethod<int>('pageCount', {'path': path})) ?? 0;

  @override
  Future<Uint8List> renderPage(String path, int index, int width) async => (await _channel
      .invokeMethod<Uint8List>('render', {'path': path, 'page': index, 'width': width}))!;

  @override
  Future<bool> openExternally(String path, String name) async =>
      (await _channel.invokeMethod<bool>('open', {'path': path, 'name': name})) ?? false;
}

/// The PDF tools (tests override with a fake).
final pdfPlatformProvider = Provider<PdfPlatform>((ref) => const MethodChannelPdf());
