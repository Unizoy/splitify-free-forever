import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/domain/entities/attachment.dart';

final _log = Logger('uploads');

/// The photo and file upload queue (`pending_uploads`, 04 §6; attachments W2-Y). A photo goes up only once its record's mutation
/// was applied (no outbox row left for the record), so the server knows the group and the record
/// first. Runs after every push; one run at a time; a network failure stops the run until the next
/// sync, a refusal counts an attempt and the photo is skipped after [maxAttempts].
class UploadQueue {
  UploadQueue({
    required this.db,
    required this.remote,
    required this.files,
    this.maxAttempts = skipAfter,
  });

  /// Refusals after which a photo is skipped (S-113); "Sync & storage" lists it with Retry.
  static const skipAfter = 8;

  final AppDatabase db;
  final MediaRemote remote;
  final MediaFiles files;
  final int maxAttempts;

  Future<int>? _running;

  static const _rowid = CustomExpression<int>('rowid');

  /// Uploads what is ready; returns how many photos went up. Joins a run in progress.
  Future<int> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<int> _run() async {
    final waiting = db.selectOnly(db.outbox)..addColumns([db.outbox.recordId]);
    final rows =
        await (db.select(db.pendingUploads)
              ..where((u) => u.attempts.isSmallerThanValue(maxAttempts))
              ..where((u) => u.recordId.isNotInQuery(waiting))
              // Queued order (an attachment's thumbnail before its photo, W2-Y): ids made in the same
              // millisecond are not ordered.
              ..orderBy([(u) => OrderingTerm.asc(_rowid), (u) => OrderingTerm.asc(u.id)]))
            .get();
    var done = 0;
    for (final row in rows) {
      final bytes = await files.read(row.localPath);
      if (bytes == null) {
        _log.warning('upload ${row.id}: local file is gone, dropping it');
        await _delete(row);
        continue;
      }
      try {
        await remote.upload(row.bucket, row.remotePath, bytes);
      } on MediaOffline catch (e) {
        _log.info('upload paused: $e');
        return done;
      } on MediaRejected catch (e) {
        _log.warning('upload ${row.id} refused: ${e.code}');
        await (db.update(db.pendingUploads)..where((u) => u.id.equals(row.id))).write(
          PendingUploadsCompanion(attempts: Value(row.attempts + 1)),
        );
        continue;
      }
      await _delete(row);
      await files.uploaded(
        row.bucket,
        row.remotePath,
        keepFull: AttachmentPaths.keepAfterUpload(row.bucket, row.remotePath),
      );
      done++;
    }
    return done;
  }

  Future<void> _delete(PendingUpload row) =>
      (db.delete(db.pendingUploads)..where((u) => u.id.equals(row.id))).go();
}
