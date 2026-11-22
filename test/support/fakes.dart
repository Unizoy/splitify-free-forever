import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_engine.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/currency/application/currency_providers.dart'
    show fxAutoRefreshProvider;
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/balances/application/account_stats.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/application/balances_providers.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

import 'notification_fakes.dart';

/// Clock that only moves when the test says so.
class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// In-memory [AuthRepository] for controller and widget tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? user}) : _user = user;

  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();
  final calls = <String>[];

  /// Next failure to throw from any call (cleared after use).
  AuthFailure? fail;

  /// Codes that verify successfully.
  String goodCode = '123456';

  void _maybeFail() {
    final f = fail;
    if (f != null) {
      fail = null;
      throw f;
    }
  }

  void _signIn(String email) {
    _user = AuthUser(id: 'u-$email', email: email);
    _changes.add(_user);
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    calls.add('google');
    _maybeFail();
    _signIn('g@splitify.test');
  }

  @override
  Future<void> sendEmailCode(String email) async {
    calls.add('send:$email');
    _maybeFail();
  }

  @override
  Future<void> verifyEmailCode({required String email, required String code}) async {
    calls.add('verify:$code');
    _maybeFail();
    if (code != goodCode) throw const AuthFailure(AuthFailureCode.invalidCode);
    _signIn(email);
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    calls.add('password:$email');
    _maybeFail();
    _signIn(email);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _maybeFail();
    _user = null;
    _changes.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('delete');
    _maybeFail();
    _user = null;
    _changes.add(null);
  }
}

/// In-memory [ProfileRemote].
class FakeProfileRemote implements ProfileRemote {
  FakeProfileRemote([this.profile]);

  Profile? profile;
  ProfileFailure? fail;
  final uploads = <String>[];

  @override
  Future<Profile?> fetch(String userId) async {
    if (fail != null) throw fail!;
    return profile;
  }

  @override
  Future<Profile> update(Profile p) async {
    if (fail != null) throw fail!;
    return profile = p;
  }

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) async {
    final path = '$userId/${uploads.length}.jpg';
    uploads.add(path);
    return path;
  }
}

/// A sample profile for tests and goldens.
const sampleProfile = Profile(
  id: '00000000-0000-4000-8000-0000000000a1',
  displayName: 'Asha Rao',
  upiId: 'asha.rao@okaxis',
);

/// In-memory database for widget tests; streams close synchronously so no timers are left behind.
AppDatabase testDb() =>
    AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

/// Scripted [SyncRepository] for screens: fixed streams, records every action.
class FakeSyncRepository implements SyncRepository {
  FakeSyncRepository({
    this.status = const SyncStatus(phase: SyncPhase.idle),
    this.issues = const [],
    this.unsynced = false,
  });

  SyncStatus status;
  List<SyncIssue> issues;
  bool unsynced;
  final calls = <String>[];

  /// Completes "Sync now"; null = completes at once.
  Completer<void>? syncGate;

  @override
  SyncEngine get engine => throw UnimplementedError();

  @override
  Stream<SyncStatus> watchStatus() => Stream.value(status);

  @override
  Stream<List<SyncIssue>> watchIssues() => Stream.value(issues);

  @override
  Stream<bool> watchAnyUnsynced() => Stream.value(unsynced);

  @override
  Stream<bool> watchGroupUnsynced(String groupId) => Stream.value(unsynced);

  @override
  Future<void> syncNow() async {
    calls.add('sync');
    await syncGate?.future;
  }

  @override
  Future<void> retry(int seq) async => calls.add('retry:$seq');

  @override
  Future<void> discard(int seq) async => calls.add('discard:$seq');

  @override
  Future<bool> pushBeforeSignOut({Duration timeout = const Duration(seconds: 10)}) async {
    calls.add('push');
    return true;
  }

  @override
  Future<void> wipeLocal() async => calls.add('wipe');
}

/// A refused expense edit (screens, goldens).
SyncIssue sampleIssue({
  int seq = 7,
  SyncEntity entity = SyncEntity.expense,
  String code = 'NOT_MEMBER',
}) => SyncIssue(
  seq: seq,
  entity: entity,
  op: SyncOp.upsert,
  recordId: '01900000-0000-7000-8000-00000000e001',
  groupId: '01900000-0000-7000-8000-000000000001',
  code: code,
  attempts: 2,
  createdAt: DateTime.utc(2026, 11, 21, 9, 30),
);

/// Groups screens without a database or server: no groups, online, sync does nothing.
List<Override> emptyGroupsOverrides() => [
  groupsListProvider.overrideWith((ref) => Stream.value(const [])),
  deletedGroupsProvider.overrideWith((ref) => Stream.value(const [])),
  syncOfflineProvider.overrideWith((ref) => Stream.value(false)),
  syncNowProvider.overrideWithValue(() async {}),
  ...emptyBalanceOverrides(),
  ...quietNotificationOverrides(),
];

/// No balances or activity anywhere (phase 09 reads), without a database.
const noBalances = MyBalances(totals: {}, byGroup: {}, people: []);

/// Phase 09 overall reads without a database: nothing owed, no activity, zero stats. [all] is what
/// every group's Balances tab shows (the Settle up sheet and the wallet breakdown read it).
List<Override> emptyBalanceOverrides({
  MyBalances my = noBalances,
  List<GroupBalances> all = const [],
  AccountStats stats = const AccountStats(
    currency: 'INR',
    spentThisMonth: 0,
    groups: 0,
    people: 0,
    expenses: 0,
  ),
}) => [
  myBalancesProvider.overrideWithValue(AsyncData(my)),
  allGroupBalancesProvider.overrideWithValue(AsyncData(all)),
  accountStatsProvider.overrideWithValue(AsyncData(stats)),
  activityItemsProvider(null).overrideWithValue(const AsyncData([])),
  // Phase 11: the Friends tab reads every ledger.
  friendsProvider.overrideWithValue(const AsyncData([])),
  fxAutoRefreshProvider.overrideWith((ref) {}),
];
