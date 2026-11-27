// TC-25-02 (Record a payment, one screen since D-033), plus the payment detail screen, payment rows in the Expenses tab and
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
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/expenses/presentation/editor/editor_fields.dart' show ToolChip;
import 'package:splitify/features/expenses/presentation/expense_list.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show syncOfflineProvider;
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
  bool offline = false,
}) async {
  usePhone(t);
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(const SizedBox());
  final handle = _Handle();
  final screen = _screen(args);
  await t.pumpWidget(
    _app(
      PushHost(
        offline
            ? ProviderScope(
                overrides: [syncOfflineProvider.overrideWith((ref) => Stream.value(true))],
                child: screen,
              )
            : screen,
      ),
      [
        settleProvider(args).overrideWith(() {
          final c = FixedSettleController(args, draft ?? sampleSettleDraft());
          handle.controller = c;
          return c;
        }),
      ],
    ),
  );
  await tapKey(t, 'open');
  return handle;
}

Finder _amount() => fieldIn('settle-amount');

String _fieldText(WidgetTester t) => t.widget<TextField>(_amount()).controller!.text;

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(_amount(), text);
  await t.pump();
}

String _sentence(WidgetTester t) => t.widget<Text>(find.byKey(const Key('settle-sentence'))).data!;

String _pillTitle(WidgetTester t) => textOf(
  find.descendant(
    of: find.byKey(const Key('settle-summary')),
    matching: find.byKey(const Key('form-pill-title')),
  ),
)!;

String? _pillSub(WidgetTester t) {
  final f = find.descendant(
    of: find.byKey(const Key('settle-summary')),
    matching: find.byKey(const Key('form-pill-subtitle')),
  );
  return f.evaluate().isEmpty ? null : textOf(f);
}

ToolChip _chip(WidgetTester t, String key) => t.widget<ToolChip>(find.byKey(Key(key)));

Map<String, Object?> _keyboard(WidgetTester t) =>
    (t.testTextInput.setClientArgs!['inputType']! as Map).cast<String, Object?>();

void main() {
  group('Record a payment (one screen, D-033)', () {
    // TC-25-02
    testWidgets('prefills who pays whom and exactly what is owed', (t) async {
      final h = await _pump(t);
      expect(find.text('Record a payment'), findsOneWidget);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(_sentence(t), 'You paid Rahul Mehta');
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Rahul Mehta'), findsOneWidget);
      expect(_fieldText(t), '300');
      expect(find.text('INR'), findsOneWidget);
      expect(h.draft.method, 'cash');
      expect(h.draft.canSave, isTrue);
      expect(find.text('Record cash payment'), findsOneWidget);
      // Prefilled: no keyboard until the amount is tapped.
      expect(t.testTextInput.isVisible, isFalse);
    });

    // TC-25-02
    testWidgets('the amount uses the number keyboard; no custom pad, one keyboard', (t) async {
      await _pump(t);
      await t.tap(_amount());
      await t.pump();
      expect(_keyboard(t)['name'], 'TextInputType.number');
      expect(_keyboard(t)['decimal'], isTrue);
      expect(find.byKey(const Key('key-d1')), findsNothing);
    });

    // TC-25-02
    testWidgets('paying the whole debt: the pill says it settles all, no "Pay all"', (t) async {
      await _pump(t);
      expect(_pillTitle(t), 'Settles all of ₹300');
      expect(_pillSub(t), isNull);
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
      expect(_pillTitle(t), 'Nothing owed right now');
      expect(h.draft.canSave, isFalse);

      await tapKey(t, 'settle-swap');
      expect(_sentence(t), 'You paid Rahul Mehta');
      expect(_fieldText(t), '300');
      expect(h.draft.canSave, isTrue);
    });

    // TC-25-02
    testWidgets('a typed amount is kept when the people change', (t) async {
      final h = await _pump(t);
      await _type(t, '120');
      await tapKey(t, 'settle-swap');
      expect(h.draft.amountText, '120');
      expect(_fieldText(t), '120');
      expect(h.draft.canSave, isTrue);
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
    testWidgets('someone nobody owes: the pill says so, and the amount can still be typed', (
      t,
    ) async {
      final h = await _pump(t);
      await tapKey(t, 'settle-to');
      await t.tap(find.byKey(const Key('pick-person-m4')));
      await settle(t);
      expect(_sentence(t), 'You paid Priya Nair');
      expect(_pillTitle(t), 'Nothing owed right now');
      expect(_pillSub(t), 'You can still record a payment.');
      expect(h.draft.canSave, isFalse);
      await _type(t, '50');
      expect(h.draft.canSave, isTrue);
      expect(h.draft.amount, 5000);
    });

    // TC-25-02
    testWidgets('nothing owed and nothing typed: the amount gets the focus', (t) async {
      await _pump(
        t,
        draft: sampleSettleDraft(to: 'm4', amountText: ''),
      );
      expect(t.widget<TextField>(_amount()).focusNode!.hasFocus, isTrue);
      expect(_keyboard(t)['name'], 'TextInputType.number');
    });

    // TC-25-02
    testWidgets('a partial payment says what is left and offers "Pay all"', (t) async {
      await _pump(t);
      await _type(t, '150');
      expect(_pillTitle(t), 'Part of the ₹300 owed');
      expect(_pillSub(t), '₹150 left after this');
      expect(find.text('Pay all ₹300'), findsOneWidget);

      await tapKey(t, 'settle-use-owed');
      expect(_fieldText(t), '300');
      expect(_pillTitle(t), 'Settles all of ₹300');
      expect(find.byKey(const Key('settle-use-owed')), findsNothing);
    });

    // TC-25-02 (overpay: allowed, never silent)
    testWidgets('more than is owed is allowed and the pill says by how much', (t) async {
      final h = await _pump(t);
      await _type(t, '500');
      expect(_pillTitle(t), 'More than the ₹300 owed');
      expect(_pillSub(t), '₹200 more than owed');
      expect(h.draft.canSave, isTrue);
      expect(find.text('Pay all ₹300'), findsOneWidget);
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
    });

    // TC-25-02
    testWidgets('an invalid amount shows its error inline and Save never records it', (t) async {
      final h = await _pump(t);
      await _type(t, '0');
      expect(find.text('Enter an amount above zero'), findsOneWidget);
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 0);
      expect(find.byType(SettleUpScreen), findsOneWidget);

      // A third decimal is refused by the field: the text stays as it was.
      await _type(t, '120.5');
      await _type(t, '120.505');
      expect(_fieldText(t), '120.5');

      await _type(t, '');
      expect(find.text('Enter an amount above zero'), findsNothing);
      await tapKey(t, 'settle-save');
      // Save points at the problem: "Enter an amount", the amount focused, nothing recorded.
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(t.widget<TextField>(_amount()).focusNode!.hasFocus, isTrue);
      expect(h.controller!.saves, 0);

      await _type(t, '120.50');
      expect(find.text('Enter an amount'), findsNothing);
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
    });

    // TC-25-02
    testWidgets('the method chip: cash by default, the sheet changes it and the button', (t) async {
      final h = await _pump(t);
      expect(_chip(t, 'settle-method').active, isFalse);
      await tapKey(t, 'settle-method');
      expect(find.text('How was it paid?'), findsOneWidget);
      for (final m in ['Cash', 'UPI', 'Bank', 'Other']) {
        expect(
          find.descendant(of: find.byKey(const Key('settle-methods')), matching: find.text(m)),
          findsOneWidget,
        );
      }
      await tapKey(t, 'method-bank');
      expect(h.draft.method, 'bank');
      expect(find.text('Record bank payment'), findsOneWidget);
      expect(_chip(t, 'settle-method').active, isTrue);
      await tapKey(t, 'settle-method');
      await tapKey(t, 'method-upi');
      expect(find.text('Record UPI payment'), findsOneWidget);
      await tapKey(t, 'settle-method');
      await tapKey(t, 'method-other');
      expect(h.draft.method, 'other');
      expect(find.text('Record payment'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('the date chip: today by default, the sheet picks yesterday', (t) async {
      final h = await _pump(t);
      expect(
        find.descendant(of: find.byKey(const Key('settle-date')), matching: find.text('Today')),
        findsOneWidget,
      );
      await tapKey(t, 'settle-date');
      expect(find.text('Pick a date'), findsWidgets);
      await tapKey(t, 'date-yesterday');
      expect(h.draft.date, DateTime(2026, 11, 20));
      expect(
        find.descendant(of: find.byKey(const Key('settle-date')), matching: find.text('Yesterday')),
        findsOneWidget,
      );
      expect(_chip(t, 'settle-date').active, isTrue);
    });

    // TC-25-02
    testWidgets('the note chip opens its sheet; one that is too long blocks saving', (t) async {
      final h = await _pump(t);
      await tapKey(t, 'settle-note-chip');
      await t.enterText(fieldIn('settle-note'), 'Thanks for the cab');
      await t.pump();
      expect(h.draft.note, 'Thanks for the cab');
      await tapKey(t, 'text-sheet-done');
      expect(_chip(t, 'settle-note-chip').active, isTrue);

      await tapKey(t, 'settle-note-chip');
      await t.enterText(fieldIn('settle-note'), 'x' * 201);
      await t.pump();
      expect(find.text('Use up to 200 characters'), findsOneWidget);
      await tapKey(t, 'text-sheet-done');
      await tapKey(t, 'settle-save');
      // Save reopens the note sheet with its error; nothing is recorded.
      expect(find.text('Use up to 200 characters'), findsOneWidget);
      expect(h.controller!.saves, 0);
      await t.enterText(fieldIn('settle-note'), 'x' * 200);
      await t.pump();
      expect(find.text('Use up to 200 characters'), findsNothing);
      await tapKey(t, 'text-sheet-done');
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
    });

    // TC-25-02
    testWidgets('Record cash payment saves, closes the form, says so and celebrates briefly', (
      t,
    ) async {
      final h = await _pump(t);
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
      // The form is gone at once; the celebration plays over the page below (T6) and closes itself.
      expect(find.byType(SettleUpScreen), findsNothing);
      expect(find.text('Payment recorded'), findsOneWidget);
      expect(find.byKey(const Key('settled-celebration')), findsOneWidget);
      await t.pump(celebrationHold);
      await settle(t);
      expect(find.byKey(const Key('settled-celebration')), findsNothing);
    });

    // TC-25-02
    testWidgets('a tap skips the celebration', (t) async {
      await _pump(t);
      await tapKey(t, 'settle-save');
      expect(find.byKey(const Key('settled-celebration')), findsOneWidget);
      await t.tap(find.byKey(const Key('settled-celebration')));
      await settle(t);
      expect(find.byKey(const Key('settled-celebration')), findsNothing);
    });

    // TC-25-02
    testWidgets('a partial payment closes without a celebration', (t) async {
      await _pump(t);
      await _type(t, '100');
      await tapKey(t, 'settle-save');
      expect(find.byType(SettleUpScreen), findsNothing);
      expect(find.byKey(const Key('settled-celebration')), findsNothing);
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('back with nothing changed closes at once, without saving', (t) async {
      final h = await _pump(t);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.byType(SettleUpScreen), findsNothing);
      expect(h.controller!.saves, 0);
    });

    // TC-25-02
    testWidgets('back after a change asks first: Cancel keeps the amount, Discard closes', (
      t,
    ) async {
      final h = await _pump(t);
      await _type(t, '120');
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('Discard this payment?'), findsOneWidget);
      expect(find.text('The amount and note you typed will be lost.'), findsOneWidget);
      await tapText(t, 'Cancel');
      expect(find.byType(SettleUpScreen), findsOneWidget);
      expect(_fieldText(t), '120');

      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.text('Discard this payment?'), findsOneWidget);
      await tapKey(t, 'confirm-action');
      expect(find.byType(SettleUpScreen), findsNothing);
      expect(h.controller!.saves, 0);
    });

    // TC-25-02
    testWidgets('editing a saved payment: its own title, button, snackbar and discard copy', (
      t,
    ) async {
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
      expect(find.byKey(const Key('settle-upi')), findsNothing);
      expect(_fieldText(t), '500');
      expect(_chip(t, 'settle-note-chip').active, isTrue);
      expect(_chip(t, 'settle-method').label, 'UPI');
      await tapKey(t, 'settle-note-chip');
      expect(t.widget<TextField>(fieldIn('settle-note')).controller!.text, 'Thanks for the cab');
      await tapKey(t, 'text-sheet-done');

      await _type(t, '450');
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(find.text('Discard your changes?'), findsOneWidget);
      expect(find.text('The payment stays as it was last saved.'), findsOneWidget);
      await tapText(t, 'Cancel');

      expect(h.draft.amount, 45000);
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
      expect(find.text('Payment saved'), findsOneWidget);
      expect(find.byKey(const Key('settled-celebration')), findsNothing);
    });

    // TC-25-02
    testWidgets('offline: the group chip says it is saved on this phone for now', (t) async {
      await _pump(t, offline: true);
      expect(find.byKey(const Key('money-offline')), findsOneWidget);
      expect(find.text('Not synced yet'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('large text: the form scrolls and nothing overflows', (t) async {
      final h = await _pump(t, scale: 2);
      await _type(t, '150');
      expect(t.takeException(), isNull);
      await tapKey(t, 'settle-method');
      expect(t.takeException(), isNull);
      await tapKey(t, 'method-cash');
      await tapKey(t, 'settle-save');
      expect(h.controller!.saves, 1);
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
      // Compact (D-033): no "Payment" pill, no "Details" heading, one "UPI · date" line.
      expect(find.text('Payment'), findsNothing);
      expect(find.text('DETAILS'), findsNothing);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.byKey(const Key('payment-added')), findsOneWidget);
      expect(find.text('20\u00A0Nov\u00A02026'), findsOneWidget);
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
      expect(row('p1').caption, 'Payment\u00A0· 20\u00A0Nov');
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

    double top(WidgetTester t, String key) => t.getTopLeft(find.byKey(Key(key))).dy;

    // TC-25-02
    testWidgets('group sheet: my balances first, each row opens Record a payment prefilled', (
      t,
    ) async {
      await pumpPicker(
        t,
        (c) => unawaited(showSettlePicker(c, gid)),
        overrides: [groupBalancesProvider(gid).overrideWithValue(AsyncData(withOthersFirst()))],
      );
      expect(find.byKey(const Key('settle-picker')), findsOneWidget);
      expect(find.text('Pick a balance to settle.'), findsOneWidget);
      expect(find.text('owes you ₹1,200'), findsOneWidget);
      expect(find.text('owes Priya Nair ₹50'), findsOneWidget);
      expect(find.text('Record a different payment'), findsOneWidget);
      expect(top(t, 'settle-pick-INR-m2-m1'), lessThan(top(t, 'settle-pick-INR-m3-m4')));
      // One currency: no currency headings.
      expect(find.text('INR BALANCES'), findsNothing);

      await t.tap(find.byKey(const Key('settle-pick-INR-m2-m1')));
      await settle(t);
      expect(find.byKey(const Key('settle-picker')), findsNothing);
      expect(find.text('at /settle?group=g-goa&from=m2&to=m1&currency=INR'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('group sheet: biggest first within mine, a heading per currency', (t) async {
      await pumpPicker(
        t,
        (c) => unawaited(showSettlePicker(c, gid)),
        overrides: [groupBalancesProvider(gid).overrideWithValue(AsyncData(goaMixed()))],
      );
      expect(find.text('INR BALANCES'), findsOneWidget);
      expect(find.text('USD BALANCES'), findsOneWidget);
      expect(find.text('you owe ₹300'), findsOneWidget);
      expect(find.text(r'you owe $20'), findsOneWidget);
      // Asha owes me ₹1,200 before I owe Rahul ₹300; dollars after rupees.
      expect(top(t, 'settle-pick-INR-m2-m1'), lessThan(top(t, 'settle-pick-INR-m1-m3')));
      expect(top(t, 'settle-pick-INR-m1-m3'), lessThan(top(t, 'settle-pick-USD-m1-m3')));
    });

    // TC-25-02 (Splitwise: one balance, no list)
    testWidgets('exactly one balance in the group opens Record a payment at once', (t) async {
      await pumpPicker(
        t,
        (c) => unawaited(showSettlePicker(c, gid)),
        overrides: [groupBalancesProvider(gid).overrideWithValue(AsyncData(goaOwe()))],
      );
      expect(find.byKey(const Key('settle-picker')), findsNothing);
      expect(find.text('at /settle?group=g-goa&from=m1&to=m3&currency=INR'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('group sheet when everyone is settled still offers to record a payment', (t) async {
      await pumpPicker(
        t,
        (c) => unawaited(showSettlePicker(c, gid)),
        overrides: [groupBalancesProvider(gid).overrideWithValue(AsyncData(goaSettled()))],
      );
      expect(find.text('Everyone in this group is settled up.'), findsOneWidget);
      expect(find.byType(SettleBalanceRow), findsNothing);
      expect(find.text('Record a payment'), findsOneWidget);
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
    testWidgets('Groups home sheet groups my balances by group name', (t) async {
      await pumpPicker(t, (c) => unawaited(showSettleEverywhere(c, [goaOwed(), flatOwed()])));
      expect(find.byKey(const Key('settle-everywhere')), findsOneWidget);
      expect(find.text('Settle up with'), findsOneWidget);
      expect(find.text('GOA TRIP'), findsOneWidget);
      expect(find.text('FLAT 4B'), findsOneWidget);
      expect(find.byType(SettleBalanceRow), findsNWidgets(3));
      await t.tap(find.byKey(const Key('settle-pick-INR-f2-f1')));
      await settle(t);
      expect(find.text('at /settle?group=g-flat&from=f2&to=f1&currency=INR'), findsOneWidget);
    });

    // TC-25-02
    testWidgets('Groups home with exactly one balance of mine opens it at once', (t) async {
      await pumpPicker(t, (c) => unawaited(showSettleEverywhere(c, [withOthersFirst()])));
      expect(find.byKey(const Key('settle-everywhere')), findsNothing);
      expect(find.text('at /settle?group=g-goa&from=m2&to=m1&currency=INR'), findsOneWidget);
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
      expect(h.draft.canSave, isFalse);

      await pick(t, 'INR');
      expect(h.draft.currency, 'INR');
      expect(_fieldText(t), '300');
      expect(h.draft.canSave, isTrue);
    });

    // TC-14-04
    testWidgets('a typed amount stays when the currency changes', (t) async {
      final h = await pumpWithPicker(t);
      await _type(t, '42');
      await pick(t, 'USD');
      expect(h.draft.currency, 'USD');
      expect(h.draft.amount, 4200);
      expect(_fieldText(t), '42');
      expect(h.draft.canSave, isTrue);
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
