import 'package:splitify/core/time/clock.dart';
import 'package:splitify/data/local/daos/sync_dao.dart';

/// Phone time corrected by the offset measured from every RPC's `server_time` (04 §3.5), so a wrong phone
/// clock does not decide conflicts.
class ServerClock {
  ServerClock(this.clock, this.dao);

  final Clock clock;
  final SyncDao dao;

  static const offsetKey = 'server_offset_ms';

  Duration? _offset;

  Future<Duration> offset() async =>
      _offset ??= Duration(milliseconds: int.tryParse(await dao.meta(offsetKey) ?? '') ?? 0);

  /// `client_updated_at` for a new local write.
  Future<DateTime> now() async => clock.now().toUtc().add(await offset());

  /// Records `server_time - phone time` from a response.
  Future<void> measure(DateTime serverTime) async {
    final o = serverTime.difference(clock.now().toUtc());
    _offset = o;
    await dao.setMeta(offsetKey, '${o.inMilliseconds}');
  }
}
