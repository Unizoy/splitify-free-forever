// TC-29-01 (receipt/cover save, pending queue, local-first file access, signed URL cache).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/repositories/media_repository.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

import '../sync/sync_fakes.dart';

class _Remote implements MediaRemote {
  final urlCalls = <String>[];
  final downloads = <Uri>[];
  Object? signError;
  Object? downloadError;
  final bytes = Uint8List.fromList([9, 9, 9]);

  @override
  Future<Uri> signedUrl(String bucket, String path, Duration lifetime) async {
    if (signError != null) throw signError!;
    urlCalls.add('$bucket/$path');
    return Uri.parse('https://x.test/${urlCalls.length}');
  }

  @override
  Future<Uint8List> download(Uri url) async {
    if (downloadError != null) throw downloadError!;
    downloads.add(url);
    return bytes;
  }

  @override
  Future<void> upload(String bucket, String path, Uint8List jpeg) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late Directory docs;
  late Directory cache;
  late MediaFiles files;
  late _Remote remote;
  late FakeClock clock;
  late SyncEngine engine;
  late MediaRepository repo;

  setUp(() {
    db = memoryDb();
    docs = Directory.systemTemp.createTempSync('mr_docs');
    cache = Directory.systemTemp.createTempSync('mr_cache');
    files = MediaFiles(docs: () async => docs, cache: () async => cache);
    remote = _Remote();
    clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    engine = SyncEngine(
      db: db,
      remote: FakeRemoteApi(),
      clock: clock,
      timer: ManualTimers().call,
      random: Random(1),
    );
    repo = MediaRepository(
      db: db,
      writer: LocalWriter(db, clock, engine.serverClock),
      files: files,
      remote: remote,
      clock: clock,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
    docs.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  final image = PreparedImage(full: Uint8List.fromList([1, 2]), thumb: Uint8List.fromList([3]));
  const eid = '01900000-0000-7000-8000-0000000000e1';

  Map<String, Object?> row() => {
    'description': 'Taxi',
    'date': '2026-11-21',
    'currency': 'INR',
    'total': 1000,
    'payers': {m1: 1000},
    'shares': {m1: 1000},
  };

  Future<List<PendingUpload>> pending() => db.select(db.pendingUploads).get();
  Future<List<OutboxItem>> outbox() => db.select(db.outbox).get();

  // TC-29-01
  test('saveExpenseWithReceipt writes row, outbox mutation and upload row together', () async {
    final path = await repo.saveExpenseWithReceipt(gid, eid, row(), image);
    expect(path, matches(RegExp('^$gid/$eid/[0-9a-f-]{36}\\.jpg\$')));
    final saved = await (db.select(db.expenses)..where((e) => e.id.equals(eid))).getSingle();
    expect(saved.receiptPath, path);
    final box = await outbox();
    expect(box, hasLength(1));
    expect(box.single.recordId, eid);
    final up = (await pending()).single;
    expect(up.bucket, MediaBuckets.receipts);
    expect(up.remotePath, path);
    expect(up.recordId, eid);
    expect(await files.read(up.localPath), [1, 2]);
  });

  // TC-29-01
  test(
    'the sync nudge after saving a photo runs outside the save transaction (device e2e bug)',
    () async {
      // The writer's onWrite schedules work later; it must not inherit a closed transaction's zone.
      Future<void>? later;
      final writer = LocalWriter(db, clock, engine.serverClock)
        ..onWrite = () =>
            later = Future<void>.delayed(Duration.zero, () => db.select(db.outbox).get());
      final r = MediaRepository(db: db, writer: writer, files: files, remote: remote, clock: clock);
      await r.saveExpenseWithReceipt(gid, eid, row(), image);
      await expectLater(later, completes);
    },
  );

  test('saveGroupCover sets cover_kind photo and queues the cover upload', () async {
    await db.customStatement(
      'INSERT INTO groups (id, name, type, main_currency, cover_kind, simplify_debts, '
      "created_at, seq, sync_state) VALUES ('$gid', 'Goa', 'trip', 'INR', 'generated', 0, "
      "'2026-11-20T10:00:00Z', 1, 'synced')",
    );
    final path = await repo.saveGroupCover(gid, image);
    expect(path, matches(RegExp('^$gid/[0-9a-f-]{36}\\.jpg\$')));
    final g = await (db.select(db.groups)..where((e) => e.id.equals(gid))).getSingle();
    expect(g.coverKind, 'photo');
    expect(g.coverPath, path);
    expect((await outbox()).single.entity, 'group');
    final up = (await pending()).single;
    expect(up.bucket, MediaBuckets.groupCovers);
    expect(up.recordId, gid);
  });

  // TC-29-01
  test('discardPending removes row and files only when a row existed', () async {
    final path = await repo.saveExpenseWithReceipt(gid, eid, row(), image);
    final rel = (await pending()).single.localPath;
    await repo.discardPending(MediaBuckets.receipts, 'other/path.jpg');
    expect(await pending(), hasLength(1));
    expect(await files.read(rel), isNotNull);

    await repo.discardPending(MediaBuckets.receipts, path);
    expect(await pending(), isEmpty);
    expect(await files.read(rel), isNull);
  });

  // TC-29-01
  test('watchPending emits true while queued, then false once discarded', () async {
    final path = await repo.saveExpenseWithReceipt(gid, eid, row(), image);
    final seen = <bool>[];
    final sub = repo.watchPending(MediaBuckets.receipts, path).listen(seen.add);
    await pumpEventQueue();
    await repo.discardPending(MediaBuckets.receipts, path);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [true, false]);
  });

  // TC-29-01
  test('file returns the local copy without any remote call', () async {
    await files.stage(MediaBuckets.receipts, 'g/a.jpg', image);
    final f = await repo.file(MediaBuckets.receipts, 'g/a.jpg');
    expect(f.readAsBytesSync(), [1, 2]);
    final t = await repo.file(MediaBuckets.receipts, 'g/a.jpg', thumb: true);
    expect(t.readAsBytesSync(), [3]);
    expect(remote.urlCalls, isEmpty);
    expect(remote.downloads, isEmpty);
  });

  // TC-29-01
  test('file downloads once through a signed URL, then serves the cached file', () async {
    final f = await repo.file(MediaBuckets.receipts, 'g/b.jpg');
    expect(f.readAsBytesSync(), [9, 9, 9]);
    expect(remote.urlCalls, ['receipts/g/b.jpg']);
    expect(remote.downloads, hasLength(1));
    final again = await repo.file(MediaBuckets.receipts, 'g/b.jpg');
    expect(again.path, f.path);
    expect(remote.downloads, hasLength(1));
    expect(remote.urlCalls, hasLength(1));
  });

  // TC-29-01
  test('signedUrl is reused until less than five minutes of the hour are left', () async {
    final a = await repo.signedUrl('receipts', 'g/c.jpg');
    clock.time = clock.time.add(const Duration(minutes: 54));
    expect(await repo.signedUrl('receipts', 'g/c.jpg'), a);
    expect(remote.urlCalls, hasLength(1));
    clock.time = clock.time.add(const Duration(minutes: 2));
    final b = await repo.signedUrl('receipts', 'g/c.jpg');
    expect(b, isNot(a));
    expect(remote.urlCalls, hasLength(2));
    await repo.signedUrl('receipts', 'g/d.jpg');
    expect(remote.urlCalls, hasLength(3));
  });

  // TC-29-01
  test('remote errors propagate', () async {
    remote.signError = const MediaOffline();
    await expectLater(repo.file(MediaBuckets.receipts, 'g/e.jpg'), throwsA(isA<MediaOffline>()));
    remote.signError = null;
    remote.downloadError = const MediaRejected('403');
    await expectLater(repo.file(MediaBuckets.receipts, 'g/e.jpg'), throwsA(isA<MediaRejected>()));
  });
}
