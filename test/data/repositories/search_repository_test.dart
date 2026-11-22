// TC-34-02 (support): the offline search over the local copy (words, amounts, filters).
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/repositories/search_repository.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/data/sync/server_clock.dart';
import 'package:splitify/domain/rules/search_query.dart';

import '../../support/fakes.dart' show FakeClock, testDb;
import '../sync/sync_fakes.dart' show gid, m1, m2, serverGroup, serverMember;

const _pune = '01900000-0000-7000-8000-000000000002';
const _puneMember = '01900000-0000-7000-8000-0000000000c1';
const _ravi = '01900000-0000-7000-8000-0000000000f1';

void main() {
  late AppDatabase db;
  late LocalWriter writer;
  late ExpensesRepository expenses;
  late SearchRepository search;
  var added = 0;

  setUp(() async {
    db = testDb();
    final clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    writer = LocalWriter(db, clock, ServerClock(clock, SyncDao(db)));
    expenses = ExpensesRepository(db, writer);
    added = 0;
    search = SearchRepository(db);
    await PullApplier(db).apply(
      PullPage(
        serverTime: clock.now(),
        rows: {
          'groups': [
            serverGroup(name: 'Goa'),
            {...serverGroup(seq: 2), 'id': _pune, 'name': 'Pune'},
          ],
          'group_members': [
            {...serverMember(m1, 0), 'display_name': 'Asha'},
            {...serverMember(m2, 1), 'display_name': 'Ravi', 'user_id': _ravi},
            {...serverMember(_puneMember, 0), 'group_id': _pune, 'display_name': 'Kabir'},
          ],
          'profiles': [
            {
              'id': _ravi,
              'display_name': 'Ravindra Kumar',
              'avatar_path': null,
              'upi_id': null,
              'default_currency': 'INR',
              'updated_at': null,
              'deleted_at': null,
              'seq': 1,
            },
          ],
        },
        nextCursors: const {gid: 3},
        userSeq: 0,
      ),
    );
  });

  tearDown(() => db.close());

  Future<String> add(
    String description, {
    int total = 10000,
    String currency = 'INR',
    String date = '2026-11-20',
    String? notes,
    String category = 'other.general',
    String kind = 'expense',
    String group = gid,
    String payer = m1,
    List<String> sharers = const [m1, m2],
  }) => expenses.save(group, {
    'description': description,
    'notes': notes,
    'kind': kind,
    'category': category,
    'date': date,
    // Later saves are newer, so the order of equal days is known.
    'created_at': '2026-11-20T10:00:${(added++).toString().padLeft(2, '0')}Z',
    'currency': currency,
    'total': total,
    'payers': {payer: total},
    'shares': {for (final m in sharers) m: total ~/ sharers.length},
  });

  Future<List<String>> find(String text, [SearchFilters filters = const SearchFilters()]) async {
    final rows = await search.watch(SearchQuery.parse(text), filters).first;
    return [for (final e in rows) e.description];
  }

  group('words', () {
    // TC-34-02
    test('a description prefix finds it, case-insensitively', () async {
      await add('Dinner at the beach');
      await add('Taxi');
      expect(await find('din'), ['Dinner at the beach']);
      expect(await find('DINNER bea'), ['Dinner at the beach']);
      expect(await find('inner'), isEmpty);
    });

    // TC-34-02
    test('notes are searched', () async {
      await add('Taxi', notes: 'Airport pickup');
      await add('Lunch');
      expect(await find('airport'), ['Taxi']);
    });

    // TC-34-02
    test('a member name finds the expenses that member is in', () async {
      await add('With both');
      await add('Asha alone', sharers: [m1]);
      expect(await find('ravi'), ['With both']);
      expect(await find('asha'), ['Asha alone', 'With both']);
    });

    // TC-34-02
    test('the linked account name is searched too', () async {
      await add('With both');
      await add('Asha alone', sharers: [m1]);
      expect(await find('ravind'), ['With both']);
      expect(await find('kumar'), ['With both']);
    });

    // TC-34-02
    test('every term has to match', () async {
      await add('Dinner');
      await add('Dinner party', sharers: [m1]);
      expect(await find('dinner ravi'), ['Dinner']);
      expect(await find('dinner party ravi'), isEmpty);
    });

    // TC-34-02
    test('punctuation in the text is never search syntax', () async {
      await add('Dinner');
      expect(await find('din" *'), ['Dinner']);
      expect(await find('(NEAR) "'), isEmpty);
    });
  });

  group('amounts', () {
    // TC-34-02
    test('an amount finds the expense of that total', () async {
      await add('Rent', total: 120000);
      await add('Rent half', total: 60000);
      await add('Rent with paise', total: 120050);
      // The number is also looked up as text, so 1200.50 shows up for 1200 as well.
      expect(await find('1200'), ['Rent with paise', 'Rent']);
      expect(await find('1,200'), ['Rent with paise', 'Rent']);
      expect(await find('1200.50'), ['Rent with paise']);
      expect(await find('Rs 1200.5'), ['Rent with paise']);
      expect(await find('₹600'), ['Rent half']);
    });

    // TC-34-02
    test('rupee amounts are not matched against paise', () async {
      await add('Chai', total: 1200);
      expect(await find('1200'), isEmpty);
      expect(await find('12'), ['Chai']);
    });

    // TC-34-02
    test('a currency without decimals matches the number as it is', () async {
      await add('Tokyo hotel', total: 1200, currency: 'JPY');
      await add('Pune hotel', total: 120000);
      expect(await find('1200'), ['Pune hotel', 'Tokyo hotel']);
      expect(await find('1,200 hotel'), ['Pune hotel', 'Tokyo hotel']);
      expect(await find('1200.5'), isEmpty);
    });

    // TC-34-02
    test('a number inside the description is found', () async {
      await add('Flat 302 rent');
      await add('Flat 400 rent');
      expect(await find('flat 302'), ['Flat 302 rent']);
      expect(await find('302'), ['Flat 302 rent']);
    });

    // TC-34-02
    test('an amount and words must both match', () async {
      await add('Rent', total: 120000);
      await add('Cab', total: 120000);
      expect(await find('rent 1200'), ['Rent']);
      expect(await find('rent 1300'), isEmpty);
    });
  });

  group('filters', () {
    // TC-34-02
    test('a group filter alone lists that group, newest first', () async {
      await add('Old', date: '2026-11-01');
      await add('New', date: '2026-11-18');
      await add('Pune lunch', group: _pune, payer: _puneMember, sharers: [_puneMember]);
      expect(await find('', const SearchFilters(groupId: gid)), ['New', 'Old']);
      expect(await find('lunch', const SearchFilters(groupId: gid)), isEmpty);
      expect(await find('lunch'), ['Pune lunch']);
    });

    // TC-34-02
    test('a person filter matches the expenses that member is part of', () async {
      await add('With both');
      await add('Asha alone', sharers: [m1]);
      expect(await find('', SearchFilters(memberIds: {m2})), ['With both']);
      expect(await find('', SearchFilters(memberIds: {m1, m2})), ['Asha alone', 'With both']);
      expect(await find('alone', SearchFilters(memberIds: {m2})), isEmpty);
      expect(await find('', const SearchFilters(memberIds: {})), isEmpty);
    });

    // TC-34-02
    test('the date range includes both end days', () async {
      await add('A', date: '2026-11-09');
      await add('B', date: '2026-11-10');
      await add('C', date: '2026-11-15');
      await add('D', date: '2026-11-16');
      expect(await find('', const SearchFilters(from: '2026-11-10', to: '2026-11-15')), ['C', 'B']);
      expect(await find('', const SearchFilters(from: '2026-11-15')), ['D', 'C']);
      expect(await find('', const SearchFilters(to: '2026-11-09')), ['A']);
    });

    // TC-34-02
    test('a parent category covers its subcategories', () async {
      await add('Thali', category: 'food.dining');
      await add('Plain food', category: 'food');
      await add('Cab', category: 'transport.taxi');
      await add('Look-alike', category: 'foodie.x');
      expect(await find('', const SearchFilters(category: 'food')), ['Plain food', 'Thali']);
      expect(await find('cab', const SearchFilters(category: 'food')), isEmpty);
    });

    // TC-34-02
    test('words and filters combine', () async {
      await add('Dinner', date: '2026-11-02');
      await add('Dinner out', date: '2026-11-12');
      expect(await find('dinner', const SearchFilters(from: '2026-11-10')), ['Dinner out']);
    });
  });

  group('results', () {
    // TC-34-02
    test('deleted expenses are left out, restored ones come back', () async {
      final id = await add('Taxi');
      await expenses.delete(id, gid);
      expect(await find('taxi'), isEmpty);
      expect(await find('', const SearchFilters(groupId: gid)), isEmpty);
      await expenses.restore(id, gid);
      expect(await find('taxi'), ['Taxi']);
    });

    // TC-34-02
    test('loans are found too', () async {
      await add('Loan to Ravi', kind: 'iou', sharers: [m2]);
      expect(await find('loan'), ['Loan to Ravi']);
    });

    // TC-34-02
    test('newest day first, then newest created', () async {
      await add('Earlier', date: '2026-11-01');
      await add('Later', date: '2026-11-19');
      expect(await find('', const SearchFilters(groupId: gid)), ['Later', 'Earlier']);
    });

    // TC-34-02
    test('an empty query with no filters gives nothing', () async {
      await add('Taxi');
      expect(await find(''), isEmpty);
      expect(await find('   !! '), isEmpty);
    });

    // TC-34-02
    test('the list updates after a new write', () async {
      final seen = <List<String>>[];
      final sub = search
          .watch(SearchQuery.parse('taxi'), const SearchFilters())
          .listen((rows) => seen.add([for (final e in rows) e.description]));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      final id = await add('Taxi to airport');
      await pumpEventQueue();
      expect(seen.last, ['Taxi to airport']);
      await expenses.delete(id, gid);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
    });

    // TC-34-02
    test('the list updates when a member is renamed', () async {
      await add('Dinner');
      final seen = <List<String>>[];
      final sub = search
          .watch(SearchQuery.parse('zed'), const SearchFilters())
          .listen((rows) => seen.add([for (final e in rows) e.description]));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(seen.last, isEmpty);
      await MembersRepository(db, writer).rename(gid, m2, 'Zed');
      await pumpEventQueue();
      expect(seen.last, ['Dinner']);
    });
  });

  group('lookups', () {
    // TC-34-02
    test('watchMembers lists every member, watchGroups the live groups by name', () async {
      final names = [for (final m in await search.watchMembers().first) m.displayName];
      expect(names..sort(), ['Asha', 'Kabir', 'Ravi']);
      expect([for (final g in await search.watchGroups().first) g.name], ['Goa', 'Pune']);
      await (db.update(db.groups)..where((g) => g.id.equals(_pune))).write(
        const GroupsCompanion(deletedAt: Value('2026-11-21T00:00:00Z')),
      );
      expect([for (final g in await search.watchGroups().first) g.name], ['Goa']);
    });
  });
}
