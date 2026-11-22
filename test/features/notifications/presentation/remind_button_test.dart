// TC-23-02: the Remind button (ready, sent, throttled, failures) and where TransferRow shows it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
import 'package:splitify/features/notifications/application/reminders.dart';
import 'package:splitify/features/notifications/presentation/remind_button.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/notification_fakes.dart';
import '../../expenses/expense_fixtures.dart' show gid;
import '../../expenses/presentation/presentation_harness.dart';
import '../notif_fixtures.dart';
import 'notif_harness.dart';

/// The harness clock (`baseOverrides`).
final _now = DateTime(2026, 11, 21, 10).toUtc();

class _Rig {
  _Rig({this.lastSent, this.linked = true, FakeNotificationsRemote? remote})
    : remote = remote ?? FakeNotificationsRemote();

  final DateTime? lastSent;
  final bool linked;
  final FakeNotificationsRemote remote;
}

Future<void> _pump(WidgetTester t, _Rig r, Widget child, {double scale = 1}) async {
  await pumpNotif(
    t,
    Scaffold(
      body: SafeArea(child: SingleChildScrollView(child: child)),
    ),
    scale: scale,
    overrides: [
      ...notifOverrides(remote: r.remote),
      lastReminderProvider.overrideWith((ref, p) => Stream.value(r.lastSent)),
    ],
  );
}

Widget _button({bool linked = true}) => Center(
  child: RemindButton(groupId: gid, fromMember: 'm1', toMember: 'm2', name: 'Asha', linked: linked),
);

Finder get _btn => find.byKey(const Key('remind-m2'));
Finder get _bell => find.descendant(of: _btn, matching: find.byIcon(AppIcons.bell));
Finder get _check => find.descendant(of: _btn, matching: find.byIcon(AppIcons.check));

void main() {
  group('RemindButton', () {
    // TC-23-02
    testWidgets('is hidden for a name-only member', (t) async {
      await _pump(t, _Rig(), _button(linked: false));
      expect(_btn, findsNothing);
      expect(find.byType(RemindButton), findsOneWidget);
    });

    // TC-23-02
    testWidgets('ready: a bell with "Remind Asha"', (t) async {
      await _pump(t, _Rig(), _button());
      expect(_bell, findsOneWidget);
      expect(_check, findsNothing);
      expect(find.byTooltip('Remind Asha'), findsOneWidget);
    });

    // TC-23-02
    testWidgets('tap sends the reminder, says so, and the button turns into a check', (t) async {
      final r = _Rig();
      await _pump(t, r, _button());
      await t.tap(_btn);
      await settle(t);
      expect(r.remote.reminders, [(gid, 'm2')]);
      expect(find.text('Reminder sent to Asha'), findsOneWidget);
      expect(_check, findsOneWidget);
      expect(_bell, findsNothing);
      expect(find.byTooltip('Reminded. Again in 24 hours'), findsOneWidget);
    });

    // TC-23-02
    testWidgets('the server\'s retry time sets the wait', (t) async {
      final r = _Rig()
        ..remote.reminderSent = ReminderSent(
          amounts: const {'INR': 120000},
          retryAt: _now.add(const Duration(hours: 23, minutes: 30)),
        );
      await _pump(t, r, _button());
      await t.tap(_btn);
      await settle(t);
      expect(find.byTooltip('Reminded. Again in 24 hours'), findsOneWidget);
    });

    // TC-23-02
    testWidgets('a reminder sent 2 hours ago shows throttled and only explains on tap', (t) async {
      final r = _Rig(lastSent: _now.subtract(const Duration(hours: 2)));
      await _pump(t, r, _button());
      expect(_check, findsOneWidget);
      expect(find.byTooltip('Reminded. Again in 22 hours'), findsOneWidget);
      await t.tap(_btn);
      await settle(t);
      expect(
        find.text('You reminded Asha recently. You can remind again in 22 hours.'),
        findsOneWidget,
      );
      expect(r.remote.reminders, isEmpty);
    });

    // TC-23-02
    testWidgets('a reminder older than 24 hours is ready again', (t) async {
      final r = _Rig(lastSent: _now.subtract(const Duration(hours: 25)));
      await _pump(t, r, _button());
      expect(_bell, findsOneWidget);
      await t.tap(_btn);
      await settle(t);
      expect(r.remote.reminders, hasLength(1));
    });

    // TC-23-02
    testWidgets('the last hour says "1 hour"', (t) async {
      await _pump(
        t,
        _Rig(lastSent: _now.subtract(const Duration(hours: 23, minutes: 30))),
        _button(),
      );
      await t.tap(_btn);
      await settle(t);
      expect(
        find.text('You reminded Asha recently. You can remind again in 1 hour.'),
        findsOneWidget,
      );
    });

    // TC-23-02
    testWidgets('is read out as a button with its state', (t) async {
      final h = t.ensureSemantics();
      await _pump(t, _Rig(), _button());
      expect(find.bySemanticsLabel('Remind Asha'), findsOneWidget);
      h.dispose();
    });

    group('failures', () {
      Future<_Rig> fail(WidgetTester t, ReminderFailure e) async {
        final r = _Rig(remote: FakeNotificationsRemote()..reminderError = e);
        await _pump(t, r, _button());
        await t.tap(_btn);
        await settle(t);
        expect(r.remote.reminders, [(gid, 'm2')]);
        return r;
      }

      // TC-23-02
      testWidgets('offline needs internet and stays ready', (t) async {
        await fail(t, const ReminderFailure(ReminderFailureCode.offline));
        expect(find.text('Needs internet. Connect and try again.'), findsOneWidget);
        expect(_bell, findsOneWidget);
      });

      // TC-23-02
      testWidgets('nothing owed', (t) async {
        await fail(t, const ReminderFailure(ReminderFailureCode.nothingOwed));
        expect(find.text("Asha doesn't owe you anything here right now."), findsOneWidget);
        expect(_bell, findsOneWidget);
      });

      // TC-23-02
      testWidgets('name only', (t) async {
        await fail(t, const ReminderFailure(ReminderFailureCode.nameOnly));
        expect(find.text('Only people who joined the app can be reminded.'), findsOneWidget);
      });

      // TC-23-02
      testWidgets('throttled by the server: hours left, and the button turns into a check', (
        t,
      ) async {
        await fail(
          t,
          ReminderFailure(
            ReminderFailureCode.throttled,
            retryAt: _now.add(const Duration(hours: 5, minutes: 30)),
          ),
        );
        expect(
          find.text('You reminded Asha recently. You can remind again in 6 hours.'),
          findsOneWidget,
        );
        expect(_check, findsOneWidget);
        expect(find.byTooltip('Reminded. Again in 6 hours'), findsOneWidget);
      });

      // TC-23-02
      testWidgets('throttled without a time says 24 hours', (t) async {
        await fail(t, const ReminderFailure(ReminderFailureCode.throttled));
        expect(
          find.text('You reminded Asha recently. You can remind again in 24 hours.'),
          findsOneWidget,
        );
      });

      // TC-23-02
      testWidgets('anything else says it could not be sent', (t) async {
        await fail(t, const ReminderFailure(ReminderFailureCode.unknown));
        expect(find.text("Couldn't send the reminder. Try again."), findsOneWidget);
        await t.pump(const Duration(seconds: 10));
        await fail(t, const ReminderFailure(ReminderFailureCode.notMember));
        expect(find.text("Couldn't send the reminder. Try again."), findsOneWidget);
      });
    });
  });

  group('TransferRow', () {
    Future<void> row(WidgetTester t, Transfer tr, {VoidCallback? onSettle, double scale = 1}) =>
        _pump(
          t,
          _Rig(),
          TransferRow(
            balances: remindBalances(),
            currency: 'INR',
            transfer: tr,
            onSettle: onSettle,
          ),
          scale: scale,
        );

    // TC-23-02
    testWidgets('"Asha owes you" has Remind next to Settle', (t) async {
      await row(t, const Transfer('m2', 'm1', 120000));
      expect(find.text('Asha Rao owes you'), findsOneWidget);
      expect(_btn, findsOneWidget);
      expect(find.byKey(const Key('settle-m2-m1')), findsOneWidget);
      expect(
        t.getTopLeft(_btn).dx,
        lessThan(t.getTopLeft(find.byKey(const Key('settle-m2-m1'))).dx),
      );
    });

    // TC-23-02
    testWidgets('a name-only debtor has no Remind button', (t) async {
      await row(t, const Transfer('m3', 'm1', 30000));
      expect(find.text('Rahul Mehta owes you'), findsOneWidget);
      expect(find.byKey(const Key('remind-m3')), findsNothing);
      expect(find.byKey(const Key('settle-m3-m1')), findsOneWidget);
    });

    // TC-23-02
    testWidgets('rows where I owe, or others owe others, have no Remind button', (t) async {
      await row(t, const Transfer('m1', 'm2', 5000));
      expect(find.byType(RemindButton), findsNothing);
      await row(t, const Transfer('m2', 'm4', 5000));
      expect(find.byType(RemindButton), findsNothing);
    });

    // TC-23-02
    testWidgets('picker rows (custom Settle) have no Remind button', (t) async {
      await row(t, const Transfer('m2', 'm1', 120000), onSettle: () {});
      expect(find.byType(RemindButton), findsNothing);
    });

    // TC-23-02
    testWidgets('a throttled debtor shows the check', (t) async {
      await _pump(
        t,
        _Rig(lastSent: _now.subtract(const Duration(hours: 1))),
        TransferRow(
          balances: remindBalances(),
          currency: 'INR',
          transfer: const Transfer('m4', 'm1', 45000),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('remind-m4')),
          matching: find.byIcon(AppIcons.check),
        ),
        findsOneWidget,
      );
    });

    // TC-23-02
    testWidgets('at text scale 2.0 the buttons sit under the words', (t) async {
      await row(t, const Transfer('m2', 'm1', 120000), scale: 2);
      expect(_btn, findsOneWidget);
      expect(t.getTopLeft(_btn).dy, greaterThan(t.getTopLeft(find.text('Asha Rao owes you')).dy));
      expect(t.takeException(), isNull);
    });
  });
}
