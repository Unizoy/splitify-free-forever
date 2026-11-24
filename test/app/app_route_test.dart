import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/account/presentation/about_screen.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/groups/presentation/groups_home_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/painters/cover_cache.dart' show CoverCacheOff;
import 'package:splitify/ui/theme/theme.dart';

import '../support/fakes.dart';
import '../support/group_fakes.dart';
import '../support/group_harness.dart';

Iterable<RouteBase> _all(List<RouteBase> routes) sync* {
  for (final r in routes) {
    yield r;
    yield* _all(r.routes);
  }
}

void main() {
  // S-288: go_router 18 would make plain `builder:` routes NoTransitionPages (it looks for material_ui's
  // MaterialApp); every route must be an AppRoute (a Flutter MaterialPage with the theme's transitions).
  test('every GoRoute in the app router is an AppRoute with a page builder', () {
    final router = buildRouter();
    addTearDown(router.dispose);
    final offenders = [
      for (final r in _all(router.configuration.routes))
        if (r is GoRoute && !r.redirectOnly && (r is! AppRoute || r.pageBuilder == null)) r.path,
    ];
    expect(offenders, isEmpty);
    final shells = _all(router.configuration.routes).whereType<StatefulShellRoute>();
    expect(
      shells.every((s) => s.pageBuilder != null),
      isTrue,
      reason: 'the tab shell is a page too',
    );
  });

  Future<GoRouter> pump(WidgetTester tester, {bool reduced = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = buildRouter(initialLocation: Routes.groups);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(user: const AuthUser(id: 'u1')),
          ),
          profileRemoteProvider.overrideWithValue(FakeProfileRemote(sampleProfile)),
          syncRepositoryProvider.overrideWithValue(
            FakeSyncRepository(status: const SyncStatus(phase: SyncPhase.idle)),
          ),
          ...emptyGroupsOverrides(),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return router;
  }

  testWidgets(
    'a push slides in on the shared axis (280 ms) over the tabs, and pops back (240 ms)',
    (tester) async {
      final router = await pump(tester);
      // The tab shell's page (Groups lives in a branch navigator inside it).
      final route = ModalRoute.of(
        tester
            .element(find.byType(GroupsHomeScreen))
            .findAncestorStateOfType<NavigatorState>()!
            .context,
      )!;
      expect(
        route,
        isA<MaterialRouteTransitionMixin<void>>(),
        reason: 'a Flutter MaterialPage route',
      );

      router.push(Routes.about);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final about = ModalRoute.of(tester.element(find.byType(AboutScreen)))!;
      expect(about.transitionDuration, const Duration(milliseconds: 280));
      expect(about.reverseTransitionDuration, const Duration(milliseconds: 240));
      expect(about.animation!.status, AnimationStatus.forward, reason: 'still moving at 100 ms');
      expect(
        find.ancestor(of: find.byType(AboutScreen), matching: find.byType(SharedAxisTransition)),
        findsOneWidget,
      );
      // The tabs underneath shift along with it (secondary animation).
      expect(route.secondaryAnimation!.value, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(about.animation!.status, AnimationStatus.completed);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AboutScreen), findsOneWidget, reason: 'still leaving at 100 ms');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AboutScreen), findsNothing);
    },
  );

  testWidgets('removed animations: the page is simply there, with no transition widget', (
    tester,
  ) async {
    final router = await pump(tester, reduced: true);
    router.push(Routes.about);
    await tester.pump();
    await tester.pump();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(AboutScreen), matching: find.byType(SharedAxisTransition)),
      findsNothing,
    );
  });

  testWidgets('the group card flies into the group page (Hero over the 280 ms push)', (
    tester,
  ) async {
    final h = await pumpGroups(
      tester,
      '/groups',
      overrides: fixedGroupData(
        groups: [sampleGroup(id: 'g1', name: 'Goa trip')],
      ),
    );
    await tester.tap(find.byKey(const Key('group-card-g1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-flight the cover shuttle (coverHeroShuttle) is on screen.
    expect(find.byType(CoverCacheOff), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CoverCacheOff), findsNothing);
    expect(h.location, '/groups/g1');
  });
}
