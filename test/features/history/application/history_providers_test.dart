import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/features/history/application/history_providers.dart';
import 'package:splitify/features/history/domain/version_diff.dart';

import '../../../support/history_data_fakes.dart';
import 'history_app_env.dart';

void main() {
  late HistoryEnv env;

  const expenseT = (kind: HistoryRecordKind.expense, id: 'e1');
  const paymentT = (kind: HistoryRecordKind.payment, id: 'p1');

  Future<void> settle() => pumpEventQueue();

  setUp(() async => env = await HistoryEnv.create());
  tearDown(() => env.dispose());

  group('historyRecordProvider', () {
    test('is null when the expense is not on this phone', () async {
      env.keep(historyRecordProvider(expenseT));
      await settle();
      expect(env.container.read(historyRecordProvider(expenseT)).value, isNull);
      expect(env.container.read(historyRecordProvider(expenseT)).hasValue, isTrue);
    });

    test('reads an expense with group, seq and the pending flag', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 4));
      env.keep(historyRecordProvider(expenseT));
      await settle();
      var r = env.container.read(historyRecordProvider(expenseT)).requireValue!;
      expect((r.groupId, r.seq, r.pending), ('g1', 4, false));
      expect(r.expense!.id, 'e1');
      expect(r.payment, isNull);

      await putRow(env.db, 'expenses', expenseRow('e1', seq: 4, syncState: 'pending'));
      await settle();
      r = env.container.read(historyRecordProvider(expenseT)).requireValue!;
      expect(r.pending, isTrue);
    });

    test('a failed sync state also counts as pending', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', syncState: 'failed'));
      env.keep(historyRecordProvider(expenseT));
      await settle();
      expect(env.container.read(historyRecordProvider(expenseT)).requireValue!.pending, isTrue);
    });

    test('reads a deleted payment too', () async {
      await putRow(env.db, 'payments', paymentRow('p1', deletedAt: '2026-11-21T10:00:00Z', seq: 7));
      env.keep(historyRecordProvider(paymentT));
      await settle();
      final r = env.container.read(historyRecordProvider(paymentT)).requireValue!;
      expect((r.groupId, r.seq, r.pending), ('g1', 7, false));
      expect(r.payment!.deletedAt, isNotNull);
      expect(r.expense, isNull);
    });

    test('a missing payment is null', () async {
      env.keep(historyRecordProvider(paymentT));
      await settle();
      expect(env.container.read(historyRecordProvider(paymentT)).value, isNull);
    });
  });

  group('historyFetchProvider', () {
    test('returns 0 without fetching when the record is not on the phone', () async {
      env.keep(historyFetchProvider(expenseT));
      await settle();
      expect(await env.container.read(historyFetchProvider(expenseT).future), 0);
      expect(env.history.calls, isEmpty);
    });

    // TC-20-03
    test('fetches newer versions once the record is known and caches them', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 2));
      env.history.rows.addAll([versionRow(1, seq: 1, op: 'insert'), versionRow(2, seq: 2)]);
      env.keep(historyFetchProvider(expenseT));
      await settle();
      expect(await env.container.read(historyFetchProvider(expenseT).future), 2);
      expect(env.history.calls, [(recordId: 'e1', afterSeq: 0)]);
      expect(await env.db.select(env.db.recordVersions).get(), hasLength(2));
    });

    test('fetches again when the record seq moves (a pull brought a new edit)', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 2));
      env.history.rows.addAll([versionRow(1, seq: 1, op: 'insert'), versionRow(2, seq: 2)]);
      env.keep(historyFetchProvider(expenseT));
      await settle();
      await env.container.read(historyFetchProvider(expenseT).future);

      env.history.rows.add(versionRow(3, seq: 5, op: 'delete'));
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 5, deletedAt: '2026-11-22T10:00:00Z'));
      await settle();
      expect(await env.container.read(historyFetchProvider(expenseT).future), 1);
      expect(env.history.calls.map((c) => c.afterSeq), [0, 2]);
      expect(await env.db.select(env.db.recordVersions).get(), hasLength(3));
    });

    test('does not fetch again when other columns change but seq does not', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 2));
      env.keep(historyFetchProvider(expenseT));
      await settle();
      await env.container.read(historyFetchProvider(expenseT).future);
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 2, syncState: 'pending'));
      await settle();
      expect(env.history.calls, hasLength(1));
    });

    test('offline surfaces the error and leaves the cache', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 2));
      await putRow(env.db, 'record_versions', versionRow(1, seq: 1, op: 'insert'));
      env.history.error = const NetworkException();
      env.keep(historyFetchProvider(expenseT));
      await settle();
      await expectLater(
        env.container.read(historyFetchProvider(expenseT).future),
        throwsA(isA<NetworkException>()),
      );
      expect(await env.db.select(env.db.recordVersions).get(), hasLength(1));
    });

    test('payments use the same fetch', () async {
      await putRow(env.db, 'payments', paymentRow('p1', seq: 3));
      env.history.rows.add(versionRow(1, seq: 3, recordId: 'p1', table: 'payments', op: 'insert'));
      env.keep(historyFetchProvider(paymentT));
      await settle();
      expect(await env.container.read(historyFetchProvider(paymentT).future), 1);
      expect(env.history.calls.single.recordId, 'p1');
    });
  });

  group('versionRecordOf', () {
    test('decodes the cached snapshot and times', () async {
      await putRow(
        env.db,
        'record_versions',
        versionRow(1, seq: 6, op: 'restore', changedAt: '2026-11-20T15:30:00+05:30'),
      );
      final v = versionRecordOf(await env.db.select(env.db.recordVersions).getSingle());
      expect(v.seq, 6);
      expect(v.op, 'restore');
      expect(v.snapshot['description'], 'Dinner');
      expect(v.snapshot['payers'], {'m1': 10000});
      expect(v.changedAt, DateTime.utc(2026, 11, 20, 10));
      expect(v.changedAt.isUtc, isTrue);
      expect(v.changedBy, 'u1');
    });
  });

  group('historyViewProvider', () {
    test('is loading before the record arrives', () {
      expect(env.container.read(historyViewProvider(expenseT)).isLoading, isTrue);
    });

    test('is data(null) when the record is not on this phone', () async {
      env.keep(historyViewProvider(expenseT));
      await settle();
      final v = env.container.read(historyViewProvider(expenseT));
      expect(v.hasValue, isTrue);
      expect(v.value, isNull);
    });

    // TC-20-03
    test('builds the timeline newest first with names, me and the pending flag', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 2, syncState: 'pending'));
      await putRow(env.db, 'record_versions', versionRow(1, seq: 1, op: 'insert'));
      await putRow(
        env.db,
        'record_versions',
        versionRow(
          2,
          seq: 2,
          changedBy: 'u2',
          changedAt: '2026-11-21T10:00:00Z',
          snapshot: {
            'description': 'Dinner out',
            'total': 12000,
            'currency': 'INR',
            'date': '2026-11-20',
            'category': 'food.dining',
            'payers': {'m1': 12000},
            'shares': {'m1': 6000, 'm2': 6000},
            'split_kind': 'equal',
          },
        ),
      );
      env.keep(historyViewProvider(expenseT));
      await settle();
      final view = env.container.read(historyViewProvider(expenseT)).requireValue!;
      expect(view.target, expenseT);
      expect(view.record.pending, isTrue);
      expect(view.entries.map((e) => e.seq), [2, 1]);
      expect(view.entries.map((e) => e.op), [HistoryOp.update, HistoryOp.create]);
      expect(view.entries.first.changedBy, 'u2');
      expect(view.memberNames, {'m1': 'Mohit', 'm2': 'Asha', 'm3': 'Ravi'});
      expect(view.userNames, {'u1': 'Mohit', 'u2': 'Asha'});
      expect(view.meUserId, 'u1');
      expect(view.meMemberId, 'm1');
    });

    test('an empty cache gives an empty timeline', () async {
      await putRow(env.db, 'expenses', expenseRow('e1', seq: 2));
      env.keep(historyViewProvider(expenseT));
      await settle();
      expect(env.container.read(historyViewProvider(expenseT)).requireValue!.entries, isEmpty);
    });

    test('removed members keep their names; a removed me has no member id', () async {
      await putRow(env.db, 'expenses', expenseRow('e1'));
      await putRow(
        env.db,
        'group_members',
        memberRow('m1', userId: 'u1', name: 'Mohit', deletedAt: '2026-11-21T10:00:00Z'),
      );
      env.keep(historyViewProvider(expenseT));
      await settle();
      final view = env.container.read(historyViewProvider(expenseT)).requireValue!;
      expect(view.memberNames['m1'], 'Mohit');
      expect(view.meMemberId, isNull);
      expect(view.meUserId, 'u1');
    });

    test('signed out: no me', () async {
      env.dispose();
      env = await HistoryEnv.create(userId: null);
      await putRow(env.db, 'expenses', expenseRow('e1'));
      env.keep(historyViewProvider(expenseT));
      await settle();
      final view = env.container.read(historyViewProvider(expenseT)).requireValue!;
      expect(view.meUserId, isNull);
      expect(view.meMemberId, isNull);
    });

    test('payment history uses the payment diff', () async {
      await putRow(env.db, 'payments', paymentRow('p1', seq: 1));
      await putRow(
        env.db,
        'record_versions',
        versionRow(
          1,
          seq: 1,
          recordId: 'p1',
          table: 'payments',
          op: 'insert',
          snapshot: {
            'from_member': 'm1',
            'to_member': 'm2',
            'amount': 5000,
            'currency': 'INR',
            'date': '2026-11-20',
          },
        ),
      );
      env.keep(historyViewProvider(paymentT));
      await settle();
      final view = env.container.read(historyViewProvider(paymentT)).requireValue!;
      expect(view.entries.single.op, HistoryOp.create);
      expect(view.record.payment!.id, 'p1');
    });
  });
}
