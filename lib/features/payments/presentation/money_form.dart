import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/features/expenses/presentation/editor/pickers.dart' show MonthCalendar;
import 'package:splitify/features/expenses/presentation/expense_copy.dart';
import 'package:splitify/features/friends/presentation/friend_widgets.dart' show groupTypeIcon;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Pieces the one-screen payment and loan forms share with the one-screen add expense (D-032, D-033):
/// the first "In [group]" row, a summary pill, the date and text sheets the toolbar chips open.

/// "In" + the group chip (the editor's "With you and" row): where the payment or loan goes. Offline, a
/// "Not synced yet" marker sits next to it.
class GroupLine extends StatelessWidget {
  const GroupLine({required this.name, required this.type, required this.offline, super.key});

  final String name;

  /// `trip`, `home`, `couple`, `direct` or `other` (the chip's icon).
  final String type;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.moneyInLabel, style: context.text.body.copyWith(color: c.textSecondary)),
        Semantics(
          key: const Key('money-group'),
          container: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.s1,
              AppSpacing.s1,
              AppSpacing.s4,
              AppSpacing.s1,
            ),
            decoration: ShapeDecoration(
              color: c.surface,
              shape: StadiumBorder(side: BorderSide(color: c.border, width: 1.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TintedIcon(icon: groupTypeIcon(type), color: c.primary, size: 32),
                const SizedBox(width: AppSpacing.s2),
                Flexible(child: Text(name, style: context.text.body.w(600))),
              ],
            ),
          ),
        ),
        // Offline: what is saved now stays on this phone until it syncs (rule 3).
        if (offline) const SyncMarker(key: Key('money-offline')),
      ],
    );
  }
}

/// A summary pill under the amount (like "Paid by You · split equally"): an icon, a bold line and a
/// quieter one; red edge when [error]. With [onTap] it opens a sheet; [trailing] holds a small action.
class FormPill extends StatelessWidget {
  const FormPill({
    required this.icon,
    required this.title,
    this.subtitle,
    this.error = false,
    this.onTap,
    this.hint,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool error;
  final VoidCallback? onTap;

  /// What a tap does (spoken).
  final String? hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sub = subtitle;
    final body = AnimatedContainer(
      duration: context.motion.fast,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s3,
        AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: AppRadii.all24,
        border: Border.all(color: error ? c.oweText : AppPalette.clear, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: c.onPrimaryContainer),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const Key('form-pill-title'),
                  style: context.text.body.w(700).copyWith(color: c.onPrimaryContainer),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    key: const Key('form-pill-subtitle'),
                    style: context.text.bodySmall
                        .w(600)
                        .copyWith(
                          color: error ? c.oweText : c.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.s2), trailing!],
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.s2),
            Icon(AppIcons.chevronRight, size: 18, color: c.onPrimaryContainer),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(container: true, liveRegion: true, child: body);
    }
    return Semantics(
      button: true,
      label: title,
      value: sub,
      hint: hint,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(onTap: onTap, borderRadius: AppRadii.all24, child: body),
    );
  }
}

/// "Today", "Yesterday", "21 Nov" (this year) or "21 Nov 2025" for a toolbar date chip.
String dayLabel(BuildContext context, DateTime day, DateTime today) {
  final l = AppLocalizations.of(context);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (DateUtils.isSameDay(day, today)) return l.expToday;
  if (DateUtils.isSameDay(day, yesterday)) return l.expYesterday;
  return day.year == today.year ? dayMonth(context, day) : shortDate(context, day);
}

/// The date sheet of the toolbar date chip (Today / Yesterday chips over a month calendar); the picked
/// day, or null when closed.
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime value,
  required DateTime today,
}) {
  final l = AppLocalizations.of(context);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  return showAppSheet<DateTime>(
    context,
    title: l.expPickDate,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            IconChip(
              key: const Key('date-today'),
              label: l.expToday,
              selected: DateUtils.isSameDay(value, today),
              onTap: () => Navigator.of(sheet).pop(today),
            ),
            IconChip(
              key: const Key('date-yesterday'),
              label: l.expYesterday,
              selected: DateUtils.isSameDay(value, yesterday),
              onTap: () => Navigator.of(sheet).pop(yesterday),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s5),
        MonthCalendar(
          initial: value,
          today: today,
          onPicked: (day) => Navigator.of(sheet).pop(day),
        ),
      ],
    ),
  );
}

/// A sheet with one text field (the toolbar's note chip): typed text goes straight to [onChanged], so
/// closing it never loses anything; "Done" closes it.
Future<void> showTextSheet(
  BuildContext context, {
  required String title,
  required Key fieldKey,
  required String label,
  required String hint,
  required TextEditingController controller,
  required int max,
  required String tooLong,
  required ValueChanged<String> onChanged,
}) {
  final l = AppLocalizations.of(context);
  return showAppSheet<void>(
    context,
    title: title,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => UnderlineField(
              key: fieldKey,
              label: label,
              hint: hint,
              controller: controller,
              autofocus: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              errorText: value.text.trim().length > max ? tooLong : null,
              inputFormatters: [LengthLimitingTextInputFormatter(max + 50)],
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          PillButton(
            key: const Key('text-sheet-done'),
            label: l.loanAmountDone,
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
      ),
    ),
  );
}
