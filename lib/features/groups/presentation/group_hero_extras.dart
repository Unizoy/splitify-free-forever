import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/features/balances/application/balance_views.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart';
import 'package:splitify/features/groups/application/group_extras_providers.dart';
import 'package:splitify/features/groups/domain/group_extras.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Lines shown before "+N more" (D-034 C1).
const groupLinesShown = 3;

/// "12–18 Dec", "28 Nov – 3 Dec", "28 Dec 2026 – 3 Jan 2027", "From 12 Dec", "Until 18 Dec" (years only when
/// they differ from each other or from [today]'s). Null when neither day is set.
String? tripDatesText(BuildContext context, DateTime? start, DateTime? end, DateTime today) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  String day(DateTime d, {bool month = true, bool year = false}) => DateFormat(
    year
        ? 'd MMM y'
        : month
        ? 'd MMM'
        : 'd',
    locale,
  ).format(d).replaceAll(' ', ' ');
  if (start == null && end == null) return null;
  if (start == null) return l.tripUntil(day(end!, year: end.year != today.year));
  if (end == null) return l.tripFrom(day(start, year: start.year != today.year));
  final years = start.year != end.year || start.year != today.year;
  if (years) return l.tripRange(day(start, year: true), day(end, year: true));
  if (start.month == end.month) {
    if (start.day == end.day) return day(start);
    return l.tripRange(day(start, month: false), day(end));
  }
  return l.tripRange(day(start), day(end));
}

/// The group page's "who owes whom" from my side, under the status pill (D-034 C1): up to
/// [groupLinesShown] lines ("Asha owes you ₹200", "You owe Rahul ₹100", main currency first, simplified
/// when simplify is on — the Balances tab's rows exactly), "+N more" to the Balances tab, the "not synced
/// yet" marker for pending rows, and a chevron beside the pill that folds them away (remembered per group on
/// this phone).
class GroupBalanceLines extends ConsumerWidget {
  const GroupBalanceLines({
    required this.balances,
    required this.pill,
    required this.onMore,
    super.key,
  });

  final GroupBalances? balances;

  /// The status pill the lines belong to.
  final Widget pill;

  /// Opens the Balances tab.
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = balances;
    final lines = b == null ? const <BalanceLine>[] : myBalanceLines(b);
    if (b == null || lines.isEmpty) return pill;
    final l = AppLocalizations.of(context);
    final c = context.colors;
    // Short phones start folded (session only); taller ones keep the choice stored on this phone.
    final short = MediaQuery.sizeOf(context).height < 700;
    final collapsed = short
        ? !ref.watch(groupLinesOpenedShortProvider(b.groupId))
        : ref.watch(groupLinesCollapsedProvider(b.groupId));
    void toggleLines() => short
        ? ref.read(groupLinesOpenedShortProvider(b.groupId).notifier).toggle()
        : ref.read(groupLinesCollapsedProvider(b.groupId).notifier).toggle();
    final toggle = Semantics(
      button: true,
      expanded: !collapsed,
      label: collapsed ? l.groupLinesShow : l.groupLinesHide,
      excludeSemantics: true,
      onTap: toggleLines,
      child: Pressable(
        key: const Key('group-lines-toggle'),
        onTap: toggleLines,
        circle: true,
        scale: 0.9,
        child: SizedBox.square(
          dimension: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.onHero.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: AnimatedRotation(
                turns: collapsed ? 0 : 0.5,
                duration: AppMotion.of(context).fast,
                child: Icon(AppIcons.chevronDown, size: 16, color: c.onHero),
              ),
            ),
          ),
        ),
      ),
    );
    // Short phones (< 700 dp tall) show one line and "+N more", so the list still shows below the hero
    // (R3-A, S-446).
    final shown = lines.take(groupLinesShown).toList();
    final more = lines.length - shown.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Balances the chevron so the pill stays centred.
            const SizedBox(width: AppSpacing.minTouch - AppSpacing.s1),
            Flexible(child: pill),
            const SizedBox(width: AppSpacing.s1),
            toggle,
          ],
        ),
        // Like the pill, the lines keep the hero readable at 200 % text (06 §4).
        // Who owes whom folds open from the top and fades in (S-451).
        AppExpand(
          open: !collapsed,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: AppText.maxSerifScale,
            child: Column(
              key: const Key('group-lines'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.s1),
                for (final line in shown) _Line(balances: b, line: line),
                if (more > 0) _MoreLink(label: l.groupLinesMore(more), onTap: onMore),
                if (b.unsynced) ...[const SizedBox(height: AppSpacing.s2), const _HeroSyncMarker()],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.balances, required this.line});

  final GroupBalances balances;
  final BalanceLine line;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final b = balances;
    final who = personName(l, b, line.other, start: !line.iOwe);
    final words = line.iOwe ? l.balYouOwePerson(who) : l.balPairOwes(who, l.youLower);
    final amount = listMoney(line.amount, line.currency);
    return Padding(
      key: Key('group-line-${line.currency}-${line.other}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$words '),
            // The amount on its own dark chip, like the status pill above: coral or lime straight on the
            // lavender hero was about 2:1 (R3-A, S-445).
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 1),
                decoration: BoxDecoration(
                  color: line.iOwe ? c.chipDarkRed : c.chipDarkGreen,
                  borderRadius: AppRadii.allPill,
                ),
                child: Text(
                  amount,
                  style: context.text.body
                      .w(700)
                      .copyWith(
                        color: line.iOwe ? c.onChipDarkRed : c.onChipDarkGreen,
                        fontFeatures: AppText.tabularFigures,
                      ),
                ),
              ),
            ),
          ],
        ),
        semanticsLabel: [words, amount].join(' '),
        textAlign: TextAlign.center,
        style: context.text.body.copyWith(color: c.onHero),
      ),
    );
  }
}

class _MoreLink extends StatelessWidget {
  const _MoreLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: Pressable(
      key: const Key('group-lines-more'),
      onTap: onTap,
      borderRadius: AppRadii.allPill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: context.text.bodySmall
                  .w(700)
                  .copyWith(
                    color: context.colors.onHero,
                    decoration: TextDecoration.underline,
                    decorationColor: context.colors.onHero,
                  ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Not synced yet" on a light pill so it reads over the hero.
class _HeroSyncMarker extends StatelessWidget {
  const _HeroSyncMarker();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('group-lines-sync'),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
    decoration: BoxDecoration(color: context.colors.bg, borderRadius: AppRadii.allPill),
    child: const SyncMarker(),
  );
}

/// Small glass chips under the members on the group page (D-034 C4/C5): the trip dates ("12–18 Dec") and,
/// when the group has notes, "Notes" (opens them). Nothing when neither applies.
class GroupHeroChips extends StatelessWidget {
  const GroupHeroChips({
    required this.group,
    required this.today,
    required this.onNotes,
    super.key,
  });

  final LocalGroup group;
  final DateTime today;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dates = group.type == 'trip'
        ? tripDatesText(context, parseDay(group.tripStartsOn), parseDay(group.tripEndsOn), today)
        : null;
    final notes = (group.whiteboard ?? '').trim().isNotEmpty;
    if (dates == null && !notes) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: AppText.maxSerifScale,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s2,
          children: [
            if (dates != null)
              Semantics(
                label: l.tripChipLabel(dates),
                excludeSemantics: true,
                child: StatusPill(
                  key: const Key('group-trip-dates'),
                  label: dates,
                  icon: AppIcons.calendar,
                  tone: StatusPillTone.glass,
                ),
              ),
            if (notes)
              Semantics(
                button: true,
                label: l.boardOpen,
                excludeSemantics: true,
                onTap: onNotes,
                child: Pressable(
                  key: const Key('group-notes-chip'),
                  onTap: onNotes,
                  borderRadius: AppRadii.allPill,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: StatusPill(
                        label: l.boardChip,
                        icon: AppIcons.notes,
                        tone: StatusPillTone.glass,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
