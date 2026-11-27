import 'dart:async';
import 'dart:io';

import 'package:splitify/data/remote/groups_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The direct (friend) group of two accounts: its id and the friend's member id there.
typedef DirectGroup = ({String groupId, String friendMemberId});

/// Why a friend-code call did not work (D-034 B4).
enum FriendCodeFailureCode { offline, invalidCode, ownCode, rateLimited, unknown }

class FriendCodeFailure implements Exception {
  const FriendCodeFailure(this.code);

  final FriendCodeFailureCode code;

  static FriendCodeFailureCode fromServer(String? code) => switch (code) {
    'INVALID_CODE' => FriendCodeFailureCode.invalidCode,
    'OWN_CODE' => FriendCodeFailureCode.ownCode,
    'RATE_LIMITED' => FriendCodeFailureCode.rateLimited,
    _ => FriendCodeFailureCode.unknown,
  };

  @override
  String toString() => 'FriendCodeFailure(${code.name})';
}

/// `add_friend_by_code` answer: our direct group, the friend's account and member id there, their name, and
/// whether the group is new ([created]) or we were friends already.
typedef FriendByCode = ({
  String groupId,
  String friendUserId,
  String friendMemberId,
  String friendName,
  bool created,
});

/// Online-only friend RPCs: `find_or_create_direct_group` (0014; a linked friend's member row can only be made
/// by the server, S-120) and the personal friend code (0025: my code, a new code, add a friend by code).
/// Throws [GroupFailure] / [FriendCodeFailure] (`offline` without a network or server).
abstract class FriendsRemote {
  Future<DirectGroup> findOrCreateDirectGroup(String friendUserId);

  /// My code (made on first use), normalised `ABCDEFGH`.
  Future<String> myFriendCode();

  /// A new code; the old one stops working at once.
  Future<String> rotateFriendCode();

  Future<FriendByCode> addFriendByCode(String code);
}

/// No server configured (D-020 dummy builds, widget tests): fails like being offline.
class UnconfiguredFriendsRemote implements FriendsRemote {
  const UnconfiguredFriendsRemote();

  @override
  Future<DirectGroup> findOrCreateDirectGroup(String friendUserId) =>
      Future.error(const GroupFailure(GroupFailureCode.offline));

  @override
  Future<String> myFriendCode() =>
      Future.error(const FriendCodeFailure(FriendCodeFailureCode.offline));

  @override
  Future<String> rotateFriendCode() =>
      Future.error(const FriendCodeFailure(FriendCodeFailureCode.offline));

  @override
  Future<FriendByCode> addFriendByCode(String code) =>
      Future.error(const FriendCodeFailure(FriendCodeFailureCode.offline));
}

/// [FriendsRemote] over PostgREST RPCs.
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

  Future<Object?> _call(String name, [Map<String, Object?> params = const {}]) async {
    try {
      return await rpc(name, params);
    } on SocketException {
      throw const FriendCodeFailure(FriendCodeFailureCode.offline);
    } on TimeoutException {
      throw const FriendCodeFailure(FriendCodeFailureCode.offline);
    } on sb.PostgrestException catch (e) {
      throw FriendCodeFailure(FriendCodeFailure.fromServer(e.message));
    }
  }

  @override
  Future<String> myFriendCode() async => (await _call('my_friend_code'))! as String;

  @override
  Future<String> rotateFriendCode() async => (await _call('rotate_friend_code'))! as String;

  @override
  Future<FriendByCode> addFriendByCode(String code) async {
    final j = ((await _call('add_friend_by_code', {'code': code}))! as Map).cast<String, Object?>();
    final error = j['error'] as String?;
    if (error != null) throw FriendCodeFailure(FriendCodeFailure.fromServer(error));
    return (
      groupId: j['group_id']! as String,
      friendUserId: j['friend_user_id']! as String,
      friendMemberId: j['member_id']! as String,
      friendName: (j['friend_name'] as String?) ?? '',
      created: j['status'] == 'created',
    );
  }
}
