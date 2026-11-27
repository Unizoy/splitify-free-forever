// D-033 minimal money movement: Record a payment (all of the debt, part, more, nothing owed, Pay via UPI,
// edit, the inline error, offline), its method sheet, the group Settle up sheet, Record a loan (new,
// filled, borrowed, between two others, the error, who-lent-whom sheet), the compact payment detail and
// the default split sheet — light and dark at text 1.0 and 2.0, plus a small phone (360 × 640).
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/core/money/split.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/default_split_controller.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/application/loan_draft.dart';
import 'package:splitify/features/expenses/application/loan_editor_controller.dart';
import 'package:splitify/features/expenses/application/split_draft.dart';
import 'package:splitify/features/expenses/presentation/default_split_sheet.dart';
import 'package:splitify/features/expenses/presentation/loan_screen.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';
import 'package:splitify/features/payments/presentation/settle_picker.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../features/balances/balance_fixtures.dart';
import '../features/expenses/expense_fixtures.dart' show FixedDefaultSplitController, ids, people;
import '../features/expenses/presentation/loan_screen_test.dart'
    show FixedLoanController, newLoan, editLoan, sampleLoan;
import 'golden_support.dart';

const SettleArgs _upiArgs = (groupId: gid, from: 'm1', to: 'm2', currency: 'INR', paymentId: null);
const SettleArgs _editArgs = (groupId: '', from: null, to: null, currency: null, paymentId: 'p1');

/// I owe Asha ₹500 (she has a UPI ID).
GroupBalances _oweAsha() => GroupBalances(
  groupId: gid,
  groupName: 'Goa trip',
  mainCurrency: 'INR',
  members: goaMembers(),
  byCurrency: const {
    'INR': Balances(
      nets: {'m1': -50000, 'm2': 50000, 'm3': 0, 'm4': 0},
      pairs: [Transfer('m1', 'm2', 50000)],
      simplified: [Transfer('m1', 'm2', 50000)],
    ),
  },
  meId: 'm1',
  hasRecords: true,
);

List<Override> _settle(SettleArgs args, SettleDraft d) => [
  settleProvider(args).overrideWith(() => FixedSettleController(args, d)),
  upiIdProvider('u2').overrideWith((ref) => Stream.value('asha@okaxis')),
  upiIdProvider('u1').overrideWith((ref) => Stream.value(null)),
];

List<Override> _loan(LoanEditorArgs args, LoanDraft d) => [
  loanEditorProvider(args).overrideWith(() => FixedLoanController(args, d)),
];

List<Override> _detail(PaymentView v) => [
  paymentViewProvider(v.payment.id).overrideWithValue(AsyncData(v)),
  expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
  commentThreadProvider((groupId: gid, targetType: 'payment', targetId: v.payment.id))
      .overrideWithValue(const AsyncData([])),
];

/// Pumps like [pumpFixedFrames], runs [act] (press Save) and lets it settle.
Future<void> Function(WidgetTester) _after(Future<void> Function(WidgetTester t) act) => (t) async {
  await t.pump();
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await act(t);
  await t.pump();
  await t.pump(const Duration(milliseconds: 1500));
  await t.pump(const Duration(milliseconds: 100));
  // The error state moves the focus to the amount: no keyboard in a golden.
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pump();
  await expectA11y(t);
};

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pump();
}

/// A sheet body at the bottom of a dimmed screen, like the real modal sheet (D-032 golden pattern).
class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.title, required this.child});

  final String Function(AppLocalizations l) title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.scrim,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: title(AppLocalizations.of(context)), child: child),
    ),
  );
}

typedef _Case = (
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  Future<void> Function(WidgetTester)? pump,
);

List<_Case> _cases() {
  const settleScreen = SettleUpScreen(groupId: gid, from: 'm1', to: 'm3', currency: 'INR');
  const upiScreen = SettleUpScreen(groupId: gid, from: 'm1', to: 'm2', currency: 'INR');
  final shares = SplitDraft.initial(
    ids,
    2,
  ).withValues(SplitKind.shares, {'m1': 2000, 'm2': 1000, 'm3': 1000, 'm4': 1000});
  return [
    ('settle_all', () => settleScreen, () => _settle(settleArgs, sampleSettleDraft()), null),
    (
      'settle_part',
      () => settleScreen,
      () => _settle(settleArgs, sampleSettleDraft(amountText: '150', note: 'Thanks for the cab')),
      null,
    ),
    (
      'settle_more',
      () => settleScreen,
      () => _settle(settleArgs, sampleSettleDraft(amountText: '500', method: 'bank')),
      null,
    ),
    (
      'settle_nothing_owed',
      // Offline: the group chip says the payment stays on this phone for now.
      () => ProviderScope(
        overrides: [syncOfflineProvider.overrideWith((ref) => Stream.value(true))],
        child: settleScreen,
      ),
      () => _settle(settleArgs, sampleSettleDraft(to: 'm4', amountText: '')),
      null,
    ),
    (
      'settle_upi',
      () => upiScreen,
      () => _settle(_upiArgs, sampleSettleDraft(to: 'm2', amountText: '500', balances: _oweAsha())),
      null,
    ),
    (
      'settle_edit',
      () => const SettleUpScreen(paymentId: 'p1'),
      () => _settle(
        _editArgs,
        sampleSettleDraft(
          from: 'm2',
          to: 'm1',
          amountText: '500',
          method: 'upi',
          note: 'Thanks for the cab',
          paymentId: 'p1',
        ),
      ),
      null,
    ),
    (
      'settle_error',
      () => settleScreen,
      () => _settle(settleArgs, sampleSettleDraft(to: 'm4', amountText: '')),
      _after((t) => _tap(t, 'settle-save')),
    ),
    (
      'settle_method_sheet',
      () => _SheetHost(
        title: (l) => l.settleMethodTitle,
        child: PaymentMethodOptions(currency: 'INR', selected: 'cash', onPicked: (_) {}),
      ),
      () => const [],
      null,
    ),
    (
      'settle_picker',
      () => _SheetHost(
        title: (l) => l.settleUp,
        child: GroupSettlePicker(groupId: gid, open: (_) {}),
      ),
      () => [groupBalancesProvider(gid).overrideWithValue(AsyncData(goaMixed()))],
      null,
    ),
    (
      'payment_detail',
      () => const PaymentDetailScreen(paymentId: 'p1'),
      () => _detail(paymentView()),
      null,
    ),
    (
      'payment_detail_unsynced',
      () => const PaymentDetailScreen(paymentId: 'p2'),
      () => _detail(samplePayments()[1]),
      null,
    ),
    ('loan_new', () => const LoanScreen(groupId: gid), () => _loan(newLoan, sampleLoan()), null),
    (
      'loan_filled',
      () => const LoanScreen(groupId: gid),
      () => _loan(newLoan, sampleLoan(person: 'm2', amount: '500', note: 'Cab money')),
      null,
    ),
    (
      'loan_borrowed',
      () => const LoanScreen(expenseId: 'l1'),
      () => _loan(
        editLoan,
        sampleLoan(
          direction: LoanDirection.borrowed,
          person: 'm2',
          amount: '2000',
          note: 'Rent share',
          expenseId: 'l1',
        ),
      ),
      null,
    ),
    (
      'loan_others',
      () => const LoanScreen(expenseId: 'l1'),
      () => _loan(
        editLoan,
        sampleLoan(self: 'm2', selfIsMe: false, person: 'm3', amount: '750', expenseId: 'l1'),
      ),
      null,
    ),
    (
      'loan_error',
      () => const LoanScreen(groupId: gid),
      () => _loan(newLoan, sampleLoan()),
      _after((t) async {
        await _tap(t, 'loan-save');
        // The who sheet opens after the amount: only the inline errors are wanted here.
      }),
    ),
    (
      'loan_who_sheet',
      () => _SheetHost(
        title: (l) => l.loanWhoTitle,
        child: LoanWhoPanel(
          draft: sampleLoan(person: 'm2', amount: '500'),
          showErrors: false,
          onDirection: (_) {},
          onPerson: (_) {},
          onDone: () {},
        ),
      ),
      () => const [],
      null,
    ),
    (
      'default_split_sheet',
      () => _SheetHost(
        title: (l) => l.expDefaultSplitTitle,
        child: DefaultSplitSheet(groupId: gid, onSaved: () {}),
      ),
      () => [
        defaultSplitProvider(gid).overrideWith(
          () => FixedDefaultSplitController(
            gid,
            DefaultSplitState(groupName: 'Goa trip', members: people, split: shares),
          ),
        ),
      ],
      null,
    ),
  ];
}

void main() {
  for (final (name, screen, overrides, pump) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'minimal pay $name ${mode.name} $suffix',
          fileName: 'minimal_pay_${name}_${mode.name}_$suffix',
          pumpBeforeTest: pump ?? pumpFixedFrames,
          builder: () => expenseApp(screen(), overrides: overrides(), mode: mode, scale: scale),
        );
      }
    }
  }

  // A small phone: everything still fits or scrolls, the action stays on screen.
  for (final name in ['settle_part', 'settle_upi', 'loan_filled', 'payment_detail']) {
    final (_, screen, overrides, pump) = _cases().firstWhere((c) => c.$1 == name);
    goldenTest(
      'minimal pay $name small phone',
      fileName: 'minimal_pay_${name}_small_light_text100',
      pumpBeforeTest: pump ?? pumpFixedFrames,
      builder: () => expenseApp(screen(), overrides: overrides(), size: const Size(360, 640)),
    );
  }
}
