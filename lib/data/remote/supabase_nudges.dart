import 'dart:async';

import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [ChangeNudges] over private Realtime broadcast channels (03 §3). Untested until the dev project exists
/// (BLK-001); the server side is in migration 0009.
class SupabaseNudges implements ChangeNudges {
  SupabaseNudges(this._client);

  final SupabaseClient _client;
  final _out = StreamController<void>.broadcast();
  final _channels = <String, RealtimeChannel>{};

  @override
  Stream<void> get nudges => _out.stream;

  @override
  Future<void> watchGroups(Set<String> groupIds) async {
    final uid = _client.auth.currentUser?.id;
    final topics = {for (final g in groupIds) 'group:$g', if (uid != null) 'user:$uid'};
    for (final t in _channels.keys.toList()) {
      if (!topics.contains(t)) await _client.removeChannel(_channels.remove(t)!);
    }
    for (final t in topics) {
      if (_channels.containsKey(t)) continue;
      _channels[t] = _client
          .channel(t, opts: const RealtimeChannelConfig(private: true))
          .onBroadcast(event: 'changed', callback: (_) => _out.add(null))
          .subscribe();
    }
  }

  @override
  Future<void> dispose() async {
    for (final c in _channels.values) {
      await _client.removeChannel(c);
    }
    _channels.clear();
    await _out.close();
  }
}
