import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/app/shell/app_shell.dart';
import 'package:splitify/features/account/presentation/account_screen.dart';
import 'package:splitify/features/account/presentation/appearance_screen.dart';
import 'package:splitify/features/activity/presentation/activity_screen.dart';
import 'package:splitify/features/debug/presentation/gallery_screen.dart';
import 'package:splitify/features/friends/presentation/friends_screen.dart';
import 'package:splitify/features/groups/presentation/groups_home_screen.dart';
import 'package:splitify/features/onboarding/presentation/welcome_screen.dart';

/// Route paths (planning/07-screens-and-flows.md §1).
abstract final class Routes {
  static const welcome = '/welcome';
  static const groups = '/groups';
  static const friends = '/friends';
  static const activity = '/activity';
  static const account = '/account';
  static const appearance = '/account/appearance';
  static const gallery = '/debug/gallery';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Builds the app router. [initialLocation] is for tests.
GoRouter buildRouter({String initialLocation = Routes.welcome}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: Routes.welcome, builder: (context, state) => const WelcomeScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.groups, builder: (context, state) => const GroupsHomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.friends, builder: (context, state) => const FriendsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: Routes.activity, builder: (context, state) => const ActivityScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.account,
              builder: (context, state) => const AccountScreen(),
              routes: [
                GoRoute(
                  path: 'appearance',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const AppearanceScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    if (kDebugMode)
      GoRoute(path: Routes.gallery, builder: (context, state) => const GalleryScreen()),
  ],
);

/// App router, one per app run.
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});
