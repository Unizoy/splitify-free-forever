import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/presentation/payment_row.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The group's Expenses tab (07 §2): month headers, one [AmountRow] per expense ("you lent ₹400" /
/// "you borrowed ₹300" / "not involved"), payments as slim rows (phase 09) and the "not synced yet"
/// marker on pending rows. Not scrollable itself, so it can sit inside the group's overlap sheet.
class ExpenseList extends ConsumerWidget {
  const ExpenseList({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final views = ref.watch(groupExpenseViewsProvider(groupId));
    final payments = ref.watch(groupPaymentViewsProvider(groupId)).value ?? const <PaymentView>[];
    return switch (views) {
      AsyncData(:final value) when value.isEmpty && payments.isEmpty => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: EmptyState(
          icon: AppIcons.receipt,
          title: l.expNoExpensesTitle,
          message: l.expNoExpensesBody,
          actions: [
            PillButton(
              key: const Key('expenses-empty-add'),
              label: l.addExpense,
              icon: AppIcons.add,
              variant: PillVariant.money,
              expand: false,
              onPressed: () => unawaited(context.push(ExpenseRoutes.add(groupId))),
            ),
          ],
        ),
      ),
      AsyncData(:final value) => _Rows(views: value, payments: payments),
      AsyncError() => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        child: EmptyState(
          icon: AppIcons.warning,
          title: l.expLoadError,
          message: l.expLoadErrorBody,
        ),
      ),
      _ => const _Skeleton(),
    };
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.views, this.payments = const []});

  final List<ExpenseView> views;
  final List<PaymentView> payments;

  @override
  Widget build(BuildContext context) {
    // Expenses and payments by date, newest first (both lists already are; merge keeps that).
    final items = <(String date, Widget Function(bool divider) row)>[];
    var e = 0;
    var p = 0;
    while (e < views.length || p < payments.length) {
      final takeExpense =
          p >= payments.length ||
          (e < views.length && views[e].expense.date.compareTo(payments[p].payment.date) >= 0);
      if (takeExpense) {
        final v = views[e++];
        items.add((v.expense.date, (d) => ExpenseRow(view: v, showDivider: d)));
      } else {
        final v = payments[p++];
        items.add((v.payment.date, (d) => PaymentRow(view: v, showDivider: d)));
      }
    }
    final children = <Widget>[];
    String? month;
    for (var i = 0; i < items.length; i++) {
      final header = monthHeader(context, parseIsoDate(items[i].$1));
      if (header != month) {
        month = header;
        children.add(_MonthHeader(text: header, first: i == 0));
      }
      final nextSameMonth =
          i + 1 < items.length && monthHeader(context, parseIsoDate(items[i + 1].$1)) == header;
      children.add(items[i].$2(nextSameMonth));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.text, required this.first});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? AppSpacing.s2 : AppSpacing.s6, bottom: AppSpacing.s1),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
      ),
    ),
  );
}

/// One expense in the list: category circle, description, "Rahul paid ₹1,200 · 21 Nov", and the
/// viewer's side on the right.
class ExpenseRow extends StatelessWidget {
  const ExpenseRow({required this.view, this.showDivider = true, super.key});

  final ExpenseView view;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = view.expense;
    String money(int v) => MoneyFormatter.list.format(v, e.currency);
    final payer = view.singlePayer;
    final paidBy = payer == null
        ? l.expSeveralPaidCaption(view.paid.length, money(e.total))
        : l.expPaidCaption(payer == view.meId ? l.you : view.nameOf(payer), money(e.total));
    final net = view.myNet;
    final (tone, amount, side) = switch (net) {
      > 0 => (MoneyTone.owed, money(net), l.expYouLent),
      < 0 => (MoneyTone.owe, money(-net), l.expYouBorrowed),
      _ => (MoneyTone.settled, '', view.involved ? l.expNoBalance : l.expNotInvolved),
    };
    return AmountRow(
      key: ValueKey('expense-${e.id}'),
      title: e.description,
      caption: '$paidBy · ${dayMonth(context, parseIsoDate(e.date))}',
      amountText: amount,
      amountCaption: side,
      tone: tone,
      unsynced: view.unsynced,
      showDivider: showDivider,
      leading: TintedIcon.category(categoryOf(e.category), size: 44),
      onTap: () => unawaited(context.push(ExpenseRoutes.detail(e.id))),
    );
  }
}

/// Loading placeholder: three quiet rows in the list's shape.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(160, 14),
                        const SizedBox(height: AppSpacing.s2),
                        bar(110, 10),
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
