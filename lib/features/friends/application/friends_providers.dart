import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/friends_repository.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(appDatabaseProvider)),
);

/// Profiles on this phone by account id (self + co-members; names and UPI IDs).
final profilesProvider = StreamProvider.autoDispose<Map<String, LocalProfile>>(
  (ref) => ref.watch(friendsRepositoryProvider).watchProfiles(),
);

/// Friends tab (#2, #16): everyone I share a group with, with the total per currency. Local and instant;
/// the tab shows "not synced yet" while anything is pending (rule 3).
final friendsProvider = Provider.autoDispose<AsyncValue<List<Friend>>>((ref) {
  final ledgers = ref.watch(allLedgersProvider);
  if (ledgers.hasError && !ledgers.hasValue) {
    return AsyncError(ledgers.error!, ledgers.stackTrace ?? StackTrace.current);
  }
  if (!ledgers.hasValue) return const AsyncLoading();
  final profiles = ref.watch(profilesProvider).value ?? const {};
  return AsyncData(
    friendsOf(
      ledgers.requireValue,
      ref.watch(currentUserIdProvider),
      profileNames: {for (final p in profiles.values) p.id: p.displayName},
    ),
  );
});

/// One friend by key (`u:<user id>` / `m:<member id>`); data(null) when there is no such friend.
final friendProvider = Provider.autoDispose.family<AsyncValue<Friend?>, String>(
  (ref, key) =>
      ref.watch(friendsProvider).whenData((all) => all.where((f) => f.key == key).firstOrNull),
);

/// Friend actions: where a new expense with a friend goes, and new name-only friends (#2).
class FriendActions {
  FriendActions(this._ref);

  final Ref _ref;

  FriendsRemote get _remote => _ref.read(friendsRemoteProvider);

  /// The group a new expense with [friend] goes to: our direct group; for a linked friend without one it
  /// is made on the server first (online once, S-120) and pulled; a name-only friend from another group
  /// has only that group. Throws `GroupFailure` (offline) when the server is needed and unreachable.
  Future<String> expenseGroupFor(Friend friend) async {
    final direct = friend.directGroupId;
    if (direct != null) return direct;
    final friendUser = friend.userId;
    if (friendUser == null) return friend.links.first.group.id;
    final me = _ref.read(currentUserIdProvider);
    if (me != null) {
      final local = await _ref.read(friendsRepositoryProvider).findDirectGroup(me, friendUser);
      if (local != null) return local;
    }
    final made = await _remote.findOrCreateDirectGroup(friendUser);
    try {
      await _ref.read(syncNowProvider)();
    } on Exception {
      // The engine records its own failures; the group arrives with the next pull.
    }
    return made.groupId;
  }

  /// A new friend who has no account: a direct group with them as a name-only member, made offline
  /// (outbox, rule 6). Returns the group id and the friend's key.
  Future<({String groupId, String key})> addNameOnlyFriend(String name) async {
    final friendName = name.trim();
    final profile = _ref.read(profileProvider).value;
    final myName = (profile?.displayName ?? '').trim();
    final both = myName.isEmpty ? friendName : '$myName & $friendName';
    final groupId = await _ref
        .read(groupActionsProvider)
        .create(
          name: GroupRules.name(both) == null ? both : friendName,
          type: 'direct',
          currency: profile?.defaultCurrency ?? 'INR',
          ownerName: myName,
        );
    final memberId = await _ref.read(groupActionsProvider).addMember(groupId, friendName, tint: 1);
    return (groupId: groupId, key: 'm:$memberId');
  }
}

final friendActionsProvider = Provider<FriendActions>(FriendActions.new);
