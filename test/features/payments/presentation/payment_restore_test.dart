// D-034 B2: a deleted payment opened from Activity is read-only with a "Deleted" pill and Restore instead of edit
// and delete (and no comment box); Restore uses the soft-delete restore; an archived group only explains.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/comments/presentation/comment_thread.dart' show CommentComposer;
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';
import 'package:splitify/ui/components/components.dart'
    show PillButton, PillVariant, StatusPill, StatusPillTone;

import '../../balances/balance_fixtures.dart';
import '../../expenses/expense_fixtures.dart' show gid, sampleGroup;
import '../../expenses/presentation/presentation_harness.dart';

class _FakeActions extends PaymentActions {
  _FakeActions(super.ref);

  final restored = <String>[];

  @override
  Future<void> restore(LocalPayment p) async => restored.add(p.id);
}

PaymentView _deleted() =>
    paymentView(samplePayment().copyWith(deletedAt: const Value('2026-11-21T09:00:00Z')));

List<Override> _overrides(
  PaymentView v, {
  bool archived = false,
  _FakeActions Function(Ref)? actions,
}) => [
  paymentViewProvider(v.payment.id).overrideWithValue(AsyncData(v)),
  expenseGroupProvider(gid).overrideWith(
    (ref) => Stream.value(
      archived
          ? sampleGroup().copyWith(archivedAt: const Value('2026-11-25T10:00:00Z'))
          : sampleGroup(),
    ),
  ),
  commentThreadProvider((groupId: gid, targetType: 'payment', targetId: v.payment.id))
      .overrideWithValue(const AsyncData([])),
  if (actions != null) paymentActionsProvider.overrideWith(actions),
];

Future<void> _pump(WidgetTester t, List<Override> overrides) async {
  usePhone(t);
  await t.pumpWidget(expenseApp(const PaymentDetailScreen(paymentId: 'p1'), overrides: overrides));
  await settle(t);
}

void main() {
  testWidgets('a live payment keeps edit, delete and comments', (t) async {
    await _pump(t, _overrides(paymentView()));
    expect(find.byKey(const Key('payment-edit')), findsOneWidget);
    expect(find.byKey(const Key('payment-delete')), findsOneWidget);
    expect(find.byKey(const Key('payment-deleted-pill')), findsNothing);
    expect(find.byKey(const Key('payment-restore')), findsNothing);
    expect(find.byType(CommentComposer), findsOneWidget);
  });

  testWidgets('deleted: the "Deleted" pill and Restore instead of edit and delete', (t) async {
    late _FakeActions actions;
    await _pump(t, _overrides(_deleted(), actions: (ref) => actions = _FakeActions(ref)));
    expect(find.text('Deleted'), findsOneWidget);
    expect(find.byKey(const Key('payment-edit')), findsNothing);
    expect(find.byKey(const Key('payment-delete')), findsNothing);
    expect(
      find.text('This payment was deleted. Restore it to count it in the balances again.'),
      findsOneWidget,
    );
    expect(find.byType(CommentComposer), findsNothing);
    // Still shows what it was.
    expect(find.byKey(const Key('payment-detail-amount')), findsOneWidget);
    // The same "Deleted" pill and Restore as a deleted expense's page (final QA S-410).
    expect(
      t.widget<StatusPill>(find.byKey(const Key('payment-deleted-pill'))).tone,
      StatusPillTone.negative,
    );
    expect(t.widget<PillButton>(find.byKey(const Key('payment-restore'))).variant, PillVariant.ink);
    await t.tap(find.byKey(const Key('payment-restore')));
    await settle(t);
    expect(actions.restored, ['p1']);
    expect(find.text('Payment restored'), findsOneWidget);
  });

  testWidgets('deleted in an archived group: it only explains', (t) async {
    await _pump(t, _overrides(_deleted(), archived: true));
    expect(find.text("This group is archived, so the payment can't be restored."), findsOneWidget);
    expect(find.byKey(const Key('payment-restore')), findsNothing);
  });
}
