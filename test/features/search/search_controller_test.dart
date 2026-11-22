// TC-34-02 (support): the search screen's state, date presets, people list and results.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart' as editor;
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;
import 'package:splitify/features/search/application/search_controller.dart';

import '../../data/sync/sync_fakes.dart' show gid, m1, m2, serverExpense, serverGroup, serverMember;
import '../../support/fakes.dart' show testDb;

const _pune = '01900000-0000-7000-8000-000000000002';
const _puneMe = '01900000-0000-7000-8000-0000000000c1';
const _puneAsha = '01900000-0000-7000-8000-0000000000c2';
const _puneBen = '01900000-0000-7000-8000-0000000000c3';
const _e1 = '01900000-0000-7000-8000-00000000e001';
const _e2 = '01900000-0000-7000-8000-00000000e002';

void main() {
  group('presetRange', () {
    final today = DateTime(2026, 11, 21, 15, 30);

    // TC-34-02
    test('this month runs from the 1st to today', () {
      final r = presetRange(DatePreset.thisMonth, today);
      expect(r.from, DateTime(2026, 11));
      expect(r.to, DateTime(2026, 11, 21));
    });

    // TC-34-02
    test('last month is the whole previous month', () {
      final r = presetRange(DatePreset.lastMonth, today);
      expect(r.from, DateTime(2026, 10));
      expect(r.to, DateTime(2026, 10, 31));
    });

    // TC-34-02
    test('last month across New Year, and in a leap February', () {
      final jan = presetRange(DatePreset.lastMonth, DateTime(2026, 1, 15));
      expect(jan.from, DateTime(2025, 12));
      expect(jan.to, DateTime(2025, 12, 31));
      final mar = presetRange(DatePreset.lastMonth, DateTime(2028, 3, 5));
      expect(mar.to, DateTime(2028, 2, 29));
    });

    // TC-34-02
    test('last 3 months starts two months back', () {
      final r = presetRange(DatePreset.last3Months, today);
      expect(r.from, DateTime(2026, 9));
      expect(r.to, DateTime(2026, 11, 21));
      final early = presetRange(DatePreset.last3Months, DateTime(2026, 1, 10));
      expect(early.from, DateTime(2025, 11));
    });

    // TC-34-02
    test('this year starts on 1 January', () {
      final r = presetRange(DatePreset.thisYear, today);
      expect(r.from, DateTime(2026));
      expect(r.to, DateTime(2026, 11, 21));
    });

    // TC-34-02
    test('a custom range is swapped when picked backwards, and defaults to today', () {
      final a = DateTime(2026, 11, 3);
      final b = DateTime(2026, 11, 9);
      expect(presetRange(DatePreset.custom, today, from: a, to: b), (from: a, to: b));
      expect(presetRange(DatePreset.custom, today, from: b, to: a), (from: a, to: b));
      expect(presetRange(DatePreset.custom, today), (
        from: DateTime(2026, 11, 21),
        to: DateTime(2026, 11, 21),
      ));
      expect(presetRange(DatePreset.custom, today, from: a), (from: a, to: DateTime(2026, 11, 21)));
    });
  });

  group('SearchState', () {
    // TC-34-02
    test('nothing typed and no filter is idle', () {
      const s = SearchState();
      expect(s.idle, isTrue);
      expect(s.hasFilters, isFalse);
      expect(s.filters.isEmpty, isTrue);
      expect(const SearchState(text: '  ,, ').idle, isTrue);
    });

    // TC-34-02
    test('text or any filter ends idle', () {
      expect(const SearchState(text: 'dinner').idle, isFalse);
      expect(const SearchState(text: 'dinner').hasFilters, isFalse);
      for (final s in [
        const SearchState(groupId: 'g'),
        const SearchState(category: 'food'),
        SearchState(from: DateTime(2026)),
        SearchState(to: DateTime(2026)),
        const SearchState(person: (key: 'm:1', name: 'Ravi', memberIds: {'1'})),
      ]) {
        expect(s.idle, isFalse);
        expect(s.hasFilters, isTrue);
      }
    });

    // TC-34-02
    test('filters carry ISO days, member ids and the category', () {
      final s = SearchState(
        groupId: 'g',
        person: (key: 'u:7', name: 'Asha', memberIds: {'a', 'b'}),
        from: DateTime(2026, 3, 5),
        to: DateTime(2026, 11, 21),
        category: 'food',
      );
      final f = s.filters;
      expect(f.groupId, 'g');
      expect(f.memberIds, {'a', 'b'});
      expect(f.from, '2026-03-05');
      expect(f.to, '2026-11-21');
      expect(f.category, 'food');
    });

    // TC-34-02
    test('the query is the parsed text', () {
      final q = const SearchState(text: 'Dinner 1,200').query;
      expect(q.words, ['dinner']);
      expect(q.amounts.single.text, '1200');
    });
  });

  group('controller', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);
    });

    ExpenseSearchController start([String? group]) {
      final p = searchControllerProvider(group);
      container.listen(p, (_, _) {});
      return container.read(p.notifier);
    }

    SearchState state([String? group]) => container.read(searchControllerProvider(group));

    // TC-34-02
    test('opened from a group it starts filtered to that group', () {
      start('g1');
      expect(state('g1').groupId, 'g1');
      expect(state('g1').idle, isFalse);
      start();
      expect(state().groupId, isNull);
      expect(state().idle, isTrue);
    });

    // TC-34-02
    test('setters change one thing each', () {
      final c = start();
      c.setText('din');
      c.setCategory('food');
      c.setDates(DatePreset.thisMonth, today: DateTime(2026, 11, 21));
      const asha = (key: 'u:1', name: 'Asha', memberIds: {'a'});
      c.setPerson(asha);
      c.setGroup('g1');
      final s = state();
      expect(s.text, 'din');
      expect(s.category, 'food');
      expect(s.datePreset, DatePreset.thisMonth);
      expect(s.from, DateTime(2026, 11));
      expect(s.to, DateTime(2026, 11, 21));
      expect(s.groupId, 'g1');
      expect(s.person, isNull, reason: 'a group change drops the person');
    });

    // TC-34-02
    test('setPerson keeps the group, null clears the person', () {
      final c = start();
      c.setGroup('g1');
      c.setPerson((key: 'm:1', name: 'Ravi', memberIds: {'r'}));
      expect(state().groupId, 'g1');
      expect(state().person?.name, 'Ravi');
      c.setPerson(null);
      expect(state().person, isNull);
      expect(state().groupId, 'g1');
    });

    // TC-34-02
    test('a custom date range and clearing the dates', () {
      final c = start();
      c.setDates(
        DatePreset.custom,
        today: DateTime(2026, 11, 21),
        from: DateTime(2026, 11, 9),
        to: DateTime(2026, 11, 3),
      );
      expect(state().from, DateTime(2026, 11, 3));
      expect(state().to, DateTime(2026, 11, 9));
      c.setDates(null, today: DateTime(2026, 11, 21));
      expect(state().datePreset, isNull);
      expect(state().from, isNull);
      expect(state().to, isNull);
    });

    // TC-34-02
    test(
      'clearing the filters keeps the typed text, and the group it was opened from goes too',
      () {
        final c = start('g1');
        c.setText('dinner');
        c.setCategory('food');
        c.setDates(DatePreset.thisYear, today: DateTime(2026, 11, 21));
        c.clearFilters();
        final s = state('g1');
        expect(s.text, 'dinner');
        expect(s.hasFilters, isFalse);
        expect(s.datePreset, isNull);
        expect(s.groupId, isNull);
      },
    );
  });

  group('providers over the local copy', () {
    late AppDatabase db;
    late ProviderContainer container;

    Future<void> pull(Map<String, List<Map<String, Object?>>> rows) => PullApplier(db).apply(
      PullPage(
        serverTime: DateTime.utc(2026, 11, 21),
        rows: rows,
        nextCursors: const {gid: 9},
        userSeq: 0,
      ),
    );

    Map<String, Object?> member(
      String id,
      String group,
      String name, {
      String? user,
      int position = 0,
      String? deletedAt,
    }) => {
      ...serverMember(id, position),
      'group_id': group,
      'display_name': name,
      'user_id': user,
      'deleted_at': deletedAt,
    };

    setUp(() async {
      db = testDb();
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          editor.currentUserIdProvider.overrideWithValue('u1'),
          groups.currentUserIdProvider.overrideWithValue('u1'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await pull({
        'groups': [
          serverGroup(name: 'Goa'),
          {...serverGroup(seq: 2), 'id': _pune, 'name': 'Pune'},
        ],
        'group_members': [
          member(m1, gid, 'Mohit', user: 'u1'),
          member(m2, gid, 'asha', user: 'u2', position: 1),
          member(_puneMe, _pune, 'Mohit', user: 'u1'),
          member(_puneAsha, _pune, 'Asha R', user: 'u2', position: 1),
          member(_puneBen, _pune, 'Ben', position: 2),
        ],
        'expenses': [
          serverExpense(_e1, description: 'Dinner in Goa'),
          {
            ...serverExpense(_e2, seq: 4, description: 'Dinner in Pune'),
            'group_id': _pune,
            'payers': {_puneMe: 10000},
            'shares': {_puneMe: 5000, _puneBen: 5000},
            'date': '2026-11-21',
          },
        ],
      });
    });

    Future<T> settled<T>(ProviderListenable<T> p) async {
      container.listen(p, (_, _) {});
      await pumpEventQueue(times: 200);
      return container.read(p);
    }

    // TC-34-02
    test('people across groups: one per account, me left out, by name', () async {
      final people = await settled(searchPeopleProvider(null));
      expect([for (final p in people) p.name], ['asha', 'Ben']);
      final asha = people.first;
      expect(asha.key, 'u:u2');
      expect(asha.memberIds, {m2, _puneAsha});
      expect(people.last.key, 'm:$_puneBen');
      expect(people.last.memberIds, {_puneBen});
    });

    // TC-34-02
    test('people of one group only', () async {
      final people = await settled(searchPeopleProvider(gid));
      expect([for (final p in people) p.name], ['asha']);
      expect(people.single.memberIds, {m2});
    });

    // TC-34-02
    test('removed members are not offered', () async {
      await pull({
        'group_members': [member(_puneBen, _pune, 'Ben', position: 2, deletedAt: '2026-11-21')],
      });
      final people = await settled(searchPeopleProvider(null));
      expect([for (final p in people) p.name], ['asha']);
    });

    // TC-34-02
    test('with nobody signed in everyone is offered', () async {
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          editor.currentUserIdProvider.overrideWithValue(null),
          groups.currentUserIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      c.listen(searchPeopleProvider(null), (_, _) {});
      await pumpEventQueue(times: 200);
      expect(
        [for (final p in c.read(searchPeopleProvider(null))) p.name],
        ['asha', 'Ben', 'Mohit'],
      );
    });

    // TC-34-02
    test('the results for typed text carry the group name', () async {
      container.listen(searchControllerProvider(null), (_, _) {});
      container.read(searchControllerProvider(null).notifier).setText('dinner');
      final results = await settled(searchResultsProvider(null));
      final hits = results.requireValue;
      expect(
        [for (final h in hits) h.view.expense.description],
        ['Dinner in Pune', 'Dinner in Goa'],
      );
      expect([for (final h in hits) h.groupName], ['Pune', 'Goa']);
      expect(hits.first.view.nameOf(_puneBen), 'Ben');
      expect(hits.first.view.meId, _puneMe);
    });

    // TC-34-02
    test('a person filter narrows the results', () async {
      container.listen(searchControllerProvider(null), (_, _) {});
      final c = container.read(searchControllerProvider(null).notifier);
      c.setText('dinner');
      c.setPerson((key: 'm:b', name: 'Ben', memberIds: {_puneBen}));
      final hits = (await settled(searchResultsProvider(null))).requireValue;
      expect([for (final h in hits) h.view.expense.description], ['Dinner in Pune']);
    });

    // TC-34-02
    test('opened from a group, the group filter is already on', () async {
      final hits = (await settled(searchResultsProvider(gid))).requireValue;
      expect([for (final h in hits) h.view.expense.description], ['Dinner in Goa']);
    });

    // TC-34-02
    test('nothing typed and no filter gives no results', () async {
      final results = await settled(searchResultsProvider(null));
      expect(results.requireValue, isEmpty);
    });

    // TC-34-02
    test('the group list for the filter is the live groups by name', () async {
      final list = await settled(searchGroupsProvider);
      expect([for (final g in list.requireValue) g.name], ['Goa', 'Pune']);
    });
  });
}
