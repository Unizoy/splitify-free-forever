import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/comment_rules.dart';
import 'package:splitify/features/comments/application/comments_providers.dart';

import '../../../support/history_data_fakes.dart';
import '../../history/application/history_app_env.dart';

void main() {
  late HistoryEnv env;

  const target = (groupId: 'g1', targetType: 'expense', targetId: 'e1');

  setUp(() async => env = await HistoryEnv.create());
  tearDown(() => env.dispose());

  List<CommentView> thread() => env.container.read(commentThreadProvider(target)).requireValue;

  Future<void> open() async {
    env.keep(commentThreadProvider(target));
    await pumpEventQueue();
  }

  group('commentThreadProvider', () {
    test('is loading before the streams answer', () {
      expect(env.container.read(commentThreadProvider(target)).isLoading, isTrue);
    });

    test('an empty thread is data([])', () async {
      await open();
      expect(thread(), isEmpty);
    });

    test('oldest first, only this target, deleted comments hidden', () async {
      await putRow(env.db, 'comments', commentRow('c2', createdAt: '2026-11-20T12:00:00Z'));
      await putRow(env.db, 'comments', commentRow('c1', createdAt: '2026-11-20T11:00:00Z'));
      await putRow(
        env.db,
        'comments',
        commentRow('gone', createdAt: '2026-11-20T11:30:00Z', deletedAt: '2026-11-21T10:00:00Z'),
      );
      await putRow(env.db, 'comments', commentRow('other', targetId: 'e2'));
      await open();
      expect(thread().map((c) => c.comment.id), ['c1', 'c2']);
    });

    test('mine, author name and member id come from the members by user id', () async {
      await putRow(
        env.db,
        'comments',
        commentRow('c1', createdBy: 'u1', createdAt: '2026-11-20T11:00:00Z'),
      );
      await putRow(
        env.db,
        'comments',
        commentRow('c2', createdBy: 'u2', createdAt: '2026-11-20T12:00:00Z'),
      );
      await putRow(
        env.db,
        'comments',
        commentRow('c3', createdBy: 'u9', createdAt: '2026-11-20T13:00:00Z'),
      );
      await putRow(env.db, 'comments', commentRow('c4', createdAt: '2026-11-20T14:00:00Z'));
      await open();
      final t = {for (final c in thread()) c.comment.id: c};
      expect((t['c1']!.mine, t['c1']!.authorName, t['c1']!.authorMemberId), (true, 'Mohit', 'm1'));
      expect((t['c2']!.mine, t['c2']!.authorName, t['c2']!.authorMemberId), (false, 'Asha', 'm2'));
      // Author no longer a member (or a deleted account): no name, never mine.
      expect((t['c3']!.mine, t['c3']!.authorName, t['c3']!.authorMemberId), (false, null, null));
      expect((t['c4']!.mine, t['c4']!.authorName), (false, null));
    });

    test('unsynced follows the row sync state', () async {
      await putRow(env.db, 'comments', commentRow('c1', syncState: 'pending'));
      await putRow(env.db, 'comments', commentRow('c2', createdAt: '2026-11-20T11:00:00Z'));
      await open();
      expect(thread().map((c) => c.unsynced), [true, false]);
    });

    test('signed out: nothing is mine', () async {
      env.dispose();
      env = await HistoryEnv.create(userId: null);
      await putRow(env.db, 'comments', commentRow('c1', createdBy: 'u1'));
      await open();
      expect(thread().single.mine, isFalse);
    });
  });

  group('CommentActions.add', () {
    // TC-13-03
    test('offline: trims the body, saves the row and queues one comment mutation', () async {
      final ok = await env.container.read(commentActionsProvider).add(target, '  Paid in cash \n');
      expect(ok, isTrue);

      final row = await env.db.select(env.db.comments).getSingle();
      expect(row.body, 'Paid in cash');
      expect(row.groupId, 'g1');
      expect(row.targetType, 'expense');
      expect(row.targetId, 'e1');
      expect(row.createdBy, 'u1');
      expect(row.createdAt, '2026-11-22T09:00:00.000Z');
      expect(row.syncState, SyncState.pending);

      final out = await env.db.select(env.db.outbox).getSingle();
      expect(out.entity, 'comment');
      expect(out.op, SyncOp.upsert.name);
      expect(out.recordId, row.id);
      expect(out.groupId, 'g1');
      final payload = jsonDecode(out.payload) as Map;
      expect(payload['body'], 'Paid in cash');
      expect(payload['target_type'], 'expense');
      expect(payload['target_id'], 'e1');
    });

    // TC-13-03
    test('the new comment shows in the thread as mine and not synced', () async {
      await open();
      await env.container.read(commentActionsProvider).add(target, 'Hello');
      await pumpEventQueue();
      final c = thread().single;
      expect(c.mine, isTrue);
      expect(c.authorName, 'Mohit');
      expect(c.unsynced, isTrue);
      expect(c.comment.body, 'Hello');
    });

    // TC-13-03
    test('empty and too long comments are refused and write nothing', () async {
      final actions = env.container.read(commentActionsProvider);
      expect(await actions.add(target, ''), isFalse);
      expect(await actions.add(target, '   \n'), isFalse);
      expect(await actions.add(target, 'a' * (CommentRules.maxLength + 1)), isFalse);
      expect(await env.db.select(env.db.comments).get(), isEmpty);
      expect(await env.db.select(env.db.outbox).get(), isEmpty);
    });

    test('exactly the maximum length is accepted', () async {
      final ok = await env.container
          .read(commentActionsProvider)
          .add(target, 'a' * CommentRules.maxLength);
      expect(ok, isTrue);
    });

    test('signed out: saved without an author', () async {
      env.dispose();
      env = await HistoryEnv.create(userId: null);
      await env.container.read(commentActionsProvider).add(target, 'x');
      expect((await env.db.select(env.db.comments).getSingle()).createdBy, isNull);
    });

    test('a payment target is kept', () async {
      const p = (groupId: 'g1', targetType: 'payment', targetId: 'p1');
      await env.container.read(commentActionsProvider).add(p, 'thanks');
      final row = await env.db.select(env.db.comments).getSingle();
      expect((row.targetType, row.targetId), ('payment', 'p1'));
    });
  });

  group('CommentActions.delete', () {
    test('soft-deletes the row and queues a delete mutation', () async {
      await putRow(env.db, 'comments', commentRow('c1', createdBy: 'u1'));
      await open();
      await env.container.read(commentActionsProvider).delete(thread().single.comment);
      final row = await env.db.select(env.db.comments).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.syncState, SyncState.pending);
      final out = await env.db.select(env.db.outbox).getSingle();
      expect(out.entity, 'comment');
      expect(out.op, SyncOp.delete.name);
      expect(out.recordId, 'c1');
      await pumpEventQueue();
      expect(thread(), isEmpty);
    });
  });
}
