import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The group's Balances tab (#15, 712): an overlap banner with my side, then per currency "who owes
/// whom" (or the suggested payments when simplify is on, with "Show original debts") with Settle on
/// every row, and everyone's net. Not scrollable itself (it sits inside the group's overlap sheet).
class BalancesTab extends ConsumerStatefulWidget {
  const BalancesTab({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<BalancesTab> createState() => _BalancesTabState();
}

class _BalancesTabState extends ConsumerState<BalancesTab> {
  /// Simplify is on but the person asked for the original debts.
  bool _original = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(groupBalancesProvider(widget.groupId));
    final b = async.value;
    if (b == null) {
      if (async.hasError) {
        return _Padded(EmptyState(icon: AppIcons.warning, title: l.balLoadError));
      }
      if (async.isLoading) return const BalancesSkeleton();
      return _Padded(EmptyState(icon: AppIcons.groups, title: l.groupNotFound));
    }
    if (!b.hasRecords) {
      return _Padded(
        EmptyState(
          icon: AppIcons.coins,
          title: l.groupBalancesEmptyTitle,
          message: l.groupBalancesEmptyBody,
        ),
      );
    }
    final simplified = b.simplify && !_original;
    final multi = b.currencies.length > 1;
    return Column(
      key: const Key('balances-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s4),
        _Banner(balances: b),
        for (final c in b.currencies) ...[
          const SizedBox(height: AppSpacing.s8),
          if (multi) ...[
            Semantics(
              header: true,
              child: Text(l.balCurrencySection(c), style: context.text.title.w(700)),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
          SectionLabel(
            simplified ? l.balSuggestedPayments : l.balWhoOwesWhom,
            trailing: b.simplify
                ? _LinkButton(
                    key: Key('balances-toggle-$c'),
                    label: simplified ? l.balShowOriginal : l.balShowSimplified,
                    onTap: () => setState(() => _original = !_original),
                  )
                : null,
          ),
          ..._transfers(context, b, c, simplified),
          const SizedBox(height: AppSpacing.s6),
          SectionLabel(l.balEveryone),
          ..._nets(context, b, c),
        ],
      ],
    );
  }

  List<Widget> _transfers(BuildContext context, GroupBalances b, String currency, bool simplified) {
    final l = AppLocalizations.of(context);
    final shown = b.shown(currency, simplified: simplified);
    if (shown.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Row(
            children: [
              Icon(AppIcons.checkCircle, size: 22, color: context.colors.owedAccent),
              const SizedBox(width: AppSpacing.s3),
              Expanded(child: Text(l.balEveryoneSettled, style: context.text.body.w(600))),
            ],
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < shown.length; i++)
        TransferRow(
          key: Key('transfer-$currency-${shown[i].from}-${shown[i].to}'),
          balances: b,
          currency: currency,
          transfer: shown[i],
          showDivider: i < shown.length - 1,
        ),
    ];
  }

  List<Widget> _nets(BuildContext context, GroupBalances b, String currency) {
    final l = AppLocalizations.of(context);
    final nets = b.byCurrency[currency]!.nets;
    final people = [
      for (final m in b.members)
        if ((nets[m.id] ?? 0) != 0 || (m.deletedAt == null && m.status == 'active')) m,
    ];
    return [
      for (var i = 0; i < people.length; i++)
        Builder(
          builder: (context) {
            final m = people[i];
            final net = nets[m.id] ?? 0;
            return AmountRow(
              key: Key('net-$currency-${m.id}'),
              title: personName(l, b, m.id),
              amountText: net == 0 ? '' : listMoney(net.abs(), currency),
              amountCaption: net > 0
                  ? l.balGetsBack
                  : net < 0
                  ? l.balOwes
                  : l.balSettledUp,
              tone: toneOfNet(net),
              leading: Avatar(name: b.nameOf(m.id), seed: m.id, tint: m.tint),
              showDivider: i < people.length - 1,
            );
          },
        ),
    ];
  }
}

class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
    child: child,
  );
}

/// "You are owed here · ₹2,400" (indigo, overhanging the sheet).
class _Banner extends StatelessWidget {
  const _Banner({required this.balances});

  final GroupBalances balances;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mine = balances.myNets;
    final status = balanceStatusOf(mine.values);
    final (line1, line2) = switch (status) {
      BalanceStatus.owed => (l.balBannerOwed, amountsText(mine)),
      BalanceStatus.owe => (l.balBannerOwe, amountsText(mine)),
      BalanceStatus.mixed => (l.balBannerMixed, amountsText(mine)),
      BalanceStatus.settled => (l.balBannerSettled, l.balBannerSettledLine2),
    };
    return OverlapBanner(
      key: const Key('balances-banner'),
      line1: line1,
      line2: line2,
      icon: status == BalanceStatus.settled ? AppIcons.shieldCheck : AppIcons.coins,
    );
  }
}

/// One "who owes whom" row: both avatars, "Asha owes you", the amount in the viewer's colour, and
/// Settle (opens Settle up prefilled). At large text the button moves under the words.
class TransferRow extends StatelessWidget {
  const TransferRow({
    required this.balances,
    required this.currency,
    required this.transfer,
    this.showDivider = true,
    this.onSettle,
    super.key,
  });

  final GroupBalances balances;
  final String currency;
  final Transfer transfer;
  final bool showDivider;

  /// Replaces the default "open Settle up" (the pickers close their sheet first).
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final b = balances;
    final t = transfer;
    final tone = t.from == b.meId
        ? MoneyTone.owe
        : t.to == b.meId
        ? MoneyTone.owed
        : MoneyTone.settled;
    final title = l.balPairOwes(personName(l, b, t.from), personName(l, b, t.to, start: false));
    final amount = listMoney(t.amount, currency);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    void open() {
      final custom = onSettle;
      if (custom != null) return custom();
      unawaited(
        context.push(PaymentRoutes.settle(b.groupId, from: t.from, to: t.to, currency: currency)),
      );
    }

    final settle = PillButton(
      key: Key('settle-${t.from}-${t.to}'),
      label: l.balSettle,
      variant: PillVariant.outline,
      size: PillSize.medium,
      expand: false,
      onPressed: open,
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.title.w(500)),
        const SizedBox(height: 2),
        Text(
          amount,
          style: context.text.title
              .w(700)
              .copyWith(color: tone == MoneyTone.settled ? c.textPrimary : tone.textColor(c)),
        ),
        if (large) ...[const SizedBox(height: AppSpacing.s2), settle],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              children: [
                _PairAvatars(balances: b, from: t.from, to: t.to),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Semantics(label: '$title, $amount', excludeSemantics: true, child: words),
                ),
                if (!large) ...[const SizedBox(width: AppSpacing.s3), settle],
              ],
            ),
          ),
        ),
        if (showDivider) const DashedDivider(),
      ],
    );
  }
}

/// Payer avatar overlapping the receiver's, with a small arrow badge between them.
class _PairAvatars extends StatelessWidget {
  const _PairAvatars({required this.balances, required this.from, required this.to});

  final GroupBalances balances;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = balances.member(from);
    final b = balances.member(to);
    return ExcludeSemantics(
      child: SizedBox(
        width: 68,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Avatar(name: balances.nameOf(from), seed: from, tint: a?.tint),
            Positioned(
              left: 28,
              child: Avatar(name: balances.nameOf(to), seed: to, tint: b?.tint, ring: true),
            ),
            Positioned(
              left: 22,
              top: 24,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 1.5),
                ),
                child: Icon(AppIcons.arrowRight, size: 10, color: c.onInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small text link in the section header ("Show original debts").
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadii.allPill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: context.text.bodySmall.w(600).copyWith(color: context.colors.primary),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Loading placeholder for the Balances and Totals tabs: a banner block and three quiet rows.
class BalancesSkeleton extends StatelessWidget {
  const BalancesSkeleton({super.key});

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
          const SizedBox(height: AppSpacing.s4),
          Container(
            height: 88,
            decoration: BoxDecoration(color: fill, borderRadius: AppRadii.all24),
          ),
          const SizedBox(height: AppSpacing.s6),
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
                        bar(150, 14),
                        const SizedBox(height: AppSpacing.s2),
                        bar(80, 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
