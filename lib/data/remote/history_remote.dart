import 'dart:async';

import 'package:splitify/data/remote/remote_api.dart';
import 'package:splitify/data/remote/supabase_remote_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Reads `record_versions` (edit history, 08 #20). Read-only and per record (S-130): the history screen fetches
/// what it has not cached yet. RLS lets only group members read them.
abstract class HistoryRemote {
  /// Versions of [recordId] with `seq > afterSeq`, oldest first, as snake_case JSON rows. Throws
  /// [NetworkException] when offline, [AuthExpiredException] or [RemoteException] otherwise.
  Future<List<Map<String, Object?>>> versions(String recordId, {int afterSeq = 0});
}

/// No server configured (D-020 builds, widget tests): fails like being offline.
class UnconfiguredHistoryRemote implements HistoryRemote {
  const UnconfiguredHistoryRemote();

  @override
  Future<List<Map<String, Object?>>> versions(String recordId, {int afterSeq = 0}) =>
      Future.error(const NetworkException(UnconfiguredRemoteApi.code));
}

typedef VersionsQuery = Future<List<Object?>> Function(String recordId, int afterSeq);

/// [HistoryRemote] over PostgREST.
class SupabaseHistoryRemote implements HistoryRemote {
  SupabaseHistoryRemote(this._query);

  /// Wires the real client (thin glue, exercised on the device).
  factory SupabaseHistoryRemote.fromClient(sb.SupabaseClient c) => SupabaseHistoryRemote(
    (recordId, afterSeq) async => c
        .from('record_versions')
        .select(columns)
        .eq('record_id', recordId)
        .gt('seq', afterSeq)
        .order('seq', ascending: true),
  );

  static const columns =
      'id, table_name, record_id, group_id, op, snapshot, changed_by, changed_at, client_updated_at, seq';

  final VersionsQuery _query;

  @override
  Future<List<Map<String, Object?>>> versions(String recordId, {int afterSeq = 0}) async {
    try {
      final rows = await _query(recordId, afterSeq).timeout(const Duration(seconds: 20));
      return [for (final r in rows) (r! as Map).cast<String, Object?>()];
    } on sb.PostgrestException catch (e) {
      throw SupabaseRemoteApi.mapPostgrest(e);
    } on sb.AuthException {
      throw const AuthExpiredException();
    } on TimeoutException {
      throw const NetworkException('timeout');
    } on Exception catch (e) {
      // Socket, HTTP client and TLS failures: treat as offline (the screen keeps the cached history).
      throw NetworkException(e.runtimeType.toString());
    }
  }
}
