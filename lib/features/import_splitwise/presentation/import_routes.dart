import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/features/import_splitwise/presentation/import_screen.dart';

/// Route paths of the import flow (08 X1): from a group's settings or from Account.
abstract final class ImportRoutes {
  static String forGroup(String groupId) => '/groups/$groupId/import';
  static const fromAccount = '/account/import';
}

/// Top-level routes (root navigator, above the tab shell).
List<RouteBase> importRoutes() => [
  AppRoute(
    path: '/groups/:id/import',
    builder: (context, state) => ImportScreen(groupId: state.pathParameters['id']),
  ),
  AppRoute(path: ImportRoutes.fromAccount, builder: (context, state) => const ImportScreen()),
];
