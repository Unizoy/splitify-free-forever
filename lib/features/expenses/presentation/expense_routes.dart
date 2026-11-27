import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/app/app_route.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart' show ExpenseView;
import 'package:splitify/features/expenses/presentation/default_split_screen.dart';
import 'package:splitify/features/expenses/presentation/editor/expense_editor_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/loan_screen.dart';
import 'package:splitify/features/recurring/presentation/recurring_tile.dart'
    show recurringEditRoute;

/// Expense routes (07 §1): `/expense/new?group=`, `/expense/:id`, `/expense/:id/edit`, the group's
/// default split (`/groups/:id/default-split`, opened from group settings) and loans
/// (`/loan/new?group=&with=`, `/loan/:id/edit`, phase 10).
abstract final class ExpenseRoutes {
  /// A new expense with nobody picked yet: "With you and" asks (D-033).
  static const addNew = '/expense/new';

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
  AppRoute(
    path: '/expense/new',
    builder: (context, state) => ExpenseEditorScreen(groupId: state.uri.queryParameters['group']),
  ),
  AppRoute(
    path: '/expense/:id',
    builder: (context, state) => ExpenseDetailScreen(
      expenseId: state.pathParameters['id']!,
      initial: state.extra is ExpenseView ? state.extra! as ExpenseView : null,
    ),
    routes: [
      AppRoute(
        path: 'edit',
        builder: (context, state) => ExpenseEditorScreen(expenseId: state.pathParameters['id']),
      ),
    ],
  ),
  AppRoute(
    path: '/groups/:id/default-split',
    builder: (context, state) => DefaultSplitScreen(groupId: state.pathParameters['id']!),
  ),
  AppRoute(
    path: '/loan/new',
    builder: (context, state) => LoanScreen(
      groupId: state.uri.queryParameters['group'],
      withMember: state.uri.queryParameters['with'],
    ),
  ),
  AppRoute(
    path: '/loan/:id/edit',
    builder: (context, state) => LoanScreen(expenseId: state.pathParameters['id']),
  ),
  AppRoute(
    path: '/recurring/:id/edit',
    builder: (context, state) => ExpenseEditorScreen(templateId: state.pathParameters['id']),
  ),
];

/// The amber "+" in the capsule nav (D-033): opens the one-screen editor at once, like Splitwise. Its
/// "With you and" picks the group or friend there; with only one open group it is already picked.
Future<void> startAddExpense(BuildContext context) async {
  final router = GoRouter.of(context);
  final groups = await ProviderScope.containerOf(
    context,
    listen: false,
  ).read(groupsRepositoryProvider).watchAll().first;
  final open = [
    for (final g in groups)
      if (g.archivedAt == null && g.deletedAt == null) g,
  ];
  unawaited(
    router.push(open.length == 1 ? ExpenseRoutes.add(open.first.id) : ExpenseRoutes.addNew),
  );
}
