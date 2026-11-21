import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The group's Expenses tab (07 §2): month headers, one [AmountRow] per expense ("you lent ₹400" /
/// "you borrowed ₹300" / "not involved") and the "not synced yet" marker on pending rows. Not
/// scrollable itself, so it can sit inside the group's overlap sheet.
class ExpenseList extends ConsumerWidget {
  const ExpenseList({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final views = ref.watch(groupExpenseViewsProvider(groupId));
    return switch (views) {
      AsyncData(:final value) when value.isEmpty => Padding(
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
      AsyncData(:final value) => _Rows(views: value),
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
  const _Rows({required this.views});

  final List<ExpenseView> views;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? month;
    for (var i = 0; i < views.length; i++) {
      final date = parseIsoDate(views[i].expense.date);
      final header = monthHeader(context, date);
      if (header != month) {
        month = header;
        children.add(_MonthHeader(text: header, first: i == 0));
      }
      final nextSameMonth =
          i + 1 < views.length &&
          monthHeader(context, parseIsoDate(views[i + 1].expense.date)) == header;
      children.add(ExpenseRow(view: views[i], showDivider: nextSameMonth));
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
    final net = view.myNet;
    final (tone, amount, side) = switch (net) {
      > 0 => (MoneyTone.owed, money(net), l.expYouLent),
      < 0 => (MoneyTone.owe, money(-net), l.expYouBorrowed),
      _ => (MoneyTone.settled, '', view.involved ? l.expNoBalance : l.expNotInvolved),
    };
    return AmountRow(
      key: ValueKey('expense-${e.id}'),
      title: e.description,
      caption: '${paidCaption(l, view)} · ${dayMonth(context, parseIsoDate(e.date))}',
      amountText: amount,
      amountCaption: side,
      tone: tone,
      unsynced: view.unsynced,
      showDivider: showDivider,
      badge: view.isLoan
          ? TagChip(key: ValueKey('loan-chip-${e.id}'), label: l.loanChip)
          : (e.receiptPath == null
                ? null
                : Semantics(
                    label: l.receiptOnList,
                    child: Icon(AppIcons.image, size: 16, color: context.colors.textTertiary),
                  )),
      leading: view.isLoan
          ? TintedIcon(icon: AppIcons.loanFill, color: context.colors.primary, size: 44)
          : TintedIcon.category(categoryOf(e.category), size: 44),
      onTap: () => unawaited(context.push(ExpenseRoutes.detail(e.id))),
    );
  }
}

/// "Rahul paid ₹1,200", "You and Asha paid ₹1,200", "3 people paid ₹1,200"; loans read
/// "You lent Asha ₹500" (#10, #11).
String paidCaption(AppLocalizations l, ExpenseView view) {
  final e = view.expense;
  final amount = MoneyFormatter.list.format(e.total, e.currency);
  String name(String id, {bool capital = true}) =>
      id == view.meId ? (capital ? l.you : l.expYouLower) : view.nameOf(id);
  if (view.isLoan && view.lender != null && view.borrower != null) {
    return l.loanCaption(name(view.lender!), name(view.borrower!, capital: false), amount);
  }
  final payers = [
    ...view.paid.keys.where((id) => id == view.meId),
    ...view.paid.keys.where((id) => id != view.meId),
  ];
  return switch (payers.length) {
    1 => l.expPaidCaption(name(payers.first), amount),
    2 => l.payersCaption(l.payersTwo(name(payers[0]), name(payers[1], capital: false)), amount),
    _ => l.expSeveralPaidCaption(payers.length, amount),
  };
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
