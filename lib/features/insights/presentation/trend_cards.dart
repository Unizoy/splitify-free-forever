import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart' show listMoney;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/insights/application/insights_providers.dart';
import 'package:splitify/features/insights/domain/aggregations.dart';
import 'package:splitify/features/insights/presentation/insights_charts.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Category over time" (D-034 WP-D, P-6): chips of the categories with spending (biggest first), the
/// picked one's last 12 months as bars in its chart colour, the picked month's amount and the 12-month
/// total. Shares the picked month with the "By month" card.
class CategoryTrendCard extends StatelessWidget {
  const CategoryTrendCard({
    required this.view,
    required this.category,
    required this.month,
    required this.onCategory,
    required this.onMonth,
    super.key,
  });

  final InsightsView view;

  /// Picked top-level category key.
  final String category;

  /// Picked `YYYY-MM`.
  final String month;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onMonth;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final months =
        view.categoryTrends[category] ?? view.months.map((m) => MonthSpend(m.month, 0)).toList();
    final amount = months.where((m) => m.month == month).firstOrNull?.minor ?? 0;
    final total = months.fold(0, (sum, m) => sum + m.minor);
    final cat = categoryOfKey(category);
    return InsightsCard(
      key: const Key('insights-category-trend'),
      title: l.trendCategoryTitle,
      trailing: l.insLast12Months,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChipRow(
            label: l.trendPickCategory,
            children: [
              for (final s in view.summary.byCategory)
                IconChip(
                  key: Key('trend-category-${s.category}'),
                  label: l.category(s.category),
                  icon: categoryOfKey(s.category).icon,
                  iconColor: categoryOfKey(s.category).color,
                  selected: s.category == category,
                  onTap: () => onCategory(s.category),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            monthTitle(context, month),
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              listMoney(amount, view.currency),
              key: const Key('trend-category-amount'),
              maxLines: 1,
              style: context.text.title.w(700).copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          MonthBars(
            months: months,
            currency: view.currency,
            selected: month,
            onSelect: onMonth,
            keyPrefix: 'trend-bar',
            color: cat.color,
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            l.trendCategoryTotal(listMoney(total, view.currency), l.category(category)),
            key: const Key('trend-category-total'),
            style: context.text.bodySmall.w(600).copyWith(color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// "Who paid" (D-034 WP-D, P-6; Group mode): a person's chips, their paid (solid) against share (light)
/// bars per month, the picked month's numbers and the 12-month sums.
class WhoPaidCard extends StatelessWidget {
  const WhoPaidCard({
    required this.view,
    required this.memberId,
    required this.month,
    required this.onMember,
    required this.onMonth,
    super.key,
  });

  final InsightsView view;
  final String memberId;
  final String month;
  final ValueChanged<String> onMember;
  final ValueChanged<String> onMonth;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    String name(String id) => id == view.meMemberId
        ? l.you
        : (view.memberNames[id] ?? '').isEmpty
        ? l.someone
        : view.memberNames[id]!;
    final trend = view.whoPaid.firstWhere(
      (t) => t.memberId == memberId,
      orElse: () => view.whoPaid.first,
    );
    final picked = trend.months.where((m) => m.month == month).firstOrNull;
    return InsightsCard(
      key: const Key('insights-who-paid'),
      title: l.trendWhoPaidTitle,
      trailing: l.insLast12Months,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChipRow(
            label: l.trendPickPerson,
            children: [
              for (final t in view.whoPaid)
                IconChip(
                  key: Key('trend-person-${t.memberId}'),
                  label: name(t.memberId),
                  icon: t.memberId == view.meMemberId ? AppIcons.userFill : AppIcons.user,
                  selected: t.memberId == trend.memberId,
                  onTap: () => onMember(t.memberId),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            monthTitle(context, month),
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
          Text(
            l.totPaidShare(
              listMoney(picked?.paid ?? 0, view.currency),
              listMoney(picked?.share ?? 0, view.currency),
            ),
            key: const Key('trend-who-month'),
            style: context.text.title.w(700).copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s4),
          PaidShareBars(
            months: trend.months,
            currency: view.currency,
            selected: month,
            onSelect: onMonth,
          ),
          const SizedBox(height: AppSpacing.s3),
          _Legend(paid: l.trendPaid, share: l.trendShare),
          const SizedBox(height: AppSpacing.s2),
          Text(
            l.trendMemberTotal(
              listMoney(trend.paid, view.currency),
              listMoney(trend.share, view.currency),
            ),
            key: const Key('trend-who-total'),
            style: context.text.bodySmall.w(600).copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(l.trendWhoPaidHint, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// A sideways-scrolling row of chips with a label for TalkBack.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s2),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.paid, required this.share});

  final String paid;
  final String share;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(Color color, String text, {bool outline = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: outline ? c.primary.withValues(alpha: context.isDark ? 0.45 : 0.3) : color,
            borderRadius: AppRadii.allPill,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(text, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppSpacing.s4,
        runSpacing: AppSpacing.s1,
        children: [item(c.primary, paid), item(c.primary, share, outline: true)],
      ),
    );
  }
}

/// Paired monthly bars: what a person paid (solid) next to their share (light); a tap picks the month.
class PaidShareBars extends StatelessWidget {
  const PaidShareBars({
    required this.months,
    required this.currency,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<PaidShareMonth> months;
  final String currency;
  final String selected;
  final ValueChanged<String> onSelect;

  static const double _height = 140;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    var top = 0;
    for (final m in months) {
      if (m.paid > top) top = m.paid;
      if (m.share > top) top = m.share;
    }
    final maxY = top == 0 ? 1.0 : top.toDouble();
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final short = large ? DateFormat('MMMMM', locale) : DateFormat.MMM(locale);
    DateTime date(String key) =>
        DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(5, 7)));
    final soft = c.primary.withValues(alpha: context.isDark ? 0.45 : 0.3);
    final chart = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: months[i].paid.toDouble(),
                  width: 6,
                  color: months[i].month == selected
                      ? c.primary
                      : c.primary.withValues(alpha: 0.75),
                  borderRadius: AppRadii.allPill,
                ),
                BarChartRodData(
                  toY: months[i].share.toDouble(),
                  width: 6,
                  color: soft,
                  borderRadius: AppRadii.allPill,
                ),
              ],
            ),
        ],
      ),
      duration: context.motion.base,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _height,
          child: Stack(
            children: [
              Positioned.fill(child: ExcludeSemantics(child: chart)),
              Positioned.fill(
                child: Row(
                  children: [
                    for (final m in months)
                      Expanded(
                        child: Semantics(
                          selected: m.month == selected,
                          label: l.trendMemberBar(
                            monthTitle(context, m.month),
                            listMoney(m.paid, currency),
                            listMoney(m.share, currency),
                          ),
                          excludeSemantics: true,
                          child: Pressable(
                            key: Key('trend-who-bar-${m.month}'),
                            onTap: () => onSelect(m.month),
                            borderRadius: AppRadii.all16,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final m in months)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      short.format(date(m.month)),
                      maxLines: 1,
                      style: context.text.caption
                          .w(m.month == selected ? 700 : 500)
                          .copyWith(color: m.month == selected ? c.textPrimary : c.textTertiary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
