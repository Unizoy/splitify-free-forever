import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:splitify/core/utils/uuid.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/domain/entities/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Calls the server makes for profiles, as plain functions so tests can fake
/// them without a Supabase client.
typedef RpcCall = Future<Object?> Function(String name, Map<String, Object?> params);
typedef ProfileSelect = Future<Map<String, Object?>?> Function(String userId);
typedef AvatarPut = Future<void> Function(String path, Uint8List jpeg);

/// [ProfileRemote] over PostgREST (`profiles`, `update_profile`) and Storage.
class SupabaseProfileRemote implements ProfileRemote {
  SupabaseProfileRemote({required this.rpc, required this.select, required this.putAvatar});

  /// Wires the real client (thin glue, exercised on the device).
  factory SupabaseProfileRemote.fromClient(sb.SupabaseClient c) => SupabaseProfileRemote(
    rpc: (name, params) => c.rpc<Object?>(name, params: params),
    select: (id) => c.from('profiles').select().eq('id', id).maybeSingle(),
    putAvatar: (path, jpeg) => c.storage
        .from('avatars')
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const sb.FileOptions(contentType: 'image/jpeg', upsert: true),
        ),
  );

  final RpcCall rpc;
  final ProfileSelect select;
  final AvatarPut putAvatar;

  @override
  Future<Profile?> fetch(String userId) => _guard(() async {
    final row = await select(userId);
    return row == null ? null : Profile.fromJson(row);
  });

  @override
  Future<Profile> update(Profile p) => _guard(() async {
    final r = await rpc('update_profile', {
      'p_display_name': p.displayName,
      'p_upi_id': p.upiId,
      'p_default_currency': p.defaultCurrency,
      'p_avatar_path': p.avatarPath,
    });
    return Profile.fromJson((r! as Map).cast<String, Object?>());
  });

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) => _guard(() async {
    final path = '$userId/${newId()}.jpg';
    await putAvatar(path, jpeg);
    return path;
  });

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SocketException {
      throw const ProfileFailure(ProfileFailureCode.offline);
    } on TimeoutException {
      throw const ProfileFailure(ProfileFailureCode.offline);
    } on sb.PostgrestException catch (e) {
      throw ProfileFailure(switch (e.message) {
        'INVALID_NAME' => ProfileFailureCode.invalidName,
        'INVALID_UPI' => ProfileFailureCode.invalidUpi,
        'UNKNOWN_CURRENCY' => ProfileFailureCode.unknownCurrency,
        _ => ProfileFailureCode.unknown,
      });
    } on sb.StorageException {
      throw const ProfileFailure(ProfileFailureCode.unknown);
    }
  }
}
