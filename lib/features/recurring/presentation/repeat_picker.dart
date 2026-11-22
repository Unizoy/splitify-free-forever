import 'dart:async';

import 'package:flutter/material.dart';
import 'package:splitify/domain/rules/recurrence.dart';
import 'package:splitify/features/expenses/presentation/editor/details_step.dart'
    show MonthCalendar;
import 'package:splitify/features/expenses/presentation/editor/step_body.dart' show SectionLabel;
import 'package:splitify/features/expenses/presentation/expense_copy.dart' show shortDate;
import 'package:splitify/features/recurring/application/recurring_providers.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Repeat" on the expense details (#12, TC-12-04): Never · Every week · Every 2 weeks · Every month ·
/// Every year as chips, then "Ends" (No end date · a date from the calendar sheet) and a hint with the
/// first copy. [allowNever] is off when editing future copies (Stop repeating lives on the expense).
class RepeatPicker extends StatelessWidget {
  const RepeatPicker({
    required this.value,
    required this.start,
    required this.today,
    required this.onChanged,
    this.allowNever = true,
    super.key,
  });

  final RepeatDraft value;

  /// The expense date (the first date of the series).
  final DateTime start;

  /// The device's local calendar day (the first copy is never before it).
  final DateTime today;
  final ValueChanged<RepeatDraft> onChanged;
  final bool allowNever;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final end = value.endsOn;
    final rule = value.ruleFrom(start);
    final first = rule == null ? null : firstCopyFrom(rule, today);
    final String? hint;
    final bool problem = value.endsBefore(start);
    if (!value.repeats) {
      hint = null;
    } else if (problem) {
      hint = l.repeatEndBeforeStart(shortDate(context, start));
    } else if (first == null) {
      hint = l.repeatNoCopiesHint;
    } else {
      hint = l.repeatNextHint(shortDate(context, localDate(first)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            if (allowNever)
              IconChip(
                key: const Key('repeat-never'),
                label: l.repeatNever,
                selected: !value.repeats,
                onTap: () => onChanged(value.withInterval(null)),
              ),
            for (final i in RecurrenceInterval.values)
              IconChip(
                key: Key('repeat-${i.key}'),
                label: intervalLabel(l, i),
                icon: value.interval == i ? AppIcons.repeat : null,
                selected: value.interval == i,
                onTap: () => onChanged(value.withInterval(i)),
              ),
          ],
        ),
        if (value.repeats) ...[
          const SizedBox(height: AppSpacing.s6),
          SectionLabel(l.repeatEndsLabel),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              IconChip(
                key: const Key('repeat-no-end'),
                label: l.repeatNoEnd,
                selected: end == null,
                onTap: () => onChanged(value.withEnd(null)),
              ),
              IconChip(
                key: const Key('repeat-end-pick'),
                label: end == null ? l.repeatPickEnd : l.repeatUntil(shortDate(context, end)),
                icon: AppIcons.calendar,
                selected: end != null,
                onTap: () => unawaited(_pickEnd(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                problem ? AppIcons.warning : AppIcons.repeat,
                size: 18,
                color: problem ? c.oweText : c.textSecondary,
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  hint!,
                  key: const Key('repeat-hint'),
                  style: context.text.bodySmall.copyWith(
                    color: problem ? c.oweText : c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickEnd(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final initial = value.endsOn ?? (start.isAfter(today) ? start : today);
    final picked = await showAppSheet<DateTime>(
      context,
      title: l.repeatPickEnd,
      builder: (sheet) => MonthCalendar(
        initial: initial,
        today: today,
        onPicked: (d) => Navigator.of(sheet).pop(d),
      ),
    );
    if (picked != null) onChanged(value.withEnd(picked));
  }
}
