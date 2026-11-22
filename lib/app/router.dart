import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/app/shell/app_shell.dart';
import 'package:splitify/features/account/presentation/account_screen.dart';
import 'package:splitify/features/account/presentation/appearance_screen.dart';
import 'package:splitify/features/account/presentation/delete_account_screen.dart';
import 'package:splitify/features/account/presentation/profile_edit_screen.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/auth/presentation/code_screen.dart';
import 'package:splitify/features/auth/presentation/dev_login_screen.dart';
import 'package:splitify/features/auth/presentation/profile_confirm_screen.dart';
import 'package:splitify/features/auth/presentation/sign_in_screen.dart';
import 'package:splitify/features/activity/presentation/activity_screen.dart';
import 'package:splitify/features/app_lock/presentation/security_routes.dart';
import 'package:splitify/features/debug/presentation/gallery_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/friends/presentation/friends_screen.dart';
import 'package:splitify/features/groups/presentation/deleted_groups_screen.dart';
import 'package:splitify/features/groups/presentation/group_detail_screen.dart';
import 'package:splitify/features/groups/presentation/group_form_screen.dart';
import 'package:splitify/features/groups/presentation/group_settings_screen.dart';
import 'package:splitify/features/groups/presentation/groups_home_screen.dart';
import 'package:splitify/features/groups/presentation/join_screen.dart';
import 'package:splitify/features/history/presentation/history_routes.dart';
import 'package:splitify/features/import_splitwise/presentation/import_routes.dart';
import 'package:splitify/features/insights/presentation/insights_routes.dart';
import 'package:splitify/features/notifications/presentation/notifications_binding.dart';
import 'package:splitify/features/onboarding/presentation/welcome_screen.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/features/sync/presentation/sync_storage_screen.dart';
import 'package:splitify/features/search/presentation/search_screen.dart' show searchRoutes;

/// Route paths (planning/07-screens-and-flows.md §1).
abstract final class Routes {
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const signInCode = '/sign-in/code';
  static const signInProfile = '/sign-in/profile';
  static const groups = '/groups';
  static const newGroup = '/groups/new';
  static const join = '/join';
  static const deletedGroups = '/account/deleted-groups';
  static const friends = '/friends';
  static const activity = '/activity';
  static const account = '/account';
  static const appearance = '/account/appearance';
  static const profile = '/account/profile';
  static const deleteAccount = '/account/delete';
  static const syncStorage = '/account/sync';
  static const gallery = '/debug/gallery';

  static String group(String id) => '/groups/$id';
  static String groupSettings(String id) => '/groups/$id/settings';
  static String editGroup(String id) => '/groups/$id/edit';
  static const devLogin = '/debug/login';
}

/// Where the router sends [uri] for the given auth state (T3), or null to stay.
/// Signed out: only welcome, sign-in and debug pages. Signed in: the sign-in
/// pages lead on (code → profile confirm, others → groups). The debug deep
/// link `splitify://dev/login?user=e2e-a` opens the developer sign-in (T4).
String? authRedirect(Uri uri, {required bool signedIn, bool debug = kDebugMode}) {
  final path = uri.path;
  // Invite QR / share link `splitify://join?code=…` (host `join`) → the join screen.
  if (uri.host == 'join' && path != Routes.join) {
    return Uri(path: Routes.join, queryParameters: _code(uri)).toString();
  }
  if (debug && (path == '/login' || path == '/dev/login')) {
    return Uri(
      path: Routes.devLogin,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
    ).toString();
  }
  final public =
      path == Routes.welcome || path.startsWith(Routes.signIn) || path.startsWith('/debug/');
  if (!signedIn) return public ? null : Routes.welcome;
  if (path == Routes.signInCode) return Routes.signInProfile;
  if (path == Routes.welcome || path == Routes.signIn) return Routes.groups;
  return null;
}

Map<String, String>? _code(Uri uri) {
  final code = uri.queryParameters['code'];
  return code == null ? null : {'code': code};
}

/// Auth state for the router: the current answer plus a change signal.
class AuthGate extends ChangeNotifier {
  AuthGate({required bool signedIn, required Stream<bool> changes}) : _signedIn = signedIn {
    _sub = changes.listen((v) {
      if (v == _signedIn) return;
      _signedIn = v;
      notifyListeners();
    });
  }

  bool _signedIn;
  late final StreamSubscription<bool> _sub;

  bool get signedIn => _signedIn;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Builds the app router. [initialLocation] is for tests; without a [gate]
/// there are no auth redirects (screenshots, widget tests).
GoRouter buildRouter({String initialLocation = Routes.welcome, AuthGate? gate}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  refreshListenable: gate,
  redirect: gate == null
      ? null
      : (context, state) => authRedirect(state.uri, signedIn: gate.signedIn),
  routes: [
    GoRoute(path: Routes.welcome, builder: (context, state) => const WelcomeScreen()),
    GoRoute(
      path: Routes.signIn,
      builder: (context, state) => const SignInScreen(),
      routes: [
        GoRoute(
          path: 'code',
          builder: (context, state) => CodeScreen(email: state.uri.queryParameters['email']),
        ),
        GoRoute(path: 'profile', builder: (context, state) => const ProfileConfirmScreen()),
      ],
    ),
    GoRoute(
      path: Routes.join,
      builder: (context, state) => JoinScreen(code: state.uri.queryParameters['code']),
      routes: [
        GoRoute(
          path: ':code',
          builder: (context, state) => JoinScreen(code: state.pathParameters['code']),
        ),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.groups,
              builder: (context, state) => const GroupsHomeScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const GroupFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => GroupDetailScreen(
                    groupId: state.pathParameters['id']!,
                    initialTab: state.uri.queryParameters['tab'],
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) =>
                          GroupFormScreen(groupId: state.pathParameters['id']),
                    ),
                    GoRoute(
                      path: 'settings',
                      parentNavigatorKey: _rootKey,
                      builder: (context, state) =>
                          GroupSettingsScreen(groupId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
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
                GoRoute(
                  path: 'profile',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const ProfileEditScreen(),
                ),
                GoRoute(
                  path: 'delete',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const DeleteAccountScreen(),
                ),
                GoRoute(
                  path: 'sync',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const SyncStorageScreen(),
                ),
                GoRoute(
                  path: 'deleted-groups',
                  parentNavigatorKey: _rootKey,
                  builder: (context, state) => const DeletedGroupsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    ...expenseRoutes(),
    ...historyRoutes(),
    ...paymentRoutes(),
    ...insightsRoutes(),
    ...friendRoutes(),
    ...searchRoutes(),
    ...notificationRoutes(),
    ...importRoutes(),
    ...securityRoutes(),
    if (kDebugMode) ...[
      GoRoute(path: Routes.gallery, builder: (context, state) => const GalleryScreen()),
      GoRoute(
        path: Routes.devLogin,
        builder: (context, state) => DevLoginScreen(user: state.uri.queryParameters['user']),
      ),
    ],
  ],
);

/// App router, one per app run, redirecting by auth state.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final gate = AuthGate(
    signedIn: auth.currentUser != null,
    changes: auth.authStateChanges().map((u) => u != null),
  );
  final router = buildRouter(gate: gate);
  ref.onDispose(() {
    router.dispose();
    gate.dispose();
  });
  return router;
});
