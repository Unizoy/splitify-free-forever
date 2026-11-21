// TC-29-01 (receipt on the expense editor: pick, remove, replace, reopen) + lastCategory ignoring loans.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/media_files.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';

import 'expense_test_env.dart';

void main() {
  late ExpenseEnv env;
  late Directory docs;
  late Directory cache;

  final image = PreparedImage(full: Uint8List.fromList([1, 2]), thumb: Uint8List.fromList([3]));

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

  // TC-29-01
  test('a picked photo sets receipt_path and queues one receipts upload', () async {
    final e = await env.open();
    e.edit((d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image)));
    final id = (await e.save())!;

    final row = await expense(id);
    expect(row.receiptPath, matches(RegExp('^${env.groupId}/$id/[0-9a-f-]{36}\\.jpg\$')));
    final up = (await pending()).single;
    expect(up.bucket, 'receipts');
    expect(up.remotePath, row.receiptPath);
    expect(up.recordId, id);
    final out = await env.db.select(env.db.outbox).get();
    expect((jsonDecode(out.last.payload) as Map<String, Object?>)['receipt_path'], row.receiptPath);
  });

  // TC-29-01
  test('a saved expense with receipt_path reopens with ReceiptDraft.saved', () async {
    final e = await env.open();
    e.edit((d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image)));
    final id = (await e.save())!;
    final path = (await expense(id)).receiptPath!;

    final r = await env.open(expenseId: id);
    expect(r.draft.receipt.savedPath, path);
    expect(r.draft.receipt.hasPhoto, isTrue);
    expect(r.draft.receipt.changed, isFalse);

    // Saving again without touching the receipt keeps the path and queues nothing new.
    expect(await r.save(), id);
    expect((await expense(id)).receiptPath, path);
    expect(await pending(), hasLength(1));

    final plain = await env.open();
    expect(plain.draft.receipt.hasPhoto, isFalse);
  });

  // TC-29-01
  test('removing a photo that never went up clears receipt_path and drops the upload', () async {
    final e = await env.open();
    e.edit((d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image)));
    final id = (await e.save())!;
    final rel = (await pending()).single.localPath;

    final r = await env.open(expenseId: id);
    r.edit((d) => d.copyWith(receipt: d.receipt.remove()));
    expect(await r.save(), id);

    expect((await expense(id)).receiptPath, isNull);
    expect(await pending(), isEmpty);
    expect(await env.container.read(mediaFilesProvider).read(rel), isNull);
  });

  // TC-29-01
  test('removing an uploaded photo clears receipt_path (nothing pending to drop)', () async {
    final e = await env.open();
    e.edit(fill('100'));
    final id = (await e.save())!;
    await env.db.customStatement("UPDATE expenses SET receipt_path = 'g/old.jpg' WHERE id = '$id'");
    final r = await env.open(expenseId: id);
    r.edit((d) => d.copyWith(receipt: d.receipt.remove()));
    await r.save();
    expect((await expense(id)).receiptPath, isNull);
    expect(await pending(), isEmpty);
  });

  // TC-29-01
  test('replacing a pending photo discards the old upload and queues the new one', () async {
    final e = await env.open();
    e.edit((d) => fill('100')(d).copyWith(receipt: const ReceiptDraft.none().pick(image)));
    final id = (await e.save())!;
    final oldPath = (await expense(id)).receiptPath!;

    final r = await env.open(expenseId: id);
    r.edit((d) => d.copyWith(receipt: d.receipt.pick(image)));
    await r.save();

    final newPath = (await expense(id)).receiptPath!;
    expect(newPath, isNot(oldPath));
    final up = await pending();
    expect(up.map((u) => u.remotePath), [newPath]);
  });

  // TC-29-01
  test('replacing an uploaded photo keeps the old one on the server and queues the new', () async {
    final e = await env.open();
    e.edit(fill('100'));
    final id = (await e.save())!;
    await env.db.customStatement("UPDATE expenses SET receipt_path = 'g/old.jpg' WHERE id = '$id'");
    final r = await env.open(expenseId: id);
    r.edit((d) => d.copyWith(receipt: d.receipt.pick(image)));
    await r.save();
    final up = await pending();
    expect(up, hasLength(1));
    expect(up.single.remotePath, isNot('g/old.jpg'));
    expect((await expense(id)).receiptPath, up.single.remotePath);
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

  // TC-29-01
  test('ReceiptDraft none, saved, pick and remove', () {
    const none = ReceiptDraft.none();
    expect(none.hasPhoto, isFalse);
    expect(none.changed, isFalse);
    expect(none.remove().removed, isFalse);

    const saved = ReceiptDraft.saved('g/e/x.jpg');
    expect(saved.hasPhoto, isTrue);
    expect(saved.changed, isFalse);

    final picked = saved.pick(image);
    expect(picked.hasPhoto, isTrue);
    expect(picked.changed, isTrue);
    expect(picked.savedPath, 'g/e/x.jpg');

    final removed = saved.remove();
    expect(removed.hasPhoto, isFalse);
    expect(removed.changed, isTrue);
    expect(removed.removed, isTrue);
    expect(removed.pick(image).removed, isFalse);
    expect(picked.remove().picked, isNull);
  });
}
