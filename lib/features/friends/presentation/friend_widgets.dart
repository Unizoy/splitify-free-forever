import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// [amounts] (per currency, positive = they owe me) as one line, [first] currency in front.
String friendAmounts(Map<String, int> amounts, String first) {
  final codes = orderCurrencies(amounts.keys, first);
  return amountsText({for (final c in codes) c: amounts[c]!});
}

/// "owes you" / "you owe" / "settled up" / "Owed and owing" under a friend's amount.
String friendStatusText(AppLocalizations l, BalanceStatus s) => switch (s) {
  BalanceStatus.owed => l.friendOwesYou,
  BalanceStatus.owe => l.friendYouOwe,
  BalanceStatus.mixed => l.statusOwedAndOwe,
  BalanceStatus.settled => l.balSettledUp,
};

/// Shared group names ("Goa trip · Flat 4B +2"), or "Friend expenses" when only the direct group is shared.
String friendGroupsCaption(AppLocalizations l, Friend f) {
  final names = [for (final g in f.sharedGroups) g.group.name];
  if (names.isEmpty) return l.friendDirectOnly;
  if (names.length <= 2) return names.join(' · ');
  return l.friendGroupsMore(names.take(2).join(' · '), names.length - 2);
}

/// The group a friend-page item or row belongs to ("Just you two" for the direct group).
String friendLinkLabel(AppLocalizations l, FriendLink link) =>
    link.isDirect ? l.friendDirectGroup : link.group.name;

IconData groupTypeIcon(String type) => switch (type) {
  'trip' => AppIcons.typeTrip,
  'home' => AppIcons.typeHome,
  'couple' => AppIcons.typeCouple,
  'direct' => AppIcons.typeDirect,
  _ => AppIcons.typeOther,
};

/// One friend on the Friends tab (438 list + 646 rows): avatar, name, shared groups, total with them.
class FriendRow extends StatelessWidget {
  const FriendRow({
    required this.friend,
    required this.firstCurrency,
    this.showDivider = true,
    this.onTap,
    super.key,
  });

  final Friend friend;

  /// The viewer's default currency (shown first).
  final String firstCurrency;
  final bool showDivider;

  /// Replaces "open the friend page" (the add-expense picker).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = friend;
    final status = f.status;
    return AmountRow(
      key: ValueKey('friend-${f.key}'),
      title: f.name,
      caption: friendGroupsCaption(l, f),
      amountText: f.balances.isEmpty ? '' : friendAmounts(f.balances, firstCurrency),
      amountCaption: friendStatusText(l, status),
      tone: toneOf(status),
      leading: Avatar(name: f.name, seed: f.seed, tint: f.tint),
      showDivider: showDivider,
      onTap: onTap ?? () => unawaited(context.push(FriendRoutes.page(f.key))),
    );
  }
}

/// One expense or payment on the friend page: what it means between the two of us, and its group.
class FriendItemRow extends StatelessWidget {
  const FriendItemRow({
    required this.item,
    required this.friendName,
    this.showDivider = true,
    super.key,
  });

  final FriendItem item;
  final String friendName;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final i = item;
    String money(int v) => MoneyFormatter.list.format(v, i.currency);
    final caption = l.friendItemCaption(
      friendLinkLabel(l, i.link),
      dayMonth(context, parseIsoDate(i.date)),
    );
    final tone = i.amount > 0
        ? MoneyTone.owed
        : i.amount < 0
        ? MoneyTone.owe
        : MoneyTone.settled;
    final e = i.expense;
    if (e != null) {
      return AmountRow(
        key: ValueKey('friend-item-${e.id}'),
        title: e.description,
        caption: caption,
        amountText: i.amount == 0 ? '' : money(i.amount.abs()),
        amountCaption: i.amount > 0
            ? l.expYouLent
            : i.amount < 0
            ? l.expYouBorrowed
            : l.expNoBalance,
        tone: tone,
        unsynced: e.syncState != SyncState.synced,
        showDivider: showDivider,
        leading: TintedIcon.category(categoryOf(e.category), size: 44),
        onTap: () => unawaited(context.push(ExpenseRoutes.detail(e.id))),
      );
    }
    final p = i.payment!;
    final iPaid = p.fromMember == i.link.meId;
    return AmountRow(
      key: ValueKey('friend-item-${p.id}'),
      title: iPaid
          ? l.settlePaidSentence(l.you, friendName)
          : l.settlePaidSentence(friendName, l.youLower),
      caption: caption,
      amountText: money(p.amount),
      amountCaption: iPaid ? l.payYouPaid : l.payYouReceived,
      unsynced: p.syncState != SyncState.synced,
      showDivider: showDivider,
      leading: TintedIcon(icon: AppIcons.payment, color: c.owedAccent, size: 44),
      onTap: () => unawaited(context.push(PaymentRoutes.detail(p.id))),
    );
  }
}

/// Loading placeholder for friend lists: three quiet rows.
class FriendsSkeleton extends StatelessWidget {
  const FriendsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fill = context.colors.surfaceMuted;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: fill, borderRadius: AppRadii.allPill),
    );
    return Semantics(
      label: l.loading,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(140, 14),
                        const SizedBox(height: AppSpacing.s2),
                        bar(90, 12),
                      ],
                    ),
                  ),
                  bar(56, 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
