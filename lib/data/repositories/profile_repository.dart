import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitify/domain/entities/profile.dart';

/// Why a profile change failed (mapped to ARB copy in the UI).
enum ProfileFailureCode { offline, invalidName, invalidUpi, unknownCurrency, unknown }

class ProfileFailure implements Exception {
  const ProfileFailure(this.code);

  final ProfileFailureCode code;

  @override
  String toString() => 'ProfileFailure(${code.name})';
}

/// Remote profile calls (`profiles` read, `update_profile` RPC, `avatars`
/// bucket). Profile edits are online-only (phase 05 allowed exception).
abstract interface class ProfileRemote {
  Future<Profile?> fetch(String userId);

  Future<Profile> update(Profile profile);

  /// Uploads a compressed JPEG and returns its bucket path.
  Future<String> uploadAvatar(String userId, Uint8List jpeg);
}

/// Profile with a local cache so the Account tab shows it offline.
class ProfileRepository {
  ProfileRepository({required this.remote, required this.prefs});

  static const cacheKey = 'profile.cache';

  final ProfileRemote? remote;
  final SharedPreferences prefs;

  /// Last profile seen on this phone.
  Profile? get cached {
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    return Profile.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  /// Fresh profile from the server (falls back to the cache when offline).
  Future<Profile?> load(String userId) async {
    final r = remote;
    if (r == null) return cached;
    try {
      final p = await r.fetch(userId);
      if (p != null) await _store(p);
      return p ?? cached;
    } on ProfileFailure catch (e) {
      if (e.code == ProfileFailureCode.offline) return cached;
      rethrow;
    }
  }

  /// Saves on the server, optionally uploading a new photo first.
  Future<Profile> save(Profile profile, {Uint8List? photo}) async {
    final r = remote;
    if (r == null) throw const ProfileFailure(ProfileFailureCode.offline);
    var next = profile;
    if (photo != null) {
      next = next.copyWith(avatarPath: await r.uploadAvatar(profile.id, photo));
    }
    final saved = await r.update(next);
    await _store(saved);
    return saved;
  }

  Future<void> _store(Profile p) => prefs.setString(cacheKey, jsonEncode(p.toJson()));
}
