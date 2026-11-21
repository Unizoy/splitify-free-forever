import 'package:splitify/core/config/env.dart';
import 'package:splitify/data/remote/supabase_auth_repository.dart';
import 'package:splitify/data/remote/supabase_profile_remote.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The remote services the app talks to, built once in bootstrap.
class RemoteServices {
  const RemoteServices({required this.auth, required this.profiles});

  final AuthRepository auth;
  final ProfileRemote? profiles;
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
  );
}
