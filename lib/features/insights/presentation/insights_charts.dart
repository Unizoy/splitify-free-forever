import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart' show listMoney;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/insights/domain/aggregations.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The chart colour and icon of a top-level category key (06 §2: chart colours = category colours).
Category categoryOfKey(String key) =>
    Category.values.where((c) => c.name == key).firstOrNull ?? Category.other;

/// "45%" of [part] in [total], rounded half up with integers; "<1%" for a sliver.
String percentText(AppLocalizations l, int part, int total) {
  if (total <= 0) return l.insPercent(0);
  final p = (part * 100 + total ~/ 2) ~/ total;
  return p == 0 && part > 0 ? l.insPercentSmall : l.insPercent(p);
}

DateTime _monthDate(String key) =>
    DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(5, 7)));

/// "November 2026" for a `YYYY-MM` key.
String monthTitle(BuildContext context, String key) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(_monthDate(key));

/// Card frame shared by the Insights charts: white surface, hairline border, radius 28.
class InsightsCard extends StatelessWidget {
  const InsightsCard({required this.title, required this.trailing, required this.child, super.key});

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all28,
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card(c, dark: context.isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s1,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  style: context.text.labelCaps.copyWith(color: c.textSecondary),
                ),
              ),
              Text(trailing, style: context.text.caption.copyWith(color: c.textTertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          child,
        ],
      ),
    );
  }
}

/// Donut of spending by category with the total (or the picked category) in the hole, and one
/// legend chip per category; tapping a slice or a chip picks it, tapping again clears.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    required this.summary,
    required this.totalLabel,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final SpendingSummary summary;

  /// "Total spent" or "Your share".
  final String totalLabel;

  /// Picked category key, or null.
  final String? selected;
  final ValueChanged<String?> onSelect;

  static const double _ring = 30;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final parts = summary.byCategory;
    // A bigger hole at large text sizes keeps the centre text readable.
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final hole = large ? 92.0 : 70.0;
    final size = (hole + _ring + 10) * 2;
    final pick = parts.where((p) => p.category == selected).firstOrNull;
    final semantics = l.insDonutLabel(
      parts
          .map(
            (p) => l.insDonutPart(
              l.category(p.category),
              listMoney(p.minor, summary.currency),
              percentText(l, p.minor, summary.total),
            ),
          )
          .join('; '),
    );
    final donut = PieChart(
      PieChartData(
        startDegreeOffset: -90,
        sectionsSpace: parts.length > 1 ? 3 : 0,
        centerSpaceRadius: hole,
        sections: [
          for (final p in parts)
            PieChartSectionData(
              value: p.minor.toDouble(),
              color: categoryOfKey(p.category).color
                  .withValues(alpha: pick == null || pick == p ? 1 : 0.28),
              radius: pick == p ? _ring + 8 : _ring,
              showTitle: false,
            ),
        ],
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) return;
            final i = response?.touchedSection?.touchedSectionIndex ?? -1;
            if (i < 0 || i >= parts.length) return;
            final key = parts[i].category;
            onSelect(key == selected ? null : key);
          },
        ),
      ),
      duration: context.motion.base,
    );
    final centre = pick == null
        ? _Centre(
            caption: totalLabel,
            amount: listMoney(summary.total, summary.currency),
            footer: l.totExpenseCount(summary.count),
          )
        : _Centre(
            caption: l.category(pick.category),
            captionColor: categoryOfKey(pick.category).color,
            amount: listMoney(pick.minor, summary.currency),
            footer: l.insCategoryOfTotal(percentText(l, pick.minor, summary.total)),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Semantics(
            label: semantics,
            container: true,
            child: SizedBox.square(
              key: const Key('insights-donut'),
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ExcludeSemantics(child: donut),
                  IgnorePointer(
                    child: SizedBox.square(
                      dimension: hole * 2 - AppSpacing.s4,
                      child: Center(child: centre),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        for (final p in parts) ...[
          LegendChip(
            key: Key('insights-chip-${p.category}'),
            part: p,
            currency: summary.currency,
            percent: percentText(l, p.minor, summary.total),
            selected: p == pick,
            onTap: () => onSelect(p == pick ? null : p.category),
          ),
          if (p != parts.last) const SizedBox(height: AppSpacing.s2),
        ],
      ],
    );
  }
}

/// One legend chip under the donut (442 chip look, full width): category icon circle, name, amount
/// and share; filled `ink` when picked. Two lines at large text sizes, so nothing is cut.
class LegendChip extends StatelessWidget {
  const LegendChip({
    required this.part,
    required this.currency,
    required this.percent,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CategorySpend part;
  final String currency;
  final String percent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final cat = categoryOfKey(part.category);
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    final fg = selected ? c.onInk : c.textPrimary;
    final sub = selected ? c.onInk.withValues(alpha: 0.72) : c.textSecondary;
    final name = Text(
      l.category(part.category),
      style: context.text.body.w(600).copyWith(color: fg),
    );
    final amount = listMoney(part.minor, currency);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.ink : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.all24,
          side: BorderSide(color: selected ? c.ink : c.border, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.s2,
                AppSpacing.s2,
                AppSpacing.s4,
                AppSpacing.s2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                    child: Icon(cat.icon, size: 18, color: c.onPrimaryFill),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  if (large)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          name,
                          Text(
                            l.insAmountShare(amount, percent),
                            style: context.text.bodySmall.copyWith(color: sub),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Expanded(child: name),
                    const SizedBox(width: AppSpacing.s2),
                    Text(amount, style: context.text.body.w(600).copyWith(color: fg)),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48),
                      child: Text(
                        percent,
                        textAlign: TextAlign.end,
                        style: context.text.bodySmall.copyWith(color: sub),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text in the donut hole: caption, amount, footer; shrinks to fit at large text sizes.
class _Centre extends StatelessWidget {
  const _Centre({
    required this.caption,
    required this.amount,
    required this.footer,
    this.captionColor,
  });

  final String caption;
  final String amount;
  final String footer;
  final Color? captionColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: context.text.caption.w(600).copyWith(color: captionColor ?? c.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(amount, maxLines: 1, style: context.text.headline.copyWith(color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(
            footer,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: context.text.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Twelve month bars (oldest left) over a soft track; the picked month is solid primary. Each bar is
/// a tap target with its own label for screen readers.
class MonthBars extends StatelessWidget {
  const MonthBars({
    required this.months,
    required this.currency,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<MonthSpend> months;
  final String currency;

  /// Picked `YYYY-MM`.
  final String selected;
  final ValueChanged<String> onSelect;

  static const double _height = 156;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final top = months.fold(0, (m, s) => s.minor > m ? s.minor : m);
    final maxY = top == 0 ? 1.0 : top.toDouble();
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final short = large ? DateFormat('MMMMM', locale) : DateFormat.MMM(locale);
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
              barRods: [
                BarChartRodData(
                  toY: months[i].minor.toDouble(),
                  width: 14,
                  color: months[i].month == selected
                      ? c.primary
                      : c.primary.withValues(alpha: context.isDark ? 0.45 : 0.32),
                  borderRadius: AppRadii.allPill,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: c.surfaceMuted,
                  ),
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
                        // Read out, not pressed: a 12-bar slot is narrower than a 48 dp target, and
                        // TalkBack already hears each month's amount (final QA S-258).
                        child: Semantics(
                          selected: m.month == selected,
                          label: l.insMonthBar(
                            monthTitle(context, m.month),
                            listMoney(m.minor, currency),
                          ),
                          excludeSemantics: true,
                          child: InkWell(
                            key: Key('insights-bar-${m.month}'),
                            borderRadius: AppRadii.all16,
                            onTap: () => onSelect(m.month),
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
                      short.format(_monthDate(m.month)),
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
