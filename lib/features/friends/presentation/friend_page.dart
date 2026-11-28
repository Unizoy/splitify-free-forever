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
import 'package:splitify/features/currency/application/in_currency_providers.dart';
import 'package:splitify/features/currency/domain/in_currency.dart' show InCurrency;
import 'package:splitify/features/currency/presentation/show_in_currency.dart';
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
import 'package:splitify/features/payments/application/settle_all_controller.dart'
    show settleAllOptions;
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/features/payments/presentation/settle_picker.dart' show SettleAllRow;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Friend page (`/friends/:key`, 542 header, #2/#16), compact like Splitwise (D-033): avatar and name on a
/// short hero with the total per currency, then Settle up and Remind (when they owe me and have the app),
/// what each shared group shows between us, every shared expense and payment across groups (group named on
/// each row), and Add expense at the bottom. Once we are settled in every currency, the history up to the last
/// full settle-up hides behind "Show settled items (N)" (D-034 B5, like Splitwise).
class FriendPage extends ConsumerStatefulWidget {
  const FriendPage({required this.friendKey, super.key});

  final String friendKey;

  @override
  ConsumerState<FriendPage> createState() => _FriendPageState();

  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/friends');
    }
  }
}

class _FriendPageState extends ConsumerState<FriendPage> {
  /// The settled history is open.
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final friendKey = widget.friendKey;
    final async = ref.watch(friendProvider(friendKey));
    final friend = async.value;
    if (friend == null) {
      return Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            tooltip: l.back,
            icon: const Icon(AppIcons.back),
            onPressed: () => FriendPage._close(context),
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
    final settled = settledHistoryCount(friend, items);
    final open = items.sublist(0, items.length - settled);
    final rows = [
      ..._itemRows(context, friend, open),
      if (settled > 0 && open.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s2),
          child: Text(
            l.friendSettledSnack(friend.name),
            key: const Key('friend-all-settled'),
            style: context.text.body.copyWith(color: context.colors.textSecondary),
          ),
        ),
      if (settled > 0)
        Padding(
          padding: EdgeInsets.only(top: open.isEmpty ? AppSpacing.s3 : AppSpacing.s6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PillButton(
              key: const Key('friend-show-settled'),
              label: _showSettled ? l.settle2HideSettled : l.settle2ShowSettled(settled),
              icon: AppIcons.history,
              variant: PillVariant.outline,
              size: PillSize.medium,
              expand: false,
              onPressed: () => setState(() => _showSettled = !_showSettled),
            ),
          ),
        ),
      if (settled > 0 && _showSettled) ..._itemRows(context, friend, items.sublist(open.length)),
    ];
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
              child: SliverContentWidth(
                maxWidth: AppSpacing.maxPage,
                sliver: SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => Entrance(index: i, child: rows[i]),
                  ),
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
    if (items.isEmpty) return out;
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
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.friend, required this.firstCurrency, required this.onLoan});

  final Friend friend;
  final String firstCurrency;

  /// "Record a loan" with this friend (S-116).
  final VoidCallback onLoan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final f = friend;
    final direct = f.directGroupId;
    // "Show in INR" (W2-X P-9): one total from saved conversions, the rest in its own currency.
    final convertible = f.balances.keys.any((code) => code != firstCurrency);
    final showIn = convertible && ref.watch(showInHomeCurrencyProvider);
    final inFirst = showIn ? friendTotalIn(firstCurrency, f) : null;
    final converted = inFirst != null && inFirst.counted ? inFirst : null;
    final shown = converted == null
        ? f.balances
        : {if (converted.amount != 0) firstCurrency: converted.amount, ...converted.notConverted};
    final amounts = shown.isEmpty ? '' : friendAmounts(shown, firstCurrency);
    final pill = switch (converted == null ? f.status : balanceStatusOf(shown.values)) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AppText.maxSerifScale,
              child: pill,
            ),
          ),
          if (showIn && inFirst != null) ...[
            const SizedBox(height: AppSpacing.s2),
            InCurrencyNote(
              value: InCurrency(currency: firstCurrency, counted: inFirst.counted),
              center: true,
            ),
          ],
          if (convertible) ...[
            const SizedBox(height: AppSpacing.s3),
            Center(
              child: ShowInCurrencyChip(
                currency: firstCurrency,
                on: showIn,
                onChanged: (on) => ref.read(showInHomeCurrencyProvider.notifier).set(on: on),
              ),
            ),
          ],
        ],
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

/// Settle up and Remind under the hero (Splitwise's header buttons); Remind shows when they owe me in a group:
/// a push when they have the app, "Share a reminder" through the Android share sheet when they don't (D-034 B3).
class _Actions extends ConsumerWidget {
  const _Actions({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final remindable = remindableLinks(friend);
    PillButton settle({required bool expand}) => PillButton(
      key: const Key('friend-settle'),
      label: l.settleUp,
      icon: AppIcons.coins,
      variant: PillVariant.outline,
      size: PillSize.medium,
      expand: expand,
      onPressed: () => unawaited(_settle(context, ref, friend)),
    );
    if (remindable.isEmpty) {
      return Align(alignment: AlignmentDirectional.centerStart, child: settle(expand: false));
    }
    final remind = PillButton(
      key: const Key('friend-remind'),
      label: l.remindAction,
      icon: AppIcons.bell,
      variant: PillVariant.outline,
      size: PillSize.medium,
      onPressed: () => unawaited(_remind(context, ref, friend, remindable)),
    );
    // Two equal buttons like Splitwise's header; stacked full width when side by side would wrap a label
    // (small phone, large text; R3-A, S-446).
    if (StickyActionBar.stacks(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          settle(expand: true),
          const SizedBox(height: AppSpacing.s3),
          remind,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: settle(expand: true)),
        const SizedBox(width: AppSpacing.s3),
        Expanded(child: remind),
      ],
    );
  }
}

/// Groups where [friend] owes me (a push or a shared reminder can go there).
List<FriendLink> remindableLinks(Friend friend) => [
  for (final link in friend.links)
    if (link.owesMe) link,
];

/// The friend has the app in [link]'s group (a push can reach them).
bool _linkedIn(FriendLink link) =>
    link.ledger.members.any((m) => m.id == link.friendMemberId && m.userId != null);

/// One group: the push goes at once (when it can't, "Share instead"), or the share sheet for a friend without the
/// app; several: a sheet with each group's Remind button.
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
  Future<void> share() => showShareReminder(
    context,
    ref,
    balances: link.balances,
    direct: link.isDirect,
    me: link.meId,
    them: link.friendMemberId,
    name: friend.name,
  );
  if (!_linkedIn(link)) return share();
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text, {bool offerShare = true}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        action: offerShare
            ? SnackBarAction(
                label: l.remindShareInstead,
                onPressed: () {
                  if (context.mounted) unawaited(share());
                },
              )
            : null,
      ),
    );
  try {
    await ref.read(reminderActionsProvider).send((
      groupId: link.group.id,
      fromMember: link.meId,
      toMember: link.friendMemberId,
    ));
    snack(l.remindSent(friend.name), offerShare: false);
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
    }, offerShare: e.code != ReminderFailureCode.nothingOwed);
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

/// One transfer between us → Settle up prefilled; several → a sheet: first "Everything with Asha" per currency
/// where we have balances in several groups (one payment form for all of them, D-034 B1), then each group's
/// balances; none → "settled up".
Future<void> _settle(BuildContext context, WidgetRef ref, Friend friend) async {
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
  final first = ref.read(profileProvider).value?.defaultCurrency ?? 'INR';
  await showAppSheet<void>(
    context,
    title: l.friendSettleTitle(friend.name),
    builder: (sheet) => FriendSettlePicker(
      friend: friend,
      firstCurrency: first,
      onEverything: (currency) {
        Navigator.of(sheet).pop();
        unawaited(router.push(PaymentRoutes.settleAll(friend.key, currency)));
      },
      onTransfer: (link, currency, t) {
        Navigator.of(sheet).pop();
        unawaited(router.push(route(link, currency, t)));
      },
    ),
  );
}

/// The friend's Settle up sheet: "Everything with Asha" per currency where we have balances in several groups,
/// then each group's balances with its Settle button.
class FriendSettlePicker extends StatelessWidget {
  const FriendSettlePicker({
    required this.friend,
    required this.firstCurrency,
    required this.onEverything,
    required this.onTransfer,
    super.key,
  });

  final Friend friend;
  final String firstCurrency;
  final ValueChanged<String> onEverything;
  final void Function(FriendLink link, String currency, Transfer transfer) onTransfer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final everything = settleAllOptions(friend, first: firstCurrency);
    return Column(
      key: const Key('friend-settle-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (everything.isNotEmpty) ...[
          for (var i = 0; i < everything.length; i++)
            SettleAllRow(
              friendName: friend.name,
              seed: friend.seed,
              tint: friend.tint,
              option: everything[i],
              showDivider: i < everything.length - 1,
              onTap: () => onEverything(everything[i].currency),
            ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            l.settle2OneGroup,
            key: const Key('friend-settle-one-group'),
            style: context.text.bodySmall.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s2),
        ],
        for (final link in friend.links)
          if (link.transfers.isNotEmpty) ...[
            SectionLabel(friendLinkLabel(l, link)),
            for (var i = 0; i < link.transfers.length; i++)
              TransferRow(
                balances: link.balances,
                currency: link.transfers[i].currency,
                transfer: link.transfers[i].transfer,
                showDivider: i < link.transfers.length - 1,
                onSettle: () =>
                    onTransfer(link, link.transfers[i].currency, link.transfers[i].transfer),
              ),
            const SizedBox(height: AppSpacing.s4),
          ],
      ],
    );
  }
}
