import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart'
    show expenseGroupProvider;
import 'package:splitify/features/currency/domain/conversion.dart';
import 'package:splitify/features/currency/presentation/conversion_sheet.dart';
import 'package:splitify/features/currency/presentation/fx_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Detail-screen row for a record in another currency than its group's (#32): "Convert to INR", or the
/// saved conversion "In INR · ₹8,964.37" with "1 USD = 89.6437 INR · Frankfurter · 20 Nov 2026"; tap opens
/// the conversion sheet. Nothing for records already in the group's currency.
class ConversionTile extends ConsumerWidget {
  const ConversionTile({
    required this.recordId,
    required this.groupId,
    required this.currency,
    required this.saved,
    this.payment = false,
    super.key,
  });

  final String recordId;
  final String groupId;

  /// The record's currency.
  final String currency;

  /// Its saved conversion, if any.
  final SavedFx? saved;
  final bool payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final main = ref.watch(expenseGroupProvider(groupId)).value?.mainCurrency.trim();
    if (main == null || main == currency) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final s = saved;
    void open() =>
        unawaited(showConversionSheet(context, recordId: recordId, payment: payment, to: main));
    if (s == null || s.currency != main) {
      return DashedListRow(
        key: const Key('conversion-tile'),
        icon: AppIcons.swap,
        label: l.fxConvertTo(main),
        onTap: open,
      );
    }
    final amount = MoneyFormatter.detail.format(s.total, s.currency);
    final caption =
        '${rateLine(l, currency, s.currency, s.rate)} · '
        '${sourceLine(context, s.asRate(currency))}';
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final amountText = Text(
      amount,
      key: const Key('conversion-tile-amount'),
      style: context.text.amount.copyWith(color: c.primary),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '${l.fxInCurrency(main)}, $amount, $caption',
          excludeSemantics: true,
          onTap: open,
          child: InkWell(
            key: const Key('conversion-tile'),
            onTap: open,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                child: Row(
                  children: [
                    Icon(AppIcons.swap, size: 24, color: c.textPrimary),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.fxInCurrency(main), style: context.text.body.w(600)),
                          const SizedBox(height: 2),
                          Text(
                            caption,
                            style: context.text.caption.copyWith(color: c.textSecondary),
                          ),
                          if (large) ...[const SizedBox(height: AppSpacing.s1), amountText],
                        ],
                      ),
                    ),
                    if (!large) ...[const SizedBox(width: AppSpacing.s3), amountText],
                    const SizedBox(width: AppSpacing.s3),
                    Icon(AppIcons.chevronRight, size: 18, color: c.textPrimary),
                  ],
                ),
              ),
            ),
          ),
        ),
        const DashedDivider(),
      ],
    );
  }
}
