import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart';
import 'package:splitify/features/groups/presentation/group_settings_screen.dart'
    show MemberNameForm;
import 'package:splitify/features/groups/presentation/group_visuals.dart'
    show SectionLabel, showGroupMessage;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens the add-expense stepper for an expense with [friend] (#2): in our direct group, made on the
/// server the first time for a linked friend (needs internet once, S-120).
Future<void> startFriendExpense(BuildContext context, WidgetRef ref, Friend friend) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  try {
    final groupId = await ref.read(friendActionsProvider).expenseGroupFor(friend);
    unawaited(router.push(ExpenseRoutes.add(groupId)));
  } on GroupFailure catch (e) {
    if (!context.mounted) return;
    showGroupMessage(
      context,
      e.code == GroupFailureCode.offline
          ? l.friendNeedsInternet(friend.name)
          : l.friendStartFailed(friend.name),
    );
  }
}

/// "Add friend expense" (Friends tab): pick a friend, or add someone new as a name-only friend (offline),
/// then the normal add-expense stepper opens.
Future<void> showAddFriendExpense(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final picked = await showAppSheet<Object>(
    context,
    title: l.addFriendExpense,
    builder: (sheet) => const _Picker(),
  );
  if (!context.mounted || picked == null) return;
  if (picked is Friend) {
    await startFriendExpense(context, ref, picked);
    return;
  }
  final result = await showAppSheet<({String name, int tint})>(
    context,
    title: l.addFriendNew,
    builder: (context) => MemberNameForm(hint: l.addFriendNewHint, confirm: l.continueLabel),
  );
  if (result == null) return;
  final made = await ref.read(friendActionsProvider).addNameOnlyFriend(result.name);
  unawaited(router.push(ExpenseRoutes.add(made.groupId)));
}

/// Marker popped by the "Someone new" row.
const _someoneNew = 'new';

class _Picker extends ConsumerWidget {
  const _Picker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider).value;
    final first = ref.watch(profileProvider).value?.defaultCurrency ?? 'INR';
    return Column(
      key: const Key('add-friend-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionTile(
          key: const Key('add-friend-new'),
          label: l.addFriendNew,
          leading: const Icon(AppIcons.userPlus),
          onTap: () => Navigator.of(context).pop(_someoneNew),
        ),
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.addFriendWho),
        if (friends == null)
          const FriendsSkeleton()
        else if (friends.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Text(
              l.addFriendNoFriends,
              style: context.text.body.copyWith(color: context.colors.textSecondary),
            ),
          )
        else
          for (var i = 0; i < friends.length; i++)
            FriendRow(
              friend: friends[i],
              firstCurrency: first,
              showDivider: i < friends.length - 1,
              onTap: () => Navigator.of(context).pop(friends[i]),
            ),
      ],
    );
  }
}
