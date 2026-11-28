import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/history/application/deleted_items_providers.dart';
import 'package:splitify/features/history/application/history_providers.dart';
import 'package:splitify/features/history/presentation/deleted_items_screen.dart';
import 'package:splitify/features/history/presentation/history_screen.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';

import '../features/expenses/expense_fixtures.dart';
import '../features/history/presentation/history_fixtures.dart';
import '../support/attachment_fixtures.dart';
import 'golden_support.dart';

/// One golden scenario: the screen, its overrides and the frame height at text scale 1.0.
typedef _Case = (String name, Widget screen, List<Override> overrides, double height);

List<Override> _history(HistoryTarget t, HistoryView view, {bool offline = false}) => [
  historyViewProvider(t).overrideWithValue(AsyncData(view)),
  historyFetchProvider(t).overrideWith((ref) async {
    if (offline) throw Exception('offline');
    return 0;
  }),
];

List<_Case> _cases() => [
  (
    'history_timeline',
    const HistoryScreen(target: expenseTarget),
    _history(expenseTarget, historyView(versions: fullExpenseVersions())),
    2400,
  ),
  (
    'history_payment',
    const HistoryScreen(target: paymentTarget),
    _history(paymentTarget, historyView(target: paymentTarget, versions: paymentVersions())),
    1100,
  ),
  (
    'history_offline',
    const HistoryScreen(target: expenseTarget),
    _history(expenseTarget, historyView(), offline: true),
    915,
  ),
  (
    'history_pending_empty',
    const HistoryScreen(target: expenseTarget),
    _history(expenseTarget, historyView(pending: true)),
    915,
  ),
  (
    'deleted_items',
    const DeletedItemsScreen(groupId: gid),
    [
      deletedItemsProvider(gid).overrideWithValue(AsyncData(sampleDeleted())),
      groupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
    ],
    915,
  ),
  (
    'deleted_items_empty',
    const DeletedItemsScreen(groupId: gid),
    [
      deletedItemsProvider(gid)
          .overrideWithValue(const AsyncData((items: [], memberNames: {}, meMemberId: null))),
      groupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
    ],
    915,
  ),
  (
    'expense_detail_comments',
    const ExpenseDetailScreen(expenseId: 'e1'),
    [
      noRepeat('e1'),
      noAttachments('e1'),
      expenseViewProvider('e1').overrideWithValue(
        AsyncData(sampleView(sampleExpense(notes: 'Table by the window, paid by card.'))),
      ),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'e1'))
          .overrideWithValue(AsyncData(sampleThread())),
    ],
    1500,
  ),
  (
    'payment_detail_comments',
    const PaymentDetailScreen(paymentId: 'p1'),
    [
      paymentViewProvider('p1').overrideWithValue(
        AsyncData(PaymentView(payment: samplePayment(), names: memberNames, meId: me)),
      ),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      commentThreadProvider((groupId: gid, targetType: 'payment', targetId: 'p1'))
          .overrideWithValue(AsyncData(sampleThread())),
    ],
    1300,
  ),
];

void main() {
  // TC-20-03, TC-20-04, TC-13-04: edit history, deleted items and the comment thread in light and dark at
  // text scale 1.0 and 2.0.
  for (final (name, screen, overrides, height) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'history screen $name ${mode.name} $suffix',
          fileName: '${name.startsWith('history_') ? '' : 'history_'}${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(
            screen,
            overrides: overrides,
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, scale > 1 ? height * 1.8 : height),
          ),
        );
      }
    }
  }
}
