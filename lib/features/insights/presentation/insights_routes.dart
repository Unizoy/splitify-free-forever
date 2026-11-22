import 'package:go_router/go_router.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/presentation/insights_screen.dart';

/// Insights route (07 §2, #33): `/insights?mode=group|me&group=<id>`.
abstract final class InsightsRoutes {
  /// A group's charts (the Totals tab link).
  static String group(String groupId) =>
      Uri(path: '/insights', queryParameters: {'mode': 'group', 'group': groupId}).toString();

  /// My shares across everything (the Account "Your spending" card).
  static const me = '/insights?mode=me';
}

/// Top-level routes (they cover the tab shell); spread into the app router.
List<RouteBase> insightsRoutes() => [
  GoRoute(
    path: '/insights',
    builder: (context, state) {
      final q = state.uri.queryParameters;
      return InsightsScreen(
        mode: q['mode'] == 'me' ? InsightsMode.me : InsightsMode.group,
        groupId: q['group'],
      );
    },
  ),
];
