import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:splitify/features/activity/application/monthly_summary.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart' show listMoney;
import 'package:splitify/features/insights/presentation/insights_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Amounts of several currencies side by side ("₹4,250 + $20"), the person's main one first.
String summaryAmounts(Map<String, int> byCurrency) {
  final codes = byCurrency.keys.toList()
    ..sort((a, b) {
      if (a == 'INR') return -1;
      if (b == 'INR') return 1;
      return a.compareTo(b);
    });
  return codes.map((c) => listMoney(byCurrency[c]!.abs(), c)).join(' + ');
}

/// The lines of the card: spent, then owed / owe / settled.
List<String> monthSummaryLines(AppLocalizations l, MonthSummary s) {
  final owed = {
    for (final e in s.balances.entries)
      if (e.value > 0) e.key: e.value,
  };
  final owe = {
    for (final e in s.balances.entries)
      if (e.value < 0) e.key: e.value,
  };
  return [
    l.w2yMonthSpent(summaryAmounts(s.spent), s.groups),
    if (owed.isNotEmpty) l.w2yMonthOwed(summaryAmounts(owed)),
    if (owe.isNotEmpty) l.w2yMonthOwe(summaryAmounts(owe)),
    if (owed.isEmpty && owe.isEmpty) l.w2yMonthSettled,
  ];
}

/// "Your November" at the top of Activity (F14): a soft card with last month's spending and where I stand;
/// a tap opens Insights; × hides it until next month.
class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({required this.summary, super.key});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final month = DateFormat.MMMM(locale).format(summary.month);
    final title = l.w2yMonthTitle(month);
    final lines = monthSummaryLines(l, summary);
    void open() => unawaited(context.push(InsightsRoutes.me));
    return Semantics(
      container: true,
      child: Container(
        key: const Key('month-summary'),
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadii.all24),
        child: Stack(
          children: [
            Semantics(
              button: true,
              label: [title, ...lines, l.w2yMonthInsights].join('. '),
              excludeSemantics: true,
              onTap: open,
              child: Pressable(
                key: const Key('month-summary-open'),
                onTap: open,
                borderRadius: AppRadii.all24,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s4,
                    AppSpacing.s12,
                    AppSpacing.s4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: c.primaryFill, shape: BoxShape.circle),
                        child: Icon(AppIcons.chart, size: 22, color: c.onPrimaryFill),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: context.text.title
                                  .w(700)
                                  .copyWith(color: c.onPrimaryContainer),
                            ),
                            const SizedBox(height: AppSpacing.s1),
                            for (final line in lines)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  line,
                                  style: context.text.bodySmall.copyWith(
                                    color: c.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.s2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    l.w2yMonthInsights,
                                    style: context.text.bodySmall
                                        .w(700)
                                        .copyWith(color: c.onPrimaryContainer),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s1),
                                Icon(AppIcons.chevronRight, size: 14, color: c.onPrimaryContainer),
                              ],
                            ),
                            if (summary.unsynced) ...[
                              const SizedBox(height: AppSpacing.s2),
                              const SyncMarker(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.s1,
              right: AppSpacing.s1,
              child: AppIconButton(
                key: const Key('month-summary-hide'),
                tooltip: l.w2yMonthHide,
                icon: Icon(AppIcons.close, size: 18, color: c.onPrimaryContainer),
                onPressed: () =>
                    unawaited(ref.read(hiddenMonthSummaryProvider.notifier).hide(summary.key)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
