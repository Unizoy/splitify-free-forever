import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Expenses tab of the group detail. Phase 08 replaces the body with `ExpenseList(groupId)`.
class GroupExpensesTab extends StatelessWidget {
  const GroupExpensesTab({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      key: const Key('group-expenses-empty'),
      icon: AppIcons.receipt,
      title: l.groupNoExpensesTitle,
      message: l.groupNoExpensesBody,
    );
  }
}

/// Balances tab placeholder (phase 09 builds the real one).
class GroupBalancesTab extends StatelessWidget {
  const GroupBalancesTab({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: AppIcons.coins,
      title: l.groupBalancesEmptyTitle,
      message: l.groupBalancesEmptyBody,
    );
  }
}

/// Totals tab placeholder (phase 09/17 build the real one).
class GroupTotalsTab extends StatelessWidget {
  const GroupTotalsTab({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: AppIcons.chart,
      title: l.groupTotalsEmptyTitle,
      message: l.groupTotalsEmptyBody,
    );
  }
}
