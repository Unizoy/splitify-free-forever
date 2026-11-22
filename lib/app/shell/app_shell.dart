import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/notifications/presentation/notifications_binding.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/capsule_nav_bar.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The 4-tab shell: Groups · Friends · Activity · Account in the floating
/// capsule nav, with the amber "Add expense" button on the first three tabs.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final index = shell.currentIndex;
    return Scaffold(
      extendBody: true,
      body: NotificationsBinding(child: shell),
      bottomNavigationBar: CapsuleNavBar(
        currentIndex: index,
        onSelected: (i) => shell.goBranch(i, initialLocation: i == index),
        onAdd: index == 3 ? null : () => unawaited(startAddExpense(context)),
        addLabel: l.addExpense,
        items: [
          CapsuleNavItem(
            label: l.navGroups,
            icon: AppIcons.groups,
            activeIcon: AppIcons.groupsActive,
          ),
          CapsuleNavItem(
            label: l.navFriends,
            icon: AppIcons.friends,
            activeIcon: AppIcons.friendsActive,
          ),
          CapsuleNavItem(
            label: l.navActivity,
            icon: AppIcons.activity,
            activeIcon: AppIcons.activityActive,
          ),
          CapsuleNavItem(
            label: l.navAccount,
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: index == 3 ? c.primaryContainer : c.chip,
                shape: BoxShape.circle,
              ),
              child: Icon(AppIcons.user, size: 16, color: c.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
