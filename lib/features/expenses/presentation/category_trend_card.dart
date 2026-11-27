import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/category_trend.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/insights/presentation/insights_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Food in Goa trip · last 3 months" (D-034 A6, Splitwise's category trend): three bars, this month
/// in indigo. Tap → the group's Insights. Hidden when nothing was spent on the category lately.
class CategoryTrendCard extends ConsumerWidget {
  const CategoryTrendCard({required this.groupId, required this.category, super.key});

  final String groupId;
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(categoryTrendProvider((groupId: groupId, category: category)));
    if (trend == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s4, bottom: AppSpacing.s2),
      child: CategoryTrendView(
        trend: trend,
        onTap: () => unawaited(context.push(InsightsRoutes.group(groupId))),
      ),
    );
  }
}

/// The card itself (also drawn by goldens).
class CategoryTrendView extends StatelessWidget {
  const CategoryTrendView({required this.trend, required this.onTap, super.key});

  final CategoryTrend trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final cat = categoryOf(trend.category);
    final tag = Localizations.localeOf(context).toLanguageTag();
    String monthName(String key) => DateFormat(
      'MMM',
      tag,
    ).format(DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(5))));
    String money(int v) => MoneyFormatter.list.format(v, trend.currency);
    final top = trend.months.fold(0, (a, m) => m.minor > a ? m.minor : a);
    final title = l.entryTrendTitle(l.category(trend.category), trend.groupName);
    final spoken = [
      for (final m in trend.months) l.entryTrendMonth(monthName(m.month), money(m.minor)),
    ].join(', ');
    return Semantics(
      button: true,
      label: '$title, ${l.entryTrendSubtitle}. $spoken',
      hint: l.entryTrendOpen,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        key: const Key('expense-trend'),
        onTap: onTap,
        borderRadius: AppRadii.all24,
        scale: AppMotion.rowPressScale,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadii.all24,
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TintedIcon(icon: cat.icon, color: cat.color, size: 36),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.body.w(600)),
                        Text(
                          l.entryTrendSubtitle,
                          style: context.text.caption.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight, size: 18, color: c.textSecondary),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, m) in trend.months.indexed)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            money(m.minor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.caption
                                .w(600)
                                .copyWith(
                                  color: m.minor == 0 ? c.textTertiary : c.textPrimary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          Container(
                            width: 28,
                            height: top == 0 ? 4 : 4 + 52 * m.minor / top,
                            decoration: BoxDecoration(
                              color: i == trend.months.length - 1
                                  ? c.primaryFill
                                  : c.primaryContainer,
                              borderRadius: AppRadii.all16,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s1),
                          Text(
                            monthName(m.month),
                            style: context.text.caption.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
