// Client side of #12 (TC-12-01..03 run on the server): recurring bills are written offline through the
// outbox (create, edit future copies, stop, repeat again) with the phone's own guess of the next date.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/repositories/recurring_repository.dart';
import 'package:splitify/data/sync/local_writer.dart';
import 'package:splitify/data/sync/pull_applier.dart';
import 'package:splitify/data/sync/server_clock.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/recurrence.dart';

import '../../support/fakes.dart' show FakeClock, testDb;
import '../sync/sync_fakes.dart' show gid, m1, m2, serverGroup, serverMember;

const _expense = '01900000-0000-7000-8000-00000000e001';
const _copy = '01900000-0000-7000-8000-00000000e002';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late RecurringRepository repo;
  late PullApplier applier;

  setUp(() async {
    db = testDb();
    clock = FakeClock(DateTime.utc(2026, 11, 21, 10));
    repo = RecurringRepository(db, LocalWriter(db, clock, ServerClock(clock, SyncDao(db))));
    applier = PullApplier(db);
    await applier.apply(
      PullPage(
        serverTime: clock.now(),
        rows: {
          'groups': [serverGroup()],
          'group_members': [serverMember(m1, 0), serverMember(m2, 1)],
        },
        nextCursors: const {gid: 2},
        userSeq: 0,
      ),
    );
  });

  tearDown(() => db.close());

  final monthly = Recurrence(
    interval: RecurrenceInterval.monthly,
    anchor: DateTime.utc(2026, 10, 15),
  );
  const template = <String, Object?>{
    'description': 'Rent',
    'total': 1500000,
    'currency': 'INR',
    'payers': {m1: 1500000},
    'shares': {m1: 750000, m2: 750000},
  };

  Future<String> create({
    Recurrence? rule,
    String expenseId = _expense,
    Map<String, Object?> tpl = template,
  }) => repo.create(groupId: gid, expenseId: expenseId, rule: rule ?? monthly, template: tpl);

  Future<LocalRecurring> row(String id) =>
      (db.select(db.recurringTemplates)..where((t) => t.id.equals(id))).getSingle();

  Future<List<OutboxItem>> outbox() => db.select(db.outbox).get();

  Map<String, Object?> payload(OutboxItem o) => jsonDecode(o.payload) as Map<String, Object?>;

  group('create', () {
    // #12
    test('writes a pending local row with the phone\'s guess of the next date', () async {
      final id = await create();
      final t = await row(id);
      expect(t.syncState, SyncState.pending);
      expect(t.groupId, gid);
      expect(t.expenseId, _expense);
      expect(t.interval, 'monthly');
      expect(t.anchorDate, '2026-10-15');
      expect(t.endsOn, isNull);
      expect(t.active, isTrue);
      expect(t.nextDate, '2026-12-15');
      expect(jsonDecode(t.template), template);
    });

    // #12
    test('queues one upsert of entity recurring with the schedule and the template', () async {
      final id = await create(
        rule: Recurrence(
          interval: RecurrenceInterval.weekly,
          anchor: DateTime.utc(2026, 11, 1),
          endsOn: DateTime.utc(2027, 3, 1),
        ),
      );
      final item = (await outbox()).single;
      expect(item.entity, 'recurring');
      expect(item.op, 'upsert');
      expect(item.recordId, id);
      expect(item.groupId, gid);
      final p = payload(item);
      expect(p.keys, containsAll(['interval', 'anchor_date', 'ends_on', 'active', 'template']));
      expect(p['expense_id'], _expense);
      expect(p['interval'], 'weekly');
      expect(p['anchor_date'], '2026-11-01');
      expect(p['ends_on'], '2027-03-01');
      expect(p['active'], isTrue);
      expect(p['template'], template);
      expect(p['next_date'], '2026-11-22');
    });

    // #12
    test('the first copy is on or after today, never before', () async {
      // Today itself counts when it is a copy day, but the anchor day is the original, not a copy.
      final a = await create(
        rule: Recurrence(interval: RecurrenceInterval.monthly, anchor: DateTime.utc(2026, 9, 21)),
      );
      expect((await row(a)).nextDate, '2026-11-21');
      final b = await create(
        rule: Recurrence(interval: RecurrenceInterval.monthly, anchor: DateTime.utc(2026, 11, 21)),
      );
      expect((await row(b)).nextDate, '2026-12-21');
      final c = await create(
        rule: Recurrence(interval: RecurrenceInterval.yearly, anchor: DateTime.utc(2020, 2, 29)),
      );
      expect((await row(c)).nextDate, '2027-02-28');
    });

    // #12
    test('a rule that has already ended has no next date', () async {
      final id = await create(
        rule: Recurrence(
          interval: RecurrenceInterval.monthly,
          anchor: DateTime.utc(2026, 10, 15),
          endsOn: DateTime.utc(2026, 12, 1),
        ),
      );
      expect((await row(id)).nextDate, isNull);
      expect(payload((await outbox()).single)['next_date'], isNull);
    });
  });

  group('edit', () {
    // #12
    test('new expense fields alone leave the schedule out of the payload', () async {
      final id = await create();
      final newTemplate = {...template, 'total': 1600000};
      await repo.edit(await row(id), template: newTemplate);
      final p = payload((await outbox()).last);
      expect(p.keys, ['template']);
      expect(p['template'], newTemplate);
      final t = await row(id);
      expect(jsonDecode(t.template), newTemplate);
      expect(t.nextDate, '2026-12-15');
      expect(t.interval, 'monthly');
    });

    // #12
    test('a schedule change recomputes the next date', () async {
      final id = await create();
      await repo.edit(await row(id), interval: RecurrenceInterval.weekly);
      final p = payload((await outbox()).last);
      expect(p.keys.toSet(), {'interval', 'ends_on', 'next_date'});
      expect(p['interval'], 'weekly');
      // Weekly from Thu 15 Oct: copies fall on 19 Nov and 26 Nov, and today is the 21st.
      expect(p['next_date'], '2026-11-26');
      final t = await row(id);
      expect(t.interval, 'weekly');
      expect(t.nextDate, '2026-11-26');
      expect(t.anchorDate, '2026-10-15');
    });

    // #12
    test('an end date can be set and cleared', () async {
      final id = await create();
      await repo.edit(await row(id), endsOn: DateTime.utc(2027, 1, 1));
      expect((await row(id)).endsOn, '2027-01-01');
      expect(payload((await outbox()).last)['ends_on'], '2027-01-01');
      await repo.edit(await row(id), clearEnd: true);
      expect((await row(id)).endsOn, isNull);
      expect(payload((await outbox()).last).containsKey('ends_on'), isTrue);
      expect(payload((await outbox()).last)['ends_on'], isNull);
    });

    // #12
    test('an edit that changes nothing sends no schedule keys', () async {
      final id = await create();
      await repo.edit(await row(id), interval: RecurrenceInterval.monthly);
      expect(payload((await outbox()).last), isEmpty);
    });
  });

  group('stop and repeat again', () {
    // #12
    test('stop switches the template off and queues only that', () async {
      final id = await create();
      await repo.stop(await row(id));
      final t = await row(id);
      expect(t.active, isFalse);
      expect(t.syncState, SyncState.pending);
      expect(payload((await outbox()).last), {'active': false});
    });

    // #12
    test('repeat again switches it on and starts from today, not from the missed copies', () async {
      final id = await create();
      await repo.stop(await row(id));
      clock.advance(const Duration(days: 29)); // 20 Dec
      await repo.resume(await row(id));
      final t = await row(id);
      expect(t.active, isTrue);
      expect(t.nextDate, '2027-01-15');
      expect(payload((await outbox()).last), {'active': true, 'next_date': '2027-01-15'});
    });

    // #12
    test('ruleOf gives back the stored rule', () async {
      final id = await create(
        rule: Recurrence(
          interval: RecurrenceInterval.fortnightly,
          anchor: DateTime.utc(2026, 10, 1),
          endsOn: DateTime.utc(2027, 1, 1),
        ),
      );
      final rule = RecurringRepository.ruleOf(await row(id));
      expect(rule.interval, RecurrenceInterval.fortnightly);
      expect(rule.anchor, DateTime.utc(2026, 10, 1));
      expect(rule.endsOn, DateTime.utc(2027, 1, 1));
    });
  });

  group('reads', () {
    // #12
    test('watchForExpense finds the template started from the expense', () async {
      final id = await create();
      expect((await repo.watchForExpense(_expense).first)?.id, id);
      expect(await repo.watchForExpense('other').first, isNull);
      expect((await repo.watchOne(id).first)?.id, id);
    });

    // #12
    test('watchForExpense finds the template that made a copy, by recurring id', () async {
      final id = await create();
      expect(await repo.watchForExpense(_copy).first, isNull);
      expect((await repo.watchForExpense(_copy, recurringId: id).first)?.id, id);
    });

    // #12
    test('an active template comes first, a deleted one never shows', () async {
      final old = await create();
      await repo.stop(await row(old));
      clock.advance(const Duration(minutes: 1));
      final stopped = await create(rule: monthly);
      await repo.stop(await row(stopped));
      final live = await create();
      expect((await repo.watchForExpense(_expense).first)?.id, live);
      await (db.update(db.recurringTemplates)..where((t) => t.id.equals(live))).write(
        const RecurringTemplatesCompanion(deletedAt: Value('2026-11-21T10:00:00Z')),
      );
      expect((await repo.watchForExpense(_expense).first)?.active, isFalse);
    });

    // #12
    test('watchForGroup lists active ones first, by next date', () async {
      final later = await create(
        rule: Recurrence(interval: RecurrenceInterval.yearly, anchor: DateTime.utc(2025, 12, 30)),
      );
      final sooner = await create(
        rule: Recurrence(interval: RecurrenceInterval.weekly, anchor: DateTime.utc(2026, 11, 1)),
      );
      final off = await create(
        rule: Recurrence(interval: RecurrenceInterval.weekly, anchor: DateTime.utc(2026, 11, 2)),
      );
      await repo.stop(await row(off));
      final ids = [for (final t in await repo.watchForGroup(gid).first) t.id];
      expect(ids, [sooner, later, off]);
      expect(await repo.watchForGroup('other').first, isEmpty);
    });
  });

  group('pull', () {
    Map<String, Object?> serverTemplate(String id, {String interval = 'weekly', int seq = 5}) => {
      'id': id,
      'group_id': gid,
      'expense_id': _expense,
      'interval': interval,
      'anchor_date': '2026-10-15',
      'next_date': '2026-11-26',
      'ends_on': null,
      'active': true,
      'template': template,
      'created_at': '2026-11-20T10:00:00Z',
      'seq': seq,
    };

    PullPage page(Map<String, Object?> t) => PullPage(
      serverTime: clock.now(),
      rows: {
        'recurring_templates': [t],
      },
      nextCursors: const {gid: 9},
      userSeq: 0,
    );

    // #12
    test('a pulled template lands as synced', () async {
      const id = '01900000-0000-7000-8000-0000000000d1';
      await applier.apply(page(serverTemplate(id)));
      final t = await row(id);
      expect(t.syncState, SyncState.synced);
      expect(t.interval, 'weekly');
      expect(t.active, isTrue);
      expect(t.nextDate, '2026-11-26');
      expect(jsonDecode(t.template), template);
      expect(t.seq, 5);
      expect((await repo.watchForGroup(gid).first).single.id, id);
    });

    // #12
    test('a pull does not overwrite a template with a pending change', () async {
      final id = await create();
      await applier.apply(page(serverTemplate(id)));
      final t = await row(id);
      expect(t.interval, 'monthly');
      expect(t.syncState, SyncState.pending);
    });

    // #12
    test('losing the group removes its templates', () async {
      final id = await create();
      await applier.forgetGroup(gid);
      expect(await db.select(db.recurringTemplates).get(), isEmpty);
      expect(id, isNotEmpty);
    });
  });
}
