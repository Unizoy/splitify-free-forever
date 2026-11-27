import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';
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

  /// Records shown at first and added by each "Show older".
  static const pageSize = 100;

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
          // The group page's bar has Add expense: no second button here (D-033).
          message: l.expNoExpensesBody,
        ),
      ),
      AsyncData(:final value) => EntranceScope(
        child: _Rows(views: value, payments: payments),
      ),
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

/// The newest [ExpenseList.pageSize] records, then "Show older" adds a page. [ExpenseList] builds every shown
/// row (it sits in a plain column); [ExpenseListSliver] builds only the rows on screen (S-167, phase 19).
/// Once everyone is settled up in every currency, the records up to the last settle-up fold into one
/// "Show N settled expenses" row (D-034 C2, worked out on the phone from these same rows); search and export
/// read their own lists, so they still see everything.
class _Rows extends StatefulWidget {
  const _Rows({required this.views, this.payments = const [], this.sliver = false});

  final List<ExpenseView> views;
  final List<PaymentView> payments;
  final bool sliver;

  @override
  State<_Rows> createState() => _RowsState();
}

class _RowsState extends State<_Rows> {
  int _limit = ExpenseList.pageSize;

  /// The settled history is unfolded.
  bool _showSettled = false;

  /// Ids of the records behind "Show settled expenses" (empty while any balance is open).
  Set<String> _settled() => settledHistoryIds([
    for (final v in widget.views)
      (
        id: v.expense.id,
        date: v.expense.date,
        createdAt: v.expense.createdAt,
        currency: v.expense.currency.trim(),
        deltas: expenseDeltas(v.paid, v.owed),
      ),
    for (final v in widget.payments)
      (
        id: v.payment.id,
        date: v.payment.date,
        createdAt: v.payment.createdAt,
        currency: v.payment.currency.trim(),
        deltas: paymentDeltas(v.payment.fromMember, v.payment.toMember, v.payment.amount),
      ),
  ]);

  /// Month headers, rows and the "Show older" button, in order, built only when asked for.
  List<WidgetBuilder> _entries(BuildContext context) {
    final views = widget.views;
    final payments = widget.payments;
    // Expenses and payments by date, newest first (both lists already are; merge keeps that).
    final settled = _settled();
    final fold = settled.isNotEmpty && !_showSettled;
    final items = <(String date, Widget Function(bool divider) row)>[];
    var e = 0;
    var p = 0;
    while (e < views.length || p < payments.length) {
      final takeExpense =
          p >= payments.length ||
          (e < views.length && views[e].expense.date.compareTo(payments[p].payment.date) >= 0);
      if (takeExpense) {
        final v = views[e++];
        if (fold && settled.contains(v.expense.id)) continue;
        items.add((v.expense.date, (d) => ExpenseRow(view: v, showDivider: d, hero: true)));
      } else {
        final v = payments[p++];
        if (fold && settled.contains(v.payment.id)) continue;
        items.add((v.payment.date, (d) => PaymentRow(view: v, showDivider: d)));
      }
    }
    final entries = <WidgetBuilder>[];
    final shown = items.length < _limit ? items.length : _limit;
    final headers = [
      for (var i = 0; i < items.length && i <= shown; i++)
        monthHeader(context, parseIsoDate(items[i].$1)),
    ];
    String? month;
    for (var i = 0; i < shown; i++) {
      final header = headers[i];
      if (header != month) {
        month = header;
        final first = i == 0;
        entries.add((_) => _MonthHeader(text: header, first: first));
      }
      final divider = i + 1 < shown && headers[i + 1] == header;
      final row = items[i].$2;
      entries.add((_) => row(divider));
    }
    final hidden = items.length - shown;
    if (hidden > 0) {
      entries.add(
        (context) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s4),
          child: PillButton(
            key: const Key('expenses-show-older'),
            label: AppLocalizations.of(context).expShowOlder(hidden),
            icon: AppIcons.chevronDown,
            variant: PillVariant.outline,
            size: PillSize.medium,
            onPressed: () => setState(() => _limit += ExpenseList.pageSize),
          ),
        ),
      );
    }
    if (settled.isNotEmpty && hidden <= 0) {
      entries.add(
        (context) => Padding(
          padding: EdgeInsets.only(top: items.isEmpty ? 0 : AppSpacing.s4),
          child: _SettledRow(
            count: settled.length,
            open: _showSettled,
            onTap: () => setState(() => _showSettled = !_showSettled),
          ),
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries(context);
    if (widget.sliver) {
      return SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) => Entrance(index: i, child: entries[i](context)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, build) in entries.indexed) Entrance(index: i, child: build(context)),
      ],
    );
  }
}

/// [ExpenseList] as a sliver for the group page's [CustomScrollView]: the same states, but rows are built
/// lazily as they scroll in, so opening a group with thousands of records costs one screen of rows.
class ExpenseListSliver extends ConsumerWidget {
  const ExpenseListSliver({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(groupExpenseViewsProvider(groupId));
    final payments = ref.watch(groupPaymentViewsProvider(groupId)).value ?? const <PaymentView>[];
    return switch (views) {
      // The first rows rise in once when the list shows (S-265); later rebuilds just appear.
      AsyncData(:final value) when value.isNotEmpty || payments.isNotEmpty => EntranceScope(
        child: _Rows(views: value, payments: payments, sliver: true),
      ),
      _ => SliverToBoxAdapter(child: ExpenseList(groupId: groupId)),
    };
  }
}

/// "Show 5 settled expenses" (D-034 C2) / "Hide settled expenses" at the end of the list.
class _SettledRow extends StatelessWidget {
  const _SettledRow({required this.count, required this.open, required this.onTap});

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DashedListRow(
      key: const Key('expenses-settled'),
      icon: AppIcons.checkCircle,
      label: open ? l.groupSettledHide : l.groupSettledShow(count),
      showDivider: false,
      onTap: onTap,
    );
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
  const ExpenseRow({
    required this.view,
    this.showDivider = true,
    this.groupName,
    this.hero = false,
    super.key,
  });

  final ExpenseView view;
  final bool showDivider;

  /// The icon flies into the expense page (one row per expense on the screen, e.g. the group list).
  final bool hero;

  /// Named in the caption when rows of several groups are listed (search results).
  final String? groupName;

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
      caption: [
        ?groupName,
        paidCaption(l, view),
        dayMonth(context, parseIsoDate(e.date)),
      ].join('\u00A0· '),
      amountText: amount,
      amountCaption: side,
      tone: tone,
      unsynced: view.unsynced,
      showDivider: showDivider,
      badge: view.isLoan
          ? TagChip(key: ValueKey('loan-chip-${e.id}'), label: l.loanChip)
          : e.source == 'recurring'
          ? TagChip(
              key: ValueKey('recurring-chip-${e.id}'),
              label: l.recurringChip,
              icon: AppIcons.repeat,
            )
          : (e.receiptPath == null
                ? null
                : Semantics(
                    label: l.receiptOnList,
                    child: Icon(AppIcons.image, size: 16, color: context.colors.textTertiary),
                  )),
      leading: _heroIcon(
        hero ? AppHeroTags.expense(e.id) : null,
        view.isLoan
            ? TintedIcon(icon: AppIcons.loanFill, color: context.colors.primary, size: 44)
            : TintedIcon.category(categoryOf(e.category), size: 44),
      ),
      // The row's view goes along, so the detail page draws (and its icon hero flies) on the first frame.
      onTap: () => unawaited(context.push(ExpenseRoutes.detail(e.id), extra: view)),
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
      child: Shimmer(
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
      ),
    );
  }
}

Widget _heroIcon(Object? tag, Widget icon) => tag == null ? icon : Hero(tag: tag, child: icon);
