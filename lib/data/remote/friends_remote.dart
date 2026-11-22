import 'dart:async';
import 'dart:io';

import 'package:splitify/data/remote/groups_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The direct (friend) group of two accounts: its id and the friend's member id there.
typedef DirectGroup = ({String groupId, String friendMemberId});

/// Online-only friend RPC (`find_or_create_direct_group`, 0014): a linked friend's member row can only be
/// made by the server (S-120). Throws [GroupFailure] (`offline` without a network or server).
abstract class FriendsRemote {
  Future<DirectGroup> findOrCreateDirectGroup(String friendUserId);
}

/// No server configured (D-020 dummy builds, widget tests): fails like being offline.
class UnconfiguredFriendsRemote implements FriendsRemote {
  const UnconfiguredFriendsRemote();

  @override
  Future<DirectGroup> findOrCreateDirectGroup(String friendUserId) =>
      Future.error(const GroupFailure(GroupFailureCode.offline));
}

/// [FriendsRemote] over a PostgREST RPC.
class SupabaseFriendsRemote implements FriendsRemote {
  SupabaseFriendsRemote(this.rpc);

  /// Wires the real client (thin glue, exercised on the device).
  factory SupabaseFriendsRemote.fromClient(sb.SupabaseClient c) =>
      SupabaseFriendsRemote((name, params) => c.rpc<Object?>(name, params: params));

  final GroupsRpc rpc;

  @override
  Future<DirectGroup> findOrCreateDirectGroup(String friendUserId) async {
    try {
      final r = await rpc('find_or_create_direct_group', {'friend_user_id': friendUserId});
      final j = (r! as Map).cast<String, Object?>();
      return (groupId: j['group_id']! as String, friendMemberId: j['member_id']! as String);
    } on SocketException {
      throw const GroupFailure(GroupFailureCode.offline);
    } on TimeoutException {
      throw const GroupFailure(GroupFailureCode.offline);
    } on sb.PostgrestException catch (e) {
      throw GroupFailure(GroupFailure.fromServer(e.message));
    }
  }
}
