import 'package:flutter/material.dart';

/// Colour tokens (planning/06-design-system.md §2) as a [ThemeExtension].
///
/// Widgets read them with `context.colors`. Never use literal colours outside
/// `lib/ui/theme/` (guarded by `tool/guards.dart`).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.bgSubtle,
    required this.surface,
    required this.surfaceMuted,
    required this.chip,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryPressed,
    required this.primaryDisabled,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.money,
    required this.onMoney,
    required this.moneyPressed,
    required this.ink,
    required this.onInk,
    required this.owedText,
    required this.owedAccent,
    required this.oweText,
    required this.oweAccent,
    required this.owedOnDark,
    required this.oweOnDark,
    required this.settled,
    required this.info,
    required this.infoContainer,
    required this.unsynced,
    required this.heroTop,
    required this.heroBottom,
    required this.onHero,
    required this.onHeroMuted,
    required this.glassFill,
    required this.glassFallback,
    required this.glassBorder,
    required this.navyTop,
    required this.navyBottom,
    required this.metal,
    required this.metalHighlight,
    required this.metalShade,
    required this.onMetal,
    required this.leatherTop,
    required this.leatherBottom,
    required this.stitch,
    required this.goldLight,
    required this.goldMid,
    required this.goldDark,
    required this.onGold,
    required this.chipDarkGreen,
    required this.onChipDarkGreen,
    required this.chipDarkRed,
    required this.onChipDarkRed,
    required this.blobLavender,
    required this.blobPink,
    required this.scrim,
    required this.sheetHandle,
    required this.shadow,
  });

  final Color bg;
  final Color bgSubtle;
  final Color surface;
  final Color surfaceMuted;
  final Color chip;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Indigo for text, icons and outlines.
  final Color primary;
  final Color primaryPressed;
  final Color primaryDisabled;
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Indigo for filled surfaces with white text (banners, status pills);
  /// same in both modes so white text stays AA (S-005).
  final Color primaryFill;
  final Color onPrimaryFill;

  /// Amber: main money actions (Save expense, Settle up, Mark as paid).
  final Color money;
  final Color onMoney;
  final Color moneyPressed;

  /// Black in light mode, white in dark mode (nav pill, primary buttons).
  final Color ink;
  final Color onInk;
  final Color owedText;
  final Color owedAccent;
  final Color oweText;
  final Color oweAccent;

  /// Money colours on dark imagery (covers, glass, navy cards).
  final Color owedOnDark;
  final Color oweOnDark;
  final Color settled;
  final Color info;
  final Color infoContainer;
  final Color unsynced;
  final Color heroTop;
  final Color heroBottom;
  final Color onHero;
  final Color onHeroMuted;
  final Color glassFill;
  final Color glassFallback;
  final Color glassBorder;
  final Color navyTop;
  final Color navyBottom;
  final Color metal;
  final Color metalHighlight;
  final Color metalShade;
  final Color onMetal;
  final Color leatherTop;
  final Color leatherBottom;
  final Color stitch;
  final Color goldLight;
  final Color goldMid;
  final Color goldDark;
  final Color onGold;
  final Color chipDarkGreen;
  final Color onChipDarkGreen;
  final Color chipDarkRed;
  final Color onChipDarkRed;
  final Color blobLavender;
  final Color blobPink;
  final Color scrim;
  final Color sheetHandle;

  /// Base colour of shadows (rgba(16,24,40)); alpha comes from the shadow token.
  final Color shadow;

  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    bgSubtle: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F5F9),
    chip: Color(0xFFEEF2F6),
    border: Color(0xFFE3E8EF),
    divider: Color(0xFFCDD5DF),
    textPrimary: Color(0xFF121926),
    // 4.5:1 also on chip / surfaceMuted fills (was #697586, 4.2:1 there; R3-A S-445).
    textSecondary: Color(0xFF616F7F),
    textTertiary: Color(0xFF9AA4B2),
    primary: Color(0xFF5057EA),
    primaryPressed: Color(0xFF3F45D6),
    primaryDisabled: Color(0xFFA7ABF4),
    primaryContainer: Color(0xFFE8E8F8),
    onPrimaryContainer: Color(0xFF3A3FC4),
    primaryFill: Color(0xFF5057EA),
    onPrimaryFill: Color(0xFFFFFFFF),
    money: Color(0xFFFDB022),
    onMoney: Color(0xFF121926),
    moneyPressed: Color(0xFFF59E0B),
    ink: Color(0xFF000000),
    onInk: Color(0xFFFFFFFF),
    owedText: Color(0xFF15803D),
    owedAccent: Color(0xFF84CC16),
    oweText: Color(0xFFD92D2D),
    oweAccent: Color(0xFFEA5050),
    owedOnDark: Color(0xFFA3E635),
    oweOnDark: Color(0xFFF87171),
    settled: Color(0xFF616F7F),
    info: Color(0xFF3B82F6),
    infoContainer: Color(0xFFEAF3FF),
    unsynced: Color(0xFFB45309),
    heroTop: Color(0xFF6E70B0),
    heroBottom: Color(0xFF9293CB),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xCCFFFFFF),
    glassFill: Color(0x47000000),
    glassFallback: Color(0x73000000),
    glassBorder: Color(0x38FFFFFF),
    navyTop: Color(0xFF030518),
    navyBottom: Color(0xFF022945),
    metal: Color(0xFFBFC3C9),
    metalHighlight: Color(0xFFE9ECEF),
    metalShade: Color(0xFF8E949C),
    onMetal: Color(0xFF121926),
    leatherTop: Color(0xFF2E2E31),
    leatherBottom: Color(0xFF151517),
    stitch: Color(0xFF85858B),
    goldLight: Color(0xFFF1E2C8),
    goldMid: Color(0xFFD2B48C),
    goldDark: Color(0xFFB08D60),
    onGold: Color(0xFF3D2E1C),
    chipDarkGreen: Color(0xFF375010),
    onChipDarkGreen: Color(0xFFA3E635),
    chipDarkRed: Color(0xFF5C1717),
    onChipDarkRed: Color(0xFFFCA5A5),
    blobLavender: Color(0xFFEFEFFA),
    blobPink: Color(0xFFF9ECF1),
    scrim: Color(0x66000000),
    sheetHandle: Color(0xFFA9A9A9),
    shadow: Color(0xFF101828),
  );

  static const dark = AppColors(
    bg: Color(0xFF050507),
    bgSubtle: Color(0xFF0E0E13),
    surface: Color(0xFF141419),
    surfaceMuted: Color(0xFF1C1C24),
    chip: Color(0xFF24242D),
    border: Color(0xFF2C2C36),
    divider: Color(0xFF33333E),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF71717A),
    primary: Color(0xFF7C83FF),
    primaryPressed: Color(0xFF6A71F5),
    primaryDisabled: Color(0xFF3B3F7A),
    primaryContainer: Color(0xFF23244A),
    onPrimaryContainer: Color(0xFFC9CBFF),
    primaryFill: Color(0xFF5057EA),
    onPrimaryFill: Color(0xFFFFFFFF),
    money: Color(0xFFFDB022),
    onMoney: Color(0xFF121926),
    moneyPressed: Color(0xFFF59E0B),
    ink: Color(0xFFFFFFFF),
    onInk: Color(0xFF000000),
    owedText: Color(0xFF4ADE80),
    owedAccent: Color(0xFFA3E635),
    oweText: Color(0xFFF87171),
    oweAccent: Color(0xFFEF6B6B),
    owedOnDark: Color(0xFFA3E635),
    oweOnDark: Color(0xFFF87171),
    settled: Color(0xFFA1A1AA),
    info: Color(0xFF60A5FA),
    infoContainer: Color(0xFF15263F),
    unsynced: Color(0xFFFBBF24),
    heroTop: Color(0xFF000000),
    heroBottom: Color(0xFF1A1A2E),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xCCFFFFFF),
    glassFill: Color(0x14FFFFFF),
    glassFallback: Color(0x73000000),
    glassBorder: Color(0x38FFFFFF),
    navyTop: Color(0xFF030518),
    navyBottom: Color(0xFF022945),
    metal: Color(0xFFBFC3C9),
    metalHighlight: Color(0xFFE9ECEF),
    metalShade: Color(0xFF8E949C),
    onMetal: Color(0xFF121926),
    leatherTop: Color(0xFF2E2E31),
    leatherBottom: Color(0xFF151517),
    stitch: Color(0xFF85858B),
    goldLight: Color(0xFFF1E2C8),
    goldMid: Color(0xFFD2B48C),
    goldDark: Color(0xFFB08D60),
    onGold: Color(0xFF3D2E1C),
    chipDarkGreen: Color(0xFF375010),
    onChipDarkGreen: Color(0xFFA3E635),
    chipDarkRed: Color(0xFF5C1717),
    onChipDarkRed: Color(0xFFFCA5A5),
    blobLavender: Color(0xFF1B1B2E),
    blobPink: Color(0xFF2A1820),
    scrim: Color(0x99000000),
    sheetHandle: Color(0xFF55555F),
    shadow: Color(0xFF000000),
  );

  List<Color> get _all => [
    bg, bgSubtle, surface, surfaceMuted, chip, border, divider, textPrimary, textSecondary, //
    textTertiary, primary, primaryPressed, primaryDisabled, primaryContainer, onPrimaryContainer,
    primaryFill, onPrimaryFill, money, onMoney, moneyPressed, ink, onInk, owedText, owedAccent,
    oweText, oweAccent, owedOnDark, oweOnDark, settled, info, infoContainer, unsynced, heroTop,
    heroBottom, onHero, onHeroMuted, glassFill, glassFallback, glassBorder, navyTop, navyBottom,
    metal, metalHighlight, metalShade, onMetal, leatherTop, leatherBottom, stitch, goldLight,
    goldMid, goldDark, onGold, chipDarkGreen, onChipDarkGreen, chipDarkRed, onChipDarkRed,
    blobLavender, blobPink, scrim, sheetHandle, shadow,
  ];

  static AppColors _fromList(List<Color> v) {
    var i = 0;
    Color n() => v[i++];
    return AppColors(
      bg: n(),
      bgSubtle: n(),
      surface: n(),
      surfaceMuted: n(),
      chip: n(),
      border: n(), //
      divider: n(),
      textPrimary: n(),
      textSecondary: n(),
      textTertiary: n(),
      primary: n(),
      primaryPressed: n(),
      primaryDisabled: n(),
      primaryContainer: n(),
      onPrimaryContainer: n(),
      primaryFill: n(),
      onPrimaryFill: n(),
      money: n(),
      onMoney: n(),
      moneyPressed: n(),
      ink: n(),
      onInk: n(),
      owedText: n(),
      owedAccent: n(),
      oweText: n(),
      oweAccent: n(),
      owedOnDark: n(),
      oweOnDark: n(),
      settled: n(),
      info: n(),
      infoContainer: n(),
      unsynced: n(),
      heroTop: n(),
      heroBottom: n(),
      onHero: n(),
      onHeroMuted: n(),
      glassFill: n(),
      glassFallback: n(),
      glassBorder: n(),
      navyTop: n(),
      navyBottom: n(),
      metal: n(),
      metalHighlight: n(),
      metalShade: n(),
      onMetal: n(),
      leatherTop: n(),
      leatherBottom: n(),
      stitch: n(),
      goldLight: n(),
      goldMid: n(),
      goldDark: n(),
      onGold: n(),
      chipDarkGreen: n(),
      onChipDarkGreen: n(),
      chipDarkRed: n(),
      onChipDarkRed: n(),
      blobLavender: n(),
      blobPink: n(),
      scrim: n(),
      sheetHandle: n(),
      shadow: n(),
    );
  }

  /// Token pairs (label, foreground, background, minimum ratio) that must pass
  /// WCAG AA. Used by `expectContrast()` in tests.
  List<(String, Color, Color, double)> get contrastPairs => [
    ('textPrimary/bg', textPrimary, bg, 4.5),
    ('textPrimary/surface', textPrimary, surface, 4.5),
    ('textSecondary/bg', textSecondary, bg, 4.5),
    ('textSecondary/surface', textSecondary, surface, 4.5),
    // R3-A (S-445): text on every neutral fill it is drawn on (bands, muted cards, chips, tracks).
    ('textPrimary/bgSubtle', textPrimary, bgSubtle, 4.5),
    ('textPrimary/surfaceMuted', textPrimary, surfaceMuted, 4.5),
    ('textPrimary/chip', textPrimary, chip, 4.5),
    ('textPrimary/primaryContainer', textPrimary, primaryContainer, 4.5),
    ('textSecondary/bgSubtle', textSecondary, bgSubtle, 4.5),
    ('textSecondary/surfaceMuted', textSecondary, surfaceMuted, 4.5),
    ('textSecondary/chip', textSecondary, chip, 4.5),
    ('primary/surface', primary, surface, 4.5),
    ('primary/surfaceMuted', primary, surfaceMuted, 4.5),
    ('owedText/surface', owedText, surface, 4.5),
    ('oweText/surface', oweText, surface, 4.5),
    ('settled/surface', settled, surface, 4.5),
    ('unsynced/surface', unsynced, surface, 4.5),
    ('owedText/surfaceMuted', owedText, surfaceMuted, 4.5),
    ('primary/bg', primary, bg, 4.5),
    ('onPrimaryContainer/primaryContainer', onPrimaryContainer, primaryContainer, 4.5),
    ('onPrimaryFill/primaryFill', onPrimaryFill, primaryFill, 4.5),
    ('onMoney/money', onMoney, money, 4.5),
    ('onInk/ink', onInk, ink, 4.5),
    ('owedText/bg', owedText, bg, 4.5),
    ('oweText/bg', oweText, bg, 4.5),
    ('settled/bg', settled, bg, 4.5),
    ('unsynced/bg', unsynced, bg, 4.5),
    ('onChipDarkGreen/chipDarkGreen', onChipDarkGreen, chipDarkGreen, 4.5),
    ('onChipDarkRed/chipDarkRed', onChipDarkRed, chipDarkRed, 4.5),
    ('onHero/heroTop', onHero, heroTop, 3),
    ('onHero/navyTop', onHero, navyTop, 4.5),
    ('owedOnDark/navyTop', owedOnDark, navyTop, 4.5),
    ('oweOnDark/navyTop', oweOnDark, navyTop, 4.5),
    ('onMetal/metal', onMetal, metal, 4.5),
    ('onGold/goldMid', onGold, goldMid, 4.5),
    ('info/infoContainer', info, infoContainer, 3),
  ];

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    final a = _all;
    final b = other._all;
    return _fromList([for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!]);
  }
}

/// Initials-avatar tint pair (background, foreground).
typedef AvatarTint = ({Color bg, Color fg});

/// Fixed colours that do not change with the theme mode.
abstract final class AppPalette {
  /// Avatar tints: lavender, peach, mint, sky, rose (§2), picked by
  /// `stableHash(id) % 5`.
  static const List<AvatarTint> avatarLight = [
    (bg: Color(0xFFE8E8F8), fg: Color(0xFF6D35D9)),
    // Peach and mint initials darkened to 4.5:1 (were 3.8:1; S-445).
    (bg: Color(0xFFFAF6EE), fg: Color(0xFFA35A17)),
    (bg: Color(0xFFF4FCF4), fg: Color(0xFF347C34)),
    (bg: Color(0xFFEAF3FF), fg: Color(0xFF1D5FC9)),
    (bg: Color(0xFFFDF0F3), fg: Color(0xFFB4335A)),
  ];

  static const List<AvatarTint> avatarDark = [
    (bg: Color(0xFF2A2350), fg: Color(0xFFC4B5FD)),
    (bg: Color(0xFF3A2A17), fg: Color(0xFFF4B67A)),
    (bg: Color(0xFF17301A), fg: Color(0xFF86D98A)),
    (bg: Color(0xFF15263F), fg: Color(0xFF93C0FA)),
    (bg: Color(0xFF3A1724), fg: Color(0xFFF49AB8)),
  ];

  /// Category icon colours (§2); icon sits on a 12 % tint circle.
  static const food = Color(0xFFF97316);
  static const groceries = Color(0xFF22C55E);
  static const travel = Color(0xFF3B82F6);
  static const rent = Color(0xFF8B5CF6);
  static const utilities = Color(0xFFEAB308);
  static const shopping = Color(0xFFEC4899);
  static const entertainment = Color(0xFF14B8A6);
  static const other = Color(0xFF64748B);

  /// Brand mark gradient (app icon, splash, welcome).
  static const brandStart = Color(0xFF5057EA);
  static const brandEnd = Color(0xFF9B9CE0);
  static const brandMark = Color(0xFFFFFFFF);

  /// Pure black, for gradients that fade imagery to dark (cover legibility).
  static const black = Color(0xFF000000);

  /// Pure white, for highlights painted on imagery.
  static const white = Color(0xFFFFFFFF);

  /// Transparent.
  static const clear = Color(0x00000000);

  /// The four colours of Google's "G" mark (sign-in branding guidelines; never recoloured).
  static const googleBlue = Color(0xFF4285F4);
  static const googleRed = Color(0xFFEA4335);
  static const googleYellow = Color(0xFFFBBC05);
  static const googleGreen = Color(0xFF34A853);
}
