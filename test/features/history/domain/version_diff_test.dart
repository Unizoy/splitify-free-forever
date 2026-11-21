import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/money.dart';
import 'package:splitify/features/history/domain/version_diff.dart';

// TC-20-02 [unit] diff builder.

const _a = 'aaaaaaaa-0000-0000-0000-000000000001';
const _b = 'bbbbbbbb-0000-0000-0000-000000000002';
const _c = 'cccccccc-0000-0000-0000-000000000003';

Map<String, Object?> _expense([Map<String, Object?> patch = const {}]) => {
  'id': 'e1',
  'kind': 'expense',
  'description': 'Dinner',
  'notes': null,
  'category': 'food.dining',
  'date': '2026-11-20',
  'currency': 'INR',
  'total': 10000,
  'payers': {_a: 10000},
  'shares': {_a: 3334, _b: 3333, _c: 3333},
  'split_kind': 'equal',
  'split_values': null,
  'receipt_path': null,
  'deleted_at': null,
  ...patch,
};

VersionRecord _v(int seq, String op, Map<String, Object?> snap, {String? by = 'u1'}) =>
    VersionRecord(
      seq: seq,
      op: op,
      snapshot: snap,
      changedAt: DateTime.utc(2026, 11, 21, 10, seq),
      changedBy: by,
    );

FieldChange _field(HistoryEntry e, HistoryField f) => e.changes.singleWhere((c) => c.field == f);

void main() {
  group('buildHistory expense', () {
    test('create lists every present field with no old value', () {
      final [e] = buildHistory(HistoryRecordKind.expense, [_v(1, 'insert', _expense())]);
      expect(e.op, HistoryOp.create);
      expect(e.seq, 1);
      expect(e.changedBy, 'u1');
      expect(e.changedAt, DateTime.utc(2026, 11, 21, 10, 1));
      expect(e.muted, isFalse);
      expect(e.deleted, isFalse);
      expect(e.changes.map((c) => c.field), [
        HistoryField.description,
        HistoryField.amount,
        HistoryField.date,
        HistoryField.category,
        HistoryField.payers,
        HistoryField.shares,
        HistoryField.splitKind,
        HistoryField.kind,
      ]);
      expect(e.changes.every((c) => c.oldValue == null), isTrue);
      expect(_field(e, HistoryField.amount).newValue, const Money(10000, 'INR'));
      expect(_field(e, HistoryField.date).newValue, DateTime.utc(2026, 11, 20));
      expect(_field(e, HistoryField.payers).members, [
        const MemberValueChange(_a, null, Money(10000, 'INR')),
      ]);
    });

    test('update shows only changed fields with old and new values', () {
      final entries = buildHistory(HistoryRecordKind.expense, [
        _v(1, 'insert', _expense()),
        _v(
          2,
          'update',
          _expense({
            'description': 'Team dinner',
            'notes': 'Paid by card',
            'date': '2026-11-21',
            'total': '12000',
            'payers': {_a: 6000, _b: 6000},
            'shares': {_a: 4000, _b: 8000},
            'split_kind': 'shares',
            'split_values': {_a: 1, _b: 2},
            'receipt_path': 'g/e1.jpg',
          }),
        ),
      ]);
      final e = entries[1];
      expect(e.op, HistoryOp.update);
      expect(_field(e, HistoryField.description).oldValue, 'Dinner');
      expect(_field(e, HistoryField.description).newValue, 'Team dinner');
      expect(_field(e, HistoryField.notes).oldValue, isNull);
      expect(_field(e, HistoryField.amount).oldValue, const Money(10000, 'INR'));
      expect(_field(e, HistoryField.amount).newValue, const Money(12000, 'INR'));
      expect(_field(e, HistoryField.date).newValue, DateTime.utc(2026, 11, 21));
      expect(_field(e, HistoryField.receipt).newValue, 'g/e1.jpg');
      expect(_field(e, HistoryField.splitKind).newValue, 'shares');
      expect(_field(e, HistoryField.payers).members, [
        const MemberValueChange(_a, Money(10000, 'INR'), Money(6000, 'INR')),
        const MemberValueChange(_b, null, Money(6000, 'INR')),
      ]);
      expect(_field(e, HistoryField.shares).members, [
        const MemberValueChange(_a, Money(3334, 'INR'), Money(4000, 'INR')),
        const MemberValueChange(_b, Money(3333, 'INR'), Money(8000, 'INR')),
        const MemberValueChange(_c, Money(3333, 'INR'), null),
      ]);
      final split = _field(e, HistoryField.splitValues);
      expect(split.oldValue, isNull);
      expect(split.newValue, {_a: '1', _b: '2'});
      expect(split.members.map((m) => m.memberId), [_a, _b]);
      expect(e.changes.any((c) => c.field == HistoryField.category), isFalse);
    });

    test('currency change shows in amount and in every member amount', () {
      final [_, e] = buildHistory(HistoryRecordKind.expense, [
        _v(1, 'insert', _expense()),
        _v(2, 'update', _expense({'currency': 'USD'})),
      ]);
      expect(_field(e, HistoryField.amount).newValue, const Money(10000, 'USD'));
      expect(_field(e, HistoryField.payers).members.single.newValue, const Money(10000, 'USD'));
      expect(_field(e, HistoryField.shares).members, hasLength(3));
    });

    test('no-op update has no changes; delete and restore flip deleted', () {
      final entries = buildHistory(HistoryRecordKind.expense, [
        _v(1, 'insert', _expense()),
        _v(2, 'update', _expense()),
        _v(3, 'delete', _expense({'deleted_at': '2026-11-21T10:03:00Z'})),
        _v(4, 'restore', _expense(), by: null),
      ]);
      expect(entries.map((e) => e.op), [
        HistoryOp.create,
        HistoryOp.update,
        HistoryOp.delete,
        HistoryOp.restore,
      ]);
      expect(entries[1].changes, isEmpty);
      expect(entries[2].deleted, isTrue);
      expect(entries[2].changes, isEmpty);
      expect(entries[3].deleted, isFalse);
      expect(entries[3].changedBy, isNull);
    });

    test('deleted flag key is honoured', () {
      final [e] = buildHistory(HistoryRecordKind.expense, [
        _v(1, 'delete', _expense({'deleted': true})),
      ]);
      expect(e.deleted, isTrue);
    });

    test('conflict_lost is muted, diffed against applied, never the baseline', () {
      final entries = buildHistory(HistoryRecordKind.expense, [
        _v(1, 'insert', _expense()),
        _v(2, 'update', _expense({'description': 'Lunch'})),
        _v(3, 'conflict_lost', _expense({'description': 'Brunch', 'lost_op': 'upsert'})),
        _v(4, 'update', _expense({'description': 'Supper'})),
      ]);
      final lost = entries[2];
      expect(lost.op, HistoryOp.conflictLost);
      expect(lost.muted, isTrue);
      expect(_field(lost, HistoryField.description).oldValue, 'Lunch');
      expect(_field(lost, HistoryField.description).newValue, 'Brunch');
      expect(_field(entries[3], HistoryField.description).oldValue, 'Lunch');
      expect(entries[3].muted, isFalse);
    });

    test('missing currency, total or maps give null values', () {
      final [e] = buildHistory(HistoryRecordKind.expense, [
        _v(1, 'insert', {
          'description': 'x',
          'total': 5,
          'payers': {_a: 5},
        }),
      ]);
      expect(e.changes.map((c) => c.field), [HistoryField.description]);
    });

    test('empty list gives empty timeline', () {
      expect(buildHistory(HistoryRecordKind.expense, const []), isEmpty);
    });
  });

  group('buildHistory payment', () {
    Map<String, Object?> pay([Map<String, Object?> patch = const {}]) => {
      'from_member': _a,
      'to_member': _b,
      'amount': 50000,
      'currency': 'INR',
      'date': '2026-11-21',
      'method': 'cash',
      'note': null,
      'deleted_at': null,
      ...patch,
    };

    test('payment fields diff', () {
      final [c, u] = buildHistory(HistoryRecordKind.payment, [
        _v(1, 'insert', pay()),
        _v(2, 'update', pay({'amount': 45000, 'method': 'upi', 'note': 'UPI', 'to_member': _c})),
      ]);
      expect(c.changes.map((f) => f.field), [
        HistoryField.amount,
        HistoryField.date,
        HistoryField.fromMember,
        HistoryField.toMember,
        HistoryField.method,
      ]);
      expect(u.changes.map((f) => f.field), [
        HistoryField.amount,
        HistoryField.toMember,
        HistoryField.method,
        HistoryField.notes,
      ]);
      expect(_field(u, HistoryField.amount).oldValue, const Money(50000, 'INR'));
      expect(_field(u, HistoryField.amount).newValue, const Money(45000, 'INR'));
      expect(_field(u, HistoryField.toMember).oldValue, _b);
      expect(_field(u, HistoryField.toMember).newValue, _c);
      expect(_field(u, HistoryField.notes).members, isEmpty);
    });
  });

  group('errors', () {
    test('unknown op throws', () {
      expect(
        () => buildHistory(HistoryRecordKind.expense, [_v(1, 'merge', _expense())]),
        throwsFormatException,
      );
    });

    test('fractional amount throws', () {
      expect(
        () => buildHistory(HistoryRecordKind.expense, [
          _v(1, 'insert', _expense({'total': 100.5})),
        ]),
        throwsFormatException,
      );
    });
  });

  group('VersionRecord.fromJson', () {
    test('parses a pulled row', () {
      final r = VersionRecord.fromJson(const {
        'seq': '42',
        'op': 'update',
        'snapshot': <String, Object?>{'description': 'x'},
        'changed_at': '2026-11-21T15:30:00+05:30',
        'changed_by': 'u9',
      });
      expect(r.seq, 42);
      expect(r.op, 'update');
      expect(r.snapshot, {'description': 'x'});
      expect(r.changedAt, DateTime.utc(2026, 11, 21, 10));
      expect(r.changedBy, 'u9');
    });
  });

  group('value objects', () {
    test('MemberValueChange equality and toString', () {
      const a = MemberValueChange(_a, null, Money(1, 'INR'));
      expect(a, const MemberValueChange(_a, null, Money(1, 'INR')));
      expect(a.hashCode, const MemberValueChange(_a, null, Money(1, 'INR')).hashCode);
      expect(a == const MemberValueChange(_b, null, Money(1, 'INR')), isFalse);
      expect(a.toString(), contains(_a));
    });

    test('FieldChange toString', () {
      expect(
        const FieldChange(HistoryField.notes, 'a', 'b').toString(),
        'FieldChange(notes: a → b)',
      );
    });
  });
}
