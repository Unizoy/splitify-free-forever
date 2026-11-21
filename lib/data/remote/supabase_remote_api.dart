import 'dart:async';
import 'dart:io';

import 'package:splitify/data/remote/remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef RpcCall = Future<Object?> Function(String fn, Map<String, Object?> params);

/// [RemoteApi] over Supabase RPCs. Errors are mapped to [NetworkException], [AuthExpiredException] or
/// [RemoteException] so the sync engine never sees Supabase types.
class SupabaseRemoteApi implements RemoteApi {
  SupabaseRemoteApi(this._rpc, this._refresh);

  /// Real client (not covered by unit tests; proven on the dev project, BLK-001).
  factory SupabaseRemoteApi.client(SupabaseClient c) =>
      SupabaseRemoteApi((fn, params) async => c.rpc<Object?>(fn, params: params), () async {
        await c.auth.refreshSession();
      });

  final RpcCall _rpc;
  final Future<void> Function() _refresh;

  Future<Map<String, Object?>> _call(String fn, Map<String, Object?> params) async {
    try {
      final r = await _rpc(fn, params).timeout(const Duration(seconds: 30));
      if (r is! Map) throw const RemoteException('BAD_RESPONSE');
      return r.cast<String, Object?>();
    } on PostgrestException catch (e) {
      throw mapPostgrest(e);
    } on AuthException {
      throw const AuthExpiredException();
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      throw const NetworkException('timeout');
    } on HttpException catch (e) {
      throw NetworkException(e.message);
    }
  }

  /// PostgREST error → sync error. JWT problems are 401s; 5xx and gateway errors are retryable.
  static Exception mapPostgrest(PostgrestException e) {
    final code = e.code ?? '';
    if (code == 'PGRST301' || code == 'PGRST303' || code == '401' || e.message.contains('JWT')) {
      return const AuthExpiredException();
    }
    if (code.startsWith('5') || code == 'PGRST000' || code == 'PGRST001' || code == 'PGRST002') {
      return NetworkException(code);
    }
    return RemoteException(code.isEmpty ? e.message : code);
  }

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) async =>
      ApplyResponse.fromJson(await _call('apply_mutations', {'batch': batch}));

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) async => PullPage.fromJson(
    await _call('pull_changes', {
      'cursors': cursors,
      'since_user_seq': userSeq,
      'page_size': pageSize,
    }),
  );

  @override
  Future<void> refreshSession() async {
    try {
      await _refresh();
    } on Exception {
      throw const AuthExpiredException();
    }
  }
}
