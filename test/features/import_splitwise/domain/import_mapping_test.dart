import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart';

MappingMember _m(String id, String name) => (id: id, name: name, isMe: false);

SplitwiseRow _row(int n, Map<String, int> nets, {String currency = 'INR'}) => SplitwiseRow(
  row: n,
  date: DateTime.utc(2026, 1, n),
  description: 'Row $n',
  category: 'General',
  isPayment: false,
  currency: currency,
  cost: 1000,
  nets: nets,
);

void main() {
  group('suggestMapping', () {
    test('same name ignoring case and spaces', () {
      final s = suggestMapping(['  asha   rao ', 'RAVI'], [_m('m1', 'Asha Rao'), _m('m2', 'Ravi')]);
      expect(s['  asha   rao '], const UseMember('m1'));
      expect(s['RAVI'], const UseMember('m2'));
    });

    test('a unique first-name match is used', () {
      final s = suggestMapping(['Asha Rao'], [_m('m1', 'Asha'), _m('m2', 'Ravi')]);
      expect(s['Asha Rao'], const UseMember('m1'));
    });

    test('an ambiguous first name becomes a new member', () {
      final s = suggestMapping(['Asha Rao'], [_m('m1', 'Asha K'), _m('m2', 'Asha M')]);
      expect(s['Asha Rao'], const NewMember('Asha Rao'));
    });

    test('a member is suggested once', () {
      final s = suggestMapping(['Asha', 'Asha'], [_m('m1', 'Asha')]);
      expect(s.length, 1);
      final two = suggestMapping(['Asha Rao', 'Asha Kumar'], [_m('m1', 'Asha')]);
      expect(two['Asha Rao'], const UseMember('m1'));
      expect(two['Asha Kumar'], const NewMember('Asha Kumar'));
    });

    test('unknown names become new members, long names are clipped to 50', () {
      final long = 'N' * 60;
      final s = suggestMapping([long, 'Zed'], [_m('m1', 'Asha')]);
      expect((s[long]! as NewMember).name, 'N' * 50);
      expect(s['Zed'], const NewMember('Zed'));
      expect(clipName('  Zed  '), 'Zed');
      expect(clipName('${'a' * 49} bcd'), 'a' * 49);
    });
  });

  group('checkMapping', () {
    MappingProblem? check(Map<String, MemberChoice> m, {int current = 2, int max = 5}) =>
        checkMapping(m, currentMembers: current, maxMembers: max);

    test('fine mappings give null', () {
      expect(check({'A': const UseMember('m1'), 'B': const NewMember('B')}), isNull);
    });

    test('two people on the same member', () {
      expect(
        check({'A': const UseMember('m1'), 'B': const UseMember('m1')}),
        MappingProblem.sameMemberTwice,
      );
    });

    test('empty new name', () {
      expect(check({'A': const NewMember('  ')}), MappingProblem.emptyName);
    });

    test('everyone skipped', () {
      expect(check({'A': const SkipPerson(), 'B': const SkipPerson()}), MappingProblem.nobodyLeft);
    });

    test('too many members', () {
      final m = {
        'A': const NewMember('A'),
        'B': const NewMember('B'),
        'C': const NewMember('C'),
        'D': const NewMember('D'),
      };
      expect(check(m), MappingProblem.tooManyMembers);
      expect(check(m, current: 1), isNull);
    });
  });

  group('withoutSkipped', () {
    final file = SplitwiseCsv(
      members: const ['A', 'B', 'C'],
      rows: [
        _row(2, {'A': 500, 'B': -500, 'C': 0}),
        _row(3, {'A': 300, 'B': -150, 'C': -150}),
        _row(4, {'A': 0, 'B': 200, 'C': -200}, currency: 'USD'),
      ],
      columnSums: const {
        'INR': {'A': 800, 'B': -650, 'C': -150},
        'USD': {'A': 0, 'B': 200, 'C': -200},
      },
      totals: const {
        'INR': {'A': 800, 'B': -650, 'C': -150},
        'USD': {'A': 0, 'B': 200, 'C': -200},
      },
    );

    test('nobody skipped returns the file untouched', () {
      final r = withoutSkipped(file, {});
      expect(identical(r.file, file), isTrue);
      expect(r.dropped, 0);
    });

    test(
      'skipping drops every row of the skipped person even when other rows have a zero cell',
      () {
        final r = withoutSkipped(
          SplitwiseCsv(
            members: file.members,
            rows: [file.rows.first, file.rows[2]],
            columnSums: const {
              'INR': {'A': 500, 'B': -500, 'C': 0},
              'USD': {'A': 0, 'B': 200, 'C': -200},
            },
            totals: const {
              'INR': {'A': 500, 'B': -500, 'C': 0},
            },
          ),
          {'A'},
        );
        // Row 2 has A = 500 so it goes; row 4 has A = 0 so it stays.
        expect(r.dropped, 1);
        expect(r.file.members, ['B', 'C']);
        expect(r.file.rows.map((x) => x.row), [4]);
        expect(r.file.totals, isEmpty);
      },
    );

    test('rows with a non-zero cell of a skipped person are dropped and counted', () {
      final r = withoutSkipped(file, {'C'});
      expect(r.file.members, ['A', 'B']);
      expect(r.dropped, 2);
      expect(r.file.rows.map((x) => x.row), [2]);
      expect(r.file.rows.single.nets, {'A': 500, 'B': -500});
    });

    test('column sums are recomputed and totals dropped when something was dropped', () {
      final r = withoutSkipped(file, {'C'});
      expect(r.file.columnSums, {
        'INR': {'A': 500, 'B': -500},
      });
      expect(r.file.totals, isEmpty);
    });

    test('totals are kept (without the skipped column) when no row is dropped', () {
      final clean = SplitwiseCsv(
        members: const ['A', 'B', 'C'],
        rows: [
          _row(2, {'A': 500, 'B': -500, 'C': 0}),
          _row(3, {'A': 100, 'B': -100, 'C': 0}),
        ],
        columnSums: const {
          'INR': {'A': 600, 'B': -600, 'C': 0},
        },
        totals: const {
          'INR': {'A': 600, 'B': -600, 'C': 0},
        },
      );
      final r = withoutSkipped(clean, {'C'});
      expect(r.dropped, 0);
      expect(r.file.rows, hasLength(2));
      expect(r.file.columnSums, {
        'INR': {'A': 600, 'B': -600},
      });
      expect(r.file.totals, {
        'INR': {'A': 600, 'B': -600},
      });
      expect(r.file.totalsMismatches, isEmpty);
    });
  });
}
