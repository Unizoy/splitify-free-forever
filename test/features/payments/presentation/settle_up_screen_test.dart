// TC-25-02 (settle-up form), plus the payment detail screen, payment rows in the Expenses tab and
// the two Settle up pickers (group sheet, Groups home sheet) of phase 09.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/local/app_database.dart' show LocalPayment;
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart' show TransferRow;
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';
import 'package:splitify/features/payments/presentation/payment_row.dart';
import 'package:splitify/features/payments/presentation/settle_picker.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart';
import 'package:splitify/features/payments/presentation/settled_celebration.dart';
import 'package:splitify/ui/components/components.dart';

import '../../balances/balance_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';

const SettleArgs _editArgs = (groupId: '', from: null, to: null, currency: null, paymentId: 'p1');

class _NotFoundSettle extends SettleController {
  _NotFoundSettle(super.args);

  @override
  Future<SettleDraft> build() async => throw const SettleNotFound();
}

class _LoadingSettle extends SettleController {
  _LoadingSettle(super.args);

  @override
  Future<SettleDraft> build() => Completer<SettleDraft>().future;
}

class _Handle {
  FixedSettleController? controller;

  SettleDraft get draft => controller!.state.value!;
}

SettleUpScreen _screen(SettleArgs a) => SettleUpScreen(
  groupId: a.groupId,
  from: a.from,
  to: a.to,
  currency: a.currency,
  paymentId: a.paymentId,
);

/// The screen under a router (Settle up reads GoRouter when it saves), with a stub for the group.
Widget _app(Widget host, List<Override> overrides) => routerApp(
  GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => host),
      stubRoute('/groups/:id'),
    ],
  ),
  overrides: overrides,
);

Future<_Handle> _pump(
  WidgetTester t, {
  SettleDraft? draft,
  SettleArgs args = settleArgs,
  double scale = 1,
}) async {
  usePhone(t);
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(const SizedBox());
  final handle = _Handle();
  await t.pumpWidget(
    _app(PushHost(_screen(args)), [
      settleProvider(args).overrideWith(() {
        final c = FixedSettleController(args, draft ?? sampleSettleDraft());
        handle.controller = c;
        return c;
      }),
    ]),
  );
  await tapKey(t, 'open');
  return handle;
}

String _fieldText(WidgetTester t) =>
    t.widget<TextField>(find.byKey(const Key('settle-amount'))).controller!.text;

ArcGauge _gauge(WidgetTester t) => t.widget<ArcGauge>(find.byKey(const Key('settle-gauge')));

bool _canSave(WidgetTester t) => buttonEnabled(t, 'settle-save');

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.enterText(find.byKey(Key(key)), text);
  await t.pump();
}

String _sentence(WidgetTester t) => t.widget<Text>(find.byKey(const Key('settle-sentence'))).data!;

void main() {
  group('SettleUpScreen form', () {
    // TC-25-02
    testWidgets('prefills who pays whom and exactly what is owed', (t) async {
      final h = await _pump(t);
      expect(find.text('Settle up'), findsOneWidget);
      expect(find.text('Goa trip'), findsWidgets);
      expect(_sentence(t), 'You paid Rahul Mehta');
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Rahul Mehta'), findsOneWidget);
      expect(_fieldText(t), '300');
      expect(find.text('₹'), findsOneWidget);
      expect(find.text('INR'), findsOneWidget);
      expect(h.draft.method, 'cash');
      expect(_canSave(t), isTrue);
      expect(find.text('Record payment'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('paying the whole debt fills the gauge and hides "Pay all"', (t) async {
      await _pump(t);
      expect(_gauge(t).valueText, '100%');
      expect(_gauge(t).caption, 'settles all of ₹300');
      expect(find.byKey(const Key('settle-use-owed')), findsNothing);
    });

    // TC-25-02
    testWidgets('swap flips the direction and the amount follows what is owed', (t) async {
      final h = await _pump(t);
      await tapKey(t, 'settle-swap');
      expect(h.draft.from, 'm3');
      expect(h.draft.to, 'm1');
      expect(_sentence(t), 'Rahul Mehta paid you');
      // Nothing is owed that way round: the field and the form agree on an empty amount.
      expect(h.draft.amountText, '');
      expect(_fieldText(t), '');
      expect(find.byKey(const Key('settle-gauge-none')), findsOneWidget);
      expect(_canSave(t), isFalse);

      await tapKey(t, 'settle-swap');
      expect(_sentence(t), 'You paid Rahul Mehta');
      expect(_fieldText(t), '300');
      expect(_canSave(t), isTrue);
    });

    // TC-25-02
    testWidgets('a typed amount is kept when the people change', (t) async {
      final h = await _pump(t);
      await _type(t, 'settle-amount', '120');
      await tapKey(t, 'settle-swap');
      expect(h.draft.amountText, '120');
      expect(_fieldText(t), '120');
      expect(_canSave(t), isTrue);
    });

    // TC-25-02
    testWidgets('picking another receiver opens the sheet and updates the form', (t) async {
      final h = await _pump(
        t,
        draft: sampleSettleDraft(
          from: 'm2',
          to: 'm1',
          amountText: '900',
          balances: goaOwed(simplify: true),
        ),
      );
      expect(_sentence(t), 'Asha Rao paid you');
      await tapKey(t, 'settle-to');
      expect(find.text('Who got the money?'), findsOneWidget);
      for (final id in ['m1', 'm2', 'm3', 'm4']) {
        expect(find.byKey(Key('pick-person-$id')), findsOneWidget);
      }
      await t.tap(find.byKey(const Key('pick-person-m3')));
      await settle(t);
      expect(find.text('Who got the money?'), findsNothing);
      expect(h.draft.to, 'm3');
      expect(_sentence(t), 'Asha Rao paid Rahul Mehta');
      // Asha owes Rahul 300 once simplified, and the field says so.
      expect(h.draft.amountText, '300');
      expect(_fieldText(t), '300');
    });

    // TC-25-02
    testWidgets('picking the other person as payer swaps the pair', (t) async {
      final h = await _pump(t);
      await tapKey(t, 'settle-from');
      expect(find.text('Who paid?'), findsOneWidget);
      await t.tap(find.byKey(const Key('pick-person-m3')));
      await settle(t);
      expect(h.draft.from, 'm3');
      expect(h.draft.to, 'm1');
    });

    // TC-25-02
    testWidgets('someone nobody owes: a note says so, and the amount can still be typed', (
      t,
    ) async {
      final h = await _pump(t);
      await tapKey(t, 'settle-to');
      await t.tap(find.byKey(const Key('pick-person-m4')));
      await settle(t);
      expect(_sentence(t), 'You paid Priya Nair');
      expect(find.text('Nothing is owed between them. You can still record it.'), findsOneWidget);
      expect(find.byKey(const Key('settle-gauge')), findsNothing);
      expect(_canSave(t), isFalse);
      await _type(t, 'settle-amount', '50');
      expect(_canSave(t), isTrue);
      expect(h.draft.amount, 5000);
    });

    // TC-25-02
    testWidgets('a smaller amount shows the share it settles and offers "Pay all"', (t) async {
      await _pump(t);
      await _type(t, 'settle-amount', '150');
      expect(_gauge(t).valueText, '50%');
      expect(_gauge(t).caption, 'of ₹300 owed');
      expect(find.text('Pay all ₹300'), findsOneWidget);

      await tapKey(t, 'settle-use-owed');
      expect(_fieldText(t), '300');
      expect(_gauge(t).valueText, '100%');
      expect(find.byKey(const Key('settle-use-owed')), findsNothing);
    });

    // TC-25-02
    testWidgets('more than is owed is allowed, shown as 100%+', (t) async {
      await _pump(t);
      await _type(t, 'settle-amount', '500');
      expect(_gauge(t).valueText, '100%+');
      expect(_gauge(t).caption, 'more than the ₹300 owed');
      expect(_canSave(t), isTrue);
      expect(find.text('Pay all ₹300'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('an invalid amount shows its error and disables Record payment', (t) async {
      await _pump(t);
      await _type(t, 'settle-amount', '0');
      expect(find.text('Enter an amount above zero'), findsOneWidget);
      expect(_canSave(t), isFalse);

      await _type(t, 'settle-amount', '1.234');
      expect(find.text('INR allows 2 decimals'), findsOneWidget);
      expect(_canSave(t), isFalse);

      await _type(t, 'settle-amount', '');
      expect(find.text('Enter an amount above zero'), findsNothing);
      expect(_canSave(t), isFalse);

      await _type(t, 'settle-amount', '120.50');
      expect(find.textContaining('allows'), findsNothing);
      expect(_canSave(t), isTrue);
    });

    // TC-25-02
    testWidgets('method chips: cash by default, tap to change', (t) async {
      final h = await _pump(t);
      for (final m in ['Cash', 'UPI', 'Bank', 'Other']) {
        expect(find.text(m), findsOneWidget);
      }
      expect(t.widget<IconChip>(find.byKey(const Key('method-cash'))).selected, isTrue);
      await tapKey(t, 'method-upi');
      expect(h.draft.method, 'upi');
      expect(t.widget<IconChip>(find.byKey(const Key('method-upi'))).selected, isTrue);
      expect(t.widget<IconChip>(find.byKey(const Key('method-cash'))).selected, isFalse);
      await tapKey(t, 'method-bank');
      await tapKey(t, 'method-other');
      expect(h.draft.method, 'other');
    });

    // TC-25-02
    testWidgets('date chips: today by default, yesterday, and a picked day', (t) async {
      final h = await _pump(t);
      expect(t.widget<IconChip>(find.byKey(const Key('date-today'))).selected, isTrue);
      await tapKey(t, 'date-yesterday');
      expect(h.draft.date, DateTime(2026, 11, 20));
      expect(t.widget<IconChip>(find.byKey(const Key('date-yesterday'))).selected, isTrue);
      await tapKey(t, 'date-today');
      expect(h.draft.date, DateTime(2026, 11, 21));
      await tapKey(t, 'date-pick');
      expect(find.text('Pick a date'), findsWidgets);
    });

    // TC-25-02
    testWidgets('the note is saved with the draft; one that is too long blocks saving', (t) async {
      final h = await _pump(t);
      await _type(t, 'settle-note', 'Thanks for the cab');
      expect(h.draft.note, 'Thanks for the cab');
      expect(find.text('Keep the note under 200 characters'), findsNothing);
      expect(_canSave(t), isTrue);

      await _type(t, 'settle-note', 'x' * 201);
      expect(find.text('Keep the note under 200 characters'), findsOneWidget);
      expect(_canSave(t), isFalse);

      await _type(t, 'settle-note', 'x' * 200);
      expect(find.text('Keep the note under 200 characters'), findsNothing);
      expect(_canSave(t), isTrue);
    });

    // TC-25-02
    testWidgets('Record payment saves, closes the screen and says so', (t) async {
      final h = await _pump(t);
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
      // A payment that settles a person plays the celebration first (T6, phase 11); it closes itself.
      await t.pump(celebrationHold);
      await settle(t);
      expect(find.byType(SettleUpScreen), findsNothing);
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('the back button closes without saving', (t) async {
      final h = await _pump(t);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(SettleUpScreen), findsNothing);
      expect(h.controller!.saves, 0);
    });

    // TC-25-02
    testWidgets('editing a saved payment: its own title, button and snackbar', (t) async {
      final h = await _pump(
        t,
        args: _editArgs,
        draft: sampleSettleDraft(
          from: 'm2',
          to: 'm1',
          amountText: '500',
          method: 'upi',
          note: 'Thanks for the cab',
          paymentId: 'p1',
        ),
      );
      expect(find.text('Edit payment'), findsOneWidget);
      expect(find.text('Save payment'), findsOneWidget);
      expect(_fieldText(t), '500');
      expect(
        t
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('settle-note')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'Thanks for the cab',
      );
      expect(t.widget<IconChip>(find.byKey(const Key('method-upi'))).selected, isTrue);
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
      expect(find.text('Payment saved'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('large text: the form scrolls and nothing overflows', (t) async {
      await _pump(t, scale: 2);
      await _type(t, 'settle-amount', '150');
      expect(t.takeException(), isNull);
      await tapKey(t, 'settle-save');
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('a group or payment that is not on this phone says so', (t) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        _app(PushHost(_screen(settleArgs)), [
          settleProvider(settleArgs).overrideWith(() => _NotFoundSettle(settleArgs)),
        ]),
      );
      await tapKey(t, 'open');
      expect(find.text('Nothing to settle here'), findsOneWidget);
      expect(find.text('This group or payment is not on this phone.'), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(SettleUpScreen), findsNothing);
    });

    // TC-25-02
    testWidgets('while it loads a quiet indicator shows', (t) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        _app(PushHost(_screen(settleArgs)), [
          settleProvider(settleArgs).overrideWith(() => _LoadingSettle(settleArgs)),
        ]),
      );
      await tapKey(t, 'open');
      expect(find.byType(DotsPulse), findsOneWidget);
      expect(find.byKey(const Key('settle-save')), findsNothing);
    });
  });

  group('PaymentDetailScreen', () {
    Future<_RecordingActions> pumpDetail(
      WidgetTester t,
      AsyncValue<PaymentView?> view, {
      String id = 'p1',
    }) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (_, _) => PushHost(PaymentDetailScreen(paymentId: id)),
          ),
          stubRoute('/payment/:id/edit'),
          stubRoute('/payment/:id/history'),
        ],
      );
      await t.pumpWidget(
        routerApp(
          router,
          overrides: [
            paymentViewProvider(id).overrideWithValue(view),
            expenseGroupProvider(gid).overrideWith((ref) => Stream.value(sampleGroup())),
            paymentActionsProvider.overrideWith(_RecordingActions.new),
            // Phase 12 comment thread on the detail screen.
            commentThreadProvider((groupId: gid, targetType: 'payment', targetId: id))
                .overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tapKey(t, 'open');
      final container = ProviderScope.containerOf(t.element(find.byType(PaymentDetailScreen)));
      return container.read(paymentActionsProvider) as _RecordingActions;
    }

    // TC-25-02
    testWidgets('shows who paid whom, the amount, method, date and note', (t) async {
      await pumpDetail(t, AsyncData(paymentView()));
      expect(find.text('Asha Rao paid you'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('payment-detail-amount'))).data, '₹500.00');
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Method'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('20 Nov 2026'), findsOneWidget);
      expect(find.text('Thanks for the cab'), findsOneWidget);
      expect(find.byType(SyncMarker), findsNothing);
    });

    // TC-25-02
    testWidgets('a payment I made, not yet synced, is marked and has no note row', (t) async {
      await pumpDetail(t, AsyncData(samplePayments()[1]), id: 'p2');
      expect(find.text('You paid Rahul Mehta'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('payment-detail-amount'))).data, '₹300.00');
      expect(find.text('Cash'), findsOneWidget);
      expect(find.byType(SyncMarker), findsOneWidget);
      expect(find.text('Thanks for the cab'), findsNothing);
    });

    // TC-25-02
    testWidgets('history opens the payment history route (phase 12)', (t) async {
      await pumpDetail(t, AsyncData(paymentView()));
      await tapKey(t, 'payment-history');
      expect(find.text('at /payment/p1/history'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('edit opens the edit route', (t) async {
      await pumpDetail(t, AsyncData(paymentView()));
      await tapKey(t, 'payment-edit');
      expect(find.text('at /payment/p1/edit'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('delete soft-deletes, closes the screen and offers Undo', (t) async {
      final actions = await pumpDetail(t, AsyncData(paymentView()));
      await tapKey(t, 'payment-delete');
      expect(actions.calls, ['delete p1']);
      expect(find.byType(PaymentDetailScreen), findsNothing);
      expect(find.text('Payment deleted'), findsOneWidget);
      await t.tap(find.text('Undo'));
      await settle(t);
      expect(actions.calls, ['delete p1', 'restore p1']);
    });

    // TC-25-02
    testWidgets('not found and loading states', (t) async {
      await pumpDetail(t, const AsyncData(null));
      expect(find.text('Payment not found'), findsOneWidget);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(PaymentDetailScreen), findsNothing);

      await pumpDetail(t, const AsyncLoading());
      expect(find.byType(DotsPulse), findsOneWidget);
    });
  });

  group('Payment rows in the Expenses tab', () {
    Future<void> pumpList(
      WidgetTester t, {
      List<ExpenseView>? expenses,
      List<PaymentView>? pays,
    }) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            // A nested scope: the harness already overrides the payments of this group.
            builder: (_, _) => ProviderScope(
              overrides: [
                groupExpenseViewsProvider(gid)
                    .overrideWithValue(AsyncData(expenses ?? sampleViews())),
                groupPaymentViewsProvider(gid)
                    .overrideWithValue(AsyncData(pays ?? samplePayments())),
              ],
              child: const Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(child: ExpenseList(groupId: gid)),
                ),
              ),
            ),
          ),
          stubRoute('/payment/:id'),
        ],
      );
      await t.pumpWidget(routerApp(router));
      await settle(t);
    }

    double top(WidgetTester t, String key) => t.getTopLeft(find.byKey(ValueKey(key))).dy;

    // TC-25-02
    testWidgets('payments and expenses merge by date under month headers', (t) async {
      await pumpList(t);
      expect(find.byType(PaymentRow), findsNWidgets(3));
      expect(find.text('NOVEMBER 2026'), findsOneWidget);
      expect(find.text('OCTOBER 2026'), findsOneWidget);
      // 21 Nov e2, 20 Nov e1 then p1 (expenses first on the same day), 28 Oct e3, 26 Oct p2, 25 Oct e4, 20 Oct p3.
      final order = [
        'expense-e2',
        'expense-e1',
        'payment-p1',
        'expense-e3',
        'payment-p2',
        'expense-e4',
        'payment-p3',
      ];
      for (var i = 0; i + 1 < order.length; i++) {
        expect(
          top(t, order[i]),
          lessThan(top(t, order[i + 1])),
          reason: '${order[i]} above ${order[i + 1]}',
        );
      }
    });

    // TC-25-02
    testWidgets('each payment row says who paid whom, when, how much, and my side', (t) async {
      await pumpList(t);
      AmountRow row(String id) => t.widget<AmountRow>(find.byKey(ValueKey('payment-$id')));
      expect(row('p1').title, 'Asha Rao paid you');
      expect(row('p1').caption, 'Payment · 20 Nov');
      expect(row('p1').amountText, '₹500');
      expect(row('p1').amountCaption, 'you received');
      expect(row('p1').unsynced, isFalse);
      expect(row('p2').title, 'You paid Rahul Mehta');
      expect(row('p2').amountCaption, 'you paid');
      expect(row('p2').unsynced, isTrue);
      expect(row('p3').title, 'Rahul Mehta paid Priya Nair');
      expect(row('p3').amountCaption, 'not involved');
      expect(row('p3').amountText, '₹75.50');
    });

    // TC-25-02
    testWidgets('only payments, no expenses: the list shows them, not the empty state', (t) async {
      await pumpList(t, expenses: const [], pays: [paymentView()]);
      expect(find.text('No expenses yet'), findsNothing);
      expect(find.byType(PaymentRow), findsOneWidget);
    });

    // TC-25-02
    testWidgets('tapping a payment opens it', (t) async {
      await pumpList(t);
      await t.tap(find.byKey(const ValueKey('payment-p1')));
      await settle(t);
      expect(find.text('at /payment/p1'), findsOneWidget);
    });
  });

  group('Settle pickers', () {
    Future<void> pumpPicker(
      WidgetTester t,
      void Function(BuildContext) open, {
      List<Override> overrides = const [],
    }) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
          stubRoute('/settle'),
        ],
      );
      await t.pumpWidget(routerApp(router, overrides: overrides));
      await tapKey(t, 'open');
    }

    // Asha owes me, Rahul owes Priya (not mine), listed in that order by the group.
    GroupBalances withOthersFirst() => GroupBalances(
      groupId: gid,
      groupName: 'Goa trip',
      mainCurrency: 'INR',
      members: goaMembers(),
      byCurrency: const {
        'INR': Balances(
          nets: {'m1': 120000, 'm2': -120000, 'm3': -5000, 'm4': 5000},
          pairs: [Transfer('m3', 'm4', 5000), Transfer('m2', 'm1', 120000)],
          simplified: [],
        ),
      },
      meId: 'm1',
      hasRecords: true,
    );

    // TC-25-02
    testWidgets('group sheet lists my transfers first and opens Settle up prefilled', (t) async {
      await pumpPicker(
        t,
        (c) => unawaited(showSettlePicker(c, gid)),
        overrides: [groupBalancesProvider(gid).overrideWithValue(AsyncData(withOthersFirst()))],
      );
      expect(find.byKey(const Key('settle-picker')), findsOneWidget);
      expect(find.text('SUGGESTED'), findsOneWidget);
      expect(find.text('Record a different payment'), findsOneWidget);
      expect(
        t.getTopLeft(find.byKey(const Key('settle-m2-m1'))).dy,
        lessThan(t.getTopLeft(find.byKey(const Key('settle-m3-m4'))).dy),
      );

      await t.tap(find.byKey(const Key('settle-m2-m1')));
      await settle(t);
      expect(find.byKey(const Key('settle-picker')), findsNothing);
      expect(find.text('at /settle?group=g-goa&from=m2&to=m1&currency=INR'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('group sheet when everyone is settled still offers a different payment', (t) async {
      await pumpPicker(
        t,
        (c) => unawaited(showSettlePicker(c, gid)),
        overrides: [groupBalancesProvider(gid).overrideWithValue(AsyncData(goaSettled()))],
      );
      expect(find.text('Everyone in this group is settled up.'), findsOneWidget);
      expect(find.byType(TransferRow), findsNothing);
      await tapKey(t, 'settle-other');
      expect(find.text('at /settle?group=g-goa'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('group sheet shows a loading indicator until balances arrive', (t) async {
      await pumpPicker(
        t,
        (c) => unawaited(showSettlePicker(c, gid)),
        overrides: [groupBalancesProvider(gid).overrideWithValue(const AsyncLoading())],
      );
      expect(find.byType(DotsPulse), findsOneWidget);
    });

    // TC-25-02
    testWidgets('Groups home sheet groups my transfers by group name', (t) async {
      await pumpPicker(t, (c) => unawaited(showSettleEverywhere(c, [goaOwed(), flatOwed()])));
      expect(find.byKey(const Key('settle-everywhere')), findsOneWidget);
      expect(find.text('Settle up with'), findsOneWidget);
      expect(find.text('GOA TRIP'), findsOneWidget);
      expect(find.text('FLAT 4B'), findsOneWidget);
      expect(find.byType(TransferRow), findsNWidgets(3));
      await t.tap(find.byKey(const Key('settle-f2-f1')));
      await settle(t);
      expect(find.text('at /settle?group=g-flat&from=f2&to=f1&currency=INR'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('Groups home sheet skips transfers that do not involve me', (t) async {
      await pumpPicker(t, (c) => unawaited(showSettleEverywhere(c, [withOthersFirst()])));
      expect(find.byType(TransferRow), findsOneWidget);
      expect(find.byKey(const Key('settle-m3-m4')), findsNothing);
    });

    // TC-25-02
    testWidgets('Groups home with nothing to settle shows a snackbar instead of a sheet', (
      t,
    ) async {
      await pumpPicker(t, (c) => unawaited(showSettleEverywhere(c, [goaSettled(), goaEmpty()])));
      expect(find.byKey(const Key('settle-everywhere')), findsNothing);
      expect(find.text("You're all settled up"), findsOneWidget);
    });
  });

  group('Settle up currency', () {
    Future<_Handle> pumpWithPicker(WidgetTester t, {SettleDraft? draft}) async {
      usePhone(t);
      await t.pumpWidget(const SizedBox());
      final handle = _Handle();
      await t.pumpWidget(
        _app(PushHost(_screen(settleArgs)), [
          groupMainCurrencyProvider(gid).overrideWith((ref) => Stream.value('INR')),
          recentCurrenciesProvider.overrideWith((ref) => Stream.value(const <String>['EUR'])),
          settleProvider(settleArgs).overrideWith(() {
            final c = FixedSettleController(settleArgs, draft ?? sampleSettleDraft());
            handle.controller = c;
            return c;
          }),
        ]),
      );
      await tapKey(t, 'open');
      return handle;
    }

    Future<void> pick(WidgetTester t, String code) async {
      await tapKey(t, 'settle-currency');
      expect(find.text('Currency'), findsOneWidget);
      await t.enterText(find.byKey(const Key('currency-search')), code);
      await settle(t);
      await t.tap(find.byKey(Key('currency-found-$code')));
      await settle(t);
    }

    // TC-14-04
    testWidgets('the currency chip opens the picker with the group currency and recent ones', (
      t,
    ) async {
      await pumpWithPicker(t);
      await tapKey(t, 'settle-currency');
      expect(find.text('Currency'), findsOneWidget);
      expect(find.byKey(const Key('currency-group-INR')), findsOneWidget);
      expect(find.byKey(const Key('currency-recent-EUR')), findsOneWidget);
    });

    // TC-14-04
    testWidgets('switching currency updates the chip and the amount follows what is owed', (
      t,
    ) async {
      final h = await pumpWithPicker(t);
      expect(_fieldText(t), '300');
      await pick(t, 'USD');
      expect(h.draft.currency, 'USD');
      expect(
        find.descendant(of: find.byKey(const Key('settle-currency')), matching: find.text('USD')),
        findsOneWidget,
      );
      // nothing is owed in USD, the amount was not typed: the field empties
      expect(h.draft.amountText, '');
      expect(_fieldText(t), '');
      expect(_canSave(t), isFalse);

      await pick(t, 'INR');
      expect(h.draft.currency, 'INR');
      expect(_fieldText(t), '300');
      expect(_canSave(t), isTrue);
    });

    // TC-14-04
    testWidgets('a typed amount stays when the currency changes', (t) async {
      final h = await pumpWithPicker(t);
      await _type(t, 'settle-amount', '42');
      await pick(t, 'USD');
      expect(h.draft.currency, 'USD');
      expect(h.draft.amount, 4200);
      expect(_fieldText(t), '42');
      expect(_canSave(t), isTrue);
    });

    // TC-14-04
    testWidgets('picking the current currency changes nothing', (t) async {
      final h = await pumpWithPicker(t);
      await pick(t, 'INR');
      expect(h.draft.currency, 'INR');
      expect(_fieldText(t), '300');
    });
  });
}

class _RecordingActions extends PaymentActions {
  _RecordingActions(super.ref);

  final calls = <String>[];

  @override
  Future<void> delete(LocalPayment p) async => calls.add('delete ${p.id}');

  @override
  Future<void> restore(LocalPayment p) async => calls.add('restore ${p.id}');
}
