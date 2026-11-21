import 'package:go_router/go_router.dart';
import 'package:splitify/features/history/domain/version_diff.dart';
import 'package:splitify/features/history/presentation/deleted_items_screen.dart';
import 'package:splitify/features/history/presentation/history_screen.dart';

/// History routes (07 §1): `/expense/:id/history`, `/payment/:id/history` and the group's deleted items
/// (`/groups/:id/deleted`, opened from group settings).
abstract final class HistoryRoutes {
  static String expense(String id) => '/expense/$id/history';
  static String payment(String id) => '/payment/$id/history';
  static String deleted(String groupId) => '/groups/$groupId/deleted';
}

/// Top-level routes (they cover the tab shell); spread into the app router.
List<RouteBase> historyRoutes() => [
  GoRoute(
    path: '/expense/:id/history',
    builder: (context, state) =>
        HistoryScreen(target: (kind: HistoryRecordKind.expense, id: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/payment/:id/history',
    builder: (context, state) =>
        HistoryScreen(target: (kind: HistoryRecordKind.payment, id: state.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/groups/:id/deleted',
    builder: (context, state) => DeletedItemsScreen(groupId: state.pathParameters['id']!),
  ),
];
