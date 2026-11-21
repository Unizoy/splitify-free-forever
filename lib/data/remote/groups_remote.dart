import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Why an online-only group action failed (08 #3 #4; codes from `0010_groups_members.sql`).
enum GroupFailureCode {
  offline,
  invalidCode,
  rateLimited,
  alreadyClaimed,
  memberNotFound,
  nonzeroBalance,
  notMember,
  notClaimed,
  groupFull,
  claimRequired,
  unknown,
}

class GroupFailure implements Exception {
  const GroupFailure(this.code);
  final GroupFailureCode code;

  static GroupFailureCode fromServer(String? code) => switch (code) {
    'INVALID_CODE' => GroupFailureCode.invalidCode,
    'RATE_LIMITED' => GroupFailureCode.rateLimited,
    'ALREADY_CLAIMED' => GroupFailureCode.alreadyClaimed,
    'MEMBER_NOT_FOUND' => GroupFailureCode.memberNotFound,
    'NONZERO_BALANCE' => GroupFailureCode.nonzeroBalance,
    'NOT_MEMBER' => GroupFailureCode.notMember,
    'NOT_CLAIMED' => GroupFailureCode.notClaimed,
    'GROUP_FULL' => GroupFailureCode.groupFull,
    'CLAIM_REQUIRED' => GroupFailureCode.claimRequired,
    _ => GroupFailureCode.unknown,
  };

  @override
  String toString() => 'GroupFailure(${code.name})';
}

/// One unclaimed name-only spot shown on the claim step.
typedef UnclaimedMember = ({String id, String name, int? tint});

/// `preview_join` answer.
class JoinPreview {
  const JoinPreview({
    required this.groupId,
    required this.name,
    required this.type,
    required this.memberCount,
    required this.archived,
    required this.alreadyMember,
    required this.unclaimed,
  });

  factory JoinPreview.fromJson(Map<String, Object?> j) {
    final g = (j['group']! as Map).cast<String, Object?>();
    return JoinPreview(
      groupId: g['id']! as String,
      name: g['name']! as String,
      type: (g['type'] as String?) ?? 'other',
      memberCount: (g['member_count'] as int?) ?? 0,
      archived: (g['archived'] as bool?) ?? false,
      alreadyMember: (j['already_member'] as bool?) ?? false,
      unclaimed: [
        for (final m in (j['unclaimed'] as List?) ?? const [])
          (
            id: (m as Map)['id']! as String,
            name: m['display_name']! as String,
            tint: m['tint'] as int?,
          ),
      ],
    );
  }

  final String groupId;
  final String name;
  final String type;
  final int memberCount;
  final bool archived;
  final bool alreadyMember;
  final List<UnclaimedMember> unclaimed;
}

/// Online-only group RPCs (offline-sync rule 2 exceptions: they need the server's checks). Throws
/// [GroupFailure].
abstract class GroupsRemote {
  Future<JoinPreview> preview(String code);

  /// Joins (or claims [claimMemberId]); returns the group id.
  Future<String> join(String code, {String? claimMemberId});

  /// New invite code for the group.
  Future<String> rotateCode(String groupId);
  Future<void> leave(String groupId);
  Future<void> removeMember(String groupId, String memberId);
  Future<void> unlinkMember(String groupId, String memberId);
}

typedef GroupsRpc = Future<Object?> Function(String name, Map<String, Object?> params);

/// [GroupsRemote] over PostgREST RPCs.
class SupabaseGroupsRemote implements GroupsRemote {
  SupabaseGroupsRemote(this.rpc);

  /// Wires the real client (thin glue, exercised on the device).
  factory SupabaseGroupsRemote.fromClient(sb.SupabaseClient c) =>
      SupabaseGroupsRemote((name, params) => c.rpc<Object?>(name, params: params));

  final GroupsRpc rpc;

  @override
  Future<JoinPreview> preview(String code) => _guard(() async {
    final j = _map(await rpc('preview_join', {'code': code}));
    return JoinPreview.fromJson(j);
  });

  @override
  Future<String> join(String code, {String? claimMemberId}) => _guard(() async {
    final j = _map(await rpc('join_group', {'code': code, 'claim_member_id': claimMemberId}));
    return j['group_id']! as String;
  });

  @override
  Future<String> rotateCode(String groupId) =>
      _guard(() async => (await rpc('rotate_invite_code', {'group_id': groupId}))! as String);

  @override
  Future<void> leave(String groupId) => _guard(() => rpc('leave_group', {'group_id': groupId}));

  @override
  Future<void> removeMember(String groupId, String memberId) =>
      _guard(() => rpc('remove_member', {'group_id': groupId, 'member_id': memberId}));

  @override
  Future<void> unlinkMember(String groupId, String memberId) =>
      _guard(() => rpc('unlink_member', {'group_id': groupId, 'member_id': memberId}));

  /// Wrong codes come back as `{error: INVALID_CODE}` (so the server can count the try).
  static Map<String, Object?> _map(Object? r) {
    final j = (r! as Map).cast<String, Object?>();
    final error = j['error'] as String?;
    if (error != null) throw GroupFailure(GroupFailure.fromServer(error));
    return j;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SocketException {
      throw const GroupFailure(GroupFailureCode.offline);
    } on TimeoutException {
      throw const GroupFailure(GroupFailureCode.offline);
    } on sb.PostgrestException catch (e) {
      throw GroupFailure(GroupFailure.fromServer(e.message));
    }
  }
}
