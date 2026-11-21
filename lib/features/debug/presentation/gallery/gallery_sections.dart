import 'package:flutter/material.dart';
import 'package:splitify/features/debug/presentation/gallery/sections_basics.dart';
import 'package:splitify/features/debug/presentation/gallery/sections_surfaces.dart';
import 'package:splitify/ui/components/hero_header.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// One gallery section: shown on `/debug/gallery` and rendered by the golden
/// tests (planning/06-design-system.md §9).
class GallerySection {
  const GallerySection(this.id, this.title, this.builder);

  /// File-name friendly id, used for golden names.
  final String id;
  final String title;
  final WidgetBuilder builder;
}

/// Every section, in gallery order.
final List<GallerySection> gallerySections = [
  const GallerySection('buttons', 'Buttons & controls', buttonsSection),
  const GallerySection('chips', 'Pills, chips & markers', chipsSection),
  const GallerySection('inputs', 'Inputs', inputsSection),
  const GallerySection('avatars', 'Avatars', avatarsSection),
  const GallerySection('covers', 'Generated covers', coversSection),
  const GallerySection('cards', 'Cards', cardsSection),
  const GallerySection('showpieces', 'Showpiece cards', showpiecesSection),
  const GallerySection('lists', 'Rows, tabs & bars', listsSection),
  const GallerySection('navigation', 'Navigation & headers', navigationSection),
  const GallerySection('feedback', 'Empty, loading & success', feedbackSection),
];

/// Labelled demo block inside a section.
class Demo extends StatelessWidget {
  const Demo(this.label, this.child, {super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: context.text.labelCaps.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s3),
          child,
        ],
      ),
    );
  }
}

/// A patch of hero imagery for components that live on dark art.
class HeroSwatch extends StatelessWidget {
  const HeroSwatch({required this.child, this.seed = 'swatch', super.key});

  final Widget child;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: AppRadii.all24,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.heroTop, c.heroBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CoverArt(
              seed: seed,
              family: CoverFamily.other,
              legibilityScrim: false,
              cache: false,
            ),
          ),
          Positioned.fill(child: ColoredBox(color: AppPalette.black.withValues(alpha: 0.25))),
          Padding(padding: const EdgeInsets.all(AppSpacing.s5), child: child),
        ],
      ),
    );
  }
}

/// Re-exported so sections can build heroes without another import.
typedef GalleryHeroArt = HeroArt;
