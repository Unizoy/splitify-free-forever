// TC-29-01 (W2-Y): the expense's files in the editor — photos and PDFs saved as attachments with the expense,
// reopened, taken out (soft delete), the old single receipt photo kept and removable — + lastCategory ignoring
// loans.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/domain/entities/attachment.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';

import 'expense_test_env.dart';

void main() {
  late ExpenseEnv env;
  late Directory docs;
  late Directory cache;

  final image = PreparedImage(full: Uint8List.fromList([1, 2]), thumb: Uint8List.fromList([3]));
  final pdf = NewAttachment.pdf(
    Uint8List.fromList(utf8.encode('%PDF-1.7 tiny')),
    name: 'Hotel invoice.pdf',
  );

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('er_docs');
    cache = Directory.systemTemp.createTempSync('er_cache');
    final files = MediaFiles(docs: () async => docs, cache: () async => cache);
    env = await ExpenseEnv.create(overrides: [mediaFilesProvider.overrideWithValue(files)]);
  });

  tearDown(() {
    env.dispose();
    docs.deleteSync(recursive: true);
    cache.deleteSync(recursive: true);
  });

  ExpenseDraft Function(ExpenseDraft) fill(String amount) =>
      (d) => d.copyWith(amountText: amount, description: 'Dinner');

  Future<LocalExpense> expense(String id) =>
      (env.db.select(env.db.expenses)..where((e) => e.id.equals(id))).getSingle();

  Future<List<PendingUpload>> pending() => env.db.select(env.db.pendingUploads).get();

  Future<List<LocalAttachment>> attachments() => (env.db.select(
    env.db.expenseAttachments,
  )..orderBy([(a) => OrderingTerm.asc(a.position)])).get();

  /// The expense and attachment mutations (the test group's own set-up rows left out).
  Future<List<OutboxItem>> outbox() async => [
    for (final o in await (env.db.select(
      env.db.outbox,
    )..orderBy([(o) => OrderingTerm.asc(o.seq)])).get())
      if (o.entity == 'expense' || o.entity == 'attachment') o,
  ];

  // TC-29-01 (W2-Y): a picked photo is an attachment now, saved with the expense in one transaction.
  test(
    'a picked photo becomes an attachment: row, outbox after the expense, thumb then full upload',
    () async {
      final e = await env.open();
      e.edit((d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image)));
      final id = (await e.save())!;

      expect((await expense(id)).receiptPath, isNull);
      final a = (await attachments()).single;
      expect(
        (a.expenseId, a.groupId, a.kind, a.sizeBytes, a.position, a.syncState),
        (id, env.groupId, 'photo', 2, 0, 'pending'),
      );
      expect(a.path, '${env.groupId}/$id/${a.id}.jpg');
      expect(a.thumbPath, '${env.groupId}/$id/${a.id}-thumb.jpg');
      final out = await outbox();
      expect(out.map((o) => (o.entity, o.recordId)), [('expense', id), ('attachment', a.id)]);
      final payload = jsonDecode(out.last.payload) as Map<String, Object?>;
      expect(payload['expense_id'], id);
      expect(payload['path'], a.path);
      expect(payload['thumb_path'], a.thumbPath);
      final up = await pending();
      expect(up.map((u) => (u.bucket, u.remotePath, u.recordId)), [
        ('expense-files', a.thumbPath, a.id),
        ('expense-files', a.path, a.id),
      ]);
      final files = env.container.read(mediaFilesProvider);
      expect(await files.read(up.last.localPath), image.full);
      expect(await files.read(up.first.localPath), image.thumb);
    },
  );

  // TC-29-01
  test('a saved expense reopens with its files; saving again writes nothing new', () async {
    final e = await env.open();
    e.edit(
      (d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image).addAll([pdf])),
    );
    final id = (await e.save())!;
    expect((await attachments()).map((a) => (a.kind, a.position, a.name)), [
      ('photo', 0, null),
      ('pdf', 1, 'Hotel invoice.pdf'),
    ]);

    final r = await env.open(expenseId: id);
    expect(r.draft.receipt.kept, hasLength(2));
    expect(r.draft.receipt.hasPhoto, isTrue);
    expect(r.draft.receipt.changed, isFalse);
    expect(r.draft.receipt.nextPosition, 2);
    final before = (await outbox()).length;
    expect(await r.save(), id);
    final after = await outbox();
    expect(after.length, before + 1, reason: 'only the expense itself');
    expect(after.last.entity, 'expense');
    expect(await pending(), hasLength(3));

    final plain = await env.open();
    expect(plain.draft.receipt.hasPhoto, isFalse);
  });

  // TC-29-01
  test(
    'taking a saved file out is a soft delete; its upload still goes (Undo keeps the file)',
    () async {
      final e = await env.open();
      e.edit((d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image)));
      final id = (await e.save())!;
      final a = (await attachments()).single;

      final r = await env.open(expenseId: id);
      r.edit((d) => d.copyWith(receipt: d.receipt.removeSaved(a.id)));
      expect(await r.save(), id);

      expect((await attachments()).single.deletedAt, isNotNull);
      final last = (await outbox()).last;
      expect((last.entity, last.op, last.recordId), ('attachment', 'delete', a.id));
      expect(jsonDecode(last.payload), {'expense_id': id, 'kind': 'photo'});
      expect(await pending(), hasLength(2));
      expect((await env.open(expenseId: id)).draft.receipt.hasPhoto, isFalse);
    },
  );

  // TC-29-01
  test('new files go after the saved ones', () async {
    final e = await env.open();
    e.edit((d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image)));
    final id = (await e.save())!;
    final r = await env.open(expenseId: id);
    r.edit((d) => d.copyWith(receipt: d.receipt.addAll([pdf])));
    await r.save();
    expect((await attachments()).map((a) => (a.kind, a.position)), [('photo', 0), ('pdf', 1)]);
  });

  // TC-29-01: the one receipt photo of older versions.
  test(
    'removing an old receipt photo that never went up clears receipt_path and drops its upload',
    () async {
      final e = await env.open();
      e.edit(fill('100'));
      final id = (await e.save())!;
      final files = env.container.read(mediaFilesProvider);
      const path = 'g/e/old.jpg';
      final rel = await files.stage(MediaBuckets.receipts, path, image);
      await env.db
          .into(env.db.pendingUploads)
          .insert(
            PendingUploadsCompanion.insert(
              id: 'u1',
              bucket: MediaBuckets.receipts,
              localPath: rel,
              remotePath: path,
              recordId: id,
            ),
          );
      await env.db.customStatement("UPDATE expenses SET receipt_path = '$path' WHERE id = '$id'");

      final r = await env.open(expenseId: id);
      expect(r.draft.receipt.savedPath, path);
      expect(r.draft.receipt.showsLegacy, isTrue);
      r.edit((d) => d.copyWith(receipt: d.receipt.remove()));
      expect(await r.save(), id);

      expect((await expense(id)).receiptPath, isNull);
      expect(await pending(), isEmpty);
      expect(await files.read(rel), isNull);
    },
  );

  // TC-29-01
  test(
    'removing an uploaded old receipt photo clears receipt_path (nothing pending to drop)',
    () async {
      final e = await env.open();
      e.edit(fill('100'));
      final id = (await e.save())!;
      await env.db.customStatement(
        "UPDATE expenses SET receipt_path = 'g/old.jpg' WHERE id = '$id'",
      );
      final r = await env.open(expenseId: id);
      r.edit((d) => d.copyWith(receipt: d.receipt.remove()));
      await r.save();
      expect((await expense(id)).receiptPath, isNull);
      expect(await pending(), isEmpty);
    },
  );

  // TC-29-01
  test('an old receipt photo stays next to new files', () async {
    final e = await env.open();
    e.edit(fill('100'));
    final id = (await e.save())!;
    await env.db.customStatement("UPDATE expenses SET receipt_path = 'g/old.jpg' WHERE id = '$id'");
    final r = await env.open(expenseId: id);
    r.edit((d) => d.copyWith(receipt: d.receipt.pick(image)));
    await r.save();
    expect((await expense(id)).receiptPath, 'g/old.jpg');
    expect(await attachments(), hasLength(1));
    expect((await env.open(expenseId: id)).draft.receipt.count, 2);
  });

  // TC-13-01
  test('lastCategory ignores loans (kind iou)', () async {
    final reads = env.container.read(expensesRepositoryProvider);
    expect(await reads.lastCategory(env.groupId), isNull);

    final e = await env.open();
    e.edit((d) => fill('50')(d).copyWith(category: 'food.snacks'));
    await e.save();
    env.clock.time = DateTime(2026, 11, 21, 11);
    await env.container.read(expensesRepositoryProvider).save(env.groupId, {
      'kind': 'iou',
      'description': 'Loan',
      'category': 'travel.taxi',
      'date': '2026-11-21',
      'currency': 'INR',
      'total': 500,
      'payers': {env.me: 500},
      'shares': {env.ids['Asha']!: 500},
      'split_kind': 'equal',
      'split_values': null,
      'created_at': env.clock.time.toUtc().toIso8601String(),
    });
    expect(await reads.lastCategory(env.groupId), 'food.snacks');
  });

  // TC-29-01 (W2-Y)
  test('ReceiptDraft: none, saved, pick, add, remove and the limits', () {
    const none = ReceiptDraft.none();
    expect((none.hasPhoto, none.changed, none.count, none.room), (false, false, 0, 10));
    expect(none.remove().removed, isFalse);

    const saved = ReceiptDraft.saved('g/e/x.jpg');
    expect((saved.hasPhoto, saved.changed, saved.showsLegacy, saved.count), (true, false, true, 1));

    final picked = saved.pick(image);
    expect((picked.hasPhoto, picked.changed, picked.count), (true, true, 2));
    expect(picked.picked, same(image));
    expect(picked.savedPath, 'g/e/x.jpg');
    expect(picked.removeAdded(picked.added.single.id).added, isEmpty);

    final removed = saved.remove();
    expect((removed.hasPhoto, removed.changed, removed.removed), (false, true, true));
    expect(
      removed.pick(image).removed,
      isTrue,
      reason: 'adding a file keeps the old photo removed',
    );

    final full = none.addAll([for (var i = 0; i < 12; i++) NewAttachment.photo(image)]);
    expect((full.count, full.room), (10, 0), reason: 'never more than 10 files');
    expect(full.totalBytes, 20);
    expect(full.addAll([pdf]).count, 10);
  });
}
