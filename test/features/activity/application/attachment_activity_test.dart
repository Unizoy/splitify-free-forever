// W2-Y (0029): attachment rows in the activity feed — server rows (attachment_added / removed / restored) and my
// queued ones — read as sentences, sit under the Expenses filter and open the expense.
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/activity_repository.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart';
import 'package:splitify/l10n/app_localizations_en.dart';

import '../../../support/ledger_seed.dart';

ActivitySources _sources({
  List<LocalActivity> activity = const [],
  List<OutboxItem> pending = const [],
}) => ActivitySources(
  activity: activity,
  pending: pending,
  groups: {'g1': seedGroup()},
  members: {
    for (final m in [
      seedMember('m1', userId: 'u1', name: 'Mohit'),
      seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
    ])
      m.id: m,
  },
  expenses: {
    'e1': seedExpense(
      'e1',
      description: 'Hotel',
      total: 100,
      payers: {'m1': 100},
      shares: {'m1': 100},
    ),
  },
  payments: const {},
);

void main() {
  final l = AppLocalizationsEn();

  test('server rows: who attached, removed or restored which kind of file on which expense', () {
    LocalActivity a(
      String id,
      String type,
      String kind, {
      String actor = 'm2',
      String user = 'u2',
    }) => seedActivity(
      id,
      type,
      actorMemberId: actor,
      actorUserId: user,
      targetType: 'expense',
      targetId: 'e1',
      data: {'attachment_id': 'x', 'kind': kind, 'description': 'Hotel', 'name': null},
      createdAt: '2026-11-28T10:0$id:00Z',
    );
    final items = buildActivityItems(
      _sources(
        activity: [
          a('1', 'attachment_added', 'pdf'),
          a('2', 'attachment_removed', 'photo', actor: 'm1', user: 'u1'),
          a('3', 'attachment_restored', 'photo'),
        ],
      ),
      'u1',
    );
    expect(items.map((i) => activitySentence(l, i)), [
      'Asha restored a photo on “Hotel”',
      'You removed a photo from “Hotel”',
      'Asha attached a PDF to “Hotel”',
    ]);
    for (final i in items) {
      expect((i.filter, i.targetType, i.targetId), (ActivityFilter.expenses, 'expense', 'e1'));
    }
  });

  test('my queued files show as "not synced yet" rows on their expense', () {
    final items = buildActivityItems(
      _sources(
        pending: [
          seedOutbox(1, 'attachment', 'upsert', 'a1', payload: {'expense_id': 'e1', 'kind': 'pdf'}),
          seedOutbox(
            2,
            'attachment',
            'delete',
            'a2',
            payload: {'expense_id': 'e1', 'kind': 'photo'},
          ),
          seedOutbox(3, 'attachment', 'restore', 'a3'),
        ],
      ),
      'u1',
    );
    final byType = {for (final i in items) i.type: i};
    expect(byType.keys.toSet(), {'attachment_added', 'attachment_removed', 'attachment_restored'});
    expect(items.every((i) => i.pending), isTrue);
    expect(activitySentence(l, byType['attachment_added']!), 'You attached a PDF to “Hotel”');
    expect(activitySentence(l, byType['attachment_removed']!), 'You removed a photo from “Hotel”');
    expect(
      (byType['attachment_added']!.targetType, byType['attachment_added']!.targetId),
      ('expense', 'e1'),
    );
    // Without its expense id the row still reads and opens the group.
    expect(byType['attachment_restored']!.targetType, 'group');
    expect(byType['attachment_restored']!.detail, 'photo');
  });
}
