// TC-19-07 (per kind push / in-app switches, muted groups, saved offline), TC-19-07 (push banners).
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/notifications/presentation/notification_settings_screen.dart';
import 'package:splitify/ui/components/components.dart';

import '../../../support/group_fakes.dart' as gf;
import '../../../support/notification_fakes.dart';
import '../../expenses/presentation/presentation_harness.dart';
import 'notif_harness.dart';

List<LocalGroup> _groups() => [
  gf.sampleGroup(),
  gf.sampleGroup(id: 'g-flat', name: 'Flat 4B', type: 'home'),
  gf.sampleGroup(id: 'g-old', name: 'Old trip', archivedAt: '2026-10-01T00:00:00Z'),
  gf.sampleGroup(id: 'g-gone', name: 'Deleted group', deletedAt: '2026-10-02T00:00:00Z'),
  gf.sampleGroup(id: 'g-dm', name: 'Asha and me', type: 'direct'),
];

class _Rig {
  _Rig({
    NotificationPrefs prefs = const NotificationPrefs(),
    bool pending = false,
    this.push,
    List<LocalGroup>? groups,
    this.remote,
  }) : repo = FakeNotificationsRepository(prefs: prefs, prefsPending: pending),
       groups = groups ?? _groups();

  final FakeNotificationsRepository repo;
  final FakePushMessaging? push;
  final FakeNotificationsRemote? remote;
  final List<LocalGroup> groups;
}

Future<void> _pump(WidgetTester t, _Rig r, {double scale = 1}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await pumpNotif(
    t,
    const NotificationSettingsScreen(),
    height: 3200,
    scale: scale,
    overrides: [
      ...notifOverrides(
        repo: r.repo,
        push: r.push,
        remote: r.remote ?? FakeNotificationsRemote(),
        prefs: prefs,
      ),
      groupsListProvider.overrideWithValue(AsyncData(r.groups)),
    ],
  );
}

Finder _row(String ch, NotificationKind k) => find.byKey(Key('notif-$ch-${k.name}'));

bool _on(WidgetTester t, Finder row) =>
    t.widget<PillSwitch>(find.descendant(of: row, matching: find.byType(PillSwitch))).value;

void main() {
  group('switches', () {
    // TC-19-07
    testWidgets('five push and five in-app rows, all on by default', (t) async {
      await _pump(t, _Rig(push: FakePushMessaging()));
      expect(find.byType(ToggleRow), findsNWidgets(10 + 2));
      for (final ch in ['push', 'inapp']) {
        for (final k in NotificationKind.values) {
          expect(_row(ch, k), findsOneWidget, reason: '$ch $k');
          expect(_on(t, _row(ch, k)), isTrue, reason: '$ch $k');
        }
      }
      expect(find.text('ON YOUR PHONE'), findsOneWidget);
      expect(find.text('IN THE APP'), findsOneWidget);
      expect(find.text('MUTED GROUPS'), findsOneWidget);
    });

    // TC-19-07
    testWidgets('the switches reflect the saved settings', (t) async {
      final prefs = const NotificationPrefs()
          .withKind(NotificationKind.comments, NotificationChannel.push, on: false)
          .withKind(NotificationKind.reminders, NotificationChannel.inapp, on: false);
      await _pump(t, _Rig(prefs: prefs, push: FakePushMessaging()));
      expect(_on(t, _row('push', NotificationKind.comments)), isFalse);
      expect(_on(t, _row('inapp', NotificationKind.reminders)), isFalse);
      expect(_on(t, _row('push', NotificationKind.reminders)), isTrue);
      expect(_on(t, _row('inapp', NotificationKind.comments)), isTrue);
    });

    // TC-19-07
    testWidgets('toggling saves on the phone and shows the not-synced marker', (t) async {
      final r = _Rig(push: FakePushMessaging());
      await _pump(t, r);
      expect(find.byType(SyncMarker), findsNothing);
      await t.tap(_row('push', NotificationKind.expenses));
      await settle(t);
      expect(r.repo.prefs.isOn(NotificationKind.expenses, NotificationChannel.push), isFalse);
      expect(r.repo.prefs.isOn(NotificationKind.expenses, NotificationChannel.inapp), isTrue);
      expect(_on(t, _row('push', NotificationKind.expenses)), isFalse);
      expect(find.byType(SyncMarker), findsOneWidget);
      // Sent with the next refresh.
      expect(r.repo.refreshCalls, 1);
      await t.tap(_row('push', NotificationKind.expenses));
      await settle(t);
      expect(_on(t, _row('push', NotificationKind.expenses)), isTrue);
    });

    // TC-19-07
    testWidgets('the marker shows while a change waits for the server', (t) async {
      await _pump(t, _Rig(pending: true, push: FakePushMessaging()));
      expect(find.byType(SyncMarker), findsOneWidget);
    });

    // TC-19-07
    testWidgets('a switch is read out with its state', (t) async {
      final h = t.ensureSemantics();
      await _pump(
        t,
        _Rig(
          prefs: const NotificationPrefs().withKind(
            NotificationKind.payments,
            NotificationChannel.inapp,
            on: false,
          ),
          push: FakePushMessaging(),
        ),
      );
      final node = t.getSemantics(_row('inapp', NotificationKind.payments));
      expect(node.label, 'Payments, Payments recorded with you');
      expect(node.flagsCollection.isToggled, Tristate.isFalse);
      h.dispose();
    });

    // TC-19-07
    testWidgets('lays out at text scale 2.0', (t) async {
      await _pump(t, _Rig(push: FakePushMessaging()), scale: 2);
      expect(find.byType(ToggleRow), findsWidgets);
      expect(t.takeException(), isNull);
    });
  });

  group('muted groups', () {
    // TC-19-07
    testWidgets('lists live groups only, not archived, deleted or direct ones', (t) async {
      await _pump(t, _Rig(push: FakePushMessaging()));
      expect(find.byKey(const Key('notif-mute-g-goa')), findsOneWidget);
      expect(find.byKey(const Key('notif-mute-g-flat')), findsOneWidget);
      expect(find.byKey(const Key('notif-mute-g-old')), findsNothing);
      expect(find.byKey(const Key('notif-mute-g-gone')), findsNothing);
      expect(find.byKey(const Key('notif-mute-g-dm')), findsNothing);
      expect(find.text('Goa trip'), findsOneWidget);
    });

    // TC-19-07
    testWidgets('muting a group saves it; muted ones show on', (t) async {
      final r = _Rig(
        prefs: const NotificationPrefs(mutedGroupIds: {'g-flat'}),
        push: FakePushMessaging(),
      );
      await _pump(t, r);
      expect(_on(t, find.byKey(const Key('notif-mute-g-flat'))), isTrue);
      expect(_on(t, find.byKey(const Key('notif-mute-g-goa'))), isFalse);
      await t.tap(find.byKey(const Key('notif-mute-g-goa')));
      await settle(t);
      expect(r.repo.prefs.mutedGroupIds, {'g-flat', 'g-goa'});
      await t.tap(find.byKey(const Key('notif-mute-g-flat')));
      await settle(t);
      expect(r.repo.prefs.mutedGroupIds, {'g-goa'});
    });

    // TC-19-07
    testWidgets('no groups says so', (t) async {
      await _pump(t, _Rig(groups: const [], push: FakePushMessaging()));
      expect(find.text("You're not in any groups yet."), findsOneWidget);
      expect(find.byType(ToggleRow), findsNWidgets(10));
    });

    // TC-19-07
    testWidgets('only archived or direct groups count as none', (t) async {
      await _pump(t, _Rig(groups: [_groups()[2], _groups()[4]], push: FakePushMessaging()));
      expect(find.text("You're not in any groups yet."), findsOneWidget);
    });
  });

  group('push banner', () {
    Finder banner() => find.byKey(const Key('notif-push-banner'));

    // TC-19-07
    testWidgets('push not set up in this build', (t) async {
      await _pump(t, _Rig());
      expect(banner(), findsOneWidget);
      expect(
        find.text(
          "Push notifications aren't set up in this build. Everything still shows in the bell.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notif-allow')), findsNothing);
    });

    // TC-19-07
    testWidgets('Android permission denied', (t) async {
      await _pump(t, _Rig(push: FakePushMessaging(permissionState: PushPermission.denied)));
      expect(
        find.text(
          "Notifications are blocked for Splitify on this phone. You'll still see everything in the bell.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notif-allow')), findsNothing);
    });

    // TC-19-07
    testWidgets('no banner once permission is granted', (t) async {
      await _pump(t, _Rig(push: FakePushMessaging()));
      expect(banner(), findsNothing);
    });

    // TC-19-07
    testWidgets('not asked yet: Allow notifications asks Android, registers and hides the banner', (
      t,
    ) async {
      final push = FakePushMessaging(permissionState: PushPermission.notAsked);
      final remote = FakeNotificationsRemote();
      await _pump(t, _Rig(push: push, remote: remote));
      expect(find.text('Push notifications are off for now.'), findsOneWidget);
      expect(find.byKey(const Key('notif-allow')), findsOneWidget);
      await t.tap(find.byKey(const Key('notif-allow')));
      await settle(t);
      expect(push.requested, 1);
      expect(remote.registered.map((e) => e.$1), ['tok-1']);
      expect(banner(), findsNothing);
    });

    // TC-19-07
    testWidgets('Allow answered "no" keeps a banner, now about blocking', (t) async {
      final push = FakePushMessaging(permissionState: PushPermission.notAsked)
        ..requestAnswer = PushPermission.denied;
      final remote = FakeNotificationsRemote();
      await _pump(t, _Rig(push: push, remote: remote));
      await t.tap(find.byKey(const Key('notif-allow')));
      await settle(t);
      expect(push.requested, 1);
      expect(remote.registered, isEmpty);
      expect(find.textContaining('are blocked for Splitify'), findsOneWidget);
      expect(find.byKey(const Key('notif-allow')), findsNothing);
    });
  });
}
