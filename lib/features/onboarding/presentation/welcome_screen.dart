import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/components/brand_mark.dart';
import 'package:splitify/ui/components/dashed_circle_button.dart';
import 'package:splitify/ui/components/status_pill.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Onboarding (`/welcome`, 455): full-bleed generated art, the mark, a serif
/// headline with a lime highlight, the "free forever" chip and the turning
/// dashed "Get started" circle.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppPalette.clear,
        systemNavigationBarColor: AppPalette.clear,
      ),
      child: Scaffold(
        backgroundColor: c.navyTop,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const CoverArt(
              seed: 'splitify-welcome',
              family: CoverFamily.other,
              legibilityScrim: false,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppPalette.black.withValues(alpha: 0.30),
                    AppPalette.black.withValues(alpha: 0.45),
                    AppPalette.black.withValues(alpha: 0.70),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.s4),
                          Row(
                            children: [
                              const BrandMark(size: 32, tile: true),
                              const SizedBox(width: AppSpacing.s3),
                              Flexible(
                                child: Text(
                                  l.appTitle.toUpperCase(),
                                  style: context.text.labelCaps.copyWith(color: c.onHero),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12 + AppSpacing.s8),
                          Container(
                            width: 64,
                            height: 64,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.onHero.withValues(alpha: 0.14),
                              border: Border.all(color: c.onHero.withValues(alpha: 0.35)),
                            ),
                            child: const BrandMark(size: 36),
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          Semantics(
                            header: true,
                            child: MediaQuery.withClampedTextScaling(
                              maxScaleFactor: AppText.maxSerifScale,
                              child: Text.rich(
                                TextSpan(
                                  text: '${l.welcomeLead}\n',
                                  children: [
                                    TextSpan(
                                      text: l.welcomeHighlight,
                                      style: context.text.heroDisplay.copyWith(
                                        color: c.owedOnDark,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 46,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: context.text.heroDisplay.copyWith(
                                  color: c.onHero,
                                  fontSize: 46,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          StatusPill(
                            label: l.welcomeBadge,
                            icon: AppIcons.sparkle,
                            tone: StatusPillTone.positive,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          DashedCircleButton(
                            label: l.getStarted,
                            onPressed: () => context.go('/sign-in'),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Text(
                            l.welcomeFooter.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: context.text.labelCaps.copyWith(
                              color: c.onHero.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
