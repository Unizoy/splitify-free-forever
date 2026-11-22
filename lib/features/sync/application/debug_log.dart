import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:splitify/core/logging/logger.dart';
import 'package:splitify/data/repositories/sync_repository.dart';

/// Hands the debug log to the system share sheet; tests override.
final debugLogSharerProvider = Provider<Future<void> Function(String subject, String text)>(
  (ref) => (subject, text) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  },
);

/// The in-memory log lines (last 2,000); tests override.
final debugLogLinesProvider = Provider<List<String> Function()>(
  (ref) =>
      () => logBuffer.lines,
);

/// "Export debug log" text (04 §9): sync state, refused changes and recent log lines. Ids only — log
/// messages never carry tokens, emails, UPI IDs or names (02 §4).
String buildDebugLog({
  required String version,
  required DateTime now,
  required SyncStatus? status,
  required List<SyncIssue> issues,
  required List<String> lines,
  List<SyncUpload> uploads = const [],
}) {
  final b = StringBuffer()
    ..writeln('Splitify debug log')
    ..writeln('version: $version')
    ..writeln('generated: ${now.toUtc().toIso8601String()}');
  if (status != null) {
    b.writeln(
      'sync: phase=${status.phase.name} waiting=${status.waiting} failed=${status.failed} '
      'last=${status.lastSync?.toIso8601String() ?? 'never'} error=${status.lastError ?? '-'}',
    );
  }
  for (final i in issues) {
    b.writeln(
      'issue: seq=${i.seq} ${i.entity.wire} ${i.op.name} record=${i.recordId} '
      'group=${i.groupId} code=${i.code} attempts=${i.attempts}',
    );
  }
  for (final u in uploads) {
    b.writeln(
      'upload: ${u.bucket} record=${u.recordId} attempts=${u.attempts}${u.skipped ? ' skipped' : ''}',
    );
  }
  b.writeln('--- log (${lines.length} lines) ---');
  lines.forEach(b.writeln);
  return b.toString();
}
