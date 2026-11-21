import 'dart:io';

import 'package:drift/drift.dart';
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

/// Receipt photos and group covers (#29, S-073; 04 §6): saving a record together with its new photo
/// (one transaction: row + outbox + upload queue), dropping photos that never went up, and finding a
/// photo to show (local copy first, else a download through a cached signed URL).
class MediaRepository {
  MediaRepository({
    required this.db,
    required this.writer,
    required this.files,
    required this.remote,
    required this.clock,
  });

  final AppDatabase db;
  final LocalWriter writer;
  final MediaFiles files;
  final MediaRemote remote;
  final Clock clock;

  /// Signed URLs are asked for this long and reused until [_margin] before they run out.
  static const urlLifetime = Duration(hours: 1);
  static const _margin = Duration(minutes: 5);
  final _urls = <String, ({Uri url, DateTime expires})>{};

  /// Upserts [data] of a record and queues [image] for `bucket/path`, in one transaction.
  Future<void> saveWithPhoto({
    required SyncEntity entity,
    required String recordId,
    required String groupId,
    required Map<String, Object?> data,
    required String bucket,
    required String path,
    required PreparedImage image,
  }) async {
    final rel = await files.stage(bucket, path, image);
    await db.transaction(() async {
      await writer.write(entity, SyncOp.upsert, recordId, groupId, data);
      await db
          .into(db.pendingUploads)
          .insert(
            PendingUploadsCompanion.insert(
              id: newId(),
              bucket: bucket,
              localPath: rel,
              remotePath: path,
              recordId: recordId,
            ),
          );
    });
  }

  /// Saves an expense (snake_case [row]) with a new receipt photo; returns the photo's storage path.
  Future<String> saveExpenseWithReceipt(
    String groupId,
    String expenseId,
    Map<String, Object?> row,
    PreparedImage image,
  ) async {
    final path = MediaBuckets.receiptPath(groupId, expenseId, newId());
    await saveWithPhoto(
      entity: SyncEntity.expense,
      recordId: expenseId,
      groupId: groupId,
      data: {...row, 'receipt_path': path},
      bucket: MediaBuckets.receipts,
      path: path,
      image: image,
    );
    return path;
  }

  /// Gives a group a photo cover (S-073); returns the photo's storage path.
  Future<String> saveGroupCover(String groupId, PreparedImage image) async {
    final path = MediaBuckets.coverPath(groupId, newId());
    await saveWithPhoto(
      entity: SyncEntity.group,
      recordId: groupId,
      groupId: groupId,
      data: {'cover_kind': 'photo', 'cover_path': path},
      bucket: MediaBuckets.groupCovers,
      path: path,
      image: image,
    );
    return path;
  }

  /// Forgets a photo that is still waiting for upload (removed or replaced before it went up). Photos
  /// already on the server stay there for the edit history (rule 9).
  Future<void> discardPending(String bucket, String path) async {
    final n = await (db.delete(
      db.pendingUploads,
    )..where((u) => u.bucket.equals(bucket) & u.remotePath.equals(path))).go();
    if (n > 0) await files.discard(bucket, path);
  }

  /// True while `bucket/path` waits for upload ("Uploads when you're online").
  Stream<bool> watchPending(String bucket, String path) =>
      (db.select(db.pendingUploads)
            ..where((u) => u.bucket.equals(bucket) & u.remotePath.equals(path)))
          .watch()
          .map((rows) => rows.isNotEmpty);

  /// A file to show for `bucket/path`: the local copy, else downloaded once (signed URL) into the cache.
  /// Throws [MediaOffline] / [MediaRejected] when it is not on this phone and cannot be fetched.
  Future<File> file(String bucket, String path, {bool thumb = false}) async {
    final local = await files.local(bucket, path, thumb: thumb);
    if (local != null) return local;
    final bytes = await remote.download(await signedUrl(bucket, path));
    return files.cache(bucket, path, bytes);
  }

  /// Signed URL for `bucket/path`, reused while it has more than five minutes left.
  Future<Uri> signedUrl(String bucket, String path) async {
    final key = '$bucket/$path';
    final now = clock.now().toUtc();
    final hit = _urls[key];
    if (hit != null && hit.expires.difference(now) > _margin) return hit.url;
    final url = await remote.signedUrl(bucket, path, urlLifetime);
    _urls[key] = (url: url, expires: now.add(urlLifetime));
    return url;
  }
}
