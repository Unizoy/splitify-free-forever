import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/debug/presentation/gallery/gallery_sections.dart';
import 'package:splitify/ui/components/components.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Debug-only component gallery (`/debug/gallery`): every component in its
/// variants, section by section. The moon button flips light/dark.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  static const _title = 'Component gallery';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text(_title),
        actions: [
          AppIconButton(
            tooltip: _title,
            icon: Icon(context.isDark ? AppIcons.sun : AppIcons.moon),
            onPressed: () => ref
                .read(themeModeControllerProvider.notifier)
                .select(context.isDark ? ThemeMode.light : ThemeMode.dark),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.s4,
          AppSpacing.screen,
          AppSpacing.s12,
        ),
        itemCount: gallerySections.length,
        itemBuilder: (context, i) {
          final section = gallerySections[i];
          return Column(
            key: ValueKey('gallery-${section.id}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (i > 0) Divider(height: AppSpacing.s12, color: c.border),
              Semantics(
                header: true,
                child: Text(section.title, style: context.text.sheetTitle.copyWith(fontSize: 28)),
              ),
              const SizedBox(height: AppSpacing.s5),
              section.builder(context),
            ],
          );
        },
      ),
    );
  }
}
