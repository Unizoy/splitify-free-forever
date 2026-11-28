// W2-Y (P-7, 0029): photos and PDFs of an expense on the phone — staged files, one transaction with the outbox
// and the upload queue, uploads only after the row is on the server (thumbnail first), what stays on the phone
// afterwards, remove / restore, the pull of other phones' rows and forgetting a lost group.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/attachments_repository.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/data/sync/server_clock.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/data/sync/uploads.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';

import '../sync/sync_fakes.dart';

class _Remote implements MediaRemote {
  final uploaded = <String>[];
  bool offline = false;

  @override
  Future<void> upload(String bucket, String path, Uint8List jpeg) async {
    if (offline) throw const MediaOffline();
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
  late AttachmentsRepository repo;
  late UploadQueue queue;

  const g = 'g1';
  const e = 'e1';

  setUp(() {
    db = memoryDb();
    docs = Directory.systemTemp.createTempSync('at_docs');
    cache = Directory.systemTemp.createTempSync('at_cache');
    files = MediaFiles(docs: () async => docs, cache: () async => cache);
    remote = _Remote();
    final clock = FakeClock(DateTime.utc(2026, 11, 28, 10));
    repo = AttachmentsRepository(
      db: db,
      writer: LocalWriter(db, clock, ServerClock(clock, SyncDao(db))),
      files: files,
    );
    queue = UploadQueue(db: db, remote: remote, files: files);
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  final photo = NewAttachment.photo(
    PreparedImage(full: Uint8List.fromList([1, 2, 3]), thumb: Uint8List.fromList([9])),
    width: 3072,
    height: 2304,
  );
  final pdf = NewAttachment.pdf(Uint8List.fromList(utf8.encode('%PDF-1.4 x')), name: 'Bill.pdf');

  Future<List<OutboxItem>> outbox() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();

  Future<void> serverApplied() => db.delete(db.outbox).go();

  test(
    'saveWithExpense: the expense first, then each file, in one transaction with its uploads',
    () async {
      await repo.saveWithExpense(
        groupId: g,
        expenseId: e,
        expenseRow: {
          'description': 'Hotel',
          'date': '2026-11-27',
          'currency': 'INR',
          'total': 100,
          'payers': {'m1': 100},
          'shares': {'m1': 100},
        },
        added: [photo, pdf],
        firstPosition: 3,
      );
      final out = await outbox();
      expect(out.map((o) => (o.entity, o.recordId)), [
        ('expense', e),
        ('attachment', photo.id),
        ('attachment', pdf.id),
      ]);
      final rows = await repo.forExpense(e);
      expect(rows.map((a) => (a.kind, a.position, a.sizeBytes, a.width, a.name)), [
        ('photo', 3, 3, 3072, null),
        ('pdf', 4, 10, null, 'Bill.pdf'),
      ]);
      final up = await (db.select(
        db.pendingUploads,
      )..orderBy([(u) => OrderingTerm.asc(const CustomExpression<int>('rowid'))])).get();
      expect(up.map((u) => u.remotePath), [
        AttachmentPaths.thumb(g, e, photo.id),
        AttachmentPaths.file(g, e, photo.id, AttachmentKind.photo),
        AttachmentPaths.file(g, e, pdf.id, AttachmentKind.pdf),
      ]);
      expect(up.every((u) => u.bucket == 'expense-files'), isTrue);
    },
  );

  test(
    'uploads wait for the rows, go thumbnail first, then keep thumbnails and PDFs on the phone',
    () async {
      await repo.add(g, e, [photo, pdf], firstPosition: 0);
      expect(await queue.run(), 0, reason: 'the rows are not on the server yet');

      await serverApplied();
      expect(await queue.run(), 3);
      final thumb = AttachmentPaths.thumb(g, e, photo.id);
      final full = AttachmentPaths.file(g, e, photo.id, AttachmentKind.photo);
      final doc = AttachmentPaths.file(g, e, pdf.id, AttachmentKind.pdf);
      expect(remote.uploaded, [
        'expense-files/$thumb',
        'expense-files/$full',
        'expense-files/$doc',
      ]);
      expect(await db.select(db.pendingUploads).get(), isEmpty);
      // Thumbnail and PDF stay (shown and opened offline); the big photo comes back through a signed URL.
      expect(await files.local(AttachmentPaths.bucket, thumb, thumb: true), isNotNull);
      expect(await files.local(AttachmentPaths.bucket, doc, thumb: false), isNotNull);
      expect(await files.local(AttachmentPaths.bucket, full, thumb: false), isNull);
    },
  );

  test('offline: nothing is lost, the next run sends it', () async {
    await repo.add(g, e, [pdf], firstPosition: 0);
    await serverApplied();
    remote.offline = true;
    expect(await queue.run(), 0);
    expect(await db.select(db.pendingUploads).get(), hasLength(1));
    remote.offline = false;
    expect(await queue.run(), 1);
  });

  test('remove and restore are queued soft deletes; the list hides removed files', () async {
    await repo.add(g, e, [photo, pdf], firstPosition: 0);
    final saved = (await repo.forExpense(e)).first;
    await repo.remove(saved);
    expect((await repo.forExpense(e)).map((a) => a.id), [pdf.id]);
    final del = (await outbox()).last;
    expect((del.entity, del.op, del.recordId), ('attachment', 'delete', photo.id));
    expect(jsonDecode(del.payload), {'expense_id': e, 'kind': 'photo'});
    expect(
      await db.select(db.pendingUploads).get(),
      hasLength(3),
      reason: 'Undo must still find the file',
    );

    await repo.restore(saved);
    expect((await repo.forExpense(e)).map((a) => a.id), [photo.id, pdf.id]);
    expect((await outbox()).last.op, 'restore');
    expect(await repo.forGroups([g]), hasLength(2));
  });

  test('saveWithExpense takes saved files out by id', () async {
    await repo.add(g, e, [photo], firstPosition: 0);
    await repo.saveWithExpense(
      groupId: g,
      expenseId: e,
      expenseRow: {
        'description': 'Hotel',
        'date': '2026-11-27',
        'currency': 'INR',
        'total': 100,
        'payers': {'m1': 100},
        'shares': {'m1': 100},
      },
      removedIds: [photo.id],
    );
    expect(await repo.forExpense(e), isEmpty);
    expect((await outbox()).last.op, 'delete');
  });

  test('watchForExpense follows changes', () async {
    final seen = <int>[];
    final sub = repo.watchForExpense(e).listen((rows) => seen.add(rows.length));
    await pumpEventQueue();
    await repo.add(g, e, [pdf], firstPosition: 0);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, 0);
    expect(seen.last, 1);
  });

  test(
    'the pull stores other phones\' files and keeps my unsent ones; a lost group forgets them',
    () async {
      await repo.add(g, e, [pdf], firstPosition: 0);
      final applier = PullApplier(db);
      Map<String, Object?> row(String id, {String? deletedAt}) => {
        'id': id,
        'group_id': g,
        'expense_id': e,
        'kind': 'photo',
        'path': '$g/$e/$id.jpg',
        'thumb_path': '$g/$e/$id-thumb.jpg',
        'name': null,
        'size_bytes': 512000,
        'width': 1600,
        'height': 1200,
        'position': 1,
        'created_at': '2026-11-28T10:00:00Z',
        'deleted_at': deletedAt,
        'seq': 44,
      };
      await applier.apply(
        PullPage(
          rows: {
            'expense_attachments': [
              row('a-other'),
              {...row(pdf.id), 'kind': 'pdf', 'size_bytes': 1},
            ],
          },
          nextCursors: const {g: 44},
          userSeq: 0,
          lostGroups: const [],
          hasMore: false,
          serverTime: DateTime.utc(2026, 11, 28),
        ),
      );
      final rows = {for (final a in await repo.forExpense(e)) a.id: a};
      expect(rows['a-other']!.syncState, SyncState.synced);
      expect(rows['a-other']!.sizeBytes, 512000);
      expect(rows[pdf.id]!.sizeBytes, 10, reason: 'my unsent row wins until it is pushed');

      await applier.forgetGroup(g);
      expect(await db.select(db.expenseAttachments).get(), isEmpty);
    },
  );

  test('paths, content types and what stays on the phone', () {
    expect(AttachmentPaths.file('g', 'e', 'a', AttachmentKind.photo), 'g/e/a.jpg');
    expect(AttachmentPaths.file('g', 'e', 'a', AttachmentKind.pdf), 'g/e/a.pdf');
    expect(AttachmentPaths.thumb('g', 'e', 'a'), 'g/e/a-thumb.jpg');
    expect(AttachmentPaths.contentType('g/e/a.pdf'), 'application/pdf');
    expect(AttachmentPaths.contentType('g/e/a.PDF'), 'application/pdf');
    expect(AttachmentPaths.contentType('g/e/a.jpg'), 'image/jpeg');
    expect(AttachmentPaths.keepAfterUpload('expense-files', 'g/e/a-thumb.jpg'), isTrue);
    expect(AttachmentPaths.keepAfterUpload('expense-files', 'g/e/a.pdf'), isTrue);
    expect(AttachmentPaths.keepAfterUpload('expense-files', 'g/e/a.jpg'), isFalse);
    expect(AttachmentPaths.keepAfterUpload(MediaBuckets.receipts, 'g/e/r.jpg'), isFalse);
    expect(AttachmentPaths.keepAfterUpload(MediaBuckets.groupCovers, 'g/c.jpg'), isTrue);
    expect(AttachmentPaths.keepAfterUpload(MediaBuckets.avatars, 'u/a.jpg'), isTrue);
  });
}
