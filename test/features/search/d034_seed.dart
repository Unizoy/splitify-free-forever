// D-034 WP-D test data: two groups on an in-memory database written through the real repositories
// (outbox, search index), with expenses, payments, comments, a deleted row and a second currency.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/history_repository.dart' show CommentWrites;
import 'package:splitify/features/expenses/application/expense_editor_controller.dart' as editor;
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;

import '../../data/sync/sync_fakes.dart' show FakeRemoteApi;
import '../../support/fakes.dart' show FakeClock, testDb;

/// The seeded world: ids by name.
class D034World {
  D034World(this.db, this.container);

  final AppDatabase db;
  final ProviderContainer container;
  late String goa;
  late String flat;

  /// Member ids: `Mohit` (Goa), `MohitFlat`, `Asha`, `Ravi`, `Kiran`.
  final m = <String, String>{};

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

/// Overrides every D-034 WP-D test needs around [db].
List<Override> d034Overrides(AppDatabase db, SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  appDatabaseProvider.overrideWithValue(db),
  remoteApiProvider.overrideWithValue(FakeRemoteApi()),
  clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 21, 10))),
  editor.currentUserIdProvider.overrideWithValue('u1'),
  groups.currentUserIdProvider.overrideWithValue('u1'),
];

Future<SharedPreferences> d034Prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Writes one equal-split expense ([among] by member key; leftover to the first, fixed order).
Future<void> d034Expense(
  D034World w,
  String groupId,
  String id, {
  required String description,
  required int total,
  required String date,
  required String payer,
  required List<String> among,
  String category = 'food.dining_out',
  String currency = 'INR',
  String? notes,
  String kind = 'expense',
}) async {
  final base = total ~/ among.length;
  final shares = {for (final k in among) w.m[k]!: base};
  shares[w.m[among.first]!] = base + total - base * among.length;
  await w.container.read(expensesRepositoryProvider).save(groupId, {
    'kind': kind,
    'description': description,
    'notes': notes,
    'category': category,
    'date': date,
    'currency': currency,
    'total': total,
    'payers': {w.m[payer]!: total},
    'shares': shares,
    'split_kind': 'equal',
    'split_values': null,
    'created_at': '${date}T10:00:00Z',
  }, id: id);
}

Future<void> d034Payment(
  D034World w,
  String groupId,
  String id, {
  required String from,
  required String to,
  required int amount,
  required String date,
  String currency = 'INR',
  String method = 'cash',
  String? note,
}) => w.container.read(paymentsRepositoryProvider).save(groupId, {
  'from_member': w.m[from],
  'to_member': w.m[to],
  'amount': amount,
  'currency': currency,
  'date': date,
  'method': method,
  'note': note,
  'created_at': '${date}T12:00:00Z',
}, id: id);

/// Goa trip (Mohit, Asha, Ravi) and Flat (Mohit, Kiran): expenses, payments, comments, one deleted
/// expense, one deleted payment and a EUR expense in Goa.
Future<D034World> seedD034([SharedPreferences? prefs]) async {
  final db = testDb();
  final p = prefs ?? await d034Prefs();
  final container = ProviderContainer(retry: (_, _) => null, overrides: d034Overrides(db, p));
  final w = D034World(db, container);
  final g = container.read(groupsRepositoryProvider);
  final mem = container.read(membersRepositoryProvider);
  w
    ..goa = await g.create(
      name: 'Goa trip',
      ownerName: 'Mohit',
      ownerUserId: 'u1',
      mainCurrency: 'INR',
    )
    ..flat = await g.create(
      name: 'Flat',
      ownerName: 'Mohit',
      ownerUserId: 'u1',
      mainCurrency: 'INR',
    );
  await mem.addNameOnly(w.goa, 'Asha');
  await mem.addNameOnly(w.goa, 'Ravi');
  await mem.addNameOnly(w.flat, 'Kiran');
  for (final r in await db.select(db.groupMembers).get()) {
    if (r.userId == 'u1') {
      w.m[r.groupId == w.goa ? 'Mohit' : 'MohitFlat'] = r.id;
    } else {
      w.m[r.displayName] = r.id;
    }
  }
  await d034Expense(
    w,
    w.goa,
    'e-dinner',
    description: 'Dinner at Thalassa',
    total: 240000,
    date: '2026-11-20',
    payer: 'Mohit',
    among: ['Mohit', 'Asha', 'Ravi'],
  );
  await d034Expense(
    w,
    w.goa,
    'e-cab',
    description: 'Cab to airport',
    total: 120000,
    date: '2026-10-10',
    payer: 'Asha',
    among: ['Asha', 'Mohit'],
    category: 'travel.cab_auto',
  );
  await d034Expense(
    w,
    w.goa,
    'e-museum',
    description: 'Museum tickets',
    total: 3000,
    date: '2026-11-02',
    payer: 'Ravi',
    among: ['Ravi', 'Mohit', 'Asha'],
    category: 'entertainment.events',
    currency: 'EUR',
  );
  await d034Expense(
    w,
    w.goa,
    'e-deleted',
    description: 'Deleted snack',
    total: 50000,
    date: '2026-11-03',
    payer: 'Mohit',
    among: ['Mohit', 'Asha'],
  );
  await container.read(expensesRepositoryProvider).delete('e-deleted', w.goa);
  await d034Expense(
    w,
    w.flat,
    'e-rent',
    description: 'Rent',
    total: 1500000,
    date: '2026-11-01',
    payer: 'MohitFlat',
    among: ['MohitFlat', 'Kiran'],
    category: 'rent.rent',
  );
  await d034Payment(
    w,
    w.goa,
    'p-asha',
    from: 'Asha',
    to: 'Mohit',
    amount: 50000,
    date: '2026-11-18',
  );
  await d034Payment(
    w,
    w.flat,
    'p-kiran',
    from: 'MohitFlat',
    to: 'Kiran',
    amount: 125050,
    date: '2026-11-05',
    method: 'upi',
    note: 'rent share',
  );
  await d034Payment(
    w,
    w.goa,
    'p-gone',
    from: 'Ravi',
    to: 'Mohit',
    amount: 70000,
    date: '2026-11-04',
  );
  await container.read(paymentsRepositoryProvider).delete('p-gone', w.goa);
  final comments = container.read(commentsRepositoryProvider);
  await comments.add(
    groupId: w.goa,
    targetType: 'expense',
    targetId: 'e-dinner',
    body: 'Paid the tip in cash, 500 extra',
    authorId: 'u1',
  );
  await comments.add(
    groupId: w.goa,
    targetType: 'payment',
    targetId: 'p-asha',
    body: 'Thanks for the cab!',
    authorId: 'u1',
  );
  await comments.add(
    groupId: w.goa,
    targetType: 'payment',
    targetId: 'p-gone',
    body: 'Thanks for nothing',
    authorId: 'u1',
  );
  return w;
}
