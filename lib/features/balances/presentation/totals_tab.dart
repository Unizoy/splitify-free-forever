import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/balances/application/balance_views.dart' show orderCurrencies;
import 'package:splitify/features/balances/application/totals_providers.dart';
import 'package:splitify/features/balances/domain/group_totals.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show BalancesSkeleton;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The group's Totals tab (#21): This month · All time; per currency the total spent (IOUs and
/// payments excluded), my share and what I paid, then each person's paid and share; a link to the
/// charts (phase 17).
class TotalsTab extends ConsumerStatefulWidget {
  const TotalsTab({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<TotalsTab> createState() => _TotalsTabState();
}

class _TotalsTabState extends ConsumerState<TotalsTab> {
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(groupTotalsProvider(widget.groupId));
    final v = async.value;
    if (v == null) {
      if (async.isLoading) return const BalancesSkeleton();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: EmptyState(
          icon: async.hasError ? AppIcons.warning : AppIcons.groups,
          title: async.hasError ? l.balLoadError : l.groupNotFound,
        ),
      );
    }
    final totals = _month ? v.month : v.allTime;
    final codes = orderCurrencies(totals.keys, v.mainCurrency);
    return Column(
      key: const Key('totals-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s4),
        SegmentedPill<bool>(
          key: const Key('totals-period'),
          items: [
            SegmentedPillItem(value: true, label: l.totThisMonth),
            SegmentedPillItem(value: false, label: l.totAllTime),
          ],
          value: _month,
          onChanged: (m) => setState(() => _month = m),
        ),
        if (codes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            child: EmptyState(
              icon: AppIcons.chart,
              title: _month ? l.totEmptyMonthTitle : l.totEmptyTitle,
              message: l.totEmptyBody,
            ),
          )
        else
          for (final c in codes) ...[
            const SizedBox(height: AppSpacing.s6),
            _SpentCard(totals: totals[c]!, view: v, showCode: codes.length > 1),
            const SizedBox(height: AppSpacing.s6),
            SectionLabel(l.totEachPerson),
            ..._people(context, v, totals[c]!),
          ],
        const SizedBox(height: AppSpacing.s4),
        Text(
          l.totFootnote,
          style: context.text.caption.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s2),
        DashedListRow(
          key: const Key('totals-charts'),
          icon: AppIcons.chart,
          label: l.totCharts,
          showDivider: false,
          onTap: () => showComingSoon(context),
        ),
      ],
    );
  }

  List<Widget> _people(BuildContext context, GroupTotalsView v, CurrencyTotals t) {
    final l = AppLocalizations.of(context);
    final ids = [
      for (final m in v.members)
        if (t.paid.containsKey(m.id) || t.shares.containsKey(m.id)) m.id,
    ];
    return [
      for (var i = 0; i < ids.length; i++)
        AmountRow(
          key: Key('totals-${t.currency}-${ids[i]}'),
          title: ids[i] == v.meId ? l.you : v.nameOf(ids[i]),
          caption: l.totPaidShare(
            listMoney(t.paid[ids[i]] ?? 0, t.currency),
            listMoney(t.shares[ids[i]] ?? 0, t.currency),
          ),
          amountText: '',
          leading: Avatar(
            name: v.nameOf(ids[i]),
            seed: ids[i],
            tint: v.members.where((m) => m.id == ids[i]).firstOrNull?.tint,
          ),
          showDivider: i < ids.length - 1,
        ),
    ];
  }
}

/// "TOTAL SPENT · ₹48,250 · 12 expenses" with my share and what I paid.
class _SpentCard extends StatelessWidget {
  const _SpentCard({required this.totals, required this.view, required this.showCode});

  final CurrencyTotals totals;
  final GroupTotalsView view;
  final bool showCode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final me = view.meId;
    final label = showCode ? '${l.totSpent} · ${totals.currency}' : l.totSpent;
    Widget stat(String caption, int value, Key key) => Expanded(
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: 2),
          // Long amounts shrink instead of breaking mid-number at large text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              listMoney(value, totals.currency),
              maxLines: 1,
              style: context.text.title.w(700),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: Key('totals-card-${totals.currency}'),
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: context.text.labelCaps.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              listMoney(totals.spent, totals.currency),
              style: context.text.amountHero.copyWith(color: c.primary),
            ),
          ),
          Text(
            l.totExpenseCount(totals.count),
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
          if (me != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Divider(height: 1, thickness: 1, color: c.divider),
            const SizedBox(height: AppSpacing.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stat(l.totYourShare, totals.shares[me] ?? 0, const Key('totals-my-share')),
                const SizedBox(width: AppSpacing.s4),
                stat(l.totYouPaid, totals.paid[me] ?? 0, const Key('totals-my-paid')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
