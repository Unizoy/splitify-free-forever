import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/features/activity/presentation/group_activity_screen.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';
import 'package:splitify/features/payments/presentation/settle_all_screen.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';

/// Payment and balance routes (07 §1): `/settle?group=&from=&to=&currency=`, everything with one friend
/// `/settle/all?friend=&currency=` (D-034 B1), `/payment/:id`, `/payment/:id/edit` and the group feed
/// `/groups/:id/activity` (S-101).
abstract final class PaymentRoutes {
  static String settle(String groupId, {String? from, String? to, String? currency}) => Uri(
    path: '/settle',
    queryParameters: {'group': groupId, 'from': ?from, 'to': ?to, 'currency': ?currency},
  ).toString();

  /// One payment per shared group, for everything with friend [friendKey] in [currency].
  static String settleAll(String friendKey, String currency) => Uri(
    path: '/settle/all',
    queryParameters: {'friend': friendKey, 'currency': currency},
  ).toString();

  static String detail(String id) => '/payment/$id';
  static String edit(String id) => '/payment/$id/edit';
  static String groupActivity(String groupId) => '/groups/$groupId/activity';
}

/// Top-level routes (they cover the tab shell); spread into the app router.
List<RouteBase> paymentRoutes() => [
  AppRoute(
    path: '/settle',
    builder: (context, state) {
      final q = state.uri.queryParameters;
      return SettleUpScreen(
        groupId: q['group'] ?? '',
        from: q['from'],
        to: q['to'],
        currency: q['currency'],
      );
    },
  ),
  AppRoute(
    path: '/settle/all',
    builder: (context, state) {
      final q = state.uri.queryParameters;
      return SettleAllScreen(friendKey: q['friend'] ?? '', currency: q['currency'] ?? 'INR');
    },
  ),
  AppRoute(
    path: '/payment/:id',
    builder: (context, state) => PaymentDetailScreen(paymentId: state.pathParameters['id']!),
    routes: [
      AppRoute(
        path: 'edit',
        builder: (context, state) => SettleUpScreen(paymentId: state.pathParameters['id']),
      ),
    ],
  ),
  AppRoute(
    path: '/groups/:id/activity',
    builder: (context, state) => GroupActivityScreen(groupId: state.pathParameters['id']!),
  ),
];
