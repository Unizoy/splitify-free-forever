// TC-19-03: the bell on the Activity hero shows the unread count and opens the notifications list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/presentation/activity_screen.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../expenses/expense_fixtures.dart';
import '../../expenses/presentation/presentation_harness.dart';
import 'notif_harness.dart';

Future<void> _pumpButton(WidgetTester t, int badge, {String? label}) async {
  usePhone(t);
  await t.pumpWidget(
    expenseApp(
      Scaffold(
        body: Center(
          child: HeroIconButton(
            icon: AppIcons.bell,
            tooltip: 'Notifications',
            semanticLabel: label,
            badge: badge,
            onPressed: () {},
          ),
        ),
      ),
    ),
  );
  await settle(t);
}

Finder get _badge => find.byKey(const Key('hero-badge'));

void main() {
  group('HeroIconButton badge', () {
    // TC-19-03
    testWidgets('no badge at 0', (t) async {
      await _pumpButton(t, 0);
      expect(_badge, findsNothing);
    });

    // TC-19-03
    testWidgets('shows the count up to 9', (t) async {
      await _pumpButton(t, 3);
      expect(find.descendant(of: _badge, matching: find.text('3')), findsOneWidget);
      await _pumpButton(t, 9);
      expect(find.descendant(of: _badge, matching: find.text('9')), findsOneWidget);
    });

    // TC-19-03
    testWidgets('shows 9+ from ten up', (t) async {
      await _pumpButton(t, 10);
      expect(find.descendant(of: _badge, matching: find.text('9+')), findsOneWidget);
      await _pumpButton(t, 12);
      expect(find.descendant(of: _badge, matching: find.text('9+')), findsOneWidget);
    });

    // TC-19-03
    testWidgets('screen readers hear the semantic label, else the tooltip', (t) async {
      final h = t.ensureSemantics();
      await _pumpButton(t, 3, label: 'Notifications, 3 unread');
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
      await _pumpButton(t, 3);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      h.dispose();
    });

    // TC-19-03
    testWidgets('the badge stays compact', (t) async {
      await _pumpButton(t, 3);
      final size = t.getSize(_badge);
      expect(size.height, lessThanOrEqualTo(24));
    });
  });

  group('ActivityScreen bell', () {
    Future<void> pump(WidgetTester t, int unread) => pumpNotif(
      t,
      const ActivityScreen(),
      overrides: [
        activityItemsProvider(null).overrideWithValue(const AsyncData([])),
        unreadNotificationsProvider.overrideWithValue(AsyncData(unread)),
      ],
    );

    // TC-19-03
    testWidgets('shows the unread count on the bell', (t) async {
      await pump(t, 3);
      expect(find.descendant(of: _badge, matching: find.text('3')), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });

    // TC-19-03
    testWidgets('no badge when nothing is unread, and the label drops the count', (t) async {
      final h = t.ensureSemantics();
      await pump(t, 0);
      expect(_badge, findsNothing);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      h.dispose();
    });

    // TC-19-03
    testWidgets('the label says how many are unread', (t) async {
      final h = t.ensureSemantics();
      await pump(t, 12);
      expect(find.bySemanticsLabel('Notifications, 12 unread'), findsOneWidget);
      expect(find.descendant(of: _badge, matching: find.text('9+')), findsOneWidget);
      h.dispose();
    });

    // TC-19-03
    testWidgets('tapping the bell opens /notifications', (t) async {
      await pump(t, 3);
      await t.tap(find.byKey(const Key('activity-bell')));
      await settle(t);
      expect(find.text('at /notifications'), findsOneWidget);
    });
  });
}
