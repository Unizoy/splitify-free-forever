import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';

/// Expenses tab of the group detail: the phase 08 [ExpenseList] (month headers, rows, empty state).
class GroupExpensesTab extends StatelessWidget {
  const GroupExpensesTab({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) => ExpenseList(groupId: groupId);
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
