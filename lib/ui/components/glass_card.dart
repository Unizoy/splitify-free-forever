import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Frosted glass card over hero imagery (438): radius 32, dark translucent
/// fill, backdrop blur σ 18, thin white border, padding 20.
///
/// Use at most one per screen (§9 blur budget). With [blur] off — or when the
/// user removed animations — it falls back to a plain 45 % black fill.
class GlassCard extends StatelessWidget {
  const GlassCard({required this.child, this.blur = true, this.padding, super.key});

  final Widget child;
  final bool blur;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final useBlur = blur && !context.motion.reduced;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: useBlur ? c.glassFill : c.glassFallback,
        borderRadius: AppRadii.all32,
        border: Border.all(color: c.glassBorder),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.s5),
        child: DefaultTextStyle.merge(
          style: context.text.body.copyWith(color: c.onHero),
          child: IconTheme.merge(
            data: IconThemeData(color: c.onHero),
            child: child,
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: AppRadii.all32,
      child: useBlur
          ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: body)
          : body,
    );
  }
}
