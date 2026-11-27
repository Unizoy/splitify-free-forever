// Shared harness for the friends widget tests and goldens: fixed friends (no database), a fake
// FriendActions and a router with stub routes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/auth/application/auth_providers.dart'
    show ProfileController, profileProvider;
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/friends/application/friends_view.dart';

import '../../../support/notification_fakes.dart';
import '../../expenses/presentation/presentation_harness.dart';

class FixedProfile extends ProfileController {
  FixedProfile([this.profile = const Profile(id: 'u1', displayName: 'Mohit Bindal')]);

  final Profile? profile;

  @override
  Future<Profile?> build() async => profile;
}

/// FriendActions that only records the calls.
class FakeFriendActions extends FriendActions {
  FakeFriendActions(super.ref, {this.groupFor = 'g-friend', this.failure});

  final String groupFor;
  final GroupFailure? failure;
  final asked = <String>[];
  final added = <String>[];

  @override
  Future<String> expenseGroupFor(Friend friend) async {
    asked.add(friend.key);
    if (failure != null) throw failure!;
    return groupFor;
  }

  @override
  Future<({String groupId, String? memberId})> loanTargetFor(Friend friend) async {
    asked.add('loan ${friend.key}');
    if (failure != null) throw failure!;
    return (groupId: groupFor, memberId: 'c2');
  }

  @override
  Future<({String groupId, String key})> addNameOnlyFriend(String name) async {
    added.add(name);
    return (groupId: 'g-new', key: 'm:new');
  }
}

/// Overrides shared by the friends screens.
List<Override> friendOverrides(
  AsyncValue<List<Friend>> friends, {
  bool unsynced = false,
  FakeFriendActions Function(Ref ref)? actions,
  Profile? profile = const Profile(id: 'u1', displayName: 'Mohit Bindal'),
}) => [
  friendsProvider.overrideWithValue(friends),
  anyUnsyncedProvider.overrideWith((ref) => Stream.value(unsynced)),
  profileProvider.overrideWith(() => FixedProfile(profile)),
  if (actions != null) friendActionsProvider.overrideWith(actions),
  // Remind on "By group" rows (phase 13) without a database.
  ...quietNotificationOverrides(),
];

/// Pumps [home] at `/` with stub routes for everything the friends screens push; returns the router.
Future<GoRouter> pumpFriends(
  WidgetTester t,
  Widget home, {
  required List<Override> overrides,
  double scale = 1,
  String initial = '/',
}) async {
  usePhone(t);
  if (scale != 1) {
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await t.pumpWidget(const SizedBox());
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      stubRoute('/friends/code'),
      stubRoute('/friends/:key'),
      stubRoute('/settle/all'),
      stubRoute('/expense/new'),
      stubRoute('/loan/new'),
      stubRoute('/expense/:id'),
      stubRoute('/payment/:id'),
      stubRoute('/settle'),
      stubRoute('/groups/:id'),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(routerApp(router, overrides: overrides));
  await settle(t);
  return router;
}

/// Every Text under [key].
List<String> textsIn(WidgetTester t, Key key) => [
  for (final w in t.widgetList<Text>(
    find.descendant(of: find.byKey(key), matching: find.byType(Text)),
  ))
    ?w.data,
];

String locationOf(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

String fullLocationOf(GoRouter r) => r.routerDelegate.currentConfiguration.uri.toString();
