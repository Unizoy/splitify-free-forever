import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show SectionLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The trip ends before it starts (both set).
bool tripDatesInvalid(DateTime? start, DateTime? end) =>
    start != null && end != null && end.isBefore(start);

/// "Sat, 12 Dec" (+ the year when it is not [today]'s), never split across lines.
String formDay(BuildContext context, DateTime d, DateTime today) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat(
    d.year == today.year ? 'EEE, d MMM' : 'EEE, d MMM y',
    locale,
  ).format(d).replaceAll(' ', ' ');
}

/// Trip dates on the group form (D-034 C4): "Starts" and "Ends" rows that each open a calendar sheet. No end
/// date simply means no end; the end before the start shows an inline error and keeps both dates.
class TripDatesRows extends StatelessWidget {
  const TripDatesRows({
    required this.start,
    required this.end,
    required this.today,
    required this.onStart,
    required this.onEnd,
    super.key,
  });

  final DateTime? start;
  final DateTime? end;
  final DateTime today;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final invalid = tripDatesInvalid(start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.tripDatesTitle),
        DashedListRow(
          key: const Key('trip-start'),
          icon: AppIcons.calendar,
          label: l.tripStarts,
          value: start == null ? l.tripNotSet : formDay(context, start!, today),
          valueColor: start == null ? c.textSecondary : null,
          onTap: onStart,
        ),
        DashedListRow(
          key: const Key('trip-end'),
          icon: AppIcons.calendar,
          label: l.tripEnds,
          value: end == null ? l.tripNoEnd : formDay(context, end!, today),
          valueColor: end == null ? c.textSecondary : (invalid ? c.oweText : null),
          showDivider: false,
          onTap: onEnd,
        ),
        if (invalid)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: Text(
                l.tripEndBeforeStart,
                key: const Key('trip-error'),
                style: context.text.bodySmall.w(600).copyWith(color: c.oweText),
              ),
            ),
          ),
        Text(l.tripDatesHint, style: context.text.bodySmall.copyWith(color: c.textSecondary)),
      ],
    );
  }
}

/// "Settle-up reminders: Off · Weekly · Monthly" on the group form (D-034 C4, any group type): one tap, with
/// what it does and the next day a reminder would go out ([nextSettleNudge], the server's rules).
class SettleReminderRow extends StatelessWidget {
  const SettleReminderRow({
    required this.value,
    required this.today,
    required this.createdDay,
    required this.onChanged,
    this.tripEndsOn,
    super.key,
  });

  final SettleReminder value;
  final DateTime today;

  /// Weekly reminders go out on this day's weekday.
  final DateTime createdDay;

  /// The trip's last day (the day after it, a reminder goes out whatever the setting).
  final DateTime? tripEndsOn;
  final ValueChanged<SettleReminder> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hint = switch (value) {
      SettleReminder.off => l.nudgeHintOff,
      SettleReminder.weekly => l.nudgeHintWeekly(DateFormat.EEEE(locale).format(createdDay)),
      SettleReminder.monthly => l.nudgeHintMonthly,
    };
    final next = nextSettleNudge(
      reminder: value,
      today: today,
      createdDay: createdDay,
      tripEndsOn: tripEndsOn,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.s6),
        SectionLabel(l.nudgeTitle),
        const SizedBox(height: AppSpacing.s3),
        SegmentedPill<SettleReminder>(
          key: const Key('group-reminder'),
          value: value,
          onChanged: onChanged,
          items: [
            SegmentedPillItem(value: SettleReminder.off, label: l.nudgeOff),
            SegmentedPillItem(value: SettleReminder.weekly, label: l.nudgeWeekly),
            SegmentedPillItem(value: SettleReminder.monthly, label: l.nudgeMonthly),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          hint,
          key: const Key('group-reminder-hint'),
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
        if (next != null)
          Text(
            l.nudgeNext(formDay(context, next.day, today)),
            key: const Key('group-reminder-next'),
            style: context.text.bodySmall.w(600).copyWith(color: c.textPrimary),
          ),
      ],
    );
  }
}
