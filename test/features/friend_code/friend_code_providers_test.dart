// D-034 B4: my friend code needs internet the first time, then shows offline from the cache (refreshed quietly
// when online); Reset stores the new code; adding by code syncs before the friend page opens; server answers map
// to friendly failures.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/friend_code/application/friend_code_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

import 'friend_code_fakes.dart';

void main() {
  late SharedPreferences prefs;
  late FakeFriendCodeRemote remote;
  late List<int> syncs;

  Future<ProviderContainer> make({Map<String, Object> cached = const {}}) async {
    SharedPreferences.setMockInitialValues(cached);
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        friendsRemoteProvider.overrideWithValue(remote),
        currentUserIdProvider.overrideWithValue('u1'),
        syncNowProvider.overrideWithValue(() async => syncs.add(1)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(myFriendCodeProvider, (_, _) {});
    return c;
  }

  setUp(() {
    remote = FakeFriendCodeRemote();
    syncs = [];
  });

  group('my code', () {
    test('the first time it comes from the server and is cached', () async {
      final c = await make();
      expect(await c.read(myFriendCodeProvider.future), 'ABCD2345');
      expect(prefs.getString(friendCodeCacheKey('u1')), 'ABCD2345');
    });

    test('offline the first time: "needs internet"', () async {
      remote.offline = true;
      final c = await make();
      await expectLater(
        c.read(myFriendCodeProvider.future),
        throwsA(
          isA<FriendCodeFailure>().having((e) => e.code, 'code', FriendCodeFailureCode.offline),
        ),
      );
    });

    test('offline later: the cached code shows', () async {
      remote.offline = true;
      final c = await make(cached: {friendCodeCacheKey('u1'): 'WXYZ6789'});
      expect(await c.read(myFriendCodeProvider.future), 'WXYZ6789');
    });

    test('online with a cache: shown at once, then refreshed when it changed elsewhere', () async {
      final c = await make(cached: {friendCodeCacheKey('u1'): 'OLDC0DE1'});
      expect(await c.read(myFriendCodeProvider.future), 'OLDC0DE1');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(myFriendCodeProvider).value, 'ABCD2345');
      expect(prefs.getString(friendCodeCacheKey('u1')), 'ABCD2345');
    });

    test('Reset stores and shows the new code', () async {
      final c = await make();
      await c.read(myFriendCodeProvider.future);
      expect(await c.read(myFriendCodeProvider.notifier).rotate(), 'WXYZ6789');
      expect(c.read(myFriendCodeProvider).value, 'WXYZ6789');
      expect(prefs.getString(friendCodeCacheKey('u1')), 'WXYZ6789');
    });

    test('Reset offline fails and keeps the code', () async {
      final c = await make();
      await c.read(myFriendCodeProvider.future);
      remote.offline = true;
      await expectLater(
        c.read(myFriendCodeProvider.notifier).rotate(),
        throwsA(isA<FriendCodeFailure>()),
      );
      expect(c.read(myFriendCodeProvider).value, 'ABCD2345');
    });
  });

  group('add by code', () {
    test('adds, then syncs so our friend group is on the phone', () async {
      final c = await make();
      final added = await c.read(friendCodeActionsProvider).add('ABCD2345');
      expect((added.friendUserId, added.created), ('u2', true));
      expect(remote.added, ['ABCD2345']);
      expect(syncs, [1]);
    });

    test('failures pass through without a sync', () async {
      remote.addFailure = FriendCodeFailureCode.invalidCode;
      final c = await make();
      await expectLater(
        c.read(friendCodeActionsProvider).add('ZZZZZZZZ'),
        throwsA(
          isA<FriendCodeFailure>().having((e) => e.code, 'code', FriendCodeFailureCode.invalidCode),
        ),
      );
      expect(syncs, isEmpty);
    });
  });

  group('server answers', () {
    test('error codes map to friendly failures', () {
      expect(FriendCodeFailure.fromServer('INVALID_CODE'), FriendCodeFailureCode.invalidCode);
      expect(FriendCodeFailure.fromServer('OWN_CODE'), FriendCodeFailureCode.ownCode);
      expect(FriendCodeFailure.fromServer('RATE_LIMITED'), FriendCodeFailureCode.rateLimited);
      expect(FriendCodeFailure.fromServer('SOMETHING'), FriendCodeFailureCode.unknown);
    });

    test('the RPC glue reads the answer and the error object', () async {
      final calls = <String>[];
      Object? answer;
      final glue = SupabaseFriendsRemote((name, params) async {
        calls.add('$name $params');
        return answer;
      });
      answer = 'ABCD2345';
      expect(await glue.myFriendCode(), 'ABCD2345');
      expect(await glue.rotateFriendCode(), 'ABCD2345');
      answer = {
        'group_id': 'g',
        'member_id': 'm2',
        'my_member_id': 'm1',
        'friend_user_id': 'u2',
        'friend_name': 'Asha',
        'status': 'found',
      };
      final r = await glue.addFriendByCode('ABCD2345');
      expect(
        (r.groupId, r.friendMemberId, r.friendUserId, r.friendName, r.created),
        ('g', 'm2', 'u2', 'Asha', false),
      );
      answer = {'error': 'OWN_CODE'};
      await expectLater(
        glue.addFriendByCode('ABCD2345'),
        throwsA(
          isA<FriendCodeFailure>().having((e) => e.code, 'code', FriendCodeFailureCode.ownCode),
        ),
      );
      expect(calls, [
        'my_friend_code {}',
        'rotate_friend_code {}',
        'add_friend_by_code {code: ABCD2345}',
        'add_friend_by_code {code: ABCD2345}',
      ]);
      await expectLater(
        const UnconfiguredFriendsRemote().myFriendCode(),
        throwsA(isA<FriendCodeFailure>()),
      );
    });
  });
}
