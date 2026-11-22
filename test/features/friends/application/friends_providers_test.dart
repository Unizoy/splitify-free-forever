// TC-2-03 (where a friend expense goes, new name-only friends): FriendActions on a memory Drift database
// with fake remote and sync.
import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/ledger_repository.dart' show GroupLedger;
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/auth/application/auth_providers.dart'
    show ProfileController, profileProvider;
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/expenses/application/expense_editor_controller.dart' as editor;
import 'package:splitify/features/groups/application/groups_providers.dart' as groups;

import '../../../data/sync/sync_fakes.dart';
import '../../../support/ledger_seed.dart';
import '../friend_fixtures.dart';

class _FixedProfile extends ProfileController {
  _FixedProfile(this.name);

  final String name;

  @override
  Future<Profile?> build() async => Profile(id: 'u1', displayName: name);
}

class _FakeFriendsRemote implements FriendsRemote {
  _FakeFriendsRemote({this.fail});

  final GroupFailure? fail;
  final calls = <String>[];

  @override
  Future<DirectGroup> findOrCreateDirectGroup(String friendUserId) async {
    calls.add(friendUserId);
    if (fail != null) throw fail!;
    return (groupId: 'g-made', friendMemberId: 'm-made');
  }
}

void main() {
  late AppDatabase db;
  late _FakeFriendsRemote remote;
  late List<int> syncs;
  late ProviderContainer container;

  Object? syncError;

  ProviderContainer make({FriendsRemote? friendsRemote, String myName = 'Me'}) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        remoteApiProvider.overrideWithValue(FakeRemoteApi()),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 11, 22, 10))),
        editor.currentUserIdProvider.overrideWithValue('u1'),
        groups.currentUserIdProvider.overrideWithValue('u1'),
        friendsRemoteProvider.overrideWithValue(friendsRemote ?? remote),
        groups.syncNowProvider.overrideWithValue(() async {
          syncs.add(syncs.length);
          final e = syncError;
          if (e is Exception) throw e;
        }),
        profileProvider.overrideWith(() => _FixedProfile(myName)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Friend asha(List<GroupLedger> ledgers) =>
      friendsOf(ledgers, 'u1').firstWhere((f) => f.key == 'u:u2');

  /// The profile loads on first use (as when the app is open); the action reads its value.
  Future<void> profileLoaded(ProviderContainer c) async {
    c.listen(profileProvider, (_, _) {});
    await c.read(profileProvider.future);
  }

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = memoryDb();
    remote = _FakeFriendsRemote();
    syncs = [];
    syncError = null;
    container = make();
  });
  tearDown(() => db.close());

  group('expenseGroupFor', () {
    // TC-2-03
    test('returns our direct group when there is one, without asking the server', () async {
      final friend = asha([goaLedger(), directLedger()]);
      expect(await container.read(friendActionsProvider).expenseGroupFor(friend), 'g3');
      expect(remote.calls, isEmpty);
      expect(syncs, isEmpty);
    });

    // TC-2-03
    test('a name-only friend goes to the group they are in', () async {
      final friend = friendsOf([goaLedger()], 'u1').firstWhere((f) => f.key == 'm:a3');
      expect(await container.read(friendActionsProvider).expenseGroupFor(friend), 'g1');
      expect(remote.calls, isEmpty);
    });

    // TC-2-03
    test('a linked friend without a direct group is made on the server, then synced', () async {
      final friend = asha([goaLedger()]);
      final id = await container.read(friendActionsProvider).expenseGroupFor(friend);
      expect(id, 'g-made');
      expect(remote.calls, ['u2']);
      expect(syncs, hasLength(1));
    });

    // TC-2-03
    test('a failing sync after the RPC does not lose the new group id', () async {
      syncError = Exception('offline');
      final id = await container.read(friendActionsProvider).expenseGroupFor(asha([goaLedger()]));
      expect(id, 'g-made');
      expect(syncs, hasLength(1));
    });

    // TC-2-03
    test('a direct group already on this phone skips the server call', () async {
      final direct = directLedger(id: 'g-local');
      await db.seed(groups: [direct.group], members: direct.members);
      final id = await container.read(friendActionsProvider).expenseGroupFor(asha([goaLedger()]));
      expect(id, 'g-local');
      expect(remote.calls, isEmpty);
      expect(syncs, isEmpty);
    });

    // TC-2-03
    test('offline: the GroupFailure reaches the caller and nothing is synced', () async {
      final c = make(friendsRemote: const UnconfiguredFriendsRemote());
      await expectLater(
        c.read(friendActionsProvider).expenseGroupFor(asha([goaLedger()])),
        throwsA(isA<GroupFailure>().having((f) => f.code, 'code', GroupFailureCode.offline)),
      );
      expect(syncs, isEmpty);
    });

    // TC-2-03
    test('a server refusal (not friends) also propagates', () async {
      final c = make(
        friendsRemote: _FakeFriendsRemote(fail: const GroupFailure(GroupFailureCode.unknown)),
      );
      await expectLater(
        c.read(friendActionsProvider).expenseGroupFor(asha([goaLedger()])),
        throwsA(isA<GroupFailure>().having((f) => f.code, 'code', GroupFailureCode.unknown)),
      );
    });
  });

  group('addNameOnlyFriend', () {
    Future<List<OutboxItem>> outbox() => db.select(db.outbox).get();

    // TC-2-03
    test(
      'makes a direct group with the friend as a name-only member, offline through the outbox',
      () async {
        await profileLoaded(container);
        final made = await container.read(friendActionsProvider).addNameOnlyFriend('  Rahul ');
        final group = await (db.select(
          db.groups,
        )..where((g) => g.id.equals(made.groupId))).getSingle();
        expect(group.type, 'direct');
        expect(group.name, 'Me & Rahul');
        expect(group.syncState, SyncState.pending);
        final members = await (db.select(
          db.groupMembers,
        )..where((m) => m.groupId.equals(made.groupId))).get();
        final friend = members.singleWhere((m) => m.userId == null);
        expect(friend.displayName, 'Rahul');
        expect(friend.syncState, SyncState.pending);
        expect(made.key, 'm:${friend.id}');
        // Me: the owner member.
        expect(members.singleWhere((m) => m.userId == 'u1').displayName, 'Me');
        // Two mutations queued, in order: the group (with its owner), then the member.
        final queued = await outbox();
        expect([for (final o in queued) o.entity], ['group', 'member']);
        expect(queued.every((o) => o.status == OutboxStatus.queued), isTrue);
        final groupPayload = jsonDecode(queued.first.payload) as Map<String, Object?>;
        expect(groupPayload['type'], 'direct');
        expect(groupPayload['name'], 'Me & Rahul');
        expect((jsonDecode(queued.last.payload) as Map<String, Object?>)['display_name'], 'Rahul');
      },
    );

    // TC-2-03
    test(
      'names the group after the friend alone when "me & friend" is over 60 characters',
      () async {
        final c = make(myName: 'M' * 20);
        await profileLoaded(c);
        final friendName = 'F' * 50;
        final made = await c.read(friendActionsProvider).addNameOnlyFriend(friendName);
        final group = await (db.select(
          db.groups,
        )..where((g) => g.id.equals(made.groupId))).getSingle();
        expect(group.name, friendName);
      },
    );

    // TC-2-03
    test('the new friend shows up in the friends list once the rows are local', () async {
      await profileLoaded(container);
      final made = await container.read(friendActionsProvider).addNameOnlyFriend('Rahul');
      container.listen(friendsProvider, (_, _) {});
      for (var i = 0; i < 50 && container.read(friendsProvider).value == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final all = container.read(friendsProvider).requireValue;
      expect(all.single.key, made.key);
      expect(all.single.name, 'Rahul');
      expect(all.single.directGroupId, made.groupId);
      expect(all.single.sharedGroups, isEmpty);
    });
  });
}
