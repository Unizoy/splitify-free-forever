import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/groups_remote.dart';

/// Scripted [GroupsRemote]: queue answers (a value, or a [GroupFailure] to throw) per call; every call is
/// recorded in [calls] as `name:arg:arg`. With an empty queue the last default applies.
class FakeGroupsRemote implements GroupsRemote {
  /// Answers for `preview`: [JoinPreview] or [GroupFailure]. The last one repeats.
  final previews = <Object>[];

  /// Answers for `join`: group id [String] or [GroupFailure]. Defaults to [joinedGroupId].
  final joins = <Object>[];

  /// Answers for `rotateCode`: [String] or [GroupFailure].
  final rotations = <Object>[];

  /// Failure thrown by `leave` / `removeMember` / `unlinkMember` (cleared after use).
  GroupFailure? actionFailure;

  String joinedGroupId = 'g-joined';
  final calls = <String>[];

  T _next<T>(List<Object> queue, T fallback) {
    if (queue.isEmpty) return fallback;
    final r = queue.removeAt(0);
    if (r is GroupFailure) throw r;
    return r as T;
  }

  void _maybeFail() {
    final f = actionFailure;
    if (f != null) {
      actionFailure = null;
      throw f;
    }
  }

  @override
  Future<JoinPreview> preview(String code) async {
    calls.add('preview:$code');
    if (previews.isEmpty) throw StateError('no preview scripted');
    final r = previews.length == 1 ? previews.first : previews.removeAt(0);
    if (r is GroupFailure) throw r;
    return r as JoinPreview;
  }

  @override
  Future<String> join(String code, {String? claimMemberId}) async {
    calls.add('join:$code:${claimMemberId ?? '-'}');
    return _next<String>(joins, joinedGroupId);
  }

  @override
  Future<String> rotateCode(String groupId) async {
    calls.add('rotate:$groupId');
    return _next<String>(rotations, 'ZZZZYYYY');
  }

  @override
  Future<void> leave(String groupId) async {
    calls.add('leave:$groupId');
    _maybeFail();
  }

  @override
  Future<void> removeMember(String groupId, String memberId) async {
    calls.add('remove:$groupId:$memberId');
    _maybeFail();
  }

  @override
  Future<void> unlinkMember(String groupId, String memberId) async {
    calls.add('unlink:$groupId:$memberId');
    _maybeFail();
  }
}

/// A preview with sensible defaults.
JoinPreview samplePreview({
  String groupId = 'g-goa',
  String name = 'Goa trip',
  String type = 'trip',
  int memberCount = 3,
  bool archived = false,
  bool alreadyMember = false,
  List<UnclaimedMember> unclaimed = const [],
}) => JoinPreview(
  groupId: groupId,
  name: name,
  type: type,
  memberCount: memberCount,
  archived: archived,
  alreadyMember: alreadyMember,
  unclaimed: unclaimed,
);

/// A group row for goldens and provider overrides.
LocalGroup sampleGroup({
  String id = 'g-goa',
  String name = 'Goa trip',
  String type = 'trip',
  String? inviteCode = 'ABCDEFGH',
  String? archivedAt,
  String? deletedAt,
  String? createdBy = 'u1',
  String createdAt = '2026-11-20T10:00:00Z',
  String syncState = 'synced',
}) => LocalGroup(
  id: id,
  name: name,
  type: type,
  mainCurrency: 'INR',
  coverKind: 'generated',
  simplifyDebts: false,
  inviteCode: inviteCode,
  archivedAt: archivedAt,
  createdAt: createdAt,
  createdBy: createdBy,
  deletedAt: deletedAt,
  deletedBy: deletedAt == null ? null : createdBy,
  seq: 1,
  syncState: syncState,
);

/// A member row for goldens and provider overrides.
LocalMember sampleMember({
  required String id,
  String groupId = 'g-goa',
  String? userId,
  String name = 'Member',
  int position = 0,
  String role = 'member',
  String? claimedAt,
  int? tint,
  String syncState = 'synced',
}) => LocalMember(
  id: id,
  groupId: groupId,
  userId: userId,
  displayName: name,
  position: position,
  role: role,
  status: 'active',
  claimedAt: claimedAt,
  tint: tint,
  seq: 1,
  syncState: syncState,
);
