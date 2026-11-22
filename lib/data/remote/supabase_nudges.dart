import 'dart:async';

import 'package:splitify/data/sync/sync_triggers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Joins one private Realtime topic: [onChanged] on every "changed" broadcast, [onFailed] when the join is
/// refused or times out. Returns what leaves the topic again.
typedef TopicJoin = Future<void> Function() Function(
  String topic, {
  required void Function() onChanged,
  required void Function() onFailed,
});

/// [ChangeNudges] over private Realtime broadcast channels (03 §3; server side in migration 0009).
///
/// A group made on this phone appears in the list before the outbox has created it on the server, so its
/// first join is refused ("Unauthorized … group:<id>", seen in the dev project's Realtime log during the
/// final QA). A refused or timed-out topic is dropped and joined again after a pause (10 s, 20 s … up to
/// 2 min), and on every later [watchGroups] call — otherwise that group never got live updates until the app
/// restarted (S-259).
class SupabaseNudges implements ChangeNudges {
  SupabaseNudges(
    SupabaseClient client, {
    TopicJoin? join,
    String? Function()? userId,
    Duration retryBase = const Duration(seconds: 10),
  }) : _join = join ?? _supabaseJoin(client),
       _userId = userId ?? (() => client.auth.currentUser?.id),
       _retryBase = retryBase;

  final TopicJoin _join;
  final String? Function() _userId;
  final Duration _retryBase;
  final _out = StreamController<void>.broadcast();
  final _joined = <String, Future<void> Function()>{};
  final _retries = <String, Timer>{};
  final _attempts = <String, int>{};
  Set<String> _wanted = const {};
  bool _closed = false;

  @override
  Stream<void> get nudges => _out.stream;

  static TopicJoin _supabaseJoin(SupabaseClient client) =>
      (topic, {required onChanged, required onFailed}) {
        final channel = client
            .channel(topic, opts: const RealtimeChannelConfig(private: true))
            .onBroadcast(event: 'changed', callback: (_) => onChanged())
            .subscribe((status, [error]) {
              if (status == RealtimeSubscribeStatus.channelError ||
                  status == RealtimeSubscribeStatus.timedOut) {
                onFailed();
              }
            });
        return () => client.removeChannel(channel);
      };

  @override
  Future<void> watchGroups(Set<String> groupIds) async {
    if (_closed) return;
    final uid = _userId();
    _wanted = {for (final g in groupIds) 'group:$g', if (uid != null) 'user:$uid'};
    for (final t in _joined.keys.toList()) {
      if (!_wanted.contains(t)) await _leave(t);
    }
    for (final t in _retries.keys.toList()) {
      if (!_wanted.contains(t)) _retries.remove(t)?.cancel();
    }
    for (final t in _wanted) {
      if (!_joined.containsKey(t)) _subscribe(t);
    }
  }

  void _subscribe(String topic) {
    _retries.remove(topic)?.cancel();
    _joined[topic] = _join(topic, onChanged: () => _changed(topic), onFailed: () => _failed(topic));
  }

  void _changed(String topic) {
    _attempts.remove(topic);
    if (!_out.isClosed) _out.add(null);
  }

  void _failed(String topic) {
    if (_closed) return;
    unawaited(_leave(topic));
    if (!_wanted.contains(topic) || _retries.containsKey(topic)) return;
    final n = (_attempts[topic] ?? 0) + 1;
    _attempts[topic] = n;
    final wait = _retryBase * (n > 12 ? 12 : n);
    _retries[topic] = Timer(wait, () {
      _retries.remove(topic);
      if (!_closed && _wanted.contains(topic) && !_joined.containsKey(topic)) _subscribe(topic);
    });
  }

  Future<void> _leave(String topic) async {
    final leave = _joined.remove(topic);
    if (leave != null) await leave();
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    for (final t in _retries.values) {
      t.cancel();
    }
    _retries.clear();
    for (final t in _joined.keys.toList()) {
      await _leave(t);
    }
    await _out.close();
  }
}
