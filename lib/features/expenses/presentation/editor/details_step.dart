import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:splitify/domain/rules/expense_categories.dart';
import 'package:splitify/features/expenses/application/expense_draft.dart';
import 'package:splitify/features/expenses/application/receipt_draft.dart';
import 'package:splitify/features/expenses/presentation/editor/receipt_field.dart';
import 'package:splitify/features/expenses/presentation/editor/step_body.dart';
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/recurring/application/repeat_draft.dart';
import 'package:splitify/features/recurring/presentation/repeat_picker.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Step 4 "A few details": category (parent → sub IconChips), date (today / yesterday / calendar
/// sheet like 534), repeat (#12), notes and the receipt photo (#29). Editing future copies of a
/// repeating expense shows its first date read-only and no receipt.
class DetailsStep extends StatelessWidget {
  const DetailsStep({
    required this.draft,
    required this.today,
    required this.notes,
    required this.onCategory,
    required this.onDate,
    required this.onNotes,
    this.onReceipt,
    this.onRepeat,
    super.key,
  });

  final ExpenseDraft draft;

  /// The device's local calendar day.
  final DateTime today;
  final TextEditingController notes;
  final ValueChanged<String> onCategory;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<String> onNotes;

  /// Receipt changes; null hides the receipt section.
  final ValueChanged<ReceiptDraft>? onReceipt;

  /// Repeat changes; null hides the repeat section.
  final ValueChanged<RepeatDraft>? onRepeat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tooLong = draft.notes.trim().length > maxNotes;
    return StepBody(
      question: l.expDetailsQuestion,
      children: [
        SectionLabel(l.expCategoryLabel),
        CategoryPicker(value: draft.category, onChanged: onCategory),
        const SizedBox(height: AppSpacing.s8),
        if (draft.isTemplate) ...[
          DashedListRow(
            key: const Key('template-start'),
            icon: AppIcons.calendar,
            label: l.repeatStartsLabel,
            value: shortDate(context, draft.date),
            showDivider: false,
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.info, size: 18, color: context.colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  l.recurringEditNote,
                  key: const Key('template-note'),
                  style: context.text.bodySmall.copyWith(color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
        ] else ...[
          SectionLabel(l.expDateLabel),
          DateChips(value: draft.date, today: today, onChanged: onDate),
        ],
        if (onRepeat != null) ...[
          const SizedBox(height: AppSpacing.s8),
          SectionLabel(l.repeatLabel),
          RepeatPicker(
            value: draft.repeat,
            start: draft.date,
            today: today,
            allowNever: !draft.isTemplate,
            onChanged: onRepeat!,
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        UnderlineField(
          key: const Key('expense-notes'),
          label: l.expNotesLabel,
          hint: l.expNotesHint,
          controller: notes,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          errorText: tooLong ? l.expNotesTooLong : null,
          inputFormatters: [LengthLimitingTextInputFormatter(maxNotes + 50)],
          onChanged: onNotes,
        ),
        if (onReceipt != null) ...[
          const SizedBox(height: AppSpacing.s8),
          SectionLabel(l.receiptLabel),
          ReceiptField(receipt: draft.receipt, onChanged: onReceipt!),
        ],
      ],
    );
  }
}

/// Category picker (#13, TC-13-02): the 8 parents as coloured IconChips, then the chosen parent's
/// sub categories.
class CategoryPicker extends StatelessWidget {
  const CategoryPicker({required this.value, required this.onChanged, super.key});

  /// Selected `parent.sub` key.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final parent = ExpenseCategories.parentOf(value);
    final subs = ExpenseCategories.tree[parent]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final p in ExpenseCategories.tree.keys)
              IconChip(
                key: Key('category-$p'),
                label: l.category(p),
                icon: Category.values.byName(p).icon,
                iconColor: Category.values.byName(p).color,
                selected: p == parent,
                onTap: p == parent ? () {} : () => onChanged(ExpenseCategories.tree[p]!.first),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: context.colors.bgSubtle,
            borderRadius: AppRadii.all24,
            border: Border.all(color: context.colors.border),
          ),
          child: Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              for (final s in subs)
                IconChip(
                  key: Key('category-$s'),
                  label: l.category(s),
                  selected: s == value,
                  onTap: () => onChanged(s),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today · Yesterday · calendar chip (opens [MonthCalendar] in a sheet).
class DateChips extends StatelessWidget {
  const DateChips({required this.value, required this.today, required this.onChanged, super.key});

  final DateTime value;
  final DateTime today;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final isToday = DateUtils.isSameDay(value, today);
    final isYesterday = DateUtils.isSameDay(value, yesterday);
    final other = !isToday && !isYesterday;
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        IconChip(
          key: const Key('date-today'),
          label: l.expToday,
          selected: isToday,
          onTap: () => onChanged(today),
        ),
        IconChip(
          key: const Key('date-yesterday'),
          label: l.expYesterday,
          selected: isYesterday,
          onTap: () => onChanged(yesterday),
        ),
        IconChip(
          key: const Key('date-pick'),
          label: other ? shortDate(context, value) : l.expPickDate,
          icon: AppIcons.calendar,
          selected: other,
          onTap: () => unawaited(_pick(context)),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<DateTime>(
      context,
      title: l.expPickDate,
      builder: (sheet) =>
          MonthCalendar(initial: value, today: today, onPicked: (d) => Navigator.of(sheet).pop(d)),
    );
    if (picked != null) onChanged(picked);
  }
}

/// Month grid (534): month title with prev/next, weekday initials, days as 44 dp cells; the chosen
/// day is a filled indigo circle, today is bold indigo.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    required this.initial,
    required this.today,
    required this.onPicked,
    super.key,
  });

  final DateTime initial;
  final DateTime today;
  final ValueChanged<DateTime> onPicked;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final lead = (DateTime(_month.year, _month.month).weekday % 7 - firstWeekday + 7) % 7;
    final names = DateFormat.E(locale).dateSymbols.SHORTWEEKDAYS;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= days; d++) DateTime(_month.year, _month.month, d),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('MMMM y', locale).format(_month),
                style: context.text.title.w(700),
              ),
            ),
            AppIconButton(
              tooltip: l.expPrevMonth,
              onPressed: () => _shift(-1),
              icon: Icon(AppIcons.backChevron, size: 18, color: c.textPrimary),
            ),
            AppIconButton(
              tooltip: l.expNextMonth,
              onPressed: () => _shift(1),
              icon: Icon(AppIcons.chevronRight, size: 18, color: c.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    names[(firstWeekday + i) % 7],
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall.w(600).copyWith(color: c.textTertiary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Divider(height: 1, color: c.border),
        const SizedBox(height: AppSpacing.s2),
        for (var r = 0; r < (cells.length / 7).ceil(); r++)
          Row(
            children: [
              for (var i = r * 7; i < r * 7 + 7; i++)
                Expanded(
                  child: i < cells.length && cells[i] != null
                      ? _DayCell(
                          day: cells[i]!,
                          selected: DateUtils.isSameDay(cells[i], widget.initial),
                          today: DateUtils.isSameDay(cells[i], widget.today),
                          onTap: () => widget.onPicked(cells[i]!),
                        )
                      : const SizedBox(height: AppSpacing.minTouch),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.onPrimaryFill : (today ? c.primary : c.textPrimary);
    return Semantics(
      button: true,
      selected: selected,
      label: shortDate(context, day),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        circle: true,
        scale: 0.9,
        child: SizedBox(
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.primaryFill : AppPalette.clear,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: context.text.body.w(selected || today ? 700 : 500).copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
