// TC-D34D-01 (D-034 WP-D, P-4): "Download my data": the JSON's shape, integer amounts, the pending flag,
// deleted rows, the CSVs, the round trip into the same per-currency nets as the ledger, and a 500-row
// time budget.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/export_reads.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/export/application/backup_export.dart';

import '../../../support/fakes.dart' show testDb;
import '../../search/d034_seed.dart';
import '../zip_reader.dart';

String _label(String key) => 'cat:$key';

Map<String, Object?> _obj(Object? v) => v! as Map<String, Object?>;
List<Map<String, Object?>> _list(Object? v) => [
  for (final x in v! as List) x as Map<String, Object?>,
];

/// Per-currency nets of one backup group, worked out from the JSON alone (live rows only):
/// paid − owed for expenses (loans too), + amount for the payer and − for the receiver of payments.
Map<String, Map<String, int>> _netsFromJson(Map<String, Object?> g) {
  final out = <String, Map<String, int>>{};
  void add(String c, String m, int v) {
    final n = out.putIfAbsent(c, () => {});
    n[m] = (n[m] ?? 0) + v;
  }

  for (final e in _list(g['expenses'])) {
    if (e['deleted_at'] != null) continue;
    final c = e['currency']! as String;
    _obj(e['paid_by']).forEach((m, v) => add(c, m, v! as int));
    _obj(e['owed']).forEach((m, v) => add(c, m, -(v! as int)));
  }
  for (final p in _list(g['payments'])) {
    if (p['deleted_at'] != null) continue;
    final c = p['currency']! as String;
    add(c, p['from_member']! as String, p['amount']! as int);
    add(c, p['to_member']! as String, -(p['amount']! as int));
  }
  return {
    for (final c in out.entries)
      c.key: {
        for (final n in c.value.entries)
          if (n.value != 0) n.key: n.value,
      },
  };
}

/// Every value under a money key is an int (rule 1), anywhere in the tree.
void _expectIntegers(Object? node, [String path = r'$']) {
  const money = {'total', 'amount', 'paid_by', 'owed'};
  if (node is Map) {
    node.forEach((k, v) {
      final p = '$path.$k';
      if (money.contains(k) && v != null) {
        if (v is Map) {
          for (final x in v.values) {
            expect(x, isA<int>(), reason: p);
          }
        } else {
          expect(v, isA<int>(), reason: p);
        }
      }
      _expectIntegers(v, p);
    });
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      _expectIntegers(node[i], '$path[$i]');
    }
  }
}

void main() {
  late D034World w;

  setUp(() async => w = await seedD034());
  tearDown(() => w.dispose());

  Future<BackupFile> backup() async {
    final f = await w.container.read(backupExporterProvider).build(categoryLabel: _label);
    return f!;
  }

  Map<String, Object?> groupOf(Map<String, Object?> json, String id) =>
      _list(json['groups']).firstWhere((g) => _obj(g['group'])['id'] == id);

  // TC-D34D-01
  test('the zip holds the JSON, a README and one CSV per group with records', () async {
    final f = await backup();
    expect(f.fileName, 'splitify-backup-2026-11-21.zip');
    final texts = zipTexts(f.bytes);
    expect(texts.keys, ['splitify-backup.json', 'README.txt', 'csv/goa-trip.csv', 'csv/flat.csv']);
    expect(jsonDecode(texts['splitify-backup.json']!), f.json);
    expect(texts['README.txt'], contains('docs/backup-format.md'));
    // The CSV keeps its byte order mark for spreadsheet apps.
    final csv = readZip(f.bytes).firstWhere((e) => e.name == 'csv/goa-trip.csv').bytes;
    expect(csv.take(3), [0xEF, 0xBB, 0xBF]);
    expect(texts['csv/goa-trip.csv'], contains('Date,Description,Category'));
    expect(texts['csv/goa-trip.csv'], contains('Dinner at Thalassa'));
    expect(texts['csv/goa-trip.csv'], contains('cat:food.dining_out'));
    expect(texts['csv/flat.csv'], contains('Rent'));
  });

  // TC-D34D-01
  test('shape: format, version, me and every group with its rows', () async {
    final json = (await backup()).json;
    expect(json['format'], 'splitify-backup');
    expect(json['version'], 1);
    expect(json['exported_at'], DateTime(2026, 11, 21, 10).toUtc().toIso8601String());
    expect(DateTime.parse(json['exported_at']! as String).isUtc, isTrue);
    expect(_obj(json['me'])['user_id'], 'u1');
    final groups = _list(json['groups']);
    expect(groups.map((g) => _obj(g['group'])['name']), ['Goa trip', 'Flat']);
    final goa = groupOf(json, w.goa);
    expect(goa.keys, [
      'group',
      'me_member_id',
      'members',
      'expenses',
      'payments',
      'comments',
      'recurring',
    ]);
    expect(goa['me_member_id'], w.m['Mohit']);
    expect(_obj(goa['group'])['main_currency'], 'INR');
    expect(_list(goa['members']).map((m) => m['name']), ['Mohit', 'Asha', 'Ravi']);
    expect(_list(goa['expenses']).map((e) => e['id']), [
      'e-cab',
      'e-museum',
      'e-deleted',
      'e-dinner',
    ]);
    final dinner = _list(goa['expenses']).last;
    expect(dinner['total'], 240000);
    expect(dinner['currency'], 'INR');
    expect(dinner['paid_by'], {w.m['Mohit']: 240000});
    expect(dinner['owed'], {w.m['Mohit']: 80000, w.m['Asha']: 80000, w.m['Ravi']: 80000});
    expect(dinner['fx'], isNull);
    expect(_list(goa['payments']).map((p) => p['id']), ['p-gone', 'p-asha']);
    expect(_list(goa['comments']).map((c) => c['body']), [
      'Paid the tip in cash, 500 extra',
      'Thanks for the cab!',
      'Thanks for nothing',
    ]);
    _expectIntegers(json);
  });

  // TC-D34D-01
  test('deleted rows are kept with deleted_at; unsynced rows say pending', () async {
    var goa = groupOf((await backup()).json, w.goa);
    final deleted = _list(goa['expenses']).firstWhere((e) => e['id'] == 'e-deleted');
    expect(deleted['deleted_at'], isNotNull);
    expect(_list(goa['payments']).first['deleted_at'], isNotNull);
    expect(_list(goa['expenses']).every((e) => e['pending'] == true), isTrue);

    // The server took the dinner.
    await (w.db.update(w.db.expenses)..where((e) => e.id.equals('e-dinner'))).write(
      const ExpensesCompanion(syncState: Value(SyncState.synced)),
    );
    goa = groupOf((await backup()).json, w.goa);
    final rows = {for (final e in _list(goa['expenses'])) e['id']: e['pending']};
    expect(rows['e-dinner'], isFalse);
    expect(rows['e-cab'], isTrue);
  });

  // TC-D34D-01: round trip.
  test('the JSON gives exactly the per-currency nets of the ledger, every group', () async {
    final json = (await backup()).json;
    final ledgers = await w.container.read(ledgerRepositoryProvider).loadAll();
    expect(ledgers, hasLength(2));
    for (final l in ledgers) {
      final expected = {
        for (final c in groupBalancesOf(l, 'u1').byCurrency.entries)
          c.key: {
            for (final n in c.value.nets.entries)
              if (n.value != 0) n.key: n.value,
          },
      };
      final fromJson = _netsFromJson(groupOf(json, l.group.id));
      expect(fromJson, expected, reason: l.group.name);
      for (final nets in fromJson.values) {
        expect(nets.values.fold(0, (a, b) => a + b), 0);
      }
    }
    // Goa has INR and EUR, never mixed (rule 4).
    expect(_netsFromJson(groupOf(json, w.goa)).keys.toSet(), {'INR', 'EUR'});
  });

  // TC-D34D-01
  test('a saved conversion goes along as integers with its rate text', () async {
    await (w.db.update(w.db.expenses)..where((e) => e.id.equals('e-museum'))).write(
      ExpensesCompanion(
        fxCurrency: const Value('INR'),
        fxRate: const Value('90.5'),
        fxRateDate: const Value('2026-11-02'),
        fxSource: const Value('frankfurter'),
        fxTotal: const Value(271500),
        fxPayers: Value(jsonEncode({w.m['Ravi']: 271500})),
        fxShares: Value(jsonEncode({w.m['Ravi']: 90500, w.m['Mohit']: 90500, w.m['Asha']: 90500})),
      ),
    );
    final goa = groupOf((await backup()).json, w.goa);
    final fx = _obj(_list(goa['expenses']).firstWhere((e) => e['id'] == 'e-museum')['fx']);
    expect(fx, {
      'currency': 'INR',
      'rate': '90.5',
      'rate_date': '2026-11-02',
      'source': 'frankfurter',
      'total': 271500,
      'paid_by': {w.m['Ravi']: 271500},
      'owed': {w.m['Ravi']: 90500, w.m['Mohit']: 90500, w.m['Asha']: 90500},
    });
  });

  // TC-D34D-01
  test('a deleted group stays in the JSON but gets no CSV; same names get -2', () async {
    final other = await w.container
        .read(groupsRepositoryProvider)
        .create(name: 'Goa Trip!', ownerName: 'Mohit', ownerUserId: 'u1', mainCurrency: 'INR');
    final me = (await (w.db.select(
      w.db.groupMembers,
    )..where((m) => m.groupId.equals(other))).getSingle()).id;
    await w.container.read(expensesRepositoryProvider).save(other, {
      'kind': 'expense',
      'description': 'Chai',
      'category': 'food.snacks',
      'date': '2026-11-11',
      'currency': 'INR',
      'total': 4000,
      'payers': {me: 4000},
      'shares': {me: 4000},
      'split_kind': 'equal',
    }, id: 'e-other');
    await (w.db.update(w.db.groups)..where((x) => x.id.equals(w.flat))).write(
      const GroupsCompanion(deletedAt: Value('2026-11-20T10:00:00Z')),
    );
    final f = await backup();
    expect(zipTexts(f.bytes).keys, [
      'splitify-backup.json',
      'README.txt',
      'csv/goa-trip.csv',
      'csv/goa-trip-2.csv',
    ]);
    expect(_obj(groupOf(f.json, w.flat)['group'])['deleted_at'], isNotNull);
  });

  // TC-D34D-01
  test('nothing on the phone: no file', () async {
    final db = testDb();
    final c = ProviderContainer(overrides: d034Overrides(db, await d034Prefs()));
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    expect(await c.read(backupExporterProvider).build(categoryLabel: _label), isNull);
  });

  // TC-D34D-01
  test('counts for the sheet: live groups, expenses, payments and pending rows', () async {
    final counts = await w.container.read(ledgerRepositoryProvider).watchBackupCounts().first;
    expect(counts.groups, 2);
    expect(counts.expenses, 4);
    expect(counts.payments, 2);
    expect(counts.pending, greaterThan(10));
  });

  // TC-D34D-01: 500-row budget.
  test('500 expenses and payments are packed well within the time budget', () async {
    final payer = w.m['Mohit']!;
    final asha = w.m['Asha']!;
    await w.db.batch((b) {
      for (var i = 0; i < 400; i++) {
        b.insert(
          w.db.expenses,
          ExpensesCompanion.insert(
            id: 'bulk-e$i',
            groupId: w.goa,
            description: 'Bulk expense $i',
            date: '2026-0${1 + i % 9}-1${i % 9}',
            currency: 'INR',
            total: 1000 + i,
            payers: jsonEncode({payer: 1000 + i}),
            shares: jsonEncode({payer: 500 + i, asha: 500}),
          ),
        );
      }
      for (var i = 0; i < 100; i++) {
        b.insert(
          w.db.payments,
          PaymentsCompanion.insert(
            id: 'bulk-p$i',
            groupId: w.goa,
            fromMember: asha,
            toMember: payer,
            amount: 100 + i,
            currency: 'INR',
            date: '2026-05-0${1 + i % 9}',
          ),
        );
      }
    });
    final watch = Stopwatch()..start();
    final f = await backup();
    watch.stop();
    expect(_list(groupOf(f.json, w.goa)['expenses']), hasLength(404));
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });

  group('names', () {
    // TC-D34D-01
    test('CSV names are ASCII slugs, unique, never empty', () {
      final used = <String>{};
      expect(backupCsvName('Goa trip', used), 'csv/goa-trip.csv');
      expect(backupCsvName('GOA  trip', used), 'csv/goa-trip-2.csv');
      expect(backupCsvName('गोवा', used), 'csv/group.csv');
      expect(backupCsvName('', used), 'csv/group-2.csv');
      expect(backupCsvName('a' * 60, used), 'csv/${'a' * 40}.csv');
    });

    // TC-D34D-01
    test('the zip is named after the local day', () {
      expect(backupFileName(DateTime(2026, 1, 5, 23)), 'splitify-backup-2026-01-05.zip');
    });
  });

  // TC-D34D-01
  test('text that is not JSON stays text; odd money maps keep only integers', () {
    final json = backupJson(
      groups: [
        BackupGroupRows(
          group: LocalGroup(
            id: 'g',
            name: 'G',
            type: 'other',
            mainCurrency: 'INR',
            coverKind: 'generated',
            simplifyDebts: false,
            defaultSplit: 'not json',
            seq: 0,
            syncState: SyncState.synced,
          ),
          expenses: const [
            LocalExpense(
              id: 'e',
              groupId: 'g',
              kind: 'expense',
              description: 'x',
              category: 'other.general',
              date: '2026-11-01',
              currency: 'INR ',
              total: 100,
              payers: '{"m":100,"n":"1"}',
              shares: '[1]',
              splitKind: 'equal',
              source: 'app',
              seq: 3,
              syncState: SyncState.synced,
            ),
          ],
        ),
      ],
      exportedAt: DateTime.utc(2026, 11, 21),
    );
    final g = _list(json['groups']).single;
    expect(_obj(g['group'])['default_split'], 'not json');
    expect(_obj(g['group'])['pending'], isFalse);
    expect(g['me_member_id'], isNull);
    final e = _list(g['expenses']).single;
    expect(e['currency'], 'INR');
    expect(e['paid_by'], {'m': 100});
    expect(e['owed'], <String, int>{});
    expect(_obj(json['me'])['user_id'], isNull);
  });
}
