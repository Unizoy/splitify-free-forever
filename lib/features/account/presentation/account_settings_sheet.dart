import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/push_messaging.dart' show PushPermission;
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/features/app_lock/presentation/security_routes.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/capture/application/capture_providers.dart';
import 'package:splitify/features/capture/presentation/capture_routes.dart' show CaptureRoutes;
import 'package:splitify/features/import_splitwise/presentation/import_routes.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/sync/application/sync_texts.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Opens the "Account settings" sheet (614/623).
Future<void> showAccountSettings(BuildContext context) => showAppSheet<void>(
  context,
  title: AppLocalizations.of(context).accountSettings,
  builder: (context) => const AccountSettingsBody(),
);

/// Label for a theme mode in the current language.
String themeModeLabel(AppLocalizations l, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l.themeSystem,
  ThemeMode.light => l.themeLight,
  ThemeMode.dark => l.themeDark,
};

/// Asks before signing out (B1), then signs out and wipes this phone.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final yes = await showAppSheet<bool>(
    context,
    title: l.signOutTitle,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.signOutBody, style: context.text.body.copyWith(color: context.colors.textSecondary)),
        const SizedBox(height: AppSpacing.s6),
        PillButton(
          key: const Key('sign-out-confirm'),
          label: l.signOut,
          icon: AppIcons.signOut,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.s2),
        PillButton(
          label: l.cancelLabel,
          variant: PillVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  if (yes ?? false) await ref.read(accountActionsProvider).signOut();
}

/// Settings sheet content (07 §2): Profile and Preferences accordions, then
/// Sync & storage, Deleted groups, About & licences, Sign out, Delete account and the version.
/// Security (app lock, widget) and Import from Splitwise came with phase 18.
class AccountSettingsBody extends ConsumerWidget {
  const AccountSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final mode = ref.watch(themeModeControllerProvider);
    final profile = ref.watch(profileProvider).value;
    final sync = ref.watch(syncStatusProvider).value;
    final uploads = ref.watch(syncUploadsProvider).value ?? const [];
    void openProfile() {
      Navigator.of(context).pop();
      unawaited(context.push('/account/profile'));
    }

    return Column(
      children: [
        AccordionCard(
          icon: AppIcons.user,
          iconColor: c.primary,
          title: l.profileTitle,
          subtitle: l.profileSubtitle,
          initiallyExpanded: true,
          rows: [
            AccordionRow(
              label: l.nameLabel,
              value: profile?.displayName ?? l.notSet,
              onTap: openProfile,
            ),
            AccordionRow(label: l.upiLabel, value: profile?.upiId ?? l.notSet, onTap: openProfile),
            AccordionRow(
              label: l.defaultCurrency,
              value: profile?.defaultCurrency ?? 'INR',
              onTap: openProfile,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        AccordionCard(
          icon: AppIcons.palette,
          iconColor: c.primary,
          title: l.preferences,
          subtitle: l.preferencesSubtitle,
          rows: [
            AccordionRow(
              label: l.appearance,
              value: themeModeLabel(l, mode),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/account/appearance');
              },
            ),
            AccordionRow(
              label: l.notifications,
              // "On" only when Android lets pushes through (final QA: it said On while not allowed).
              value:
                  ref.watch(pushMessagingProvider).available &&
                      ref.watch(pushStateProvider).value?.permission == PushPermission.granted
                  ? l.notifRowOn
                  : l.notifRowBellOnly,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(context.push('/account/notifications'));
              },
            ),
            AccordionRow(
              label: l.captureRow,
              value: (ref.watch(captureSettingsProvider).value?.enabled ?? false)
                  ? l.captureRowOn
                  : l.captureRowOff,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(context.push(CaptureRoutes.settings));
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        // X2 app lock, X3 home-screen widget (phase 18).
        AccordionCard(
          key: const Key('settings-security'),
          icon: AppIcons.lock,
          iconColor: c.primary,
          title: l.lockSecurity,
          subtitle: l.lockSecuritySubtitle,
          rows: [
            AccordionRow(
              label: l.lockAppLock,
              value: ref.watch(appLockProvider).enabled ? l.lockOn : l.lockOff,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(context.push(SecurityRoutes.security));
              },
            ),
            AccordionRow(
              label: l.widgetRow,
              value: ref.watch(widgetHideAmountsProvider) ? l.widgetHidden : null,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(context.push(SecurityRoutes.widget));
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        DashedListRow(
          key: const Key('settings-sync'),
          icon: AppIcons.sync,
          label: l.syncStorage,
          value: syncRowValue(l, sync, uploads: uploads),
          valueColor: sync == null || (sync.allSynced && uploads.every((u) => !u.skipped))
              ? c.textSecondary
              : c.unsynced,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(context.push('/account/sync'));
          },
        ),
        DashedListRow(
          key: const Key('settings-deleted-groups'),
          icon: AppIcons.restore,
          label: l.deletedGroups,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(context.push('/account/deleted-groups'));
          },
        ),
        DashedListRow(
          key: const Key('settings-import'),
          icon: AppIcons.fileImport,
          label: l.impTitle,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(context.push(ImportRoutes.fromAccount));
          },
        ),
        DashedListRow(
          key: const Key('settings-about'),
          icon: AppIcons.licence,
          label: l.aboutLicences,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(context.push('/account/about'));
          },
        ),
        DashedListRow(
          key: const Key('settings-sign-out'),
          icon: AppIcons.signOut,
          label: l.signOut,
          onTap: () => unawaited(confirmSignOut(context, ref)),
        ),
        DashedListRow(
          key: const Key('settings-delete-account'),
          icon: AppIcons.trash,
          label: l.deleteAccount,
          destructive: true,
          showDivider: false,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(context.push('/account/delete'));
          },
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(l.version(appVersion), style: context.text.bodySmall.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
