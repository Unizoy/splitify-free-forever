import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// While the records are written: the stacked-cards loader (07 §2 loading states) with a count.
class ImportRunningStep extends StatelessWidget {
  const ImportRunningStep({required this.state, super.key});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: StackedCardsLoader(
          key: const Key('import-running'),
          title: l.impRunning,
          message: l.impRunningCount(state.done, state.total),
          cards: [
            (
              seed: state.fileName ?? 'import',
              family: CoverFamily.trip,
              caption: state.fileName ?? '',
            ),
            for (final (i, e) in (state.preview?.result?.expenses ?? const []).take(2).indexed)
              (
                seed: '${e.row}-${e.description}',
                family: CoverFamily.values[(i + 1) % 4],
                caption: e.description,
              ),
          ],
        ),
      ),
    );
  }
}

/// Result: celebration, what came in, "Not synced yet" until the server has it, then the deleted
/// state after "Delete this import".
class ImportDoneStep extends ConsumerWidget {
  const ImportDoneStep({required this.state, required this.groupName, super.key});

  final ImportState state;
  final String groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final r = state.result!;
    final unsynced = ref.watch(groupUnsyncedProvider(r.groupId)).value ?? false;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.s6,
        AppSpacing.screen,
        AppSpacing.s8,
      ),
      children: [
        if (state.deleted)
          EmptyState(
            key: const Key('import-deleted'),
            icon: AppIcons.trash,
            title: l.impDeleted,
            message: l.impDeletedBody,
          )
        else ...[
          ClipRRect(
            borderRadius: AppRadii.all24,
            child: SizedBox(
              height: 320,
              child: Celebration(
                key: const Key('import-done'),
                lead: l.impDoneLead,
                highlight: l.impDoneHighlight,
                seed: r.batchId,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            l.impDoneBody(
              l.impCountExpenses(r.expenses),
              l.impCountPayments(r.payments),
              groupName,
            ),
            textAlign: TextAlign.center,
            style: context.text.body.copyWith(color: c.textSecondary),
          ),
          if (unsynced) ...[
            const SizedBox(height: AppSpacing.s3),
            const Center(child: SyncMarker(key: Key('import-sync-marker'))),
          ],
        ],
      ],
    );
  }
}
