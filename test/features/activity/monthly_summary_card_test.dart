// F14 (W2-Y, S-434): the monthly summary card on Activity — its lines (owed / owe / settled / two currencies),
// the tap to Insights, "Hide until next month", and where it sits on the Activity tab.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/application/monthly_summary.dart';
import 'package:splitify/features/activity/presentation/activity_screen.dart';
import 'package:splitify/features/activity/presentation/monthly_summary_card.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/ui/components/components.dart';

import '../expenses/presentation/presentation_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

/// Last month (October 2026) as the card shows it on 1 Nov.
MonthSummary _summary({
  Map<String, int> spent = const {'INR': 425000},
  int groups = 2,
  Map<String, int> balances = const {'INR': 120000},
  bool unsynced = false,
}) => MonthSummary(
  month: DateTime(2026, 10),
  spent: spent,
  groups: groups,
  balances: balances,
  unsynced: unsynced,
);

/// [home] at '/', with stubs for the places the card and the tab open.
Future<GoRouter> _pump(
  WidgetTester t,
  Widget home, {
  List<Override> overrides = const [],
  double scale = 1,
  Size size = const Size(412, 915),
}) async {
  usePhone(t);
  t.view.physicalSize = size;
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(const SizedBox());
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      stubRoute('/insights'),
      stubRoute('/notifications'),
      stubRoute('/search'),
    ],
  );
  await t.pumpWidget(routerApp(router, overrides: overrides));
  await settle(t);
  return router;
}

Widget _card(MonthSummary s) => Scaffold(
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: MonthlySummaryCard(summary: s),
    ),
  ),
);

/// The card as production wires it: gone once its month is hidden.
Override _summaryProvider(MonthSummary? s) => monthSummaryProvider.overrideWith(
  (ref) => s == null || ref.watch(hiddenMonthSummaryProvider) == s.key ? null : s,
);

List<Override> _activity({MonthSummary? summary}) => [
  activityItemsProvider(null).overrideWithValue(const AsyncData([])),
  unreadNotificationsProvider.overrideWith((ref) => Stream.value(0)),
  _summaryProvider(summary),
];

ProviderContainer _container(WidgetTester t, Finder inside) =>
    ProviderScope.containerOf(t.element(inside));

void main() {
  group('lines', () {
    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('owed: title, what was spent across how many groups, and what I am owed', (
      t,
    ) async {
      await _pump(t, _card(_summary()));
      expect(find.text('Your October'), findsOneWidget);
      expect(find.text('You spent ₹4,250 across 2 groups'), findsOneWidget);
      expect(find.text("You're owed ₹1,200"), findsOneWidget);
      expect(find.textContaining('You owe'), findsNothing);
      expect(find.text('See insights'), findsOneWidget);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('owe: "You owe" and no "owed" line; one group is singular', (t) async {
      await _pump(t, _card(_summary(groups: 1, balances: const {'INR': -50000})));
      expect(find.text('You spent ₹4,250 across 1 group'), findsOneWidget);
      expect(find.text('You owe ₹500'), findsOneWidget);
      expect(find.textContaining("You're owed"), findsNothing);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('settled: says all settled up', (t) async {
      await _pump(t, _card(_summary(balances: const {})));
      expect(find.text("You're all settled up"), findsOneWidget);
      expect(find.textContaining('You owe'), findsNothing);
      expect(find.textContaining("You're owed"), findsNothing);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('two currencies stay apart: rupees first, owed and owe lines per sign', (t) async {
      await _pump(
        t,
        _card(
          _summary(
            spent: const {'USD': 2000, 'INR': 425000},
            groups: 3,
            balances: const {'INR': 120000, 'USD': -500},
          ),
        ),
      );
      expect(find.text(r'You spent ₹4,250 + $20 across 3 groups'), findsOneWidget);
      expect(find.text("You're owed ₹1,200"), findsOneWidget);
      expect(find.text(r'You owe $5'), findsOneWidget);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('unsynced balances carry the "not synced yet" marker', (t) async {
      await _pump(t, _card(_summary()));
      expect(find.byType(SyncMarker), findsNothing);
      await _pump(t, _card(_summary(unsynced: true)));
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('a screen reader hears the title, the lines and where it goes as one button', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await _pump(t, _card(_summary()));
      expect(
        find.bySemanticsLabel(
          'Your October. You spent ₹4,250 across 2 groups. You\'re owed ₹1,200. See insights',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('large text on a small phone does not overflow', (t) async {
      await _pump(
        t,
        _card(
          _summary(
            spent: const {'USD': 2000, 'INR': 425000},
            groups: 3,
            balances: const {'INR': 120000, 'USD': -500},
            unsynced: true,
          ),
        ),
        scale: 2,
        size: const Size(320, 568),
      );
      expect(t.takeException(), isNull);
      expect(_key('month-summary'), findsOneWidget);
    });
  });

  group('actions', () {
    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('a tap opens Insights for me', (t) async {
      await _pump(t, _card(_summary()));
      await t.tap(_key('month-summary-open'));
      await settle(t);
      expect(find.text('at /insights?mode=me'), findsOneWidget);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('× hides this month: the notifier remembers it', (t) async {
      await _pump(t, _card(_summary()));
      expect(_container(t, _key('month-summary')).read(hiddenMonthSummaryProvider), isNull);
      await t.tap(_key('month-summary-hide'));
      await settle(t);
      expect(_container(t, _key('month-summary')).read(hiddenMonthSummaryProvider), '2026-10');
      // The × does not also open Insights.
      expect(find.text('at /insights?mode=me'), findsNothing);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('× also saves the choice on the phone', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await _pump(
        t,
        _card(_summary()),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      await t.tap(_key('month-summary-hide'));
      await settle(t);
      expect(prefs.getString('w2y.monthSummaryHidden'), '2026-10');
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('a month hidden earlier stays hidden; the next month shows again', (t) async {
      SharedPreferences.setMockInitialValues({'w2y.monthSummaryHidden': '2026-10'});
      final prefs = await SharedPreferences.getInstance();
      await _pump(
        t,
        _card(_summary()),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(_container(t, _key('month-summary')).read(hiddenMonthSummaryProvider), '2026-10');
      expect(
        _container(t, _key('month-summary')).read(hiddenMonthSummaryProvider) == _summary().key,
        isTrue,
      );
      expect(
        _container(t, _key('month-summary')).read(hiddenMonthSummaryProvider) ==
            MonthSummary(
              month: DateTime(2026, 11),
              spent: const {'INR': 100},
              groups: 1,
              balances: const {},
            ).key,
        isFalse,
      );
    });
  });

  group('on the Activity tab', () {
    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('shows at the top, above the filters, when there is a summary', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _activity(summary: _summary()));
      expect(_key('month-summary'), findsOneWidget);
      expect(find.text('Your October'), findsOneWidget);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets(
      'is not there when there is no summary (later in the month, nothing spent, hidden)',
      (t) async {
        await _pump(t, const ActivityScreen(), overrides: _activity());
        expect(_key('month-summary'), findsNothing);
        expect(find.text('No activity yet'), findsOneWidget);
      },
    );

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('is not there while the ledgers have not loaded (no override at all)', (t) async {
      await _pump(
        t,
        const ActivityScreen(),
        overrides: [
          activityItemsProvider(null).overrideWithValue(const AsyncData([])),
          unreadNotificationsProvider.overrideWith((ref) => Stream.value(0)),
        ],
      );
      expect(_key('month-summary'), findsNothing);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('× on the tab hides the card at once', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _activity(summary: _summary()));
      await t.tap(_key('month-summary-hide'));
      await settle(t);
      expect(_key('month-summary'), findsNothing);
    });

    // W2-Y F14 (no TC id yet; TC-29 UI family)
    testWidgets('a tap on the tab opens Insights', (t) async {
      await _pump(t, const ActivityScreen(), overrides: _activity(summary: _summary()));
      await t.tap(_key('month-summary-open'));
      await settle(t);
      expect(find.text('at /insights?mode=me'), findsOneWidget);
    });
  });
}
