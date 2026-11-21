import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Appearance (`/account/appearance`, B3): System / Light / Dark.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final mode = ref.watch(themeModeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(AppIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s2,
          AppSpacing.screen,
          AppSpacing.s8,
        ),
        children: [
          Semantics(
            header: true,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: AppText.maxSerifScale,
              child: Text(l.appearance, style: context.text.sheetTitle),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(l.appearanceHint, style: context.text.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s8),
          SegmentedPill<ThemeMode>(
            key: const Key('appearance-mode'),
            value: mode,
            onChanged: (m) => ref.read(themeModeControllerProvider.notifier).select(m),
            items: [
              SegmentedPillItem(
                value: ThemeMode.system,
                label: l.themeSystem,
                icon: AppIcons.device,
              ),
              SegmentedPillItem(value: ThemeMode.light, label: l.themeLight, icon: AppIcons.sun),
              SegmentedPillItem(value: ThemeMode.dark, label: l.themeDark, icon: AppIcons.moon),
            ],
          ),
        ],
      ),
    );
  }
}
