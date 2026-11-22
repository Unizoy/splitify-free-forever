// #34 offline search: the Search screen over the phone's own database (FTS index filled by the real
// repositories), its filters and states.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart' as editor;
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;
import 'package:splitify/features/search/presentation/search_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../data/sync/sync_fakes.dart' show FakeRemoteApi;
import '../../support/fakes.dart' show FakeClock, testDb;
import '../expenses/presentation/presentation_harness.dart' show settle, stubRoute, usePhone;

class _Env {
  _Env(this.db, this.container);

  final AppDatabase db;
  final ProviderContainer container;
  late String goa;
  late String flat;
  final members = <String, String>{};
}

Future<void> _settleReal(WidgetTester t, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await settle(t, 2);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await settle(t);
}

Future<void> _expense(
  _Env env,
  String groupId,
  String id, {
  required String description,
  required int total,
  required String date,
  required String category,
  required String payer,
  required List<String> among,
  String? notes,
}) async {
  final base = total ~/ among.length;
  final shares = {for (final m in among) env.members[m]!: base};
  shares[env.members[among.first]!] = base + total - base * among.length;
  await env.container.read(expensesRepositoryProvider).save(groupId, {
    'kind': 'expense',
    'description': description,
    'notes': notes,
    'category': category,
    'date': date,
    'currency': 'INR',
    'total': total,
    'payers': {env.members[payer]!: total},
    'shares': shares,
    'split_kind': 'equal',
    'split_values': null,
    'created_at': '2026-11-20T10:00:00Z',
  }, id: id);
}

Future<_Env> _seed(WidgetTester t) async {
  final db = testDb();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      remoteApiProvider.overrideWithValue(FakeRemoteApi()),
      clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 21, 10))),
      editor.currentUserIdProvider.overrideWithValue('u1'),
      groups.currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  final env = _Env(db, container);
  await t.runAsync(() async {
    final g = container.read(groupsRepositoryProvider);
    final m = container.read(membersRepositoryProvider);
    env.goa = await g.create(
      name: 'Goa trip',
      ownerName: 'Mohit',
      ownerUserId: 'u1',
      mainCurrency: 'INR',
    );
    env.flat = await g.create(
      name: 'Flat',
      ownerName: 'Mohit',
      ownerUserId: 'u1',
      mainCurrency: 'INR',
    );
    await m.addNameOnly(env.goa, 'Asha');
    await m.addNameOnly(env.goa, 'Ravi');
    await m.addNameOnly(env.flat, 'Kiran');
    for (final r in await db.select(db.groupMembers).get()) {
      final key = r.userId == 'u1'
          ? 'Mohit@${r.groupId == env.goa ? 'goa' : 'flat'}'
          : r.displayName;
      env.members[key] = r.id;
    }
    env.members['Mohit'] = env.members['Mohit@goa']!;
    Future<void> goa(
      String id,
      String d,
      int total,
      String date,
      String cat,
      String payer,
      List<String> among, {
      String? notes,
    }) => _expense(
      env,
      env.goa,
      id,
      description: d,
      total: total,
      date: date,
      category: cat,
      payer: payer,
      among: among,
      notes: notes,
    );
    await goa('g1', 'Dinner at Thalassa', 240000, '2026-11-20', 'food.dining_out', 'Mohit', [
      'Mohit',
      'Asha',
      'Ravi',
    ], notes: 'Table by the window');
    await goa('g2', 'Cab to airport', 120000, '2026-11-10', 'travel.cab_auto', 'Asha', [
      'Asha',
      'Mohit',
    ]);
    await goa('g3', 'Beach shack', 1800000, '2026-10-25', 'travel.hotel', 'Mohit', [
      'Mohit',
      'Asha',
      'Ravi',
    ]);
    // Flat: Mohit's member there is a different id.
    final flatMe = env.members['Mohit@flat']!;
    env.members['MohitFlat'] = flatMe;
    Future<void> flat(
      String id,
      String d,
      int total,
      String date,
      String cat,
      String payer,
      List<String> among,
    ) async {
      final base = total ~/ among.length;
      await container.read(expensesRepositoryProvider).save(env.flat, {
        'kind': 'expense',
        'description': d,
        'notes': null,
        'category': cat,
        'date': date,
        'currency': 'INR',
        'total': total,
        'payers': {payer: total},
        'shares': {for (final m in among) m: base},
        'split_kind': 'equal',
        'split_values': null,
        'created_at': '2026-11-20T10:00:00Z',
      }, id: id);
    }

    final kiran = env.members['Kiran']!;
    await flat('f1', 'Rent', 1500000, '2026-11-01', 'rent.rent', flatMe, [flatMe, kiran]);
    await flat('f2', 'Dinner party snacks', 75050, '2026-09-05', 'food.snacks', kiran, [
      kiran,
      flatMe,
    ]);
  });
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async {
      container.dispose();
      await db.close();
    });
  });
  return env;
}

Future<_Env> _pump(WidgetTester t, {String? group, double scale = 1}) async {
  usePhone(t);
  final env = await _seed(t);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-search'),
              onPressed: () =>
                  context.push(SearchRoutes.search(groupId: group == 'goa' ? env.goa : null)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      ...searchRoutes(),
      stubRoute('/expense/:id'),
    ],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: env.container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await settle(t, 2);
  await t.tap(find.byKey(const Key('open-search')));
  await _settleReal(t);
  return env;
}

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.byKey(const Key('search-field')), text);
  await _settleReal(t);
}

Future<void> _tap(WidgetTester t, String key, {int rounds = 4}) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await _settleReal(t, rounds);
}

String _count(WidgetTester t) => (t.widget<Text>(find.byKey(const Key('search-count')))).data!;

void main() {
  testWidgets('starts on the "find any expense" state with the four filter chips', (t) async {
    await _pump(t);
    expect(find.byKey(const Key('search-start')), findsOneWidget);
    expect(find.text('Find any expense'), findsOneWidget);
    for (final k in ['group', 'person', 'date', 'category']) {
      expect(find.byKey(Key('search-filter-$k')), findsOneWidget);
    }
    expect(find.text('All groups'), findsOneWidget);
    expect(find.text('Anyone'), findsOneWidget);
    expect(find.text('Any time'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.byKey(const Key('search-clear-filters')), findsNothing);
    expect(find.byKey(const Key('search-clear')), findsNothing);
    expect(find.byKey(const Key('search-results')), findsNothing);
  });

  testWidgets('typing finds expenses by description across groups, newest first', (t) async {
    await _pump(t);
    await _type(t, 'dinner');
    expect(find.byKey(const Key('search-results')), findsOneWidget);
    expect(_count(t), '2 expenses');
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('Dinner party snacks'), findsOneWidget);
    expect(find.text('Cab to airport'), findsNothing);
    // newest first, under month headers
    expect(find.text('NOVEMBER 2026'), findsOneWidget);
    expect(find.text('SEPTEMBER 2026'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('Dinner at Thalassa')).dy <
          t.getTopLeft(find.text('Dinner party snacks')).dy,
      isTrue,
    );
    // rows name their group when several groups are searched
    expect(find.textContaining('Goa trip'), findsOneWidget);
    expect(find.textContaining('Flat'), findsOneWidget);
  });

  testWidgets('finds by a word prefix, by note text and by amount', (t) async {
    await _pump(t);
    await _type(t, 'thal');
    expect(_count(t), '1 expense');
    expect(find.text('Dinner at Thalassa'), findsOneWidget);

    await _type(t, 'window');
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(_count(t), '1 expense');

    await _type(t, '1200');
    expect(find.text('Cab to airport'), findsOneWidget);
    expect(find.text('Dinner at Thalassa'), findsNothing);

    await _type(t, 'kiran');
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Dinner party snacks'), findsOneWidget);
  });

  testWidgets('no match shows the empty state without a clear-filters button', (t) async {
    await _pump(t);
    await _type(t, 'zzzz');
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    expect(find.text('No matches'), findsOneWidget);
    expect(find.byKey(const Key('search-empty-clear')), findsNothing);
    expect(find.byKey(const Key('search-count')), findsNothing);
  });

  testWidgets('with a filter set the empty state offers Clear filters', (t) async {
    await _pump(t);
    await _type(t, 'zzzz');
    await _tap(t, 'search-filter-group');
    await _tap(t, 'search-group-${(await _groupIds(t))['Flat']}', rounds: 6);
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    expect(find.byKey(const Key('search-empty-clear')), findsOneWidget);
    await _tap(t, 'search-empty-clear');
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    expect(find.byKey(const Key('search-empty-clear')), findsNothing);
    expect(find.byKey(const Key('search-clear-filters')), findsNothing);
    expect(find.text('All groups'), findsOneWidget);
  });

  testWidgets('the clear button empties the field and returns to the start state', (t) async {
    await _pump(t);
    await _type(t, 'cab');
    expect(find.byKey(const Key('search-clear')), findsOneWidget);
    await _tap(t, 'search-clear');
    expect(t.widget<TextField>(find.byKey(const Key('search-field'))).controller!.text, '');
    expect(find.byKey(const Key('search-start')), findsOneWidget);
    expect(find.byKey(const Key('search-clear')), findsNothing);
  });

  testWidgets('the group filter narrows the results; All groups lifts it', (t) async {
    final env = await _pump(t);
    await _type(t, 'dinner');
    await _tap(t, 'search-filter-group');
    expect(find.byKey(const Key('search-group-any')), findsOneWidget);
    expect(find.byKey(Key('search-group-${env.goa}')), findsOneWidget);
    expect(find.byKey(Key('search-group-${env.flat}')), findsOneWidget);
    await _tap(t, 'search-group-${env.flat}', rounds: 6);
    expect(find.text('Flat'), findsWidgets);
    expect(_count(t), '1 expense');
    expect(find.text('Dinner party snacks'), findsOneWidget);
    expect(find.byKey(const Key('search-clear-filters')), findsOneWidget);

    await _tap(t, 'search-filter-group');
    await _tap(t, 'search-group-any', rounds: 6);
    expect(_count(t), '2 expenses');
    expect(find.byKey(const Key('search-clear-filters')), findsNothing);
  });

  testWidgets('a filter alone (no text) lists everything it matches', (t) async {
    final env = await _pump(t);
    await _tap(t, 'search-filter-group');
    await _tap(t, 'search-group-${env.flat}', rounds: 6);
    expect(find.byKey(const Key('search-start')), findsNothing);
    expect(_count(t), '2 expenses');
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('opened from a group it starts filtered to that group', (t) async {
    await _pump(t, group: 'goa');
    expect(find.byKey(const Key('search-start')), findsNothing);
    expect(find.text('Goa trip'), findsOneWidget);
    expect(_count(t), '3 expenses');
    expect(find.text('Rent'), findsNothing);
  });

  testWidgets('the person filter lists everyone but me and narrows to their expenses', (t) async {
    final env = await _pump(t);
    await _tap(t, 'search-filter-person');
    expect(find.byKey(const Key('search-person-any')), findsOneWidget);
    expect(find.byKey(Key('search-person-m:${env.members['Kiran']}')), findsOneWidget);
    expect(find.byKey(Key('search-person-m:${env.members['Asha']}')), findsOneWidget);
    expect(find.byKey(Key('search-person-m:${env.members['Ravi']}')), findsOneWidget);
    expect(find.text('Mohit'), findsNothing);
    await _tap(t, 'search-person-m:${env.members['Kiran']}', rounds: 6);
    expect(find.text('Kiran'), findsOneWidget);
    expect(_count(t), '2 expenses');
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Dinner party snacks'), findsOneWidget);
  });

  testWidgets('the date filter presets use today (21 Nov 2026) and Any time clears them', (
    t,
  ) async {
    await _pump(t);
    await _tap(t, 'search-filter-date');
    for (final k in ['any', 'thisMonth', 'lastMonth', 'last3Months', 'thisYear', 'custom']) {
      expect(find.byKey(Key('search-date-$k')), findsOneWidget, reason: k);
    }
    await _tap(t, 'search-date-thisMonth', rounds: 6);
    expect(find.text('This month'), findsOneWidget);
    expect(_count(t), '3 expenses');
    expect(find.text('Beach shack'), findsNothing);

    await _tap(t, 'search-filter-date');
    await _tap(t, 'search-date-lastMonth', rounds: 6);
    expect(find.text('Last month'), findsOneWidget);
    expect(_count(t), '1 expense');
    expect(find.text('Beach shack'), findsOneWidget);

    await _tap(t, 'search-filter-date');
    await _tap(t, 'search-date-last3Months', rounds: 6);
    expect(_count(t), '5 expenses');

    await _tap(t, 'search-filter-date');
    await _tap(t, 'search-date-thisYear', rounds: 6);
    expect(_count(t), '5 expenses');

    await _tap(t, 'search-filter-date');
    await _tap(t, 'search-date-any', rounds: 6);
    expect(find.text('Any time'), findsOneWidget);
    expect(find.byKey(const Key('search-start')), findsOneWidget);
  });

  testWidgets('a custom date range is picked on two calendars', (t) async {
    await _pump(t);
    await _tap(t, 'search-filter-date');
    await _tap(t, 'search-date-custom', rounds: 10);
    expect(find.text('November 2026'), findsOneWidget);
    await t.tap(find.text('5'));
    await _settleReal(t, 8);
    await t.tap(find.text('15'));
    await _settleReal(t, 6);
    expect(find.text('5 Nov – 15 Nov'), findsOneWidget);
    expect(_count(t), '1 expense');
    expect(find.text('Cab to airport'), findsOneWidget);
  });

  testWidgets('the category filter uses the parent categories; Clear filters resets', (t) async {
    await _pump(t);
    await _tap(t, 'search-filter-category');
    expect(find.byKey(const Key('search-category-any')), findsOneWidget);
    await _tap(t, 'search-category-food', rounds: 6);
    expect(_count(t), '2 expenses');
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    expect(find.text('Dinner party snacks'), findsOneWidget);
    expect(find.byKey(const Key('search-clear-filters')), findsOneWidget);

    await _tap(t, 'search-filter-category');
    await _tap(t, 'search-category-travel', rounds: 6);
    expect(_count(t), '2 expenses');
    expect(find.text('Cab to airport'), findsOneWidget);
    expect(find.text('Beach shack'), findsOneWidget);

    await _tap(t, 'search-clear-filters');
    expect(find.byKey(const Key('search-start')), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
  });

  testWidgets('filters and text combine', (t) async {
    await _pump(t);
    await _type(t, 'dinner');
    await _tap(t, 'search-filter-category');
    await _tap(t, 'search-category-food', rounds: 6);
    expect(_count(t), '2 expenses');
    await _tap(t, 'search-filter-date');
    await _tap(t, 'search-date-thisMonth', rounds: 6);
    expect(_count(t), '1 expense');
    expect(find.text('Dinner at Thalassa'), findsOneWidget);
    // Clear filters keeps the typed text.
    await _tap(t, 'search-clear-filters');
    expect(_count(t), '2 expenses');
    expect(t.widget<TextField>(find.byKey(const Key('search-field'))).controller!.text, 'dinner');
  });

  testWidgets('tapping a result opens the expense', (t) async {
    await _pump(t);
    await _type(t, 'cab');
    await t.tap(find.byKey(const ValueKey('expense-g2')));
    await _settleReal(t);
    expect(find.text('at /expense/g2'), findsOneWidget);
  });

  testWidgets('the back button leaves the screen', (t) async {
    await _pump(t);
    await _tap(t, 'search-back');
    expect(find.byKey(const Key('search-field')), findsNothing);
    expect(find.byKey(const Key('open-search')), findsOneWidget);
  });

  testWidgets('no overflow at 200 % text scale (start, results, empty)', (t) async {
    await _pump(t, scale: 2);
    expect(find.byKey(const Key('search-start')), findsOneWidget);
    await _type(t, 'dinner');
    expect(find.byKey(const Key('search-results')), findsOneWidget);
    await _type(t, 'zzzz');
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

/// Group ids by name from the open screen's database.
Future<Map<String, String>> _groupIds(WidgetTester t) async {
  final c = ProviderScope.containerOf(t.element(find.byType(SearchScreen)));
  final db = c.read(appDatabaseProvider);
  final rows = await t.runAsync(() => db.select(db.groups).get());
  return {for (final g in rows!) g.name: g.id};
}
