// D-034 WP-C widget tests on the real router and an in-memory database: the group page's who-owes-whom lines
// (C1), the settled history folded in the Expenses tab (C2), the Groups filter (C3), trip dates and settle-up
// reminders on the form (C4), the group notes (C5) and search from the group page (C6).
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/expenses/presentation/editor/pickers.dart' show MonthCalendar;
import 'package:splitify/features/groups/application/group_extras_providers.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';

import '../../support/group_harness.dart';
import '../../support/ledger_seed.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, Finder f, {bool up = false}) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, up ? -300 : 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester, db: true);
}

final _people = [
  seedMember('m1', userId: 'u1', name: 'Mohit'),
  seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
  seedMember('m3', name: 'Rahul', position: 2),
  seedMember('m4', name: 'Neha', position: 3),
  seedMember('m5', name: 'Kiran', position: 4),
];

Future<AppDatabase> _db(
  WidgetTester tester, {
  List<LocalGroup>? groups,
  List<LocalMember>? members,
  List<LocalExpense> expenses = const [],
  List<LocalPayment> payments = const [],
  List<LocalActivity> activity = const [],
}) async {
  final db = openTestDb(tester);
  await tester.runAsync(() async {
    for (final g in groups ?? [seedGroup()]) {
      await db.into(db.groups).insert(g);
    }
    for (final m in members ?? _people) {
      await db.into(db.groupMembers).insert(m);
    }
    for (final e in expenses) {
      await db.into(db.expenses).insert(e);
    }
    for (final p in payments) {
      await db.into(db.payments).insert(p);
    }
    for (final a in activity) {
      await db.into(db.activity).insert(a);
    }
  });
  return db;
}

/// One-payer expense split by [shares].
LocalExpense _exp(
  String id,
  String payer,
  Map<String, int> shares, {
  String date = '2026-11-20',
  String currency = 'INR',
  String groupId = 'g1',
  String syncState = SyncState.synced,
}) {
  final total = shares.values.fold(0, (a, b) => a + b);
  return seedExpense(
    id,
    groupId: groupId,
    date: date,
    currency: currency,
    total: total,
    payers: {payer: total},
    shares: shares,
    syncState: syncState,
  );
}

Future<List<OutboxItem>> _outbox(WidgetTester tester, AppDatabase db) =>
    real(tester, () => db.select(db.outbox).get());

Future<LocalGroup> _group(WidgetTester tester, AppDatabase db, [String id = 'g1']) =>
    real(tester, () => (db.select(db.groups)..where((g) => g.id.equals(id))).getSingle());

/// Taps day [day] of the calendar in the open sheet.
Future<void> _pickDay(WidgetTester tester, int day) async {
  final cell = find.descendant(of: find.byType(MonthCalendar), matching: find.text('$day'));
  await tester.tap(cell.last);
  await settle(tester, db: true);
}

void main() {
  group('C1 who owes whom on the group page', () {
    testWidgets('up to 3 lines from my side, +N more opens the Balances tab with the same rows', (
      tester,
    ) async {
      final db = await _db(
        tester,
        expenses: [
          _exp('e1', 'm1', {'m2': 80000}),
          _exp('e2', 'm1', {'m3': 40000}),
          _exp('e3', 'm4', {'m1': 20000}),
          _exp('e4', 'm1', {'m5': 1000}, currency: 'USD'),
          // Not mine: Kiran owes Neha.
          _exp('e5', 'm4', {'m5': 5000}),
        ],
      );
      await pumpGroups(tester, '/groups/g1', db: db);
      expect(_key('group-lines'), findsOneWidget);
      // The main currency first: the three INR lines, the USD one behind "+1 more".
      expect(_key('group-line-INR-m2'), findsOneWidget);
      expect(_key('group-line-INR-m3'), findsOneWidget);
      expect(_key('group-line-INR-m4'), findsOneWidget);
      expect(_key('group-line-USD-m5'), findsNothing);
      expect(find.textContaining('Asha owes you'), findsOneWidget);
      expect(find.textContaining('You owe Neha'), findsOneWidget);
      expect(find.textContaining('Kiran'), findsNothing);
      expect(find.text('+1 more'), findsOneWidget);

      await _tap(tester, _key('group-lines-more'));
      expect(_key('balances-tab'), findsOneWidget);
      // The tab lists the same pairs (and Kiran → Neha, which is not mine).
      expect(_key('transfer-INR-m2-m1'), findsOneWidget);
      expect(_key('transfer-INR-m3-m1'), findsOneWidget);
      expect(_key('transfer-INR-m1-m4'), findsOneWidget);
      expect(_key('transfer-USD-m5-m1'), findsOneWidget);
    });

    testWidgets('the chevron folds the lines and the choice is kept on this phone', (tester) async {
      final db = await _db(
        tester,
        expenses: [
          _exp('e1', 'm1', {'m2': 30000}),
        ],
      );
      await pumpGroups(tester, '/groups/g1', db: db);
      expect(_key('group-line-INR-m2'), findsOneWidget);
      expect(find.text('+1 more'), findsNothing);
      expect(find.bySemanticsLabel('Hide who owes whom'), findsOneWidget);
      await _tap(tester, _key('group-lines-toggle'));
      expect(_key('group-lines'), findsNothing);
      expect(find.bySemanticsLabel('Show who owes whom'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(GroupLinesCollapsed.storageKey('g1')), isTrue);
      await _tap(tester, _key('group-lines-toggle'));
      expect(_key('group-line-INR-m2'), findsOneWidget);
      expect(prefs.getBool(GroupLinesCollapsed.storageKey('g1')), isNull);
    });

    testWidgets('follows simplify debts and shows "not synced yet" for pending rows', (
      tester,
    ) async {
      final db = await _db(
        tester,
        groups: [seedGroup(simplify: true)],
        expenses: [
          // Asha owes me 300, I owe Rahul 300 -> simplified: Asha pays Rahul, nothing for me.
          _exp('e1', 'm1', {'m2': 30000}),
          _exp('e2', 'm3', {'m1': 30000}),
          _exp('e3', 'm1', {'m4': 10000}, syncState: SyncState.pending),
        ],
      );
      await pumpGroups(tester, '/groups/g1', db: db);
      expect(_key('group-line-INR-m2'), findsNothing);
      expect(_key('group-line-INR-m3'), findsNothing);
      expect(_key('group-line-INR-m4'), findsOneWidget);
      expect(_key('group-lines-sync'), findsOneWidget);
    });

    testWidgets('settled or archived: only the pill', (tester) async {
      final db = await _db(
        tester,
        groups: [
          seedGroup(),
          seedGroup(id: 'g2', archivedAt: '2026-11-21T10:00:00Z'),
        ],
        members: [
          ..._people,
          seedMember('n1', groupId: 'g2', userId: 'u1', name: 'Mohit'),
          seedMember('n2', groupId: 'g2', name: 'Asha', position: 1),
        ],
        expenses: [
          _exp('x1', 'n1', {'n2': 30000}, groupId: 'g2'),
        ],
      );
      final h = await pumpGroups(tester, '/groups/g1', db: db);
      expect(_key('group-status-settled'), findsOneWidget);
      expect(_key('group-lines-toggle'), findsNothing);
      h.open('/groups/g2');
      await settle(tester, db: true);
      expect(_key('group-lines-toggle'), findsNothing);
    });
  });

  group('C2 settled history', () {
    testWidgets('a settled group folds the rows before the settle-up into one row', (tester) async {
      final db = await _db(
        tester,
        expenses: [
          _exp('e1', 'm1', {'m2': 30000}, date: '2026-11-01'),
          _exp('e2', 'm2', {'m1': 10000}, date: '2026-11-02'),
          // After everyone settled: moves nothing, stays visible.
          _exp('e3', 'm1', {'m1': 5000}, date: '2026-11-10'),
        ],
        payments: [seedPayment('p1', from: 'm2', to: 'm1', amount: 20000, date: '2026-11-05')],
      );
      await pumpGroups(tester, '/groups/g1', db: db);
      expect(find.byKey(const ValueKey('expense-e3')), findsOneWidget);
      expect(find.byKey(const ValueKey('expense-e1')), findsNothing);
      expect(find.byKey(const ValueKey('expense-e2')), findsNothing);
      expect(find.text('Show 3 settled expenses'), findsOneWidget);

      await _tap(tester, _key('expenses-settled'));
      expect(find.byKey(const ValueKey('expense-e1')), findsOneWidget);
      expect(find.byKey(const ValueKey('expense-e2')), findsOneWidget);
      expect(find.text('Hide settled expenses'), findsOneWidget);
    });

    testWidgets('an open balance lists everything', (tester) async {
      final db = await _db(
        tester,
        expenses: [
          _exp('e1', 'm1', {'m2': 30000}, date: '2026-11-01'),
          _exp('e4', 'm1', {'m3': 1000}, date: '2026-11-12'),
        ],
        payments: [seedPayment('p1', from: 'm2', to: 'm1', amount: 30000, date: '2026-11-05')],
      );
      await pumpGroups(tester, '/groups/g1', db: db);
      expect(find.byKey(const ValueKey('expense-e1')), findsOneWidget);
      expect(_key('expenses-settled'), findsNothing);
    });
  });

  group('C3 groups filter', () {
    Future<AppDatabase> three(WidgetTester tester) => _db(
      tester,
      groups: [
        seedGroup(id: 'gA', name: 'I owe here'),
        seedGroup(id: 'gB', name: 'Owed here', createdAt: '2026-11-02T10:00:00Z'),
        seedGroup(id: 'gC', name: 'Settled here', createdAt: '2026-11-03T10:00:00Z'),
      ],
      members: [
        for (final g in ['gA', 'gB', 'gC']) ...[
          seedMember('$g-me', groupId: g, userId: 'u1', name: 'Mohit'),
          seedMember('$g-x', groupId: g, name: 'Asha', position: 1),
        ],
      ],
      expenses: [
        _exp('a1', 'gA-x', {'gA-me': 10000}, groupId: 'gA'),
        _exp('b1', 'gB-me', {'gB-x': 10000}, groupId: 'gB'),
      ],
    );

    testWidgets('All / Outstanding / I owe / Owe me, kept on this phone', (tester) async {
      final db = await three(tester);
      await pumpGroups(tester, '/groups', db: db);
      for (final g in ['gA', 'gB', 'gC']) {
        expect(_key('group-card-$g'), findsOneWidget);
      }
      Future<void> pick(String f) async {
        await _tap(tester, _key('groups-filter'));
        await _tap(tester, _key('groups-filter-$f'));
      }

      await pick('iOwe');
      expect(_key('group-card-gA'), findsOneWidget);
      expect(_key('group-card-gB'), findsNothing);
      expect(_key('group-card-gC'), findsNothing);
      expect(find.text('ACTIVE GROUPS\u00A0· 1'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GroupFilterController.storageKey), 'iOwe');

      await pick('owedToMe');
      expect(_key('group-card-gA'), findsNothing);
      expect(_key('group-card-gB'), findsOneWidget);

      await pick('outstanding');
      expect(_key('group-card-gA'), findsOneWidget);
      expect(_key('group-card-gB'), findsOneWidget);
      expect(_key('group-card-gC'), findsNothing);

      await pick('all');
      expect(_key('group-card-gC'), findsOneWidget);
      expect(prefs.getString(GroupFilterController.storageKey), 'all');
    });

    testWidgets('no match: "No groups match" with Show all', (tester) async {
      final db = await _db(
        tester,
        groups: [seedGroup(id: 'gC', name: 'Settled here')],
      );
      await pumpGroups(tester, '/groups', db: db);
      await _tap(tester, _key('groups-filter'));
      await _tap(tester, _key('groups-filter-iOwe'));
      expect(find.text('No groups match'), findsOneWidget);
      await _tap(tester, _key('groups-filter-show-all'));
      expect(_key('group-card-gC'), findsOneWidget);
    });

    test('the choice survives a restart (read back from preferences)', () async {
      SharedPreferences.setMockInitialValues({GroupFilterController.storageKey: 'owedToMe'});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      expect(c.read(groupFilterProvider), GroupFilter.owedToMe);
      c.read(groupFilterProvider.notifier).select(GroupFilter.iOwe);
      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(groupFilterProvider), GroupFilter.iOwe);
    });

    test('no preferences (some tests): defaults, no crash', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(groupFilterProvider), GroupFilter.all);
      c.read(groupFilterProvider.notifier).select(GroupFilter.iOwe);
      expect(c.read(groupFilterProvider), GroupFilter.iOwe);
      expect(c.read(groupLinesCollapsedProvider('g1')), isFalse);
    });
  });

  group('C4 trip dates and settle-up reminders on the form', () {
    testWidgets('pick both days, an end before the start blocks Save, weekly reminders save', (
      tester,
    ) async {
      final db = await _db(tester);
      final h = await pumpGroups(tester, '/groups/g1/edit', db: db);
      await _tap(tester, _key('trip-start'));
      await _pickDay(tester, 12);
      await _tap(tester, _key('trip-end'));
      await _pickDay(tester, 10);
      expect(_key('trip-error'), findsOneWidget);
      expect(find.text('The trip ends before it starts'), findsOneWidget);
      await _tap(tester, _key('group-save'));
      expect(await _outbox(tester, db), isEmpty, reason: 'nothing saved while the dates are wrong');
      expect(h.location, '/groups/g1/edit');

      await _tap(tester, _key('trip-end'));
      await _pickDay(tester, 18);
      expect(_key('trip-error'), findsNothing);
      await _tap(tester, find.text('Weekly'));
      // Seeded group: created Sun 1 Nov 2026 -> weekly on Sundays; today is Sun 22 Nov.
      expect(
        find.text('Every Sunday, everyone who owes or is owed gets a reminder.'),
        findsOneWidget,
      );
      expect(find.text('Next reminder: Sun, 22 Nov'), findsOneWidget);
      await _tap(tester, _key('group-save'));

      final g = await _group(tester, db);
      expect(
        (g.tripStartsOn, g.tripEndsOn, g.settleReminder),
        ('2026-11-12', '2026-11-18', 'weekly'),
      );
      final sent = jsonDecode((await _outbox(tester, db)).single.payload) as Map<String, Object?>;
      expect(sent, containsPair('trip_starts_on', '2026-11-12'));
      expect(sent, containsPair('trip_ends_on', '2026-11-18'));
      expect(sent, containsPair('settle_reminder', 'weekly'));
    });

    testWidgets('no end date means no end; another type clears the dates', (tester) async {
      final db = await _db(
        tester,
        groups: [
          seedGroup().copyWith(
            tripStartsOn: const Value('2026-12-12'),
            tripEndsOn: const Value('2026-12-18'),
          ),
        ],
      );
      await pumpGroups(tester, '/groups/g1/edit', db: db);
      await _tap(tester, _key('trip-end'));
      await _tap(tester, _key('trip-no-end'));
      expect(find.text('No end'), findsOneWidget);
      // Monthly: the next 1st.
      await _tap(tester, find.text('Monthly'));
      expect(find.text('Next reminder: Tue, 1 Dec'), findsOneWidget);
      await _tap(tester, _key('group-type-home'), up: true);
      expect(_key('trip-start'), findsNothing);
      await _tap(tester, _key('group-save'));
      final g = await _group(tester, db);
      expect(
        (g.type, g.tripStartsOn, g.tripEndsOn, g.settleReminder),
        ('home', null, null, 'monthly'),
      );
    });

    testWidgets('a new trip with dates: the group, then its dates, both through the outbox', (
      tester,
    ) async {
      final db = await _db(tester, groups: const [], members: const []);
      await pumpGroups(tester, '/groups/new', db: db);
      await tester.enterText(_key('group-name'), 'Ladakh');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await _tap(tester, _key('trip-start'));
      await _pickDay(tester, 25);
      await _tap(tester, _key('group-save'));
      final g = (await real(tester, () => db.select(db.groups).get())).single;
      expect((g.name, g.tripStartsOn, g.tripEndsOn), ('Ladakh', '2026-11-25', null));
      final out = await _outbox(tester, db);
      expect(out.map((o) => o.entity), ['group', 'group']);
      expect(jsonDecode(out.last.payload), containsPair('trip_starts_on', '2026-11-25'));
      // Back on the group page: the dates chip.
      expect(_key('group-trip-dates'), findsOneWidget);
      expect(find.text('From 25 Nov'), findsOneWidget);
    });
  });

  group('C5 group notes', () {
    testWidgets('empty, typed and saved offline: outbox, "Notes saved", the chip on the page', (
      tester,
    ) async {
      final db = await _db(tester);
      final h = await pumpGroups(tester, '/groups/g1', db: db);
      expect(_key('group-notes-chip'), findsNothing);
      h.open('/groups/g1/notes');
      await settle(tester, db: true);
      expect(find.text('Group notes'), findsOneWidget);
      expect(_key('board-edited'), findsNothing);
      await tester.enterText(_key('board-text'), 'Villa: 12 Beach Rd\nWi-Fi: goa2026');
      await tester.pump();
      await _tap(tester, _key('board-save'));
      expect(find.text('Notes saved'), findsOneWidget);
      expect(h.location, '/groups/g1');
      final g = await _group(tester, db);
      expect(g.whiteboard, 'Villa: 12 Beach Rd\nWi-Fi: goa2026');
      expect(g.syncState, SyncState.pending);
      final sent = (await _outbox(tester, db)).single;
      expect(jsonDecode(sent.payload), {'whiteboard': 'Villa: 12 Beach Rd\nWi-Fi: goa2026'});
      expect(_key('group-notes-chip'), findsOneWidget);

      // Reopened: my change, not synced yet.
      await _tap(tester, _key('group-notes-chip'));
      expect(find.textContaining('Last edited by you'), findsOneWidget);
      expect(find.text('Not synced yet'), findsOneWidget);
    });

    testWidgets(
      '"Last edited by Asha" from the activity; too long shows the error, saves nothing',
      (tester) async {
        final db = await _db(
          tester,
          groups: [seedGroup().copyWith(whiteboard: const Value('Door code 4512'))],
          activity: [
            seedActivity(
              'a1',
              'whiteboard_updated',
              actorUserId: 'u2',
              actorMemberId: 'm2',
              targetType: 'group',
              targetId: 'g1',
              createdAt: '2026-11-21T10:00:00Z',
            ),
          ],
        );
        await pumpGroups(tester, '/groups/g1/notes', db: db);
        expect(find.text('Door code 4512'), findsOneWidget);
        expect(find.text('Last edited by Asha · 21 Nov'), findsOneWidget);
        await tester.enterText(_key('board-text'), 'x' * 5001);
        await tester.pump();
        expect(find.text('5,001 / 5,000'), findsOneWidget);
        await _tap(tester, _key('board-save'));
        expect(find.text('Notes can be up to 5,000 characters'), findsOneWidget);
        expect(await _outbox(tester, db), isEmpty);
        // The typed text stays.
        expect(find.text('x' * 5001), findsOneWidget);
      },
    );

    testWidgets('archived: read only; settings has the Group notes row', (tester) async {
      final db = await _db(tester, groups: [seedGroup(archivedAt: '2026-11-21T10:00:00Z')]);
      final h = await pumpGroups(tester, '/groups/g1/settings', db: db);
      await _tap(tester, _key('settings-notes'));
      expect(h.location, '/groups/g1/notes');
      expect(find.text("This group is archived, so its notes can't be changed."), findsOneWidget);
      expect(_key('board-save'), findsNothing);
    });
  });

  testWidgets('C6 the search icon opens search for this group', (tester) async {
    final db = await _db(tester);
    final h = await pumpGroups(tester, '/groups/g1', db: db);
    await _tap(tester, _key('group-search'));
    expect(h.location, '/search?group=g1');
  });
}
