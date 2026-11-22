// TC-19-06 (bell list: grouping, unread, mark read, navigation), TC-19-06 (offline note, empty state),
// TC-19-07 (gear to settings).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/features/notifications/presentation/notifications_screen.dart';
import 'package:splitify/l10n/app_localizations_en.dart';

import '../../../support/notification_fakes.dart';
import '../../expenses/presentation/presentation_harness.dart';
import 'notif_harness.dart';

Finder _row(String id) => find.byKey(ValueKey('notification-$id'));
Finder get _dots => find.byKey(const Key('notification-unread-dot'));
Finder get _markAll => find.byKey(const Key('notifications-mark-all'));

Future<FakeNotificationsRepository> _pump(
  WidgetTester t, {
  List<LocalNotification> rows = const [],
  Object? refreshError,
  double scale = 1,
}) async {
  final repo = FakeNotificationsRepository(rows: rows)..refreshError = refreshError;
  await pumpNotif(
    t,
    const NotificationsScreen(),
    overrides: notifOverrides(repo: repo),
    scale: scale,
  );
  return repo;
}

void main() {
  group('list', () {
    // TC-19-06
    testWidgets('groups rows by day, newest first', (t) async {
      await _pump(t, rows: sampleNotifRows());
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.byType(NotificationRow), findsNWidgets(5));
      double top(String id) => t.getTopLeft(_row(id)).dy;
      expect(top('n1'), lessThan(top('n2')));
      expect(top('n3'), lessThan(top('n4')));
      expect(t.getTopLeft(find.text('TODAY')).dy, lessThan(top('n1')));
      expect(t.getTopLeft(find.text('YESTERDAY')).dy, greaterThan(top('n3')));
      expect(t.getTopLeft(find.text('YESTERDAY')).dy, lessThan(top('n4')));
    });

    // TC-19-06
    testWidgets('shows the sentence, group name with time and the unread count', (t) async {
      await _pump(t, rows: sampleNotifRows());
      expect(find.text('Asha added “Dinner” · ₹1,200'), findsOneWidget);
      expect(find.textContaining('Goa trip · '), findsWidgets);
      expect(find.textContaining('Flat 4B · '), findsOneWidget);
      expect(find.text('3 unread'), findsOneWidget);
    });

    // TC-19-06
    testWidgets('the unread dot shows on unread rows only', (t) async {
      await _pump(t, rows: sampleNotifRows());
      expect(_dots, findsNWidgets(3));
      for (final id in ['n1', 'n2', 'n4']) {
        expect(find.descendant(of: _row(id), matching: _dots), findsOneWidget);
      }
      for (final id in ['n3', 'n5']) {
        expect(find.descendant(of: _row(id), matching: _dots), findsNothing);
      }
    });

    // TC-19-06
    testWidgets('unread rows are read out as unread', (t) async {
      final h = t.ensureSemantics();
      await _pump(t, rows: sampleNotifRows());
      expect(
        find.bySemanticsLabel(RegExp(r'^Unread, Rahul paid you ₹300, Goa trip · ')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Priya joined the group, Goa trip · ')),
        findsOneWidget,
      );
      h.dispose();
    });

    // TC-19-06
    testWidgets('refreshes when it opens', (t) async {
      final repo = await _pump(t, rows: sampleNotifRows());
      expect(repo.refreshCalls, greaterThanOrEqualTo(1));
      expect(find.byKey(const Key('notifications-offline')), findsNothing);
    });

    // TC-19-06
    testWidgets('lays out at text scale 2.0', (t) async {
      await _pump(t, rows: sampleNotifRows(), scale: 2);
      expect(find.text('Asha added “Dinner” · ₹1,200'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('mark read', () {
    // TC-19-06
    testWidgets('Mark all read shows only with unread rows and reads everything', (t) async {
      final repo = await _pump(t, rows: sampleNotifRows());
      expect(_markAll, findsOneWidget);
      await t.tap(_markAll);
      await settle(t);
      expect(repo.markedAll, 1);
      expect(repo.rows.every((r) => r.readAt != null), isTrue);
      expect(_dots, findsNothing);
      expect(_markAll, findsNothing);
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    // TC-19-06
    testWidgets('no Mark all read when everything is read', (t) async {
      await _pump(t, rows: [notifRow('r1', read: true)]);
      expect(_markAll, findsNothing);
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    // TC-19-06
    testWidgets('tapping an expense row reads it and opens the expense', (t) async {
      final repo = await _pump(t, rows: sampleNotifRows());
      await t.tap(_row('n1'));
      await settle(t);
      expect(repo.readIds, ['n1']);
      expect(find.text('at /expense/e-n1'), findsOneWidget);
    });

    // TC-19-06
    testWidgets('a reminder opens the group Balances tab', (t) async {
      await _pump(t, rows: sampleNotifRows());
      await t.tap(_row('n3'));
      await settle(t);
      expect(find.text('at /groups/g-goa?tab=balances'), findsOneWidget);
    });

    // TC-19-06
    testWidgets('a payment row opens the payment and is marked read', (t) async {
      final repo = await _pump(t, rows: sampleNotifRows());
      await t.tap(_row('n2'));
      await settle(t);
      expect(find.text('at /payment/p1'), findsOneWidget);
      expect(repo.rows.firstWhere((r) => r.id == 'n2').readAt, isNotNull);
    });

    // TC-19-06
    testWidgets('a group row opens the group', (t) async {
      await _pump(t, rows: sampleNotifRows());
      await t.tap(_row('n5'));
      await settle(t);
      expect(find.text('at /groups/g-goa'), findsOneWidget);
    });

    // TC-19-06
    testWidgets('a row without a target is marked read and goes nowhere', (t) async {
      final repo = await _pump(
        t,
        rows: [notifRow('x1', groupId: null, data: const <String, Object?>{})],
      );
      await t.tap(_row('x1'));
      await settle(t);
      expect(repo.readIds, ['x1']);
      expect(find.byKey(const Key('stub')), findsNothing);
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });
  });

  group('states', () {
    // TC-19-06
    testWidgets('empty state', (t) async {
      await _pump(t);
      expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(_markAll, findsNothing);
      expect(find.textContaining('unread'), findsNothing);
    });

    // TC-19-06
    testWidgets('a failed refresh keeps the rows and adds the offline note', (t) async {
      await _pump(t, rows: sampleNotifRows(), refreshError: offlineError);
      expect(find.byKey(const Key('notifications-offline')), findsOneWidget);
      expect(find.text("Offline · showing what's on this phone"), findsOneWidget);
      expect(find.byType(NotificationRow), findsNWidgets(5));
    });

    // TC-19-06
    testWidgets('offline with nothing saved shows the empty state and the note', (t) async {
      await _pump(t, refreshError: offlineError);
      expect(find.byKey(const Key('notifications-offline')), findsOneWidget);
      expect(find.byKey(const Key('notifications-empty')), findsOneWidget);
    });

    // TC-19-06
    testWidgets('new rows from a refresh appear without leaving', (t) async {
      final repo = await _pump(t);
      expect(find.byType(NotificationRow), findsNothing);
      repo.setRows([notifRow('late')]);
      await settle(t);
      expect(_row('late'), findsOneWidget);
    });

    // TC-19-07
    testWidgets('the gear opens the notification settings', (t) async {
      await _pump(t, rows: sampleNotifRows());
      await t.tap(find.byKey(const Key('notifications-settings')));
      await settle(t);
      expect(find.text('at /account/notifications'), findsOneWidget);
    });
  });

  group('kind helpers', () {
    // TC-19-06
    test('every kind has an icon, a label and a hint', () {
      final l = AppLocalizationsEn();
      final icons = {for (final k in NotificationKind.values) kindIcon(k)};
      expect(icons.length, NotificationKind.values.length);
      for (final k in NotificationKind.values) {
        expect(kindLabel(l, k), isNotEmpty);
        expect(kindHint(l, k), isNotEmpty);
      }
      expect(kindLabel(l, NotificationKind.reminders), 'Reminders');
    });
  });
}
