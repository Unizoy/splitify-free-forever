import 'dart:async';
import 'dart:io';

import 'package:splitify/core/money/balances.dart';
import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// The server's balances of one group (`group_balances`, 0006): one [Balances] block per currency
/// (rule 3: the server holds the true balances).
class ServerGroupBalances {
  const ServerGroupBalances({
    required this.groupId,
    required this.mainCurrency,
    required this.simplify,
    required this.currencies,
  });

  factory ServerGroupBalances.fromJson(Map<String, Object?> j) => ServerGroupBalances(
    groupId: j['group_id']! as String,
    mainCurrency: (j['main_currency'] as String?)?.trim() ?? 'INR',
    simplify: (j['simplify_debts'] as bool?) ?? false,
    currencies: {
      for (final e in ((j['currencies'] as Map?) ?? const {}).entries)
        e.key as String: _block((e.value! as Map).cast<String, Object?>()),
    },
  );

  final String groupId;
  final String mainCurrency;
  final bool simplify;

  /// Balances per currency code.
  final Map<String, Balances> currencies;

  static Balances _block(Map<String, Object?> b) => Balances(
    nets: minorMap(b['nets']),
    pairs: _transfers(b['pairs']),
    simplified: _transfers(b['simplified']),
  );

  static List<Transfer> _transfers(Object? json) => [
    for (final t in (json as List?) ?? const [])
      Transfer((t as List)[0]! as String, t[1]! as String, (t[2]! as num).toInt()),
  ];
}

/// One group in `my_overview`: my member id there and my net per currency.
typedef ServerGroupBalance = ({String groupId, String memberId, Map<String, int> balances});

/// One person in `my_overview` (positive = they owe me). Linked people have [userId]; name-only
/// members have [memberId] + [groupId].
typedef ServerPersonBalance = ({
  String? userId,
  String? memberId,
  String? groupId,
  String name,
  Map<String, int> balances,
});

/// `my_overview()`: my overall balance per currency, per group and per person.
class ServerOverview {
  const ServerOverview({required this.totals, required this.groups, required this.people});

  factory ServerOverview.fromJson(Map<String, Object?> j) => ServerOverview(
    totals: minorMap(j['totals']),
    groups: [
      for (final g in (j['groups'] as List?) ?? const [])
        (
          groupId: (g as Map)['group_id']! as String,
          memberId: g['member_id']! as String,
          balances: minorMap(g['balances']),
        ),
    ],
    people: [
      for (final f in (j['friends'] as List?) ?? const [])
        (
          userId: (f as Map)['user_id'] as String?,
          memberId: f['member_id'] as String?,
          groupId: f['group_id'] as String?,
          name: (f['name'] as String?) ?? '',
          balances: minorMap(f['balances']),
        ),
    ],
  );

  final Map<String, int> totals;
  final List<ServerGroupBalance> groups;
  final List<ServerPersonBalance> people;
}

/// `{key: minor}` JSON → ints (PostgREST sends bigint as JSON numbers).
Map<String, int> minorMap(Object? json) => {
  for (final e in ((json as Map?) ?? const {}).entries) e.key as String: (e.value! as num).toInt(),
};

/// Read-only balance RPCs. Throws [NetworkException] when offline, [AuthExpiredException] or
/// [RemoteException] otherwise (same mapping as sync).
abstract class BalancesRemote {
  Future<ServerGroupBalances> groupBalances(String groupId);
  Future<ServerOverview> myOverview();
}

/// No server configured (D-020 dummy builds, widget tests): always offline.
class UnconfiguredBalancesRemote implements BalancesRemote {
  const UnconfiguredBalancesRemote();

  @override
  Future<ServerGroupBalances> groupBalances(String groupId) =>
      Future.error(const NetworkException(UnconfiguredRemoteApi.code));

  @override
  Future<ServerOverview> myOverview() =>
      Future.error(const NetworkException(UnconfiguredRemoteApi.code));
}

/// [BalancesRemote] over PostgREST RPCs.
class SupabaseBalancesRemote implements BalancesRemote {
  SupabaseBalancesRemote(this._rpc);

  /// Wires the real client (thin glue, exercised on the device).
  factory SupabaseBalancesRemote.fromClient(sb.SupabaseClient c) =>
      SupabaseBalancesRemote((fn, params) => c.rpc<Object?>(fn, params: params));

  final RpcCall _rpc;

  Future<Map<String, Object?>> _call(String fn, Map<String, Object?> params) async {
    try {
      final r = await _rpc(fn, params).timeout(const Duration(seconds: 20));
      if (r is! Map) throw const RemoteException('BAD_RESPONSE');
      return r.cast<String, Object?>();
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

  @override
  Future<ServerGroupBalances> groupBalances(String groupId) async =>
      ServerGroupBalances.fromJson(await _call('group_balances', {'group_id': groupId}));

  @override
  Future<ServerOverview> myOverview() async =>
      ServerOverview.fromJson(await _call('my_overview', const {}));
}
