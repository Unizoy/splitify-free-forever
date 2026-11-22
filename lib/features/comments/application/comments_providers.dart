import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/expense_reads.dart';
import 'package:splitify/data/repositories/history_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/rules/comment_rules.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;

/// The record a thread belongs to (`comments.target_type` = `expense` | `payment`).
typedef CommentTarget = ({String groupId, String targetType, String targetId});

/// One comment as the thread shows it.
final class CommentView {
  const CommentView({
    required this.comment,
    required this.mine,
    this.authorName,
    this.authorMemberId,
  });

  final LocalComment comment;

  /// Written by the signed-in user: shown on the right, can be deleted (author only, TC-13-04).
  final bool mine;

  /// Author's name in this group; null when the author is no longer a member (or a deleted account).
  final String? authorName;

  /// Author's member id (avatar colour).
  final String? authorMemberId;

  bool get unsynced => comment.syncState != SyncState.synced;
}

final _commentsProvider = StreamProvider.autoDispose.family<List<LocalComment>, String>(
  (ref, targetId) => ref.watch(commentsRepositoryProvider).watchForTarget(targetId),
);

final _membersProvider = StreamProvider.autoDispose.family<List<LocalMember>, String>(
  (ref, groupId) => ref.watch(expensesRepositoryProvider).watchAllMembers(groupId),
);

/// Live, oldest-first thread of one expense or payment (08 #13).
final commentThreadProvider = Provider.autoDispose
    .family<AsyncValue<List<CommentView>>, CommentTarget>((ref, t) {
      final comments = ref.watch(_commentsProvider(t.targetId));
      final members = ref.watch(_membersProvider(t.groupId));
      for (final v in [comments, members]) {
        if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
      }
      if (!comments.hasValue || !members.hasValue) return const AsyncLoading();
      final uid = ref.watch(currentUserIdProvider);
      final byUser = <String, LocalMember>{
        for (final m in members.requireValue)
          if (m.userId != null) m.userId!: m,
      };
      return AsyncData([
        for (final c in comments.requireValue)
          CommentView(
            comment: c,
            mine: uid != null && c.createdBy == uid,
            authorName: byUser[c.createdBy]?.displayName,
            authorMemberId: byUser[c.createdBy]?.id,
          ),
      ]);
    });

/// Add / delete comments; both go through the outbox (offline-first, TC-13-03).
final commentActionsProvider = Provider<CommentActions>(CommentActions.new);

class CommentActions {
  CommentActions(this._ref);

  final Ref _ref;

  /// Saves [text] (trimmed) on the target; false when it is empty or too long.
  Future<bool> add(CommentTarget t, String text) async {
    final body = CommentRules.clean(text);
    if (body == null) return false;
    await _ref
        .read(commentsRepositoryProvider)
        .add(
          groupId: t.groupId,
          targetType: t.targetType,
          targetId: t.targetId,
          body: body,
          authorId: _ref.read(currentUserIdProvider),
        );
    return true;
  }

  /// Soft delete (author only; the server rejects anyone else with NOT_AUTHOR).
  Future<void> delete(LocalComment c) =>
      _ref.read(commentsRepositoryProvider).delete(c.id, c.groupId);
}
