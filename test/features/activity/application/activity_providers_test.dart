import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/activity_repository.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

import '../../../support/fakes.dart';
import '../../../support/ledger_seed.dart';

final _members = {
  for (final m in [
    seedMember('m1', userId: 'u1', name: 'Mohit'),
    seedMember('m2', userId: 'u2', name: 'Asha', position: 1),
    seedMember('m3', name: 'Ravi', position: 2),
    seedMember('n1', groupId: 'g2', userId: 'u1', name: 'Mohit (Flat)'),
  ])
    m.id: m,
};

ActivitySources _sources({
  List<LocalActivity> activity = const [],
  List<OutboxItem> pending = const [],
  List<LocalExpense> expenses = const [],
  List<LocalPayment> payments = const [],
  List<LocalGroup>? groups,
  Map<String, LocalMember>? members,
}) => ActivitySources(
  activity: activity,
  pending: pending,
  groups: {
    for (final g in groups ?? [seedGroup(), seedGroup(id: 'g2', name: 'Flat')]) g.id: g,
  },
  members: members ?? _members,
  expenses: {for (final e in expenses) e.id: e},
  payments: {for (final p in payments) p.id: p},
);

ActivityItem _one(
  LocalActivity a, {
  List<LocalExpense> expenses = const [],
  String? userId = 'u1',
}) => buildActivityItems(_sources(activity: [a], expenses: expenses), userId).single;

ActivityItem _pending(
  OutboxItem o, {
  List<LocalExpense> expenses = const [],
  List<LocalPayment> payments = const [],
  List<LocalGroup>? groups,
  Map<String, LocalMember>? members,
}) => buildActivityItems(
  _sources(pending: [o], expenses: expenses, payments: payments, groups: groups, members: members),
  'u1',
).single;

DateTime _at(String iso) => DateTime.parse(iso).toLocal();

void main() {
  group('server rows', () {
    test('expense_added carries description, total, currency and opens the expense', () {
      final i = _one(
        seedActivity(
          'a1',
          'expense_added',
          actorMemberId: 'm2',
          actorUserId: 'u2',
          targetType: 'expense',
          targetId: 'e1',
          data: {'description': 'Dinner', 'total': 30000, 'currency': 'INR '},
          createdAt: '2026-11-21T10:00:00Z',
        ),
      );
      expect(i.id, 'a1');
      expect(i.type, 'expense_added');
      expect((i.groupId, i.groupName), ('g1', 'Goa trip'));
      expect(i.at, _at('2026-11-21T10:00:00Z'));
      expect((i.actor.name, i.actor.seed, i.actor.isMe), ('Asha', 'm2', false));
      expect((i.description, i.amount, i.currency), ('Dinner', 30000, 'INR'));
      expect((i.targetType, i.targetId), ('expense', 'e1'));
      expect(i.pending, isFalse);
      expect((i.member, i.from, i.to), (null, null, null));
    });

    test(
      'a deleted expense or payment opens its page (Deleted + Restore); a deleted group the group',
      () {
        expect(
          (_one(seedActivity('a', 'expense_deleted', targetType: 'expense', targetId: 'e1')))
              .targetId,
          'e1',
        );
        final p = _one(seedActivity('a', 'payment_deleted', targetType: 'payment', targetId: 'p1'));
        expect((p.targetType, p.targetId), ('payment', 'p1'));
        final g = _one(seedActivity('a', 'group_deleted', targetType: 'group', targetId: 'g1'));
        expect((g.targetType, g.targetId), ('group', 'g1'));
      },
    );

    test('payment rows name payer and receiver and open the payment', () {
      final i = _one(
        seedActivity(
          'a',
          'payment_added',
          actorMemberId: 'm2',
          targetType: 'payment',
          targetId: 'p1',
          data: {'from_member': 'm2', 'to_member': 'm1', 'amount': 5000, 'currency': 'INR'},
        ),
      );
      expect((i.from!.name, i.from!.isMe), ('Asha', false));
      expect((i.to!.name, i.to!.isMe), ('Mohit', true));
      expect((i.amount, i.currency), (5000, 'INR'));
      expect((i.targetType, i.targetId), ('payment', 'p1'));
      expect(i.description, isNull);
    });

    test('a payment with unknown people has empty names', () {
      final i = _one(seedActivity('a', 'payment_edited', data: {'amount': 10}));
      expect((i.from!.name, i.from!.seed, i.to!.name), ('', '', ''));
      expect((i.targetType, i.targetId), ('group', 'g1'));
    });

    test('comment rows use the target in data and the local expense description', () {
      final e = seedExpense(
        'e1',
        description: 'Cab',
        total: 1,
        payers: {'m1': 1},
        shares: {'m1': 1},
      );
      final onExpense = _one(
        seedActivity('c1', 'comment_added', data: {'target_type': 'expense', 'target_id': 'e1'}),
        expenses: [e],
      );
      expect(onExpense.description, 'Cab');
      expect((onExpense.targetType, onExpense.targetId), ('expense', 'e1'));
      final onPayment = _one(
        seedActivity('c2', 'comment_added', data: {'target_type': 'payment', 'target_id': 'p1'}),
      );
      expect(onPayment.description, isNull);
      expect((onPayment.targetType, onPayment.targetId), ('payment', 'p1'));
      final unknown = _one(
        seedActivity('c3', 'comment_added', data: {'target_type': 'expense', 'target_id': 'zz'}),
      );
      expect(unknown.description, isNull);
      // A deleted comment keeps pointing at what it was on.
      final deleted = _one(
        seedActivity('c4', 'comment_deleted', data: {'target_type': 'expense', 'target_id': 'e1'}),
        expenses: [e],
      );
      expect((deleted.targetType, deleted.targetId), ('expense', 'e1'));
      // A comment on nothing opens the group.
      final nowhere = _one(seedActivity('c5', 'comment_added'));
      expect((nowhere.targetType, nowhere.targetId), ('group', 'g1'));
    });

    test('group rows name the group (data name wins) and open it', () {
      final named = _one(seedActivity('a', 'group_created', data: {'name': 'Goa 2'}));
      expect(named.description, 'Goa 2');
      final plain = _one(seedActivity('b', 'group_updated'));
      expect(plain.description, 'Goa trip');
      final settings = _one(seedActivity('c', 'settings_changed'));
      expect(settings.description, 'Goa trip');
      expect((settings.targetType, settings.targetId), ('group', 'g1'));
      final other = _one(seedActivity('d', 'group_archived', groupId: 'g2'));
      expect((other.description, other.groupName), ('Flat', 'Flat'));
      final lost = _one(seedActivity('e', 'group_archived', groupId: 'gone'));
      expect((lost.description, lost.groupName), ('', ''));
    });

    test('member rows name the member, falling back to the name in data', () {
      final known = _one(seedActivity('a', 'member_added', data: {'member_id': 'm3'}));
      expect((known.member!.name, known.member!.seed, known.member!.isMe), ('Ravi', 'm3', false));
      final unknown = _one(
        seedActivity('b', 'member_added', data: {'member_id': 'zz', 'name': 'Zed'}),
      );
      expect((unknown.member!.name, unknown.member!.seed), ('Zed', 'zz'));
      final nameOnly = _one(seedActivity('c', 'member_removed', data: {'name': 'Yan'}));
      expect((nameOnly.member!.name, nameOnly.member!.seed), ('Yan', 'Yan'));
      final me = _one(seedActivity('d', 'member_joined', data: {'member_id': 'm1'}));
      expect(me.member!.isMe, isTrue);
      final none = _one(seedActivity('e', 'member_added'));
      expect((none.member!.name, none.member!.seed), ('', ''));
    });

    test('the actor falls back to a member with the same user id, else an empty name', () {
      final byMember = _one(seedActivity('a', 'expense_added', actorMemberId: 'm2'));
      expect((byMember.actor.name, byMember.actor.isMe), ('Asha', false));
      // Member known and the actor user is me.
      final mine = _one(seedActivity('b', 'expense_added', actorMemberId: 'm3', actorUserId: 'u1'));
      expect((mine.actor.name, mine.actor.isMe), ('Ravi', true));
      // Unknown member id: look the user up in the same group.
      final byUser = _one(
        seedActivity('c', 'expense_added', actorMemberId: 'zz', actorUserId: 'u2'),
      );
      expect((byUser.actor.name, byUser.actor.seed, byUser.actor.isMe), ('Asha', 'm2', false));
      final byUserMe = _one(seedActivity('d', 'expense_added', actorUserId: 'u1'));
      expect((byUserMe.actor.name, byUserMe.actor.isMe), ('Mohit', true));
      // The same user in another group does not count.
      final otherGroup = _one(seedActivity('e', 'expense_added', actorUserId: 'u2', groupId: 'g2'));
      expect((otherGroup.actor.name, otherGroup.actor.seed), ('', 'u2'));
      final stranger = _one(seedActivity('f', 'expense_added', actorUserId: 'u7'));
      expect((stranger.actor.name, stranger.actor.seed, stranger.actor.isMe), ('', 'u7', false));
      final nobody = _one(seedActivity('g', 'expense_added'));
      expect((nobody.actor.name, nobody.actor.seed, nobody.actor.isMe), ('', 'g', false));
      final signedOut = _one(seedActivity('h', 'expense_added', actorUserId: 'u1'), userId: null);
      expect((signedOut.actor.name, signedOut.actor.isMe), ('Mohit', false));
    });

    test('odd rows: no time, bad JSON, no amounts, unknown target types', () {
      final i = _one(
        LocalActivity(
          id: 'x',
          groupId: 'g1',
          type: 'expense_added',
          targetType: 'weird',
          targetId: 'w',
          data: '[1,2]',
          seq: 1,
        ),
      );
      expect(i.at, DateTime.fromMillisecondsSinceEpoch(0));
      expect((i.description, i.amount, i.currency), (null, null, null));
      expect((i.targetType, i.targetId), ('group', 'g1'));
      final empty = _one(
        LocalActivity(id: 'y', groupId: 'g1', type: 'expense_added', data: '', seq: 1),
      );
      expect(empty.amount, isNull);
      final bad = _one(
        LocalActivity(
          id: 'z',
          groupId: 'g1',
          type: 'expense_added',
          data: '{}',
          createdAt: 'not a date',
          seq: 1,
        ),
      );
      expect(bad.at, DateTime.fromMillisecondsSinceEpoch(0));
    });

    // Final QA: a deleted group's history left the feed (only its "deleted" line stays).
    test('activity of a deleted group is left out, except the deletion itself', () {
      final gone = seedGroup(id: 'g2', name: 'Flat', deletedAt: '2026-11-22T10:00:00Z');
      final items = buildActivityItems(
        _sources(
          activity: [
            seedActivity('a', 'expense_added'),
            seedActivity('b', 'expense_added', groupId: 'g2'),
            seedActivity('c', 'group_deleted', groupId: 'g2'),
          ],
          groups: [seedGroup(), gone],
        ),
        'u1',
      );
      expect(items.map((i) => i.id), ['a', 'c']);
    });

    test('amount is read from total or amount, as an int', () {
      expect(_one(seedActivity('a', 'expense_added', data: {'total': 12.0})).amount, 12);
      expect(_one(seedActivity('b', 'payment_added', data: {'amount': 7})).amount, 7);
      expect(_one(seedActivity('c', 'payment_added', data: {'amount': '7'})).amount, isNull);
    });
  });

  group('pending changes (outbox)', () {
    final e0 = seedExpense(
      'e1',
      description: 'Dinner',
      total: 900,
      payers: {'m1': 900},
      shares: {'m1': 900},
      seq: 0,
    );
    final e1 = seedExpense(
      'e1',
      description: 'Dinner',
      total: 900,
      payers: {'m1': 900},
      shares: {'m1': 900},
    );

    test('a new expense (local seq 0) is "added"; an existing one "edited"', () {
      final added = _pending(seedOutbox(1, 'expense', 'upsert', 'e1'), expenses: [e0]);
      expect(added.type, 'expense_added');
      expect((added.description, added.amount, added.currency), ('Dinner', 900, 'INR'));
      expect(added.pending, isTrue);
      expect(added.id, 'pending-1');
      expect((added.targetType, added.targetId), ('expense', 'e1'));
      expect(added.actor.isMe, isTrue);
      expect(added.actor.name, 'Mohit');
      expect(added.groupName, 'Goa trip');
      expect(added.at, _at('2026-11-22T09:00:00Z'));
      final edited = _pending(seedOutbox(2, 'expense', 'upsert', 'e1'), expenses: [e1]);
      expect(edited.type, 'expense_edited');
    });

    test('without a local row the payload fills in, and the expense counts as new', () {
      final i = _pending(
        seedOutbox(
          3,
          'expense',
          'upsert',
          'ex',
          payload: {'description': 'Chai', 'total': 40, 'currency': 'USD'},
        ),
      );
      expect(i.type, 'expense_added');
      expect((i.description, i.amount, i.currency), ('Chai', 40, 'USD'));
    });

    test('delete and restore of an expense', () {
      final del = _pending(seedOutbox(4, 'expense', 'delete', 'e1'), expenses: [e1]);
      expect(del.type, 'expense_deleted');
      expect((del.targetType, del.targetId), ('expense', 'e1'));
      final res = _pending(seedOutbox(5, 'expense', 'restore', 'e1'), expenses: [e1]);
      expect(res.type, 'expense_restored');
      expect((res.targetType, res.targetId), ('expense', 'e1'));
    });

    test('payments: added / edited / deleted / restored', () {
      final p0 = seedPayment('p1', from: 'm2', to: 'm1', amount: 250, seq: 0);
      final p1 = seedPayment('p1', from: 'm2', to: 'm1', amount: 250);
      final added = _pending(seedOutbox(1, 'payment', 'upsert', 'p1'), payments: [p0]);
      expect(added.type, 'payment_added');
      expect((added.from!.name, added.to!.name, added.to!.isMe), ('Asha', 'Mohit', true));
      expect((added.amount, added.currency), (250, 'INR'));
      expect((added.targetType, added.targetId), ('payment', 'p1'));
      expect(
        _pending(seedOutbox(2, 'payment', 'upsert', 'p1'), payments: [p1]).type,
        'payment_edited',
      );
      final del = _pending(seedOutbox(3, 'payment', 'delete', 'p1'), payments: [p1]);
      expect(del.type, 'payment_deleted');
      expect((del.targetType, del.targetId), ('payment', 'p1'));
      expect(
        _pending(seedOutbox(4, 'payment', 'restore', 'p1'), payments: [p1]).type,
        'payment_restored',
      );
    });

    test('a payment without a local row uses the payload', () {
      final i = _pending(
        seedOutbox(
          5,
          'payment',
          'upsert',
          'px',
          payload: {'from_member': 'm2', 'to_member': 'm3', 'amount': 99, 'currency': 'EUR'},
        ),
      );
      expect(i.type, 'payment_added');
      expect((i.from!.name, i.to!.name, i.amount, i.currency), ('Asha', 'Ravi', 99, 'EUR'));
    });

    test('group: created, updated, archived, unarchived, deleted, restored', () {
      final fresh = seedGroup(seq: 0);
      final old = seedGroup();
      String typeOf(String op, {Map<String, Object?> payload = const {}, LocalGroup? g}) =>
          _pending(seedOutbox(1, 'group', op, 'g1', payload: payload), groups: [?g]).type;
      expect(typeOf('upsert', g: fresh), 'group_created');
      expect(typeOf('upsert'), 'group_created');
      expect(typeOf('upsert', g: old, payload: {'name': 'New'}), 'group_updated');
      expect(
        typeOf('upsert', g: old, payload: {'archived_at': '2026-11-22T00:00:00Z'}),
        'group_archived',
      );
      expect(typeOf('upsert', g: old, payload: {'archived_at': null}), 'group_unarchived');
      expect(typeOf('delete', g: old), 'group_deleted');
      expect(typeOf('restore', g: old), 'group_restored');
      final i = _pending(
        seedOutbox(2, 'group', 'upsert', 'g1', payload: {'name': 'From payload'}),
        groups: const [],
      );
      expect((i.description, i.groupName), ('From payload', ''));
      expect((i.targetType, i.targetId), ('group', 'g1'));
      final named = _pending(seedOutbox(3, 'group', 'upsert', 'g1'), groups: [old]);
      expect(named.description, 'Goa trip');
    });

    test('members: added, removed, renamed', () {
      final added = _pending(
        seedOutbox(1, 'member', 'upsert', 'm9', payload: {'display_name': 'Neha'}),
      );
      expect(added.type, 'member_added');
      expect((added.member!.name, added.member!.seed), ('Neha', 'm9'));
      expect(added.description, 'Goa trip');
      expect((added.targetType, added.targetId), ('group', 'g1'));
      final newLocal = _pending(
        seedOutbox(2, 'member', 'upsert', 'm3'),
        members: {
          ..._members,
          'm3': seedMember('m3', name: 'Ravi', seq: 0),
        },
      );
      expect(newLocal.type, 'member_added');
      final renamed = _pending(seedOutbox(3, 'member', 'upsert', 'm3'));
      expect(renamed.type, 'group_updated');
      expect(renamed.member!.name, 'Ravi');
      final removed = _pending(seedOutbox(4, 'member', 'delete', 'm3'));
      expect(removed.type, 'member_removed');
    });

    test('comments: added and deleted open the group', () {
      final added = _pending(seedOutbox(1, 'comment', 'upsert', 'c1'));
      expect(added.type, 'comment_added');
      expect((added.targetType, added.targetId), ('group', 'g1'));
      expect(_pending(seedOutbox(2, 'comment', 'delete', 'c1')).type, 'comment_deleted');
    });

    test('unknown entities are ignored', () {
      expect(
        buildActivityItems(_sources(pending: [seedOutbox(1, 'thing', 'upsert', 'x')]), 'u1'),
        isEmpty,
      );
    });

    test('without an account the actor is empty but still "me"', () {
      final i = buildActivityItems(
        _sources(pending: [seedOutbox(1, 'comment', 'upsert', 'c1')]),
        null,
      ).single;
      expect((i.actor.name, i.actor.seed, i.actor.isMe), ('', '', true));
    });

    test('in a group where I am not a member the actor is empty with my user id', () {
      final i = buildActivityItems(
        _sources(pending: [seedOutbox(1, 'comment', 'upsert', 'c1', groupId: 'g9')]),
        'u1',
      ).single;
      expect((i.actor.name, i.actor.seed, i.actor.isMe), ('', 'u1', true));
    });
  });

  test('server rows and pending changes are mixed newest first', () {
    final items = buildActivityItems(
      _sources(
        activity: [
          seedActivity('old', 'expense_added', createdAt: '2026-11-20T10:00:00Z'),
          seedActivity('new', 'payment_added', createdAt: '2026-11-22T12:00:00Z'),
        ],
        pending: [seedOutbox(1, 'comment', 'upsert', 'c', createdAt: '2026-11-22T09:00:00Z')],
      ),
      'u1',
    );
    expect([for (final i in items) i.id], ['new', 'pending-1', 'old']);
  });

  group('filters', () {
    // TC-18-02
    test('TC-18-02 every type lands in its chip', () {
      const expected = {
        ActivityFilter.expenses: [
          'expense_added',
          'expense_edited',
          'expense_deleted',
          'expense_restored',
          'recurring_created',
          'recurring_paused',
          'import_completed',
        ],
        ActivityFilter.payments: [
          'payment_added',
          'payment_edited',
          'payment_deleted',
          'payment_restored',
          'reminder_sent',
        ],
        ActivityFilter.comments: ['comment_added', 'comment_deleted'],
        ActivityFilter.groups: [
          'group_created',
          'group_updated',
          'group_archived',
          'group_unarchived',
          'group_deleted',
          'group_restored',
          'member_added',
          'member_removed',
          'member_joined',
          'member_left',
          'settings_changed',
        ],
      };
      expected.forEach((filter, types) {
        for (final t in types) {
          expect(ActivityItem.filterOf(t), filter, reason: t);
        }
      });
    });

    // TC-18-02
    test('TC-18-02 filterActivity keeps the chip, "all" keeps everything in order', () {
      final items = buildActivityItems(
        _sources(
          activity: [
            seedActivity('1', 'expense_added', createdAt: '2026-11-22T10:00:00Z'),
            seedActivity('2', 'payment_added', createdAt: '2026-11-22T11:00:00Z'),
            seedActivity('3', 'comment_added', createdAt: '2026-11-22T12:00:00Z'),
            seedActivity('4', 'member_added', createdAt: '2026-11-22T13:00:00Z'),
            seedActivity('5', 'expense_deleted', createdAt: '2026-11-22T14:00:00Z'),
          ],
        ),
        'u1',
      );
      List<String> ids(ActivityFilter f) => [for (final i in filterActivity(items, f)) i.id];
      expect(ids(ActivityFilter.all), ['5', '4', '3', '2', '1']);
      expect(ids(ActivityFilter.expenses), ['5', '1']);
      expect(ids(ActivityFilter.payments), ['2']);
      expect(ids(ActivityFilter.comments), ['3']);
      expect(ids(ActivityFilter.groups), ['4']);
      expect(items.first.filter, ActivityFilter.expenses);
    });
  });

  group('activityItemsProvider', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() async {
      db = testDb();
      c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue('u1'),
        ],
      );
      await db.seed(
        groups: [
          seedGroup(),
          seedGroup(id: 'g2', name: 'Flat'),
        ],
        members: [
          seedMember('m1', userId: 'u1', name: 'Mohit'),
          seedMember('n1', groupId: 'g2', userId: 'u1', name: 'Mohit'),
        ],
        expenses: [
          seedExpense('e1', description: 'Dinner', total: 1, payers: {'m1': 1}, shares: {'m1': 1}),
        ],
        activity: [
          seedActivity(
            'a1',
            'expense_added',
            actorMemberId: 'm1',
            createdAt: '2026-11-20T10:00:00Z',
            data: {'description': 'Dinner', 'total': 1, 'currency': 'INR'},
          ),
          seedActivity(
            'a2',
            'group_created',
            groupId: 'g2',
            createdAt: '2026-11-21T10:00:00Z',
            seq: 2,
          ),
          seedActivity(
            'a3',
            'comment_added',
            createdAt: '2026-11-21T11:00:00Z',
            data: {'target_type': 'expense', 'target_id': 'e1'},
            seq: 3,
          ),
        ],
        outbox: [seedOutbox(1, 'group', 'upsert', 'g2', groupId: 'g2')],
      );
    });

    tearDown(() async {
      c.dispose();
      await db.close();
    });

    Future<List<ActivityItem>> items(String? groupId) {
      final done = Completer<List<ActivityItem>>();
      late final ProviderSubscription<AsyncValue<List<ActivityItem>>> sub;
      sub = c.listen(activityItemsProvider(groupId), (_, n) {
        if (done.isCompleted) return;
        if (n.hasValue) {
          done.complete(n.requireValue);
        } else if (n.hasError) {
          done.completeError(n.error!);
        }
      }, fireImmediately: true);
      return done.future.whenComplete(sub.close);
    }

    test('all groups: server rows and pending changes, newest first', () async {
      final all = await items(null);
      expect([for (final i in all) i.id], ['pending-1', 'a3', 'a2', 'a1']);
      expect(all.where((i) => i.pending), hasLength(1));
      expect(all[1].description, 'Dinner');
      expect(all[1].targetId, 'e1');
    });

    test('one group', () async {
      final g2 = await items('g2');
      expect([for (final i in g2) i.id], ['pending-1', 'a2']);
      expect([for (final i in g2) i.groupName].toSet(), {'Flat'});
      final g1 = await items('g1');
      expect([for (final i in g1) i.id], ['a3', 'a1']);
      expect(g1.last.actor.name, 'Mohit');
      expect(g1.last.actor.isMe, isTrue);
    });

    test('the repository provider reads the same database', () {
      expect(c.read(activityRepositoryProvider).db, same(db));
    });
  });
}
