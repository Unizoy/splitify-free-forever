// Phase 12 on the phase-09 payment detail: the History row opens `/payment/:id/history`, the comment thread and
// the composer are there, and an archived group makes the composer read-only (TC-20-03, TC-13-04).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';
import 'package:splitify/features/expenses/application/expense_providers.dart';
import 'package:splitify/features/payments/application/payment_providers.dart';
import 'package:splitify/features/payments/presentation/payment_detail_screen.dart';

import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';
import '../../history/presentation/history_fixtures.dart';

const _target = (groupId: gid, targetType: 'payment', targetId: 'p1');

Future<void> _pump(
  WidgetTester t, {
  List<CommentView> comments = const [],
  LocalGroup? group,
}) async {
  usePhone(t);
  final router = GoRouter(
    initialLocation: '/payment/p1',
    routes: [
      GoRoute(
        path: '/payment/:id',
        builder: (_, state) => PaymentDetailScreen(paymentId: state.pathParameters['id']!),
      ),
      stubRoute('/payment/:id/history'),
      stubRoute('/payment/:id/edit'),
    ],
  );
  await t.pumpWidget(
    routerApp(
      router,
      overrides: [
        paymentViewProvider('p1').overrideWithValue(
          AsyncData(PaymentView(payment: samplePayment(), names: memberNames, meId: me)),
        ),
        expenseGroupProvider(gid).overrideWith((ref) => Stream.value(group ?? sampleGroup())),
        commentThreadProvider(_target).overrideWithValue(AsyncData(comments)),
      ],
    ),
  );
  await settle(t);
}

void main() {
  testWidgets('the history row opens the payment history route', (t) async {
    await _pump(t);
    await tapKey(t, 'payment-history');
    expect(find.text('at /payment/p1/history'), findsOneWidget);
  });

  testWidgets('shows the comment thread and the composer', (t) async {
    await _pump(t, comments: sampleThread());
    expect(find.byKey(const Key('comment-field')), findsOneWidget);
    expect(find.byKey(const Key('comment-send')), findsOneWidget);
    for (final c in sampleThread()) {
      await reveal(t, find.text(c.comment.body));
      expect(find.text(c.comment.body), findsOneWidget);
    }
  });

  testWidgets('no comments yet shows the empty state', (t) async {
    await _pump(t);
    await reveal(t, find.byKey(const Key('comments-empty')));
    expect(find.text('No comments yet'), findsOneWidget);
  });

  testWidgets('an archived group makes the composer read-only', (t) async {
    final g = sampleGroup();
    await _pump(t, group: g.copyWith(archivedAt: const Value('2026-11-21T10:00:00Z')));
    expect(find.byKey(const Key('comment-read-only')), findsOneWidget);
    expect(find.byKey(const Key('comment-field')), findsNothing);
  });
}
