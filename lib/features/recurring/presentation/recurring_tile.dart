import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart' show shortDate;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show confirmAction;
import 'package:splitify/features/recurring/application/recurring_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Route of "Edit future copies" (the expense editor on a template).
String recurringEditRoute(String templateId) => '/recurring/$templateId/edit';

/// "Repeats · Every month" on the expense detail (#12): tap for the repeat sheet (next copy, end date,
/// Edit future copies, Stop repeating / Repeat again). Shown for the expense a template was started
/// from and for every copy; nothing when the expense does not repeat.
class RecurringTile extends ConsumerWidget {
  const RecurringTile({
    required this.expenseId,
    required this.recurringId,
    this.readOnly = false,
    super.key,
  });

  final String expenseId;

  /// The copy's template (`expenses.recurring_id`), if it is a copy.
  final String? recurringId;

  /// Archived group: the sheet shows the rule without actions.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = ref
        .watch(expenseRecurringProvider((expenseId: expenseId, recurringId: recurringId)))
        .value;
    if (t == null) return const SizedBox.shrink();
    final value = t.repeating
        ? intervalLabel(l, t.repeatInterval)
        : (t.active ? l.recurringFinished : l.recurringStoppedValue);
    return DashedListRow(
      key: const Key('expense-recurring'),
      icon: AppIcons.repeat,
      label: l.recurringRowLabel,
      value: value,
      valueColor: t.repeating ? null : context.colors.textSecondary,
      onTap: () => unawaited(showRecurringSheet(context, t, readOnly: readOnly)),
    );
  }
}

/// The repeat sheet of [t].
Future<void> showRecurringSheet(BuildContext context, LocalRecurring t, {bool readOnly = false}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<void>(
    context,
    title: t.active ? intervalLabel(l, t.repeatInterval) : l.recurringStop,
    builder: (sheet) => _RecurringSheet(templateId: t.id, readOnly: readOnly),
  );
}

class _RecurringSheet extends ConsumerWidget {
  const _RecurringSheet({required this.templateId, required this.readOnly});

  final String templateId;
  final bool readOnly;

  Future<void> _stop(BuildContext context, WidgetRef ref, LocalRecurring t) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final description = t.title;
    final yes = await confirmAction(
      context,
      title: l.recurringStopTitle(description),
      body: l.recurringStopBody,
      confirm: l.recurringStop,
      icon: AppIcons.close,
    );
    if (!yes) return;
    await ref.read(recurringActionsProvider).stop(t);
    unawaited(HapticFeedback.mediumImpact());
    if (navigator.canPop()) navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.recurringStoppedSnack)));
  }

  Future<void> _resume(BuildContext context, WidgetRef ref, LocalRecurring t) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref.read(recurringActionsProvider).resume(t);
    if (navigator.canPop()) navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.recurringResumedSnack)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = ref.watch(recurringTemplateProvider(templateId)).value;
    if (t == null) return const SizedBox(height: AppSpacing.s12);
    final next = t.nextCopy;
    final end = t.endDate;
    final lines = <(IconData, String)>[
      if (!t.active)
        (AppIcons.info, l.recurringStoppedLine)
      else if (next != null)
        (AppIcons.calendar, l.recurringNext(shortDate(context, localDate(next))))
      else
        (AppIcons.info, l.recurringFinished),
      (
        AppIcons.clock,
        end == null ? l.recurringNoEnd : l.recurringEndsOn(shortDate(context, localDate(end))),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t.unsynced) ...[
          const Align(alignment: Alignment.centerLeft, child: SyncMarker()),
          const SizedBox(height: AppSpacing.s3),
        ],
        for (final (icon, text) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            child: Row(
              children: [
                Icon(icon, size: 20, color: c.textSecondary),
                const SizedBox(width: AppSpacing.s3),
                Expanded(child: Text(text, style: context.text.body)),
              ],
            ),
          ),
        if (!readOnly) ...[
          const SizedBox(height: AppSpacing.s6),
          if (t.active) ...[
            PillButton(
              key: const Key('recurring-edit-future'),
              label: l.recurringEditFuture,
              icon: AppIcons.edit,
              variant: PillVariant.outline,
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                unawaited(router.push(recurringEditRoute(t.id)));
              },
            ),
            const SizedBox(height: AppSpacing.s2),
            PillButton(
              key: const Key('recurring-stop'),
              label: l.recurringStop,
              variant: PillVariant.ghost,
              onPressed: () => unawaited(_stop(context, ref, t)),
            ),
          ] else
            PillButton(
              key: const Key('recurring-resume'),
              label: l.recurringResume,
              icon: AppIcons.repeat,
              onPressed: () => unawaited(_resume(context, ref, t)),
            ),
        ],
      ],
    );
  }
}
