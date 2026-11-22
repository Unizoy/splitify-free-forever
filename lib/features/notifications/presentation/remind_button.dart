import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/notifications_remote.dart';
import 'package:splitify/features/notifications/application/reminders.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// "Remind" on a row where [toMember] owes me (08 #23, TC-23-02): a round bell button. Hidden for name-only
/// members ([linked] false: they have no app to remind). Within 24 h of the last reminder it shows a check
/// and says when the next one is allowed; tapping then only explains. Online only.
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

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.linked) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final c = context.colors;
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
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          key: Key('remind-${widget.toMember}'),
          radius: 24,
          onTap: _busy
              ? null
              : throttled
              ? () => _snack(l.remindThrottled(widget.name, _hoursLeft(retryAt, now)))
              : () => unawaited(_send()),
          child: SizedBox.square(
            dimension: AppSpacing.minTouch,
            child: Center(
              child: AnimatedContainer(
                duration: context.motion.fast,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: throttled ? c.surfaceMuted : c.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: throttled ? c.surfaceMuted : c.border, width: 1.2),
                ),
                child: _busy
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.s3),
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
                      )
                    : Icon(
                        throttled ? AppIcons.check : AppIcons.bell,
                        size: 18,
                        color: throttled ? c.textSecondary : c.primary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
