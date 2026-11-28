import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/local/app_database.dart';
import 'package:splitify/data/remote/push_messaging.dart';
import 'package:splitify/domain/entities/notification_prefs.dart';
import 'package:splitify/features/groups/application/groups_providers.dart';
import 'package:splitify/features/groups/presentation/group_visuals.dart' show GroupThumb;
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/notifications/presentation/notifications_screen.dart'
    show kindHint, kindIcon, kindLabel;
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Notification settings (`/account/notifications`, #19): per kind push / in-app switches and muted groups,
/// each group of switches in one card (D-033).
/// Saved on the phone at once (offline too) and sent with the next refresh; a banner explains when this
/// phone gets no pushes (not set up in this build, or blocked in Android). While push is blocked or missing
/// the push switches are shown disabled and the banner offers Android's settings; the state is read again
/// when the person comes back (final QA).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(pushStateProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefs = ref.watch(notificationPrefsProvider).value ?? const NotificationPrefs();
    final pending = ref.watch(notificationPrefsPendingProvider).value ?? false;
    final push = ref.watch(pushStateProvider).value;
    final groups = <LocalGroup>[
      for (final g in ref.watch(groupsListProvider).value ?? const <LocalGroup>[])
        if (g.archivedAt == null && g.deletedAt == null && g.type != 'direct') g,
    ];
    final actions = ref.read(notificationActionsProvider);
    final pushOff = push != null && (!push.available || push.permission == PushPermission.denied);
    // Push rows explain each kind; the in-app rows repeat only the names (D-033: shorter page).
    List<Widget> kindRows(NotificationChannel ch) => [
      for (final k in NotificationKind.switchable)
        ToggleRow(
          key: Key('notif-${ch.name}-${k.name}'),
          icon: kindIcon(k),
          title: kindLabel(l, k),
          subtitle: ch == NotificationChannel.push ? kindHint(l, k) : null,
          value: prefs.isOn(k, ch),
          showDivider: k != NotificationKind.switchable.last,
          onChanged: ch == NotificationChannel.push && pushOff
              ? null
              : (on) => unawaited(actions.setKind(k, ch, on: on)),
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l.notifications),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s2,
          AppSpacing.screen,
          AppSpacing.s8,
        ),
        children: [
          Text(
            l.notifSettingsHint,
            style: context.text.body.copyWith(color: context.colors.textSecondary),
          ),
          if (pending) ...[const SizedBox(height: AppSpacing.s3), const SyncMarker()],
          if (push != null && (!push.available || push.permission != PushPermission.granted)) ...[
            const SizedBox(height: AppSpacing.s5),
            _PushBanner(available: push.available, permission: push.permission),
          ],
          const SizedBox(height: AppSpacing.s6),
          SettingsSection(
            key: const Key('notif-section-push'),
            title: l.notifSectionPush,
            children: kindRows(NotificationChannel.push),
          ),
          const SizedBox(height: AppSpacing.s6),
          // W2-Y (F14): the monthly summary is opt-in (off until switched on).
          SettingsSection(
            key: const Key('notif-section-summary'),
            title: l.w2yNotifMonthly,
            children: [
              ToggleRow(
                key: const Key('notif-push-summary'),
                icon: kindIcon(NotificationKind.summary),
                title: kindLabel(l, NotificationKind.summary),
                subtitle: kindHint(l, NotificationKind.summary),
                value: prefs.isOn(NotificationKind.summary, NotificationChannel.push),
                showDivider: false,
                onChanged: pushOff
                    ? null
                    : (on) => unawaited(
                        actions.setKind(NotificationKind.summary, NotificationChannel.push, on: on),
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          SettingsSection(
            key: const Key('notif-section-inapp'),
            title: l.notifSectionInApp,
            children: kindRows(NotificationChannel.inapp),
          ),
          const SizedBox(height: AppSpacing.s6),
          SettingsSection(
            key: const Key('notif-section-muted'),
            title: l.notifSectionMuted,
            footer: l.notifMutedHint,
            children: [
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                  child: Text(l.notifMutedEmpty, style: context.text.body),
                )
              else
                for (var i = 0; i < groups.length; i++)
                  ToggleRow(
                    key: Key('notif-mute-${groups[i].id}'),
                    leading: GroupThumb(group: groups[i]),
                    title: groups[i].name,
                    subtitle: prefs.isMuted(groups[i].id) ? l.notifMutedOn : l.notifMutedOff,
                    value: prefs.isMuted(groups[i].id),
                    showDivider: i < groups.length - 1,
                    onChanged: (muted) => unawaited(actions.setMuted(groups[i].id, muted: muted)),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Push isn't set up in this version" / "blocked in Android" / "off for now" + Allow.
class _PushBanner extends ConsumerWidget {
  const _PushBanner({required this.available, required this.permission});

  final bool available;
  final PushPermission permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final text = !available
        ? l.notifPushOffBuild
        : permission == PushPermission.denied
        ? l.notifPushBlocked
        : l.notifPushNotAsked;
    return Container(
      key: const Key('notif-push-banner'),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: AppRadii.all24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.info, size: 22, color: c.onPrimaryContainer),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(text, style: context.text.body.copyWith(color: c.onPrimaryContainer)),
              ),
            ],
          ),
          if (available && permission == PushPermission.denied) ...[
            const SizedBox(height: AppSpacing.s3),
            PillButton(
              key: const Key('notif-open-settings'),
              label: l.notifOpenSettings,
              icon: AppIcons.settings,
              size: PillSize.medium,
              expand: false,
              onPressed: () =>
                  unawaited(ref.read(systemSettingsProvider).openNotificationSettings()),
            ),
          ],
          if (available && permission == PushPermission.notAsked) ...[
            const SizedBox(height: AppSpacing.s3),
            PillButton(
              key: const Key('notif-allow'),
              label: l.notifAllow,
              icon: AppIcons.bell,
              size: PillSize.medium,
              expand: false,
              onPressed: () async {
                final allowed = await ref.read(pushPrePromptProvider).allow();
                if (allowed) await ref.read(pushRegistrationProvider).register();
                ref.invalidate(pushStateProvider);
              },
            ),
          ],
        ],
      ),
    );
  }
}
