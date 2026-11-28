// R3-B performance regressions (S-454, S-455, S-457): lazy lists build one screen of rows, writes to other
// groups send nothing new to an open group, sync loads coalesce, and opening/closing screens 20 times leaves
// no undisposed controllers behind. Device numbers: integration_test/perf_r3_test.dart (tool/e2e/perf_r3.ps1).
import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/stream_ext.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/insights/presentation/insights_routes.dart';
import 'package:splitify/ui/components/components.dart';

import '../features/expenses/expense_fixtures.dart' hide sampleGroup;
import '../support/group_fakes.dart';
import '../support/group_harness.dart';
import '../support/ledger_seed.dart';

/// Every Flutter object that reports its creation and disposal (controllers, notifiers, layers…) and is not
/// disposed yet, by class name.
class _LiveObjects {
  final _live = <Object, String>{};

  void _on(ObjectEvent e) {
    if (e is ObjectCreated) _live[e.object] = e.className;
    if (e is ObjectDisposed) _live.remove(e.object);
  }

  void start() => FlutterMemoryAllocations.instance.addListener(_on);

  void stop() => FlutterMemoryAllocations.instance.removeListener(_on);

  Map<String, int> get byClass {
    final out = <String, int>{};
    for (final c in _live.values) {
      out[c] = (out[c] ?? 0) + 1;
    }
    return out;
  }
}

void main() {
  group('lazy lists (S-454)', () {
    testWidgets('Groups home with 50 groups builds only the cards near the screen', (tester) async {
      final groups = [
        for (var i = 0; i < 50; i++)
          sampleGroup(
            id: 'g$i',
            name: 'Group $i',
            createdAt: '2026-11-20T10:${i.toString().padLeft(2, '0')}:00Z',
          ),
      ];
      await pumpGroups(tester, '/groups', overrides: fixedGroupData(groups: groups));
      await settle(tester);
      final built = find.byType(GroupCoverCard, skipOffstage: false).evaluate().length;
      expect(
        built,
        inInclusiveRange(2, 12),
        reason: 'was 50: every card built, laid out and painted',
      );
      // The last card is still reachable.
      await tester.scrollUntilVisible(
        find.byKey(Key('group-card-${groups.last.id}')),
        800,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(Key('group-card-${groups.last.id}')), findsOneWidget);
    });

    testWidgets('a group with 2,000 expenses builds one screen of rows', (tester) async {
      const gid = 'g-goa';
      final views = [
        for (var i = 0; i < 2000; i++)
          sampleView(
            sampleExpense(
              id: 'e$i',
              date: '2026-${(1 + (i ~/ 200) % 11).toString().padLeft(2, '0')}-10',
              total: 10000 + i,
              payers: {'m1': 10000 + i},
            ),
          ),
      ];
      await pumpGroups(
        tester,
        '/groups/$gid',
        overrides: fixedGroupData(groups: [sampleGroup()], expenses: {gid: views}),
      );
      await settle(tester);
      final rows = find.byType(ExpenseRow, skipOffstage: false).evaluate().length;
      expect(rows, inInclusiveRange(1, 25));
    });
  });

  group('sync storms (S-455)', () {
    late AppDatabase db;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    Future<void> seed() async {
      await db.batch((b) {
        b
          ..insert(db.groups, seedGroup(id: 'A'))
          ..insert(db.groups, seedGroup(id: 'B', name: 'Flat'))
          ..insert(db.groupMembers, seedMember('a1', groupId: 'A'))
          ..insert(db.groupMembers, seedMember('a2', groupId: 'A', position: 1))
          ..insert(db.groupMembers, seedMember('b1', groupId: 'B'));
        for (var i = 0; i < 200; i++) {
          b.insert(
            db.expenses,
            seedExpense(
              'ea$i',
              groupId: 'A',
              total: 200,
              payers: {'a1': 200},
              shares: {'a1': 100, 'a2': 100},
            ),
          );
        }
      });
    }

    Future<void> writeToB(int n) async {
      for (var i = 0; i < n; i++) {
        await db
            .into(db.expenses)
            .insert(
              seedExpense('eb$i', groupId: 'B', total: 50, payers: {'b1': 50}, shares: {'b1': 50}),
            );
      }
    }

    test('ten writes to another group send nothing new to an open group', () async {
      await seed();
      final ledgers = <GroupLedger?>[];
      final expenses = <int>[];
      final s1 = LedgerRepository(db).watchGroup('A').listen(ledgers.add);
      final s2 = (db.select(db.expenses)..where((e) => e.groupId.equals('A')))
          .watch()
          .distinctRows()
          .listen((rows) => expenses.add(rows.length));
      await pumpEventQueue(times: 50);
      expect(ledgers, hasLength(1));
      expect(expenses, [200]);

      await writeToB(10);
      await pumpEventQueue(times: 200);
      expect(ledgers, hasLength(1), reason: 'before S-455 every write re-sent the whole ledger');
      expect(expenses, [200]);

      // A write to the open group still arrives.
      await db
          .into(db.expenses)
          .insert(
            seedExpense(
              'ea-new',
              groupId: 'A',
              total: 300,
              payers: {'a2': 300},
              shares: {'a1': 300},
            ),
          );
      await pumpEventQueue(times: 200);
      expect(ledgers, hasLength(2));
      expect(ledgers.last!.expenses, hasLength(201));
      expect(expenses, [200, 201]);
      await s1.cancel();
      await s2.cancel();
    });

    test('a burst of writes reloads every ledger a couple of times, not once per write', () async {
      await seed();
      var loads = 0;
      final repo = _CountingLedgers(db, () => loads++);
      final seen = <List<GroupLedger>>[];
      final sub = repo.watchAll().listen(seen.add);
      await pumpEventQueue(times: 50);
      final before = loads;
      // Ten writes, no waiting between them (a pull applying pages back to back).
      await Future.wait([
        for (var i = 0; i < 10; i++)
          db
              .into(db.expenses)
              .insert(
                seedExpense(
                  'burst$i',
                  groupId: 'B',
                  total: 10,
                  payers: {'b1': 10},
                  shares: {'b1': 10},
                ),
              ),
      ]);
      await pumpEventQueue(times: 400);
      expect(loads - before, lessThanOrEqualTo(3), reason: 'was 10: one full reload per write');
      expect(seen.last.firstWhere((l) => l.group.id == 'B').expenses, hasLength(10));
      await sub.cancel();
    });
  });

  group('memory (S-457)', () {
    testWidgets(
      'opening and closing the group page, editor and Insights 20 times leaves nothing undisposed',
      (tester) async {
        const gid = 'g-goa';
        final h = await pumpGroups(
          tester,
          '/groups',
          overrides: fixedGroupData(
            groups: [sampleGroup()],
            expenses: {
              gid: [for (var i = 0; i < 300; i++) sampleView(sampleExpense(id: 'e$i'))],
            },
          ),
        );
        await settle(tester);
        final live = _LiveObjects()..start();
        addTearDown(live.stop);
        Future<void> roundTrip() async {
          for (final route in ['/groups/$gid', ExpenseRoutes.add(gid), InsightsRoutes.group(gid)]) {
            h.open(route);
            await settle(tester, frames: 8);
            h.router.pop();
            await settle(tester, frames: 8);
          }
        }

        await roundTrip();
        final afterOne = live.byClass;
        for (var i = 0; i < 19; i++) {
          await roundTrip();
        }
        final afterTwenty = live.byClass;
        final grew = {
          for (final e in afterTwenty.entries)
            if (e.value > (afterOne[e.key] ?? 0)) e.key: '${afterOne[e.key] ?? 0} → ${e.value}',
        };
        expect(grew, isEmpty, reason: 'objects created by a visit and never disposed');
      },
    );

    testWidgets('motion widgets dispose their controllers (mounted and removed 20 times)', (
      tester,
    ) async {
      final live = _LiveObjects()..start();
      addTearDown(live.stop);
      for (var i = 0; i < 20; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InsertMotionScope(
                ids: const ['a'],
                child: Column(
                  children: [
                    const InsertMotion(id: 'a', child: SizedBox(height: 10)),
                    AppExpand(open: i.isEven, child: const SizedBox(height: 20)),
                    MotionSwitcher(child: SizedBox(key: ValueKey(i), height: 5)),
                    SelectionMotion(
                      selected: i.isOdd,
                      builder: (context, t, _) => SizedBox(height: 4 + t),
                    ),
                    const SuccessCheck(size: 20),
                    Pressable(onTap: () {}, child: const SizedBox(height: 30)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpAndSettle();
      final left = {
        for (final e in live.byClass.entries)
          if (e.key.contains('AnimationController') || e.key.contains('Ticker')) e.key: e.value,
      };
      expect(left, isEmpty);
    });
  });
}

/// A ledger repository that counts full reloads.
class _CountingLedgers extends LedgerRepository {
  _CountingLedgers(super.db, this.onLoad);

  final VoidCallback onLoad;

  @override
  Future<List<GroupLedger>> loadAll() {
    onLoad();
    return super.loadAll();
  }
}
