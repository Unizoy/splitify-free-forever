import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/sync/application/debug_log.dart';
import 'package:splitify/features/sync/application/sync_texts.dart';
import 'package:splitify/l10n/app_localizations_en.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/fakes.dart';

void main() {
  final l = AppLocalizationsEn();
  const m = DefaultMaterialLocalizations();

  SyncStatus st(SyncPhase p, {int waiting = 0, int failed = 0}) =>
      SyncStatus(phase: p, waiting: waiting, failed: failed);

  test('describeSync: busy, problems, offline, waiting, synced', () {
    expect(describeSync(l, st(SyncPhase.syncing, failed: 2)).tone, SyncTone.busy);
    expect(describeSync(l, st(SyncPhase.syncing)).title, 'Syncing…');
    final failed = describeSync(l, st(SyncPhase.offline, waiting: 3, failed: 1));
    expect((failed.title, failed.tone), ('1 change needs attention', SyncTone.problem));
    expect(describeSync(l, st(SyncPhase.idle, failed: 2)).title, '2 changes need attention');
    expect(describeSync(l, st(SyncPhase.signedOut)).title, 'Sign in again to sync');
    final off = describeSync(l, st(SyncPhase.offline, waiting: 2));
    expect(
      (off.title, off.tone, off.hint),
      ('You are offline', SyncTone.waiting, l.syncStateOfflineHint),
    );
    expect(describeSync(l, st(SyncPhase.error)).tone, SyncTone.problem);
    expect(describeSync(l, st(SyncPhase.idle, waiting: 1)).title, '1 change waiting to sync');
    expect(describeSync(l, st(SyncPhase.idle, waiting: 4)).title, '4 changes waiting to sync');
    final ok = describeSync(l, st(SyncPhase.idle));
    expect((ok.title, ok.tone, ok.icon), ('Everything is synced', SyncTone.ok, AppIcons.synced));
  });

  test('tone colours come from tokens', () {
    final c = AppTheme.light().extension<AppColors>()!;
    expect(syncToneColor(c, SyncTone.ok), c.owedText);
    expect(syncToneColor(c, SyncTone.busy), c.primary);
    expect(syncToneColor(c, SyncTone.waiting), c.unsynced);
    expect(syncToneColor(c, SyncTone.problem), c.oweText);
  });

  test('lastSyncText: never, just now, minutes, hours, date', () {
    final now = DateTime.utc(2026, 11, 21, 12);
    expect(lastSyncText(l, m, null, now), 'never');
    expect(lastSyncText(l, m, now.subtract(const Duration(seconds: 30)), now), 'just now');
    expect(lastSyncText(l, m, now.subtract(const Duration(minutes: 5)), now), '5 min ago');
    expect(lastSyncText(l, m, now.subtract(const Duration(hours: 1)), now), '1 hour ago');
    expect(lastSyncText(l, m, now.subtract(const Duration(hours: 3)), now), '3 hours ago');
    expect(lastSyncText(l, m, now.subtract(const Duration(days: 2)), now), startsWith('on '));
  });

  test('settings row value, reasons and icons', () {
    expect(syncRowValue(l, null), isNull);
    expect(syncRowValue(l, st(SyncPhase.idle)), 'Synced');
    expect(syncRowValue(l, st(SyncPhase.idle, waiting: 3)), '3 waiting');
    expect(syncRowValue(l, st(SyncPhase.idle, waiting: 3, failed: 1)), '1 problem');
    expect(syncIssueReason(l, sampleIssue()), 'You are no longer in this group.');
    expect(syncIssueReason(l, sampleIssue(code: 'INVALID_SHARES')), l.syncErrorRejected);
    expect({for (final e in SyncEntity.values) syncEntityIcon(e)}, hasLength(7));
    expect(l.syncIssueEntity('payment'), 'Payment');
    expect(l.syncIssueOp('delete'), 'Delete');
    expect(l.syncIssueTries(1), 'Tried once');
  });

  test('debug log has the sync state, issues by id and the log lines, nothing else', () {
    final text = buildDebugLog(
      version: '0.1.0',
      now: DateTime.utc(2026, 11, 21, 12),
      status: SyncStatus(
        phase: SyncPhase.offline,
        waiting: 2,
        failed: 1,
        lastSync: DateTime.utc(2026, 11, 21, 11),
        lastError: 'offline',
      ),
      issues: [sampleIssue()],
      lines: const ['10:00 INFO [sync] pushed 2'],
    );
    expect(text, contains('version: 0.1.0'));
    expect(text, contains('phase=offline waiting=2 failed=1 last=2026-11-21T11:00:00.000Z'));
    expect(
      text,
      contains('issue: seq=7 expense upsert record=01900000-0000-7000-8000-00000000e001'),
    );
    expect(text, contains('code=NOT_MEMBER attempts=2'));
    expect(text, contains('--- log (1 lines) ---\n10:00 INFO [sync] pushed 2'));
    final empty = buildDebugLog(
      version: 'x',
      now: DateTime.utc(2026),
      status: null,
      issues: const [],
      lines: const [],
    );
    expect(empty, isNot(contains('sync:')));
  });

  // TC-OFF-EDIT: where "Edit" opens each kind of refused change.
  group('syncIssueRoute', () {
    SyncIssue issue(
      SyncEntity e, {
      SyncOp op = SyncOp.upsert,
      String? targetType,
      String? targetId,
    }) => SyncIssue(
      seq: 1,
      entity: e,
      op: op,
      recordId: 'r1',
      groupId: 'g1',
      code: 'X',
      attempts: 1,
      createdAt: null,
      targetType: targetType,
      targetId: targetId,
    );

    test('every entity opens its own screen', () {
      expect(syncIssueRoute(issue(SyncEntity.expense)), '/expense/r1');
      expect(syncIssueRoute(issue(SyncEntity.payment)), '/payment/r1');
      expect(syncIssueRoute(issue(SyncEntity.group)), '/groups/r1/edit');
      expect(syncIssueRoute(issue(SyncEntity.member)), '/groups/g1/settings');
    });

    test('comments open what they are on, or nothing when unknown', () {
      expect(
        syncIssueRoute(issue(SyncEntity.comment, targetType: 'expense', targetId: 'e7')),
        '/expense/e7',
      );
      expect(
        syncIssueRoute(issue(SyncEntity.comment, targetType: 'payment', targetId: 'p7')),
        '/payment/p7',
      );
      expect(syncIssueRoute(issue(SyncEntity.comment)), isNull);
      expect(syncIssueRoute(issue(SyncEntity.comment, targetType: 'group', targetId: 'x')), isNull);
      expect(syncIssueRoute(issue(SyncEntity.comment, targetType: 'expense')), isNull);
    });

    test('a refused delete has nothing to edit', () {
      for (final e in SyncEntity.values) {
        expect(syncIssueRoute(issue(e, op: SyncOp.delete)), isNull, reason: e.name);
      }
    });
  });

  test('upload texts: waiting, retrying, skipped, kind', () {
    SyncUpload u(int attempts, [String bucket = 'receipts']) =>
        SyncUpload(id: 'a', bucket: bucket, recordId: 'r', attempts: attempts);
    expect(syncUploadState(l, u(0)), l.syncUploadWaiting);
    expect(syncUploadState(l, u(3)), l.syncUploadRetrying(3));
    expect(syncUploadState(l, u(8)), l.syncUploadSkipped(8));
    expect(syncUploadTitle(l, u(0)), 'Receipt photo');
    expect(syncUploadTitle(l, u(0, 'group-covers')), 'Group cover');
    expect(syncUploadTitle(l, u(0, 'zzz')), 'Photo');
    // W2-Y: an attachment's three kinds of upload.
    SyncUpload f(String path) =>
        SyncUpload(id: 'a', bucket: 'expense-files', recordId: 'r', attempts: 0, path: path);
    expect(syncUploadTitle(l, f('g/e/a.pdf')), 'PDF');
    expect(syncUploadTitle(l, f('g/e/a-thumb.jpg')), 'Photo preview');
    expect(syncUploadTitle(l, f('g/e/a.jpg')), 'Photo');
  });

  test('a refused attachment opens its expense (W2-Y)', () {
    SyncIssue at({String? targetId}) => SyncIssue(
      seq: 1,
      entity: SyncEntity.attachment,
      op: SyncOp.upsert,
      recordId: 'a1',
      groupId: 'g1',
      code: 'TOO_MANY_ATTACHMENTS',
      attempts: 1,
      createdAt: null,
      targetId: targetId,
    );
    expect(syncIssueRoute(at(targetId: 'e1')), '/expense/e1');
    expect(syncIssueRoute(at()), isNull);
  });
}
