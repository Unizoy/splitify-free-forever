import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/friend_code/presentation/my_code_sheet.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show showGroupMessage;
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

/// "Add friend expense" (Friends tab, D-033): the one-screen editor opens at once, like the "+"; its "With
/// you and" picker lists friends (and "Add <name> as a friend") — no friend sheet first. A friend page's
/// Add expense opens it with that friend already picked (`startFriendExpense`).
void showAddFriendExpense(BuildContext context) =>
    unawaited(GoRouter.of(context).push(ExpenseRoutes.addNew));

/// "Add friend" (Friends tab, D-033): one sheet with the name, then Add friend (a name-only friend, made
/// offline) or "Add and invite with a link" (the same, then the invite sheet of our friend group, whose code
/// arrives once it reaches the server). The friend's page opens either way. Under them (D-034 B4): "Show my
/// code" (my personal friend QR) and "Scan a friend's code" (add someone who has the app, linked at once).
Future<void> showAddFriendSheet(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final result = await showAppSheet<({String name, bool invite})>(
    context,
    title: l.addFriendTitle,
    builder: (sheet) => AddFriendForm(
      onShowCode: () {
        Navigator.of(sheet).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (rootNavigator.mounted) unawaited(showMyFriendCode(rootNavigator.context));
        });
      },
      onScanCode: () {
        Navigator.of(sheet).pop();
        unawaited(router.push(FriendRoutes.addByCode));
      },
    ),
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
  const AddFriendForm({this.onShowCode, this.onScanCode, super.key});

  /// "Show my code" / "Scan a friend's code" rows (shown when set).
  final VoidCallback? onShowCode;
  final VoidCallback? onScanCode;

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
          if (widget.onShowCode != null || widget.onScanCode != null) ...[
            const SizedBox(height: AppSpacing.s4),
            const DashedDivider(),
            if (widget.onShowCode case final show?)
              DashedListRow(
                key: const Key('add-friend-my-code'),
                icon: AppIcons.qr,
                label: l.friendCodeShowMine,
                onTap: show,
              ),
            if (widget.onScanCode case final scan?)
              DashedListRow(
                key: const Key('add-friend-scan-code'),
                icon: AppIcons.scan,
                label: l.friendCodeScan,
                showDivider: false,
                onTap: scan,
              ),
          ],
        ],
      ),
    );
  }
}
