import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/data/repositories/friends_repository.dart';
import 'package:splitify/data/repositories/ledger_repository.dart';
import 'package:splitify/domain/rules/group_rules.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/friends/application/friend_identity.dart';
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

/// The people of a friend (`direct`) or several-friends (`adhoc`) group other than me, as friends, in the
/// group's member order (W2-X F11: the chips of "With you and"). Empty for other groups or while loading.
final groupFriendsProvider = Provider.autoDispose.family<List<Friend>, String>((ref, groupId) {
  final friends = ref.watch(friendsProvider).value ?? const <Friend>[];
  final out = <({int position, Friend friend})>[];
  for (final f in friends) {
    final link = f.links.where((l) => l.group.id == groupId).firstOrNull;
    if (link == null || !(link.isDirect || link.isAdhoc)) continue;
    final m = link.ledger.members.where((m) => m.id == link.friendMemberId).firstOrNull;
    if (m == null || m.status != 'active' || m.deletedAt != null) continue;
    out.add((position: m.position, friend: f));
  }
  out.sort((a, b) => a.position.compareTo(b.position));
  return [for (final e in out) e.friend];
});

/// The name of a new several-friends group: everyone in it, me first ("Mohit, Asha & Ben"), at most
/// [GroupRules.nameMax] characters ("Mohit, Asha & 4 more" when the names do not fit). The name is only seen in
/// notifications and the activity feed; the app shows the people.
String adhocGroupName(String myName, List<String> names, {required String Function(int n) more}) {
  final all = [if (myName.trim().isNotEmpty) myName.trim(), for (final n in names) n.trim()];
  String join(List<String> xs) =>
      xs.length == 1 ? xs.first : '${xs.sublist(0, xs.length - 1).join(', ')} & ${xs.last}';
  final full = join(all);
  if (full.runes.length <= GroupRules.nameMax) return full;
  for (var keep = all.length - 1; keep >= 1; keep--) {
    final short = '${all.take(keep).join(', ')} & ${more(all.length - keep)}';
    if (short.runes.length <= GroupRules.nameMax) return short;
  }
  return String.fromCharCodes(full.runes.take(GroupRules.nameMax));
}

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
    if (friendUser == null) {
      // Their own group (not a several-friends group they were picked into).
      final own = friend.links.where((l) => !l.isAdhoc).firstOrNull;
      if (own != null) return own.group.id;
      return _directFromAdhoc(friend);
    }
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

  /// A name-only person known only from a several-friends group: a direct group with them, made offline; their
  /// member id there is derived from the one they have, so they stay one friend (S-421).
  Future<String> _directFromAdhoc(Friend friend) async {
    final profile = _ref.read(profileProvider).value;
    final myName = (profile?.displayName ?? '').trim();
    final both = myName.isEmpty ? friend.name : '$myName & ${friend.name}';
    final groupId = newId();
    await _ref
        .read(groupActionsProvider)
        .create(
          id: groupId,
          name: GroupRules.name(both) == null ? both : friend.name,
          type: 'direct',
          currency: profile?.defaultCurrency ?? 'INR',
          ownerName: myName,
        );
    await _ref.read(membersRepositoryProvider).save(groupId, {
      'display_name': friend.name,
      'position': 1,
      'tint': friend.tint ?? 1,
    }, id: derivedMemberId(friend.originMemberId, groupId));
    return groupId;
  }

  /// Where "Record a loan" with [friend] goes (S-116 amendment): the same group as a new expense, with the
  /// friend's member id there already picked (null when the phone does not have it yet).
  Future<({String groupId, String? memberId})> loanTargetFor(Friend friend) async {
    final groupId = await expenseGroupFor(friend);
    final link = friend.links.where((l) => l.group.id == groupId).firstOrNull;
    if (link != null) return (groupId: groupId, memberId: link.friendMemberId);
    final friendUser = friend.userId;
    final memberId = friendUser == null
        ? null
        : await _ref.read(friendsRepositoryProvider).memberOf(groupId, friendUser);
    return (groupId: groupId, memberId: memberId);
  }

  /// Where a new expense with several people goes (W2-X F11, like Splitwise's "With you and" chips): one friend
  /// is [expenseGroupFor]; one new name is a new name-only friend; more people are a several-friends group,
  /// the existing one of exactly these people or a new hidden one made offline (rule 6). [newNames] are people
  /// typed or picked from contacts who are not friends yet (name-only members of the new group).
  Future<String> expenseGroupWith(
    List<Friend> friends, {
    List<String> newNames = const [],
    String Function(int n)? more,
  }) async {
    final names = [
      for (final n in newNames)
        if (n.trim().isNotEmpty) n.trim(),
    ];
    final unique = {for (final f in friends) f.key: f}.values.toList();
    if (unique.isEmpty && names.isEmpty) throw ArgumentError('nobody picked');
    if (unique.length + names.length == 1) {
      if (unique.isNotEmpty) return expenseGroupFor(unique.single);
      return (await addNameOnlyFriend(names.single)).groupId;
    }
    final uid = _ref.read(currentUserIdProvider);
    if (names.isEmpty) {
      final ledgers = await _ref.read(ledgerRepositoryProvider).loadAll();
      final found = existingAdhocGroup(ledgers, uid, {for (final f in unique) f.key});
      if (found != null) return found;
    }
    final profile = _ref.read(profileProvider).value;
    final myName = (profile?.displayName ?? '').trim();
    final groupId = newId();
    final people = [
      for (var i = 0; i < unique.length; i++)
        (
          id: derivedMemberId(unique[i].originMemberId, groupId),
          name: unique[i].name,
          tint: unique[i].tint ?? (i + 1) % 5,
          userId: unique[i].userId,
        ),
      for (var i = 0; i < names.length; i++)
        (id: newId(), name: names[i], tint: (unique.length + i + 1) % 5, userId: null),
    ];
    await _ref
        .read(groupsRepositoryProvider)
        .createAdhoc(
          id: groupId,
          name: adhocGroupName(myName, [
            for (final p in people) p.name,
          ], more: more ?? (n) => '$n more'),
          ownerName: myName.isEmpty ? 'Me' : myName,
          ownerUserId: uid,
          mainCurrency: profile?.defaultCurrency ?? 'INR',
          people: people,
        );
    return groupId;
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

/// The live several-friends group whose active people other than me ([uid]) are exactly the friends [keys]
/// (W2-X F11: the same people reuse one group, so their balances stay together); null when there is none.
String? existingAdhocGroup(List<GroupLedger> ledgers, String? uid, Set<String> keys) {
  if (uid == null) return null;
  final byId = membersById([for (final l in ledgers) l.members]);
  for (final l in ledgers) {
    final g = l.group;
    if (g.type != 'adhoc' || g.deletedAt != null || g.archivedAt != null) continue;
    final active = [
      for (final m in l.members)
        if (m.status == 'active' && m.deletedAt == null) m,
    ];
    if (!active.any((m) => m.userId == uid)) continue;
    final others = {
      for (final m in active)
        if (m.userId != uid) friendKeyIn(m, byId),
    };
    if (others.length == keys.length && others.containsAll(keys)) return g.id;
  }
  return null;
}
