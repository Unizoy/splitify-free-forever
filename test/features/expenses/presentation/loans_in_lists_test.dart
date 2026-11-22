// TC-11-02 / TC-10-02 / TC-29 UI: loans, multi-payer and receipt expenses in the list and the detail screen,
// plus the TagChip and AmountRow badge components.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_detail_screen.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/photo_fixtures.dart';
import '../expense_fixtures.dart';
import 'presentation_harness.dart';

Finder _key(String k) => find.byKey(Key(k));

class _ListHost extends StatelessWidget {
  const _ListHost();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(child: ExpenseList(groupId: gid)),
    ),
  );
}

/// IOU row: [lender] lent [borrower] [total] (minor units).
LocalExpense sampleLoanRow({
  String id = 'l1',
  String lender = 'm1',
  String borrower = 'm2',
  int total = 50000,
  String description = 'Cab money',
  String date = '2026-11-20',
}) => sampleExpense(
  id: id,
  description: description,
  date: date,
  total: total,
  payers: {lender: total},
  shares: {borrower: total},
).copyWith(kind: 'iou', category: 'other.general');

Future<GoRouter> _pumpList(WidgetTester t, List<ExpenseView> views) async {
  usePhone(t);
  await t.pumpWidget(const SizedBox());
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _ListHost()),
      stubRoute('/expense/:id'),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    routerApp(
      router,
      overrides: [groupExpenseViewsProvider(gid).overrideWithValue(AsyncData(views))],
    ),
  );
  await settle(t);
  return router;
}

Future<GoRouter> _pumpDetail(WidgetTester t, LocalExpense e) async {
  usePhone(t);
  await t.pumpWidget(const SizedBox());
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => ExpenseDetailScreen(expenseId: e.id),
      ),
      stubRoute('/loan/:id/edit'),
      stubRoute('/expense/:id/edit'),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    routerApp(
      router,
      overrides: [
        expenseViewProvider(e.id).overrideWithValue(AsyncData(sampleView(e))),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
      ],
    ),
  );
  await settle(t);
  return router;
}

void main() {
  group('Expense list rows', () {
    // TC-11-02
    testWidgets('a loan row has the LOAN chip and "You lent Asha Rao ₹500\u00A0· date"', (t) async {
      await _pumpList(t, [sampleView(sampleLoanRow())]);
      expect(_key('loan-chip-l1'), findsOneWidget);
      expect(find.text('LOAN'), findsOneWidget);
      expect(find.text('Cab money'), findsOneWidget);
      expect(find.text('You lent Asha Rao ₹500\u00A0· 20\u00A0Nov'), findsOneWidget);
      expect(find.text('you lent'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('a loan I borrowed reads "Asha Rao lent you ₹500" and "you borrowed"', (t) async {
      await _pumpList(t, [sampleView(sampleLoanRow(lender: 'm2', borrower: 'm1'))]);
      expect(find.text('Asha Rao lent you ₹500\u00A0· 20\u00A0Nov'), findsOneWidget);
      expect(find.text('you borrowed'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('a loan between two others names both and is not mine', (t) async {
      await _pumpList(t, [sampleView(sampleLoanRow(lender: 'm2', borrower: 'm3'))]);
      expect(find.text('Asha Rao lent Rahul Mehta ₹500\u00A0· 20\u00A0Nov'), findsOneWidget);
      expect(find.text('not involved'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('ordinary expenses have no LOAN chip', (t) async {
      await _pumpList(t, [sampleView(sampleExpense())]);
      expect(find.text('LOAN'), findsNothing);
    });

    // TC-10-02
    testWidgets('two payers: "You and Asha Rao paid ₹1,200"', (t) async {
      await _pumpList(t, [
        sampleView(sampleExpense(payers: const {'m1': 70000, 'm2': 50000}, total: 120000)),
      ]);
      expect(find.text('You and Asha Rao paid ₹1,200\u00A0· 20\u00A0Nov'), findsOneWidget);
    });

    // TC-10-02
    testWidgets('two payers without me: both named', (t) async {
      await _pumpList(t, [
        sampleView(sampleExpense(payers: const {'m2': 70000, 'm3': 50000}, total: 120000)),
      ]);
      expect(find.text('Asha Rao and Rahul Mehta paid ₹1,200\u00A0· 20\u00A0Nov'), findsOneWidget);
    });

    // TC-10-02
    testWidgets('three or more payers: "3 people paid ₹1,200"', (t) async {
      await _pumpList(t, [
        sampleView(
          sampleExpense(payers: const {'m1': 40000, 'm2': 40000, 'm3': 40000}, total: 120000),
        ),
      ]);
      expect(find.text('3 people paid ₹1,200\u00A0· 20\u00A0Nov'), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('a receipt expense shows the image badge, others do not', (t) async {
      await _pumpList(t, [
        sampleView(sampleExpense().copyWith(receiptPath: const Value('g/e/r.jpg'))),
      ]);
      expect(find.byIcon(AppIcons.image), findsOneWidget);
    });

    // TC-29 UI
    testWidgets('no badge without a receipt', (t) async {
      await _pumpList(t, [sampleView(sampleExpense())]);
      expect(find.byIcon(AppIcons.image), findsNothing);
    });

    // TC-11-02
    testWidgets('tapping a loan row opens its detail', (t) async {
      await _pumpList(t, [sampleView(sampleLoanRow())]);
      await t.tap(find.text('Cab money'));
      await settle(t);
      expect(textOf(_key('stub')), 'at /expense/l1');
    });
  });

  group('Expense detail for a loan', () {
    // TC-11-02
    testWidgets('shows LENT BY / BORROWED BY, the LOAN pill and the not-in-totals row', (t) async {
      await _pumpDetail(t, sampleLoanRow());
      expect(find.text('Cab money'), findsOneWidget);
      expect(find.textContaining('Loan'), findsWidgets);
      await reveal(t, find.text('LENT BY'));
      expect(find.text('LENT BY'), findsOneWidget);
      expect(find.text('BORROWED BY'), findsOneWidget);
      expect(find.text("Loans aren't counted in group totals."), findsOneWidget);
      // No split kind label for a loan.
      expect(find.textContaining('SPLIT'), findsNothing);
      expect(find.text('PAID BY'), findsNothing);
    });

    // TC-11-02
    testWidgets('an ordinary expense keeps PAID BY and has no loan note', (t) async {
      await _pumpDetail(t, sampleExpense());
      await reveal(t, find.text('PAID BY'));
      expect(find.text('PAID BY'), findsOneWidget);
      expect(find.text('LENT BY'), findsNothing);
      expect(find.text("Loans aren't counted in group totals."), findsNothing);
    });

    // TC-11-02
    testWidgets('the edit button of a loan opens /loan/<id>/edit', (t) async {
      await _pumpDetail(t, sampleLoanRow());
      await t.tap(_key('expense-edit'));
      await settle(t);
      expect(textOf(_key('stub')), 'at /loan/l1/edit');
    });

    // TC-11-02
    testWidgets('the edit button of an expense still opens /expense/<id>/edit', (t) async {
      await _pumpDetail(t, sampleExpense());
      await t.tap(_key('expense-edit'));
      await settle(t);
      expect(textOf(_key('stub')), 'at /expense/e1/edit');
    });

    // TC-29 UI
    testWidgets('an expense with a receipt shows the receipt card', (t) async {
      final file = samplePhotoFile(addTearDown);
      usePhone(t);
      final e = sampleExpense().copyWith(receiptPath: const Value('g/e/r.jpg'));
      await t.pumpWidget(
        expenseApp(
          const ExpenseDetailScreen(expenseId: 'e1'),
          overrides: [
            expenseViewProvider('e1').overrideWithValue(AsyncData(sampleView(e))),
            expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
            ...storedReceipt('g/e/r.jpg', file),
          ],
        ),
      );
      await settle(t);
      await reveal(t, _key('expense-receipt'));
      expect(_key('expense-receipt'), findsOneWidget);
    });
  });

  group('TagChip and AmountRow badge', () {
    Future<void> pump(WidgetTester t, Widget child) async {
      usePhone(t);
      await t.pumpWidget(expenseApp(Scaffold(body: Center(child: child))));
      await settle(t);
    }

    // TC-11-02
    testWidgets('TagChip upper-cases its label', (t) async {
      await pump(t, const TagChip(label: 'Loan'));
      expect(find.text('LOAN'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('TagChip with an icon shows it before the label', (t) async {
      await pump(t, const TagChip(label: 'Loan', icon: Icons.sync));
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.text('LOAN'), findsOneWidget);
    });

    // TC-11-02
    testWidgets('AmountRow shows the badge after the title and without one shows just the title', (
      t,
    ) async {
      await pump(t, const AmountRow(title: 'Cab', amountText: '₹1', badge: Text('BADGE')));
      expect(find.text('BADGE'), findsOneWidget);
      expect(find.text('Cab'), findsOneWidget);
      await pump(t, const AmountRow(title: 'Cab', amountText: '₹1'));
      expect(find.text('BADGE'), findsNothing);
      expect(find.text('Cab'), findsOneWidget);
    });
  });
}
