import 'package:go_router/go_router.dart';
import 'package:splitify/features/friends/presentation/friend_page.dart';

/// Friend routes (07 §1): `/friends/:key`, key `u:<user id>` or `m:<member id>` (S-121). Top-level so the
/// page covers the tab shell, like the group detail.
abstract final class FriendRoutes {
  static String page(String key) => '/friends/${Uri.encodeComponent(key)}';
}

/// Spread into the app router.
List<RouteBase> friendRoutes() => [
  GoRoute(
    path: '/friends/:key',
    builder: (context, state) =>
        FriendPage(friendKey: Uri.decodeComponent(state.pathParameters['key']!)),
  ),
];
