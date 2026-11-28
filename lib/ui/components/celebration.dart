import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitify/ui/painters/cover_cache.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Settle-up success (§6): cover cards fan out, a big check draws itself,
/// and a serif line with a lime highlighted word ("all *settled*").
/// Plays once with a medium haptic; shows the final frame when the user
/// removed animations. Sits on a navy panel so lime and white stay AA.
class Celebration extends StatefulWidget {
  const Celebration({
    required this.lead,
    required this.highlight,
    this.message,
    this.seed = 'celebrate',
    super.key,
  });

  final String lead;
  final String highlight;
  final String? message;

  /// Seeds the fanned cover cards.
  final String seed;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.motion.reduced) {
      _c.value = 1;
    } else {
      HapticFeedback.mediumImpact();
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b, [Curve curve = AppMotion.standard]) =>
      CurvedAnimation(
        parent: _c,
        curve: Interval(a, b, curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fan = _interval(0, 0.55, const SpringCurve());
    final check = _interval(0.3, 0.8);
    final text = _interval(0.5, 1);
    final families = [CoverFamily.trip, CoverFamily.couple, CoverFamily.home];
    return Semantics(
      liveRegion: true,
      label: '${widget.lead} ${widget.highlight}. ${widget.message ?? ''}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.all32,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.navyTop, c.navyBottom],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 190,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Transform.translate(
                          offset: Offset((i - 1) * 70 * fan.value, (i == 1 ? -8 : 6) * fan.value),
                          child: Transform.rotate(
                            angle: (i - 1) * 0.28 * fan.value,
                            child: _MiniCard(seed: '${widget.seed}-$i', family: families[i]),
                          ),
                        ),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: c.owedOnDark,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.lifted(c),
                        ),
                        child: CustomPaint(
                          painter: _CheckPainter(progress: check.value, color: c.navyTop),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              FadeTransition(
                opacity: text,
                child: Column(
                  children: [
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: AppText.maxSerifScale,
                      child: Text.rich(
                        TextSpan(
                          text: '${widget.lead} ',
                          children: [
                            TextSpan(
                              text: widget.highlight,
                              style: context.text.heroDisplay.copyWith(
                                color: c.owedOnDark,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: context.text.displayLarge.copyWith(color: c.onHero),
                      ),
                    ),
                    if (widget.message != null) ...[
                      const SizedBox(height: AppSpacing.s3),
                      Text(
                        widget.message!,
                        textAlign: TextAlign.center,
                        style: context.text.body.copyWith(color: c.onHero.withValues(alpha: 0.75)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.seed, required this.family});

  final String seed;
  final CoverFamily family;

  @override
  Widget build(BuildContext context) => Container(
    width: 112,
    height: 150,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: context.colors.onHero,
      borderRadius: AppRadii.all16,
      boxShadow: AppShadows.lifted(context.colors),
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.r12)),
      child: CoverArt(seed: seed, family: family, legibilityScrim: false, cache: false),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * min(progress, 1)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress || old.color != color;
}
