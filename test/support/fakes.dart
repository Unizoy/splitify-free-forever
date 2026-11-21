import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';

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

/// Groups screens without a database or server: no groups, online, sync does nothing.
List<Override> emptyGroupsOverrides() => [
  groupsListProvider.overrideWith((ref) => Stream.value(const [])),
  deletedGroupsProvider.overrideWith((ref) => Stream.value(const [])),
  syncOfflineProvider.overrideWith((ref) => Stream.value(false)),
  syncNowProvider.overrideWithValue(() async {}),
];
