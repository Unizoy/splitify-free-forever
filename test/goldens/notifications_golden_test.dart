import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/money/balances.dart' show Transfer;
import 'package:splitify/data/local/app_database.dart' show LocalNotification;
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/features/balances/presentation/balances_tab.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/notifications/application/reminders.dart';
import 'package:splitify/features/notifications/presentation/notification_settings_screen.dart';
import 'package:splitify/features/notifications/presentation/notifications_screen.dart';
import 'package:splitify/features/notifications/presentation/push_pre_prompt.dart';
import 'package:splitify/ui/components/components.dart';

import '../features/expenses/expense_fixtures.dart';
import '../features/notifications/notif_fixtures.dart';
import '../features/notifications/presentation/notif_harness.dart';
import '../support/group_fakes.dart' as gf;
import '../support/notification_fakes.dart';
import 'golden_support.dart';

/// One golden scenario: the screen, its overrides and the frame height at text scale 1.0.
typedef _Case = (
  String name,
  Widget Function() screen,
  List<Override> Function() overrides,
  double height,
);

/// The harness clock (`baseOverrides`: 21 Nov 2026, 10:00).
final _now = DateTime(2026, 11, 21, 10).toUtc();

List<Override> _bell(List<LocalNotification> rows) =>
    notifOverrides(repo: FakeNotificationsRepository(rows: rows));

List<Override> _settings({FakePushMessaging? push}) => [
  ...notifOverrides(
    repo: FakeNotificationsRepository(
      prefs: const NotificationPrefs()
          .withKind(NotificationKind.comments, NotificationChannel.push, on: false)
          .withKind(NotificationKind.groups, NotificationChannel.push, on: false)
          .withKind(NotificationKind.reminders, NotificationChannel.inapp, on: false)
          .withMuted('g-flat', muted: true),
      prefsPending: true,
    ),
    push: push,
  ),
  groupsListProvider.overrideWithValue(
    AsyncData([
      gf.sampleGroup(),
      gf.sampleGroup(id: 'g-flat', name: 'Flat 4B', type: 'home'),
      gf.sampleGroup(id: 'g-old', name: 'Old trip', archivedAt: '2026-10-01T00:00:00Z'),
    ]),
  ),
];

class _RemindList extends StatelessWidget {
  const _RemindList();

  @override
  Widget build(BuildContext context) {
    final b = remindBalances();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              for (final (i, t) in const [
                Transfer('m2', 'm1', 120000),
                Transfer('m4', 'm1', 45000),
                Transfer('m3', 'm1', 30000),
              ].indexed)
                TransferRow(balances: b, currency: 'INR', transfer: t, showDivider: i < 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrePrompt extends StatelessWidget {
  const _PrePrompt();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheet(title: 'Stay in the loop', child: PushPrePromptBody()),
    ),
  );
}

List<_Case> _cases() => [
  ('notifications_list', () => const NotificationsScreen(), () => _bell(sampleNotifRows()), 1000),
  ('notifications_empty', () => const NotificationsScreen(), () => _bell(const []), 915),
  ('notification_settings', () => const NotificationSettingsScreen(), () => _settings(), 2150),
  (
    'notification_settings_blocked',
    () => const NotificationSettingsScreen(),
    () => _settings(push: FakePushMessaging(permissionState: PushPermission.denied)),
    1550,
  ),
  ('push_preprompt', () => const _PrePrompt(), () => notifOverrides(), 700),
  (
    'balances_remind',
    () => const _RemindList(),
    () => [
      ...notifOverrides(),
      lastReminderProvider.overrideWith(
        (ref, p) =>
            Stream.value(p.toMember == 'm4' ? _now.subtract(const Duration(hours: 1)) : null),
      ),
    ],
    520,
  ),
];

void main() {
  // TC-19-01, TC-19-05, TC-19-06, TC-23-02: the bell list, settings, pre-prompt and Remind buttons in light
  // and dark at text scale 1.0 and 2.0.
  for (final (name, screen, overrides, height) in _cases()) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final (suffix, scale) in goldenScales) {
        goldenTest(
          'notifications $name ${mode.name} $suffix',
          fileName: '${name}_${mode.name}_$suffix',
          pumpBeforeTest: pumpFixedFrames,
          builder: () => expenseApp(
            screen(),
            overrides: overrides(),
            mode: mode,
            scale: scale,
            size: Size(goldenWidth, scale > 1 ? height * 1.8 : height),
          ),
        );
      }
    }
  }
}
