// TC-17-03 (simplify debts setting): the row in group settings, its offline write through the outbox and
// the group's balances following it. The Balances tab with simplify on ("Suggested payments" + "Show
// original debts") is covered in test/features/balances/presentation/balances_tab_test.dart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/groups/presentation/simplify_setting.dart';

import '../../support/group_fakes.dart';
import '../../support/group_harness.dart';
import '../../support/ledger_seed.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tap(WidgetTester tester, String key) async {
  if (_key(key).evaluate().isEmpty) {
    await tester.scrollUntilVisible(_key(key), 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(_key(key));
  await tester.pump();
  await tester.tap(_key(key));
  await settle(tester, db: true);
}

/// Me (u1), Asha and Kabir in a cycle: I owe Asha 10.00, Asha owes Kabir 10.00, Kabir owes me 10.00.
Future<AppDatabase> _seed(
  WidgetTester tester, {
  String type = 'trip',
  bool simplify = false,
}) async {
  final db = openTestDb(tester);
  await tester.runAsync(() async {
    await db.seed(
      groups: [seedGroup(type: type, simplify: simplify, createdAt: '2026-11-01T10:00:00Z')],
      members: [
        seedMember('m1', userId: 'u1', name: 'Asha Rao'),
        seedMember('m2', name: 'Ravi', position: 1),
        seedMember('m3', name: 'Kabir', position: 2),
      ],
      expenses: [
        seedExpense('e1', total: 1000, payers: {'m2': 1000}, shares: {'m1': 1000}),
        seedExpense('e2', total: 1000, payers: {'m3': 1000}, shares: {'m2': 1000}),
        seedExpense('e3', total: 1000, payers: {'m1': 1000}, shares: {'m3': 1000}),
      ],
    );
  });
  return db;
}

Future<LocalGroup> _group(WidgetTester t, AppDatabase db) async =>
    (await real(t, () => db.select(db.groups).get())).single;

void main() {
  group('Simplify debts setting', () {
    // TC-17-03
    testWidgets('the row is in the settings of a normal group, switched off by default', (t) async {
      final db = await _seed(t);
      await pumpGroups(t, '/groups/g1/settings', db: db);
      expect(find.byType(SimplifySettingRow), findsOneWidget);
      expect(find.text('Simplify debts'), findsOneWidget);
      expect(
        find.text(
          "Fewer payments, same totals. Someone may pay a person they didn't share an expense with.",
        ),
        findsOneWidget,
      );
      expect(t.widget<Switch>(_key('settings-simplify-switch')).value, isFalse);
    });

    // TC-17-03
    testWidgets('the row shows the saved setting', (t) async {
      final db = await _seed(t, simplify: true);
      await pumpGroups(t, '/groups/g1/settings', db: db);
      expect(t.widget<Switch>(_key('settings-simplify-switch')).value, isTrue);
    });

    // TC-17-03
    testWidgets('a friend (direct) group has no simplify row', (t) async {
      final db = await _seed(t, type: 'direct');
      await pumpGroups(t, '/groups/g1/settings', db: db);
      expect(find.byType(SimplifySettingRow), findsNothing);
      expect(find.text('Simplify debts'), findsNothing);
    });

    // TC-17-03
    testWidgets('tapping the switch writes simplify_debts through the outbox and says so', (
      t,
    ) async {
      final db = await _seed(t);
      await pumpGroups(t, '/groups/g1/settings', db: db);
      await _tap(t, 'settings-simplify-switch');

      final g = await _group(t, db);
      expect(g.simplifyDebts, isTrue);
      expect(g.syncState, 'pending');
      final outbox = await real(t, () => db.select(db.outbox).get());
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'group');
      expect(outbox.single.op, 'upsert');
      expect(outbox.single.recordId, 'g1');
      expect(jsonDecode(outbox.single.payload), {'simplify_debts': true});
      expect(find.text('Simplify debts is on'), findsOneWidget);
      expect(t.widget<Switch>(_key('settings-simplify-switch')).value, isTrue);
    });

    // TC-17-03
    testWidgets('tapping the row turns it back off, and each change is queued', (t) async {
      final db = await _seed(t, simplify: true);
      await pumpGroups(t, '/groups/g1/settings', db: db);
      await _tap(t, 'settings-simplify');
      expect((await _group(t, db)).simplifyDebts, isFalse);
      expect(find.text('Simplify debts is off'), findsOneWidget);
      await _tap(t, 'settings-simplify');
      expect((await _group(t, db)).simplifyDebts, isTrue);
      final outbox = await real(t, () => db.select(db.outbox).get());
      expect(
        [for (final o in outbox) jsonDecode(o.payload)],
        [
          {'simplify_debts': false},
          {'simplify_debts': true},
        ],
      );
    });

    // TC-17-03
    testWidgets('the group balances follow the setting: the cycle disappears when simplified', (
      t,
    ) async {
      final db = await _seed(t);
      await pumpGroups(t, '/groups/g1/settings', db: db);
      final container = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
      final sub = container.listen(groupBalancesProvider('g1'), (_, _) {});
      addTearDown(sub.close);

      Future<GroupBalances> balances() async {
        for (var i = 0; i < 30; i++) {
          final v = container.read(groupBalancesProvider('g1')).value;
          if (v != null) return v;
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
          await t.pump(const Duration(milliseconds: 100));
        }
        fail('balances did not load');
      }

      var b = await balances();
      expect(b.simplify, isFalse);
      expect(b.shown('INR'), hasLength(3), reason: 'original debts: the three pairs');

      await _tap(t, 'settings-simplify-switch');
      b = await balances();
      expect(b.simplify, isTrue);
      expect(b.shown('INR'), isEmpty, reason: 'every net is 0, so nothing to pay');
      // Nobody owes anything different overall (rule 12).
      expect(b.byCurrency['INR']!.nets.values.every((v) => v == 0), isTrue);
    });
  });
}
