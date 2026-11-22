// TC-19-08: the push pre-prompt (once per install, only when push exists and Android was not asked).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/notifications/presentation/push_pre_prompt.dart';
import 'package:splitify/ui/components/components.dart';

import '../../../support/notification_fakes.dart';
import '../../expenses/presentation/presentation_harness.dart';
import 'notif_harness.dart';

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        key: const Key('go'),
        onPressed: () => maybeShowPushPrePrompt(context, ref),
        child: const Text('go'),
      ),
    ),
  );
}

class _BodyHost extends StatefulWidget {
  const _BodyHost();

  @override
  State<_BodyHost> createState() => _BodyHostState();
}

class _BodyHostState extends State<_BodyHost> {
  bool? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        children: [
          ElevatedButton(
            key: const Key('open'),
            onPressed: () async {
              final r = await showAppSheet<bool>(
                context,
                title: 'Stay in the loop',
                builder: (_) => const PushPrePromptBody(),
              );
              setState(() => result = r);
            },
            child: const Text('open'),
          ),
          Text('result: $result'),
        ],
      ),
    ),
  );
}

class _Rig {
  _Rig(this.push, this.prefs, this.remote);

  final FakePushMessaging push;
  final SharedPreferences prefs;
  final FakeNotificationsRemote remote;

  bool get shownFlag => prefs.getBool(PushPrePrompt.shownKey) ?? false;
}

Future<_Rig> _pump(
  WidgetTester t, {
  PushPermission permission = PushPermission.notAsked,
  bool available = true,
  bool shownBefore = false,
  Widget home = const _Host(),
}) async {
  SharedPreferences.setMockInitialValues({if (shownBefore) PushPrePrompt.shownKey: true});
  final prefs = await SharedPreferences.getInstance();
  final push = FakePushMessaging(available: available, permissionState: permission);
  final remote = FakeNotificationsRemote();
  await pumpNotif(
    t,
    home,
    overrides: notifOverrides(push: push, prefs: prefs, remote: remote),
  );
  return _Rig(push, prefs, remote);
}

Future<void> _go(WidgetTester t) async {
  await t.tap(find.byKey(const Key('go')));
  await settle(t);
}

Finder get _sheet => find.byKey(const Key('push-preprompt'));

void main() {
  group('PushPrePromptBody', () {
    // TC-19-08
    testWidgets('shows the reasons and both buttons', (t) async {
      await _pump(t, home: const _BodyHost());
      await t.tap(find.byKey(const Key('open')));
      await settle(t);
      expect(find.text('Stay in the loop'), findsOneWidget);
      expect(find.text('Get a quiet nudge when something changes in your groups.'), findsOneWidget);
      expect(find.text("New expenses you're part of"), findsOneWidget);
      expect(find.text('Payments and reminders to settle up'), findsOneWidget);
      expect(find.text('Comments on your expenses'), findsOneWidget);
      expect(find.text('Turn on notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    // TC-19-08
    testWidgets('Turn on notifications closes with true', (t) async {
      await _pump(t, home: const _BodyHost());
      await t.tap(find.byKey(const Key('open')));
      await settle(t);
      await t.tap(find.byKey(const Key('push-preprompt-allow')));
      await settle(t);
      expect(find.text('result: true'), findsOneWidget);
      expect(_sheet, findsNothing);
    });

    // TC-19-08
    testWidgets('Not now closes with false', (t) async {
      await _pump(t, home: const _BodyHost());
      await t.tap(find.byKey(const Key('open')));
      await settle(t);
      await t.tap(find.byKey(const Key('push-preprompt-later')));
      await settle(t);
      expect(find.text('result: false'), findsOneWidget);
      expect(_sheet, findsNothing);
    });
  });

  group('maybeShowPushPrePrompt', () {
    // TC-19-08
    testWidgets('shows once when push exists and Android has not been asked, and marks it shown', (
      t,
    ) async {
      final r = await _pump(t);
      await _go(t);
      expect(_sheet, findsOneWidget);
      expect(r.shownFlag, isTrue);
      expect(r.push.requested, 0);
    });

    // TC-19-08
    testWidgets('Turn on notifications asks Android and registers this phone', (t) async {
      final r = await _pump(t);
      await _go(t);
      await t.tap(find.byKey(const Key('push-preprompt-allow')));
      await settle(t);
      expect(r.push.requested, 1);
      expect(r.remote.registered.map((e) => e.$1), ['tok-1']);
      expect(_sheet, findsNothing);
    });

    // TC-19-08
    testWidgets('Android saying no registers nothing', (t) async {
      final r = await _pump(t);
      r.push.requestAnswer = PushPermission.denied;
      await _go(t);
      await t.tap(find.byKey(const Key('push-preprompt-allow')));
      await settle(t);
      expect(r.push.requested, 1);
      expect(r.remote.registered, isEmpty);
    });

    // TC-19-08
    testWidgets('Not now never asks Android and is not shown again', (t) async {
      final r = await _pump(t);
      await _go(t);
      await t.tap(find.byKey(const Key('push-preprompt-later')));
      await settle(t);
      expect(r.push.requested, 0);
      expect(r.shownFlag, isTrue);
      await _go(t);
      expect(_sheet, findsNothing);
    });

    // TC-19-08
    testWidgets('not shown when it was shown before', (t) async {
      final r = await _pump(t, shownBefore: true);
      await _go(t);
      expect(_sheet, findsNothing);
      expect(r.push.requested, 0);
    });

    // TC-19-08
    testWidgets('not shown without push in this build', (t) async {
      final r = await _pump(t, available: false);
      await _go(t);
      expect(_sheet, findsNothing);
      expect(r.shownFlag, isFalse);
    });

    // TC-19-08
    testWidgets('not shown when Android was already asked', (t) async {
      for (final p in [PushPermission.granted, PushPermission.denied]) {
        final r = await _pump(t, permission: p);
        await _go(t);
        expect(_sheet, findsNothing, reason: p.name);
        expect(r.shownFlag, isFalse, reason: p.name);
      }
    });
  });
}
