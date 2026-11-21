import 'package:flutter/material.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/painters/gauge_painter.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Arc gauge card (646): 240° arc on a `surfaceMuted` card, indigo progress,
/// black knob, big amount and caption in the middle. Settle-up uses it for
/// "settled so far". Progress animates with the base motion.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    required this.progress,
    required this.valueText,
    required this.caption,
    this.size = 240,
    super.key,
  });

  /// 0–1.
  final double progress;
  final String valueText;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Semantics(
      label: caption,
      value: '$valueText, ${AppLocalizations.of(context).gaugeSemantics(percent)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s6),
        decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: AppRadii.all32),
        child: SizedBox.square(
          dimension: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: context.motion.slow,
            curve: AppMotion.standard,
            builder: (context, value, child) => CustomPaint(
              painter: GaugePainter(
                progress: value,
                track: context.isDark ? c.chip : c.surface,
                fill: c.primary,
                knob: c.ink,
              ),
              child: child,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        valueText,
                        style: context.text.amountHero.copyWith(color: c.primary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s1),
                    Text(
                      caption,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: context.text.body.w(500).copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
