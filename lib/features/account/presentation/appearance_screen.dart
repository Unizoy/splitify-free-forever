import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Appearance (B3) as a sheet from the Account list (D-033: one choice, no page of its own): System /
/// Light / Dark. A pick applies at once and closes the sheet.
Future<void> showAppearanceSheet(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  return showAppSheet<void>(
    context,
    title: AppLocalizations.of(context).appearance,
    builder: (sheet) => UncontrolledProviderScope(
      container: container,
      child: AppearancePicker(onPicked: () => Navigator.of(sheet).pop()),
    ),
  );
}

/// The sheet's content: a short hint and the three-way pill.
class AppearancePicker extends ConsumerWidget {
  const AppearancePicker({this.onPicked, super.key});

  /// After a mode was picked (the sheet closes).
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.appearanceHint,
          textAlign: TextAlign.center,
          style: context.text.body.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s6),
        SegmentedPill<ThemeMode>(
          key: const Key('appearance-mode'),
          value: mode,
          onChanged: (m) {
            ref.read(themeModeControllerProvider.notifier).select(m);
            onPicked?.call();
          },
          items: [
            SegmentedPillItem(value: ThemeMode.system, label: l.themeSystem, icon: AppIcons.device),
            SegmentedPillItem(value: ThemeMode.light, label: l.themeLight, icon: AppIcons.sun),
            SegmentedPillItem(value: ThemeMode.dark, label: l.themeDark, icon: AppIcons.moon),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
      ],
    );
  }
}
