import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/data/sync/sync_types.dart';
import 'package:splitify/features/sync/application/debug_log.dart';
import 'package:splitify/features/sync/application/sync_texts.dart';
import 'package:splitify/features/sync/presentation/sync_issue_card.dart';
import 'package:splitify/features/sync/presentation/sync_uploads_card.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Sync & storage" (`/account/sync`, 04 §9, 07 §2): status card (last sync, waiting, need attention),
/// "Sync now", refused changes with Edit / Retry / Discard, photos waiting to upload (skipped ones with
/// Retry, S-113), and "Export debug log".
class SyncStorageScreen extends ConsumerStatefulWidget {
  const SyncStorageScreen({super.key});

  @override
  ConsumerState<SyncStorageScreen> createState() => _SyncStorageScreenState();
}

class _SyncStorageScreenState extends ConsumerState<SyncStorageScreen> {
  bool _syncing = false;
  final _busy = <int>{};
  final _uploadBusy = <String>{};

  Future<void> _retryUpload(SyncUpload u) async {
    setState(() => _uploadBusy.add(u.id));
    try {
      await ref.read(syncRepositoryProvider).retryUpload(u.id);
    } finally {
      if (mounted) setState(() => _uploadBusy.remove(u.id));
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await ref.read(syncRepositoryProvider).syncNow();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _run(int seq, Future<void> Function(SyncRepository r) action) async {
    setState(() => _busy.add(seq));
    try {
      await action(ref.read(syncRepositoryProvider));
    } finally {
      if (mounted) setState(() => _busy.remove(seq));
    }
  }

  Future<void> _discard(SyncIssue issue) async {
    final yes = await confirmDiscard(context);
    if (yes ?? false) await _run(issue.seq, (r) => r.discard(issue.seq));
  }

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    final text = buildDebugLog(
      version: appVersion,
      now: ref.read(clockProvider).now(),
      status: ref.read(syncStatusProvider).value,
      issues: ref.read(syncIssuesProvider).value ?? const [],
      uploads: ref.read(syncUploadsProvider).value ?? const [],
      lines: ref.read(debugLogLinesProvider)(),
    );
    await ref.read(debugLogSharerProvider)(l.debugLogSubject, text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final status = ref.watch(syncStatusProvider);
    final issues = ref.watch(syncIssuesProvider).value ?? const <SyncIssue>[];
    final uploads = ref.watch(syncUploadsProvider).value ?? const <SyncUpload>[];
    final s = status.value;
    final syncing = _syncing || s?.phase == SyncPhase.syncing;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s2,
          AppSpacing.screen,
          MediaQuery.paddingOf(context).bottom + AppSpacing.s8,
        ),
        children: [
          Semantics(
            header: true,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AppText.maxSerifScale,
              child: Text(l.syncStorage, style: context.text.sheetTitle),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(l.syncStorageHint, style: context.text.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s6),
          if (status.hasError && s == null)
            EmptyState(icon: AppIcons.warning, title: l.syncStateError)
          else
            SyncStatusCard(status: s, now: ref.watch(clockProvider).now()),
          const SizedBox(height: AppSpacing.s5),
          PillButton(
            key: const Key('sync-now'),
            label: l.syncNow,
            icon: AppIcons.sync,
            loading: syncing,
            onPressed: syncing ? null : () => unawaited(_syncNow()),
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            _SectionLabel(l.syncIssuesTitle),
            for (final i in issues) ...[
              const SizedBox(height: AppSpacing.s3),
              SyncIssueCard(
                key: ValueKey('sync-issue-${i.seq}'),
                issue: i,
                busy: _busy.contains(i.seq),
                onEdit: switch (syncIssueRoute(i)) {
                  final route? => () => unawaited(context.push(route)),
                  null => null,
                },
                onRetry: () => unawaited(_run(i.seq, (r) => r.retry(i.seq))),
                onDiscard: () => unawaited(_discard(i)),
              ),
            ],
          ],
          if (uploads.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            _SectionLabel('${l.syncUploadsTitle}\u00A0· ${l.syncUploadsWaiting(uploads.length)}'),
            const SizedBox(height: AppSpacing.s3),
            SyncUploadsCard(
              uploads: uploads,
              busy: _uploadBusy,
              onRetry: (u) => unawaited(_retryUpload(u)),
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          _SectionLabel(l.onThisPhone),
          const SizedBox(height: AppSpacing.s1),
          DashedListRow(
            key: const Key('export-debug-log'),
            icon: AppIcons.share,
            label: l.exportDebugLog,
            showDivider: false,
            onTap: () => unawaited(_export()),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
    ),
  );
}

/// Status headline, last sync time and the two counts. [status] null = still loading.
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({required this.status, required this.now, super.key});

  final SyncStatus? status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final s = status;
    final head = s == null ? null : describeSync(l, s);
    final tone = head == null ? c.textTertiary : syncToneColor(c, head.tone);
    String count(int? n) => n?.toString() ?? '–';
    return Container(
      key: const Key('sync-status-card'),
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all24,
        border: Border.all(color: c.border),
        boxShadow: AppShadows.card(c, dark: context.isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(head?.icon ?? AppIcons.sync, size: 22, color: tone),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(head?.title ?? '…', style: context.text.title),
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        l.lastSyncLine(
                          lastSyncText(l, MaterialLocalizations.of(context), s?.lastSync, now),
                        ),
                        style: context.text.bodySmall.copyWith(color: c.textSecondary),
                      ),
                      if (head?.hint case final hint?) ...[
                        const SizedBox(height: AppSpacing.s2),
                        Text(hint, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          const DashedDivider(),
          const SizedBox(height: AppSpacing.s5),
          StatGrid(
            stats: [
              (value: count(s?.waiting), label: l.syncWaitingLabel),
              (value: count(s?.failed), label: l.syncFailedLabel),
            ],
            valueColor: c.textPrimary,
            labelColor: c.textSecondary,
          ),
        ],
      ),
    );
  }
}
