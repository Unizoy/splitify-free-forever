import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/expenses/presentation/default_split_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/loan_screen.dart';
import 'package:splitify/features/recurring/presentation/recurring_tile.dart'
    show recurringEditRoute;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Expense routes (07 §1): `/expense/new?group=`, `/expense/:id`, `/expense/:id/edit`, the group's
/// default split (`/groups/:id/default-split`, opened from group settings) and loans
/// (`/loan/new?group=&with=`, `/loan/:id/edit`, phase 10).
abstract final class ExpenseRoutes {
  static String add(String groupId) =>
      Uri(path: '/expense/new', queryParameters: {'group': groupId}).toString();
  static String detail(String id) => '/expense/$id';
  static String edit(String id) => '/expense/$id/edit';
  static String defaultSplit(String groupId) => '/groups/$groupId/default-split';

  /// "Record a loan" (#11) in [groupId], optionally with [withMember] already picked (friend pages).
  static String addLoan(String groupId, {String? withMember}) =>
      Uri(path: '/loan/new', queryParameters: {'group': groupId, 'with': ?withMember}).toString();
  static String editLoan(String id) => '/loan/$id/edit';

  /// "Edit future copies" of a repeating expense (#12).
  static String editRecurring(String templateId) => recurringEditRoute(templateId);
}

/// Top-level routes (they cover the tab shell); spread into the app router.
List<RouteBase> expenseRoutes() => [
  GoRoute(
    path: '/expense/new',
    builder: (context, state) => ExpenseEditorScreen(groupId: state.uri.queryParameters['group']),
  ),
  GoRoute(
    path: '/expense/:id',
    builder: (context, state) => ExpenseDetailScreen(expenseId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        builder: (context, state) => ExpenseEditorScreen(expenseId: state.pathParameters['id']),
      ),
    ],
  ),
  GoRoute(
    path: '/groups/:id/default-split',
    builder: (context, state) => DefaultSplitScreen(groupId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/loan/new',
    builder: (context, state) => LoanScreen(
      groupId: state.uri.queryParameters['group'],
      withMember: state.uri.queryParameters['with'],
    ),
  ),
  GoRoute(
    path: '/loan/:id/edit',
    builder: (context, state) => LoanScreen(expenseId: state.pathParameters['id']),
  ),
  GoRoute(
    path: '/recurring/:id/edit',
    builder: (context, state) => ExpenseEditorScreen(templateId: state.pathParameters['id']),
  ),
];

/// The amber "+" in the capsule nav: add to the only group, or ask which group first.
Future<void> startAddExpense(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final groups = await ProviderScope.containerOf(
    context,
    listen: false,
  ).read(groupsRepositoryProvider).watchAll().first;
  final open = [
    for (final g in groups)
      if (g.archivedAt == null) g,
  ];
  if (open.isEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.expNoGroupFirst)));
    return;
  }
  if (open.length == 1) {
    unawaited(router.push(ExpenseRoutes.add(open.first.id)));
    return;
  }
  if (!context.mounted) return;
  final picked = await showAppSheet<String>(
    context,
    title: l.expPickGroup,
    builder: (sheet) => Column(
      children: [
        for (final g in open) ...[
          OptionTile(
            key: Key('pick-group-${g.id}'),
            label: g.name,
            onTap: () => Navigator.of(sheet).pop(g.id),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
      ],
    ),
  );
  if (picked != null) unawaited(router.push(ExpenseRoutes.add(picked)));
}
