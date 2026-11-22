// TC-22-01: "Export CSV" on the Totals tab and in group settings (share sheet, empty, failure, not found).
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/presentation/totals_tab.dart';
import 'package:splitify/features/export/application/group_export.dart';

import '../../../support/fakes.dart';
import '../../../support/group_harness.dart' as gh;
import '../../../support/ledger_seed.dart';
import '../../balances/balance_fixtures.dart';
import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart' as ph;

typedef _Shared = ({Uint8List bytes, String name, String subject});

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: TotalsTab(groupId: gid),
      ),
    ),
  );
}

/// Lets real database futures finish between frames.
Future<void> _settleDb(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _seed(WidgetTester t, AppDatabase db, {bool expense = true, bool group = true}) async {
  await t.runAsync(
    () => db.seed(
      groups: group ? [seedGroup(id: gid)] : const [],
      members: group
          ? [
              seedMember('m1', groupId: gid, name: 'Mohit', userId: 'u1'),
              seedMember('m2', groupId: gid, name: 'Asha', position: 1),
            ]
          : const [],
      expenses: expense
          ? [
              seedExpense(
                'e1',
                groupId: gid,
                total: 30000,
                payers: {'m1': 30000},
                shares: {'m1': 15000, 'm2': 15000},
              ),
            ]
          : const [],
    ),
  );
}

void main() {
  late AppDatabase db;
  late List<_Shared> shared;
  Object? sharerError;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = testDb();
    shared = [];
    sharerError = null;
  });

  tearDown(() => db.close());

  List<Override> overrides() => [
    ledgerRepositoryProvider.overrideWithValue(LedgerRepository(db)),
    csvSharerProvider.overrideWithValue((bytes, name, subject) async {
      final e = sharerError;
      if (e != null) throw e;
      shared.add((bytes: bytes, name: name, subject: subject));
    }),
  ];

  Future<void> pumpTotals(WidgetTester t) async {
    ph.usePhone(t);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      expenseApp(
        const _Host(),
        overrides: [
          groupTotalsProvider(gid).overrideWithValue(AsyncData(sampleTotals())),
          ...overrides(),
        ],
      ),
    );
    await ph.settle(t);
  }

  Future<void> tapExport(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await ph.reveal(t, f);
    await t.tap(f);
    await _settleDb(t);
  }

  group('Totals tab "Export CSV"', () {
    // TC-22-01
    testWidgets('shares a UTF-8 CSV named after the group and the day', (t) async {
      await pumpTotals(t);
      await _seed(t, db);
      expect(find.text('Export CSV', skipOffstage: false), findsOneWidget);
      await tapExport(t, 'totals-export');
      final f = shared.single;
      expect(f.bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(f.name, 'splitify-goa-trip-2026-11-21.csv');
      expect(f.subject, 'Goa trip expenses (Splitify)');
      expect(find.byType(SnackBar), findsNothing);
    });

    // TC-22-01
    testWidgets('a group with nothing in it says so and shares nothing', (t) async {
      await pumpTotals(t);
      await _seed(t, db, expense: false);
      await tapExport(t, 'totals-export');
      expect(shared, isEmpty);
      expect(find.text('Nothing to export yet. Add an expense first.'), findsOneWidget);
    });

    // TC-22-01
    testWidgets('a failing share sheet shows "Couldn\'t export. Try again."', (t) async {
      await pumpTotals(t);
      await _seed(t, db);
      sharerError = Exception('no share sheet');
      await tapExport(t, 'totals-export');
      expect(shared, isEmpty);
      expect(find.text("Couldn't export. Try again."), findsOneWidget);
    });

    // TC-22-01
    testWidgets('a group that is not on this phone says so', (t) async {
      await pumpTotals(t);
      await tapExport(t, 'totals-export');
      expect(shared, isEmpty);
      expect(find.text('This group is not on this phone.'), findsOneWidget);
    });
  });

  group('Group settings "Export CSV"', () {
    Future<void> pumpSettings(WidgetTester t) async {
      await gh.pumpGroups(
        t,
        '/groups/g1/settings',
        overrides: [
          ...gh.fixedGroupData(groups: [seedGroup()]),
          ...overrides(),
        ],
      );
    }

    Future<void> tapSettingsExport(WidgetTester t) async {
      final f = find.byKey(const Key('settings-export'));
      await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
      await t.tap(f);
      await gh.settle(t, db: true);
    }

    Future<void> seedG1(WidgetTester t, {bool expense = true}) => t.runAsync(
      () => db.seed(
        groups: [seedGroup()],
        members: [seedMember('m1', name: 'Mohit', userId: 'u1')],
        expenses: expense
            ? [
                seedExpense('e1', total: 100, payers: {'m1': 100}, shares: {'m1': 100}),
              ]
            : const [],
      ),
    );

    // TC-22-01
    testWidgets('shares the file from the settings row', (t) async {
      await pumpSettings(t);
      await seedG1(t);
      await tapSettingsExport(t);
      expect(shared.single.name, 'splitify-goa-trip-2026-11-22.csv');
      expect(shared.single.subject, 'Goa trip expenses (Splitify)');
    });

    // TC-22-01
    testWidgets('an empty group and a failing share sheet each show their message', (t) async {
      await pumpSettings(t);
      await seedG1(t, expense: false);
      await tapSettingsExport(t);
      expect(find.text('Nothing to export yet. Add an expense first.'), findsOneWidget);

      await seedG1(t);
      sharerError = Exception('boom');
      await tapSettingsExport(t);
      expect(find.text("Couldn't export. Try again."), findsOneWidget);
      expect(shared, isEmpty);
    });
  });
}
