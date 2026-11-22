// TC-22-01 (mapping part): the CSV export read from the phone's database and shared as a file.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/export_reads.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/export/application/group_export.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

import '../../../support/fakes.dart';
import '../../../support/ledger_seed.dart';

String _label(String key) => 'L:$key';

List<LocalMember> _members() => [
  // Stored out of order on purpose; the export lists them by position.
  seedMember('m3', name: 'Ravi', position: 2),
  seedMember('m1', name: 'Mohit', userId: 'u1'),
  seedMember('m2', name: 'Asha', userId: 'u2', position: 1),
  seedMember('m4', name: 'Gone', position: 3, deletedAt: '2026-11-05T00:00:00Z'),
];

List<LocalExpense> _expenses() => [
  seedExpense(
    'e1',
    description: 'Dinner',
    date: '2026-11-18',
    total: 30000,
    payers: {'m1': 30000},
    shares: {'m1': 10000, 'm2': 10000, 'm3': 10000},
    createdBy: 'u2',
  ),
  // Not yet on the server: no creator, seq 0 = added on this phone.
  seedExpense(
    'e2',
    description: 'Loan',
    date: '2026-11-19',
    kind: 'iou',
    total: 5000,
    payers: {'m1': 5000},
    shares: {'m2': 5000},
    seq: 0,
  ),
  seedExpense(
    'e3',
    description: 'Old taxi',
    date: '2026-11-20',
    total: 2000,
    payers: {'m2': 2000},
    shares: {'m1': 1000, 'm2': 1000},
    createdBy: 'u1',
    deletedAt: '2026-11-21T10:00:00Z',
  ),
  // Synced but creator unknown: nobody to name.
  seedExpense(
    'e4',
    description: 'Mystery',
    date: '2026-11-21',
    total: 1000,
    payers: {'m3': 1000},
    shares: {'m3': 1000},
  ),
];

List<LocalPayment> _payments() => [
  seedPayment(
    'p1',
    from: 'm2',
    to: 'm1',
    amount: 2000,
    method: 'upi',
    note: 'thanks',
  ).copyWith(createdBy: const Value('u2')),
];

void main() {
  late AppDatabase db;
  late LedgerRepository repo;

  setUp(() {
    db = testDb();
    repo = LedgerRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedAll() => db.seed(
    groups: [seedGroup()],
    members: _members(),
    expenses: _expenses(),
    payments: _payments(),
  );

  group('loadExport', () {
    // TC-22-01
    test('returns the group, members by position and every row, deleted ones too', () async {
      await seedAll();
      final x = (await repo.loadExport('g1'))!;
      expect(x.group.name, 'Goa trip');
      expect([for (final m in x.members) m.id], ['m1', 'm2', 'm3', 'm4']);
      expect([for (final e in x.expenses) e.id], ['e1', 'e2', 'e3', 'e4']);
      expect(x.expenses.firstWhere((e) => e.id == 'e3').deletedAt, isNotNull);
      expect([for (final p in x.payments) p.id], ['p1']);
    });

    // TC-22-01
    test('only that group\'s rows, oldest first', () async {
      await seedAll();
      await db.seed(
        groups: [seedGroup(id: 'g2', name: 'Other')],
        members: [seedMember('o1', groupId: 'g2')],
        expenses: [
          seedExpense('o-e', groupId: 'g2', total: 1, payers: {'o1': 1}, shares: {'o1': 1}),
        ],
      );
      await db.seed(
        expenses: [
          seedExpense('early', date: '2026-01-02', total: 1, payers: {'m1': 1}, shares: {'m1': 1}),
        ],
        payments: [seedPayment('p0', from: 'm1', to: 'm2', amount: 1, date: '2026-01-01')],
      );
      final x = (await repo.loadExport('g1'))!;
      expect(x.expenses.first.id, 'early');
      expect(x.expenses.map((e) => e.id), isNot(contains('o-e')));
      expect(x.payments.first.id, 'p0');
      expect(x.members.map((m) => m.id), isNot(contains('o1')));
    });

    // TC-22-01
    test('null for a group that is missing or deleted', () async {
      await db.seed(
        groups: [seedGroup(id: 'gone', deletedAt: '2026-11-02T00:00:00Z')],
      );
      expect(await repo.loadExport('nope'), isNull);
      expect(await repo.loadExport('gone'), isNull);
    });
  });

  group('csvOfExport', () {
    late String csv;
    late List<String> lines;

    setUp(() async {
      await seedAll();
      final x = (await repo.loadExport('g1'))!;
      csv = csvOfExport(x, categoryLabel: _label, myUserId: 'u1');
      lines = csv.split('\r\n');
    });

    String row(String text) => lines.firstWhere((l) => l.contains(text));

    // TC-22-01
    test('starts with the BOM and has one column per member, removed ones too', () {
      expect(csv.startsWith('﻿'), isTrue);
      expect(
        lines.first.substring(1),
        'Date,Description,Category,Currency,Amount,Paid by,Split type,'
        'Mohit,Asha,Ravi,Gone,Notes,Added by,Deleted',
      );
    });

    // TC-22-01
    test('the category label function is applied; Added by is the creator\'s member name', () {
      expect(
        row('Dinner'),
        '2026-11-18,Dinner,L:other.general,INR,300.00,Mohit,equal,'
        '200.00,-100.00,-100.00,0.00,,Asha,no',
      );
    });

    // TC-22-01
    test('a loan has split type "loan"', () {
      expect(row('Loan'), contains(',INR,50.00,Mohit,loan,'));
    });

    // TC-22-01
    test('an unsynced row (no creator, seq 0) is mine; a synced one with no creator is blank', () {
      expect(row('Loan'), endsWith(',Mohit,no'));
      expect(row('Mystery'), endsWith(',,,no'));
    });

    // TC-22-01
    test('a deleted row is flagged "yes" and left out of the totals', () {
      expect(row('Old taxi'), endsWith(',Mohit,yes'));
      final total = row('Total balance');
      // Mohit: Dinner +200, Loan +50, payment -20 = 230; the taxi (-10) is not counted.
      expect(total, contains(',INR,'));
      expect(total, contains('230.00'));
    });

    // TC-22-01
    test('a payment is a row with category Payment and its method', () {
      expect(
        row('Asha paid Mohit'),
        '2026-11-21,Asha paid Mohit,Payment,INR,20.00,Asha,payment (upi),'
        '-20.00,20.00,0.00,0.00,thanks,Asha,no',
      );
    });

    // TC-22-01
    test('without an account the unsynced row has no name', () async {
      final x = (await repo.loadExport('g1'))!;
      final text = csvOfExport(x, categoryLabel: _label);
      expect(text.split('\r\n').firstWhere((l) => l.contains('Loan')), endsWith(',,,no'));
    });
  });

  group('exportFileName', () {
    final day = DateTime(2026, 11, 22, 10);

    // TC-22-01
    test('lower-case ASCII words joined by dashes, then the local date', () {
      expect(exportFileName('Goa Trip!', day), 'splitify-goa-trip-2026-11-22.csv');
      expect(exportFileName('  Flat 4B -- Home ', day), 'splitify-flat-4b-home-2026-11-22.csv');
      expect(exportFileName('Cafe', DateTime(2026, 1, 5, 9)), 'splitify-cafe-2026-01-05.csv');
    });

    // TC-22-01
    test('a name with no ASCII letters or digits becomes "group"', () {
      expect(exportFileName('सैर सपाटा', day), 'splitify-group-2026-11-22.csv');
      expect(exportFileName('!!!', day), 'splitify-group-2026-11-22.csv');
    });

    // TC-22-01
    test('the name part stops at 40 characters, no dash left at the cut', () {
      expect(exportFileName('a' * 50, day), 'splitify-${'a' * 40}-2026-11-22.csv');
      expect(exportFileName('${'a' * 39} bbb', day), 'splitify-${'a' * 39}-2026-11-22.csv');
    });
  });

  group('GroupExporter', () {
    late ProviderContainer c;
    final shared = <({Uint8List bytes, String name, String subject})>[];

    setUp(() {
      shared.clear();
      c = ProviderContainer(
        overrides: [
          ledgerRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('u1'),
          clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 22, 10))),
          csvSharerProvider.overrideWithValue((bytes, name, subject) async {
            shared.add((bytes: bytes, name: name, subject: subject));
          }),
        ],
      );
    });

    tearDown(() => c.dispose());

    Future<ExportOutcome> run(String id) =>
        c.read(groupExporterProvider).export(id, categoryLabel: _label, subject: (n) => 'S:$n');

    // TC-22-01
    test('shares the UTF-8 file (BOM first) with its name and subject', () async {
      await seedAll();
      expect(await run('g1'), ExportOutcome.shared);
      final f = shared.single;
      expect(f.bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(f.name, 'splitify-goa-trip-2026-11-22.csv');
      expect(f.subject, 'S:Goa trip');
      final text = utf8.decode(f.bytes);
      expect(text.contains('Dinner'), isTrue);
      expect(text.contains('L:other.general'), isTrue);
      // Mine: the unsynced loan carries my name.
      expect(text.split('\r\n').firstWhere((l) => l.contains('Loan')), endsWith(',Mohit,no'));
    });

    // TC-22-01
    test('a group with only a payment still exports', () async {
      await db.seed(groups: [seedGroup()], members: _members(), payments: _payments());
      expect(await run('g1'), ExportOutcome.shared);
    });

    // TC-22-01
    test('an empty group shares nothing', () async {
      await db.seed(groups: [seedGroup()], members: _members());
      expect(await run('g1'), ExportOutcome.empty);
      expect(shared, isEmpty);
    });

    // TC-22-01
    test('a group that is not on this phone shares nothing', () async {
      expect(await run('nope'), ExportOutcome.notFound);
      expect(shared, isEmpty);
    });
  });
}
