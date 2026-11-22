import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/features/activity/presentation/activity_feed.dart'
    show FeedSkeleton, activityDay;
import 'package:splitify/features/groups/presentation/group_visuals.dart' show PageTitle;
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Icon of a notification kind (bell rows, settings).
IconData kindIcon(NotificationKind k) => switch (k) {
  NotificationKind.expenses => AppIcons.receipt,
  NotificationKind.payments => AppIcons.payment,
  NotificationKind.reminders => AppIcons.bell,
  NotificationKind.comments => AppIcons.chat,
  NotificationKind.groups => AppIcons.groups,
};

String kindLabel(AppLocalizations l, NotificationKind k) => switch (k) {
  NotificationKind.expenses => l.notifKindExpenses,
  NotificationKind.payments => l.notifKindPayments,
  NotificationKind.reminders => l.notifKindReminders,
  NotificationKind.comments => l.notifKindComments,
  NotificationKind.groups => l.notifKindGroups,
};

String kindHint(AppLocalizations l, NotificationKind k) => switch (k) {
  NotificationKind.expenses => l.notifKindExpensesHint,
  NotificationKind.payments => l.notifKindPaymentsHint,
  NotificationKind.reminders => l.notifKindRemindersHint,
  NotificationKind.comments => l.notifKindCommentsHint,
  NotificationKind.groups => l.notifKindGroupsHint,
};

/// Bell list (`/notifications`, #19, 646): newest first by day, unread rows bold with an indigo dot, "Mark all
/// read", pull to refresh; works offline from the phone's copy.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// The last refresh could not reach the server.
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final ok = await ref.read(notificationActionsProvider).refresh();
    if (mounted && ok == _offline) setState(() => _offline = !ok);
  }

  void _open(NotificationItem n) {
    unawaited(ref.read(notificationActionsProvider).open(n.id));
    final route = n.route;
    if (route != null) unawaited(context.push(route));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final async = ref.watch(notificationItemsProvider);
    final items = async.value;
    final unread = items?.where((n) => n.unread).length ?? 0;
    final Widget content;
    if (items == null) {
      content = async.hasError
          ? EmptyState(icon: AppIcons.warning, title: l.authErrorUnknown)
          : const FeedSkeleton();
    } else if (items.isEmpty) {
      content = ClipRRect(
        borderRadius: AppRadii.all28,
        child: BlobBackground(
          child: SizedBox(
            width: double.infinity,
            child: EmptyState(
              key: const Key('notifications-empty'),
              icon: AppIcons.bell,
              title: l.notifEmptyTitle,
              message: l.notifEmptyBody,
            ),
          ),
        ),
      );
    } else {
      content = NotificationList(items: items, onTap: _open);
    }
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.s2,
              AppSpacing.screen,
              AppSpacing.s8,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l.back,
                    icon: const Icon(AppIcons.back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('notifications-settings'),
                    tooltip: l.notifSettingsTooltip,
                    icon: const Icon(AppIcons.settings),
                    onPressed: () => unawaited(context.push('/account/notifications')),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              PageTitle(
                title: l.notifications,
                subtitle: items == null || items.isEmpty
                    ? null
                    : unread > 0
                    ? l.notifUnreadCount(unread)
                    : l.notifAllCaughtUp,
              ),
              if (unread > 0) ...[
                const SizedBox(height: AppSpacing.s4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PillButton(
                    key: const Key('notifications-mark-all'),
                    label: l.notifMarkAllRead,
                    icon: AppIcons.check,
                    variant: PillVariant.outline,
                    size: PillSize.medium,
                    expand: false,
                    onPressed: () => unawaited(ref.read(notificationActionsProvider).markAllRead()),
                  ),
                ),
              ],
              if (_offline) ...[
                const SizedBox(height: AppSpacing.s4),
                Row(
                  key: const Key('notifications-offline'),
                  children: [
                    Icon(AppIcons.unsynced, size: 18, color: c.unsynced),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        l.notifOffline,
                        style: context.text.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell rows grouped by day ("TODAY", "YESTERDAY", "SAT, 21 NOV"), newest first.
class NotificationList extends ConsumerWidget {
  const NotificationList({required this.items, required this.onTap, super.key});

  final List<NotificationItem> items;
  final ValueChanged<NotificationItem> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider).now();
    final children = <Widget>[];
    String? day;
    for (var i = 0; i < items.length; i++) {
      final header = activityDay(context, items[i].at, today);
      if (header != day) {
        day = header;
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? AppSpacing.s2 : AppSpacing.s6,
              bottom: AppSpacing.s1,
            ),
            child: Semantics(
              header: true,
              child: Text(
                header.toUpperCase(),
                style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ),
        );
      }
      final next = i + 1 < items.length && activityDay(context, items[i + 1].at, today) == header;
      children.add(
        NotificationRow(item: items[i], showDivider: next, onTap: () => onTap(items[i])),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// One bell row: the actor's avatar with the kind's badge, the sentence (bold while unread), "Goa trip ·
/// 2:30 pm" and the indigo unread dot.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    required this.item,
    required this.onTap,
    this.showDivider = true,
    super.key,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final n = item;
    final time = DateFormat.jm(Localizations.localeOf(context).toLanguageTag()).format(n.at);
    final caption = n.title.isEmpty ? time : '${n.title} · $time';
    return Semantics(
      button: true,
      label: [if (n.unread) l.notifUnread, n.body, caption].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: ValueKey('notification-${n.id}'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KindAvatar(item: n),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.body,
                          style: context.text.title
                              .w(n.unread ? 600 : 400)
                              .copyWith(color: n.unread ? c.textPrimary : c.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          style: context.text.bodySmall.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s2),
                    child: AnimatedOpacity(
                      opacity: n.unread ? 1 : 0,
                      duration: context.motion.fast,
                      child: Container(
                        key: n.unread ? const Key('notification-unread-dot') : null,
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider) Divider(height: 1, thickness: 1, color: c.divider),
          ],
        ),
      ),
    );
  }
}

/// Actor avatar with a small ink circle showing the kind (receipt, payment, bell, chat, people).
class _KindAvatar extends StatelessWidget {
  const _KindAvatar({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final name = item.actorName.isEmpty ? l.someone : item.actorName;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Avatar(name: name, seed: item.actorSeed),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: c.ink,
                shape: BoxShape.circle,
                border: Border.all(color: c.bg, width: 1.5),
              ),
              child: Icon(kindIcon(item.kind), size: 11, color: c.onInk),
            ),
          ),
        ],
      ),
    );
  }
}
