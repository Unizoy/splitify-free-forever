// TC-D34D-02 (D-034 WP-D, P-5): the search screen with payments and comments: result-type chips with
// counts, payment and comment rows that open their record, "Search in Goa trip", recent searches.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/features/search/application/search_everything.dart';
import 'package:splitify/features/search/presentation/search_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../expenses/presentation/presentation_harness.dart' show settle, stubRoute, usePhone;
import 'd034_seed.dart';

Future<void> _real(WidgetTester t, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await settle(t, 2);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  }
  await settle(t);
}

Future<D034World> _pump(
  WidgetTester t, {
  bool group = false,
  Map<String, Object> prefs = const {},
}) async {
  usePhone(t);
  final p = (await t.runAsync(() => d034Prefs(prefs)))!;
  final w = (await t.runAsync(() => seedD034(p)))!;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(w.dispose);
  });
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-search'),
              onPressed: () => context.push(SearchRoutes.search(groupId: group ? w.goa : null)),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      ...searchRoutes(),
      stubRoute('/expense/:id'),
      stubRoute('/payment/:id'),
    ],
  );
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: w.container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
      ),
    ),
  );
  await settle(t, 2);
  await t.tap(find.byKey(const Key('open-search')));
  await _real(t);
  return w;
}

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.byKey(const Key('search-field')), text);
  await _real(t);
}

String _count(WidgetTester t) => t.widget<Text>(find.byKey(const Key('search-count'))).data!;

String _chip(WidgetTester t, String kind) =>
    t.widget<IconChip>(find.byKey(Key('search-kind-$kind'))).label;

void main() {
  // TC-D34D-02
  testWidgets('a number finds the payment and the comment; type chips with counts filter', (
    t,
  ) async {
    await _pump(t);
    await _type(t, '500');
    expect(_count(t), '2 results');
    expect(_chip(t, 'all'), 'All\u00A0· 2');
    expect(_chip(t, 'payments'), 'Payments\u00A0· 1');
    expect(_chip(t, 'comments'), 'Comments\u00A0· 1');
    expect(find.byKey(const Key('search-kind-expenses')), findsNothing);
    expect(find.text('Asha paid you'), findsOneWidget);
    expect(find.textContaining('Payment\u00A0· 18\u00A0Nov\u00A0· Goa\u00A0trip'), findsOneWidget);
    expect(find.text('“Paid the tip in cash, 500 extra”'), findsOneWidget);
    expect(find.textContaining('Mohit on Dinner at Thalassa'), findsOneWidget);

    await t.tap(find.byKey(const Key('search-kind-payments')));
    await _real(t);
    expect(_count(t), '1 result');
    expect(find.text('Asha paid you'), findsOneWidget);
    expect(find.textContaining('Paid the tip'), findsNothing);
    expect(t.widget<IconChip>(find.byKey(const Key('search-kind-payments'))).selected, isTrue);

    await t.tap(find.byKey(const Key('search-kind-all')));
    await _real(t);
    expect(_count(t), '2 results');
  });

  // TC-D34D-02
  testWidgets('one kind only: no chips; rows open the payment and the expense', (t) async {
    await _pump(t);
    await _type(t, 'upi');
    expect(find.byKey(const Key('search-kinds')), findsNothing);
    expect(find.text('You paid Kiran'), findsOneWidget);
    expect(find.text('₹1,250.50'), findsOneWidget);
    await t.tap(find.text('You paid Kiran'));
    await _real(t);
    expect(find.text('at /payment/p-kiran'), findsOneWidget);
  });

  // TC-D34D-02
  testWidgets('a comment row opens the expense it is on', (t) async {
    await _pump(t);
    await _type(t, 'tip');
    await t.tap(find.textContaining('Paid the tip'));
    await _real(t);
    expect(find.text('at /expense/e-dinner'), findsOneWidget);
  });

  // TC-D34D-02, TC-34-05
  testWidgets('opened from a group: "Search in Goa trip", the group chip set, only Goa', (t) async {
    await _pump(t, group: true);
    final field = t.widget<TextField>(find.byKey(const Key('search-field')));
    expect(field.decoration!.hintText, 'Search in Goa trip');
    expect(t.widget<IconChip>(find.byKey(const Key('search-filter-group'))).label, 'Goa trip');
    expect(t.widget<IconChip>(find.byKey(const Key('search-filter-group'))).selected, isTrue);
    await _type(t, 'paid');
    // Asha's payment and the comment that says "Paid".
    expect(_count(t), '2 results in Goa trip');
    expect(find.text('You paid Kiran'), findsNothing);
    expect(find.text('Asha paid you'), findsOneWidget);
  });

  // TC-D34D-02
  testWidgets('recent searches: kept on submit, tap to search again, remove one, clear', (t) async {
    final w = await _pump(t);
    expect(find.byKey(const Key('search-recent')), findsNothing);
    await _type(t, 'cab');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await _real(t);
    await _type(t, 'kiran');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await _real(t);
    await t.tap(find.byKey(const Key('search-clear')));
    await _real(t);
    expect(find.byKey(const Key('search-recent')), findsOneWidget);
    expect(find.text('RECENT SEARCHES'), findsOneWidget);
    expect(w.container.read(recentSearchesProvider), ['kiran', 'cab']);

    await t.tap(find.byKey(const Key('search-recent-1')));
    await _real(t);
    expect(t.widget<TextField>(find.byKey(const Key('search-field'))).controller!.text, 'cab');
    expect(find.text('Cab to airport'), findsOneWidget);
    expect(w.container.read(recentSearchesProvider), ['cab', 'kiran']);

    await t.tap(find.byKey(const Key('search-clear')));
    await _real(t);
    await t.tap(find.byKey(const Key('search-recent-remove-1')));
    await _real(t);
    expect(w.container.read(recentSearchesProvider), ['cab']);
    await t.tap(find.byKey(const Key('search-recent-clear')));
    await _real(t);
    expect(find.byKey(const Key('search-recent')), findsNothing);
    expect(
      (await t.runAsync(SharedPreferences.getInstance))!.getStringList(RecentSearches.storageKey),
      isEmpty,
    );
  });

  // TC-D34D-02
  testWidgets('leaving the field with text keeps it too; saved ones show on a new visit', (
    t,
  ) async {
    final w = await _pump(
      t,
      prefs: {
        RecentSearches.storageKey: <String>['rent'],
      },
    );
    expect(find.text('rent'), findsOneWidget);
    await _type(t, 'museum');
    FocusManager.instance.primaryFocus?.unfocus();
    await _real(t);
    expect(w.container.read(recentSearchesProvider), ['museum', 'rent']);
  });
}
