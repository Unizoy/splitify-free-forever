import 'package:splitify/core/config/env.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_auth_repository.dart';
import 'package:splitify/data/remote/supabase_profile_remote.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The remote services the app talks to, built once in bootstrap.
class RemoteServices {
  const RemoteServices({
    required this.auth,
    required this.profiles,
    this.api = const UnconfiguredRemoteApi(),
    this.groups = const UnconfiguredGroupsRemote(),
    this.media = const UnconfiguredMediaRemote(),
  });

  final AuthRepository auth;
  final ProfileRemote? profiles;

  /// Sync RPCs (`apply_mutations`, `pull_changes`).
  final RemoteApi api;

  /// Online-only group RPCs (join, invite code, leave/remove/unlink).
  final GroupsRemote groups;

  /// Storage for receipt photos and group covers (phase 10).
  final MediaRemote media;
}

/// Starts Supabase from the build settings (02 §2). With placeholder values
/// (BLK-001, D-020) the app runs signed out and sign-in reports "not set up".
Future<RemoteServices> initRemote(Env env) async {
  if (!isConfiguredValue(env.supabaseUrl) || !isConfiguredValue(env.supabasePublishableKey)) {
    return const RemoteServices(auth: UnconfiguredAuthRepository(), profiles: null);
  }
  await sb.Supabase.initialize(url: env.supabaseUrl, anonKey: env.supabasePublishableKey);
  final client = sb.Supabase.instance.client;
  return RemoteServices(
    auth: SupabaseAuthRepository(
      auth: client.auth,
      functions: client.functions,
      google: env.hasGoogle ? GoogleSignInIdTokenSource(env.googleWebClientId) : null,
    ),
    profiles: SupabaseProfileRemote.fromClient(client),
    api: SupabaseRemoteApi.client(client),
    groups: SupabaseGroupsRemote.fromClient(client),
    media: SupabaseMediaRemote.fromClient(client),
  );
}
