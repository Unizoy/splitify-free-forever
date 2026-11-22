import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/import_repository.dart';

final importRepositoryProvider = Provider<ImportRepository>(
  (ref) => ImportRepository(ref.watch(appDatabaseProvider), ref.watch(localWriterProvider)),
);

/// Imports of a group done on this phone (not deleted), newest first.
final importBatchesProvider = StreamProvider.autoDispose.family<List<LocalImportBatch>, String>(
  (ref, groupId) => ref.watch(importRepositoryProvider).watchForGroup(groupId),
);

/// A picked file: its name and bytes.
typedef PickedFile = ({String name, Uint8List bytes});

/// The system file picker (a seam for tests).
abstract interface class ImportFilePicker {
  /// The chosen file, or null when the user backs out.
  Future<PickedFile?> pick();
}

/// `file_picker` (Android Storage Access Framework; no storage permission needed).
class DeviceImportFilePicker implements ImportFilePicker {
  const DeviceImportFilePicker();

  @override
  Future<PickedFile?> pick() async {
    // Any type: Android often labels CSV downloads text/plain or octet-stream; the parser checks.
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes());
  }
}

final importFilePickerProvider = Provider<ImportFilePicker>(
  (ref) => const DeviceImportFilePicker(),
);
