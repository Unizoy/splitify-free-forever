import 'package:flutter/material.dart';
import 'package:splitify/core/money/money_formatter.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart' show StepBody;
import 'package:splitify/features/groups/presentation/group_visuals.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';
import 'package:splitify/features/import_splitwise/domain/splitwise_csv_parser.dart' show TotalsMismatch;
import 'package:splitify/features/import_splitwise/domain/splitwise_reconstruction.dart';
import 'package:splitify/features/import_splitwise/presentation/import_copy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Preview: what will be written (counts, dates), the check against the file's "Total balance" rows
/// (mismatch → warning + "Import anyway"), notes on rows left out, and everyone's balance after.
class ImportPreviewStep extends StatelessWidget {
  const ImportPreviewStep({required this.state, required this.onAcceptMismatch, super.key});

  final ImportState state;
  final ValueChanged<bool> onAcceptMismatch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final preview = state.preview!;
    final result = preview.result!;
    final dates = [for (final e in result.expenses) e.date, for (final p in result.payments) p.date]
      ..sort();
    final mismatches = state.mismatches;
    final checked = preview.file.totals.isNotEmpty;
    final netsRows = result.expenses.where((e) => e.kind == ImportedExpenseKind.nets).length;
    final skippedPeople = {
      for (final e in state.mapping.entries)
        if (e.value is SkipPerson) e.key,
    };
    return StepBody(
      question: l.impPreviewQuestion,
      children: [
        ImportCard(
          key: const Key('import-summary'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ImportIconBadge(icon: AppIcons.fileCsv, color: c.primary),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.fileName ?? l.impTitle, style: context.text.title),
                        if (dates.isNotEmpty)
                          Text(
                            l.impDateRange(importDate(dates.first), importDate(dates.last)),
                            style: context.text.bodySmall.copyWith(color: c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s5),
              const DashedDivider(),
              const SizedBox(height: AppSpacing.s5),
              StatGrid(
                stats: [
                  (value: '${result.expenses.length}', label: l.impStatExpenses),
                  (value: '${result.payments.length}', label: l.impStatPayments),
                  (value: '${result.members.length}', label: l.impStatPeople),
                ],
                valueColor: c.textPrimary,
                labelColor: c.textSecondary,
                columns: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        _TotalsCheck(checked: checked, mismatches: mismatches),
        if (mismatches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s2),
          ToggleRow(
            key: const Key('import-anyway'),
            title: l.impImportAnyway,
            subtitle: l.impImportAnywaySub,
            value: state.acceptMismatch,
            onChanged: onAcceptMismatch,
            showDivider: false,
          ),
        ],
        for (final note in [
          if (preview.dropped > 0) l.impDropped(preview.dropped),
          if (result.skipped.isNotEmpty) l.impZeroRows(result.skipped.length),
          if (netsRows > 0) l.impNetsRows(netsRows),
        ]) ...[
          const SizedBox(height: AppSpacing.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(AppIcons.info, size: 18, color: c.textSecondary),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(note, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        SectionLabel(l.impBalancesAfter),
        const SizedBox(height: AppSpacing.s2),
        for (final (i, name) in preview.file.members.indexed)
          if (!skippedPeople.contains(name))
            AmountRow(
              key: Key('import-net-$name'),
              title: name,
              caption: _target(l, name),
              amountText: importNetsLine(l, result.nets, name) ?? l.impNetZero,
              leading: Avatar(name: name, seed: 'import-$name'),
              showDivider: i < preview.file.members.length - 1,
            ),
      ],
    );
  }

  String? _target(AppLocalizations l, String name) => switch (state.mapping[name]) {
    UseMember(:final memberId) => () {
      final m = state.members.where((m) => m.id == memberId).firstOrNull;
      return m == null ? null : (m.isMe ? l.you : m.name);
    }(),
    NewMember() => l.impChoiceNew,
    _ => null,
  };
}

class _TotalsCheck extends StatelessWidget {
  const _TotalsCheck({required this.checked, required this.mismatches});

  final bool checked;
  final List<TotalsMismatch> mismatches;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final ok = checked && mismatches.isEmpty;
    final color = !checked ? c.textSecondary : (ok ? c.owedText : c.oweText);
    final title = !checked ? l.impTotalsNone : (ok ? l.impTotalsOk : l.impTotalsMismatch);
    return ImportCard(
      key: Key(
        ok ? 'import-totals-ok' : (checked ? 'import-totals-mismatch' : 'import-totals-none'),
      ),
      padding: AppSpacing.s4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                ImportIconBadge(
                  icon: ok ? AppIcons.checkCircle : (checked ? AppIcons.warning : AppIcons.info),
                  color: color,
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.impTotalsTitle.toUpperCase(),
                        style: context.text.labelCaps.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(title, style: context.text.title.copyWith(color: color)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final m in mismatches.take(6)) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(
              l.impMismatchRow(
                m.member,
                MoneyFormatter.list.format(m.fileTotal, m.currency),
                MoneyFormatter.list.format(m.rowsTotal, m.currency),
              ),
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
