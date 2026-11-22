import 'package:flutter/material.dart';
import 'package:splitify/data/repositories/sync_repository.dart';
import 'package:splitify/features/sync/application/sync_texts.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Photos not on the server yet (S-113/S-114): waiting, retrying, or skipped after too many refusals (with
/// Retry). They go up with the next sync, after their record.
class SyncUploadsCard extends StatelessWidget {
  const SyncUploadsCard({
    required this.uploads,
    required this.onRetry,
    this.busy = const {},
    super.key,
  });

  final List<SyncUpload> uploads;
  final void Function(SyncUpload upload) onRetry;

  /// Upload ids whose Retry is running.
  final Set<String> busy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      key: const Key('sync-uploads-card'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.all24,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < uploads.length; i++) ...[
            if (i > 0) const DashedDivider(),
            _UploadRow(
              key: ValueKey('sync-upload-${uploads[i].id}'),
              upload: uploads[i],
              busy: busy.contains(uploads[i].id),
              onRetry: () => onRetry(uploads[i]),
              title: syncUploadTitle(l, uploads[i]),
              state: syncUploadState(l, uploads[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadRow extends StatelessWidget {
  const _UploadRow({
    required this.upload,
    required this.busy,
    required this.onRetry,
    required this.title,
    required this.state,
    super.key,
  });

  final SyncUpload upload;
  final bool busy;
  final VoidCallback onRetry;
  final String title;
  final String state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final tone = upload.skipped ? c.oweText : c.textSecondary;
    final info = MergeSemantics(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.surfaceMuted, shape: BoxShape.circle),
            child: Icon(
              upload.skipped ? AppIcons.imageBroken : AppIcons.cloudUpload,
              size: 20,
              color: upload.skipped ? c.oweText : c.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.body.w(600)),
                const SizedBox(height: AppSpacing.s1),
                Text(state, style: context.text.bodySmall.copyWith(color: tone)),
              ],
            ),
          ),
        ],
      ),
    );
    final retry = upload.skipped
        ? PillButton(
            key: Key('sync-upload-retry-${upload.id}'),
            label: l.retryLabel,
            icon: AppIcons.sync,
            variant: PillVariant.outline,
            size: PillSize.medium,
            expand: large,
            loading: busy,
            onPressed: busy ? null : onRetry,
          )
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      child: retry == null
          ? info
          : large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: AppSpacing.s3),
                retry,
              ],
            )
          : Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: AppSpacing.s3),
                retry,
              ],
            ),
    );
  }
}
