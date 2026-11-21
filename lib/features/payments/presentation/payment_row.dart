import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart' show parseIsoDate;
import 'package:splitify/features/expenses/presentation/expense_copy.dart' show dayMonth;
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// A payment in the group's Expenses tab (07 §2): slim row "Asha paid you · ₹500" with the
/// payment icon, "you paid" / "you received" on the right and the "not synced yet" marker.
class PaymentRow extends StatelessWidget {
  const PaymentRow({required this.view, this.showDivider = true, super.key});

  final PaymentView view;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = view.payment;
    String name(String id, {bool start = true}) {
      if (id == view.meId) return start ? l.you : l.youLower;
      final n = view.nameOf(id);
      return n.isEmpty ? l.someone : n;
    }

    return AmountRow(
      key: ValueKey('payment-${p.id}'),
      title: l.settlePaidSentence(name(p.fromMember), name(p.toMember, start: false)),
      caption: l.payRowCaption(dayMonth(context, parseIsoDate(p.date))),
      amountText: listMoney(p.amount, p.currency.trim()),
      amountCaption: view.iPaid
          ? l.payYouPaid
          : view.iReceived
          ? l.payYouReceived
          : l.expNotInvolved,
      unsynced: view.unsynced,
      showDivider: showDivider,
      leading: TintedIcon(icon: AppIcons.payment, color: context.colors.owedAccent, size: 44),
      onTap: () => unawaited(context.push(PaymentRoutes.detail(p.id))),
    );
  }
}
