import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/repositories/media_repository.dart';
import 'package:splitify/data/sync/uploads.dart';

/// Storage for photos. Bootstrap overrides it with the Supabase one; without settings (D-020) and in
/// widget tests every call fails like being offline.
final mediaRemoteProvider = Provider<MediaRemote>((ref) => const UnconfiguredMediaRemote());

/// Photo files on this phone (documents + cache folders). Tests override with temp folders.
final mediaFilesProvider = Provider<MediaFiles>(
  (ref) => MediaFiles(docs: getApplicationDocumentsDirectory, cache: getTemporaryDirectory),
);

/// Photo uploads; the sync engine runs it after every push.
final uploadQueueProvider = Provider<UploadQueue>(
  (ref) => UploadQueue(
    db: ref.watch(appDatabaseProvider),
    remote: ref.watch(mediaRemoteProvider),
    files: ref.watch(mediaFilesProvider),
  ),
);

/// Receipts and group covers for features.
final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(
    db: ref.watch(appDatabaseProvider),
    writer: ref.watch(localWriterProvider),
    files: ref.watch(mediaFilesProvider),
    remote: ref.watch(mediaRemoteProvider),
    clock: ref.watch(clockProvider),
  ),
);
