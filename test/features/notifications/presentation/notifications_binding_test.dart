// TC-19-09 (push registration, foreground and tapped pushes), TC-19-08 (pre-prompt request).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/notifications/presentation/notifications_binding.dart';

import '../../../support/notification_fakes.dart';
import '../../expenses/presentation/presentation_harness.dart';
import 'notif_harness.dart';

class _Rig {
  _Rig(this.push, this.repo, this.remote, this.prefs);

  final FakePushMessaging push;
  final FakeNotificationsRepository repo;
  final FakeNotificationsRemote remote;
  final SharedPreferences prefs;

  FakePushMessaging get fake => push;
}

Future<_Rig> _pump(WidgetTester t, {FakePushMessaging? push}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = FakeNotificationsRepository();
  final remote = FakeNotificationsRemote();
  final p = push ?? FakePushMessaging();
  await pumpNotif(
    t,
    const NotificationsBinding(
      child: Scaffold(body: Text('shell', key: Key('shell'))),
    ),
    overrides: notifOverrides(repo: repo, remote: remote, push: p, prefs: prefs),
  );
  return _Rig(p, repo, remote, prefs);
}

void main() {
  group('with push', () {
    // TC-19-09
    testWidgets('refreshes the bell and registers this phone\'s token', (t) async {
      final r = await _pump(t);
      expect(find.byKey(const Key('shell')), findsOneWidget);
      expect(r.repo.refreshCalls, 1);
      expect(r.remote.registered.map((e) => e.$1), ['tok-1']);
      expect(r.prefs.getString(PushRegistration.tokenKey), 'tok-1');
    });

    // TC-19-09
    testWidgets('a refreshed token is registered too', (t) async {
      final r = await _pump(t);
      r.fake.refreshes.add('tok-2');
      await settle(t);
      expect(r.remote.registered.map((e) => e.$1), ['tok-1', 'tok-2']);
    });

    // TC-19-09
    testWidgets('no permission means no registration', (t) async {
      final r = await _pump(t, push: FakePushMessaging(permissionState: PushPermission.denied));
      expect(r.remote.registered, isEmpty);
    });

    // TC-19-09
    testWidgets('a push that arrives while the app is open is shown and the bell refreshes', (
      t,
    ) async {
      final r = await _pump(t);
      const m = PushMessage(
        data: {'notification_id': 'n1', 'kind': 'payments'},
        title: 'Goa trip',
        body: 'Rahul paid you ₹300',
      );
      r.fake.foregroundMessages.add(m);
      await settle(t);
      expect(r.fake.shown, [m]);
      expect(r.repo.refreshCalls, 2);
    });

    // TC-19-09
    testWidgets('tapping a push marks it read and opens its expense', (t) async {
      final r = await _pump(t);
      r.fake.taps.add(
        const PushMessage(
          data: {
            'notification_id': 'n1',
            'target_type': 'expense',
            'target_id': 'e1',
            'group_id': 'g-goa',
          },
        ),
      );
      await settle(t);
      expect(r.repo.readIds, ['n1']);
      expect(find.text('at /expense/e1'), findsOneWidget);
    });

    // TC-19-09
    testWidgets('a reminder push opens the group Balances tab', (t) async {
      await _pump(t).then(
        (r) => r.fake.taps.add(
          const PushMessage(
            data: {'notification_id': 'n2', 'target_type': 'balances', 'group_id': 'g-goa'},
          ),
        ),
      );
      await settle(t);
      expect(find.text('at /groups/g-goa?tab=balances'), findsOneWidget);
    });

    // TC-19-09
    testWidgets('a push without a target is marked read and goes nowhere', (t) async {
      final r = await _pump(t);
      r.fake.taps.add(const PushMessage(data: {'notification_id': 'n3'}));
      await settle(t);
      expect(r.repo.readIds, ['n3']);
      expect(find.byKey(const Key('stub')), findsNothing);
    });

    // TC-19-09
    testWidgets('the push that launched the app is opened at start', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = FakeNotificationsRepository();
      final push = FakePushMessaging()
        ..launch = const PushMessage(
          data: {'notification_id': 'n9', 'target_type': 'payment', 'target_id': 'p1'},
        );
      await pumpNotif(
        t,
        const NotificationsBinding(child: Scaffold(body: Text('shell'))),
        overrides: notifOverrides(
          repo: repo,
          remote: FakeNotificationsRemote(),
          push: push,
          prefs: prefs,
        ),
      );
      expect(repo.readIds, ['n9']);
      expect(find.text('at /payment/p1'), findsOneWidget);
    });

    // TC-19-09
    testWidgets('leaving stops listening to pushes', (t) async {
      final r = await _pump(t);
      expect(r.fake.taps.hasListener, isTrue);
      expect(r.fake.foregroundMessages.hasListener, isTrue);
      await t.pumpWidget(const SizedBox());
      expect(r.fake.taps.hasListener, isFalse);
      expect(r.fake.foregroundMessages.hasListener, isFalse);
    });
  });

  group('without push', () {
    // TC-19-09
    testWidgets('the bell still refreshes but nothing is registered or listened to', (t) async {
      final remote = FakeNotificationsRemote();
      final repo = FakeNotificationsRepository();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await pumpNotif(
        t,
        const NotificationsBinding(child: Scaffold(body: Text('shell'))),
        overrides: notifOverrides(
          repo: repo,
          remote: remote,
          push: FakePushMessaging(available: false),
          prefs: prefs,
        ),
      );
      expect(repo.refreshCalls, 1);
      expect(remote.registered, isEmpty);
    });

    // TC-19-09
    testWidgets('the default DisabledPushMessaging registers nothing', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final remote = FakeNotificationsRemote();
      final repo = FakeNotificationsRepository();
      await pumpNotif(
        t,
        const NotificationsBinding(child: Scaffold(body: Text('shell'))),
        overrides: notifOverrides(repo: repo, remote: remote, prefs: prefs),
      );
      expect(repo.refreshCalls, 1);
      expect(remote.registered, isEmpty);
    });
  });

  group('pre-prompt request', () {
    ProviderContainer container(WidgetTester t) =>
        ProviderScope.containerOf(t.element(find.byType(NotificationsBinding)));

    // TC-19-08
    testWidgets('a request shows the pre-prompt sheet', (t) async {
      final r = await _pump(t, push: FakePushMessaging(permissionState: PushPermission.notAsked));
      expect(find.byKey(const Key('push-preprompt')), findsNothing);
      container(t).read(pushPrePromptRequestsProvider.notifier).request();
      await settle(t);
      expect(find.byKey(const Key('push-preprompt')), findsOneWidget);
      expect(r.prefs.getBool(PushPrePrompt.shownKey), isTrue);
    });

    // Final QA: joining from an invite link replaces the stack, so the shell (and this binding) is not on
    // screen when the join asks for the pre-prompt; it shows once the shell is back.
    testWidgets('a request made while the shell was away shows when it comes back', (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var shell = false;
      await pumpNotif(
        t,
        StatefulBuilder(
          builder: (context, setState) => shell
              ? const NotificationsBinding(child: Scaffold(body: Text('shell')))
              : Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () {
                      ref.read(pushPrePromptRequestsProvider.notifier).request();
                      setState(() => shell = true);
                    },
                    child: const Text('join'),
                  ),
                ),
        ),
        overrides: notifOverrides(
          repo: FakeNotificationsRepository(),
          remote: FakeNotificationsRemote(),
          push: FakePushMessaging(permissionState: PushPermission.notAsked),
          prefs: prefs,
        ),
      );
      await t.tap(find.text('join'));
      await settle(t);
      await settle(t);
      expect(find.byKey(const Key('push-preprompt')), findsOneWidget);
    });

    // TC-19-08
    testWidgets('a request does nothing when Android was already asked', (t) async {
      await _pump(t);
      container(t).read(pushPrePromptRequestsProvider.notifier).request();
      await settle(t);
      expect(find.byKey(const Key('push-preprompt')), findsNothing);
    });

    // TC-19-08
    testWidgets('Turn on notifications from the sheet asks Android and registers', (t) async {
      final r = await _pump(t, push: FakePushMessaging(permissionState: PushPermission.notAsked));
      container(t).read(pushPrePromptRequestsProvider.notifier).request();
      await settle(t);
      await t.tap(find.byKey(const Key('push-preprompt-allow')));
      await settle(t);
      expect(r.fake.requested, 1);
      expect(r.remote.registered.map((e) => e.$1), ['tok-1']);
    });
  });
}
