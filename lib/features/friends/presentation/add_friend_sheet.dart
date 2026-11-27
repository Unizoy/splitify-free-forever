import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
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

/// "Record a loan" with [friend] (#11, S-116): the loan form in our direct group with the friend picked.
Future<void> startFriendLoan(BuildContext context, WidgetRef ref, Friend friend) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  try {
    final target = await ref.read(friendActionsProvider).loanTargetFor(friend);
    unawaited(router.push(ExpenseRoutes.addLoan(target.groupId, withMember: target.memberId)));
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

/// "Add friend" (Friends tab, D-033): one sheet with the name, then Add friend (a name-only friend, made
/// offline) or "Add and invite with a link" (the same, then the invite sheet of our friend group, whose code
/// arrives once it reaches the server). The friend's page opens either way.
Future<void> showAddFriendSheet(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final result = await showAppSheet<({String name, bool invite})>(
    context,
    title: l.addFriendTitle,
    builder: (sheet) => const AddFriendForm(),
  );
  if (result == null) return;
  final made = await ref.read(friendActionsProvider).addNameOnlyFriend(result.name);
  unawaited(router.push(FriendRoutes.page(made.key)));
  if (result.invite) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootNavigator.mounted) unawaited(showInviteSheet(rootNavigator.context, made.groupId));
    });
  } else {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.addFriendAdded(result.name))));
  }
}

/// The add-friend sheet body: the name (inline error, never cleared), Add friend, Add and invite.
class AddFriendForm extends StatefulWidget {
  const AddFriendForm({super.key});

  @override
  State<AddFriendForm> createState() => _AddFriendFormState();
}

class _AddFriendFormState extends State<AddFriendForm> {
  final _name = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit({required bool invite}) {
    if (GroupRules.memberName(_name.text) != null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop((name: _name.text.trim(), invite: invite));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UnderlineField(
            key: const Key('add-friend-name'),
            label: l.memberNameLabel,
            required: true,
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            errorText: _showError && GroupRules.memberName(_name.text) != null
                ? l.memberNameInvalid
                : null,
            onChanged: (_) {
              if (_showError) setState(() {});
            },
            onSubmitted: (_) => _submit(invite: false),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(l.addFriendNewHint, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s6),
          PillButton(
            key: const Key('add-friend-save'),
            label: l.addFriend,
            onPressed: () => _submit(invite: false),
          ),
          const SizedBox(height: AppSpacing.s2),
          PillButton(
            key: const Key('add-friend-invite'),
            label: l.addFriendInvite,
            icon: AppIcons.qr,
            variant: PillVariant.ghost,
            onPressed: () => _submit(invite: true),
          ),
        ],
      ),
    );
  }
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
