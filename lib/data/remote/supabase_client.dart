import 'package:splitify/core/config/env.dart';
import 'package:splitify/data/remote/balances_remote.dart';
import 'package:splitify/data/remote/friends_remote.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/data/remote/groups_remote.dart';
import 'package:splitify/data/remote/history_remote.dart';
import 'package:splitify/data/remote/media_remote.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_auth_repository.dart';
import 'package:splitify/data/remote/supabase_nudges.dart';
import 'package:splitify/data/remote/supabase_profile_remote.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/repositories/auth_repository.dart';
import 'package:splitify/data/repositories/profile_repository.dart';
import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The remote services the app talks to, built once in bootstrap.
class RemoteServices {
  const RemoteServices({
    required this.auth,
    required this.profiles,
    this.api = const UnconfiguredRemoteApi(),
    this.groups = const UnconfiguredGroupsRemote(),
    this.media = const UnconfiguredMediaRemote(),
    this.history = const UnconfiguredHistoryRemote(),
    this.balances = const UnconfiguredBalancesRemote(),
    this.friends = const UnconfiguredFriendsRemote(),
    this.fxRates = const UnconfiguredFxRatesRemote(),
    this.notifications = const UnconfiguredNotificationsRemote(),
    this.nudges = const NoChangeNudges(),
  });

  final AuthRepository auth;
  final ProfileRemote? profiles;

  /// Sync RPCs (`apply_mutations`, `pull_changes`).
  final RemoteApi api;

  /// Online-only group RPCs (join, invite code, leave/remove/unlink).
  final GroupsRemote groups;

  /// Storage for receipt photos and group covers (phase 10).
  final MediaRemote media;

  /// Edit-history reads (`record_versions`, phase 12).
  final HistoryRemote history;

  /// Read-only balance RPCs (`group_balances`, `my_overview`).
  final BalancesRemote balances;

  /// Online-only friend RPC (`find_or_create_direct_group`, phase 11).
  final FriendsRemote friends;

  /// Read-only exchange rates (`fx_rates`, phase 14).
  final FxRatesRemote fxRates;

  /// Bell, notification settings, device token and reminders (phase 13).
  final NotificationsRemote notifications;

  /// Realtime "changed" nudges for the user's groups (sync trigger, 04 §1).
  final ChangeNudges nudges;
}

/// Starts Supabase from the build settings (02 §2). With placeholder values
/// (BLK-001, D-020) the app runs signed out and sign-in reports "not set up". [background] = WorkManager
/// run (04 §8): no sign-in links to listen for. Token refresh stays on: without it gotrue drops an expired
/// saved session, which would sign the person out.
Future<RemoteServices> initRemote(Env env, {bool background = false}) async {
  if (!isConfiguredValue(env.supabaseUrl) || !isConfiguredValue(env.supabasePublishableKey)) {
    return const RemoteServices(auth: UnconfiguredAuthRepository(), profiles: null);
  }
  await sb.Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabasePublishableKey,
    authOptions: background
        ? const sb.FlutterAuthClientOptions(detectSessionInUri: false)
        : const sb.FlutterAuthClientOptions(),
  );
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
    history: SupabaseHistoryRemote.fromClient(client),
    balances: SupabaseBalancesRemote.fromClient(client),
    friends: SupabaseFriendsRemote.fromClient(client),
    fxRates: SupabaseFxRatesRemote(client),
    notifications: SupabaseNotificationsRemote.fromClient(client),
    nudges: SupabaseNudges(client),
  );
}
