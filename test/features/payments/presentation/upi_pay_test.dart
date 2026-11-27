// TC-26-04 (Pay via UPI offered only when it can work), TC-26-03 (fallbacks without a UPI app), T6 (settled
// celebration): the real Settle up screen inside the app router on a memory database, with a fake UPI
// launcher and a mocked clipboard.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart' show Balances, Transfer;
import 'package:splitify/core/upi/upi_link.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/payments/application/settle_controller.dart' show SettleDraft;
import 'package:splitify/features/payments/application/upi_providers.dart';
import 'package:splitify/features/payments/presentation/settle_up_screen.dart' show settledWith;
import 'package:splitify/features/payments/presentation/settled_celebration.dart';

import '../../../support/group_harness.dart';
import '../../../support/ledger_seed.dart';
import '../../balances/balance_fixtures.dart'
    show goaMembers, gid, goaInr, goaMixed, goaOwe, goaOwed, sampleSettleDraft;

class _FakeUpiLauncher implements UpiLauncher {
  _FakeUpiLauncher({this.result = true});

  bool result;
  final uris = <String>[];

  @override
  Future<bool> launch(String uri) async {
    uris.add(uri);
    return result;
  }
}

Finder _key(String k) => find.byKey(Key(k));

Finder _amountField() =>
    find.descendant(of: find.byKey(const Key('settle-amount')), matching: find.byType(TextField));

const _group = 'g1';

/// Me (u1, m1), Asha (u2, m2) and Ravi (name-only, m3). Asha paid ₹1,000 for both of us: I owe her ₹500.
/// Ravi paid ₹600 for both of us: I owe him ₹300. In dollars I owe Asha $50.
Future<AppDatabase> _seed(
  WidgetTester t, {
  String? upiId = 'asha@okaxis',
  bool profile = true,
  bool payment = false,
  bool dollars = true,
}) async {
  final db = openTestDb(t);
  await t.runAsync(() async {
    await db.seed(
      groups: [seedGroup(id: _group, name: 'Goa trip')],
      members: [
        seedMember('m1', userId: 'u1', name: 'Mohit'),
        seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
        seedMember('m3', name: 'Ravi', position: 2),
      ],
      expenses: [
        seedExpense(
          'e1',
          total: 100000,
          payers: {'m2': 100000},
          shares: {'m1': 50000, 'm2': 50000},
        ),
        seedExpense('e2', total: 60000, payers: {'m3': 60000}, shares: {'m1': 30000, 'm3': 30000}),
        if (dollars)
          seedExpense(
            'e3',
            currency: 'USD',
            total: 10000,
            payers: {'m2': 10000},
            shares: {'m1': 5000, 'm2': 5000},
          ),
      ],
      payments: [if (payment) seedPayment('p1', from: 'm1', to: 'm2', amount: 5000)],
    );
    if (profile) {
      await db
          .into(db.profiles)
          .insert(
            ProfilesCompanion.insert(
              id: 'u2',
              displayName: 'Asha Rao',
              upiId: Value(upiId),
              defaultCurrency: const Value('INR'),
              seq: const Value(1),
            ),
          );
    }
  });
  return db;
}

String _settleUrl({String from = 'm1', String to = 'm2', String currency = 'INR'}) =>
    '/settle?group=$_group&from=$from&to=$to&currency=$currency';

Future<_FakeUpiLauncher> _open(
  WidgetTester t,
  AppDatabase db,
  String location, {
  bool launches = true,
}) async {
  final launcher = _FakeUpiLauncher(result: launches);
  await pumpGroups(
    t,
    location,
    db: db,
    overrides: [upiLauncherProvider.overrideWithValue(launcher)],
  );
  return launcher;
}

Future<void> _tap(WidgetTester t, String key, {int frames = 30}) async {
  final f = _key(key).last;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await settle(t, db: true, frames: frames);
}

List<String> _copied(WidgetTester t) {
  final copied = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return copied;
}

Future<List<LocalPayment>> _payments(WidgetTester t, AppDatabase db) =>
    real(t, () => db.select(db.payments).get());

Future<List<OutboxItem>> _outbox(WidgetTester t, AppDatabase db) =>
    real(t, () => db.select(db.outbox).get());

void main() {
  group('Pay via UPI is offered only when it can work', () {
    // TC-26-04
    testWidgets(
      'rupees to someone with a UPI ID: "Pay ₹500 via UPI", Record cash payment under it',
      (t) async {
        final db = await _seed(t);
        await _open(t, db, _settleUrl());
        expect(_key('settle-upi'), findsOneWidget);
        expect(find.text('Pay ₹500 via UPI'), findsOneWidget);
        // The manual way stays: a quiet "Record cash payment" under it.
        expect(_key('settle-save'), findsOneWidget);
        expect(find.text('Record cash payment'), findsOneWidget);
        // Minimal form (D-033): the copy / QR fallbacks live in the UPI sheets, not on the form.
        expect(_key('upi-copy-id'), findsNothing);
        expect(_key('upi-qr'), findsNothing);
      },
    );

    // TC-26-04
    testWidgets('the label follows the amount that is typed', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl());
      await t.enterText(_amountField(), '200');
      await settle(t, db: true, frames: 4);
      expect(find.text('Pay ₹200 via UPI'), findsOneWidget);
    });

    // TC-26-04
    testWidgets('not for dollars, even when the payee has a UPI ID', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl(currency: 'USD'));
      expect(find.text('USD'), findsOneWidget);
      expect(_key('settle-upi'), findsNothing);
      expect(find.textContaining('via UPI'), findsNothing);
      expect(find.text('Record cash payment'), findsOneWidget);
    });

    // Final QA (rule 13): no UPI method for another currency.
    testWidgets('dollars: UPI is not offered as a method', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl(currency: 'USD'));
      await _tap(t, 'settle-method', frames: 6);
      expect(_key('method-cash'), findsOneWidget);
      expect(_key('method-upi'), findsNothing);
    });

    // Final QA: with Cash picked the main button no longer says "Pay ₹500 via UPI".
    testWidgets(
      'picking Cash leaves only Record cash payment; picking UPI brings Pay via UPI back',
      (t) async {
        final db = await _seed(t);
        await _open(t, db, _settleUrl());
        expect(_key('settle-upi'), findsOneWidget);
        await _tap(t, 'settle-method', frames: 6);
        await _tap(t, 'method-cash', frames: 6);
        expect(_key('settle-upi'), findsNothing);
        expect(find.text('Record cash payment'), findsOneWidget);
        await _tap(t, 'settle-method', frames: 6);
        await _tap(t, 'method-upi', frames: 6);
        expect(_key('settle-upi'), findsOneWidget);
        expect(find.text('Record UPI payment'), findsOneWidget);
      },
    );

    // TC-26-04
    testWidgets('not for a payee who has no profile on this phone', (t) async {
      final db = await _seed(t, profile: false);
      await _open(t, db, _settleUrl());
      expect(_key('settle-upi'), findsNothing);
      expect(_key('upi-qr'), findsNothing);
      expect(find.text('Record cash payment'), findsOneWidget);
    });

    // TC-26-04
    testWidgets('not for a payee whose UPI ID is missing or not valid', (t) async {
      final none = await _seed(t, upiId: null);
      await _open(t, none, _settleUrl());
      expect(_key('settle-upi'), findsNothing);
      await t.pumpWidget(const SizedBox());

      final bad = await _seed(t, upiId: 'not a upi id');
      await _open(t, bad, _settleUrl());
      expect(_key('settle-upi'), findsNothing);
      expect(find.text('Record cash payment'), findsOneWidget);
    });

    // TC-26-04
    testWidgets('not for a name-only payee (no account, no UPI ID)', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl(to: 'm3'));
      expect(find.text('Ravi'), findsWidgets);
      expect(_key('settle-upi'), findsNothing);
      expect(find.text('Record cash payment'), findsOneWidget);
    });

    // TC-26-04
    testWidgets('not when I am the one being paid', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl(from: 'm2', to: 'm1'));
      expect(_key('settle-upi'), findsNothing);
      expect(find.text('Record cash payment'), findsOneWidget);
    });

    // TC-26-04
    testWidgets('not when editing a saved payment', (t) async {
      final db = await _seed(t, payment: true);
      await _open(t, db, '/payment/p1/edit');
      expect(find.text('Edit payment'), findsOneWidget);
      expect(_key('settle-upi'), findsNothing);
      expect(_key('settle-save'), findsOneWidget);
    });
  });

  group('Pay via UPI flow', () {
    // TC-26-04
    testWidgets('opens the UPI app with exactly the built link and asks if it went through', (
      t,
    ) async {
      final db = await _seed(t);
      final launcher = await _open(t, db, _settleUrl());
      await _tap(t, 'settle-upi', frames: 8);

      final expected = const UpiLinkBuilder().build(
        vpa: 'asha@okaxis',
        name: 'Asha',
        amountMinor: 50000,
        currencyCode: 'INR',
        note: 'Splitify: Goa trip',
      );
      expect(launcher.uris, [expected.uri]);
      final q = Uri.parse(launcher.uris.single).queryParameters;
      expect(
        (q['pa'], q['pn'], q['am'], q['cu'], q['tn']),
        ('asha@okaxis', 'Asha', '500.00', 'INR', 'Splitify: Goa trip'),
      );
      expect(launcher.uris.single, startsWith('upi://pay?'));
      expect(launcher.uris.single, contains('tn=Splitify%3A%20Goa%20trip'));

      expect(_key('upi-return'), findsOneWidget);
      expect(find.text('Did the payment go through?'), findsOneWidget);
      expect(_key('upi-mark-paid'), findsOneWidget);
      expect(_key('upi-not-yet'), findsOneWidget);
      expect(find.text('UPI ID asha@okaxis'), findsOneWidget);
      expect(find.text('To Asha'), findsWidgets);
      // The app never says whether the payment went through, so nothing is saved yet (rule 13).
      expect(await _payments(t, db), isEmpty);
    });

    // TC-26-04
    testWidgets('Mark as paid saves a UPI payment through the outbox', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl());
      await t.enterText(_amountField(), '200');
      await settle(t, db: true, frames: 4);
      await _tap(t, 'settle-upi', frames: 6);
      await _tap(t, 'upi-mark-paid', frames: 8);

      final saved = await _payments(t, db);
      expect(saved, hasLength(1));
      final p = saved.single;
      expect((p.fromMember, p.toMember, p.amount, p.currency.trim()), ('m1', 'm2', 20000, 'INR'));
      expect(p.method, 'upi');
      expect(p.groupId, _group);
      expect(p.syncState, 'pending');
      final outbox = await _outbox(t, db);
      expect([for (final o in outbox) (o.entity, o.op, o.recordId)], [('payment', 'upsert', p.id)]);
      expect(find.text('Payment recorded'), findsOneWidget);
      // A part payment does not settle the two of us: no celebration.
      expect(_key('settled-celebration'), findsNothing);
    });

    // TC-26-04
    testWidgets('Not yet saves nothing and keeps the form', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl());
      await _tap(t, 'settle-upi', frames: 6);
      await _tap(t, 'upi-not-yet', frames: 8);
      expect(_key('upi-return'), findsNothing);
      expect(_key('settle-upi'), findsOneWidget);
      expect(await _payments(t, db), isEmpty);
      expect(await _outbox(t, db), isEmpty);
      expect(_key('settled-celebration'), findsNothing);
    });

    // TC-26-03
    testWidgets('no UPI app: "No UPI app found" with the UPI ID, amount and QR fallbacks', (
      t,
    ) async {
      final db = await _seed(t);
      final launcher = await _open(t, db, _settleUrl(), launches: false);
      await _tap(t, 'settle-upi', frames: 8);
      expect(launcher.uris, hasLength(1));
      expect(_key('upi-no-app'), findsOneWidget);
      expect(_key('upi-return'), findsNothing);
      expect(find.text('No UPI app found'), findsOneWidget);
      expect(
        find.text(
          'Pay Asha from any UPI app with the UPI ID or the QR code, then record the payment here.',
        ),
        findsOneWidget,
      );
      // The three fallbacks in the sheet.
      for (final k in ['upi-copy-id', 'upi-copy-amount', 'upi-qr']) {
        expect(
          find.descendant(of: _key('upi-no-app'), matching: _key(k)),
          findsOneWidget,
          reason: k,
        );
      }
      // The "app says it failed" hint is only for a launched app.
      expect(
        find.text(
          'If your app says the payment failed, copy the UPI ID and amount into it by hand.',
        ),
        findsNothing,
      );
      expect(await _payments(t, db), isEmpty);
    });

    // TC-26-03
    testWidgets('no UPI app: after paying by hand, Mark as paid still records it as UPI', (
      t,
    ) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl(), launches: false);
      await t.enterText(_amountField(), '100');
      await settle(t, db: true, frames: 4);
      await _tap(t, 'settle-upi', frames: 6);
      await _tap(t, 'upi-mark-paid', frames: 8);
      final p = (await _payments(t, db)).single;
      expect((p.amount, p.method), (10000, 'upi'));
    });

    // TC-26-03
    testWidgets('the return sheet carries the hint for an app that says it failed', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl());
      await _tap(t, 'settle-upi', frames: 8);
      expect(
        find.text(
          'If your app says the payment failed, copy the UPI ID and amount into it by hand.',
        ),
        findsOneWidget,
      );
    });
  });

  group('UPI fallbacks', () {
    // TC-26-03
    testWidgets('Copy UPI ID puts the ID on the clipboard and the chip says "Copied"', (t) async {
      final db = await _seed(t);
      final copied = _copied(t);
      await _open(t, db, _settleUrl(), launches: false);
      await _tap(t, 'settle-upi', frames: 8);
      expect(find.text('Copy UPI ID'), findsOneWidget);
      await _tap(t, 'upi-copy-id', frames: 3);
      expect(copied, ['asha@okaxis']);
      expect(find.text('Copied'), findsOneWidget);
      expect(find.text('Copy UPI ID'), findsNothing);
      // It goes back after a moment.
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Copied'), findsNothing);
      expect(find.text('Copy UPI ID'), findsOneWidget);
    });

    // TC-26-03
    testWidgets('Copy amount copies the amount as plain text with two decimals', (t) async {
      final db = await _seed(t);
      final copied = _copied(t);
      await _open(t, db, _settleUrl(), launches: false);
      await _tap(t, 'settle-upi', frames: 8);
      await _tap(t, 'upi-copy-amount', frames: 3);
      expect(copied, ['500.00']);
      expect(find.text('Copied'), findsOneWidget);
      expect(find.text('Copy UPI ID'), findsOneWidget, reason: 'only the tapped chip changes');
      await t.pump(const Duration(seconds: 3));
    });

    // TC-26-03
    testWidgets('UPI QR opens a sheet with the code and who it pays', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl());
      // After the UPI app came back: "Did the payment go through?" carries the QR too.
      await _tap(t, 'settle-upi', frames: 8);
      await _tap(t, 'upi-qr', frames: 8);
      expect(_key('upi-qr-sheet'), findsOneWidget);
      expect(find.text('Scan to pay Asha'), findsWidgets);
      expect(find.text('Scan with a UPI app on another phone. Amount ₹500.'), findsOneWidget);
      expect(
        find.descendant(of: _key('upi-qr-sheet'), matching: find.text('UPI ID asha@okaxis')),
        findsOneWidget,
      );
    });
  });

  group('Settled celebration (T6)', () {
    // T6
    testWidgets('a payment equal to what is owed shows the celebration, then closes itself', (
      t,
    ) async {
      final db = await _seed(t, dollars: false);
      await _open(t, db, _settleUrl());
      // No amount change: the field holds exactly what I owe Asha.
      await _tap(t, 'settle-save', frames: 6);
      expect(_key('settled-celebration'), findsOneWidget);
      expect(find.text('You and Asha are square.'), findsOneWidget);
      expect((await _payments(t, db)).single.method, 'cash');

      // It closes by itself after celebrationHold (1.4 s), over the page the form returned to.
      await t.pump(celebrationHold);
      await settle(t, db: true, frames: 6);
      expect(_key('settled-celebration'), findsNothing);
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    // T6 (D-033): only when everything between us is settled — here I still owe Asha $50.
    testWidgets('still owing in dollars: paying all the rupees does not celebrate', (t) async {
      final db = await _seed(t);
      await _open(t, db, _settleUrl());
      await _tap(t, 'settle-save', frames: 6);
      expect((await _payments(t, db)).single.amount, 50000);
      expect(_key('settled-celebration'), findsNothing);
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    // T6
    testWidgets('a tap closes the celebration early', (t) async {
      final db = await _seed(t, dollars: false);
      await _open(t, db, _settleUrl());
      await _tap(t, 'settle-save', frames: 6);
      expect(_key('settled-celebration'), findsOneWidget);
      await t.tap(_key('settled-celebration'));
      await settle(t, db: true, frames: 6);
      expect(_key('settled-celebration'), findsNothing);
    });

    // T6
    testWidgets('a partial payment does not celebrate', (t) async {
      final db = await _seed(t, dollars: false);
      await _open(t, db, _settleUrl());
      await t.enterText(_amountField(), '200');
      await settle(t, db: true, frames: 4);
      await _tap(t, 'settle-save', frames: 6);
      expect(_key('settled-celebration'), findsNothing);
      expect((await _payments(t, db)).single.amount, 20000);
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    // T6
    testWidgets('paying more than is owed does not celebrate either', (t) async {
      final db = await _seed(t, dollars: false);
      await _open(t, db, _settleUrl());
      await t.enterText(_amountField(), '600');
      await settle(t, db: true, frames: 4);
      await _tap(t, 'settle-save', frames: 6);
      expect(_key('settled-celebration'), findsNothing);
    });

    // T6
    testWidgets('paying the whole debt by UPI celebrates after Mark as paid', (t) async {
      final db = await _seed(t, dollars: false);
      await _open(t, db, _settleUrl());
      await _tap(t, 'settle-upi', frames: 6);
      await _tap(t, 'upi-mark-paid', frames: 6);
      expect(_key('settled-celebration'), findsOneWidget);
      expect((await _payments(t, db)).single.method, 'upi');
      await t.pump(celebrationHold);
      await settle(t, db: true, frames: 6);
    });
  });

  group('settledWith', () {
    GroupBalances between(String from, String to, int amount, {String? me = 'm1'}) => GroupBalances(
      groupId: gid,
      groupName: 'Goa trip',
      mainCurrency: 'INR',
      members: goaMembers(),
      byCurrency: {
        'INR': Balances(
          nets: const {},
          pairs: [Transfer(from, to, amount)],
          simplified: [Transfer(from, to, amount)],
        ),
      },
      meId: me,
    );

    SettleDraft draft({
      String from = 'm1',
      String to = 'm3',
      String amountText = '300',
      String? paymentId,
      GroupBalances? balances,
    }) => sampleSettleDraft(
      from: from,
      to: to,
      amountText: amountText,
      paymentId: paymentId,
      balances: balances,
    );

    // T6
    test('I pay exactly what I owe: the person I paid', () {
      expect(settledWith(draft()), 'm3'); // goaOwed: I owe Rahul 300
    });

    // T6
    test('someone pays me exactly what they owe: that person', () {
      // Asha owes me 1,200 in the original debts.
      expect(settledWith(draft(from: 'm2', to: 'm1', amountText: '1200')), 'm2');
    });

    // T6
    test('part or more than what is owed: nobody', () {
      expect(settledWith(draft(amountText: '299.99')), isNull);
      expect(settledWith(draft(amountText: '300.01')), isNull);
      expect(settledWith(draft(amountText: '')), isNull);
    });

    // T6
    test('nothing owed that way round: nobody', () {
      expect(settledWith(draft(from: 'm3', to: 'm1', amountText: '300')), isNull);
    });

    // T6
    test('editing a saved payment never celebrates', () {
      expect(settledWith(draft(paymentId: 'p1')), isNull);
    });

    // T6
    test('a payment between two other people never celebrates', () {
      final b = between('m2', 'm3', 100000);
      expect(settledWith(draft(from: 'm2', to: 'm3', amountText: '1000', balances: b)), isNull);
    });

    // T6
    test('without a "me" in the group nobody is settled', () {
      final d = SettleDraft(
        groupId: gid,
        groupName: 'Goa trip',
        members: goaMembers(),
        balances: between('m1', 'm3', 30000, me: null),
        from: 'm1',
        to: 'm3',
        currency: 'INR',
        date: DateTime(2026, 11, 22),
        amountText: '300',
      );
      expect(d.owed, 30000);
      expect(settledWith(d), isNull);
    });

    // T6 (D-033): "everything is settled" — nothing left between us in another currency either.
    test('still owing in another currency: nobody is settled yet', () {
      final d = draft(balances: goaMixed()); // I owe Rahul ₹300 and $20
      expect(d.owed, 30000);
      expect(settledWith(d), isNull);
      expect(settledWith(draft(balances: goaOwe())), 'm3');
    });

    // T6
    test('the sample balances owe what the cases above rely on', () {
      expect(goaOwed().owed('m1', 'm3', 'INR'), 30000);
      expect(goaOwed().owed('m2', 'm1', 'INR'), 120000);
      expect(goaInr.pairs, hasLength(2));
    });
  });

  group('canPayByUpi', () {
    // TC-26-04
    test('needs a UPI ID, rupees, a new payment, and me as the payer', () {
      const vpa = 'asha@okaxis';
      expect(canPayByUpi(sampleSettleDraft(), vpa), isTrue);
      expect(canPayByUpi(sampleSettleDraft(), null), isFalse);
      expect(canPayByUpi(sampleSettleDraft(paymentId: 'p1'), vpa), isFalse);
      expect(canPayByUpi(sampleSettleDraft(from: 'm3', to: 'm1'), vpa), isFalse);
      expect(canPayByUpi(sampleSettleDraft(from: 'm2', to: 'm3'), vpa), isFalse);
    });
  });

  group('upiLinkFor', () {
    // TC-26-04
    test('builds the link from the draft, or null while the amount is not valid', () {
      final link = upiLinkFor(
        sampleSettleDraft(),
        vpa: 'rahul@oksbi',
        name: 'Rahul Mehta',
        note: 'Splitify: Goa trip',
      );
      expect(link!.amount, '300.00');
      expect(link.vpa, 'rahul@oksbi');
      expect(
        link.uri,
        'upi://pay?pa=rahul@oksbi&pn=Rahul%20Mehta&am=300.00&cu=INR&tn=Splitify%3A%20Goa%20trip',
      );
      expect(
        upiLinkFor(
          sampleSettleDraft(amountText: ''),
          vpa: 'a@b1',
          name: 'x',
          note: '',
        ),
        isNull,
      );
      expect(
        upiLinkFor(
          sampleSettleDraft(amountText: '0'),
          vpa: 'rahul@oksbi',
          name: 'x',
          note: '',
        ),
        isNull,
      );
      expect(upiLinkFor(sampleSettleDraft(), vpa: 'not a vpa', name: 'x', note: ''), isNull);
    });
  });
}
