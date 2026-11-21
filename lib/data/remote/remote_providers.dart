import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_nudges.dart';
import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server access. Bootstrap overrides it with the Supabase one (`initRemote`); without settings (D-020) and in
/// widget tests every call fails like being offline. Tests override with a fake.
final remoteApiProvider = Provider<RemoteApi>((ref) => const UnconfiguredRemoteApi());

/// Realtime nudges; tests override.
final changeNudgesProvider = Provider<ChangeNudges>((ref) {
  final n = SupabaseNudges(Supabase.instance.client);
  ref.onDispose(n.dispose);
  return n;
});
