// Emulator UI review for phase 12: edit history, deleted items and the comment thread with sample data
// (no sign-in, no network). Prints `UI-CAPTURE <name>` and holds each screen for `UI_HOLD` seconds while
// `.claude/skills/ui-review/scripts/capture_markers.ps1` takes light, dark and 200 % text screenshots.
// `UI_ONLY=history-timeline,deleted-items` holds only those screens.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../test/features/expenses/expense_fixtures.dart';
import '../test/features/history/presentation/history_fixtures.dart';

/// Seconds each screen stays up for the host captures (`UI_HOLD`, 0 = no hold).
const _hold = int.fromEnvironment('UI_HOLD');

/// Hold only these screens (comma-separated names).
const _only = String.fromEnvironment('UI_ONLY');

List<Override> _history(HistoryTarget t, HistoryView view, {bool offline = false}) => [
  historyViewProvider(t).overrideWithValue(AsyncData(view)),
  historyFetchProvider(t).overrideWith((ref) async {
    if (offline) throw Exception('offline');
    return 0;
  }),
];

List<(String, Widget, List<Override>)> _screens() => [
  (
    'history-timeline',
    const HistoryScreen(target: expenseTarget),
    _history(expenseTarget, historyView(versions: fullExpenseVersions())),
  ),
  (
    'history-offline',
    const HistoryScreen(target: expenseTarget),
    _history(expenseTarget, historyView(), offline: true),
  ),
  (
    'deleted-items',
    const DeletedItemsScreen(groupId: gid),
    [
      deletedItemsProvider(gid).overrideWithValue(AsyncData(sampleDeleted())),
      groupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
    ],
  ),
  (
    'deleted-items-empty',
    const DeletedItemsScreen(groupId: gid),
    [
      deletedItemsProvider(gid)
          .overrideWithValue(const AsyncData((items: [], memberNames: {}, meMemberId: null))),
      groupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
    ],
  ),
  (
    'expense-comments',
    const ExpenseDetailScreen(expenseId: 'e1'),
    [
      expenseViewProvider('e1').overrideWithValue(
        AsyncData(sampleView(sampleExpense(notes: 'Table by the window, paid by card.'))),
      ),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      commentThreadProvider((groupId: gid, targetType: 'expense', targetId: 'e1'))
          .overrideWithValue(AsyncData(sampleThread())),
    ],
  ),
  (
    'payment-comments',
    const PaymentDetailScreen(paymentId: 'p1'),
    [
      paymentViewProvider('p1').overrideWithValue(
        AsyncData(PaymentView(payment: samplePayment(), names: memberNames, meId: me)),
      ),
      expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      commentThreadProvider((groupId: gid, targetType: 'payment', targetId: 'p1'))
          .overrideWithValue(AsyncData(sampleThread())),
    ],
  ),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI review: history, deleted items and comments', (t) async {
    for (final (name, screen, overrides) in _screens()) {
      if (_hold == 0 || (_only.isNotEmpty && !_only.split(',').contains(name))) continue;
      await t.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [...baseOverrides(), ...overrides],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            debugShowCheckedModeBanner: false,
            home: screen,
          ),
        ),
      );
      final settle = DateTime.now().add(const Duration(seconds: 2));
      while (DateTime.now().isBefore(settle)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await t.pump();
      }
      debugPrint('UI-CAPTURE $name');
      final end = DateTime.now().add(const Duration(seconds: _hold));
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await t.pump();
      }
    }
  });
}
