import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
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
/// About & licences, Sign out, Delete account and the version. Later phases
/// add Security, Sync & storage, Deleted groups and Import.
class AccountSettingsBody extends ConsumerWidget {
  const AccountSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final mode = ref.watch(themeModeControllerProvider);
    final profile = ref.watch(profileProvider).value;
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
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        DashedListRow(
          icon: AppIcons.licence,
          label: l.aboutLicences,
          onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
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
        Text(l.version('0.1.0'), style: context.text.bodySmall.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
