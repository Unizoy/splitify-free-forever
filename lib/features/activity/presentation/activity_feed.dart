import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/features/activity/application/activity_providers.dart';
import 'package:splitify/features/balances/presentation/balance_copy.dart' show listMoney;
import 'package:splitify/features/expenses/presentation/expense_routes.dart';
import 'package:splitify/features/payments/presentation/payment_routes.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// The sentence of one activity row ("Rahul added “Dinner”"), from the ARB templates (#18).
String activitySentence(AppLocalizations l, ActivityItem i) {
  String who(ActivityPerson? p, {bool start = false}) {
    if (p == null) return l.someone;
    if (p.isMe) return start ? l.you : l.youLower;
    return p.name.isEmpty ? l.someone : p.name;
  }

  final a = who(i.actor, start: true);
  final d = i.description ?? '';
  final m = who(i.member);
  final from = who(i.from);
  final to = who(i.to);
  return switch (i.type) {
    'group_created' => l.actGroupCreated(a),
    'group_updated' => l.actGroupUpdated(a),
    'group_archived' => l.actGroupArchived(a),
    'group_unarchived' => l.actGroupUnarchived(a),
    'group_deleted' => l.actGroupDeleted(a),
    'group_restored' => l.actGroupRestored(a),
    'member_added' => l.actMemberAdded(a, m),
    'member_joined' => l.actMemberJoined(a),
    'member_claimed' => l.actMemberClaimed(a, m),
    'member_left' => l.actMemberLeft(who(i.member, start: true)),
    'member_removed' => l.actMemberRemoved(a, m),
    'expense_added' => l.actExpenseAdded(a, d),
    'expense_edited' => l.actExpenseEdited(a, d),
    'expense_deleted' => l.actExpenseDeleted(a, d),
    'expense_restored' => l.actExpenseRestored(a, d),
    // "You paid Asha" when the payer recorded it, else who recorded it.
    'payment_added' when i.from != null && i.from!.seed == i.actor.seed => l.settlePaidSentence(
      who(i.from, start: true),
      to,
    ),
    'payment_added' => l.actPaymentAdded(a, from, to),
    'payment_edited' => l.actPaymentEdited(a, from, to),
    'payment_deleted' => l.actPaymentDeleted(a, from, to),
    'payment_restored' => l.actPaymentRestored(a, from, to),
    'comment_added' => d.isEmpty ? l.actCommentAdded(a) : l.actCommentOn(a, d),
    'comment_deleted' => l.actCommentDeleted(a),
    'reminder_sent' => l.actReminderSent(a),
    'settings_changed' => l.actSettingsChanged(a),
    'recurring_created' => l.actRecurringCreated(a),
    'recurring_updated' => l.actRecurringUpdated(a),
    'recurring_stopped' => l.actRecurringStopped(a),
    'import_completed' => l.actImportCompleted(a),
    _ => l.actUnknown(a),
  };
}

/// Label of a filter chip.
String activityFilterLabel(AppLocalizations l, ActivityFilter f) => switch (f) {
  ActivityFilter.all => l.actFilterAll,
  ActivityFilter.expenses => l.actFilterExpenses,
  ActivityFilter.payments => l.actFilterPayments,
  ActivityFilter.comments => l.actFilterComments,
  ActivityFilter.groups => l.actFilterGroups,
};

/// "Today" / "Yesterday" / "Sat, 21 Nov" (+ year when not this year).
String activityDay(BuildContext context, DateTime day, DateTime today) {
  final l = AppLocalizations.of(context);
  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  if (d == t) return l.expToday;
  if (d == DateTime(t.year, t.month, t.day - 1)) return l.expYesterday;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat(d.year == t.year ? 'EEE, d MMM' : 'EEE, d MMM y', locale).format(d);
}

/// Filter chips: All · Expenses · Payments · Comments · Groups.
class ActivityFilters extends StatelessWidget {
  const ActivityFilters({required this.value, required this.onChanged, super.key});

  final ActivityFilter value;
  final ValueChanged<ActivityFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: [
        for (final f in ActivityFilter.values)
          IconChip(
            key: Key('activity-filter-${f.name}'),
            label: activityFilterLabel(l, f),
            selected: value == f,
            onTap: () => onChanged(f),
          ),
      ],
    );
  }
}

/// Activity rows grouped by day, newest first; not scrollable itself. [showGroup] adds the group
/// name to every caption (the all-groups feed).
class ActivityFeed extends ConsumerWidget {
  const ActivityFeed({required this.items, this.showGroup = true, super.key});

  final List<ActivityItem> items;
  final bool showGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider).now();
    final children = <Widget>[];
    String? day;
    for (var i = 0; i < items.length; i++) {
      final header = activityDay(context, items[i].at, today);
      if (header != day) {
        day = header;
        children.add(_DayHeader(text: header, first: i == 0));
      }
      final next = i + 1 < items.length && activityDay(context, items[i + 1].at, today) == header;
      children.add(ActivityRow(item: items[i], showGroup: showGroup, showDivider: next));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.text, required this.first});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? AppSpacing.s2 : AppSpacing.s6, bottom: AppSpacing.s1),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
      ),
    ),
  );
}

/// One activity row (646): the actor's avatar, the sentence, "Goa trip · 2:30 pm", the amount and
/// the "not synced yet" marker on my pending changes. Tap opens what it is about.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    required this.item,
    this.showGroup = true,
    this.showDivider = true,
    super.key,
  });

  final ActivityItem item;
  final bool showGroup;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = item;
    final time = DateFormat.jm(Localizations.localeOf(context).toLanguageTag()).format(i.at);
    final amount = i.amount;
    final currency = i.currency;
    // Initials come from the real name ("MB"), never from "You".
    final actorName = i.actor.name.isNotEmpty ? i.actor.name : (i.actor.isMe ? l.you : l.someone);
    return AmountRow(
      key: ValueKey('activity-${i.id}'),
      title: activitySentence(l, i),
      caption: showGroup && i.groupName.isNotEmpty ? '${i.groupName} · $time' : time,
      amountText: amount == null || currency == null || amount <= 0
          ? ''
          : listMoney(amount, currency),
      unsynced: i.pending,
      showDivider: showDivider,
      leading: Avatar(name: actorName, seed: i.actor.seed),
      onTap: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    final id = item.targetId;
    if (id == null) return;
    final route = switch (item.targetType) {
      'expense' => ExpenseRoutes.detail(id),
      'payment' => PaymentRoutes.detail(id),
      _ => '/groups/$id',
    };
    unawaited(context.push(route));
  }
}

/// Loading placeholder: four quiet rows.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fill = context.colors.surfaceMuted;
    return Semantics(
      label: l.loading,
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(color: fill, borderRadius: AppRadii.allPill),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(color: fill, borderRadius: AppRadii.allPill),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
