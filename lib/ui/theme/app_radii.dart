import 'package:flutter/widgets.dart';
import 'package:splitify/ui/theme/app_colors.dart';

/// Corner radii (planning/06-design-system.md §4).
abstract final class AppRadii {
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
  static const double r28 = 28;
  static const double r32 = 32;
  static const double r36 = 36;
  static const double pill = 999;

  static const BorderRadius all16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius all24 = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius all28 = BorderRadius.all(Radius.circular(r28));
  static const BorderRadius all32 = BorderRadius.all(Radius.circular(r32));
  static const BorderRadius allPill = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(r32));
  static const BorderRadius overlapTop = BorderRadius.vertical(top: Radius.circular(r36));
}

/// Elevation tokens (§4). Dark mode uses borders instead of shadows.
abstract final class AppShadows {
  /// 0 8 24 rgba(16,24,40,0.12): capsule nav, floating CTA.
  static List<BoxShadow> float(AppColors c, {required bool dark}) => dark
      ? const []
      : [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.12),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ];

  /// 0 2 8 rgba(16,24,40,0.06): small cards, segmented thumb.
  static List<BoxShadow> card(AppColors c, {required bool dark}) => dark
      ? const []
      : [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ];

  /// Deeper shadow for showpiece objects (wallet, stacked cards, banners).
  static List<BoxShadow> lifted(AppColors c) => [
    BoxShadow(color: c.shadow.withValues(alpha: 0.18), offset: const Offset(0, 12), blurRadius: 28),
  ];
}
