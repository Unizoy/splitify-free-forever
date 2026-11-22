import 'dart:async';
import 'dart:io';

import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// One server `fx_rates` row (0017): [rate] units of [currency] per 1 EUR on [date] (`YYYY-MM-DD`), as exact
/// decimal text; [fetchedAt] is the ISO time of the `fetch-rates` run that wrote it.
typedef RemoteFxRate = ({String date, String currency, String rate, String fetchedAt});

/// Read-only access to the server's exchange rates (05 §6). Throws [NetworkException] when offline,
/// [AuthExpiredException] or [RemoteException] otherwise (same mapping as sync).
abstract class FxRatesRemote {
  /// Rows written after [since] (every row when null) dated on or after [fromDate], ordered by
  /// `fetched_at, date, currency`; one page of at most [limit] rows starting at [offset].
  Future<List<RemoteFxRate>> changedSince({
    required String? since,
    required String fromDate,
    int offset = 0,
    int limit = 1000,
  });

  /// Rows of [currencies] dated [from]..[to] (both `YYYY-MM-DD`, inclusive), for records older than the cache.
  Future<List<RemoteFxRate>> between(Set<String> currencies, String from, String to);
}

/// No server configured (D-020 dummy builds, widget tests): always offline.
class UnconfiguredFxRatesRemote implements FxRatesRemote {
  const UnconfiguredFxRatesRemote();

  @override
  Future<List<RemoteFxRate>> changedSince({
    required String? since,
    required String fromDate,
    int offset = 0,
    int limit = 1000,
  }) => Future.error(const NetworkException(UnconfiguredRemoteApi.code));

  @override
  Future<List<RemoteFxRate>> between(Set<String> currencies, String from, String to) =>
      Future.error(const NetworkException(UnconfiguredRemoteApi.code));
}

/// [FxRatesRemote] over PostgREST (`rate::text` keeps the numeric exact; JSON numbers would be doubles).
class SupabaseFxRatesRemote implements FxRatesRemote {
  SupabaseFxRatesRemote(this._client);

  final sb.SupabaseClient _client;

  static const _columns = 'date,currency,rate::text,fetched_at';

  @override
  Future<List<RemoteFxRate>> changedSince({
    required String? since,
    required String fromDate,
    int offset = 0,
    int limit = 1000,
  }) => _run(() {
    var q = _client.from('fx_rates').select(_columns).gte('date', fromDate);
    if (since != null) q = q.gt('fetched_at', since);
    return q
        .order('fetched_at', ascending: true)
        .order('date', ascending: true)
        .order('currency', ascending: true)
        .range(offset, offset + limit - 1);
  });

  @override
  Future<List<RemoteFxRate>> between(Set<String> currencies, String from, String to) => _run(
    () => _client
        .from('fx_rates')
        .select(_columns)
        .inFilter('currency', currencies.toList()..sort())
        .gte('date', from)
        .lte('date', to)
        .order('date', ascending: true)
        .order('currency', ascending: true),
  );

  static Future<List<RemoteFxRate>> _run(
    Future<List<Map<String, dynamic>>> Function() query,
  ) async {
    try {
      final rows = await query().timeout(const Duration(seconds: 20));
      return [for (final r in rows) parseRemoteFxRate(r)];
    } on sb.PostgrestException catch (e) {
      throw SupabaseRemoteApi.mapPostgrest(e);
    } on sb.AuthException {
      throw const AuthExpiredException();
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      throw const NetworkException('timeout');
    } on HttpException catch (e) {
      throw NetworkException(e.message);
    }
  }
}

/// One PostgREST row → [RemoteFxRate] (char(3) codes are trimmed). Throws [RemoteException] for a bad row.
RemoteFxRate parseRemoteFxRate(Map<String, dynamic> r) {
  final date = r['date'];
  final currency = r['currency'];
  final rate = r['rate'];
  final fetchedAt = r['fetched_at'];
  if (date is! String || currency is! String || rate is! String || fetchedAt is! String) {
    throw const RemoteException('BAD_RESPONSE');
  }
  return (date: date, currency: currency.trim(), rate: rate, fetchedAt: fetchedAt);
}
