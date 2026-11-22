// TC-33-02: how Insights is reached (route query, Account "Your spending" card).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_routes.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';

import '../../../support/group_harness.dart';
import '../../expenses/presentation/presentation_harness.dart' as ph;
import '../insights_fixtures.dart';

void main() {
  group('InsightsRoutes', () {
    // TC-33-02
    test('group(id) builds /insights?mode=group&group=<id> and escapes the id', () {
      expect(InsightsRoutes.group('g1'), '/insights?mode=group&group=g1');
      expect(InsightsRoutes.group('a b&c'), '/insights?mode=group&group=a+b%26c');
      expect(InsightsRoutes.me, '/insights?mode=me');
    });

    // TC-33-02
    testWidgets('the route reads mode and group from the query', (t) async {
      ph.usePhone(t);
      final router = GoRouter(
        initialLocation: '/insights?mode=me&group=$flatId',
        routes: insightsRoutes(),
      );
      addTearDown(router.dispose);
      await t.pumpWidget(ph.routerApp(router, overrides: insightsOverrides(allInsightLedgers())));
      await ph.settle(t);
      var s = t.widget<InsightsScreen>(find.byType(InsightsScreen));
      expect((s.mode, s.groupId), (InsightsMode.me, flatId));

      router.go('/insights?mode=group&group=$goaId');
      await ph.settle(t);
      s = t.widget<InsightsScreen>(find.byType(InsightsScreen));
      expect((s.mode, s.groupId), (InsightsMode.group, goaId));

      router.go('/insights');
      await ph.settle(t);
      s = t.widget<InsightsScreen>(find.byType(InsightsScreen));
      expect((s.mode, s.groupId), (InsightsMode.group, null));
    });
  });

  group('Account', () {
    // TC-33-02
    testWidgets('the "Your spending" card opens Insights in Me mode', (t) async {
      final h = await pumpGroups(
        t,
        '/account',
        overrides: [...fixedGroupData(), ...insightsOverrides(allInsightLedgers())],
      );
      final card = find.byKey(const Key('account-spending'));
      expect(card, findsOneWidget);
      await t.tap(card);
      await settle(t);
      expect(h.location, '/insights?mode=me');
      final s = t.widget<InsightsScreen>(find.byType(InsightsScreen));
      expect(s.mode, InsightsMode.me);
      expect(s.groupId, isNull);
      expect(find.text('Your share everywhere'), findsOneWidget);
    });
  });
}
