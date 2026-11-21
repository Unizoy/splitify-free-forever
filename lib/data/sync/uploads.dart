import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

final _log = Logger('uploads');

/// The photo upload queue (`pending_uploads`, 04 §6). A photo goes up only once its record's mutation
/// was applied (no outbox row left for the record), so the server knows the group and the record
/// first. Runs after every push; one run at a time; a network failure stops the run until the next
/// sync, a refusal counts an attempt and the photo is skipped after [maxAttempts].
class UploadQueue {
  UploadQueue({required this.db, required this.remote, required this.files, this.maxAttempts = 8});

  final AppDatabase db;
  final MediaRemote remote;
  final MediaFiles files;
  final int maxAttempts;

  Future<int>? _running;

  /// Uploads what is ready; returns how many photos went up. Joins a run in progress.
  Future<int> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<int> _run() async {
    final waiting = db.selectOnly(db.outbox)..addColumns([db.outbox.recordId]);
    final rows =
        await (db.select(db.pendingUploads)
              ..where((u) => u.attempts.isSmallerThanValue(maxAttempts))
              ..where((u) => u.recordId.isNotInQuery(waiting))
              ..orderBy([(u) => OrderingTerm.asc(u.id)]))
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
        keepFull: row.bucket != MediaBuckets.receipts,
      );
      done++;
    }
    return done;
  }

  Future<void> _delete(PendingUpload row) =>
      (db.delete(db.pendingUploads)..where((u) => u.id.equals(row.id))).go();
}
