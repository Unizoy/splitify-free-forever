// D-034 WP-C in the feed (0026): settle-up nudges (weekly / trip end, from Splitify itself), notes edits, the
// reminder setting, my own unsynced notes edit, the filter they sit under; and the new group fields in the
// "Download my data" backup.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/repositories/activity_repository.dart';
import 'package:splitify/data/repositories/export_reads.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/features/export/application/backup_export.dart';
import 'package:splitify/l10n/app_localizations.dart';

import '../../support/ledger_seed.dart';

final _l = lookupAppLocalizations(const Locale('en'));

List<ActivityItem> _items({List<dynamic> activity = const [], List<dynamic> pending = const []}) =>
    buildActivityItems(
      ActivitySources(
        activity: [...activity.cast()],
        pending: [...pending.cast()],
        groups: {'g1': seedGroup()},
        members: {
          'm1': seedMember('m1', userId: 'u1', name: 'Mohit'),
          'm2': seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
        },
        expenses: const {},
        payments: const {},
      ),
      'u1',
    );

void main() {
  test('settle-up nudges: system rows, weekly and trip end, under Payments, open Balances', () {
    final items = _items(
      activity: [
        seedActivity(
          'a2',
          'settle_nudge',
          targetType: 'group',
          targetId: 'g1',
          data: {'reason': 'trip_end', 'name': 'Goa trip'},
          seq: 2,
          createdAt: '2026-11-21T04:30:00Z',
        ),
        seedActivity(
          'a1',
          'settle_nudge',
          targetType: 'group',
          targetId: 'g1',
          data: {'reason': 'weekly', 'name': 'Goa trip'},
          createdAt: '2026-11-20T04:30:00Z',
        ),
      ],
    );
    expect(items.map((i) => i.type), ['settle_nudge_trip_end', 'settle_nudge']);
    expect(items.map((i) => activitySentence(_l, i)), [
      'The trip is over: reminder to settle up sent',
      'Reminder to settle up sent',
    ]);
    expect(items.every((i) => i.filter == ActivityFilter.payments), isTrue);
    expect(items.first.targetType, 'group');
    expect(items.first.targetId, 'g1');
  });

  test('notes edits and the reminder setting', () {
    final items = _items(
      activity: [
        seedActivity(
          'a3',
          'settings_changed',
          actorMemberId: 'm2',
          actorUserId: 'u2',
          targetType: 'group',
          targetId: 'g1',
          data: {'name': 'Goa trip', 'setting': 'settle_reminder', 'settle_reminder': 'weekly'},
          seq: 3,
          createdAt: '2026-11-21T12:00:00Z',
        ),
        seedActivity(
          'a2',
          'settings_changed',
          actorMemberId: 'm1',
          actorUserId: 'u1',
          targetType: 'group',
          targetId: 'g1',
          data: {'name': 'Goa trip', 'setting': 'settle_reminder', 'settle_reminder': 'off'},
          seq: 2,
          createdAt: '2026-11-21T11:00:00Z',
        ),
        seedActivity(
          'a1',
          'whiteboard_updated',
          actorMemberId: 'm2',
          actorUserId: 'u2',
          targetType: 'group',
          targetId: 'g1',
          data: {'name': 'Goa trip'},
          createdAt: '2026-11-21T10:00:00Z',
        ),
      ],
    );
    expect(items.map((i) => activitySentence(_l, i)), [
      'Asha turned on weekly settle-up reminders',
      'You turned off settle-up reminders',
      'Asha updated the group notes',
    ]);
    expect(items.last.filter, ActivityFilter.groups);
  });

  test('my notes edit still in the outbox reads as a notes edit, not synced yet', () {
    final items = _items(
      pending: [
        seedOutbox(1, 'group', 'upsert', 'g1', payload: {'whiteboard': 'Wi-Fi: goa2026'}),
        seedOutbox(
          2,
          'group',
          'upsert',
          'g1',
          payload: {
            'name': 'Goa',
            'type': 'trip',
            'main_currency': 'INR',
            'settle_reminder': 'weekly',
          },
          createdAt: '2026-11-22T09:30:00Z',
        ),
      ],
    );
    expect(items.map((i) => i.type), ['group_updated', 'whiteboard_updated']);
    expect(items.last.pending, isTrue);
    expect(activitySentence(_l, items.last), 'You updated the group notes');
  });

  test('the backup carries trip dates, reminders and notes (off when not set)', () {
    final json = backupJson(
      exportedAt: DateTime.utc(2026, 11, 22),
      userId: 'u1',
      groups: [
        BackupGroupRows(
          group: seedGroup().copyWith(
            tripStartsOn: const Value('2026-12-12'),
            tripEndsOn: const Value('2026-12-18'),
            settleReminder: const Value('weekly'),
            whiteboard: const Value('Wi-Fi: goa2026'),
          ),
        ),
        BackupGroupRows(
          group: seedGroup(id: 'g2', name: 'Flat'),
        ),
      ],
    );
    final groups = [
      for (final g in json['groups']! as List) (g as Map)['group'] as Map<String, Object?>,
    ];
    expect(groups.first, containsPair('trip_starts_on', '2026-12-12'));
    expect(groups.first, containsPair('trip_ends_on', '2026-12-18'));
    expect(groups.first, containsPair('settle_reminder', 'weekly'));
    expect(groups.first, containsPair('whiteboard', 'Wi-Fi: goa2026'));
    expect(groups.last, containsPair('settle_reminder', 'off'));
    expect(groups.last, containsPair('trip_ends_on', null));
    expect(groups.last, containsPair('whiteboard', null));
  });
}
