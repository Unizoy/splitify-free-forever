// TC-29-01 (receipt/cover upload queue): upload after the record's mutation, retry rules, single flight.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/sync/uploads.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

import 'sync_fakes.dart';

class _Remote implements MediaRemote {
  final uploaded = <String>[];
  final script = <Object?>[];
  Completer<void>? gate;

  @override
  Future<void> upload(String bucket, String path, Uint8List jpeg) async {
    await gate?.future;
    final next = script.isEmpty ? null : script.removeAt(0);
    if (next is Exception) throw next;
    uploaded.add('$bucket/$path');
  }

  @override
  Future<Uri> signedUrl(String bucket, String path, Duration lifetime) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> download(Uri url) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late Directory docs;
  late Directory cache;
  late MediaFiles files;
  late _Remote remote;
  late UploadQueue queue;

  setUp(() {
    db = memoryDb();
    docs = Directory.systemTemp.createTempSync('up_docs');
    cache = Directory.systemTemp.createTempSync('up_cache');
    files = MediaFiles(docs: () async => docs, cache: () async => cache);
    remote = _Remote();
    queue = UploadQueue(db: db, remote: remote, files: files, maxAttempts: 3);
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  final image = PreparedImage(full: Uint8List.fromList([1, 2]), thumb: Uint8List.fromList([3]));

  Future<void> add(
    String id, {
    String bucket = MediaBuckets.receipts,
    String record = 'r1',
    bool stage = true,
    int attempts = 0,
  }) async {
    final path = 'g/$id.jpg';
    final rel = stage
        ? await files.stage(bucket, path, image)
        : MediaFiles.pendingRel(bucket, path);
    await db
        .into(db.pendingUploads)
        .insert(
          PendingUploadsCompanion.insert(
            id: id,
            bucket: bucket,
            localPath: rel,
            remotePath: path,
            recordId: record,
            attempts: Value(attempts),
          ),
        );
  }

  Future<List<PendingUpload>> rows() => db.select(db.pendingUploads).get();

  Future<void> outboxRow(String record) => db.customStatement(
    'INSERT INTO outbox (mutation_id, entity, op, record_id, group_id, payload, '
    'client_updated_at, created_at) '
    "VALUES ('m-$record', 'expense', 'upsert', '$record', 'g', '{}', "
    "'2026-11-21T10:00:00Z', '2026-11-21T10:00:00Z')",
  );

  // TC-29-01
  test('UploadQueue.run uploads every ready photo in order and deletes the rows', () async {
    await add('a');
    await add('b', bucket: MediaBuckets.groupCovers, record: 'g1');
    expect(await queue.run(), 2);
    expect(remote.uploaded, ['receipts/g/a.jpg', 'group-covers/g/b.jpg']);
    expect(await rows(), isEmpty);
    expect(await files.local(MediaBuckets.receipts, 'g/a.jpg', thumb: false), isNull);
    expect(await files.local(MediaBuckets.groupCovers, 'g/b.jpg', thumb: false), isNotNull);
  });

  // TC-29-01
  test('UploadQueue.run waits while the record still has an outbox mutation', () async {
    await add('a');
    await outboxRow('r1');
    expect(await queue.run(), 0);
    expect(remote.uploaded, isEmpty);
    expect(await rows(), hasLength(1));
    await db.customStatement('DELETE FROM outbox');
    expect(await queue.run(), 1);
  });

  // TC-29-01
  test('UploadQueue.run skips photos that reached the attempt limit', () async {
    await add('a', attempts: 3);
    expect(await queue.run(), 0);
    expect(remote.uploaded, isEmpty);
    expect(await rows(), hasLength(1));
  });

  // TC-29-01
  test('UploadQueue.run drops a row whose local file is gone and goes on', () async {
    await add('a', stage: false);
    await add('b');
    expect(await queue.run(), 1);
    expect(remote.uploaded, ['receipts/g/b.jpg']);
    expect(await rows(), isEmpty);
  });

  // TC-29-01
  test('UploadQueue.run stops at the first network failure and keeps every row', () async {
    await add('a');
    await add('b');
    remote.script.add(const MediaOffline());
    expect(await queue.run(), 0);
    expect(remote.uploaded, isEmpty);
    final left = await rows();
    expect(left, hasLength(2));
    expect(left.every((r) => r.attempts == 0), isTrue);
    expect(await queue.run(), 2);
  });

  // TC-29-01
  test('UploadQueue.run counts an attempt on a refusal and carries on', () async {
    await add('a');
    await add('b');
    remote.script.add(const MediaRejected('403'));
    expect(await queue.run(), 1);
    expect(remote.uploaded, ['receipts/g/b.jpg']);
    final left = await rows();
    expect(left.single.id, 'a');
    expect(left.single.attempts, 1);
  });

  // TC-29-01
  test('UploadQueue.run joins a run in progress (single flight)', () async {
    await add('a');
    remote.gate = Completer<void>();
    final first = queue.run();
    final second = queue.run();
    expect(identical(first, second), isTrue);
    remote.gate!.complete();
    expect(await first, 1);
    expect(remote.uploaded, hasLength(1));
    expect(await queue.run(), 0);
  });
}
