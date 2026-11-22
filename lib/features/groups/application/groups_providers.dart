import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/repositories.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' hide clockProvider;

/// The signed-in user's id, or null.
final currentUserIdProvider = Provider<String?>(
  (ref) =>
      ref.watch(authUserProvider).value?.id ?? ref.watch(authRepositoryProvider).currentUser?.id,
);

/// Groups tab: live groups (active and archived), newest first.
final groupsListProvider = StreamProvider<List<LocalGroup>>(
  (ref) => ref.watch(groupsRepositoryProvider).watchAll(),
);

final StreamProviderFamily<LocalGroup?, String> groupProvider =
    StreamProvider.family<LocalGroup?, String>(
      (ref, id) => ref.watch(groupsRepositoryProvider).watchOne(id),
    );

/// Active members in position order.
final StreamProviderFamily<List<LocalMember>, String> groupMembersProvider =
    StreamProvider.family<List<LocalMember>, String>(
      (ref, id) => ref.watch(membersRepositoryProvider).watchForGroup(id),
    );

/// Groups this user deleted (Account → Deleted groups).
final deletedGroupsProvider = StreamProvider<List<LocalGroup>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(groupsRepositoryProvider).watchDeletedBy(uid);
});

/// Runs one push + pull now (never throws): when the Groups tab opens and after online-only group actions.
/// The app-wide triggers (connectivity, resume, realtime) belong to phase 06 (S-046). Tests override it.
final syncNowProvider = Provider<Future<void> Function()>(
  (ref) => ref.watch(syncRepositoryProvider).syncNow,
);

/// True while the last sync failed for lack of network (offline note on the Groups tab).
final syncOfflineProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(syncRepositoryProvider)
      .watchStatus()
      .map((s) => s.phase == SyncPhase.offline)
      .distinct(),
);

/// Whole days left to restore a group deleted at [deletedAt] (30-day window, TC-1-07); -1 = too late.
int restoreDaysLeft(String deletedAt, DateTime now) {
  final left = DateTime.parse(deletedAt)
      .toUtc()
      .add(const Duration(days: 30))
      .difference(now.toUtc());
  return left.isNegative ? -1 : left.inDays;
}

/// Group writes (offline, through the outbox) and the online-only member actions (RPC, then a sync so the
/// phone sees the server's answer).
class GroupActions {
  GroupActions(this._ref);

  final Ref _ref;

  GroupsRepository get _groups => _ref.read(groupsRepositoryProvider);
  MembersRepository get _members => _ref.read(membersRepositoryProvider);
  GroupsRemote get _remote => _ref.read(groupsRemoteProvider);
  Clock get clock => _ref.read(clockProvider);

  Future<void> _syncSoon() async {
    try {
      await _ref.read(syncNowProvider)();
    } on Exception {
      // The engine records its own failures and retries; the action itself already succeeded.
    }
  }

  /// New group; the creator becomes the owner member (offline-first).
  Future<String> create({
    required String name,
    required String type,
    required String currency,
    required String ownerName,
    String? id,
  }) => _groups.create(
    id: id,
    name: name.trim(),
    type: type,
    mainCurrency: currency,
    ownerName: ownerName,
    ownerUserId: _ref.read(currentUserIdProvider),
  );

  Future<void> update(
    String id, {
    required String name,
    required String type,
    required String currency,
  }) => _groups.update(id, {'name': name.trim(), 'type': type, 'main_currency': currency});

  /// Photo cover (S-073): saved offline, uploaded by the queue once the group is on the server.
  Future<void> setCoverPhoto(String id, PreparedImage image, {String? oldPath}) async {
    final media = _ref.read(mediaRepositoryProvider);
    if (oldPath != null) await media.discardPending(MediaBuckets.groupCovers, oldPath);
    await media.saveGroupCover(id, image);
  }

  /// Back to the generated cover; a photo that never went up is forgotten.
  Future<void> useGeneratedCover(String id, {String? oldPath}) async {
    if (oldPath != null) {
      await _ref.read(mediaRepositoryProvider).discardPending(MediaBuckets.groupCovers, oldPath);
    }
    await _groups.update(id, {'cover_kind': 'generated', 'cover_path': null});
  }

  Future<void> setArchived(String id, {required bool archived}) =>
      _groups.setArchived(id, archived: archived);

  /// Creator only (the server checks too); restorable for 30 days.
  Future<void> delete(String id) => _groups.delete(id, id);

  Future<void> restore(String id) => _groups.restore(id, id);

  Future<String> addMember(String groupId, String name, {int? tint}) =>
      _members.addNameOnly(groupId, name.trim(), tint: tint);

  Future<void> renameMember(String groupId, String memberId, String name) =>
      _members.rename(groupId, memberId, name.trim());

  Future<JoinPreview> preview(String code) => _remote.preview(code);

  /// Joins (or claims a name-only spot) and pulls the group onto this phone; returns its id.
  Future<String> join(String code, {String? claimMemberId}) async {
    final id = await _remote.join(code, claimMemberId: claimMemberId);
    await _syncSoon();
    return id;
  }

  Future<String> rotateCode(String groupId) async {
    final code = await _remote.rotateCode(groupId);
    unawaited(_syncSoon());
    return code;
  }

  Future<void> leave(String groupId) async {
    await _remote.leave(groupId);
    unawaited(_syncSoon());
  }

  Future<void> removeMember(String groupId, String memberId) async {
    await _remote.removeMember(groupId, memberId);
    unawaited(_syncSoon());
  }

  Future<void> unlinkMember(String groupId, String memberId) async {
    await _remote.unlinkMember(groupId, memberId);
    unawaited(_syncSoon());
  }
}

final groupActionsProvider = Provider<GroupActions>(GroupActions.new);
