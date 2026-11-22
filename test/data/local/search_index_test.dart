// TC-34-02 (support): the offline search index `expense_search` follows local writes and pulls.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/search_index_dao.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/data/sync/server_clock.dart';

import '../../support/fakes.dart' show FakeClock, testDb;
import '../sync/sync_fakes.dart' show gid, m1, m2, serverExpense, serverGroup, serverMember;

const _linkedUser = '01900000-0000-7000-8000-0000000000f1';
const _otherGroup = '01900000-0000-7000-8000-000000000002';
const _e1 = '01900000-0000-7000-8000-00000000e001';
const _e2 = '01900000-0000-7000-8000-00000000e002';

void main() {
  late AppDatabase db;
  late LocalWriter writer;
  late ExpensesRepository expenses;
  late MembersRepository members;
  late PullApplier applier;

  setUp(() async {
    db = testDb();
    final clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    writer = LocalWriter(db, clock, ServerClock(clock, SyncDao(db)));
    expenses = ExpensesRepository(db, writer);
    members = MembersRepository(db, writer);
    applier = PullApplier(db);
    await applier.apply(
      _page({
        'groups': [serverGroup()],
        'group_members': _members(),
      }),
    );
  });

  tearDown(() => db.close());

  Map<String, Object?> data(String description, {int total = 120000, String? notes}) => {
    'description': description,
    'notes': notes,
    'date': '2026-11-21',
    'currency': 'INR',
    'total': total,
    'payers': {m1: total},
    'shares': {m1: total - total ~/ 2, m2: total ~/ 2},
  };

  Future<Map<String, Map<String, String>>> index() async {
    final rows = await db
        .customSelect(
          'SELECT expense_id, group_id, description, notes, member_names, amount_text '
          'FROM expense_search',
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('expense_id'): {
          'group': r.read<String>('group_id'),
          'description': r.read<String>('description'),
          'notes': r.read<String>('notes'),
          'names': r.read<String>('member_names'),
          'amount': r.read<String>('amount_text'),
        },
    };
  }

  group('local writes', () {
    // TC-34-02
    test('saving an expense indexes description, notes, names and amount', () async {
      final id = await expenses.save(gid, data('Beach dinner', notes: 'Fish thali'));
      final row = (await index()).entries.single;
      expect(row.key, id);
      expect(row.value, {
        'group': gid,
        'description': 'Beach dinner',
        'notes': 'Fish thali',
        'names': 'M0 M1',
        'amount': '1200 1,200',
      });
    });

    // TC-34-02
    test('a missing note is indexed as empty text', () async {
      await expenses.save(gid, data('Taxi'));
      expect((await index()).values.single['notes'], '');
    });

    // TC-34-02
    test('editing replaces the row instead of adding one', () async {
      final id = await expenses.save(gid, data('Taxi'));
      await expenses.save(gid, data('Cab', total: 120050), id: id);
      final all = await index();
      expect(all.keys, [id]);
      expect(all[id]!['description'], 'Cab');
      expect(all[id]!['amount'], '1200.5 1,200.50');
    });

    // TC-34-02
    test('delete takes the row out, restore brings it back', () async {
      final id = await expenses.save(gid, data('Taxi'));
      await expenses.delete(id, gid);
      expect(await index(), isEmpty);
      await expenses.restore(id, gid);
      expect((await index()).keys, [id]);
    });

    // TC-34-02
    test('only the people in the expense are indexed', () async {
      await expenses.save(gid, {
        ...data('Solo', total: 5000),
        'payers': {m1: 5000},
        'shares': {m1: 5000},
      });
      expect((await index()).values.single['names'], 'M0');
    });

    // TC-34-02
    test('renaming a member re-indexes the expenses of the group', () async {
      final a = await expenses.save(gid, data('Taxi'));
      await members.rename(gid, m2, 'Zed');
      expect((await index())[a]!['names'], 'M0 Zed');
    });

    // TC-34-02
    test('the name of a linked account is searchable too', () async {
      await applier.apply(
        _page({
          'group_members': [_member(m2, 1, user: _linkedUser)],
          'profiles': [_profile(_linkedUser, 'Zorro Rao')],
        }),
      );
      final a = await expenses.save(gid, data('Taxi'));
      expect((await index())[a]!['names'], 'M0 M1 Zorro Rao');
    });
  });

  group('amountText', () {
    // TC-34-02
    test('plain and grouped, no zero fraction', () {
      expect(SearchIndex.amountText(120000, 'INR'), '1200 1,200');
      expect(SearchIndex.amountText(120050, 'INR'), '1200.5 1,200.50');
      expect(SearchIndex.amountText(12345600, 'INR'), '123456 1,23,456');
      expect(SearchIndex.amountText(100, 'INR'), '1');
    });

    // TC-34-02
    test('currencies without decimals keep whole numbers', () {
      expect(SearchIndex.amountText(1200, 'JPY'), '1200 1,200');
      expect(SearchIndex.amountText(100, 'JPY'), '100');
    });
  });

  group('pull', () {
    // TC-34-02
    test('pulled expenses are indexed, a pulled delete removes them', () async {
      await applier.apply(
        _page({
          'expenses': [serverExpense(_e1, description: 'Dinner'), serverExpense(_e2, seq: 4)],
        }),
      );
      final all = await index();
      expect(all.keys.toSet(), {_e1, _e2});
      expect(all[_e1]!['names'], 'M0 M1');
      expect(all[_e1]!['amount'], '100');
      await applier.apply(
        _page({
          'expenses': [serverExpense(_e2, seq: 5, deletedAt: '2026-11-21T09:00:00Z')],
        }),
      );
      expect((await index()).keys, [_e1]);
    });

    // TC-34-02
    test('a pulled profile name becomes searchable for the expenses of its member', () async {
      await applier.apply(
        _page({
          'group_members': [_member(m2, 1, user: _linkedUser)],
          'expenses': [serverExpense(_e1)],
        }),
      );
      expect((await index())[_e1]!['names'], 'M0 M1');
      await applier.apply(
        _page({
          'profiles': [_profile(_linkedUser, 'Zorro Rao')],
        }),
      );
      expect((await index())[_e1]!['names'], 'M0 M1 Zorro Rao');
    });

    // TC-34-02
    test('pulled member names re-index the group', () async {
      await applier.apply(
        _page({
          'expenses': [serverExpense(_e1)],
        }),
      );
      await applier.apply(
        _page({
          'group_members': [_member(m2, 1, name: 'Renamed', seq: 9)],
        }),
      );
      expect((await index())[_e1]!['names'], 'M0 Renamed');
    });

    // TC-34-02
    test('a record with a pending local change is not overwritten', () async {
      final id = await expenses.save(gid, data('Local edit'));
      await applier.apply(
        _page({
          'expenses': [serverExpense(id, description: 'Server text')],
        }),
      );
      expect((await index())[id]!['description'], 'Local edit');
    });

    // TC-34-02
    test('forgetting a group clears its search rows only', () async {
      await applier.apply(
        _page({
          'groups': [_group2()],
          'group_members': [_member('g2-m', 0, group: _otherGroup)],
          'expenses': [serverExpense(_e1)],
        }),
      );
      await expenses.save(_otherGroup, {
        'description': 'Elsewhere',
        'date': '2026-11-21',
        'currency': 'INR',
        'total': 100,
        'payers': {'g2-m': 100},
        'shares': {'g2-m': 100},
      });
      expect(await index(), hasLength(2));
      await applier.forgetGroup(gid);
      final left = await index();
      expect(left.values.single['group'], _otherGroup);
    });
  });

  group('SearchIndex.all', () {
    // TC-34-02
    test('rebuilds every live expense and skips deleted ones', () async {
      final a = await expenses.save(gid, data('Taxi'));
      final b = await expenses.save(gid, data('Lunch'));
      await expenses.delete(b, gid);
      await db.customStatement('DELETE FROM expense_search');
      expect(await index(), isEmpty);
      await SearchIndex.all(db);
      expect((await index()).keys, [a]);
    });

    // TC-34-02
    test('groups() and expenses() with nothing to do leave the index alone', () async {
      final a = await expenses.save(gid, data('Taxi'));
      await SearchIndex.groups(db, const []);
      await SearchIndex.expenses(db, const []);
      await SearchIndex.expenses(db, ['no-such-expense']);
      expect((await index()).keys, [a]);
    });
  });
}

PullPage _page(Map<String, List<Map<String, Object?>>> rows) => PullPage(
  serverTime: DateTime.utc(2026, 11, 21, 10),
  rows: rows,
  nextCursors: const {gid: 9},
  userSeq: 0,
);

List<Map<String, Object?>> _members() => [serverMember(m1, 0), serverMember(m2, 1)];

Map<String, Object?> _member(
  String id,
  int position, {
  String? user,
  String? name,
  String group = gid,
  int seq = 7,
}) => {
  ...serverMember(id, position, seq: seq),
  'group_id': group,
  'user_id': user,
  'display_name': ?name,
};

Map<String, Object?> _group2() => {...serverGroup(), 'id': _otherGroup, 'name': 'Pune'};

Map<String, Object?> _profile(String id, String name) => {
  'id': id,
  'display_name': name,
  'avatar_path': null,
  'upi_id': null,
  'default_currency': 'INR',
  'updated_at': '2026-11-21T09:00:00Z',
  'deleted_at': null,
  'seq': 1,
};
