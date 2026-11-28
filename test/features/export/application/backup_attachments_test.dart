// W2-Y (P-7 in the D-034 backup): every attachment is listed in the JSON (removed ones too); the files the phone
// could get go into the .zip under attachments/<expense>/<id>.<ext>, old receipt photos under receipts/.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/export_reads.dart';
import 'package:splitify/features/export/application/backup_export.dart';

import '../../../support/ledger_seed.dart';
import '../zip_reader.dart';

LocalAttachment _att(
  String id, {
  String kind = 'photo',
  String? name,
  String? deletedAt,
  String syncState = 'synced',
}) => LocalAttachment(
  id: id,
  groupId: 'g1',
  expenseId: 'e1',
  kind: kind,
  path: 'g1/e1/$id.${kind == 'pdf' ? 'pdf' : 'jpg'}',
  thumbPath: kind == 'pdf' ? null : 'g1/e1/$id-thumb.jpg',
  name: name,
  sizeBytes: 3,
  width: kind == 'pdf' ? null : 3072,
  height: kind == 'pdf' ? null : 2304,
  position: 0,
  createdAt: '2026-11-27T10:00:00Z',
  createdBy: 'u1',
  deletedAt: deletedAt,
  seq: 4,
  syncState: syncState,
);

void main() {
  final rows = BackupGroupRows(
    group: seedGroup(),
    members: [seedMember('m1', userId: 'u1', name: 'Mohit')],
    expenses: [
      seedExpense(
        'e1',
        total: 100,
        payers: {'m1': 100},
        shares: {'m1': 100},
      ).copyWith(receiptPath: const Value('g1/e1/r.jpg')),
    ],
  );

  BackupFile build(BackupFiles files) => buildBackup(
    groups: [rows],
    now: DateTime(2026, 11, 28, 9),
    categoryLabel: (k) => k,
    userId: 'u1',
    files: files,
  );

  test('attachments are listed with their place in the zip, and the files are inside', () {
    final f = build(
      BackupFiles(
        attachments: [
          _att('a1'),
          _att('p1', kind: 'pdf', name: 'Hotel.pdf'),
          _att('gone', deletedAt: '2026-11-28T08:00:00Z', syncState: 'pending'),
        ],
        attachmentBytes: {
          'a1': Uint8List.fromList([1, 2, 3]),
          'p1': Uint8List.fromList(utf8.encode('%PDF-1')),
        },
        receiptBytes: {
          'e1': Uint8List.fromList([7, 7]),
        },
      ),
    );
    final group = (f.json['groups']! as List).single as Map<String, Object?>;
    final list = [for (final a in group['attachments']! as List) a as Map<String, Object?>];
    expect(list.map((a) => (a['id'], a['kind'], a['file'])), [
      ('a1', 'photo', 'attachments/e1/a1.jpg'),
      ('p1', 'pdf', 'attachments/e1/p1.pdf'),
      ('gone', 'photo', null),
    ]);
    expect(list[1]['name'], 'Hotel.pdf');
    expect((list[2]['deleted_at'], list[2]['pending']), ('2026-11-28T08:00:00Z', true));
    expect((list[0]['width'], list[0]['height'], list[0]['size_bytes']), (3072, 2304, 3));
    final expense = (group['expenses']! as List).single as Map<String, Object?>;
    expect((expense['receipt_path'], expense['receipt_file']), ('g1/e1/r.jpg', 'receipts/e1.jpg'));

    final entries = {for (final e in readZip(f.bytes)) e.name: e.bytes};
    expect(entries['attachments/e1/a1.jpg'], [1, 2, 3]);
    expect(utf8.decode(entries['attachments/e1/p1.pdf']!), '%PDF-1');
    expect(entries['receipts/e1.jpg'], [7, 7]);
    expect(entries.keys.where((k) => k.contains('gone')), isEmpty);
    expect(utf8.decode(entries['README.txt']!), contains('attachments/'));
  });

  test('without files the backup still lists every attachment', () {
    final f = build(BackupFiles(attachments: [_att('a1')]));
    final group = (f.json['groups']! as List).single as Map<String, Object?>;
    expect(((group['attachments']! as List).single as Map)['file'], isNull);
    final expense = (group['expenses']! as List).single as Map<String, Object?>;
    expect(expense['receipt_file'], isNull);
    expect(readZip(f.bytes).map((e) => e.name), isNot(contains(startsWith('attachments/'))));
  });

  test('a group without attachments gets an empty list', () {
    final f = build(const BackupFiles());
    final group = (f.json['groups']! as List).single as Map<String, Object?>;
    expect(group['attachments'], isEmpty);
  });
}
