import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/core/config/preferences.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/media_providers.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/local_wipe.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/domain/entities/profile.dart';

export 'package:splitify/data/data_providers.dart' show clockProvider;

/// Auth backend; bootstrap overrides it with the Supabase one.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const UnconfiguredAuthRepository(),
);

/// Remote profile calls; null when Supabase is not configured.
final profileRemoteProvider = Provider<ProfileRemote?>((ref) => null);

/// True when Google sign-in is set up in this build (D-020).
final googleConfiguredProvider = Provider<bool>((ref) => false);

/// True when the debug-only developer sign-in is available (T4, TC-B1-08).
final devLoginProvider = Provider<bool>((ref) => false);

/// Password for the e2e test users (debug builds only).
final e2ePasswordProvider = Provider<String>((ref) => '');

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    remote: ref.watch(profileRemoteProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

final localWipeProvider = Provider<LocalWipe>(
  (ref) => LocalWipe(
    prefs: ref.watch(sharedPreferencesProvider),
    clearDatabase: () async {
      await ref.read(syncRepositoryProvider).wipeLocal();
      await ref.read(mediaFilesProvider).wipe();
    },
  ),
);

/// The signed-in user (null = signed out).
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

/// The signed-in person's profile; cached locally, refreshed from the server.
final profileProvider = AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);

class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final user = ref.watch(authUserProvider).value ?? ref.watch(authRepositoryProvider).currentUser;
    final repo = ref.watch(profileRepositoryProvider);
    if (user == null) return null;
    final cached = repo.cached;
    try {
      return await repo.load(user.id) ?? cached;
    } on ProfileFailure {
      return cached;
    }
  }

  /// Saves [profile] (online only) and returns the server copy.
  Future<Profile> save(Profile profile, {Uint8List? photo}) async {
    final saved = await ref.read(profileRepositoryProvider).save(profile, photo: photo);
    state = AsyncData(saved);
    return saved;
  }
}

/// Sign out (T8) and delete account (T7): server call, then wipe this phone.
/// The router redirect then shows the welcome screen.
final accountActionsProvider = Provider<AccountActions>(AccountActions.new);

class AccountActions {
  AccountActions(this._ref);

  final Ref _ref;

  /// 04 §7: send waiting changes (10 s best effort) → sign out → wipe the local database and sign-in data.
  /// Phase 13 adds "unregister the device token" before the sign-out.
  Future<void> signOut() async {
    await _ref.read(syncRepositoryProvider).pushBeforeSignOut();
    try {
      await _ref.read(authRepositoryProvider).signOut();
    } finally {
      await _ref.read(localWipeProvider).wipe();
    }
  }

  /// Online only: waiting changes go first so they stay in the groups, then the server deletes the account.
  Future<void> deleteAccount() async {
    await _ref.read(syncRepositoryProvider).pushBeforeSignOut();
    await _ref.read(authRepositoryProvider).deleteAccount();
    await _ref.read(localWipeProvider).wipe();
  }
}
