// TC-2-03 (friend RPC): find_or_create_direct_group over a fake RPC.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  final calls = <(String, Map<String, Object?>)>[];
  Object? Function() answer = () => null;

  final remote = SupabaseFriendsRemote((name, params) async {
    calls.add((name, params));
    final a = answer();
    if (a is Exception) throw a;
    return a;
  });

  setUp(calls.clear);

  Matcher failure(GroupFailureCode code) =>
      throwsA(isA<GroupFailure>().having((f) => f.code, 'code', code));

  // TC-2-03
  test(
    'findOrCreateDirectGroup calls the RPC with the friend account and parses the answer',
    () async {
      answer = () => {'group_id': 'g-direct', 'member_id': 'm-friend'};
      final r = await remote.findOrCreateDirectGroup('u-asha');
      expect(calls.single.$1, 'find_or_create_direct_group');
      expect(calls.single.$2, {'friend_user_id': 'u-asha'});
      expect(r, (groupId: 'g-direct', friendMemberId: 'm-friend'));
    },
  );

  // TC-2-03
  test('a SocketException or a timeout means offline', () async {
    answer = () => const SocketException('no route');
    await expectLater(remote.findOrCreateDirectGroup('u'), failure(GroupFailureCode.offline));
    answer = () => TimeoutException('slow');
    await expectLater(remote.findOrCreateDirectGroup('u'), failure(GroupFailureCode.offline));
  });

  // TC-2-03
  test('NOT_FRIEND (not in a group together) is an unknown failure, not offline', () async {
    answer = () => const sb.PostgrestException(message: 'NOT_FRIEND');
    await expectLater(remote.findOrCreateDirectGroup('u'), failure(GroupFailureCode.unknown));
  });

  // TC-2-03
  test('a refusal the groups code knows keeps its code', () async {
    answer = () => const sb.PostgrestException(message: 'NOT_MEMBER');
    await expectLater(remote.findOrCreateDirectGroup('u'), failure(GroupFailureCode.notMember));
  });

  // TC-2-03
  test('the unconfigured remote fails like being offline', () async {
    await expectLater(
      const UnconfiguredFriendsRemote().findOrCreateDirectGroup('u'),
      failure(GroupFailureCode.offline),
    );
  });
}
