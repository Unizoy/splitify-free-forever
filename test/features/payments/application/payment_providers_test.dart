import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';

import '../../../support/ledger_seed.dart';
import '../../expenses/application/expense_test_env.dart';

void main() {
  final members = [
    seedMember('m1', userId: 'u1', name: 'Mohit'),
    seedMember('m2', name: 'Asha', position: 1),
    seedMember('m3', name: 'Ravi', position: 2, status: 'left'),
  ];

  group('paymentViews', () {
    final out = seedPayment('p1', from: 'm1', to: 'm2', amount: 100);
    final inn = seedPayment('p2', from: 'm2', to: 'm1', amount: 200, syncState: SyncState.pending);
    final other = seedPayment('p3', from: 'm2', to: 'm3', amount: 300);

    test('marks what I paid, what I received and what is not synced', () {
      final v = paymentViews([out, inn, other], members, 'u1');
      expect(
        [for (final x in v) (x.iPaid, x.iReceived, x.unsynced)],
        [(true, false, false), (false, true, true), (false, false, false)],
      );
      expect(v.first.meId, 'm1');
      expect(v.first.nameOf('m2'), 'Asha');
      expect(v[2].nameOf('m3'), 'Ravi');
      expect(v.first.nameOf('nobody'), '');
    });

    test('without an account (or as a stranger) nothing is mine', () {
      for (final uid in [null, 'u9']) {
        final v = paymentViews([out], members, uid).single;
        expect((v.meId, v.iPaid, v.iReceived), (null, false, false));
      }
    });

    test('a removed member is not me', () {
      final left = [seedMember('m1', userId: 'u1', status: 'left'), seedMember('m2')];
      expect(paymentViews([out], left, 'u1').single.meId, isNull);
      final gone = [seedMember('m1', userId: 'u1', deletedAt: '2026-11-01'), seedMember('m2')];
      expect(paymentViews([out], gone, 'u1').single.meId, isNull);
    });

    test('the payment methods in chip order', () {
      expect(paymentMethods, ['cash', 'upi', 'bank', 'other']);
    });
  });

  group('with a database', () {
    late ExpenseEnv env;
    late String me;
    late String asha;

    setUp(() async {
      env = await ExpenseEnv.create(others: const ['Asha']);
      me = env.me;
      asha = env.ids['Asha']!;
      await env.db.seed(
        payments: [
          seedPayment(
            'p1',
            groupId: env.groupId,
            from: asha,
            to: me,
            amount: 500,
            date: '2026-11-19',
          ),
          seedPayment(
            'p2',
            groupId: env.groupId,
            from: me,
            to: asha,
            amount: 700,
            date: '2026-11-21',
          ),
          seedPayment(
            'p3',
            groupId: env.groupId,
            from: me,
            to: asha,
            amount: 900,
            deletedAt: '2026-11-21T00:00:00Z',
          ),
        ],
      );
    });
    tearDown(() => env.dispose());

    Future<T> data<T>(ProviderListenable<AsyncValue<T>> p, {bool Function(T v)? where}) {
      final done = Completer<T>();
      late final ProviderSubscription<AsyncValue<T>> sub;
      sub = env.container.listen(p, (_, n) {
        if (done.isCompleted) return;
        if (n.hasValue && (where == null || where(n.requireValue))) {
          done.complete(n.requireValue);
        } else if (n.hasError) {
          done.completeError(n.error!);
        }
      }, fireImmediately: true);
      return done.future.whenComplete(sub.close);
    }

    test('groupPaymentViewsProvider lists the live payments newest first', () async {
      final v = await data(groupPaymentViewsProvider(env.groupId));
      expect([for (final x in v) x.payment.id], ['p2', 'p1']);
      expect([for (final x in v) x.iPaid], [true, false]);
      expect(v.first.nameOf(asha), 'Asha');
    });

    test('paymentViewProvider: the payment, null when deleted or missing', () async {
      final one = (await data(paymentViewProvider('p1')))!;
      expect((one.payment.amount, one.iReceived, one.meId), (500, true, me));
      expect(await data(paymentViewProvider('p3')), isNull);
      expect(await data(paymentViewProvider('nope')), isNull);
    });

    test('delete is soft and queued; restore brings it back', () async {
      final actions = env.container.read(paymentActionsProvider);
      final p = (await data(paymentViewProvider('p1')))!.payment;
      await actions.delete(p);
      var row = await (env.db.select(env.db.payments)..where((x) => x.id.equals('p1'))).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.syncState, SyncState.pending);
      expect(await data(paymentViewProvider('p1'), where: (v) => v == null), isNull);
      await actions.restore(row);
      row = await (env.db.select(env.db.payments)..where((x) => x.id.equals('p1'))).getSingle();
      expect(row.deletedAt, isNull);
      final box = [
        for (final o in await env.db.select(env.db.outbox).get())
          if (o.entity == 'payment') (o.op, o.recordId, o.groupId),
      ];
      expect(box, [('delete', 'p1', env.groupId), ('restore', 'p1', env.groupId)]);
      expect((await data(paymentViewProvider('p1'), where: (v) => v != null))!.payment.amount, 500);
    });
  });
}
