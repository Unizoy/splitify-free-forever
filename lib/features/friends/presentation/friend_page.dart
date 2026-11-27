import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show TransferRow;
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/presentation/expense_copy.dart' show monthHeader;
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/add_friend_sheet.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/features/groups/presentation/invite_sheet.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/features/notifications/application/reminders.dart';
import 'package:splitify/features/notifications/presentation/remind_button.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Friend page (`/friends/:key`, 542 header, #2/#16), compact like Splitwise (D-033): avatar and name on a
/// short hero with the total per currency, then Settle up and Remind (when they owe me and have the app),
/// what each shared group shows between us, every shared expense and payment across groups (group named on
/// each row), and Add expense at the bottom.
class FriendPage extends ConsumerWidget {
  const FriendPage({required this.friendKey, super.key});

  final String friendKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(friendProvider(friendKey));
    final friend = async.value;
    if (friend == null) {
      return Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => _close(context),
          ),
        ),
        body: Center(
          child: async.isLoading
              ? DotsPulse(color: context.colors.primary, semanticLabel: l.loading)
              : EmptyState(icon: AppIcons.friends, title: l.friendNotFound),
        ),
      );
    }
    final unsynced = ref.watch(anyUnsyncedProvider).value ?? false;
    final first = ref.watch(profileProvider).value?.defaultCurrency ?? 'INR';
    final items = friendItems(friend);
    final groups = friend.links.where((g) => !g.isDirect || g.amounts.isNotEmpty).toList();
    final rows = items.isEmpty ? const <Widget>[] : _itemRows(context, friend, items);
    // Shared items can run to hundreds: they follow the sheet as a lazy sliver (S-267).
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: OverlapColumn(
              top: _Hero(
                friend: friend,
                firstCurrency: first,
                onLoan: () => unawaited(startFriendLoan(context, ref, friend)),
              ),
              bottom: OverlapSheet(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.s6 + AppSpacing.s1,
                  AppSpacing.screen,
                  rows.isEmpty ? MediaQuery.paddingOf(context).bottom + AppSpacing.s6 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Actions(friend: friend),
                    const SizedBox(height: AppSpacing.s6),
                    if (unsynced) ...[
                      const Align(alignment: AlignmentDirectional.centerStart, child: SyncMarker()),
                      const SizedBox(height: AppSpacing.s4),
                    ],
                    // Shared normal groups, or a group where they owe me (its row carries Remind, #23).
                    if (groups.isNotEmpty &&
                        (friend.sharedGroups.isNotEmpty || friend.links.any((g) => g.owesMe))) ...[
                      SectionLabel(l.friendByGroup),
                      for (var i = 0; i < groups.length; i++)
                        _GroupRow(
                          link: groups[i],
                          friendName: friend.name,
                          firstCurrency: first,
                          showDivider: i < groups.length - 1,
                        ),
                      const SizedBox(height: AppSpacing.s8),
                    ],
                    SectionLabel(l.friendSharedItems),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                        child: EmptyState(
                          icon: AppIcons.receipt,
                          title: l.friendNoItemsTitle,
                          message: l.friendNoItemsBody(friend.name),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (rows.isNotEmpty)
            EntranceScope(
              child: SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) => Entrance(index: i, child: rows[i]),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s8)),
        ],
      ),
      bottomNavigationBar: _ActionBar(friend: friend),
    );
  }

  List<Widget> _itemRows(BuildContext context, Friend friend, List<FriendItem> items) {
    final out = <Widget>[];
    String? month;
    for (var i = 0; i < items.length; i++) {
      final header = monthHeader(context, parseIsoDate(items[i].date));
      if (header != month) {
        month = header;
        out.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? AppSpacing.s2 : AppSpacing.s6),
            child: Semantics(
              header: true,
              child: Text(
                header.toUpperCase(),
                style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ),
        );
      }
      final nextSame =
          i + 1 < items.length && monthHeader(context, parseIsoDate(items[i + 1].date)) == header;
      out.add(FriendItemRow(item: items[i], friendName: friend.name, showDivider: nextSame));
    }
    return out;
  }

  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/friends');
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.friend, required this.firstCurrency, required this.onLoan});

  final Friend friend;
  final String firstCurrency;

  /// "Record a loan" with this friend (S-116).
  final VoidCallback onLoan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = friend;
    final direct = f.directGroupId;
    final amounts = f.balances.isEmpty ? '' : friendAmounts(f.balances, firstCurrency);
    final pill = switch (f.status) {
      BalanceStatus.owed => StatusPill(
        key: const Key('friend-status-owed'),
        label: l.friendPillOwed(f.name, amounts),
        icon: AppIcons.coins,
        tone: StatusPillTone.positive,
      ),
      BalanceStatus.owe => StatusPill(
        key: const Key('friend-status-owe'),
        label: l.friendPillOwe(f.name, amounts),
        icon: AppIcons.coins,
        tone: StatusPillTone.negative,
      ),
      BalanceStatus.mixed => StatusPill(
        key: const Key('friend-status-mixed'),
        label: '${l.statusOwedAndOwe}\u00A0· $amounts',
        icon: AppIcons.coins,
        tone: StatusPillTone.glass,
      ),
      BalanceStatus.settled => StatusPill(
        key: const Key('friend-status-settled'),
        label: l.allSettled,
        icon: AppIcons.checkCircle,
        tone: StatusPillTone.glass,
      ),
    };
    return HeroHeader(
      art: (seed: f.seed, family: CoverFamily.couple),
      leading: HeroIconButton(
        icon: AppIcons.back,
        tooltip: l.back,
        onPressed: () => FriendPage._close(context),
      ),
      actions: [
        HeroIconButton(
          key: const Key('friend-loan'),
          icon: AppIcons.loan,
          tooltip: l.loanAction,
          onPressed: onLoan,
        ),
        if (f.nameOnly && direct != null)
          HeroIconButton(
            key: const Key('friend-invite'),
            icon: AppIcons.userPlus,
            tooltip: l.friendInvite(f.name),
            onPressed: () => unawaited(showInviteSheet(context, direct)),
          ),
      ],
      top: Center(
        child: Avatar(name: f.name, seed: f.seed, tint: f.tint, size: AvatarSize.s56, ring: true),
      ),
      title: f.name,
      child: Center(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: AppText.maxSerifScale,
          child: pill,
        ),
      ),
    );
  }
}

/// What one shared group shows between us ("Goa trip · owes you ₹300"); tap opens the group.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.link,
    required this.friendName,
    required this.firstCurrency,
    required this.showDivider,
  });

  final FriendLink link;
  final String friendName;
  final String firstCurrency;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final amounts = link.amounts;
    final status = balanceStatusOf(amounts.values);
    final row = AmountRow(
      key: ValueKey('friend-group-${link.group.id}'),
      title: friendLinkLabel(l, link),
      amountText: amounts.isEmpty ? '' : friendAmounts(amounts, firstCurrency),
      amountCaption: friendStatusText(l, status),
      tone: toneOf(status),
      showDivider: showDivider && !link.owesMe,
      leading: TintedIcon(icon: groupTypeIcon(link.group.type), color: c.primary, size: 44),
      onTap: link.isDirect ? null : () => unawaited(context.push('/groups/${link.group.id}')),
    );
    if (!link.owesMe) return row;
    // They owe me here: Remind (phase 13 #23; the button hides itself for name-only friends).
    final friendMember = link.ledger.members.where((m) => m.id == link.friendMemberId).firstOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: row),
            const SizedBox(width: AppSpacing.s2),
            RemindButton(
              groupId: link.group.id,
              fromMember: link.meId,
              toMember: link.friendMemberId,
              name: friendName,
              linked: friendMember?.userId != null,
            ),
          ],
        ),
        // Same line as AmountRow's own divider.
        if (showDivider) Divider(height: 1, thickness: 1, color: c.divider),
      ],
    );
  }
}

/// Settle up and Remind under the hero (Splitwise's header buttons); Remind shows only when they owe me in a
/// group and have the app (name-only friends cannot be reminded).
class _Actions extends ConsumerWidget {
  const _Actions({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final remindable = remindableLinks(friend);
    return Wrap(
      spacing: AppSpacing.s3,
      runSpacing: AppSpacing.s3,
      children: [
        PillButton(
          key: const Key('friend-settle'),
          label: l.settleUp,
          icon: AppIcons.coins,
          variant: PillVariant.outline,
          size: PillSize.medium,
          expand: false,
          onPressed: () => unawaited(_settle(context, friend)),
        ),
        if (remindable.isNotEmpty)
          PillButton(
            key: const Key('friend-remind'),
            label: l.remindAction,
            icon: AppIcons.bell,
            variant: PillVariant.outline,
            size: PillSize.medium,
            expand: false,
            onPressed: () => unawaited(_remind(context, ref, friend, remindable)),
          ),
      ],
    );
  }
}

/// Groups where [friend] owes me and has the app (a reminder can go there).
List<FriendLink> remindableLinks(Friend friend) => [
  for (final link in friend.links)
    if (link.owesMe &&
        link.ledger.members.any((m) => m.id == link.friendMemberId && m.userId != null))
      link,
];

/// One group: the reminder goes at once; several: a sheet with each group's Remind button.
Future<void> _remind(
  BuildContext context,
  WidgetRef ref,
  Friend friend,
  List<FriendLink> links,
) async {
  final l = AppLocalizations.of(context);
  if (links.length > 1) {
    await showAppSheet<void>(
      context,
      title: l.friendRemindPick(friend.name),
      builder: (sheet) => Column(
        key: const Key('friend-remind-picker'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < links.length; i++)
            _GroupRow(
              link: links[i],
              friendName: friend.name,
              firstCurrency: ref.read(profileProvider).value?.defaultCurrency ?? 'INR',
              showDivider: i < links.length - 1,
            ),
        ],
      ),
    );
    return;
  }
  final link = links.single;
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
  try {
    await ref.read(reminderActionsProvider).send((
      groupId: link.group.id,
      fromMember: link.meId,
      toMember: link.friendMemberId,
    ));
    snack(l.remindSent(friend.name));
  } on ReminderFailure catch (e) {
    final now = ref.read(clockProvider).now().toUtc();
    final retry = e.retryAt;
    final hours = retry == null ? 24 : (retry.difference(now).inMinutes / 60).ceil().clamp(1, 24);
    snack(switch (e.code) {
      ReminderFailureCode.offline => l.needsInternet,
      ReminderFailureCode.throttled => l.remindThrottled(friend.name, hours),
      ReminderFailureCode.nothingOwed => l.remindNothingOwed(friend.name),
      ReminderFailureCode.nameOnly => l.remindNameOnly,
      _ => l.remindFailed,
    });
  }
}

/// Add expense with this friend, always on screen at the bottom.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return StickyActionBar(
      primary: PillButton(
        key: const Key('friend-add-expense'),
        label: l.addExpense,
        icon: AppIcons.add,
        variant: PillVariant.money,
        onPressed: () => unawaited(startFriendExpense(context, ref, friend)),
      ),
    );
  }
}

/// One transfer between us → Settle up prefilled; several → a sheet by group; none → "settled up".
Future<void> _settle(BuildContext context, Friend friend) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final all = friend.transfers;
  String route(FriendLink link, String currency, Transfer t) =>
      PaymentRoutes.settle(link.group.id, from: t.from, to: t.to, currency: currency);
  if (all.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.friendSettledSnack(friend.name))));
    return;
  }
  if (all.length == 1) {
    final x = all.single;
    unawaited(router.push(route(x.link, x.currency, x.transfer)));
    return;
  }
  await showAppSheet<void>(
    context,
    title: l.friendSettleTitle(friend.name),
    builder: (sheet) => Column(
      key: const Key('friend-settle-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final link in friend.links)
          if (link.transfers.isNotEmpty) ...[
            SectionLabel(friendLinkLabel(l, link)),
            for (var i = 0; i < link.transfers.length; i++)
              TransferRow(
                balances: link.balances,
                currency: link.transfers[i].currency,
                transfer: link.transfers[i].transfer,
                showDivider: i < link.transfers.length - 1,
                onSettle: () {
                  Navigator.of(sheet).pop();
                  final x = link.transfers[i];
                  unawaited(router.push(route(link, x.currency, x.transfer)));
                },
              ),
            const SizedBox(height: AppSpacing.s4),
          ],
      ],
    ),
  );
}
