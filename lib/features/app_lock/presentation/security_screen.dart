import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/features/app_lock/domain/lock_policy.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Security (`/account/security`, X2): app lock on/off (asks for the phone's lock either way) and
/// how long Splitify may stay in the background before it locks (1 / 5 / 15 minutes).
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final s = ref.watch(appLockProvider);
    final notice = switch (s.notice) {
      LockNotice.needsScreenLock => l.lockNeedsScreenLock,
      LockNotice.turnedOff => l.lockTurnedOff,
      LockNotice.failed => l.lockConfirmFailed,
      null => null,
    };
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l.lockSecurity),
      ),
      // One screen (D-033): the switch, and once it is on, when to lock, in the same card.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s4,
          AppSpacing.screen,
          AppSpacing.s8,
        ),
        children: [
          SettingsSection(
            key: const Key('security-section'),
            children: [
              ToggleRow(
                key: const Key('security-app-lock'),
                icon: AppIcons.lock,
                title: l.lockAppLock,
                subtitle: l.lockAppLockSub,
                value: s.enabled,
                showDivider: s.enabled,
                onChanged: s.authenticating
                    ? null
                    : (on) => unawaited(
                        ref.read(appLockProvider.notifier).setEnabled(on: on, reason: l.lockReason),
                      ),
              ),
              if (s.enabled)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.lockAfter.toUpperCase(),
                        style: context.text.labelCaps.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      SegmentedPill<LockTimeout>(
                        key: const Key('security-timeout'),
                        value: s.timeout,
                        onChanged: (t) =>
                            unawaited(ref.read(appLockProvider.notifier).setTimeout(t)),
                        items: [
                          for (final t in LockTimeout.values)
                            SegmentedPillItem(
                              value: t,
                              label: l.lockMinutesShort(t.minutes),
                              semanticLabel: l.lockMinutes(t.minutes),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      Text(
                        l.lockAfterSub,
                        style: context.text.bodySmall.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Semantics(
              liveRegion: true,
              child: Text(
                notice,
                key: const Key('security-notice'),
                style: context.text.bodySmall.copyWith(color: c.oweText),
              ),
            ),
          ],
          if (s.enabled) ...[
            const SizedBox(height: AppSpacing.s5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(AppIcons.eyeSlash, size: 18, color: c.textSecondary),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    l.lockRecentsNote,
                    style: context.text.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
