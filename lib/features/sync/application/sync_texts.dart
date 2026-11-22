import 'package:flutter/material.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/domain/entities/prepared_image.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// How a sync state reads: calm, busy, waiting on the phone, or needs the person.
enum SyncTone { ok, busy, waiting, problem }

/// Headline of the status card ("Sync & storage", 04 §9).
typedef SyncHeadline = ({IconData icon, String title, String? hint, SyncTone tone});

/// Picks the one thing to say about [s]; problems win over waiting, waiting over "all synced".
SyncHeadline describeSync(AppLocalizations l, SyncStatus s) {
  if (s.phase == SyncPhase.syncing) {
    return (icon: AppIcons.sync, title: l.syncing, hint: null, tone: SyncTone.busy);
  }
  if (s.failed > 0) {
    return (
      icon: AppIcons.warning,
      title: l.syncStateFailed(s.failed),
      hint: null,
      tone: SyncTone.problem,
    );
  }
  return switch (s.phase) {
    SyncPhase.signedOut => (
      icon: AppIcons.warning,
      title: l.syncStateSignedOut,
      hint: null,
      tone: SyncTone.problem,
    ),
    SyncPhase.offline => (
      icon: AppIcons.unsynced,
      title: l.syncStateOffline,
      hint: l.syncStateOfflineHint,
      tone: SyncTone.waiting,
    ),
    SyncPhase.error => (
      icon: AppIcons.warning,
      title: l.syncStateError,
      hint: null,
      tone: SyncTone.problem,
    ),
    _ when s.waiting > 0 => (
      icon: AppIcons.unsynced,
      title: l.syncStateWaiting(s.waiting),
      hint: null,
      tone: SyncTone.waiting,
    ),
    _ => (icon: AppIcons.synced, title: l.syncStateSynced, hint: null, tone: SyncTone.ok),
  };
}

/// Token colour for a [SyncTone].
Color syncToneColor(AppColors c, SyncTone t) => switch (t) {
  SyncTone.ok => c.owedText,
  SyncTone.busy => c.primary,
  SyncTone.waiting => c.unsynced,
  SyncTone.problem => c.oweText,
};

/// "just now", "5 min ago", "3 hours ago", "on 21 Nov", "never".
String lastSyncText(AppLocalizations l, MaterialLocalizations m, DateTime? last, DateTime now) {
  if (last == null) return l.lastSyncNever;
  final ago = now.toUtc().difference(last.toUtc());
  if (ago.inMinutes < 1) return l.lastSyncJustNow;
  if (ago.inMinutes < 60) return l.lastSyncMinutes(ago.inMinutes);
  if (ago.inHours < 24) return l.lastSyncHours(ago.inHours);
  return l.lastSyncOn(m.formatShortMonthDay(last.toLocal()));
}

/// Value of the "Sync & storage" settings row; null while loading.
String? syncRowValue(AppLocalizations l, SyncStatus? s) {
  if (s == null) return null;
  if (s.failed > 0) return l.syncRowProblems(s.failed);
  if (s.waiting > 0) return l.syncRowWaiting(s.waiting);
  return l.syncRowSynced;
}

/// Friendly reason for a refused change.
String syncIssueReason(AppLocalizations l, SyncIssue i) =>
    i.code == 'NOT_MEMBER' ? l.syncErrorNotMember : l.syncErrorRejected;

/// Icon for the kind of record a change is about.
IconData syncEntityIcon(SyncEntity e) => switch (e) {
  SyncEntity.group => AppIcons.groups,
  SyncEntity.member => AppIcons.user,
  SyncEntity.expense => AppIcons.receipt,
  SyncEntity.payment => AppIcons.coins,
  SyncEntity.comment => AppIcons.chat,
  SyncEntity.recurring => AppIcons.repeat,
};

/// Where "Edit" opens the record of a refused change so the person can fix it; null when there is nothing
/// to open (a refused delete: Retry or Discard only).
String? syncIssueRoute(SyncIssue i) {
  if (i.op == SyncOp.delete) return null;
  return switch (i.entity) {
    SyncEntity.expense => '/expense/${i.recordId}',
    SyncEntity.payment => '/payment/${i.recordId}',
    SyncEntity.group => '/groups/${i.recordId}/edit',
    SyncEntity.member => '/groups/${i.groupId}/settings',
    // A refused repeat rule opens "Edit future copies" (phase 16).
    SyncEntity.recurring => '/recurring/${i.recordId}/edit',
    SyncEntity.comment => switch ((i.targetType, i.targetId)) {
      ('expense', final String id) => '/expense/$id',
      ('payment', final String id) => '/payment/$id',
      _ => null,
    },
  };
}

/// "Receipt photo" / "Group cover".
String syncUploadTitle(AppLocalizations l, SyncUpload u) => l.syncUploadKind(switch (u.bucket) {
  MediaBuckets.receipts => 'receipt',
  MediaBuckets.groupCovers => 'cover',
  _ => 'other',
});

/// Waiting, retrying after refusals, or skipped (S-113).
String syncUploadState(AppLocalizations l, SyncUpload u) {
  if (u.skipped) return l.syncUploadSkipped(u.attempts);
  if (u.attempts > 0) return l.syncUploadRetrying(u.attempts);
  return l.syncUploadWaiting;
}
