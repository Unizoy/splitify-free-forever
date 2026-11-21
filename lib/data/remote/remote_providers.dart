import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_nudges.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server access; needs `Supabase.initialize` (phase 05 bootstrap). Tests override with a fake.
final remoteApiProvider = Provider<RemoteApi>(
  (ref) => SupabaseRemoteApi.client(Supabase.instance.client),
);

/// Realtime nudges; tests override.
final changeNudgesProvider = Provider<ChangeNudges>((ref) {
  final n = SupabaseNudges(Supabase.instance.client);
  ref.onDispose(n.dispose);
  return n;
});
