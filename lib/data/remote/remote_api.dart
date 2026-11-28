/// The only door to the server (planning/04-sync-engine.md §3–4). Implemented with Supabase in
/// `supabase_remote_api.dart`; tests use a scripted fake.
abstract class RemoteApi {
  /// `apply_mutations(batch)`; mutations are applied in order.
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch);

  /// `pull_changes(cursors, since_user_seq, page_size)`.
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  });

  /// Refreshes the session once after a 401; throws [AuthExpiredException] when that fails.
  Future<void> refreshSession();
}

/// Status of one mutation as reported by `apply_mutations`.
enum MutationStatus { applied, duplicate, superseded, rejected }

class MutationResult {
  const MutationResult(this.mutationId, this.status, {this.code, this.seq});

  factory MutationResult.fromJson(Map<String, Object?> j) => MutationResult(
    j['mutation_id']! as String,
    MutationStatus.values.byName(j['status']! as String),
    code: j['code'] as String?,
    seq: (j['seq'] as num?)?.toInt(),
  );

  final String mutationId;
  final MutationStatus status;
  final String? code;

  /// The row's `seq` on the server after this mutation: the new version (applied), the version that won
  /// (superseded) or, for a duplicate, what the first delivery reported.
  final int? seq;
}

class ApplyResponse {
  const ApplyResponse(this.serverTime, this.results);

  factory ApplyResponse.fromJson(Map<String, Object?> j) =>
      ApplyResponse(DateTime.parse(j['server_time']! as String).toUtc(), [
        for (final r in j['results']! as List<Object?>)
          MutationResult.fromJson((r! as Map).cast<String, Object?>()),
      ]);

  final DateTime serverTime;
  final List<MutationResult> results;
}

/// One page of `pull_changes`.
class PullPage {
  const PullPage({
    required this.serverTime,
    required this.rows,
    required this.nextCursors,
    required this.userSeq,
    this.lostGroups = const [],
    this.hasMore = false,
  });

  factory PullPage.fromJson(Map<String, Object?> j) => PullPage(
    serverTime: DateTime.parse(j['server_time']! as String).toUtc(),
    rows: {
      for (final e in ((j['rows'] as Map?) ?? const {}).entries)
        e.key as String: [
          for (final r in e.value as List<Object?>) (r! as Map).cast<String, Object?>(),
        ],
    },
    nextCursors: {
      for (final e in ((j['next_cursors'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as int?) ?? 0,
    },
    userSeq: (j['user_seq'] as int?) ?? 0,
    lostGroups: [for (final g in (j['lost_groups'] as List?) ?? const []) g as String],
    hasMore: (j['has_more'] as bool?) ?? false,
  );

  final DateTime serverTime;

  /// Server rows per table name (`groups`, `group_members`, `expenses`, `payments`, `comments`, `activity`,
  /// `profiles`), as JSON objects with snake_case keys.
  final Map<String, List<Map<String, Object?>>> rows;
  final Map<String, int> nextCursors;
  final int userSeq;
  final List<String> lostGroups;
  final bool hasMore;
}

/// No connection, timeout or 5xx: retry later with backoff.
class NetworkException implements Exception {
  const NetworkException([this.message = 'network']);
  final String message;

  @override
  String toString() => 'NetworkException($message)';
}

/// 401 / expired session.
class AuthExpiredException implements Exception {
  const AuthExpiredException();

  @override
  String toString() => 'AuthExpiredException';
}

/// The server refused the whole request (4xx other than 401, malformed response).
class RemoteException implements Exception {
  const RemoteException(this.code);
  final String code;

  @override
  String toString() => 'RemoteException($code)';
}

/// Used when the build has no Supabase settings (D-020) and in tests that never reach the server: every call
/// fails like being offline, so writes stay queued.
class UnconfiguredRemoteApi implements RemoteApi {
  const UnconfiguredRemoteApi();

  static const code = 'not_configured';

  @override
  Future<ApplyResponse> applyMutations(List<Map<String, Object?>> batch) =>
      Future.error(const NetworkException(code));

  @override
  Future<PullPage> pullChanges({
    required Map<String, int> cursors,
    required int userSeq,
    int pageSize = 500,
  }) => Future.error(const NetworkException(code));

  @override
  Future<void> refreshSession() => Future.error(const AuthExpiredException());
}
