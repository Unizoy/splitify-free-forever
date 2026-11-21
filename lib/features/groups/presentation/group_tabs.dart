import 'package:flutter/material.dart';
import 'package:splitify/features/activity/presentation/group_activity_screen.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
import 'package:splitify/features/balances/presentation/totals_tab.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';

/// Expenses tab of the group detail: the phase 08 [ExpenseList] (month headers, expense and payment
/// rows, empty state) and the group's recent activity (phase 09).
class GroupExpensesTab extends StatelessWidget {
  const GroupExpensesTab({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExpenseList(groupId: groupId),
      GroupActivitySection(groupId: groupId),
    ],
  );
}

/// Balances tab (phase 09, #15): banner, who owes whom with Settle, everyone's net.
class GroupBalancesTab extends StatelessWidget {
  const GroupBalancesTab({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) => BalancesTab(groupId: groupId);
}

/// Totals tab (phase 09, #21): total spent, my share, each person's paid and share.
class GroupTotalsTab extends StatelessWidget {
  const GroupTotalsTab({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context) => TotalsTab(groupId: groupId);
}
