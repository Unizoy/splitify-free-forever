import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/remote_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider, syncNowProvider;

/// Where my friend code is kept on this phone (preferences are wiped on sign-out, `LocalWipe`).
String friendCodeCacheKey(String userId) => 'friend_code_$userId';

Duration? _noRetry(int retryCount, Object error) => null;

/// My personal friend code (D-034 B4). The server makes it the first time (online once); after that it is
/// cached and shows offline, refreshed quietly whenever the server can be reached. Errors are
/// [FriendCodeFailure]s (`offline` when there is no cached code and no network).
final myFriendCodeProvider = AsyncNotifierProvider.autoDispose<MyFriendCode, String>(
  MyFriendCode.new,
  retry: _noRetry,
);

class MyFriendCode extends AsyncNotifier<String> {
  FriendsRemote get _remote => ref.read(friendsRemoteProvider);

  @override
  Future<String> build() async {
    final uid = ref.watch(currentUserIdProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final cached = uid == null ? null : prefs.getString(friendCodeCacheKey(uid));
    if (cached != null) {
      unawaited(_refresh(uid!, cached));
      return cached;
    }
    final code = await _remote.myFriendCode();
    if (uid != null) await prefs.setString(friendCodeCacheKey(uid), code);
    return code;
  }

  Future<void> _refresh(String uid, String cached) async {
    try {
      final fresh = await _remote.myFriendCode();
      if (!ref.mounted || fresh == cached) return;
      await ref.read(sharedPreferencesProvider).setString(friendCodeCacheKey(uid), fresh);
      state = AsyncData(fresh);
    } on FriendCodeFailure {
      // Offline: the cached code stays (it is still valid unless it was reset on another phone).
    }
  }

  /// A new code (online only; throws [FriendCodeFailure]); the old code, QR and link stop working.
  Future<String> rotate() async {
    final code = await _remote.rotateFriendCode();
    final uid = ref.read(currentUserIdProvider);
    if (uid != null) {
      await ref.read(sharedPreferencesProvider).setString(friendCodeCacheKey(uid), code);
    }
    if (ref.mounted) state = AsyncData(code);
    return code;
  }
}

/// Adds the owner of a friend code as my friend (online only), then syncs so our direct group and their
/// profile reach this phone before the friend page opens.
class FriendCodeActions {
  FriendCodeActions(this._ref);

  final Ref _ref;

  Future<FriendByCode> add(String code) async {
    final added = await _ref.read(friendsRemoteProvider).addFriendByCode(code);
    try {
      await _ref.read(syncNowProvider)().timeout(const Duration(seconds: 15));
    } on Exception {
      // The sync engine records its own failures; the group arrives with the next pull.
    }
    return added;
  }
}

final friendCodeActionsProvider = Provider<FriendCodeActions>(FriendCodeActions.new);
