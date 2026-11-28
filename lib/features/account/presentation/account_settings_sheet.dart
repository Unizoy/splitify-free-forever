import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/core/config/app_info.dart';
import 'package:splitify/core/platform/crash_reporting.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/push_messaging.dart' show PushPermission;
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/account/presentation/appearance_screen.dart';
import 'package:splitify/features/account/presentation/your_data_sheet.dart';
import 'package:splitify/features/app_lock/application/app_lock_controller.dart';
import 'package:splitify/features/app_lock/presentation/security_routes.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/features/import_splitwise/presentation/import_routes.dart';
import 'package:splitify/features/notifications/application/notifications_providers.dart';
import 'package:splitify/features/sync/application/sync_texts.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';
import 'package:splitify/features/widget/presentation/widget_settings_screen.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

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

/// The settings list right on the Account tab (D-033, Splitwise-like: no gear, no nested accordions): the
/// profile row (→ account settings), Notifications, Security, Appearance (sheet), Sync & storage,
/// Home-screen widget (sheet), Your data (sheet, D-034), Import, Deleted groups, About; then Sign out,
/// Delete account and the version. Each row says its current state; pages open only where there is
/// more than one setting.
class AccountSettingsList extends ConsumerWidget {
  const AccountSettingsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final mode = ref.watch(themeModeControllerProvider);
    final profile = ref.watch(profileProvider).value;
    final sync = ref.watch(syncStatusProvider).value;
    final uploads = ref.watch(syncUploadsProvider).value ?? const [];
    final pushOn =
        ref.watch(pushMessagingProvider).available &&
        ref.watch(pushStateProvider).value?.permission == PushPermission.granted;
    final crash = ref.watch(crashReporterProvider);
    void open(String route) => unawaited(context.push(route));

    return Column(
      key: const Key('account-settings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l.settings,
          children: [
            _ProfileRow(
              name: profile?.displayName ?? l.yourAccount,
              seed: profile?.id ?? 'me',
              caption: [
                if ((profile?.upiId ?? '').isNotEmpty) profile!.upiId! else l.settingsNoUpi,
                profile?.defaultCurrency ?? 'INR',
              ].join(' · '),
              onTap: () => open('/account/profile'),
            ),
            DashedListRow(
              key: const Key('settings-notifications'),
              icon: AppIcons.bell,
              label: l.notifications,
              // "On" only when Android lets pushes through (final QA: it said On while not allowed).
              value: pushOn ? l.notifRowOn : l.notifRowBellOnly,
              onTap: () => open('/account/notifications'),
            ),
            DashedListRow(
              key: const Key('settings-security'),
              icon: AppIcons.lock,
              label: l.lockSecurity,
              value: ref.watch(appLockProvider).enabled ? l.lockOn : l.lockOff,
              onTap: () => open(SecurityRoutes.security),
            ),
            DashedListRow(
              key: const Key('settings-appearance'),
              icon: AppIcons.palette,
              label: l.appearance,
              value: themeModeLabel(l, mode),
              onTap: () => unawaited(showAppearanceSheet(context)),
            ),
            DashedListRow(
              key: const Key('settings-sync'),
              icon: AppIcons.sync,
              label: l.syncStorage,
              value: syncRowValue(l, sync, uploads: uploads),
              valueColor: sync == null || (sync.allSynced && uploads.every((u) => !u.skipped))
                  ? c.textSecondary
                  : c.unsynced,
              onTap: () => open('/account/sync'),
            ),
            DashedListRow(
              key: const Key('settings-widget'),
              icon: AppIcons.device,
              label: l.widgetRow,
              value: ref.watch(widgetHideAmountsProvider) ? l.widgetHidden : null,
              onTap: () => unawaited(showWidgetSheet(context)),
            ),
            // D-034 WP-D: everything on this phone as a .zip (JSON + one CSV per group).
            DashedListRow(
              key: const Key('settings-your-data'),
              icon: AppIcons.archive,
              label: l.backupRow,
              value: l.backupRowValue,
              onTap: () => unawaited(showYourDataSheet(context)),
            ),
            DashedListRow(
              key: const Key('settings-import'),
              icon: AppIcons.fileImport,
              label: l.impTitle,
              onTap: () => open(ImportRoutes.fromAccount),
            ),
            DashedListRow(
              key: const Key('settings-deleted-groups'),
              icon: AppIcons.restore,
              label: l.deletedGroups,
              onTap: () => open('/account/deleted-groups'),
            ),
            // W2-Y (S-436): crash reports with no personal data; off when this build has no Firebase.
            ToggleRow(
              key: const Key('settings-crash-reports'),
              icon: const IconData(0xe5f4, fontFamily: 'PhosphorRegular'),
              title: l.w2yCrashTitle,
              subtitle: crash.available ? l.w2yCrashHint : l.w2yCrashOff,
              value: crash.available && ref.watch(crashReportsSettingProvider),
              onChanged: crash.available
                  ? (on) => unawaited(ref.read(crashReportsSettingProvider.notifier).set(on: on))
                  : null,
            ),
            DashedListRow(
              key: const Key('settings-about'),
              icon: AppIcons.licence,
              label: l.aboutLicences,
              showDivider: false,
              onTap: () => open('/account/about'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        SettingsSection(
          children: [
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
              onTap: () => open('/account/delete'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s5),
        Text(
          l.version(appVersion),
          textAlign: TextAlign.center,
          style: context.text.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

/// "Mohit Bindal · mohit@okaxis · INR" → profile and account settings (name, photo, UPI ID, currency).
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.name,
    required this.seed,
    required this.caption,
    required this.onTap,
  });

  final String name;
  final String seed;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Semantics(
      key: const Key('settings-profile'),
      button: true,
      label: '$name, $caption',
      hint: l.accountSettings,
      excludeSemantics: true,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            onTap: onTap,
            borderRadius: AppRadii.all16,
            scale: AppMotion.rowPressScale,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                child: Row(
                  children: [
                    Avatar(name: name, seed: seed),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name, style: context.text.body.w(700)),
                          const SizedBox(height: 2),
                          Text(
                            caption,
                            style: context.text.bodySmall.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Text(
                      l.settingsEdit,
                      // The same value style and chevron as the rows below (S-448).
                      style: context.text.body.w(600).copyWith(color: c.primary),
                    ),
                    Icon(AppIcons.chevronRight, size: 18, color: c.textPrimary),
                  ],
                ),
              ),
            ),
          ),
          const DashedDivider(),
        ],
      ),
    );
  }
}
