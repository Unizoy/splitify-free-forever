import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/features/friend_code/presentation/friend_code_screen.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';

/// Friend routes (07 §1): `/friends/:key`, key `u:<user id>` or `m:<member id>` (S-121), and add a friend by
/// code `/friends/code[/:code]` (D-034 B4; the deep link `splitify://friend?code=…` lands there). Top-level so
/// the pages cover the tab shell, like the group detail.
abstract final class FriendRoutes {
  static String page(String key) => '/friends/${Uri.encodeComponent(key)}';

  static const addByCode = '/friends/code';

  static String addCode(String code) => '$addByCode/${Uri.encodeComponent(code)}';
}

/// Spread into the app router. The code routes come first: `/friends/code` would otherwise be a friend key.
List<RouteBase> friendRoutes() => [
  AppRoute(
    path: FriendRoutes.addByCode,
    builder: (context, state) => const FriendCodeScreen(),
    routes: [
      AppRoute(
        path: ':code',
        builder: (context, state) => FriendCodeScreen(code: state.pathParameters['code']),
      ),
    ],
  ),
  // go_router already decodes path parameters; decoding the key again threw on a link like `/friends/%25ZZ`
  // (R4, S-474).
  AppRoute(
    path: '/friends/:key',
    builder: (context, state) => FriendPage(friendKey: state.pathParameters['key']!),
  ),
];
