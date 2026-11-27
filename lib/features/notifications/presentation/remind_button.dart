import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/features/auth/application/auth_providers.dart' show profileProvider;
import 'package:splitify/features/balances/application/balance_views.dart'
    show GroupBalances, groupBalancesOf;
import 'package:splitify/features/balances/application/balances_providers.dart'
    show ledgerRepositoryProvider;
import 'package:splitify/features/groups/application/groups_providers.dart'
    show currentUserIdProvider;
import 'package:splitify/features/groups/presentation/invite_sheet.dart' show textSharerProvider;
import 'package:splitify/features/notifications/application/reminders.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Remind" on a row where [toMember] owes me (08 #23, TC-23-02): a round bell button that sends a push. Within
/// 24 h of the last reminder it shows a check and says when the next one is allowed; tapping then only
/// explains. Online only; when the push cannot go, the message offers "Share instead". For a name-only member
/// ([linked] false: no app to push to) it opens "Share a reminder" instead (D-034 B3).
class RemindButton extends ConsumerStatefulWidget {
  const RemindButton({
    required this.groupId,
    required this.fromMember,
    required this.toMember,
    required this.name,
    required this.linked,
    super.key,
  });

  final String groupId;

  /// My member id in the group.
  final String fromMember;
  final String toMember;

  /// The person's shown name ("Asha").
  final String name;
  final bool linked;

  @override
  ConsumerState<RemindButton> createState() => _RemindButtonState();
}

class _RemindButtonState extends ConsumerState<RemindButton> {
  bool _busy = false;

  ReminderPair get _pair =>
      (groupId: widget.groupId, fromMember: widget.fromMember, toMember: widget.toMember);

  static int _hoursLeft(DateTime retryAt, DateTime now) {
    final h = (retryAt.difference(now).inMinutes / 60).ceil();
    return h < 1 ? 1 : h;
  }

  void _snack(String text, {bool offerShare = false}) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: offerShare
              ? SnackBarAction(label: l.remindShareInstead, onPressed: () => unawaited(_share()))
              : null,
        ),
      );
  }

  /// Reads the group once from this phone (nothing is kept open while the button just sits in a list).
  Future<void> _share() async {
    final ledger = await ref.read(ledgerRepositoryProvider).loadGroup(widget.groupId);
    if (ledger == null || !mounted) return;
    await showShareReminder(
      context,
      ref,
      balances: groupBalancesOf(ledger, ref.read(currentUserIdProvider)),
      direct: ledger.group.type == 'direct',
      me: widget.fromMember,
      them: widget.toMember,
      name: widget.name,
    );
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(reminderActionsProvider).send(_pair);
      if (mounted) _snack(l.remindSent(widget.name));
    } on ReminderFailure catch (e) {
      if (!mounted) return;
      final now = ref.read(clockProvider).now().toUtc();
      final retry = e.retryAt;
      _snack(switch (e.code) {
        ReminderFailureCode.offline => l.needsInternet,
        ReminderFailureCode.throttled => l.remindThrottled(
          widget.name,
          retry == null ? 24 : _hoursLeft(retry, now),
        ),
        ReminderFailureCode.nothingOwed => l.remindNothingOwed(widget.name),
        ReminderFailureCode.nameOnly => l.remindNameOnly,
        _ => l.remindFailed,
      }, offerShare: e.code != ReminderFailureCode.nothingOwed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!widget.linked) {
      return _Bell(
        key: Key('remind-${widget.toMember}'),
        label: l.remindShareTooltip(widget.name),
        icon: AppIcons.share,
        muted: false,
        onTap: () => unawaited(_share()),
      );
    }
    final now = ref.watch(clockProvider).now().toUtc();
    final retryAt = reminderRetryAt(
      lastSent: ref.watch(lastReminderProvider(_pair)).value,
      sentHere: ref.watch(sentRemindersProvider)[SentReminders.keyOf(_pair)],
      now: now,
    );
    final throttled = retryAt != null;
    final label = throttled
        ? l.remindedTooltip(_hoursLeft(retryAt, now))
        : l.remindTooltip(widget.name);
    final VoidCallback? tap = _busy
        ? null
        : throttled
        ? () => _snack(l.remindThrottled(widget.name, _hoursLeft(retryAt, now)), offerShare: true)
        : () => unawaited(_send());
    return _Bell(
      key: Key('remind-${widget.toMember}'),
      label: label,
      icon: throttled ? AppIcons.check : AppIcons.bell,
      muted: throttled,
      busy: _busy,
      onTap: tap,
    );
  }
}

/// The round 40 dp button (48 dp touch area) with a tooltip.
class _Bell extends StatelessWidget {
  const _Bell({
    required this.label,
    required this.icon,
    required this.muted,
    required this.onTap,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool muted;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          circle: true,
          scale: 0.9,
          child: SizedBox.square(
            dimension: AppSpacing.minTouch,
            child: Center(
              child: AnimatedContainer(
                duration: context.motion.fast,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: muted ? c.surfaceMuted : c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: muted ? c.surfaceMuted : c.border, width: 1.2),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.s3),
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                      )
                    : Icon(icon, size: 18, color: muted ? c.textSecondary : c.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Share a reminder" (D-034 B3): the ready-made text ([reminderShareText]) and Share, which opens the Android
/// share sheet. Nothing is sent by the app and nothing goes to the activity log. When nothing is owed it
/// only says so.
Future<void> showShareReminder(
  BuildContext context,
  WidgetRef ref, {
  required GroupBalances balances,
  required bool direct,
  required String me,
  required String them,
  required String name,
}) async {
  final l = AppLocalizations.of(context);
  final owed = owedToMe(balances, me: me, them: them);
  if (owed.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.remindNothingOwed(name))));
    return;
  }
  final profile = ref.read(profileProvider).value;
  final text = reminderShareText(
    l,
    name: name,
    owed: owed,
    groupName: balances.groupName,
    direct: direct,
    myVpa: profile?.upiId,
    myName: profile?.displayName ?? '',
  );
  final share = ref.read(textSharerProvider);
  await showAppSheet<void>(
    context,
    title: l.remindShareTitle,
    builder: (sheet) => ShareReminderSheet(
      text: text,
      onShare: () {
        Navigator.of(sheet).pop();
        unawaited(share(text));
      },
    ),
  );
}

/// The sheet body: what it is for, the message as it will be sent, and Share.
class ShareReminderSheet extends StatelessWidget {
  const ShareReminderSheet({required this.text, required this.onShare, super.key});

  final String text;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Column(
      key: const Key('remind-share-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.remindShareBody, style: context.text.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: AppSpacing.s5),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.bell, size: 20, color: c.primary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  text,
                  key: const Key('remind-share-text'),
                  style: context.text.body.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('remind-share'),
          label: l.remindShareAction,
          icon: AppIcons.share,
          onPressed: onShare,
        ),
      ],
    );
  }
}
