/// 4 dp spacing grid (planning/06-design-system.md §4).
abstract final class AppSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;

  /// Screen side margin.
  static const double screen = 20;

  /// Grid gutter.
  static const double gutter = 12;

  /// How far an overlap sheet rides up over its hero.
  static const double sheetOverlap = 32;

  /// Minimum touch target.
  static const double minTouch = 48;

  /// Primary and secondary button heights. Secondary is 48, not the spec's
  /// 44, so every button meets the 48 dp touch target (S-006).
  static const double buttonLarge = 56;
  static const double buttonMedium = 48;

  /// Capsule nav: height, side margin, bottom margin and the amber add button.
  static const double navHeight = 64;
  static const double navSide = 16;
  static const double navBottom = 12;
  static const double navAdd = 56;

  /// Space screens keep free above the bottom edge for the floating nav.
  static const double navReserve = navHeight + navBottom + s6;

  /// Widest a column of content gets (tablets, open foldables, large phones in landscape): text lines stay
  /// readable and cards keep their phone proportions; backgrounds and heroes still fill the screen
  /// (R3-A, S-444).
  static const double maxContent = 560;

  /// Widest a bottom sheet gets (Material 3's bottom-sheet width).
  static const double maxSheet = 640;

  /// Widest the capsule nav with its add button gets.
  static const double maxNav = 520;

  /// From this width on the screen counts as a tablet / open foldable (Material's medium window class).
  static const double tabletWidth = 600;
}
