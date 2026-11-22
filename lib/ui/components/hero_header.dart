import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/components/glass_card.dart';
import 'package:splitify/ui/components/pressable.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Generated art painted into the lower part of a [HeroHeader].
typedef HeroArt = ({String seed, CoverFamily family});

/// Full-bleed hero (438/455): lavender→dusk gradient (black→navy in dark
/// mode) that runs under the status bar, optional generated cover art fading
/// in below, round translucent action buttons, centred white serif headline
/// and an optional child (usually a [GlassCard]). Leaves room at the bottom
/// for the overlap sheet.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.top,
    this.child,
    this.art,
    this.photo,
    this.overlap = AppSpacing.sheetOverlap,
    super.key,
  });

  /// Serif headline (lowercase sentence, may contain a line break).
  final String? title;

  /// Custom headline (rich text); wins over [title].
  final Widget? titleWidget;
  final Widget? leading;

  /// Right-aligned [HeroIconButton]s.
  final List<Widget> actions;

  /// Widget between the actions and the title, e.g. [HeroTabs].
  final Widget? top;

  /// Below the title, usually a GlassCard.
  final Widget? child;
  final HeroArt? art;

  /// A cover photo shown full-bleed instead of [art] (group covers, S-073), darkened for legibility.
  final ImageProvider? photo;

  /// Space kept free at the bottom for the sheet that overlaps the hero.
  final double overlap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final headline =
        titleWidget ??
        (title == null
            ? null
            : Text(
                title!,
                textAlign: TextAlign.center,
                style: context.text.heroDisplay.copyWith(color: c.onHero),
              ));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: AppPalette.clear),
      // The background never moves under the content: glass cards paint a pre-blurred slice of it.
      child: GlassBackdropHost(
        snapshot: photo == null,
        background: _HeroBackground(art: art, photo: photo),
        child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              topInset + AppSpacing.s2,
              AppSpacing.screen,
              overlap + AppSpacing.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: AppSpacing.minTouch,
                  child: Row(
                    children: [
                      ?leading,
                      const Spacer(),
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.s1),
                        actions[i],
                      ],
                    ],
                  ),
                ),
                if (top != null) ...[const SizedBox(height: AppSpacing.s4), top!],
                if (headline != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Semantics(
                    header: true,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: AppText.maxSerifScale,
                      child: headline,
                    ),
                  ),
                ],
                if (child != null) ...[const SizedBox(height: AppSpacing.s8), child!],
              ],
            ),
          ),
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.art, this.photo});

  final HeroArt? art;
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.heroTop, c.heroBottom],
            ),
          ),
        ),
        if (photo != null) ...[
          Image(image: photo!, fit: BoxFit.cover, gaplessPlayback: true),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppPalette.black.withValues(alpha: 0.45),
                  AppPalette.black.withValues(alpha: 0.2),
                  AppPalette.black.withValues(alpha: 0.45),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ] else if (art != null)
          // Fades out toward the top; baked into the cached image (no live shader mask, S-267).
          CoverArt(seed: art!.seed, family: art!.family, legibilityScrim: false, topFade: true),
        // Dark base so white text and the glass border stay readable.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppPalette.black.withValues(alpha: 0),
                AppPalette.black.withValues(alpha: 0.35),
              ],
              stops: const [0.5, 1],
            ),
          ),
        ),
      ],
    );
  }
}

/// 40 dp translucent round icon button for heroes (48 dp touch target).
class HeroIconButton extends StatelessWidget {
  const HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = 0,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Count in an amber badge on the circle (the bell's unread count, phase 13); 0 hides it, 10+ shows "9+".
  final int badge;

  /// Screen-reader label when it should say more than [tooltip] ("Notifications, 3 unread").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.onHero.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: c.onHero.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: 20, color: c.onHero),
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticLabel ?? tooltip,
        excludeSemantics: true,
        child: Pressable(
          onTap: onPressed,
          circle: true,
          scale: 0.9,
          highlightColor: c.onHero,
          haptic: PressHaptic.selection,
          child: SizedBox.square(
            dimension: AppSpacing.minTouch,
            child: Center(
              child: badge <= 0
                  ? circle
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        circle,
                        PositionedDirectional(
                          top: -3,
                          end: -5,
                          child: _CountBadge(text: badge > 9 ? '9+' : '$badge'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small amber count pill with a ring in the background colour.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MediaQuery.withNoTextScaling(
      child: Container(
        key: const Key('hero-badge'),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: c.money,
          borderRadius: AppRadii.allPill,
          border: Border.all(color: c.surface, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: context.text.caption.w(700).copyWith(color: c.onMoney, height: 1.1),
        ),
      ),
    );
  }
}

/// One icon tab in [HeroTabs].
typedef HeroTab = ({IconData icon, String label});

/// Round icon tabs on a hero (438 Explore/Events): the active circle is
/// white, its label bold with a short underline.
class HeroTabs extends StatelessWidget {
  const HeroTabs({required this.tabs, required this.index, required this.onChanged, super.key});

  final List<HeroTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < tabs.length; i++)
          Semantics(
            button: true,
            selected: i == index,
            label: tabs[i].label,
            excludeSemantics: true,
            child: Pressable(
              onTap: () {
                if (i != index) AppHaptics.selection();
                onChanged(i);
              },
              borderRadius: AppRadii.all24,
              highlightColor: c.onHero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s1,
                ),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: context.motion.base,
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == index ? c.onHero : c.onHero.withValues(alpha: 0.16),
                      ),
                      child: Icon(
                        tabs[i].icon,
                        size: 28,
                        color: i == index ? c.primaryFill : c.onHero.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      tabs[i].label,
                      style: context.text.body
                          .w(600)
                          .copyWith(color: i == index ? c.onHero : c.onHero.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    AnimatedContainer(
                      duration: context.motion.base,
                      width: i == index ? 24 : 0,
                      height: 3,
                      decoration: BoxDecoration(color: c.onHero, borderRadius: AppRadii.allPill),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
