import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/features/payments/application/settle_all_controller.dart'
    show SettleAllOption;
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Group "Settle up" (Splitwise-minimal, D-033): with exactly one balance in the group, Record a payment
/// opens at once, prefilled; otherwise a sheet lists the balances (per currency, mine first, biggest first)
/// and each opens Record a payment prefilled, plus "Record a different payment".
Future<void> showSettlePicker(BuildContext context, String groupId) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final loaded = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(groupBalancesProvider(groupId)).value;
  final only = loaded == null ? null : settleSuggestions(loaded);
  if (only != null && only.length == 1) {
    final x = only.single;
    unawaited(router.push(_route(groupId, x.currency, x.transfer)));
    return;
  }
  await showAppSheet<void>(
    context,
    title: l.settleUp,
    builder: (sheet) => GroupSettlePicker(
      groupId: groupId,
      open: (route) {
        Navigator.of(sheet).pop();
        unawaited(router.push(route));
      },
    ),
  );
}

String _route(String groupId, String currency, Transfer t) =>
    PaymentRoutes.settle(groupId, from: t.from, to: t.to, currency: currency);

/// The group sheet's content: the hint, the balances and "Record a different payment".
class GroupSettlePicker extends ConsumerWidget {
  const GroupSettlePicker({required this.groupId, required this.open, super.key});

  final String groupId;
  final ValueChanged<String> open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final b = ref.watch(groupBalancesProvider(groupId)).value;
    if (b == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Center(
          child: DotsPulse(color: c.primary, semanticLabel: l.loading),
        ),
      );
    }
    final all = settleSuggestions(b);
    final sections = all.map((x) => x.currency).toSet().length > 1;
    return Column(
      key: const Key('settle-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          all.isEmpty ? l.settleGroupSettled : l.settlePickHint,
          style: context.text.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s3),
        for (var i = 0; i < all.length; i++) ...[
          if (sections && (i == 0 || all[i - 1].currency != all[i].currency)) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s3),
            SectionLabel(l.balCurrencySection(all[i].currency)),
          ],
          SettleBalanceRow(
            balances: b,
            currency: all[i].currency,
            transfer: all[i].transfer,
            showDivider: i < all.length - 1 && all[i + 1].currency == all[i].currency,
            onTap: () => open(_route(groupId, all[i].currency, all[i].transfer)),
          ),
        ],
        const SizedBox(height: AppSpacing.s5),
        PillButton(
          key: const Key('settle-other'),
          label: all.isEmpty ? l.settleRecordTitle : l.settleOther,
          variant: PillVariant.outline,
          onPressed: () => open(PaymentRoutes.settle(groupId)),
        ),
      ],
    );
  }
}

/// Groups home "Settle up": my balances in every group (what each Balances tab shows between me and
/// someone else). Exactly one opens Record a payment at once; none says so in a snackbar.
Future<void> showSettleEverywhere(BuildContext context, List<GroupBalances> groups) async {
  final l = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final mine = [
    for (final g in groups)
      if (g.meId != null)
        (
          group: g,
          items: [
            for (final s in settleSuggestions(g))
              if (s.transfer.from == g.meId || s.transfer.to == g.meId) s,
          ],
        ),
  ].where((x) => x.items.isNotEmpty).toList();
  if (mine.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.allSettledSnack)));
    return;
  }
  if (mine.length == 1 && mine.single.items.length == 1) {
    final x = mine.single;
    unawaited(
      router.push(_route(x.group.groupId, x.items.single.currency, x.items.single.transfer)),
    );
    return;
  }
  await showAppSheet<void>(
    context,
    title: l.settleWithTitle,
    builder: (sheet) => Column(
      key: const Key('settle-everywhere'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final x in mine) ...[
          SectionLabel(x.group.groupName),
          for (var i = 0; i < x.items.length; i++)
            SettleBalanceRow(
              balances: x.group,
              currency: x.items[i].currency,
              transfer: x.items[i].transfer,
              showDivider: i < x.items.length - 1,
              onTap: () {
                Navigator.of(sheet).pop();
                unawaited(
                  router.push(_route(x.group.groupId, x.items[i].currency, x.items[i].transfer)),
                );
              },
            ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ],
    ),
  );
}

/// One balance to settle: the other person's avatar, their name and "you owe ₹400" / "owes you ₹400" /
/// "owes Rahul ₹400" (a pair without me), and a chevron. The whole row opens Record a payment.
class SettleBalanceRow extends StatelessWidget {
  const SettleBalanceRow({
    required this.balances,
    required this.currency,
    required this.transfer,
    required this.onTap,
    this.showDivider = true,
    super.key,
  });

  final GroupBalances balances;
  final String currency;
  final Transfer transfer;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final b = balances;
    final t = transfer;
    final me = b.meId;
    final amount = listMoney(t.amount, currency);
    final (String who, String line, Color color) = t.from == me
        ? (t.to, l.settlePickYouOwe(amount), c.oweText)
        : t.to == me
        ? (t.from, l.settlePickOwesYou(amount), c.owedText)
        : (t.from, l.settlePickOwes(personName(l, b, t.to, start: false), amount), c.textSecondary);
    final name = personName(l, b, who);
    return SettlePickRow(
      pressKey: Key('settle-pick-$currency-${t.from}-${t.to}'),
      avatar: Avatar(name: b.nameOf(who), seed: who, tint: b.member(who)?.tint),
      title: name,
      line: line,
      color: color,
      onTap: onTap,
      showDivider: showDivider,
    );
  }
}

/// "Everything with Asha · owes you ₹455 · 2 groups" (D-034 B1): the first rows of a friend's Settle up
/// sheet, one per currency where we have balances in several groups. Opens the batch form.
class SettleAllRow extends StatelessWidget {
  const SettleAllRow({
    required this.friendName,
    required this.seed,
    required this.option,
    required this.onTap,
    this.tint,
    this.showDivider = false,
    super.key,
  });

  final String friendName;
  final String seed;
  final int? tint;
  final SettleAllOption option;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final o = option;
    final amount = listMoney(o.net.abs(), o.currency);
    final (line, color) = o.net > 0
        ? (l.settle2EverythingOwesYou(amount, o.groups), c.owedText)
        : (l.settle2EverythingYouOwe(amount, o.groups), c.oweText);
    return SettlePickRow(
      pressKey: Key('settle-all-${o.currency}'),
      avatar: Avatar(name: friendName, seed: seed, tint: tint),
      title: l.settle2Everything(friendName),
      line: line,
      color: color,
      onTap: onTap,
      showDivider: showDivider,
    );
  }
}

/// The row shape of the settle pickers: avatar, a bold title, a coloured amount line, a chevron; the whole row
/// is one button.
class SettlePickRow extends StatelessWidget {
  const SettlePickRow({
    required this.avatar,
    required this.title,
    required this.line,
    required this.color,
    required this.onTap,
    this.showDivider = true,
    this.pressKey,
    super.key,
  });

  /// On the pressable row itself (tests tap it).
  final Key? pressKey;
  final Widget avatar;
  final String title;
  final String line;
  final Color color;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '$title, $line',
          excludeSemantics: true,
          onTap: onTap,
          child: Pressable(
            key: pressKey,
            onTap: onTap,
            scale: AppMotion.rowPressScale,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.minTouch + AppSpacing.s4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.text.body.w(600)),
                          const SizedBox(height: 2),
                          Text(
                            line,
                            style: context.text.bodySmall
                                .w(600)
                                .copyWith(
                                  color: color,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Icon(AppIcons.chevronRight, size: 18, color: c.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider) const DashedDivider(),
      ],
    );
  }
}
