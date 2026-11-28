import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart' show StepBody;
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/application/import_providers.dart';
import 'package:splitify/features/import_splitwise/presentation/import_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Step 1: how to export from Splitwise, the file picker, a readable error for a bad file, and the
/// imports already done on this phone (each can be deleted again).
class ImportFileStep extends ConsumerWidget {
  const ImportFileStep({required this.state, required this.onPick, super.key});

  final ImportState state;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final problem = state.problem;
    final groupId = state.groupId;
    final batches = groupId == null
        ? const <LocalImportBatch>[]
        : ref.watch(importBatchesProvider(groupId)).value ?? const <LocalImportBatch>[];
    return StepBody(
      question: l.impFileQuestion,
      children: [
        ImportCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, line) in [l.impHow1, l.impHow2, l.impHow3].indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s4),
                _HowRow(number: i + 1, text: line),
              ],
            ],
          ),
        ),
        if (problem != null) ...[
          const SizedBox(height: AppSpacing.s5),
          ImportCard(
            key: const Key('import-error'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImportIconBadge(icon: AppIcons.warning, color: c.oweText),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.impErrTitle, style: context.text.title),
                      if (state.fileName != null) ...[
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          state.fileName!,
                          style: context.text.bodySmall.copyWith(color: c.textSecondary),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s2),
                      Text(importProblemText(l, problem), style: context.text.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('import-pick'),
          label: problem == null ? l.impChooseFile : l.impChooseAnother,
          icon: AppIcons.fileCsv,
          onPressed: onPick,
        ),
        if (batches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s8),
          SectionLabel(l.impEarlier),
          const SizedBox(height: AppSpacing.s2),
          for (final (i, b) in batches.indexed)
            _BatchRow(batch: b, showDivider: i < batches.length - 1),
        ],
      ],
    );
  }
}

class _HowRow extends StatelessWidget {
  const _HowRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: MediaQuery.textScalerOf(context).scale(28),
          height: MediaQuery.textScalerOf(context).scale(28),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: context.text.bodySmall.w(700).copyWith(color: c.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(child: Text(text, style: context.text.body)),
      ],
    );
  }
}

class _BatchRow extends ConsumerWidget {
  const _BatchRow({required this.batch, required this.showDivider});

  final LocalImportBatch batch;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final when = DateTime.tryParse(batch.createdAt)?.toLocal();
    return DashedListRow(
      key: Key('import-batch-${batch.id}'),
      icon: AppIcons.fileCsv,
      label: batch.fileName ?? l.impTitle,
      value: when == null ? null : l.impBatchWhen(importDate(when)),
      showDivider: showDivider,
      onTap: () => unawaited(_delete(context, ref)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await confirmAction(
      context,
      title: l.impDeleteTitle,
      body: l.impDeleteBody,
      confirm: l.impDeleteImport,
      icon: AppIcons.trash,
    );
    if (!ok) return;
    await ref.read(importRepositoryProvider).deleteBatch(batch.id);
    if (context.mounted) showGroupMessage(context, l.impDeleted);
  }
}
