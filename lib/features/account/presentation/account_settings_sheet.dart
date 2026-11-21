import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
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

/// Settings sheet content: Preferences accordion and the about row.
/// Later phases add Profile, Security, Sync & storage, Sign out…
class AccountSettingsBody extends ConsumerWidget {
  const AccountSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final mode = ref.watch(themeModeControllerProvider);
    return Column(
      children: [
        AccordionCard(
          icon: AppIcons.palette,
          iconColor: c.primary,
          title: l.preferences,
          subtitle: l.preferencesSubtitle,
          initiallyExpanded: true,
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
          showDivider: false,
          onTap: () => showLicensePage(context: context, applicationName: l.appTitle),
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(l.version('0.1.0'), style: context.text.bodySmall.copyWith(color: c.textSecondary)),
      ],
    );
  }
}
