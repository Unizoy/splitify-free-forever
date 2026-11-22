import 'package:flutter/material.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
import 'package:splitify/features/balances/presentation/totals_tab.dart';

// The Expenses tab is built by the group page itself as slivers (ExpenseListSliver + GroupActivitySection,
// S-167).

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
