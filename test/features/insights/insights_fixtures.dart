// Phase 17 fixtures: ledgers for the Insights screen (TC-33-02 goldens, widget tests) and the CSV export.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';

import '../../support/ledger_seed.dart';

const goaId = 'g-goa';
const flatId = 'g-flat';
const emptyId = 'g-weekend';
const baliId = 'g-bali';
const friendId = 'g-direct';

/// Today in every Insights fixture (local date).
final insightsToday = DateTime(2026, 11, 22, 10);

/// [total] split over [ids], leftover units one each from the first (05 §3).
Map<String, int> splitEven(int total, List<String> ids) {
  final base = total ~/ ids.length;
  var left = total - base * ids.length;
  return {for (final id in ids) id: base + (left-- > 0 ? 1 : 0)};
}

/// A live expense in [groupId] paid by the first of [ids], shared evenly; optional saved conversion.
LocalExpense insightExpense(
  String id, {
  required String groupId,
  required List<String> ids,
  required String category,
  required String date,
  required int total,
  String currency = 'INR',
  String kind = 'expense',
  String description = 'Expense',
  String? fxCurrency,
  int? fxTotal,
  String? deletedAt,
  String? createdBy,
}) =>
    seedExpense(
      id,
      groupId: groupId,
      kind: kind,
      description: description,
      date: date,
      currency: currency,
      total: total,
      payers: {ids.first: total},
      shares: splitEven(total, ids),
      deletedAt: deletedAt,
      createdBy: createdBy,
    ).copyWith(
      category: category,
      fxCurrency: Value(fxCurrency),
      fxTotal: Value(fxTotal),
      fxRate: Value(fxTotal == null ? null : '83.9'),
      fxRateDate: Value(fxTotal == null ? null : date),
      fxSource: Value(fxTotal == null ? null : 'frankfurter'),
      fxPayers: Value(fxTotal == null ? null : jsonEncode({ids.first: fxTotal})),
      fxShares: Value(fxTotal == null ? null : jsonEncode(splitEven(fxTotal, ids))),
    );

const _goa = ['m1', 'm2', 'm3'];
const _flat = ['f1', 'f2'];

/// Goa trip (INR): seven categories over seven months, a loan (not spending), one USD expense with a
/// saved conversion and one without (left out, counted).
GroupLedger goaLedger() => GroupLedger(
  group: seedGroup(id: goaId),
  members: [
    seedMember('m1', groupId: goaId, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('m2', groupId: goaId, name: 'Asha Rao', userId: 'u2', position: 1),
    seedMember('m3', groupId: goaId, name: 'Rahul', position: 2),
  ],
  expenses: [
    insightExpense(
      'e1',
      groupId: goaId,
      ids: _goa,
      category: 'travel.flights',
      date: '2026-09-12',
      total: 1850000,
    ),
    insightExpense(
      'e2',
      groupId: goaId,
      ids: _goa,
      category: 'travel.hotel',
      date: '2026-10-03',
      total: 1240000,
    ),
    insightExpense(
      'e3',
      groupId: goaId,
      ids: _goa,
      category: 'food.dining_out',
      date: '2026-11-18',
      total: 320000,
    ),
    insightExpense(
      'e4',
      groupId: goaId,
      ids: _goa,
      category: 'food.takeaway',
      date: '2026-10-05',
      total: 245000,
    ),
    insightExpense(
      'e5',
      groupId: goaId,
      ids: _goa,
      category: 'food.snacks',
      date: '2026-07-21',
      total: 180000,
    ),
    insightExpense(
      'e6',
      groupId: goaId,
      ids: _goa,
      category: 'travel.cab_auto',
      date: '2026-11-19',
      total: 95000,
    ),
    insightExpense(
      'e7',
      groupId: goaId,
      ids: _goa,
      category: 'shopping.gifts',
      date: '2026-08-14',
      total: 460000,
    ),
    insightExpense(
      'e8',
      groupId: goaId,
      ids: _goa,
      category: 'entertainment.events',
      date: '2026-06-28',
      total: 200000,
    ),
    insightExpense(
      'e9',
      groupId: goaId,
      ids: _goa,
      category: 'groceries.groceries',
      date: '2026-11-20',
      total: 135000,
    ),
    insightExpense(
      'e10',
      groupId: goaId,
      ids: _goa,
      category: 'other.general',
      date: '2026-04-02',
      total: 60000,
    ),
    insightExpense(
      'e11',
      groupId: goaId,
      ids: _goa,
      category: 'entertainment.events',
      date: '2026-05-09',
      total: 12000,
      currency: 'USD',
      fxCurrency: 'INR',
      fxTotal: 1006800,
    ),
    insightExpense(
      'e12',
      groupId: goaId,
      ids: _goa,
      category: 'food.dining_out',
      date: '2026-11-21',
      total: 4500,
      currency: 'USD',
    ),
    insightExpense(
      'e13',
      groupId: goaId,
      ids: ['m1', 'm2'],
      category: 'other.general',
      date: '2026-11-02',
      total: 500000,
      kind: 'iou',
    ),
  ],
  payments: const [],
);

/// Flat 4B (home, INR): rent, power and groceries; I am `f1`.
GroupLedger flatLedger() => GroupLedger(
  group: seedGroup(id: flatId, name: 'Flat 4B', type: 'home', createdAt: '2026-08-01T10:00:00Z'),
  members: [
    seedMember('f1', groupId: flatId, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('f2', groupId: flatId, name: 'Neha', userId: 'u3', position: 1),
  ],
  expenses: [
    for (final (i, m) in const ['2026-09-01', '2026-10-01', '2026-11-01'].indexed)
      insightExpense(
        'r$i',
        groupId: flatId,
        ids: _flat,
        category: 'rent.rent',
        date: m,
        total: 2400000,
      ),
    insightExpense(
      'p1',
      groupId: flatId,
      ids: _flat,
      category: 'utilities.electricity',
      date: '2026-10-11',
      total: 180000,
    ),
    insightExpense(
      'p2',
      groupId: flatId,
      ids: _flat,
      category: 'groceries.household',
      date: '2026-11-09',
      total: 220000,
    ),
  ],
  payments: const [],
);

/// A friend (direct) group: counts in Me across everything, never in the picker.
GroupLedger friendLedger() => GroupLedger(
  group: seedGroup(id: friendId, name: 'Neha', type: 'direct'),
  members: [
    seedMember('d1', groupId: friendId, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('d2', groupId: friendId, name: 'Neha', userId: 'u3', position: 1),
  ],
  expenses: [
    insightExpense(
      'd-e1',
      groupId: friendId,
      ids: ['d1', 'd2'],
      category: 'entertainment.movies',
      date: '2026-11-15',
      total: 90000,
    ),
  ],
  payments: const [],
);

/// A group with nothing in it yet.
GroupLedger emptyLedger() => GroupLedger(
  group: seedGroup(id: emptyId, name: 'Weekend', type: 'other', createdAt: '2026-11-20T10:00:00Z'),
  members: [seedMember('w1', groupId: emptyId, name: 'Mohit Bindal', userId: 'u1')],
  expenses: const [],
  payments: const [],
);

/// Bali (INR) with only USD expenses and no saved conversions: nothing to draw yet.
GroupLedger baliLedger() => GroupLedger(
  group: seedGroup(id: baliId, name: 'Bali', archivedAt: '2026-11-10T10:00:00Z'),
  members: [
    seedMember('b1', groupId: baliId, name: 'Mohit Bindal', userId: 'u1'),
    seedMember('b2', groupId: baliId, name: 'Asha Rao', userId: 'u2', position: 1),
  ],
  expenses: [
    insightExpense(
      'b-e1',
      groupId: baliId,
      ids: ['b1', 'b2'],
      category: 'travel.hotel',
      date: '2026-11-04',
      total: 32000,
      currency: 'USD',
    ),
    insightExpense(
      'b-e2',
      groupId: baliId,
      ids: ['b1', 'b2'],
      category: 'food.dining_out',
      date: '2026-11-05',
      total: 5400,
      currency: 'USD',
    ),
  ],
  payments: const [],
);

List<GroupLedger> allInsightLedgers() => [
  goaLedger(),
  flatLedger(),
  friendLedger(),
  emptyLedger(),
  baliLedger(),
];

/// Feeds the Insights screen from [ledgers] through the real mapping (signed in as `u1`, INR).
List<Override> insightsOverrides(List<GroupLedger> ledgers) => [
  insightsProvider.overrideWith(
    (ref, q) => AsyncData(
      insightsViewOf(ledgers, q, userId: 'u1', defaultCurrency: 'INR', today: insightsToday),
    ),
  ),
];
